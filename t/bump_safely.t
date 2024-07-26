use Test2::V0;
use Test2::Tools::Compare qw( D U );
use Path::Tiny;
use Perl::Version::Bumper;

my @tests = split /^########## (.*)\n/m,
  path( __FILE__ =~ s/\.t\z/.data/r )->slurp;
shift @tests;    # drop the test preamble

while ( my ( $name, $data ) = splice @tests, 0, 2 ) {
    my ( $src, %expected ) = split /^--- (.*)\n/m, $data, -1;
    my $file = Path::Tiny->tempfile;
    $file->spew($src);

    for my $defn ( sort keys %expected ) {
        my ( $version_range, $todo ) = split / /, $defn, 3;
        my ( $version, $version_limit ) = split /-/, $version_range;
      SKIP: {
            my $perv = eval {
                Perl::Version::Bumper->new( version => $version );
            };
            skip "This is Perl $^V, not $version" unless $perv;

            # silence errors
            open( \*OLDERR, '>&', \*STDERR )    or die "Can't dup STDERR: $!";
            open( \*STDERR, '>',  '/dev/null' ) or die "Can't re-open STDERR: $!";

            my $ran = eval { $perv->bump_file_safely( $file, $version_limit ) }
              or my $error = $@;    # catch (syntax) errors in the eval'ed code

            # get STDERR back, and warn about errors while compiling
            open( \*STDERR, '>&', \*OLDERR )    or die "Can't restore STDERR: $!";

            # throw the errors in the eval, if any
            die $error if $error;

            if ( $name =~ /DIE!/ ) {
                is( $ran, U, "$name [$version_range] died" );
                $todo &&= todo $todo;
                is( $file->slurp, $src, "$name [$version_range]" );
            }
            else {
                is( $ran, D, "$name [$version_range] didn't die" );
                $todo &&= todo $todo;
                is( $file->slurp, $expected{$defn}, "$name [$version_range]" );
            }
        }
    }
}

done_testing;
