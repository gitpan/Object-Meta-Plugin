#!/usr/bin/perl
# $Id: Greedy.pm,v 1.9 2003/12/10 03:52:30 nothingmuch Exp $

package Object::Meta::Plugin::Useful::Greedy;

use strict;
use warnings;

use base 'Object::Meta::Plugin::Useful';

use Devel::Symdump;
use Class::ISA;

our $VERSION = 0.02;

sub exports {
	my $self = shift;
	my %seen;
	
	return $self->_filter( # filters the method names
		grep { not $seen{$_}++ } # filter duplicates
			map { s/.*:://; $_ } # $_ is any function implemented somewhere in $self's @ISA tree. Removes the namespace of all the functions.
				map { Devel::Symdump->new($_)->functions() } # $_ is any package that $self is (-a). Returns all the functions in all the packages.
					($_, Class::ISA::super_path($_)) # $_ is the package of $self, because of the for right below here
	) for ref $self;
}

sub _filter {
	shift;
	return grep { !/^(?:
		croak	|	# imported into the namespace
		carp	|
		exports	|	# provided by this class
		init	|	# provided by the 
		new			# typically undesired
	)$/x } grep { /^(?!_)/ } @_;
}

1; # Keep your mother happy.

__END__

=pod

=head1 NAME

Object::Meta::Plugin::Useful::Greedy - A useful plugin base class which gobbles up reasonable parts of the symbol table at export time.

=head1 SYNOPSIS

	package Foo;

	use base 'Object::Meta::Plugin::Useful::Greedy';

	sub new {
		# ...
	}
	
	sub ppretty {
		# ...
	}

	sub ver_pretty {
		# ...
	}

	sub ugly { # will not be exported because of the pattern
		# ...
	}

	sub _filter {
		grep {/pretty/} @_;
	}

=head1 DESCRIPTION

This is a base class for a pretty standard, pretty easy plugin. When C<export > is called it goes through the symbol table of the plugin's package, as per C<ref $self>, and so forth through all the @ISAs it finds. The functions it finds along the way are collected, and filtered.

=head1 METHODS

=over 4

=item exports

This rummages it's class's symbol table, and returns a list of method names as filtered by C<_filter>.

=item _filter LIST

This takes a list of method names, and munges it into something. The current example will filter things that don't look pretty (don't start with an underscore), and that are probably undesired (C<new>, C<init>, C<exports>, C<carp> & C<croak>).

You can define C<_filter> in your class, if you want more control of the filtering process.

@_ passed to this method will consist of a duplicate free list of all the bareword method names found in all of the packages that the plugin's class @ISA contains, as determined by L<Class::ISA>.

=back

=head1 CAVEATS

=over 4

=item *

Does not work on classless objects and such. The plugin in question must be blessed into a real class, with a real symbol table, and a real @ISA full of real classes with real what-nots. How dull.

=item *

Relies on the non core module L<Devel::Symdump>.

=back

=head1 BUGS

Peh! You must be kididgn!

=head1 TODO

Nothing right now.

=head1 COPYRIGHT & LICENSE

	Copyright 2003 Yuval Kogman. All rights reserved.
	This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 SEE ALSO

L<Object::Meta::Plugin>, L<Object::Meta::Plugin::Useful>, L<Object::meta::Plugin::Useful::Generic>, L<Object::Meta::Plugin::Useful::Meta>.

=cut
