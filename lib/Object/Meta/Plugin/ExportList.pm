#!/usr/bin/perl
# $Id: ExportList.pm,v 1.3 2003/12/03 02:34:47 nothingmuch Exp $

package Object::Meta::Plugin::ExportList; # an object representing the skin of a plugin - what can be plugged and unseamed at the top level.

use strict;
use warnings;

# this is a simple string based Object::Meta::Plugin::Export list. That is, all the methods are strings, and not code refs,
# which gives a somewhat more controlled environment.

# you could laxen these limits by writing your own ExportList, which will use code refs, and thus allow a plugin to nibble methods from other classes without base classing.
# you'd also have to subclass Object::Meta::Plugin::Host to handle coderefs. Perhaps a dualvalue system could be useful.

our $VERSION = 0.02;

sub new {
	my $pkg = shift;
	my $plugin = shift;
	
	my $self = bless {
		plugin => $plugin,
		info => (ref $_[0] ? shift : Object::Meta::Plugin::ExportList::Info->new()),
	}, $pkg;
	
	my @methods = @_;
	
	if (@methods){	
		my %list = map { $_, undef } $plugin->exports(); # used to cross out what's not exported	
		$self->{methods} = [ grep { exists $list{$_} } @methods ]; # filter the method list to be only what works;
	} else {
		$self->{methods} = [ $plugin->exports() ]; # everything unless otherwise stated
	}
	
	$self;
}

sub plugin {
	my $self = shift;
	$self->{plugin};
}

sub exists {
	my $self = shift;

	$self->{index} = { map { $_, undef } @{ $self->{methods} } } unless (exists $self->{index});
	
	if (wantarray){ # return a grepped list
		return grep { exists $self->{index}{$_} } @_;
	} else { # return a true or false
		return exists $self->{index}{$_[0]};
	}
}

sub list { # list all under plugin
	my $self = shift;
	
	return @{ $self->{methods} };
}

sub merge { # or another exoprt list into this one
	my $self = shift;
	my $x = shift;
	
	my %uniq;
	@{ $self->{methods} } = grep { not $uniq{$_}++ } @{ $self->{methods} }, $x->list();

	$self;
}

sub unmerge { # and (not|complement) another export list into this one
	my $self = shift;
	my $x = shift;
	
	my %seen = map { $_, undef } $x->list();
	@{ $self->{methods} } = grep { not exists $seen{$_} } @{ $self->{methods} };
}

sub info {
	my $self = shift;
	
	$self->{info} = shift if (@_);
	
	$self->{info};
}

package Object::Meta::Plugin::ExportList::Info; # for now it's basically a method->hashkey translator

our $AUTOLOAD;

sub new {
	my $pkg = shift;
	bless {@_ ? @_ : qw/
		style	tied
	/}, $pkg;
};

sub AUTOLOAD {
	my $self = shift;
	$AUTOLOAD =~ /.*::(.*)$/;
	my $method = $1;
	return if $method eq 'DESTROY';
	
	$self->{$method} = shift if (@_);
	
	$self->{$method};
}

1; # Keep your mother happy.

__END__

=pod

=head1 NAME

Object::Meta::Plugin::ExportList - an implementation of a very simple, string only export list.

=head1 SYNOPSIS

	# the proper way

	my $plugin = GoodPlugin->new();
	$host->plug($plugin);

	package GoodPlugin;

	# ...

	sub exports {
		qw/some methods/;
	}

	sub init {
		my $self = shift;
		return Object::Meta::Plugin::ExportList->new($self};
	}

	# or if you prefer.... *drum roll*
	# the naughty way

	my $plugin = BadPlugin->new();	# doesn't need to be a plugin per se, since
									# it's not verified by plug(). All it needs
									# is to have a working can(). the export
									# list is responsible for the rest.
									# in short, this way init() needn't be defined.

	my $export = Object::Meta::Plugin::ExportList->new($plugin, qw/foo bar/);

	$host->register($export);

=head1 DESCRIPTION

An export list is an object a plugin hands over to a host, stating what it is going to give it. This is a very basic implementation, providing only the bare minimum methods needed to register a plugin. Unregistering one requires even less.

=head1 METHODS

=over 4

=item new PLUGIN [ INFO ] [ METHODS ... ]

Creates a new export list object. If it is a reference, it will be assumed that the second argument is an info object. Provided that is the case, no info object will be created, and the argued one will be used in place. Any remaining arguments will be method names to be exported. If none are specified, the return value from the plugin's C<exports> method is used.

=item list

Returns a list of exported method names.

=item plugin

Returns the reference to the plugin object it represents.

=item exists METHODS ...

In scalar context will return truth if the first argument is a method that exists in the export list. In list context, it will return the method names given in @_, with the inexistent ones excluded.

=item merge EXPORTLIST

Performs an I<or> with the methods of the argued export list.

=item unmerge EXPORTLIST

Performs an I<and> of the I<complement> of the argued export list.

=item info [ INFO ]

Stores meta information regarding the plugin it represents. It's stored in the export list because the export list is what you use to communicate with the host.

Currently only the I<style> field is defined, which will effect the kind of context shim that is created. The default is the most naive, but also the least efficient - the tied context.

=back

=head1 Object::Meta::Plugin::ExportList::Info

This is just a hash, basically. It has an autoloader which will fetch a hash key by the method name with no arguments, or set the value to the first argument if it's there.

Deletion is not supported.

=head2 Known attributes

=over 4

=item style

This attribute can have one of two values, either I<tied> or I<explicit>. It tells the context shims how to behave. On I<tied>, the default, the shim will have it's structure be a tied one, representing the structure of the plugin. Currently hash, array and scalar refs are supported. Filehandle tie support is a little bit hairy at the moment. The I<explicit> style gives the standard shim structure to the plugin. To gain access to it's structures a plugin will then need to call the method C<self> on the shim, as documented in L<Object::Meta::Plugin::Host>. I<explicit> is probably much more efficient, but is less coder friendly. The value I<force-tied> is honored by L<Object::Meta::Plugin::Host::Context>, and will not die on C<plug> time if you try to use it on a plugin whose structure is already tied.

Again, see L<Object::Meta::Plugin::Host> for documentation of the way styles change things.

=back

=head1 CAVEATS

=over 4

=item *

Relies on the plugin implementation to provide a non-mandatory extension - the C<exports> method. This method is available in all the L<Object::Meta::Plugin::Useful> variants, and since L<Object::Meta::Plugin> is not usable on it's own this is probably ok.

=back

=head1 BUGS

Not that I know of, for the while being at least.

=head1 COPYRIGHT & LICENSE

	Copyright 2003 Yuval Kogman. All rights reserved.
	This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 SEE ALSO

L<Object::Meta::Plugin>, L<Object::Meta::Plugin::Useful>, L<Object::Meta::Plugin::Host>

=cut
