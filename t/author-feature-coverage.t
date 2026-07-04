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

# find all test data files
my @test_types = qw( bump bump_safely );
my %test_file;
$test_file{$_} = {
    map $_->basename =~ /\A1[0-9]{2}_([a-z_]+)\.data\z/g
    ? ( $1 => $_ )
    : (),
    path( t => $_ )->children(qr/\.data\z/)
  }
  for @test_types;

# check there is one set of test data per feature
# bump
for my $feature ( sort keys %$features ) {
    ok( exists $test_file{bump}{$feature}, "bump test file for $feature" )
}

# bump_safely
for my $feature ( sort keys %$features ) {
    my $todo = todo "bump_safely not fully covered yet";
    ok( exists $test_file{bump_safely}{$feature}, "bump_safely test file for $feature" )
}

done_testing;
