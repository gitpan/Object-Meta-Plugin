#!/usr/bin/perl
# $Id: OMPTest.pm,v 1.10 2003/12/11 14:27:18 nothingmuch Exp $

use strict;
use warnings;

package OMPTest;

sub new {
	my $pkg = shift;
	my $name = shift;
	
	bless {
		name => $name,
		result => undef,
		error => undef,
	}
}

our $AUTOLOAD;
sub AUTOLOAD {
	my $self = shift;
	$AUTOLOAD =~ s/.*:://;
	$self->{$AUTOLOAD} = shift if @_;
	$self->{$AUTOLOAD};
}

package OMPTest::WhoAmI;

use strict;
use warnings;

sub whoami {
	my @path = split('::',((caller(1))[3]));
	my $subname = pop @path;
	my $subref = \ %main::;
	
	foreach my $sym (@path){
		$subref = $subref->{$sym . "::"};
	}
	
	return \&{ $subref->{$subname} };
}

package OMPTest::Plugin::Generic; # base class

use strict;
use warnings;

use base qw/Object::Meta::Plugin::Useful::Generic OMPTest::WhoAmI/;

sub new {
	my $pkg = shift;
	my $self = $pkg->SUPER::new();
	$self->export(@_);
	$self;
}

package OMPTest::Host::Plugin;

use strict;
use warnings;

use base qw/Object::Meta::Plugin::Useful::Meta OMPTest::WhoAmI/;

package OMPTest::Plugin::Selfish; # actually it's just closed minded

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo bar gorch/) };

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	return $self->can($_) ? $self->$_($obj) : [] for ('bar');
}

sub bar { ### returns
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = 'ding';
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	
	return $self->super->$m($obj,$r);
}

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	my $m = 'private';
	my $r = $self->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->$m($obj,$r);
}

sub private {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	
	my $m = 'bar';
	my $r = $self->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->$m($obj, $self->$r());
}

package OMPTest::Plugin::Upset::One; # to test offsets

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/gorch bar/) };

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = 'bar';
	my $r = $self->next->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->next->$m($obj, $self->$r());
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = 'gorch';
	my $r = $self->next->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->next->$m($obj, $self->$r());
}

package OMPTest::Plugin::Upset::Two;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/bar foo/) };

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = 'foo';
	my $r = $self->prev->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->prev->$m($obj, $self->$r());
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = 'bar';
	my $r = $self->prev->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->prev->$m($obj, $self->$r());
}

package OMPTest::Plugin::Upset::Picky;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/bar foo gorch/) };

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	
	return [] unless ($self->whoami() == shift);
	
	my $m = 'gorch';
	
	foreach my $plugin (reverse @{ $self->super->stack($m) }){
		next if $plugin == $self->self;
		
		my $r = $self->super->specific($plugin)->can($m) or return [];
		$self->super->specific($plugin)->$m($obj, $self->$r());
	}
	
	$obj->add();
}

sub bar { # returns
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	
	return [] unless ($self->whoami() == shift);
	
	my $m = 'gorch';
	
	for (my $i = 1; $i <= $#{ $self->super->stack($m) }; $i++){
		my $r = $self->offset($i)->can($m) or return [];
		$self->offset($i)->$m($obj, $self->$r());
	}
	
	$obj->add();
}

sub gorch {} # never called

package OMPTest::Plugin::Upset::Picky::AnotherGorch;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/gorch/) };

sub gorch { ### returns
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
}

package OMPTest::Plugin::Nice::One;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo gorch ding/) }

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();

	my $m = 'gorch';
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

sub gorch { ### returns
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
}

sub ding { ### returns
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
}

package OMPTest::Plugin::Nice::Two;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo bar/) }

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	my $m = 'bar';
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

sub bar { #### nothing returns, also relies on gorch to be defined by someone
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	my $m = 'gorch';
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

package OMPTest::Plugin::Funny; # used within a plugged host, to bail into a higherlevel host

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/gorch/) };

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	my $m = 'ding';
	my $r = $self->super->super->can($m); # note double super
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->super->$m($obj, $self->$r());
}

package OMPTest::Plugin::Serious; # like funny only without supersuper

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/gorch/) };

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	my $m = 'ding';
	my $r = $self->super->can($m); # note double super
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

