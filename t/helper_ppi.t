use v5.10;
use strict;
use warnings;
use Test2::V0;
use PPI::Document;
use Perl::Version::Bumper::Helper::PPI qw(
  drop_statement
);

my ( $src, $doc, $expected );

$src = PPI::Document->new( \<<'DOC' );
# comment before
use Swish;              # swish
use Zlopp; use Zlonk;   # zlopp zlonk
use zok qw( thunk );    # zok
DOC

# remove individual statements
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
use Zlopp;   # zlopp zlonk
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


done_testing;
