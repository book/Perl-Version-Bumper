use v5.10;
use strict;
use warnings;
use Test2::V0;
use Path::Tiny;
use Perl::Version::Bumper;

# t/lib
use lib path(__FILE__)->parent->child('lib')->stringify;
use TestFunctions;


test_dir(
    dir      => 'bump',
    stop_at  => Perl::Version::Bumper->feature_version,
    callback => sub {
        my ( $perv, $src, $expected, $name ) = @_;
        my $version = $perv->version;
        $expected =~ s/use v5\.XX;/use $version;/g;
        is(
            $perv->bump($src),
            $expected,
            "$name [$version]"
        );
    },
);

done_testing;
