use v5.10;
use strict;
use warnings;
use Test2::V0;
use Path::Tiny;
use List::Util qw( min );

# t/lib
use lib path(__FILE__)->parent->child('lib')->stringify;
use TestFunctions;

# latest stable supported by the module
my $stop_minor = ( split /\./, Perl::Version::Bumper->feature_version )[1];

# latest stable supported by the perl binary
my $max_minor = ( split /\./, $^V )[1];
$max_minor -= $max_minor % 2;    # latest stable

test_dir(
    dir      => 'bump_safely',
    stop_at  => min( $stop_minor, $max_minor ),   # stop at the earliest
    callback => sub {
        my ( $perv, $src, $expected, $name ) = @_;
        my $version = $perv->version;
        my $this    = "$name [$version]";

        my $file = Path::Tiny->tempfile;
        $file->spew($src);

        # silence errors
        open( \*OLDERR, '>&', \*STDERR )    or die "Can't dup STDERR: $!";
        open( \*STDERR, '>',  '/dev/null' ) or die "Can't re-open STDERR: $!";

        my $ran = eval { $perv->bump_file_safely($file) }
          or my $error = $@;    # catch (syntax) errors in the eval'ed code

        # get STDERR back, and warn about errors while compiling
        open( \*STDERR, '>&', \*OLDERR ) or die "Can't restore STDERR: $!";

        # throw the errors in the eval, if any
        die $error if $error;

        # perform the version expectations bump
        $expected =~ s/use v5\.XX;/use $version;/g;

        # check the return value:
        # - undef if compilation of the original fail
        # - defined if the original snippet compiled
        if ( $name =~ /DIE(?: *< *v5\.([0-9]+))?/ ) {   # compilation might fail
            if ($1) {                                   # on an older perl binary
                if ( $^V < version::->parse("v5.$1") ) {
                    is( $ran, U, "$this did not compile on $^V" );
                    $expected = $src;    # no change expected
                }
                else { is( $ran, D, "$this compiled on $^V" ); }
            }
            else {    # no minimum version, always expected to fail compilation
                is( $ran, U, "$this did not compile on $^V" );
                $expected = $src;    # no change expected
            }
        }
        else {        # not expected to fail compilatin
            is( $ran, D, "$this compiled on $^V" );
        }

        # check the expected result
        is( $file->slurp, $expected, "$this was bumped as expected" );
    },
);

done_testing;
