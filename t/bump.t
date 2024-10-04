use v5.10;
use Test2::V0;
use Path::Tiny;
use Perl::Version::Bumper;

# t/lib
use lib path(__FILE__)->parent->child('lib')->stringify;
use TestFunctions;

# latest stable supported by the module
my $stop_at = ( split /\./, Perl::Version::Bumper->feature_version )[1];

test_dir(
    dir      => 'bump',
    stop_at  => $stop_at,
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