package OMPTest::Plugin::MetaPlugin;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/init exports whoami/) };

sub init {
	my $self = shift;
	
	if ($self->can("super")){
		unshift @_, $self->super; &init;
	} else {
		$self->SUPER::init(@_);
	}
}

sub exports { # if $self->can(super) return self->super->methods, whatever. Otherwise, export self as a plugin.
	my $self = shift;
	
	if ($self->can("super")){ # plugged in
		keys %{ $self->super->methods }
	} else {
		$self->SUPER::exports(@_);
	}
}

package OMPTest::Plugin::Nosey;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo bar gorch/) };

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	
	return [] unless join(" ", sort keys %$self) eq join(" ", sort 'what', keys %{ OMPTest::Plugin::Generic->new() } );# methods have no whitespace, so i was sloppy
	
	$obj->add();
	my $m = $self->{what} or return [] if exists $self->{what};
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj);
}

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj)
}

package OMPTest::Plugin::Tricky;

use strict;
use warnings;

use base "OMPTest::Plugin::Generic";

use Scalar::Util qw(reftype);

sub new { my $pkg = shift; bless [ $pkg->SUPER::new(qw/foo bar gorch/) ], $pkg; } # has-a, not is-a
sub exports {
	my $self = shift;
	$self = $self->[0] if (reftype($self) eq 'ARRAY');
	$self->SUPER::exports(@_);
}

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = pop @$self or return [];
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj);
}

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj)
}

package OMPTest::Plugin::Wicked; # i didn't know what else to name it

use strict;
use warnings;
use warnings::register;

use base 'OMPTest::Plugin::Generic';

use Tie::RefHash;
use Scalar::Util qw(reftype);

sub new {
	my $pkg = shift;
	my $self = bless [ ], $pkg;
	tie @$self, __PACKAGE__."::Tie";
	@$self = ($pkg->SUPER::new(qw/foo bar gorch/));
	$self;
}

sub init {
	my $self = shift;
	my $x = $self->SUPER::init(@_);
	$x->info->style('force-implicit') unless (@_);
	$x;
}

sub exports {
	my $self = shift;
	$self = $self->[0] if (reftype($self) eq 'ARRAY');
	$self->SUPER::exports(@_);
}

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	$obj->add();
	
	my $m = pop @$self or return [];
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj);
}

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj)
}

package OMPTest::Plugin::Wicked::Tie;

use strict;
use warnings;

use base 'Tie::Array';

sub TIEARRAY { bless [], shift };
sub FETCH { $_[0][$_[1]] };
sub FETCHSIZE { scalar @{ $_[0] } };
sub EXISTS { exists ${ $_[0] }[$_[1]] };
sub STORE { $_[0][$_[1]] = $_[2] };
sub STORESIZE { $#{$_[0]} = $_[1]-1 };
sub DELETE { delete ${ $_[0] }[$_[1]] };

package OMPTest::Plugin::Explicit;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo bar gorch/) };
sub init {
	my $self = shift;
	my $x = $self->SUPER::init();
	$x->info->style('explicit') unless (@_);
	$x;
}

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
		
	$obj->add();
	my $m = $self->self->{what} or return [] if exists $self->self->{what};
	my $r = $self->super->can($m);
	return [] unless ($r && ($self->whoami() == shift));
	return $self->super->$m($obj, $self->$r());
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj);
}

sub gorch {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = shift;
	return [] unless ($self->whoami() == shift);
	$obj->add($obj)
}

package OMPTest::Plugin::Classless;

use strict;
use warnings;

sub init {
	Object::Meta::Plugin::ExportList->new(grep { !/Class::Classless::CALLSTATE=ARRAY\(0x[0-9a-f]+\)/ } @_);
}

sub exports {
	qw/foo bar/;
}

sub foo {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = pop; # pop is because Class::Classless adds a CALLSTATE object
	$obj->add();
	return $self->can($_) ? $self->$_($obj) : [] for ('bar');
}

sub bar {
	my $self = shift;
	return $self->whoami() unless @_;
	my $obj = pop;
	$obj->add();
}

package OMPTest::Object::Thingy; # records who used it

use strict;
use warnings;

sub new {
	my $pkg = shift;
	bless [], $pkg;
}

