#!/usr/bin/perl

use strict;
use warnings;

use Module::Build;

our $VERSION = 0.02;

Module::Build->new(
	module_name => 'Object::Meta::Plugin',
	license => 'perl',						# gpl & al
	requires => {
		'perl'				=> '>= 5.8.0',	# needed for Scalar::Util
		'Tie::RefHash'		=> '>= 1.3',	# perl 5.8.0 core
		'Carp'				=> '>= 1.01',	# perl 5.8.0 core
		'Scalar::Util'		=> 0,			# perl 5.8.0 core, unversioned
		'autouse'			=> '>= 1.03',	# perl 5.8.0 core
	},
	recommends => {
		# for Object::Meta::Plugin::Useful::Greedy
		'Devel::Symdump'	=> '>= 2.03',	# only one I see on cpan is 2.03
		'Class::ISA'		=> '>= 0.32',	# only one I see on cpan is 0.32, perl 5.8.0 core
	},
	create_makefile_pl => "traditional",	# for the sake of people without Module::Build
	sign => 1,								# we like Module::Signature
)->create_build_script;
