#!/usr/bin/perl
# $Id: Host.pm,v 1.18 2003/12/07 10:23:30 nothingmuch Exp $

package Object::Meta::Plugin::Host;

use strict;
use warnings;

use autouse Carp => qw(croak);
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
	
	if ($x->info->style() eq 'tied'){
	
		croak "You shouldn't use implicit access context shims if the underlying plugin's structure is already tied" if do { local $@;
				eval { tied (%{$plugin}) }
			||	eval { tied (@{$plugin}) }
			||	eval { tied (${$plugin}) } };
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
		
		if ($x->list()){
			foreach my $method ($x->list()){
				next unless $self->stack($method);
				
				@{ $self->stack($method) } = grep { $_ != $x->plugin } @{ $self->stack($method) };
				
				delete $self->methods->{$method} unless (@{ $self->stack($method) });
			}
		} else {
			$self->unplug($x->plugin()); # $$$ should this happen? If a plugin loses all it's registry, is it no longer plugged in? fuss over this one to great lengths.
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
	return $self->UNIVERSAL::can($method) || ($self->stack($method) && sub { $AUTOLOAD = "::" . $method; goto &AUTOLOAD }) || undef;
}

sub AUTOLOAD { # where the magic happens
	my $self = shift;
	
	$AUTOLOAD =~ /.*::(.*?)$/;
	my $method = $1;
	croak "Method \"$method\" is reserved for use by the context object" if Object::Meta::Plugin::Host::Context->UNIVERSAL::can($method); # UNIVERSAL can differs
	
	return undef if $method eq 'DESTROY';
	my $stack = $self->stack($method) or croak "Can't locate object method \"$method\" via any plugin in $self";
	Object::Meta::Plugin::Host::Context->new($self, ${ $stack }[ $#$stack ])->$method(@_);
}

package Object::Meta::Plugin::Host::Context; # the wrapper object which defines the context of a plugin

use strict;
use warnings;

use autouse 'Scalar::Util' => qw(reftype);
use autouse Carp => qw(croak);

our $VERSION = 0.01;
our $AUTOLOAD;

sub new {
	my $pkg = shift;
	
	my $self = bless {
		host => shift,
		plugin => shift,
		instance => shift || 0, # a plugin can be plugged into several slots, each of which needs it's own context
	}, $pkg;
	
	my $style = $self->{host}->plugins->{$self->{plugin}}->info->style();

	return $self if $style eq 'explicit';
	croak "Unknown plugin style \"$style\" for ${ $self }{plugin}" unless $style eq 'tied' or $style eq 'force-tied';

	SWITCH: { # neater when there's lots to do
		reftype($self->{plugin}) eq 'HASH' and do {
			my %hash;
			tie %hash, __PACKAGE__."::TiedSelf::HASH", $self;
			$self = \%hash;
		}, last SWITCH;
		reftype($self->{plugin}) eq 'ARRAY' and do {
			my @array;
			tie @array, __PACKAGE__."::TiedSelf::ARRAY", $self;
			$self = \@array;
		}, last SWITCH;
		reftype($self->{plugin}) eq 'SCALAR' and do {
			my $scalar;
			tie $scalar, __PACKAGE__."::TiedSelf::SCALAR", $self;
			$self = \$scalar;
		}, last SWITCH;
		
		croak "Can only support HASH, ARRAY and SCALR ref types for context tie bridge (${ $self }{plugin}).";
		
	};
	
	bless $self, $pkg;
	return $self;
}

sub real { # obtain the value behind the tie, if it's there
	my $self = shift;
	
	local $@;
	
	if (reftype($self) ne 'HASH'){ # the natural type for the object
		return	eval { tied (@{$self}) }
			||	eval { tied (${$self}) }
			|| $self;
	} else {
		return tied %{$self} || $self;
	}
}

### these methods nead C<real> because they access internals

sub instance {
	my $self = shift->real();
	$self->{instance};	
}

sub super { # the real self: Object::Meta::Plugin::Host
	my $self = shift->real();
	$self->{host};
}
sub host { goto &super }

sub plugin {
	my $self = shift->real();
	$self->{plugin};
}
sub self { goto &plugin }

### methods from here on don't access internals and don't need C<real>

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
	
	$AUTOLOAD =~ /.*::(.*?)$/;
	my $method = $1;
	return undef if $method eq 'DESTROY';
	
#	print "$self, ", $self->plugin;
	
	if (my $code = $self->plugin->can($method)){ # examine the plugin's export list in the host
		### stray from magic - this is as worse as it should get
		unshift @_, $self; # return self to the argument list. Should be O(1). lets hope.
		goto &$code;
	} else {
#		print $self->plugin, " can't $method";
#		Carp::cluck("exists");
		$self->host->$method(@_);
	}
}

package Object::Meta::Plugin::Host::Context::TiedSelf::SCALAR;
use base 'Object::Meta::Plugin::Host::Context';

sub TIESCALAR { bless $_[1], $_[0] }
sub FETCH { ${$_[0]{plugin}} };
sub STORE { ${$_[0]{plugin}} = $_[1] };

package Object::Meta::Plugin::Host::Context::TiedSelf::ARRAY;
use base 'Object::Meta::Plugin::Host::Context';

sub TIEARRAY { bless $_[1], $_[0] };
sub FETCH { $_[0]{plugin}[$_[1]] };
sub STORE { $_[0]{plugin}->[$_[1]] = $_[2] };
sub FETCHSIZE { scalar @{$_[0]{plugin}} };
sub STORESIZE { $#{$_[0]{plugin}} = $_[1]-1 };
sub EXTEND { $#{$_[0]{plugin}} += $_[1] };
sub EXSISTS { exists $_[0]{plugin}->[$_[1]] };
sub DELETE { delete $_[0]{plugin}->[$_[1]] };
sub CLEAR { @{$_[0]{plugin}} = () };
sub PUSH { push @{$_[0]{plugin}}, $_[1] };
sub POP { pop @{$_[0]{plugin}} };
sub SHIFT { shift @{$_[0]{plugin}} };
sub UNSHIFT { unshift @{$_[0]{plugin}}, $_[1] };
sub SPLICE { @{$_[0]{plugin}}, @_}

package Object::Meta::Plugin::Host::Context::TiedSelf::HASH;
use base 'Object::Meta::Plugin::Host::Context';

sub TIEHASH { bless $_[1], $_[0] };
sub FETCH { $_[0]{plugin}->{$_[1]} };
sub STORE { $_[0]{plugin}->{$_[1]} = $_[2] };
sub DELETE { delete $_[0]{plugin}->{$_[1]} };
sub EXISTS { exists $_[0]{plugin}->{$_[1]} };
sub CLEAR { %{$_[0]{plugin}} = () };
sub FIRSTKEY { keys %{$_[0]{plugin}}; each %{$_[0]{plugin}} };
sub NEXTKEY { each %{$_[0]{plugin}} };

# no filehandle yet. tie is quite dirty for it ((sys)funct - no diff.)

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

# $$$ should there be a next and prev method? is $self->next->next() a valid thing to do? It's kind of silly, because $self->offset(-2) acheives the same effect.

sub can { $AUTOLOAD = ref $_[0] . "::can"; goto &AUTOLOAD; }; # $$$ not yet tested. I'm pretty sure AUTOLOAD will not be hit before UNIVERSAL::can is found. It doesn't rally matter if that's not the case.
sub AUTOLOAD { # it has to be less ugly than this
	my $self = shift;
	$AUTOLOAD =~ /.*::(.*?)$/;
	my $method = $1;
	return undef if $method eq 'DESTROY';

	my $stack = $self->{host}->stack($method) || croak "Can't locate object method \"$method\" via any plugin in ${ $self }{host}";
	
	my %counts;

	my $i;
	my $j = $self->{instance};
	
	for ($i = $#$stack; $i >= 0 or croak "${$self}{plugin} which requested an offset is not in the stack for the method \"$method\" which it called"; $i--){
		${ $stack }[$i] == $self->{plugin} and (-1 == --$j) and last;
		$counts{ ${ $stack }[$i] }++;
	}
	
	my $x = $i;
	$i += $self->{offset};
	for (; $x >= $i; $x--){
		$counts{ ${ $stack }[$x] }++;
	}

	croak "The offset is outside the bounds of the method stack for \"$method\"\n" if ($i > $#$stack or $i < 0);
	
	Object::Meta::Plugin::Host::Context->new($self->{host}, ${ $stack }[$i], $counts{${ $stack }[$i]} -1  )->$method(@_);
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

The host is not just simply a merged namespace. It is designed to allow various plugins to provide similar capabilities - methods with conflicting namespace. Conflicting namespaces can coexist, and take precedence over, as well as access one another. An examplifying scenario could be an image processor, whose various filter plugins all define the method "process". The plugins are all installed, ordered as the effect should be taken out, and finally atop them all a plugin which wraps them into a pipeline is set. It's process method will look like

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

When a plugin's method is entered it receives, instead of the host object, a context object, particular to itself. The context object allows it access to the host host, the plugin's siblings, and so forth explicitly, while implicitly providing one or two modifications. The first is that all calls against $_[0], which is the context, have an altered method priority - calls will be mapped to the current plugin's method before the host defaults methods. The second, default but optional implicit feature is that all modifications on the reference received in $_[0] are mapped via a tie interface to the original plugin's data structures.

Such a model enables a dumb plugin to work quite happily with others, even those which may take it's role.

A more complex plugin, aware that it may not be peerless, could explicitly ask for the default (host defined) methods it calls, instead of it's own. It can request to call a method on the plugin which succeeds it or precedes it in a certain method's stack.

The interface aims to be simple enough to be flexible, trying for the minimum it needs to define in order to be useful, and creating workarounds for the limitations this minimum imposes.

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

Returns an array ref to a stack of plugins, for the method. The last element is considered the topmost plugin, which is counter intuitive, considering C<offset> works with higher indices being lower perceedence.

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

=head1 CONTEXT STYLES (ACCESS TO PLUGIN INTERNALS)

The context shim styles are set by the object returned by the C<info> method of the export list. L<Object::Meta::Plugin::ExportList> will create an info object which will have the C<style> method return I<tied> by default.

=head2 Implicit access via tie

This way the shim object will be a tied reference, of the type the original plugin's data structure (if it is a hash, array or scalar). The tie will interface to the contents of the original plugin object.

In this way the plugin object can gain access to it's internals normally, but the methods it calls will be called on the context shim. The context data will be stored in the object behind the tie, and be access via a called to C<tie>.

This way implicit and complete namespace (context shim & plugin) separation can be made, without the plugin needing to do any tricks. The downsides is that the plugin can't be a blessed glob or code ref, or if the plugin does not behave well regarding blessing and stuff.

If the plugin is funny tied structure, you have to set the style to 'force-tied', in order for C<plug> not to die. Do this by sending an export list info object as the first argument to a Useful C<init>. But make sure you're not breaking anything.

=head2 Explicit access via $self->self

This method is theoretically much more efficient.

In this style, the plugin will get the actual structure of the context shim. If tied access is in applicable, that's the way to go.

In order to get access to the plugin structure the plugin must call C<$self->self> or C<$self->plugin>.

C'est tout.

=head1 DIAGNOSIS

All errors are errors (e.g not warnings), and are thus fatal, and are produced with L<Carp>'s C<croak>. They can be trapped with C<eval> if necessary.

=over 4

=item The offset is outside the bounds of the method stack for "%s"

The offset requested (via the methods C<next>, C<prev> or C<offset>) is outside of the the stack of plugins for that method. That is, no plugin could be found that offset away from the current plugin.

Generated at call time.

=item Can't locate object method "%s" via any plugin in %s

The method requested could not be found in any of the plugged in plugins. Instead of a classname, however, this error will report the host object's value.

Generated at call time.

=item Method "%s" is reserved for use by the context object

The host C<AUTOLOAD>er was queried for a method defined in the context class. This is not a good thing, because it can cause unexpected behavior.

Generated at C<plug> or call time.

=item %s doesn't look like a plugin

The provided object's method C<can> did not return a true value for C<init>. This is what we define as a plugin for clarity.

Generated at C<plug> time.

=item %s doesn't look like a valid export list

The export list handed to the C<register> method did not define all the necessary methods, as documented in L<Object::Meta::Plugin::ExportList>.

Generated at C<register> time.

=item Can't locate object method "%s" via plugin %s

The method, requested for export by the export list, cannot be found via C<can> within the plugin.

Generated at C<register> time.

=item %s is not plugged into %s

When requesting a specific plugin to be used, and the plugin doesn't exist this happens.

Generated at C<specific> time.

=back

=head1 CAVEATS

=over 4

=item *

The implementation is by no means optimized. I doubt it's fast, but I don't really care. It's supposed to create a nice framework for a complex application. It's more efficient programming, not execution. This may be worked on a bit.

=item *

The C<can> method (e.g. C<UNIVERSAL::can>) is depended on. Without it everything will break. If you try to plug something nonstandard into a host, and export something C<UNIVERSAL::can> won't say is there, implement C<can> yourself.

=back

=head1 BUGS

Just you wait. See C<TODO> for what I have in stock!

=head1 TODO

=over 4

=item *

Decide if C<unregister> should or shouldn't call C<unplug> if nothing of the plugin remains by the 0.02 release. Currently leaning towards "no".

=item *

Offset contexting AUTOLOADER needs to diet.

=item *

Since 5.8 is a prerequisite, use L<Scalar::Util> to cleanup references which shouldn't be strong.

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
