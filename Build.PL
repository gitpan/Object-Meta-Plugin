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
		'Tie::RefHash'		=> 0,			# perl 5.8.0 core, api is expected to be consistent
		'Carp'				=> 0,			# perl 5.8.0 core, api is consistent
		'Scalar::Util'		=> 0,			# perl 5.8.0 core, unversioned
		'autouse'			=> 0,			# perl 5.8.0 core, api is consistent
	},
	recommends => {
		# for Object::Meta::Plugin::Useful::Greedy
		'Devel::Symdump'	=> 0,			# only one I see on cpan is 2.03, api is consistent
		'Class::ISA'		=> 0,			# only one I see on cpan is 0.32, perl 5.8.0 core, api is expected to be consistent
	},
	create_makefile_pl => "traditional",	# for the sake of people without Module::Build
	sign => 1,								# we like Module::Signature
)->create_build_script;
