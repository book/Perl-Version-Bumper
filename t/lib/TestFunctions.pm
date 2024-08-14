use Test2::V0;
use Path::Tiny;
use Perl::Version::Bumper;

sub test_dir {
    my %args = @_;
    my $dir  = path(__FILE__)->parent->parent->child( $args{dir} );
    test_file( %args, file => $_ ) for sort $dir->children(qr/\.data\z/);
}

sub test_file {
    my %args    = @_;
    my $file    = $args{file};
    my $stop_at = $args{stop_at} + 2;

    # blocks of test data are separated by ##########
    my @tests = split /^########## (.*)\n/m, path($file)->slurp;
    return diag("$file is empty") unless @tests;

    shift @tests;    # drop the test preamble

    my $todo;        # not a TODO by default
    my $minor = 10;  # always start at v5.10

    subtest $file => sub {

        while ( my ( $name, $data ) = splice @tests, 0, 2 ) {

            # sections starting at a given version number up to the next one
            # are separated by --- (the version is optional in the first one)
            my ( $src, @expected ) = split /^---(.*)\n/m, $data, -1;
            $expected[0] =~ s/\A *//d if @expected;    # trim

            # assume no change up to the first version
            my $expected = $src //= '';

            # this is when we'll update our expectations
            my $next_minor = version->parse(
                (
                    split / /, defined $expected[0]
                    ? $expected[0]
                      || 'v5.10'   # bare --- (no version, default to v5.10)
                    : ''           # no "expected" section (the empty case)
                )[0]
            )->{version}[1] // $stop_at;

            my $todo;          # not a todo test by default
            my $minor = 10;    # always start at v5.10
            while ( $minor < $stop_at ) {
                if ( $minor >= $next_minor ) {
                    ( my $version_todo, $expected ) = splice @expected, 0, 2;
                    ( undef, $todo ) = split / /, $version_todo, 2;
                    $expected[0] =~ s/\A *//d if @expected;    # trim
                    $next_minor = @expected
                      ? version->parse( ( split / /, $expected[0] )[0] )->{version}[1]
                      : $stop_at;
                }
                $todo &&= todo $todo;

                $args{callback}->(
                    Perl::Version::Bumper->new( version => "v5.$minor" ),
                    $src, $expected, $name
                );
            }

            # bump to  the next stable
            continue { $minor += 2 }

        }
    }
}

1;
