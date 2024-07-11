use Test2::V0;

use Perl::Version::Bumper;

# this Perl's minor version
my $this_minor = $^V->{version}[1];

# constructor errors
my @errors = (
    [ '6.0.1'  => qr{\AMajor version number must be 5, not 6 } ],
    [ 'v4.2'   => qr{\AMajor version number must be 5, not 4 } ],
    [ 'v5.25'  => qr{\AMinor version number must be even, not 25 } ],
    [ '5.28'   => qr{\AMinor version number 280 > $this_minor } ],
    [ 'v5.100' => qr{\AMinor version number 100 > $this_minor } ],
    [ 'v5.8'   => qr{\AMinor version number 8 < 10 } ],
);

for my $e (@errors) {
    my ( $version, $error ) = @$e;
    ok( !eval { Perl::Version::Bumper->new( version => $version ) },
        "failed to create object with version => $version" );
    like( $@, $error, ".. expected error message" );
}

# version normalisation
my %version = qw(
  v5.26       v5.26
  5.028       v5.28
  5.030002    v5.30
  v5.32.1     v5.32
);

is( Perl::Version::Bumper->new( version => $_ )->version,
    $version{$_}, "$_ => $version{$_}" )
  for sort keys %version;

done_testing;
