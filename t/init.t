use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 1;

use GRNOC::RouterProxy;

my $routerProxy = GRNOC::RouterProxy->new();

ok( defined( $routerProxy ), "RouterProxy object instantiated" );

# no point in continuing other tests if we cant create object
BAIL_OUT( "unable to create RouterProxy object" ) if ( !defined( $routerProxy ) );

