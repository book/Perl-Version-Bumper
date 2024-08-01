package Perl::Version::Bumper;
use v5.16;    # %feature::feature_bundle wasn't accessible before v5.16
use warnings;

use Path::Tiny;
use PPI::Document;
use PPI::Token::Operator;
use PPI::Token::Attribute;
use Carp    qw( carp croak );
use feature ();                 # to access %feature::feature_bundle

my $default_minor = $^V->{version}[1];    # the current perl minor version
$default_minor -= $default_minor % 2;     # rounded down to the latest stable

# everything we know about every feature:
# - known:       when perl first learnt about the feature
# - enabled:     when the feature was first enabled (may be before known)
# - disabled:    when the feature was first disabled
# - replacement: replacement modules for features to be deprecated / added

# features are listed in the order of the perlfeature manual page
# (the information that can't be computed is pre-filled)
sub __build_feature {
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
    );

    # update when each feature was enabled
    for my $bundle ( map "5.$_", grep !( $_ % 2 ), 10 .. $default_minor ) {
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

    return \%feature;
}

my %feature = %{ __build_feature() };

sub new {

    # stolen from Moo::Object
    my $class = shift;
    my $args = scalar @_ == 1
      ? ref $_[0] eq 'HASH'
        ? { %{ $_[0] } }
        : Carp::croak("Single parameters to new() must be a HASH ref"
            . " data => ". $_[0])
      : @_ % 2
        ? Carp::croak("The new() method for $class expects a hash reference or a"
            . " key/value list. You passed an odd number of arguments")
        : {@_}
    ;

    # handle the version attribute
    $args->{version} //= $^V;
    my $version = version::->parse( $args->{version} );
    my ( $major, $minor ) = @{ $version->{version} };
    croak "Major version number must be 5, not $major"
      if $major != 5;
    croak "Minor version number $minor > $default_minor"
      if $minor > $default_minor;
    croak "Minor version number $minor < 10"
      if $minor < 10;
    croak "Minor version number must be even, not $minor"
      if $minor % 2;
    $args->{version} = "v$major.$minor";

    return bless { version => $args->{version} }, $class;
};

sub version { shift->{version} }

# PRIVATE FUNCTIONS

