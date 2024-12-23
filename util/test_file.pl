#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use Getopt::Long;
use Test2::V0;

use lib 'lib', 't/lib';
use TestFunctions;

my %options = (
    callback   => 'bump',
    start_from => '5.010',
    stop_at    => Perl::Version::Bumper->feature_version,
);

GetOptions(
    \%options,
    'callback|cb=s',                    # name of the test callback
    'start_from|start-from|start=s',    # version to start the test from
    'stop_at|stop-at|stop=s',           # version to stop the test at
) or die;

test_file( %options, file => $_ ) for @ARGV;

done_testing;
