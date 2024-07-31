use Test2::V0;
use feature ();

use Perl::Version::Bumper;

my $this_minor = $^V->{version}[1];    # this Perl's minor version
$this_minor-- if $this_minor % 2;      # rounded down to the latest stable

# check the default version
is( Perl::Version::Bumper->new->version,
    "v5.$this_minor", "default version is v5.$this_minor" );

# check we know about all features in this perl
my %feature = %{ Perl::Version::Bumper::__build_feature() };
ok( exists $feature{$_}, "Perl::Version::Bumper knows about $_" )
  for sort keys %feature::feature;

done_testing;
