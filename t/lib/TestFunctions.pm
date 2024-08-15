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

__END__

This section describes the test data format.

Each test in a section marked with '##########', followed by a short
description of the test. It will be shown as part of the test message.

The individual test data is itself separated in multiple sub-sections,
marked by '---' followed by a Perl version number and an optional TODO
message. The first sub-section is the source code to bump, and each
following sub-section is the expected result for the given test.

The test is basically looping over stable Perl versions starting at v5.10
up to the latest version supported by Perl::Version::Bumper. (The module
can bump code to a version later than the perl running it.)

This is easier to describe with an example:

    ########## <test description>
    <input code>
    --- <version 1>
    <expected result 1>
    --- <version 2> <todo text>
    <expected result 2>
    --- <version 3>
    <expected result 3>

The <test description> will be used to produce the individual test
message, concatenated with the version the <input code> is being
bumped to.

From v5.10 up to <version 1>, the test expects the result to be equal
to <input code> (for example if the input code contains a `use v5.16;`
line, trying to update it to a lower version will not do anything).

From <version 1> up to <version 2> (not included), the test expects the
result to be equal to <expected result 1>.

From <version 2> up to <version 3> (not included), the test expects the
result to be equal to <expected result 1>. Since there's a <todo text>,
any failure will be marked as TODO.

From <version 3> up to the version of the running perl (included),
the test expects the result to be equal to <expected result 3>.

Tests stop as soon as the version of the running perl is reached,
meaning that running the tests with an older perl might not test all
possible cases.

IMPORTANT: This implies the version numbers must be in increasing order.

To simplify writing the expected results, every "use v5.XX" will have the
"XX" replaced with the minor Perl version being tested.

The first "---" line can be empty, in which case the version is assumed
to be v5.10.
