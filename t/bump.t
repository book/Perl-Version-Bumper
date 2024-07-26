use Test2::V0;
use Perl::Version::Bumper;
use Path::Tiny;

my @tests = split /^########## (.*)\n/m,
  path( __FILE__ =~ s/\.t\z/.data/r )->slurp;
shift @tests;    # drop the test preamble

while ( my ( $name, $data ) = splice @tests, 0, 2 ) {
    my ( $src, %expected ) = split /^--- (.*)\n/m, $data, -1;
    for my $target ( sort keys %expected ) {
        my ( $version, $todo ) = split / /, $target, 2;
      SKIP: {
            $todo &&= todo $todo;
            my $perv =
              eval { Perl::Version::Bumper->new( version => $version ); };
            skip "This is Perl $^V, not $version" unless $perv;
            is(
                $perv->bump($src),
                $expected{$target} // '',
                "$name [$version]"
            );
        }
    }
}

done_testing;
