#!/usr/bin/perl
# $Id: extremes.t,v 1.5 2003/12/03 02:16:20 nothingmuch Exp $

### these sets of tests are not a model for a efficiency (code or programmer), but rather for clarity.
### when editing, please keep in mind that it must be absolutely clear what's going on, to ease debugging when we've forgotten what's going on.
### make sure to use lexical scoping to isolate tests from each other - you should not carry garbage around
### make sure you are coherent regarding the order of things
### make sure you comment, clearly and loudly, wherever something may look like it's doing something that it's not
### thanks,
### yuval, nothingmuch@woobling.org

use strict;
use warnings;

use Object::Meta::Plugin;
use Object::Meta::Plugin::Host;

use lib "t/lib";
use OMPTest; # auxillery testing libs

our $VERSION = 0.01;

$| = 1; # nicer to pipes
$\ = "\n"; # less to type?

my @test = ( # a series of test subs, which return true for success, 0 otherwise
	sub {
		eval { require Class::Classless } or return "can't load required module";
		
		my $o = OMPTest::Object::Thingy->new();
		my $host = Object::Meta::Plugin::Host->new();
		my $p = $Class::Classless::ROOT->clone() if defined $Class::Classless::ROOT;
		
		@{$p->{METHODS}}{qw/init exports foo bar/} = (
			\&OMPTest::Plugin::Classless::init,
			\&OMPTest::Plugin::Classless::exports,
			\&OMPTest::Plugin::Classless::foo,
			\&OMPTest::Plugin::Classless::bar,
		);
		
		$host->plug($p);
		
		my @steps = (
			qr/Classless::foo$/,
			qr/Classless::bar$/,
		);
		
		(@steps && $_ =~ (shift @steps)) or return undef foreach (@{$host->foo($o)}); return not @steps;
	},
	
	sub {
		eval { require Class::Object } or return "can't load required module";

		my $o = OMPTest::Object::Thingy->new();
		my $host = Object::Meta::Plugin::Host->new();
		my $p = new Class::Object;

		$p->sub('init', \&OMPTest::Plugin::Classless::init);
		$p->sub('exports', \&OMPTest::Plugin::Classless::exports);
		$p->sub('foo', \&OMPTest::Plugin::Classless::foo);
		$p->sub('bar', \&OMPTest::Plugin::Classless::bar);
		
		$host->plug($p);
	
		my @steps = (
			qr/Classless::foo$/,
			qr/Classless::bar$/,
		);
		
		(@steps && $_ =~ (shift @steps)) or return undef foreach (@{$host->foo($o)}); return not @steps;
	},
	sub {
		eval { require Class::SelfMethods } or return "can't load required module";
		sub Class::SelfMethods::DESTROY { }; # shut up that silly warning. I don't think it's my problem.
		
		my $o = OMPTest::Object::Thingy->new();
		my $host = Object::Meta::Plugin::Host->new();
		my $p = new Class::SelfMethods (
			init => \&OMPTest::Plugin::Classless::init,
			exports => \&OMPTest::Plugin::Classless::exports,
			foo => \&OMPTest::Plugin::Classless::foo,
			bar => \&OMPTest::Plugin::Classless::bar,
		);
		
		
		$host->plug($p);
	
		my @steps = (
			qr/Classless::foo$/,
			qr/Classless::bar$/,
		);
		
		(@steps && $_ =~ (shift @steps)) or return undef foreach (@{$host->foo($o)}); return not @steps;
	},
	sub {
		eval { require Class::Prototyped or return undef; import Class::Prototyped ':EZACCESS'; return 1 } or return "can't load required module";
		
		my $o = OMPTest::Object::Thingy->new();
		my $host = Object::Meta::Plugin::Host->new();
		my $p = new Class::Prototyped (
			init => \&OMPTest::Plugin::Classless::init,
			exports => \&OMPTest::Plugin::Classless::exports,
			foo => \&OMPTest::Plugin::Classless::foo,
			bar => \&OMPTest::Plugin::Classless::bar,
		);
		
		my $xi = Object::Meta::Plugin::ExportList::Info->new(qw/style force-tied/); # will probably break if Class::Prototyped changes.
		$host->plug($p, $xi);
		
		my @steps = (
			qr/Classless::foo$/,
			qr/Classless::bar$/,
		);
		
		(@steps && $_ =~ (shift @steps)) or return undef foreach (@{$host->foo($o)}); return not @steps;
	},
# 	sub {
# 		return "No solution for code ref objects yet. When tie will cover it, let me know.";
# 	
# 		eval { require OO::Closures } or return "can't load required module";
# 			
# 		my $o = OMPTest::Object::Thingy->new();
# 		my $host = Object::Meta::Plugin::Host->new();
# 		
# 		my %methods = (
# 			init => \&OMPTest::Plugin::Classless::init,
# 			exports => \&OMPTest::Plugin::Classless::exports,
# 			foo => \&OMPTest::Plugin::Classless::foo,
# 			bar => \&OMPTest::Plugin::Classless::bar,
# 		);
# 		my $p = OO::Closures::create_object (\%methods, {}, !@_);
# 		
# 		$host->plug($p);
# 		
# 		
# 		my @steps = (
# 			qr/Classless::foo$/,
# 			qr/Classless::bar$/,
# 		);
# 		
# 		(@steps && $_ =~ (shift @steps)) or return undef foreach (@{$host->foo($o)}); return not @steps;
# 	},
);

print "1..", scalar @test; # the number of tests we have

my $i = 0; # a counter

my $t = times();
foreach (@test) { my $e; print (($e = &$_) ? "ok " . ++$i . ( ($e ne "1") ? " # Skipped: $e" : "") : "not ok " . ++$i) } # test away
print "# tests took ", times() - $t, " cpu time";

exit;

1; # keep your mother happy

__END__

=pod

=head1 NAME

t/extremes.t - Weird ideas that should theoretically be possible. Breaking these will mean that we're doing something we probably don't want to be doing.

=head1 DESCRIPTION

The aim of this test file is to build a set of tests that should work in theory, and do work in practice, now that the implementation is simple an unoptimized.

As the L<Object::Meta::Plugin> implementation matures, and becomes more magical, I expect things to break without noticing.

If the standards regarding what works and what doesn't are set now, compatibility can be enforced, and perhaps ensured in the future.

=head1 TESTS

=over 4

=item 1

L<Class::Classless>

=item 2

L<Class::Object>

=item 3

L<Class::Prototyped>

=item 4

L<Class::SelfMethods>

=back

=head1 TODO

Nothing right now.

=head1 COPYRIGHT & LICENSE

	Copyright 2003 Yuval Kogman. All rights reserved.
	This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 SEE ALSO

L<t/basic.t>, L<t/error_handling.t>, L<t/greedy.t>, L<Class::Classless>, L<Class::Prototyped>, L<Class::Object>.

=cut
