#!/usr/bin/perl
# $Id: Host.pm,v 1.23 2003/12/11 14:27:17 nothingmuch Exp $

package Object::Meta::Plugin::Host;

use strict;
use warnings;

use autouse Carp => qw(croak);
use Scalar::Util qw(reftype);
use Tie::RefHash;

our $VERSION = 0.02;
our $AUTOLOAD;

sub new {
	my $pkg = shift;
	my $self = {
		plugins => {}, # plugin ref hash
		methods => {}, # method look up, with an array of plugin refs per method
	};
	
	tie %{ $self->{plugins} }, 'Tie::RefHash';
	
	bless $self, $pkg;
}

sub plugins {
	my $self = shift;
	return $self->{plugins};
}

sub methods {
	my $self = shift;

	return $self->{methods};
}

sub plug {
	my $self = shift;
	my $plugin = shift;
	
	croak "$plugin doesn't look like a plugin" if (grep { not $plugin->can($_) } qw/init/);

	my $x = $self->register($plugin->init(@_) or croak "init() did not return an export list");
	
	if ($x->info->style() eq 'implicit'){
	
		if (reftype($plugin) eq 'ARRAY'){
			warnings::warnif($plugin,"You probably shouldn't use implicit access context shims if the underlying plugin's structure is already a tied array. Use the 'tied' style if you want to suppress this message") if do { local $@; eval { tied (@{$plugin}) } };
		} else {
			warnings::warnif($plugin,"Overloading a plugin's \@{} operator will create unexpected behavior under the implicit style") if (overload::Method($plugin, '@{}'));
		}
	} else {
		STYLE: {
			foreach my $style (@Object::Meta::Plugin::Host::Context::styles){
				last STYLE if ($x->info->style() eq $style)
			}
			
			croak "Unknown plugin style \"",$x->info->style(),"\" for $plugin";
		}
	}
	
	$x;
}

sub unplug { #
	my $self = shift;

	foreach my $plugin (@_){
		foreach my $method (keys %{ $self->methods }){
			next unless $plugin->can($method);
			@{ $self->methods->{$method} } = grep { $_ != $plugin } @{ $self->methods->{$method} };
			delete $self->methods->{$method} unless @{ $self->methods->{$method} };
		}
		
		delete $self->plugins->{$plugin};
	}
}

sub register { # export list
	my $self = shift;
	my $x = shift;
	
	croak "$x doesn't look like a valid export list" if (!$x or grep { not $x->can($_) } qw/list plugin exists merge unmerge info/);
	
	foreach my $method ($x->list()){
		croak "Method \"$method\" is reserved for use by the context object" if Object::Meta::Plugin::Host::Context->UNIVERSAL::can($method);
		croak "Can't locate object method \"$method\" via plugin ", $x->plugin(), unless $x->plugin->can($method);
		
		my $stack = $self->stack($method) || [];
		
		push @{$stack}, $x->plugin();
		
		$self->stack($method, $stack);
	}
	exists $self->plugins->{$x->plugin} ? $self->plugins->{$x->plugin}->merge($x) : $self->plugins->{$x->plugin} = $x; # should return success
}

sub unregister {
	my $self = shift;
	
	foreach my $x (@_){
		croak "$x doesn't look like a valid export list" if (!$x or grep { not $x->can($_) } qw/list plugin/);
		
		$self->plugins->{$x->plugin}->unmerge($x);
		
		foreach my $method ($x->list()){
			next unless $self->stack($method);
			
			@{ $self->stack($method) } = grep { $_ != $x->plugin } @{ $self->stack($method) };
			
			delete $self->methods->{$method} unless (@{ $self->stack($method) });
		}
	}
}

sub stack { # : lvalue { # grant access to the stack of a certain method.
	my $self = shift;
	my $method = shift;
	
	@_ ? ($self->methods->{$method} = shift) : $self->methods->{$method};
}

sub specific {
	my $self = shift;
	my $plugin = shift;
	
	croak "$plugin is not plugged into $self" unless exists $self->plugins->{$plugin};
	
	Object::Meta::Plugin::Host::Context->new($self, $plugin);
}

sub can { # provide a subref you can goto
	my $self = shift;
	my $method = shift;
	return $self->UNIVERSAL::can($method)
		|| ($self->stack($method) && sub { $AUTOLOAD = $method; goto &AUTOLOAD })
		|| ($self->UNIVERSAL::can('super') && $self->super->can($method));
}

