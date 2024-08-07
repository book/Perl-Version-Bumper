#!/usr/bin/env perl
use v5.32;
use warnings;

use Path::Tiny;

use feature ();    # to access %feature::feature_bundle

# compute everything we need to know about every feature:
# - known:       when perl first learnt about the feature
# - enabled:     when the feature was first enabled (may be before known)
# - disabled:    when the feature was first disabled
# - replacement: replacement modules for features to be deprecated / added

my $minor = $^V->{version}[1];    # the current perl minor version
$minor -= $minor % 2;             # rounded down to the latest stable

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
    try                     => { known => 5.034 },
    defer                   => { known => 5.036 },
    extra_paired_delimiters => { known => 5.036 },
    module_true             => { known => 5.038 },
    class                   => { known => 5.038 },
);

# update when each feature was enabled
for my $bundle ( map "5.$_", grep !( $_ % 2 ), 10 .. $minor ) {
    my $bundle_num = version::->parse("v$bundle")->numify;

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

# cleanup weird artifacts (%noops in feature.pm)
delete $feature{$_}{disabled} for qw( postderef lexical_subs );

# build the tabular data
my $feature_data = join '',
  map s/ +\Z//r,    # trim whitespace added by sprintf
  map sprintf( "%26s %-8s %-8s %-8s %s\n", @$_ ),
  [ "$^V feature", qw( known enabled disabled compat ) ],
  map [ map $_ // '',
    $_,       $feature{$_}->@{qw( known enabled disabled)},
    do {
        my $feature = $_;
        join ' ', map +( $_ => $feature{$feature}{compat}{$_} ),
          sort keys %{ $feature{$_}{compat} // {} };
    }
  ],
  sort { $feature{$a}->{known} <=> $feature{$b}->{known} || $a cmp $b }
  keys %feature;

print $feature_data;
