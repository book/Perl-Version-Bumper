use Test2::V0;
use Test2::Tools::Compare qw( D U );
use Path::Tiny;
use Perl::Version::Bumper;

my %tests =
  ( 'does not compile' => do { local $/; split /^########## (.*)\n/m, <DATA> } );

my %expect_die = map +( $_ => undef ), # there are a few failure cases
    'does not compile';

for my $name ( sort keys %tests ) {
    my ( $src, %expected ) = split /^--- (.*)\n/m, $tests{$name}, -1;
    my $file = Path::Tiny->tempfile;
    $file->spew($src);

    for my $max_min ( sort keys %expected ) {
        my ( $version, $version_limit ) = split / /, $max_min;
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

            if ( exists $expect_die{$name} ) {
                is( $ran, U, "$name [$max_min] died" );
                is( $file->slurp, $src, "$name [$max_min]" );
            }
            else {
                is( $ran, D, "$name [$max_min] didn't die" );
                is( $file->slurp, $expected{$max_min}, "$name [$max_min]" );
            }
        }
    }
}

done_testing;

__DATA__
BEGIN { die }
--- v5.36
BEGIN { die }
########## indirect (no strict)
$o = new Foo;
--- v5.36
use v5.10;
$o = new Foo;
--- v5.16 v5.12
$o = new Foo;
########## indirect
{ package Foo }
my $o = new Foo;
--- v5.36
use v5.10;
{ package Foo }
my $o = new Foo;
--- v5.36
use v5.34;
{ package Foo }
my $o = new Foo;
########## multidimensional
use strict;
my %foo;
$foo{ 0, 1 } = 2;    # %foo = ( '0\0341' => 2 )
--- v5.36
use v5.34;
my %foo;
$foo{ 0, 1 } = 2;    # %foo = ( '0\0341' => 2 )
########## heredoc
use strict;
my $str = << 'EOT';
I'm a heredoc!
EOT
--- v5.36
use v5.36;
my $str = << 'EOT';
I'm a heredoc!
EOT
########## 5.8.5
use v5.8.5;
use strict;
--- v5.28
use v5.28;