sub AUTOLOAD { # where the magic happens
	my $self = shift;
	
	$AUTOLOAD =~ /([^:]*?)$/;
	my $method = $1;
	
	croak "Method \"$method\" is reserved for use by the context object" if Object::Meta::Plugin::Host::Context->UNIVERSAL::can($method); # UNIVERSAL can differs
	
	return undef if $method eq 'DESTROY';
	if (my $stack = $self->stack($method)){
		Object::Meta::Plugin::Host::Context->new($self, ${ $stack }[ -1 ])->$method(@_);
	} elsif ($self->can('super')){
		$self->super->$method(@_);
	} else { croak "Can't locate object method \"$method\" via any plugin in $self" }
}

package Object::Meta::Plugin::Host::Context; # the wrapper object which defines the context of a plugin

use strict;
use warnings;

use autouse 'Scalar::Util' => qw(reftype);
use autouse Carp => qw(croak);

our $VERSION = 0.01;
our $AUTOLOAD;

our @styles = qw/implicit explicit force-implicit/;

sub new {
	my $pkg = shift;
	
	my $self = bless [
		shift, # host
		shift, # plugin
		shift || 0, # instance # a plugin can be plugged into several slots, each of which needs it's own context
	], $pkg;
	
	my $style = $self->host->plugins->{$self->plugin}->info->style();

	return $self if $style eq 'explicit';

	reftype($self->plugin) eq 'ARRAY' and do {
		my @array;
		tie @array, __PACKAGE__."::TiedSelf", $self;
		$self = \@array;
	};
	
	bless $self, __PACKAGE__."::Overloaded";
}

### these methods access internals
### they need the real value of $self

sub instance {
	my $self = shift;
	$self = tied(@$self) || $self;
	$self->[2];	
}

sub super { # the real host
	my $self = shift;
	$self = tied(@$self) || $self;
	$self->[0];
}
sub host { goto &super }

sub plugin {
	my $self = shift;
	$self = tied(@$self) || $self;
	$self->[1];
}
sub self { goto &plugin }

### methods from here on don't access internals

sub offset { # get a context with a numerical offset
	my $self = shift;
	my $offset = -1 * shift;
	Object::Meta::Plugin::Host::Context::Offset->new($self->host,$self->plugin,$offset,$self->instance);
}

sub prev { # an overlying method - call a context one above
	my $self = shift;
	$self->offset(-1);
}

sub next { # an underlying method - call a context one below
	my $self = shift;
	$self->offset(1);
}

sub can { # try to return the correct method.
	my $self = shift;
	my $method = shift;
	$self->UNIVERSAL::can($method) || $self->plugin->can($method) || $self->host->can($method); # it's one of these, in that order
}

sub AUTOLOAD {
	my $self = shift;
	
	$AUTOLOAD =~ /([^:]*?)$/;
	my $method = $1;
	return undef if $method eq 'DESTROY';
	
	if (my $code = $self->plugin->can($method)){ # examine the plugin's export list in the host
		unshift @_, $self; # return self to the argument list. Should be O(1). lets hope.
		goto &$code;
	} else {
		$self->host->$method(@_);
	}
}

package Object::Meta::Plugin::Host::Context::Overloaded;
use base 'Object::Meta::Plugin::Host::Context';
use overload map { $_, 'plugin' } ('${}', '%{}', '&{}', '*{}', '=', 'nomethod'), fallback => 0;  # all ref types except for arrays, aswell as any other value are simply delegated to the plugin's overloading (if at all). No magic autogeneration is to be performed.

package Object::Meta::Plugin::Host::Context::TiedSelf;
use base 'Object::Meta::Plugin::Host::Context';

#use base 'Tie::Array'; # don't bother wasting the time. tie for arrays is thought to be stable. We'll be overriding anyway for efficiency reasons.

