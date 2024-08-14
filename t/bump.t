use v5.10;
use Test2::V0;
use Path::Tiny;
use Perl::Version::Bumper;

# t/lib
use lib path(__FILE__)->parent->child('lib')->stringify;
use TestFunctions;

# latest stable supported by the module
my $stop_at = ( split /\./, Perl::Version::Bumper->feature_version )[1];

test_dir(
    dir      => 'bump',
    stop_at  => $stop_at,
    callback => sub {
        my ( $perv, $src, $expected, $name ) = @_;
        my $version = $perv->version;
        is(
            $perv->bump($src),
            $expected =~ s/use v5\.XX;/use $version;/gr,
            "$name [$version]"
        );
    },
);

done_testing;

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
