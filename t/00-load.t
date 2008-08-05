#!/usr/bin/env perl

use Test::More tests => 4;

BEGIN {
    use_ok('Carp');
    use_ok('DBI');
    use_ok('App::ZofCMS');
	use_ok( 'App::ZofCMS::Plugin::DBI' );
}

diag( "Testing App::ZofCMS::Plugin::DBI $App::ZofCMS::Plugin::DBI::VERSION, Perl $], $^X" );
