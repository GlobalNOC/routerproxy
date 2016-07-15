#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;
use GRNOC::CLI;
use GRNOC::RouterProxy::RouterProxyConfig;


my $xml  = $ARGV[0];
my $yaml = $ARGV[1];

my $conf = RouterProxyConfig->New($xml);
my $ok   = $conf->Save($yaml);
if ($ok != 1) {
    print $ok;
}

