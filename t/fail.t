use Test2::V0;

use Perl::Version::Bumper;

my $this_minor = $^V->{version}[1];    # this Perl's minor version
$this_minor-- if $this_minor % 2;      # rounded down to the latest stable

# constructor errors
my @errors = (
    [ '6.0.1' => qr{\AMajor version number must be 5, not 6 } ],
    [ 'v4.2'  => qr{\AMajor version number must be 5, not 4 } ],
    [ 'v5.15' => qr{\AMinor version number must be even, not 15 } ],
    [
      'v5.25' => $this_minor >= 25
        ? qr{\AMinor version number must be even, not 25 }
        : qr{Minor version number 25 > $this_minor }
    ],
    [ '5.28'   => qr{\AMinor version number 280 > $this_minor } ],
    [ 'v5.100' => qr{\AMinor version number 100 > $this_minor } ],
    [ 'v5.8'   => qr{\AMinor version number 8 < 10 } ],
    [ 'not'    => qr{\AInvalid version format \(non-numeric data\)} ],
);

for my $e (@errors) {
    my ( $version, $error ) = @$e;
    ok( !eval { Perl::Version::Bumper->new( version => $version ) },
        "failed to create object with version => $version" );
    like( $@, $error, ".. expected error message" );
}

# version normalisation
my %version = qw(
  v5.10.1     v5.10
  5.012002    v5.12
  5.014       v5.14
  v5.16       v5.16
  v5.26       v5.26
  5.028       v5.28
  5.030002    v5.30
  v5.32.1     v5.32
);

version->parse( $version{$_} )->{version}[1] <= $this_minor
  ? is( Perl::Version::Bumper->new( version => $_ )->version,
    $version{$_}, "$_ => $version{$_}" )
  : do {
  SKIP: {
        skip( skip "This is Perl $^V, not $_", 1 );
    }
  }
  for sort keys %version;

done_testing;