sub add {
	push @{ $_[0] }, join("::", (caller(1))[0,3]);
	return $_[0];
}

package OMPTest::Plugin::Weird::Stringified;

use base 'OMPTest::Plugin::Wicked';
use overload '""' => sub { "foo" };

sub foo {
	my $self = shift;
	"$self";
}

package OMPTest::Plugin::Naughty::Nextport;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/next/) };

sub next {}

package OMPTest::Plugin::Naughty::Empty;

sub new { bless {}, shift }

package OMPTest::Plugin::Naughty::Undefs;

sub new { bless {}, shift}
sub init { undef };

package OMPTest::Plugin::Naughty::Crap;

sub new { bless {}, shift}
sub init { bless {}, 'NotReallyAnExportList' };

package OMPTest::Plugin::Naughty::Exports;

sub new { bless {}, shift }
sub exports { qw/method_i_have method_i_dont_have/ };
sub init { Object::Meta::Plugin::ExportList->new($_[0]) };
sub method_i_have {}

package OMPTest::Plugin::Noughty::OffsetDontHave;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo/) };

sub foo {
	my $self = shift;
	$self->next->ding();
}

package OMPTest::Plugin::Noughty::Overloaded;

use strict;
use warnings;
use warnings::register;

use base 'OMPTest::Plugin::Generic';
use overload '@{}' => sub {}, 'fallback' => 1;

1; # Keep your mother happy.

__END__

=pod

=head1 NAME

OMPtest - A group of packages that help the testing process.

=head1 SYNOPSIS

	#

=head1 DESCRIPTION

Just a heap of plugin implementations, and that sort of stuff.

This is actually quite a useful source of example code. Most (hopefully all) of the features of L<Object::Meta::Plugin> (the distribution, not the class) are exploited.

=head1 Classes

=over 4

=item OMPTest::Plugin::Generic

A base class for most of the plugin implementations found herein.

=item OMPTest::Plugin::Selfish

A plugin which will not use super, and thus get it's own methods, even if they're not first in the host.

=item OMPTest::Plugin::Upset

These plugins will use the various methods which cause other plugins to be called explicitly. That's C<offset>, C<next>, C<prev>, and C<specific>.

=item OMPTest::Plugin::Nice

These plugins respect the presence of others, and do everything via C<super>.

=item OMPTest::Plugin::Funny

This plugin is used to bail out of a plugged in host, by calling C<$self->super->super>.

=item OMPTest::Plugin::Serious

This plugin takes the place of C<OMPTest::Plugin::Funny>, but lets AUTOLOADER take care of going up a host.

=item OMPTest::Plugin::MetaPlugin

This plugin is used to make a host also serve as a plugin.

=item OMPTest::Plugin::Nosey

This plugin looks inside it's structures, to make sure it doesn't look like a shim.

=item OMPTest::Plugin::Tricky

This plugin is like nosey, but isn't a hash - it's an array. It tests the tied access implementation.

=item OMPTest::Plugin::Wicked

This is like tricky, but it's structure is also tied, thus achieving two layers of tying.

=item OMPTest::Plugin::Explicit

This plugin uses C<$self->self> to access it's structures.

=item OMPTest::Plugin::Classless

This plugin is used to test the various classless implementations, as found in L<t/extremes.t>

=item OMPTest::Object::Thingy

This is used to track method calls, and to later test that expected results happened. It does this with C<caller>

=item OMPTest::Plugin::Weird::Stringified

This plugin is tied, and overloads some operators in it's class.

=item OMPTest::Plugin::Naughty

These plugins do bad things, and should be caught.

=back

=head1 CAVEATS

None or many.

=head1 BUGS

=over 4

=item *

Documentation of the various elements is insufficient. This could be useful for a learn-by-example process.

=back

=head1 TODO

=over 4

=item *

Have all the methods test what they're going to call with C<can>. This way the various C<can> implementations are tested to be working properly. Moreover, the code refs can be passed down, and the next in line will check whether it is the same thing as what it should be. This can also prevent cases of dubious test deaths.

=item *

Make the tests verbose.

=back

=head1 COPYRIGHT & LICENSE

	Copyright 2003 Yuval Kogman. All rights reserved.
	This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 SEE ALSO

L<t/basic.t>, L<t/error_handling.t>.

=cut
