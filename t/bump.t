use Test2::V0;
use Perl::Version::Bumper;

my %tests = ( empty => do { local $/; split /^########## (.*)\n/m, <DATA> } );

for my $name ( sort keys %tests ) {
    my ( $src, %expected ) = split /^--- (.*)\n/m, $tests{$name}, -1;
    for my $version ( sort keys %expected ) {
        my $perv = Perl::Version::Bumper->new( version => $version );
        is( $perv->bump($src), $expected{$version} // '', "$name [$version]" );
    }

}
    done_testing;

__DATA__
--- v5.14
--- v5.28
########## no version
...;
--- v5.14
use v5.14;
...;
--- 5.028
use v5.28;
...;
########## recent version
use v5.28;
--- v5.14
use v5.28;
--- v5.28
use v5.28;
########## move version to the top
...;
use v5.14;
--- v5.28
use v5.28;
...;
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
# more stuff
...;
########## use version inside a block
{
    use v5.20;
    use feature 'signatures';
    no warnings 'experimental::signatures';
}
--- v5.36
use v5.36;
{
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
use strict; use warnings; # comment
########## partial feature removal
use v5.20;
use strict; # TODO drop
use warnings;
use feature 'lexical_subs';
use feature 'signatures';
--- v5.22
use v5.22;
use strict; # TODO drop
use warnings;
use feature 'lexical_subs';
use feature 'signatures';
--- v5.26
use v5.26;
use strict; # TODO drop
use warnings;
use feature 'signatures';
--- v5.36
use v5.36;
use strict; # TODO drop
use warnings;
########## multiple features enabled at once
use v5.20;
use strict; # TODO drop
use warnings;
use feature qw( lexical_subs signatures );
no warnings 'experimental::lexical_subs', 'experimental::signatures';
--- v5.22
use v5.22;
use strict; # TODO drop
use warnings;
use feature qw( lexical_subs signatures );
no warnings 'experimental::lexical_subs', 'experimental::signatures';
--- v5.26
use v5.26;
use strict; # TODO drop
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
--- v5.36
use v5.36;
use strict; # TODO drop
use warnings;
########## multiple features enabled at once with experimental
use v5.20;
use strict; # TODO drop
use warnings;
use experimental qw( lexical_subs signatures );
--- v5.22
use v5.22;
use strict; # TODO drop
use warnings;
use experimental qw( lexical_subs signatures );
--- v5.26
use v5.26;
use strict; # TODO drop
use warnings;
use experimental 'signatures';
--- v5.36
use v5.36;
use strict; # TODO drop
use warnings;
