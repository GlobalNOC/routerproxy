use strict;
use warnings;

use Data::Dumper;
use FindBin;
use Test::More tests => 1;

use GRNOC::RouterProxy;

my $routerProxy = GRNOC::RouterProxy->new(config_path => "$FindBin::Bin/conf/test.conf");

my $original_file_name = "$FindBin::Bin/data/show_bgp_neighbor.txt";
my $redacted_file_name = "$FindBin::Bin/data/show_bgp_neighbor_redacted.txt";

open(my $original_fh, "<", $original_file_name) or die "Cannot open file $original_file_name: $!";
open(my $redacted_fh, "<", $redacted_file_name) or die "Cannot open file $redacted_file_name: $!";

my $original_text = <$original_fh>;
my $redacted_text = <$redacted_fh>;

my $sanitized = $routerProxy->sanitize_text($original_text);

is($sanitized, $redacted_text, "Text properly sanitized");


