use v5.10;
use strict;
use warnings;
use Test2::V0;
use PPI::Document;
use Perl::Version::Bumper::Helper::PPI qw(
  drop_statement
);

my ( $src, $doc, $expected );

# remove individual statements
$src = PPI::Document->new( \<<'DOC' );
# comment before
use Swish;              # swish
use Zlopp; use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0] );
is( $doc->serialize, <<'DOC', 'remove first include and comments' );
# comment before
use Zlopp; use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1] );
is( $doc->serialize, <<'DOC', 'remove second include' );
# comment before
use Swish;              # swish
use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[2] );
is( $doc->serialize, <<'DOC', 'remove third include and comments' );
# comment before
use Swish;              # swish
use Zlopp;
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[3] );
is( $doc->serialize, <<'DOC', 'remove fourth include and comments' );
# comment before
use Swish;              # swish
use Zlopp; use Zlonk;   # zlopp zlonk
DOC

# deal with indentation
$src = PPI::Document->new( \<<'DOC' );
    # comment before
    use Swish;              # swish
    use Zlopp; use Zlonk;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0] );
is( $doc->serialize, <<'DOC', 'remove first include and comments (indented)' );
    # comment before
    use Zlopp; use Zlonk;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1] );
is( $doc->serialize, <<'DOC', 'remove second include (indented)' );
    # comment before
    use Swish;              # swish
    use Zlonk;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[2] );
is( $doc->serialize, <<'DOC', 'remove third include and comments (indented)' );
    # comment before
    use Swish;              # swish
    use Zlopp;
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[3] );
is( $doc->serialize, <<'DOC', 'remove fourth include and comments (indented)' );
    # comment before
    use Swish;              # swish
    use Zlopp; use Zlonk;   # zlopp zlonk
DOC

# compound statement starting with non-significant whitespace
$src = PPI::Document->new( \<<'DOC' );
use v5.20;
use feature 'bitwise';
{ ...  }
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1] );
is( $doc->serialize, <<'DOC', 'remove whitespace before compound statement' );
use v5.20;
{ ...  }
DOC

# compound statement starting with non-significant whitespace (indented)
$src = PPI::Document->new( \<<'DOC' );
    use v5.20;
    use feature 'bitwise';
    { ...  }
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1] );
is( $doc->serialize, <<'DOC', 'remove whitespace before compound statement (indented)' );
    use v5.20;
    { ...  }
DOC

# multiple compound statements
$src = PPI::Document->new( \<<'DOC' );
use v5.22;
use feature 'bitwise';
{
    use feature 'bitwise';
    {
        no feature 'bitwise';
        my $z = $x & $y;
    }
    my $w |= $y;
}
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[2] );
is( $doc->serialize, <<'DOC', 'multiple compound statements (indented)' );
use v5.22;
use feature 'bitwise';
{
    {
        no feature 'bitwise';
        my $z = $x & $y;
    }
    my $w |= $y;
}
DOC
drop_statement( $doc->find('PPI::Statement::Include')->[1] );
is( $doc->serialize, <<'DOC', 'multiple compount statements' );
use v5.22;
{
    {
        no feature 'bitwise';
        my $z = $x & $y;
    }
    my $w |= $y;
}
DOC

# include with internal comments
$src = PPI::Document->new( \<<'DOC' );
# comment before
use                    # load
  Slosh                # module
  qw( kayo z_zwap )    # arguments
  ; use Rip;           # next
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0] );
is( $doc->serialize, <<'DOC', 'remove statement with inner comments' );
# comment before
use Rip;           # next
DOC

# just whitespace around
$src = PPI::Document->new( \<<'DOC' );
     use v5.10  ; # some comment about use version
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0] );
is( $doc->serialize, '', 'remove use version and comments' );

# no line ending
$src = PPI::Document->new( \'use Foo; use Bar;' );

$doc = $src->clone;
ok(
    no_warnings {
        drop_statement( $doc->find('PPI::Statement::Include')->[1] );
    },
    'no warnings when removing the last statement (no EOL)'
);
is( $doc->serialize, 'use Foo;',
    'remove statement with no newline at the end' );

# KEEP COMMENTS

# remove individual statements
$src = PPI::Document->new( \<<'DOC' );
# comment before
use Swish;              # swish
use Zlopp; use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0], !!1 );
is( $doc->serialize, <<'DOC', 'remove first include and keep comments' );
# comment before
# swish
use Zlopp; use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1], !!1 );
is( $doc->serialize, <<'DOC', 'remove second include and keep comments' );
# comment before
use Swish;              # swish
use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[2], !!1 );
is( $doc->serialize, <<'DOC', 'remove third include and keep comments' );
# comment before
use Swish;              # swish
use Zlopp;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[3], !!1 );
is( $doc->serialize, <<'DOC', 'remove fourth include and keep comments' );
# comment before
use Swish;              # swish
use Zlopp; use Zlonk;   # zlopp zlonk
# zok
DOC

# deal with indentation
$src = PPI::Document->new( \<<'DOC' );
    # comment before
    use Swish;              # swish
    use Zlopp; use Zlonk;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0], !!1 );
is( $doc->serialize, <<'DOC', 'remove first include and keep comments (indented)' );
    # comment before
    # swish
    use Zlopp; use Zlonk;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1], !!1 );
is( $doc->serialize, <<'DOC', 'remove second include and keep comments (indented)' );
    # comment before
    use Swish;              # swish
    use Zlonk;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[2], !!1 );
is( $doc->serialize, <<'DOC', 'remove third include and keep comments (indented)' );
    # comment before
    use Swish;              # swish
    use Zlopp;   # zlopp zlonk
    use zok qw( thunk );    # zok
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[3], !!1 );
is( $doc->serialize, <<'DOC', 'remove fourth include and keep comments (indented)' );
    # comment before
    use Swish;              # swish
    use Zlopp; use Zlonk;   # zlopp zlonk
    # zok
DOC

# compound statement starting with non-significant whitespace
$src = PPI::Document->new( \<<'DOC' );
use v5.20;
use feature 'bitwise'; # experimental
{ ...  }
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1], !!1 );
is( $doc->serialize, <<'DOC', 'remove whitespace before compound statement and keep comments' );
use v5.20;
# experimental
{ ...  }
DOC

# compound statement starting with non-significant whitespace (indented)
$src = PPI::Document->new( \<<'DOC' );
    use v5.20;
    use feature 'bitwise'; # experimental
    { ...  }
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[1] );
is( $doc->serialize, <<'DOC', 'remove whitespace before compound statement and keep comments (indented)' );
    use v5.20;
    { ...  }
DOC

# include with internal comments
$src = PPI::Document->new( \<<'DOC' );
# comment before
use                    # load
  Slosh                # module
  qw( kayo z_zwap )    # arguments
  ; use Rip;           # next
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0] );
is( $doc->serialize, <<'DOC', 'remove statement with inner comments' );
# comment before
use Rip;           # next
DOC

# just whitespace around
$src = PPI::Document->new( \<<'DOC' );
     use v5.10  ; # some comment about use version
DOC

$doc = $src->clone;
drop_statement( $doc->find('PPI::Statement::Include')->[0], !!1 );
is( $doc->serialize, <<'DOC', 'remove use version and keep comments' );
     # some comment about use version
DOC

done_testing;
