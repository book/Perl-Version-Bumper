use v5.10;
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

        if ( $name =~ /DIE!/ ) {
            is( $ran,         U,    "$name [$version] died" );
            is( $file->slurp, $src, "$name [$version]" );
        }
        else {
            is( $ran, D, "$name [$version] didn't die" );
            is(
                $file->slurp,
                $expected =~ s/use v5\.XX;/use $version;/gr,
                "$name [$version]"
            );
        }

    },
);

done_testing;
