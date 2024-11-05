#!/usr/bin/env perl
use v5.32;
use warnings;

use Path::Tiny;
use Perl::Version::Bumper qw(
    version_fmt
    version_fix
    version_inc
);


use feature ();    # to access %feature::feature_bundle

# compute everything we need to know about every feature:
# - known:    when perl first learnt about the feature
# - enabled:  when the feature was first enabled (may be before it was known)
# - disabled: when the feature was first disabled
# - compat:   replacement modules for features to be deprecated / added

# the current perl version rounded down to the latest stable
my $stable = version_fix($]);

# features are listed in the order of the perlfeature manual page
# (the information that can't be computed is pre-filled)
my %feature = (
    say => {
        compat => {
            'Perl6::Say'  => 1,    # import only
            'Say::Compat' => 1,    # import only
        }
    },

    # state
    # switch
    # unicode_strings
    # unicode_eval
    # evalbytes
    # current_sub
    array_base => { known => 5.016, enabled => 5.010, disabled => 5.016 },

    # fc
    lexical_subs  => { known => 5.018, enabled => 5.026 },
    postderef     => { known => 5.020, enabled => 5.024 },
    postderef_qq  => { known => 5.020 },
    signatures    => { known => 5.020 },
    refaliasing   => { known => 5.022 },
    bitwise       => { known => 5.022 },
    declared_refs => { known => 5.026 },
    isa           => { known => 5.032 },
    indirect      => {
        known   => 5.032,
        enabled => 5.010,
        compat  => { indirect => 0 },    # import / unimport
    },
    multidimensional => {
        known   => 5.034,
        enabled => 5.010,
        compat  => { multidimensional => 0 },    # import / unimport
    },
    bareword_filehandles => {
        known   => 5.034,
        enabled => 5.010,
        compat  => { 'bareword::filehandles' => 0 },    # import / unimport
    },
    try => {
        known  => 5.034,
        compat => {
            'Syntax::Keyword::Try' => 0,                # import / unimport
            'Syntax::Feature::Try' => 0,                # import / unimport
        },
    },
    defer                   => { known => 5.036 },
    extra_paired_delimiters => { known => 5.036 },
    module_true             => { known => 5.038 },
    class                   => { known => 5.038 },
);

# remove data more recent than the perl we're running
# (makes it easier to run with any perl, even if we
# only really care
for my $feature ( keys %feature ) {
    exists $feature{$feature}{$_} && $feature{$feature}{$_} > $]
      and delete $feature{$feature}{$_}
      for qw( known enabled disabled );
    delete $feature{$feature}
      if join( '', keys %{ $feature{$feature} } ) =~ /\A(?:compat)?\z/;
}

# complete the %features data structure
my $bundle_num = '5.010';
while ( $bundle_num <= $stable ) {

    # bundles are v-strings without the v
    my $bundle = join '.', 5, 0 + ( split /\./, $bundle_num )[1];

    # when was the feature enabled
    $feature{$_}{enabled} //= $bundle_num
      for @{ $feature::feature_bundle{$bundle} };

    # if it's enabled, surely we know about it
    $feature{$_}{known} //= $bundle_num
      for grep exists $feature{$_}{enabled}, keys %feature;

    # detect when a feature was disabled
    # (it must be known and have been enabled first)
    for my $feature (
           grep $bundle_num >= $feature{$_}{known}
        && exists $feature{$_}{enabled}
        && $bundle_num >= $feature{$_}{enabled},
        keys %feature
      )
    {
        $feature{$feature}{disabled} //= $bundle_num
          unless grep $_ eq $feature,
          @{ $feature::feature_bundle{$bundle} };
    }

}
continue {
    $bundle_num = version_inc($bundle_num);
}

# cleanup weird artifacts (%noops in feature.pm)
delete $feature{$_}{disabled} for qw( postderef lexical_subs );

# build the tabular data
my $feature_data = join '',
  map s/ +\Z//r,    # trim whitespace added by sprintf
  map sprintf( "%26s %-8s %-8s %-8s %s\n", @$_ ),
  [ version_fmt($]) . ' features', qw( known enabled disabled compat ) ],
  map [
    $_,                                       # feature name
    map ( $_ ? sprintf "  %5.3f", $_ : '',    # version numbers
        $feature{$_}->@{qw( known enabled disabled)} ),
    do {                                      # compat modules
        my $feature = $_;
        join ' ', map +( $_ => $feature{$feature}{compat}{$_} ),
          sort keys %{ $feature{$_}{compat} // {} };
    }
  ],
  sort { $feature{$a}->{known} <=> $feature{$b}->{known} || $a cmp $b }
  keys %feature;

print $feature_data;
