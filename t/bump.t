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
        my $this    = qq{"$name" [$version]};
        $expected =~ s/use v5\.XX;/use $version;/g;

        # bump_ppi
        my $doc = PPI::Document->new( \$src );
        is( $doc, D, "'$name' parsed by PPI" );
        is( $perv->bump_ppi($doc)->serialize, $expected, "$this ->bump_ppi" );

        # bump
        is( $perv->bump($src), $expected, "$this ->bump" );

        # bump_file
        my $file = Path::Tiny->tempfile;
        $file->spew($src);
        my $ran = $perv->bump_file($file);
        if ( $src eq $expected ) { is( $ran, U, "$this ->bump_file (same)" ); }
        else                     { is( $ran, D, "$this ->bump_file (mod')" ); }
        is( $file->slurp, $expected, "$this ->bump_file (expected update)" );
    },
);

done_testing;
