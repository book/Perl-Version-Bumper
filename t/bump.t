use Test2::V0;
use Perl::Version::Bumper;

my %tests = ( empty => do { local $/; split /^########## (.*)\n/m, <DATA> } );

for my $name ( sort keys %tests ) {
    my ( $src, %expected ) = split /^--- (.*)\n/m, $tests{$name}, -1;
    for my $version ( sort keys %expected ) {
      SKIP: {
            my $perv = eval {
                Perl::Version::Bumper->new( version => $version );
            };
            skip "This is Perl $^V, not $version" unless $perv;
            is(
                $perv->bump($src),
                $expected{$version} // '',
                "$name [$version]"
            );
        }
    }
}

done_testing;

__DATA__
--- v5.14
--- v5.28
########## no version
...;
{ use strict; ... }
--- v5.14
use v5.14;
...;
{ use strict; ... }
--- 5.028
use v5.28;
...;
{ use strict; ... }
########## recent version
use v5.28;
--- v5.14
use v5.28;
--- v5.28
use v5.28;
########## same version
use 5.028;
--- v5.28
use v5.28;
########## move version to the top
...;
use v5.14;
no strict 'refs';
--- v5.28
use v5.28;
...;
no strict 'refs';
########## same version, move after package
use v5.28;
package Foo;
--- v5.28
package Foo;
use v5.28;
########## same version, remain after package
package Foo;
use v5.28;
--- v5.28
package Foo;
use v5.28;
########## move to the top if package if not first
use utf8;
package Bar;
use strict;
--- v5.30
use v5.30;
use utf8;
package Bar;
########## move version after comments
#!/usr/bin/env perl
...;
use v5.14;
--- v5.28
#!/usr/bin/env perl
use v5.28;
...;
########## a version with comments
#!/usr/bin/env perl
...;
    use v5.14  ; # some comment about use version
# more stuff
...;
--- v5.28
#!/usr/bin/env perl
use v5.28;
...;
# some comment about use version
# more stuff
...;
########## use version inside a block
{
    use v5.20;
    use feature 'signatures';
    no warnings 'experimental::signatures', "void";
}
--- v5.36
use v5.36;
{
    no warnings 'void';
}
########## use version inside a BEGIN
BEGIN {
    use v5.20;
    use experimental 'signatures';
}
--- v5.36
use v5.36;
BEGIN {
}
########## use version followed by stuff
use Foo;
use 5.020; use strict; use warnings; # comment
--- v5.28
use v5.28;
use Foo;
use warnings; # comment
--- v5.36
use v5.36;
use Foo;
# comment
########## partial feature removal
use v5.20;
use strict;
use warnings;
use feature 'lexical_subs';
use feature 'signatures';
--- v5.22
use v5.22;
use warnings;
use feature 'lexical_subs';
use feature 'signatures';
--- v5.26
use v5.26;
use warnings;
use feature 'signatures';
--- v5.36
use v5.36;
########## multiple features enabled at once
use v5.20;
use strict;
use warnings;
use feature qw( lexical_subs signatures );
no warnings "experimental::lexical_subs", "experimental::signatures";
--- v5.22
use v5.22;
use warnings;
use feature qw( lexical_subs signatures );
no warnings "experimental::lexical_subs", "experimental::signatures";
--- v5.26
use v5.26;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
--- v5.36
use v5.36;
########## multiple features enabled at once with experimental
use v5.20;
use strict;
use warnings;
use experimental qw( lexical_subs signatures );
--- v5.22
use v5.22;
use warnings;
use experimental qw( lexical_subs signatures );
--- v5.26
use v5.26;
use warnings;
use experimental 'signatures';
--- v5.36
use v5.36;
########## pay attention to non-significant elements
#!/usr/bin/env perl
use strict; use warnings; use v5.24; use feature qw/signatures/;
sub main {
}
--- v5.28
#!/usr/bin/env perl
use v5.28;
use warnings; use feature qw/signatures/;
sub main {
}
--- v5.36
#!/usr/bin/env perl
use v5.36;
sub main {
}
--- v5.38
#!/usr/bin/env perl
use v5.38;
sub main {
}
########## what happened to perl 7
require v5.36;
use strict;
use warnings;
use feature 'say';
use feature 'state';
use feature 'current_sub';
use feature 'fc';
use feature 'lexical_subs';
use feature 'signatures';
use feature 'isa';
use feature 'bareword_filehandles';
use feature 'bitwise';
use feature 'evalbytes';
use feature 'postderef_qq';
use feature 'unicode_eval';
use feature 'unicode_strings';
no feature 'indirect';
no feature 'multidimensional';
--- v5.36
use v5.36;
########## don't get medieval
require v5.28;
use strict;
use feature 'say';
use feature 'state';
use feature 'current_sub';
use feature 'bareword_filehandles';
use feature 'bitwise';
use feature 'evalbytes';
use feature 'fc';
use feature 'postderef_qq';
use feature 'switch';
use feature 'unicode_eval';
use feature 'unicode_strings';
--- v5.28
use v5.28;
########## multiple no feature on the same line
use v5.12;
no feature 'indirect', 'bareword_filehandles';
--- v5.14
use v5.14;
no feature 'indirect', 'bareword_filehandles';
--- v5.36
use v5.36;
no feature 'bareword_filehandles';
--- v5.38
use v5.38;
########## no indirect
use strict;
use warnings;
use Sub::StrictDecl;
no indirect;
use Test::More;
--- v5.28
use v5.28;
use warnings;
use Sub::StrictDecl;
no indirect;
use Test::More;
--- v5.36
use v5.36;
use Sub::StrictDecl;
use Test::More;
########## fc
use feature qw( say fc );
say fc("\x{17F}");    # s
--- v5.14
use v5.14;
use feature 'fc';
say fc("\x{17F}");    # s
--- v5.16
use v5.16;
say fc("\x{17F}");    # s
########## stable quotes
use strict;
use warnings;
no warnings "once";
--- v5.28
use v5.28;
use warnings;
no warnings "once";
--- v5.36
use v5.36;
no warnings "once";
########## keep possibly meaningful comments
use v5.28; ## no critic
--- v5.28
use v5.28;
## no critic
--- v5.36
use v5.36;
## no critic