sub TIEARRAY { bless $_[1], $_[0] };
sub FETCH { $_[0]->plugin->[$_[1]] };
sub STORE { $_[0]->plugin->[$_[1]] = $_[2] };
sub FETCHSIZE { scalar @{$_[0]->plugin} };
sub STORESIZE { $#{$_[0]->plugin} = $_[1]-1 };
sub EXTEND { $#{$_[0]->plugin} += $_[1] };
sub EXSISTS { exists $_[0]->plugin->[$_[1]] };
sub DELETE { delete $_[0]->plugin->[$_[1]] };
sub CLEAR { @{$_[0]->plugin} = () };
sub PUSH { push @{$_[0]->plugin}, $_[1] };
sub POP { pop @{$_[0]->plugin} };
sub SHIFT { shift @{$_[0]->plugin} };
sub UNSHIFT { unshift @{$_[0]->plugin}, $_[1] };
sub SPLICE { @{$_[0]->plugin}, @_}

package Object::Meta::Plugin::Host::Context::Offset; # used to implement next and previous.

use strict;
use warnings;
use autouse Carp => qw(croak);

our $AUTOLOAD;

sub new {
	my $pkg = shift;
	
	my $self = bless {
		host => shift,
		plugin => shift,
		offset => shift,
		instance => shift || 0,
	}, $pkg;

	$self;
}

{
	my $lookup = sub { # a lexical sub, if you will
		my $self = shift;
		my $method = shift;
	
		my $stack = $self->{host}->stack($method) || croak "Can't locate object method \"$method\" via any plugin in ${ $self }{host}";
		
		my %counts;
	
		my $i;
		my $j = $self->{instance};
		
		for ($i = $#$stack; $i >= 0 or croak "${$self}{plugin} which requested an offset is not in the stack for the method \"$method\" which it called"; $i--){
			${ $stack }[$i] == $self->{plugin} and (-1 == --$j) and last;
			$counts{ ${ $stack }[$i] }++ if wantarray;
		}
		
		my $x = $i;
		$i += $self->{offset};
		
		croak "The offset is outside the bounds of the method stack for \"$method\"\n" if ($i > $#$stack or $i < 0);
		
		return $stack->[$i] unless wantarray;
		
		for (; $x >= $i; $x--){
			$counts{ ${ $stack }[$x] }++;
		}
		
		return ($stack->[$i], $counts{ $stack->[$i] } - 1);
		
		Object::Meta::Plugin::Host::Context->new($self->{host}, ${ $stack }[$i], $counts{${ $stack }[$i]} -1  )->$method(@_);
	};
	
	sub can { # it has to be less ugly than this
		my $self = shift;
		my $method = shift;
	
		return $self->$lookup($method)->can($method);
	}
	sub AUTOLOAD { # it has to be less ugly than this
		my $self = shift;
		$AUTOLOAD =~ /([^:]*?)$/;
		my $method = $1;
		return undef if $method eq 'DESTROY';
		
		Object::Meta::Plugin::Host::Context->new($self->{host}, $self->$lookup($method) )->$method(@_);
	}
}

1; # Keep your mother happy.

__END__

=pod

=head1 NAME

Object::Meta::Plugin::Host - Hosts plugins that work like Object::Meta::Plugin (Or rather Object::Meta::Plugin::Useful, because the prior doesn't work per se). Can be a plugin if subclassed, or contains a plugin which can help it to plug.

=head1 SYNOPSIS

	# if you want working examples, read basic.t in the distribution
	# i don't know what kind of a synopsis would be useful for this.

	my $host = new Object::Meta::Plugin::Host;

	eval { $host->method() }; # should die

	$host->plug($plugin); # $plugin defines method
	$host->plug($another); # $another defines method and another

	# $another supplied the following, since it was plugged in later
	$host->method();
	$host->another($argument);

	$host->unplug($another);

	$host->method(); # now $plugin's method is used

=head1 DESCRIPTION

Object::Meta::Plugin::Host is an implementation of a plugin host, as illustrated in L<Object::Meta::Plugin>.

The host is not just simply a merged namespace. It is designed to allow various plugins to provide similar capabilities - methods with conflicting namespace. Conflicting namespaces can coexist, and take precedence over, as well as access one another. An example scenario could be an image processor, whose various filter plugins all define the method "process". The plugins are all installed, ordered as the effect should be taken out, and finally atop them all a plugin which wraps them into a pipeline is set. It's process method will look like

	sub process {
		my $self = shift;
		my $image = shift;
		
		foreach my $plugin (reverse @{ $self->super->stack('process') }){
			next if $plugin == $self->self;
			$image = $self->super->specific($plugin)->process($image);
		}
		
		# for (my $i = 1; $i <= $#{ $self->super->stack('process') }){
		#     $image = $self->offset($i)->process($image);
		# }
		
		return $image;
	}

When a plugin's method is entered it receives, instead of the host object, a context object, particular to itself. The context object allows it access to the host host, the plugin's siblings, and so forth explicitly, while implicitly making one or two changes. The first is that all calls against $_[0], which is the context, are like calls to the host, but have an altered method priority - calls will be mapped to the current plugin's method before the host defaults methods. Moreover, plugin methods which are not installed in the host will also be accessible this way. The second, default but optional implicit change is that all modifications on the reference received in $_[0] are mapped via a tie interface or dereference overloading to the original plugin's data structures.

Such a model enables a dumb/lazy plugin to work quite happily with others, even those which may take it's role.

A more complex plugin, aware that it may not be peerless, could gain access to the host object, to it's original plugin object, could ask for offset method calls, and so forth.

In short, the interface aims to be simple enough to be flexible, trying for the minimum it needs to define in order to be useful, and creating workarounds for the limitations this minimum imposes.

=head1 METHODS

=head2 Host

=over 4

=item methods

Returns a hash ref, to a hash of method names => array refs. The array refs are the stacks, and they can be accessed individually via the C<stack> method.

=item plug PLUGIN [ LIST ]

Takes a plugin, and calls it's C<init> with the supplied arguments. The return value is then fed to C<register>.

=item plugins

Returns a hash ref, to a refhash. The keys are references to the plugins, and the values are export lists.

=item register EXPORTLIST

Takes an export list and integrates it's context into the method tree. The plugin the export list represents will be the topmost.

=item specific PLUGIN

Returns a context object for a specific plugin. Like C<Context>'s C<next>, C<prev>, and C<offset>, only with a plugin instead of an index.

=item stack METHOD

Returns an array ref to a stack of plugins, for the method. The last element is considered the topmost plugin, which is counter intuitive, considering C<offset> works with higher indices being lower precedence.

=item unplug PLUGIN [ PLUGIN ... ]

Takes a reference to a plugin, and sweeps the method tree clean of any of it's occurrences.

=item unregister EXPORTLIST [ EXPORTLIST ... ]

Takes an export list, and unmerges it from the currently active one. If it's empty, calls C<unplug>. If something remains, it cleans out the stacks manually.

This behavior may change, as a plugin which has no active methods might still need be available.

=back

=head2 Context

=over 4

=item self

=item plugin

Grants access to the actual plugin object which was passed via the export list. Use for internal storage space. See C<CONTEXT STYLES (ACCESS TO PLUGIN INTERNALS)>.

=item super

=item host

Grants access to the host object. Use C<$self->super->method> if you want to override the precedence of the current plugin.

=item next

=item prev

=item offset INTEGER

Generates a new context, having to do with a plugin n steps away from this, to a certain direction. C<next> and C<prev> call C<offset> with 1 and -1 respectively. The offset object they return, has an autoloader which will search to see where the current plugin's instance is in the stack of a certain method, and then move a specified offset from that, and use the plugin in that slot.

=back

=head1 CONTEXT OBJECT STYLES (ACCESS TO PLUGIN INTERNALS)

The context shim styles are set by the object returned by the C<info> method of the export list. L<Object::Meta::Plugin::ExportList> will create an info object whose C<style> method will return I<implicit> by default.

You can override the info object by sending a new one to the export list constructor. Using the Useful:: implementations this can be acheived by sending the info object as the first argument to C<init>. C<plug> can do it for you:

	my $i = new Object::Meta::Plugin::ExportList::Info;
	$i->style('explicit');

	$host->plug($plugin,$i);

=head2 Implicit

=over 4

=item implicit

=item force-implicit

=back

This style allows a plugin to pretend it's operating on itself.

The means to alow this are either by using L<overload> or C<tie> magic.

When the context object is overloaded, any operations on it will be performed on the original plugin object. Dereferencing, various operators overloaded in the plugin's implementations, and so forth should all work, because all operators will simply be delegated to the original plugin.

The only case where there is an exception, is if the plugin's structure is an array. Since the context is implemented as an array, the array dereference operator cannot be overloaded, nor can a plugin editing @$self get it's own data. Instead $self is a reference to a tied array. Operations on the tied array will be performed on the plugin's structures indirectly.

The implicit style comes in two flavors: I<implicit> and I<force-implicit>. The prior is the default. The latter will shut up warnings by L<Object::Meta::Plugin::Host> on plug time. See C<DIAGNOSTIC> for when this is desired.

If needed, C<$self->plugin> and C<$self->self> still work just as they do under the C<Explicit> style.

=head2 Explicit

=over 4

=item explicit

=back

Using this style, the plugin will get the actual structure of the context shim, sans magic. If tied/overloaded access is inapplicable, that's the way to go. It's also more efficient under some scenarios.

In order to get access to the plugin structure the plugin must call C<$self->self> or C<$self->plugin>.

The I<explicit> style gives the standard shim structure to the plugin. To gain access to it's structures a plugin will then need to call the method C<self> on the shim, as documented in L<Object::Meta::Plugin::Host>.

I<explicit> is probably much more efficient when dereferencing a lot (L<overload>ing is not that fast, because it involves magic and an extra method call (C<$self->plugin> is simply called implicitly)), but is less programmer friendly. If you have a loop, like

	for (my $i = 0; $i <= $bignumber; $i++){
		$self->{thing} = $i;
	}

under the I<implicit> style, it will be slow, because $self is L<overload>ed every time. You can solve it by using

	$ref = \%$self; # only if implicit is in use, and not on arrays

or by using

	$ref = $self->plugin; # or $self->self

and operating on $ref instead of $self.

The aggregate functions (C<values>, instead of C<each>, for example) will not suffer greatly from operating on C<%$self>.

As described in C<Implicit>, arrays structures will benefit from I<explicit> much more, because all operations on their contents is totally indirect.

C'est tout.

=head1 DIAGNOSIS

=head2 Errors

An error is emitted when the module doesn't know how to cope with a situation.

=over 4

=item The offset is outside the bounds of the method stack for "%s"

The offset requested (via the methods C<next>, C<prev> or C<offset>) is outside of the the stack of plugins for that method. That is, no plugin could be found that offset away from the current plugin.

Emitted at call time.

=item Can't locate object method "%s" via any plugin in %s

The method requested could not be found in any of the plugged in plugins. Instead of a classname, however, this error will report the host object's value.

Emitted at call time.

=item Method "%s" is reserved for use by the context object

The host C<AUTOLOAD>er was queried for a method defined in the context class. This is not a good thing, because it can cause unexpected behavior.

Emitted at C<plug> or call time.

=item %s doesn't look like a plugin

The provided object's method C<can> did not return a true value for C<init>. This is what we define as a plugin for clarity.

Emitted at C<plug> time.

=item %s doesn't look like a valid export list

The export list handed to the C<register> method did not define all the necessary methods, as documented in L<Object::Meta::Plugin::ExportList>.

Emitted at C<register> time.

=item Can't locate object method "%s" via plugin %s

The method, requested for export by the export list, cannot be found via C<can> within the plugin.

Emitted at C<register> time.

=item %s is not plugged into %s

When requesting a specific plugin to be used, and the plugin doesn't exist this happens.

Emitted at C<specific> time.

=item Unknown plugin style "%s" for %s

When a plugin's C<init> method returns an object, whose C<info> method returns an object, whose C<style> method returns an unknown style, this is what happens.

Emitted at C<plug> time.

=back

=head2 Warnings

A warning is emitted when the internal functionality is expected to work, but the implications on external data (plugins) might be undesired from the programmer's standpoint.

=over 4

=item You shouldn't use implicit access context shims if the underlying plugin's structure is already tied

If a plugin whose structure is a tied array is plugged, it must be wrapped in a tied array, so that a shim can be generated for it.

If the plugin is using it's structures in ways which extend beyond the array variable interface, that is anything having to do with C<tied>, things will probably break.

Emitted at C<plug> time.

=item Overloading a plugin's @{} operator will create unexpected behavior under the implicit style

When a plugin plugged with the I<implicit> style has the C<@{}> operator overloaded, this will cause funny things. If it attempts to dereference itself as an array the array will be the structure of the shim instead of what it was hoping for.

Emitted at C<plug> time.

=back

=head1 CAVEATS

=over 4

=item *

The implementation is by no means optimized. I doubt it's fast, but I don't really care. It's supposed to create a nice framework for a complex application. It's more efficient programming, not execution. This may be worked on a bit.

=item *

The C<can> method (e.g. C<UNIVERSAL::can>) is depended on. Without it everything will break. If you try to plug something nonstandard into a host, and export something C<UNIVERSAL::can> won't say is there, implement C<can> yourself.

=item *

Constructing a plugin with a C<tie>d array as it's data structure, and using C<tied> somewhere in the plugin will break. This is because when the plugin is an array ref, C<tie>ing is used to give the context shim storage space, while allowing implicit access to the plugin's data structure via the shim's data structure.

If you do not explicitly ask for the I<tied> style when plugging the plugin into the host, you will get a warning.

=item *

Using L<Scalar::Util>'s C<reftype> on the context object will always return I<ARRAY>, even if the plugin is not an array, and pretends the shim is not an array.

=back

=head1 BUGS

=over 4

=item *

The C<can> method for the host implementation cannot return the code reference to the real subroutine which will eventually be called. This breaks hosts-as-plugins, because the plugged in host will have it's AUTOLOAD skipped.

Using C<goto> on the reference C<can> returns will work, however.

=back

=head1 TODO

=over 4

=item *

Offset contexting AUTOLOADER needs to diet.

=back

=head1 COPYRIGHT & LICENSE

	Copyright 2003 Yuval Kogman. All rights reserved.
	This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 SEE ALSO

L<Class::Classless>, L<Class::Prototyped>, L<Class::SelfMethods>, L<Class::Object>, and possibly L<Pipeline> & L<Class::Dynamic>.

=cut
