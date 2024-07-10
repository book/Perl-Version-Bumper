use Test2::V0;

use Perl::Version::Bumper;

# Perl 5.40 was released in 2024
my $latest_minor = 40 + ( (localtime)[5] - 124 ) * 2;

# constructor errors
my @errors = (
    [ '6.0.1'  => qr{\AMajor version number must be 5, not 6 } ],
    [ 'v4.2'   => qr{\AMajor version number must be 5, not 4 } ],
    [ 'v5.39'  => qr{\AMinor version number must be even, not 39 } ],
    [ '5.099'  => qr{\AMinor version number must be even, not 99 } ],
    [ '5.28'   => qr{\AMinor version number 280 > $latest_minor \Q(is the year 2144 already?) \E} ],
    [ 'v5.100' => qr{\AMinor version number 100 > $latest_minor \Q(is the year 2054 already?) \E} ],
);

for my $e (@errors) {
    my ( $version, $error ) = @$e;
    ok( !eval { Perl::Version::Bumper->new( version => $version ) },
        "failed to create object with version => $version" );
    like( $@, $error, ".. expected error message" );
}

done_testing;
