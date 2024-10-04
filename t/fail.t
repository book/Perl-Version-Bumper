use v5.10;
use strict;
use warnings;
use Test2::V0;

use Perl::Version::Bumper;

my $max_minor  = ( split /\./, Perl::Version::Bumper->feature_version )[1];
my $this_minor = $^V->{version}[1];    # this Perl's minor version
$this_minor-- if $this_minor % 2;      # rounded down to the latest stable

# constructor errors
my @errors = (
    [ '6.0.1'  => qr{\AMajor version number must be 5, not 6 } ],
    [ 'v4.2'   => qr{\AMajor version number must be 5, not 4 } ],
    [ 'v5.15'  => qr{\AMinor version number must be even, not 15 } ],
    [ 'v5.25'  => qr{\AMinor version number must be even, not 25 } ],
    [ '5.28'   => qr{\AMinor version number 280 > $max_minor } ],
    [ 'v5.100' => qr{\AMinor version number 100 > $max_minor } ],
    [ 'v5.8'   => qr{\AMinor version number 8 < 10 } ],
    [    # returns 0 in v5.10, dies otherwise
        'not' => eval { version->new('not') || 1 }
        ? qr{\AMajor version number must be 5, not 0 }
        : qr{\AInvalid version format \(non-numeric data\)}
    ],
);

# check the default
if ( $this_minor > $max_minor ) {
    push @errors,
      [ '' => qr{\AMinor version number $this_minor > $max_minor } ],;
}
else {
    is( Perl::Version::Bumper->new->version,
        "v5.$this_minor", "default version is v5.$this_minor" );
}

for my $e (@errors) {
    my ( $version, $error ) = @$e;
    ok(
        !eval {
            Perl::Version::Bumper->new(
                $version ? ( version => $version ) : () );
        },
        "failed to create object with version => $version"
    );
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
