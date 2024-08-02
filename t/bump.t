use v5.10;
use Test2::V0;
use Path::Tiny;
use Perl::Version::Bumper;

# the version at which to stop (next stable)
my $stop_minor = ( split /\./, Perl::Version::Bumper->feature_version )[1] + 2;

# blocks of test data are separated by ##########
my @tests = split /^########## (.*)\n/m,
  path( __FILE__ =~ s/\.t\z/.data/r )->slurp;
shift @tests;    # drop the test preamble

while ( my ( $name, $data ) = splice @tests, 0, 2 ) {

    # sections starting at a given version number up to the next one
    # are separated by --- (the version is optional in the first one)
    my ( $src, @expected ) = split /^---(.*)\n/m, $data, -1;
    my $expected = $src //= '';    # assume no change up to the first version
    $expected[0] =~ s/\A *//d if @expected;    # trim
    my $next_minor =    # this is when we'll update our expectations
      version->parse(
        (
            split / /, defined $expected[0]
            ? $expected[0] || 'v5.10'  # bare --- (no version, default to v5.10)
            : ''                       # no "expected" section (the empty case)
        )[0]
    )->{version}[1] // $stop_minor;

    my $todo;          # not a TODO by default
    my $minor = 10;    # always start at v5.10
    while ( $minor < $stop_minor ) {
        if ( $minor >= $next_minor ) {
            ( my $version_todo, $expected ) = splice @expected, 0, 2;
            ( undef, $todo ) = split / /, $version_todo, 2;
            $expected[0] =~ s/\A *//d if @expected;    # trim
            $next_minor =
              @expected
              ? version->parse( ( split / /, $expected[0] )[0] )->{version}[1]
              : $stop_minor;
        }
        $todo &&= todo $todo;
        my $perv = Perl::Version::Bumper->new( version => "v5.$minor" );
        is(
            $perv->bump($src),
            $expected =~ s/use v5\.XX;/use v5.$minor;/gr,
            "$name [v5.$minor]"
        );
    }

    # bump to  the next stable
    continue { $minor += 2 }

}

done_testing;
