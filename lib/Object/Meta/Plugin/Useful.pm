#!/usr/bin/perl
# $Id: Useful.pm,v 1.4 2003/12/03 02:20:14 nothingmuch Exp $

package Object::Meta::Plugin::Useful; # a base class for useful plugins, defines reasonable default methods

use strict;
use warnings;

use base 'Object::Meta::Plugin';

use Object::Meta::Plugin::ExportList;

our $VERSION = 0.01;

sub new {
	my $pkg = shift;
	
	bless {
		exported => undef, # the export list thought to be currently relevant
		exports => [], # the exports list
	}, $pkg;
}

sub init {
	my $self = shift;
	my $style;

	$self->{exported} = Object::Meta::Plugin::ExportList->new($self, @_); # create a new export list, with the methods as stated in the call to plug, and save it for future reference
}

1; # Keep your mother happy.

__END__

=pod

=head1 NAME

Object::Meta::Plugin::Useful - a subclass of L<Object::Meta::Plugin>, base class of the various Useful:: plugins.

=head1 SYNOPSIS

	# use the others. see bottom

=head1 DESCRIPTION

This is the parent of all the plugin base classes that fall under Useful::. It defines a generic constructor, as well as an C<init> without suicidal tendencies.

=head2 L<Object::Meta::Plugin::Useful::Generic>

This is a base class for a plugin which extends Object::Meta::Plugin::Useful. It provides the C<export> method, with which you explicitly select methods for export.

=head2 L<Object::Meta::Plugin::Useful::Meta>

This is a base class for a [meta] plugin which extends Object::Meta::Plugin::Useful as well as L<Object::Meta::Plugin::Host>. It's function is to provide the necessary bridging a host needs from the outside of the host. See the L<Object::Meta::Plugin::Useful::Meta>'s documents (the CAVEATS section), or the test suite (basic.t) for how to do this from within the host, without extending L<Object::Meta::Plugin::Host>, but rather plugging into one.

=head2 L<Object::Meta::Plugin::Useful::Greedy>

This is a base class for a plugin which extends Object::Meta::Plugin::Useful. It gobbles the defined methods of an object from it's symbol table / @ISA tree, and then filters them using the [overridable] method C<_filter>. It should provide the easiest functionality, provided that there is no wizardry going on. The other downside is that it requires L<Devel::Symdump> to work.

=head1 METHODS

=over 4

=item new

This method will create a new object, with a hash data structure. The key 'exported' is used, and it's value will be an L<Object::Meta::Plugin::ExportList> object, created when C<init> is called.

=item init

This method will will create a new export list. All arguments to it (probably accepted from L<Object::Meta::Plugin::Host>'s C<plug> method, are passed to L<Object::Meta::Plugin::ExportList>'s C<new>.

=back

=head1 COPYRIGHT & LICENSE

	Copyright 2003 Yuval Kogman. All rights reserved.
	This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 SEE ALSO

L<Object::Meta::Plugin>, L<Object::Meta::Plugin::Useful::Generic>, L<Object::Meta::Plugin::Useful::Meta>.

=cut
