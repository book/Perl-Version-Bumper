BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use Test2::V0;
use Perl::Version::Bumper;
use Path::Tiny;

my $features = Perl::Version::Bumper->feature_data;

# find all test files
my @test_types = qw( bump bump_safely );
my %test_file;
$test_file{$_} = {
    map $_->basename('.data') =~ /\A[1-9][0-9]{2}_([a-z_]+)\z/g
    ? ( $1 => $_ )
    : (),
    path( t => $_ )->children
  }
  for @test_types;

# check there is one set of test data per feature
for my $feature ( sort keys %$features ) {
    ok( exists $test_file{$_}{$feature}, "$_ test file for $feature" )
      for @test_types;
}

done_testing;
