package Slim::Plugin::MyApps::Plugin;

# $Id$

use strict;
use base qw(Slim::Plugin::OPMLBased);

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(
		feed   => Slim::Networking::SqueezeNetwork->url( '/api/myapps/v1/opml' ),
		tag    => 'myapps',
		node   => 'home',
		weight => 90,
	);
}

1;