sub __evaluate {
    map ref()
      ? $_->[0] eq 'CODE'
          ? sub { }    # leave anonymous subs as is
          : $_->[0] eq '[' ? [ __SUB__->( @$_[ 1 .. $#$_ ] ) ]    # ARRAY
        : $_->[0] eq '{' ? { __SUB__->( @$_[ 1 .. $#$_ ] ) }      # HASH
        : __SUB__->( @$_[ 1 .. $#$_ ] )    # LIST (flattened)
      : $_,                                  # SCALAR
      @_;
}

# given a list of PPI tokens, construct a Perl data structure
sub _ppi_list_to_perl_list {

    # are there constants we ought to know about?
    my $constants = ref $_[-1] eq 'HASH' ? pop @_ : {};

    # make sure we have tokens (i.e. deconstruct Statement and Structure objects)
    my @tokens = grep $_->significant, map $_->tokens, @_;
    my @stack  = my $root = my $ptr = [];
    my $prev;
    while ( my $token = shift @tokens ) {
        if ( $token->isa('PPI::Token::Structure') ) {
            if ( $token =~ /\A[[{(]\z/ ) {    # opening
                $ptr = $token eq '{' && $prev && $prev eq 'sub'    # sub { ... }
                  ? do { pop @{ $stack[-1] }; ['CODE'] }    # drop 'sub' token
                  : ["$token"];
                push @{ $stack[-1] }, $ptr;
                push @stack,          $ptr;
            }
            elsif ( $token =~ /\A[]})]\z/ ) {                      # closing
                pop @stack;
                $ptr = $stack[-1];
            }
        }
        elsif ( $token eq ',' || $token eq '=>' ) { }              # skip
        elsif ( $token->isa('PPI::Token::Symbol') ) {              # variable

            # construct the expression back (and keep the object around)
            my $expr = PPI::Document->new( \join '', $token, @tokens );

            # PPI::Document -> PPI::Statement
            # -> PPI::Token::Symbol (ignored), PPI::Sructure::Subscript (maybe)
            my ( undef, $subscript ) = $expr->child(0)->children;
            if ( $subscript && $subscript->isa('PPI::Structure::Subscript') ) {
                shift @tokens for $subscript->tokens;    # drop subcript tokens
                push @$ptr, "$token$subscript";          # symbol + subscript
            }
            else {
                push @$ptr, "$token";                    # simple symbol
            }
        }
        elsif ($token->isa('PPI::Token::Word')                     # undef
            && $token eq 'undef'
            && ( $tokens[0] ? $tokens[0] ne '=>' : 1 ) )
        {
            push @$ptr, undef;
        }
        elsif ($token->isa('PPI::Token::HereDoc') ) {              # heredoc
            push @$ptr, join '', $token->heredoc;
        }
        else {
            my $next_sibling = $token->snext_sibling;
            push @$ptr,

              # maybe a known constant?
                exists $constants->{$token} && ( $next_sibling ? $next_sibling ne '=>' : 1 )
                                        ? $constants->{$token}

              # various types of strings
              : $token->can('literal')  ? $token->literal
              : $token->can('simplify') ? do {
                  my $clone = $token->clone;
                  $clone->simplify && $clone->can('literal')
                                        ? $clone->literal
                                        : "$clone";
                }
              : $token->can('string')   ? $token->string

              # stop at the first operator
              : $token->isa( 'PPI::Token::Operator' ) ? last

              # give up and just stringify
              :                         "$token";
        }
        $prev = $token;
    }
    return __evaluate(@$root);
}

sub _drop_statement {
    my ( $stmt, $keep_comments ) = @_;

    # remove non-significant elements before the statement
    while ( my $prev_sibling = $stmt->previous_sibling ) {
        last if $prev_sibling->significant;
        last if $prev_sibling =~ /\n\z/;
        $prev_sibling->remove;
    }

    # remove non-significant elements after the statement
    # if there was no significant element before it on the same line
    # (i.e. it was the only statement on the line)
    $stmt->document->index_locations;
    if (  !$stmt->sprevious_sibling
        || $stmt->sprevious_sibling->location->[0] ne $stmt->location->[0] )
    {
        # collect non-significant elements until next newline (included)
        my ( $next, @to_drop ) =  ( $stmt );
        while ( $next = $next->next_sibling ) {
            last if $next->significant;
            push @to_drop, $next;
            last if $next eq "\n";
        }

        # do not drop comments if asked to keep them
        @to_drop = grep !$_->isa('PPI::Token::Comment') && $_ ne "\n", @to_drop
          if $keep_comments && grep $_->isa('PPI::Token::Comment'), @to_drop;
        $_->remove for @to_drop;

        $stmt->document->flush_locations;
    }

    # and finally remove it
    $stmt->remove;
}

sub _drop_bare {
   my ( $type, $module, $doc ) = @_;
    my $use_module = $doc->find(
        sub {
            my ( $root, $elem ) = @_;
            return 1
              if $elem->isa('PPI::Statement::Include')
              && $elem->module eq $module
              && $elem->type eq $type
              && !$elem->arguments;    # bare use module
            return;                    # only top-level
        }
    );
    if ( ref $use_module ) {
        _drop_statement($_) for @$use_module;
    }
    return;
}

sub _find_include {
   my ( $module, $doc ) = @_;
    my $found = $doc->find(
        sub {
            my ( $root, $elem ) = @_;
            return 1
              if $elem->isa('PPI::Statement::Include')
              && $elem->module eq $module;
            return '';
        }
    );
    croak "Bad condition for PPI::Node->find"
      unless defined $found;    # error
    return unless $found;       # nothing found
    return @$found;
}

sub _version_stmts {
   my ($doc) = @_;
    my $version_stmts = $doc->find(
        sub {
            my ( $root, $elem ) = @_;
            return 1 if $elem->isa('PPI::Statement::Include') && $elem->version;
            return '';
        }
    );
    croak "Bad condition for PPI::Node->find"
      unless defined $version_stmts;
    return $version_stmts ? @$version_stmts : ();
}

# The 'bitwise' feature may break bitwise operators,
# so disable it when bitwise operators are detected
sub _handle_feature_bitwise {
   my ( $doc ) = @_;

    # this only matters for code using bitwise ops
    return unless $doc->find(
        sub {
            my ( $root, $elem ) = @_;
            $elem->isa('PPI::Token::Operator') && $elem =~ /\A[&|~^]=?\z/;
        }
    );

    # the `use VERSION` inserted earlier is always the last one in the doc
    my $insert_point       = ( _version_stmts($doc) )[-1];
    my $no_feature_bitwise = PPI::Document->new( \"no feature 'bitwise';\n" );
    $insert_point->insert_after( $_->remove ) for $no_feature_bitwise->elements;

    # also add a TODO comment to warn users
    $insert_point = $insert_point->snext_sibling;
    my $todo_comment = PPI::Document->new( \( << '    TODO_COMMENT' =~ s/^    //grm ) );

    # IMPORTANT: Please double-check the use of bitwise operators
    # before removing the `no feature 'bitwise';` line below.
    # See manual pages perlfeature (section "The 'bitwise' feature")
    # and perlop (section "Bitwise String Operators") for details.
    TODO_COMMENT
    $insert_point->insert_before( $_->remove ) for $todo_comment->elements;

}

# handle the case of CPAN modules that serve as compatibility layer for some
# features on older Perls, or that existed before the feature was developed
sub _handle_compat_modules {
    my ( $doc, $bundle_num ) = @_;
    for my $feature ( grep exists $feature{$_}{compat}, keys %feature ) {
        for my $compat ( keys %{ $feature{$feature}{compat} } ) {
            if ( $bundle_num >= $feature{$feature}{known} ) {

                # negative features (eventually disabled)
                my @no_compat = grep $_->type eq 'no',
                  _find_include( $compat => $doc );
                for my $no_compat (@no_compat) {
                    if (    # can the compat module unimport?
                        $feature{$feature}{compat}{$compat} <= 0
                        && (    # feature not disabled yet, or already enabled
                            exists $feature{$feature}{disabled}
                            ? $bundle_num < $feature{$feature}{disabled}
                            : ( !exists $feature{$feature}{enabled}
                                  || $bundle_num > $feature{$feature}{enabled} )
                        )
                      )
                    {
                        my $no_feature =
                          PPI::Document->new( \"no feature '$feature';\n" );
                        $no_compat->insert_after( $_->remove )
                          for $no_feature->elements;
                    }
                    _drop_statement($no_compat);
                }

                # positive features (eventually enabled)
                my @use_compat = grep $_->type eq 'use',
                  _find_include( $compat => $doc );
                for my $use_compat (@use_compat) {
                    if ( !exists $feature{$feature}{enabled}
                        || $bundle_num < $feature{$feature}{enabled} )
                    {
                        my $use_feature =
                          PPI::Document->new( \"use feature '$feature';\n" );
                        $use_compat->insert_after( $_->remove )
                          for $use_feature->elements;
                    }
                    _drop_statement($use_compat);
                }

            }
        }
    }
}

# The 'signature' feature needs prototypes to be updated.
sub _handle_feature_signatures {
    my ($doc) = @_;

    # find all subs with prototypes
    my $prototypes = $doc->find('PPI::Token::Prototype');
    return unless $prototypes;

    # and turn them into prototype attributes
    for my $proto (@$prototypes) {
        $proto->insert_before( PPI::Token::Operator->new(':') );
        $proto->insert_before( PPI::Token::Attribute->new("prototype$proto") );
        $proto->remove;
    }
}

sub _features_enabled_in {
    my $bundle_num = shift;
    return
      grep !exists $feature{$_}{disabled} || $bundle_num <  $feature{$_}{disabled},
      grep  exists $feature{$_}{enabled}  && $bundle_num >= $feature{$_}{enabled},
      keys %feature;
}

# PRIVATE "METHODS"

sub _remove_enabled_features {
    my ( $self, $doc, $old_num ) = @_;
    my ( %enabled_in_perl, %enabled_in_code );
    my $bundle     = $self->version =~ s/\Av//r;
    my $bundle_num = version::->parse( $self->version )->numify;
    @enabled_in_perl{ _features_enabled_in($bundle_num) } = ();

    # drop features enabled in this bundle
    # (also if they were enabled with `use experimental`)
    for my $module (qw( feature experimental )) {
        for my $use_line ( grep $_->type eq 'use', _find_include( $module => $doc ) ) {
            my @old_args = _ppi_list_to_perl_list( $use_line->arguments );
            $enabled_in_code{$_}++ for @old_args;
            my @new_args = grep !exists $enabled_in_perl{$_}, @old_args;
            next if @new_args == @old_args;    # nothing to remove
            if (@new_args) {    # replace old statement with a smaller one
                my $new_use_line = PPI::Document->new(
                    \"use $module @{[ join ', ', map qq{'$_'}, @new_args]};" );
                $use_line->insert_before( $_->remove )
                  for $new_use_line->elements;
                $use_line->remove;
            }
            else { _drop_statement($use_line); }
        }
    }

    # handle specific features
    _handle_compat_modules( $doc, $bundle_num );
    _handle_feature_bitwise($doc)
      if $old_num < 5.028               # code from before 'bitwise'
      && $bundle_num >= 5.028           # bumped to after 'bitwise'
      && !$enabled_in_code{bitwise};    # and not enabling the feature
    _handle_feature_signatures($doc)
      if $old_num < 5.036                  # code from before 'signatures'
      && $bundle_num >= 5.036              # bumped to after 'signatures'
      && !$enabled_in_code{signatures};    # and not enabling the feature

    # drop previously disabled obsolete features
    for my $no_feature ( grep $_->type eq 'no', _find_include( feature => $doc ) ) {
        my @old_args = _ppi_list_to_perl_list( $no_feature->arguments );
        my @new_args = grep exists $enabled_in_perl{$_}, @old_args;
        next if @new_args == @old_args;    # nothing to remove
        if (@new_args) {    # replace old statement with a smaller one
            my $new_no_feature = PPI::Document->new(
                \"no feature @{[ join ', ', map qq{'$_'}, @new_args]};" );
            $no_feature->insert_before( $_->remove )
              for $new_no_feature->elements;
            $no_feature->remove;
        }
        else { _drop_statement($no_feature); }
    }

    # drop experimental warnings, if any
    for my $warn_line ( grep $_->type eq 'no', _find_include( warnings => $doc ) ) {
        my @old_args = _ppi_list_to_perl_list( $warn_line->arguments );
        next unless grep /\Aexperimental::/, @old_args;
        my @new_args = grep !exists $enabled_in_perl{s/\Aexperimental:://r},
          grep /\Aexperimental::/, @old_args;
        my @keep_args = grep !/\Aexperimental::/, @old_args;
        next if @new_args == @old_args    # nothing to remove
          || @new_args + @keep_args == @old_args;
        if ( @new_args || @keep_args ) {    # replace old statement
            my $new_warn_line = PPI::Document->new(
                \"no warnings @{[ join ', ', map qq{'$_'}, @new_args, @keep_args]};"
            );
            $warn_line->insert_before( $_->remove )
              for $new_warn_line->elements;
            $warn_line->remove;
        }
        else { _drop_statement($warn_line); }
    }

    # strict is automatically enabled with 5.12
    _drop_bare( use => strict => $doc ) if $bundle_num >= 5.012;

    # warnings are automatically enabled with 5.36
    _drop_bare( use => warnings => $doc ) if $bundle_num >= 5.036;

    return;
}

sub _insert_version_stmt {
    my ( $self, $doc, $old_num ) = @_;
    $old_num //= version::->parse( 'v5.8' )->numify;
    my $version_stmt =
      PPI::Document->new( \sprintf "use %s;\n", $self->version );
    my $insert_point = $doc->schild(0) // $doc->child(0);

    # insert before the next significant sibling
    # if the first element is a use VERSION
    $insert_point = $insert_point->snext_sibling
      if $insert_point->isa('PPI::Statement::Include')
      && $insert_point->version
      && $insert_point->snext_sibling;

    # because of Perl::Critic::Policy::Modules::RequireExplicitPackage
    # we have to put the use VERSION line after the package line,
    # if that's the first significant thing in the document
    if ( $insert_point->isa('PPI::Statement::Package') ) {
        $insert_point->insert_after( $_->remove ) for $version_stmt->elements;
    }
    elsif ( $insert_point->significant ) {
        $insert_point->insert_before( $_->remove ) for $version_stmt->elements;
    }
    else {
        $doc->add_element( $_->remove ) for $version_stmt->elements;
    }

    # cleanup features enabled by the new version
    _remove_enabled_features( $self, $doc, $old_num );
}

sub _try_compile {
    my ( $file ) = @_;

    # redirect STDERR for quietness
    my $tmperr = Path::Tiny->tempfile;
    open( \*OLDERR, '>&', \*STDERR ) or die "Can't dup STDERR: $!";
    open( \*STDERR, '>',  $tmperr )  or die "Can't re-open STDERR: $!";

    # try to compile the file
    my $status = system $^X, '-c', $file;
    my $exit = $status >> 8;

    # get STDERR back, and warn about errors while compiling
    open( \*STDERR, '>&', \*OLDERR ) or die "Can't restore STDERR: $!";
    warn $tmperr->slurp if $exit;

    return !$exit;    # 0 means success
}

sub _try_bump_ppi_safely {
    my ( $self, $doc, $version_limit ) = @_;
    my $version  = version::->parse( $self->version );
    my $filename = $doc->filename;
    $version_limit = version::->parse($version_limit);

    # try bumping down version until it compiles
    while ( $version >= $version_limit or $version = '' ) {
        my $perv = $self->version eq $version
          ? $self    # no need to create a new object
          : Perl::Version::Bumper->new( version => $version );
        my $tmp = Path::Tiny->tempfile;
        $tmp->spew( $perv->bump_ppi($doc)->serialize );

        # try to compile the file
        last if _try_compile( $tmp );

        # bump version down and repeat
        $version =
          version::->parse( 'v5.' . ( ( split /\./, $version )[1] - 2 ) );
    }

    return $version;
}

# PUBLIC METHOS

sub bump_ppi {
    my ( $self, $doc ) = @_;
    $doc = $doc->clone;
    my $source = $doc->filename // 'input code';

    # found at least one version statement
    if ( my @version_stmts = _version_stmts($doc) ) {

        # bail out if there's more than one `use VERSION`
        if ( @version_stmts > 1 ) {
            carp "Found multiple use VERSION statements in $source:"
              . join ', ', map $_->version, @version_stmts;
        }

        # drop the existing version statement
        # and add the new one at the top
        else {
            my ($use_v) = _version_stmts($doc);    # there's only one
            my ( $old_num, $new_num ) = map version::->parse($_)->numify,
              $use_v->version, $self->version;
            if ( $old_num <= $new_num ) {
                _insert_version_stmt( $self, $doc, $old_num );
                _drop_statement( $use_v, 1 );
            }
        }
    }

    # no version statement found, add one
    else { _insert_version_stmt( $self, $doc ); }

    return $doc;
}

sub bump {
    my ( $self, $code ) = @_;
    return $code unless length $code;    # don't touch the empty string

    my $doc = PPI::Document->new( \$code );
    croak "Parsing failed" unless defined $doc;

    return $self->bump_ppi($doc)->serialize;
}

sub bump_file {
    my ( $self, $file ) = @_;
    $file = Path::Tiny->new($file);
    my $code   = $file->slurp;
    my $bumped = $self->bump( $code, $file );
    if ( $bumped ne $code ) {
        $file->spew($bumped);
        return !!1;
    }
    return;
}

sub bump_file_safely {
    my ( $self, $file, $version_limit ) = @_;
    $file = Path::Tiny->new($file);
    my $code = $file->slurp;
    my $doc  = PPI::Document->new( \$code, filename => $file );
    croak "Parsing failed" unless defined $doc;
    $version_limit //= do {
        my @version_stmts = _version_stmts($doc);
        @version_stmts
          ? version::->parse( $version_stmts[0]->version )->normal =~ s/\.0\z//r
          : 'v5.10';
    };

    # try compiling the file: if it fails, our safeguard won't work
    unless ( _try_compile($file) ) {
        warn "Can't bump Perl version safely for $file: it does not compile\n";
        return;    # return undef
    }

    # try bumping version safely, and save the result
    if ( my $version = _try_bump_ppi_safely( $self, $doc, $version_limit ) ) {
        my $perv = $self->version eq $version
          ? $self    # no need to create a new object
          : Perl::Version::Bumper->new( version => $version );
        $file->spew( $perv->bump_ppi($doc)->serialize );
        return $version;
    }

    return '';    # return defined but false
}

1;

__END__

=head1 NAME

Perl::Version::Bumper - Update C<use VERSION> on any Perl code

=head1 SYNOPSSIS

    use Perl::Version::Bumper;

    my $perv = Perl::Version::Bumper->new( version => 'v5.36' );

    # bump a PPI::Document (and get source code)
    my $new_code = $perv->bump_ppi( $ppi_doc );

    # bump source code
    my $new_code = $perv->bump( $old_code );

    # bump the source of a file
    $perv->bump_file( $filename );

    # bump the source of a file (and double check it compiles)
    $perv->bump_file_safely( $filename, $version_limit );

=head1 DESCRIPTION

C<Perl::Version::Bumper> can update a piece of Perl code to
make it declare it uses a more recent version of the Perl language by
way of C<use VERSION>.

It takes care of removing unnecessary loading of L<feature> and
L<experimental> L<warnings>, and adds the C<use VERSION> line at the
top of the file (thus encouraging "line 1 semantics").

If the code already declares a Perl version, it can only be bumped
to a higher version.

=head1 CONSTRUCTOR

=head2 new

    my $prev = Perl::Version::Bumper->new( %arguments );
    my $prev = Perl::Version::Bumper->new( \%arguments );

Return a new C<Perl::Version::Bumper> object.

=head1 ATTRIBUTES

=head2 version

The target version to bump to.

Defaults to the stable version less than or equal to the version of the
currenly running C<perl>.

The constructor accepts both forms of Perl versions, regular
(e.g. C<v5.36>) and floating-point (e.g. C<5.036>).

To protect against simple mistakes (e.g. passing C<5.36> instead of
C<v5.36>), the constructor does some sanity checking, and checks that
the given version:

=over 4

=item *

is greater than or equal to C<v5.10>,

=item *

is lower than the version of the Perl currently running,

=item *

is even (this module targets stable Perl versions only).

=back

The constructor will also drops any version information after the minor
version (so C<v5.36.2> will be turned into C<v5.36>).

=head1 METHODS

=head2 bump_ppi

    my $new_code = $perv->bump_ppi( $ppi_doc );

Take a L<PPI::Document> as input, and return a new L<PPI::Document>
with its declared version bumped to L</version>.

=head2 bump

    my $new_code = $perv->bump( $old_code );

Bump the declared Perl version in the source code to L</version>,
and return the new source code as a string.

=head2 bump_file

    $perv->bump_file( $filename );

Bump the code of the file argument in-place.

=head2 bump_file_safely

    $perv->bump_file_safely( $filename, $version_limit );

Bump the source of the given file and save it to a temporaty file.
If that file compiles continue with the bump and update the original file.

If compilation fails, try again with the previous stable Perl version,
and repeat all the way back to the currently declared version in the file,
or C<$version_limit>, whichever is the more recent.

The return value is C<undef> if the original didn't compile, false
(empty string) if all attempts to bump the file failed, and the actual
version number the file was bumped to in case of success.

=head1 ACKNOWLEDGMENT

This software was originally developed at Booking.com. With approval
from Booking.com, this software was released as open source, for which
the authors would like to express their gratitude.

=cut
