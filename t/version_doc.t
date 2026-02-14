use Test2::V0;
use Perl::Version::Bumper;

my ($current_version) = grep /The current value of C<feature_version> is:/,
  Path::Tiny->new( $INC{'Perl/Version/Bumper.pm'} )->lines;
my $feature_version = Perl::Version::Bumper->feature_version;

is(
    $current_version,
    "The current value of C<feature_version> is: C<$feature_version>.\n",
    'documented feature_version'
);

done_testing;
