#!/usr/bin/perl
# $Id: OMPTest.pm,v 1.7 2003/12/07 10:30:44 nothingmuch Exp $

use strict;
use warnings;

package OMPTest;

package OMPTest::Plugin::Generic; # base class

use strict;
use warnings;

use base 'Object::Meta::Plugin::Useful::Generic';

sub new {
	my $pkg = shift;
	my $self = $pkg->SUPER::new();
	$self->export(@_);
	$self;
}

package OMPTest::Plugin::Selfish; # actually it's just closed minded

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/foo bar gorch/) };

sub foo {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->bar->($obj);
}

sub bar { ### returns
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->super->ding($obj);
}

sub gorch {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->bar($obj);
}

package OMPTest::Plugin::Upset::One; # to test offsets

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/gorch bar/) };

sub gorch {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->next->bar($obj);
}

sub bar {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->next->gorch($obj);
}

package OMPTest::Plugin::Upset::Two;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/bar foo/) };

sub foo {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->prev->foo($obj);
}

sub bar {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->prev->bar($obj);
}

package OMPTest::Plugin::Upset::Picky;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/bar foo gorch/) };

sub foo {
	my $self = shift;
	my $obj = shift;
	
	foreach my $plugin (reverse @{ $self->super->stack('gorch') }){
		next if $plugin == $self->self;
		$self->super->specific($plugin)->gorch($obj);
	}
	
	$obj->add();
}

sub bar { # returns
	my $self = shift;
	my $obj = shift;
	
	for (my $i = 1; $i <= $#{ $self->super->stack('gorch') }; $i++){
		$self->offset($i)->gorch($obj);
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
	my $obj = shift;
	$obj->add();
	$self->super->gorch($obj);
}

sub gorch { ### returns
	my $self = shift;
	my $obj = shift;
	$obj->add();
}

sub ding { ### returns
	my $self = shift;
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
	my $obj = shift;
	$obj->add();
	$self->super->bar($obj);
}

sub bar { #### nothing returns, also relies on gorch to be defined by someone
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->super->gorch($obj);
}

package OMPTest::Plugin::Funny; # used within a plugged host, to bail into a higherlevel host

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/gorch/) };

sub gorch {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	$self->super->super->ding($obj); # note double super
}

package OMPTest::Plugin::MetaPlugin;

use strict;
use warnings;

use base 'OMPTest::Plugin::Generic';

sub new { $_[0]->SUPER::new(qw/init exports/) };

sub init {
	my $self = shift;
	
	if ($self->can("super")){
		#$self->super->{exported} = Object::Meta::Plugin::ExportList->new($self->super, @_); # don't mess with internals, delegate instead, however weird
		unshift @_, $self->super; &init; # goto &{ __PACKAGE__->can("init") }; # lol, what was i thinking...!
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
	my $obj = shift;
	
	return [] unless join(" ", sort keys %$self) eq join(" ", sort qw/what exports exported/);# methods have no whitespace, so i was sloppy
	
	$obj->add();
	my $method = $self->{what} if exists $self->{what};
	$method or return [];
	$self->$method($obj);
}

sub bar {
	my $self = shift;
	my $obj = shift;
	$obj->add($obj);
}

sub gorch {
	my $self = shift;
	my $obj = shift;
	$obj->add($obj)
}

package OMPTest::Plugin::Wicked; # i didn't know what else to name it

use base 'OMPTest::Plugin::Generic';

use Object::Meta::Plugin::Host;

sub new { # make sure we /don't/ get an error.
	my $self = $_[0]->SUPER::new(qw/foo bar gorch/);
	tie my %hash, 'Object::Meta::Plugin::Host::Context::TiedSelf::HASH', { plugin => $self };
	bless \%hash, ref $self;
}

sub init {
	my $self = shift;
	my $x = $self->SUPER::init(@_);
	$x->info->style('explicit') unless (@_);
	$x;
}

sub foo {
	my $self = shift;
	my $obj = shift;
	$obj->add();
	
	return [] unless join(" ", sort keys %$self) eq join(" ", sort qw/host instance plugin/);
	return [] unless join(" ", sort keys %{ $self->self() }) eq join(" ", sort qw/what exports exported/);
	
	my $method = $self->self->{what} if exists $self->self->{what};
	$self->$method($obj);
}

sub bar {
	my $self = shift;
	my $obj = shift;
	$obj->add($obj);
}

sub gorch {
	my $self = shift;
	my $obj = shift;
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
	my $obj = pop; # pop is because Class::Classless adds a CALLSTATE object
	$obj->add();
	$self->bar($obj);
}

sub bar {
	my $self = shift;
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

1; # Keep your mother happy.

__END__

=pod

=head1 NAME

OMPtest - A group of packages that help the testing process.

=head1 SYNOPSIS

	#

=head1 DESCRIPTION

Just a heap of plugin implementations, and that sort of stuff.

This is actually quite a useful source of example code. Most of the features of L<Object::Meta::Plugin> (the distribution, not the class) are exploited.

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

Have all the methods test what they're going to call with C<can>. This way the various C<can> implementations are tested to be working properly. Morever, the code refs can be passed down, and the next in line will check wether it is the same thing as what it should be. This can also prevent cases of dubious test deaths.

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
