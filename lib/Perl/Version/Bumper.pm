package Perl::Version::Bumper;
use v5.28;

use warnings;
use Sub::StrictDecl;
use Path::Tiny;
use PPI::Document;
use Carp                qw( carp croak );
use feature             ();    # to access %feature::feature_bundle

use Moo;
use namespace::clean;

use experimental 'signatures';

has version => (
    is      => 'ro',
    default => 'v5.28',
);

my $base_minor = $^V->{version}[1];     # our minor

around BUILDARGS => sub ( $orig, $class, @args ) {
    my $args = $class->$orig(@args);
    if ( $args->{version} ) {
        my $version = version->parse( $args->{version} );
        my ( $major, $minor ) = $version->{version}->@*;
        croak "Major version number must be 5, not $major"
          if $major != 5;
        croak "Minor version number $minor > $base_minor"
          if $minor > $base_minor;
        croak "Minor version number $minor < 10"
          if $minor < 10;
        croak "Minor version number must be even, not $minor"
          if $minor % 2;
        $args->{version} = "v$major.$minor";
    }
    $args;
};

# PRIVATE FUNCTIONS

my sub __evaluate {
    map ref
      ? $_->[0] eq 'CODE'
          ? sub { }    # leave anonymous subs as is
          : $_->[0] eq '[' ? [ __SUB__->( $_->@[ 1 .. $#$_ ] ) ]    # ARRAY
        : $_->[0] eq '{' ? { __SUB__->( $_->@[ 1 .. $#$_ ] ) }      # HASH
        : __SUB__->( $_->@[ 1 .. $#$_ ] )    # LIST (flattened)
      : $_,                                  # SCALAR
      @_;
}

# given a list of PPI tokens, construct a Perl data structure
my sub _ppi_list_to_perl_list {

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
                  ? do { pop $stack[-1]->@*; ['CODE'] }    # drop 'sub' token
                  : ["$token"];
                push $stack[-1]->@*, $ptr;
                push @stack,         $ptr;
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

my sub _drop_statement ( $stmt, $keep_comments = '' ) {

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

my sub _drop_bare ( $type, $module, $doc ) {
    my $use_module = $doc->find(
        sub ( $root, $elem ) {
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

my sub _find_include ( $module, $doc ) {
    my $found = $doc->find(
        sub ( $root, $elem ) {
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

my sub _version_stmts ($doc) {
    my $version_stmts = $doc->find(
        sub ( $root, $elem ) {
            return 1 if $elem->isa('PPI::Statement::Include') && $elem->version;
            return '';
        }
    );
    croak "Bad condition for PPI::Node->find"
      unless defined $version_stmts;
    return $version_stmts ? @$version_stmts : ();
}

# the 'bitwise' feature may break bitwise operators
# so disable it when bitwise operators are detected
my sub _handle_feature_bitwise ( $self, $doc ) {

    # this only matters for code using bitwise ops
    return unless $doc->find(
        sub ( $root, $elem ) {
            $elem->isa('PPI::Token::Operator') && $elem =~ /\A[&|~^]=?\z/;
        }
    );

    # the `use VERSION` inserted earlier is always the last one in the doc
    my $insert_point       = ( _version_stmts($doc) )[-1];
    my $no_feature_bitwise = PPI::Document->new( \"no feature 'bitwise';\n" );
    $insert_point->insert_after( $_->remove ) for $no_feature_bitwise->elements;

    # also add a TODO comment to warn users
    $insert_point = $insert_point->snext_sibling;
    my $todo_comment = PPI::Document->new( \<<~ 'TODO_COMMENT');

    # IMPORTANT: Please double-check the use of bitwise operators
    # before removing the `no feature 'bitwise';` line below.
    # See manual pages perlfeature (section "The 'bitwise' feature")
    # and perlop (section "Bitwise String Operators") for details.
    TODO_COMMENT
    $insert_point->insert_before( $_->remove ) for $todo_comment->elements;

}

my sub _remove_enabled_features ( $self, $doc, $old_num ) {
    my ( %enabled_in_perl, %enabled_in_code );
    my $bundle = $self->version =~ s/\Av//r;
    @enabled_in_perl{ $feature::feature_bundle{$bundle}->@* } = ();

    # extra features to remove, not listed in %feature::feature_bundle
    my $bundle_num = version->parse( $self->version )->numify;
    @enabled_in_perl{qw( postderef lexical_subs )} = ()
      if $bundle_num >= 5.026;

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

    # handle specific features
    _handle_feature_bitwise( $self, $doc )
      if $old_num < 5.028               # code from before 'bitwise'
      && $bundle_num >= 5.028           # bumped to after 'bitwise'
      && !$enabled_in_code{bitwise};    # and not enabling the feature

    # drop experimental warnings, if any
    for my $warn_line ( grep $_->type eq 'no', _find_include( warnings => $doc ) ) {
        my @old_args = _ppi_list_to_perl_list( $warn_line->arguments );
        next unless grep /\Aexperimental::/, @old_args;
        my @new_args = grep !exists $enabled_in_perl{s/\Aexperimental:://r},
          grep /\Aexperimental::/, @old_args;
        my @keep_args = grep !/\Aexperimental::/, @old_args;
        next if @new_args == @old_args;    # nothing to remove
        if ( @new_args || @keep_args ) {   # replace old statement
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
    if ( $bundle_num >= 5.012 ) {
        _drop_bare( use => strict => $doc );
    }

    # warnings are automatically enabled with 5.36
    # no indirect is not needed any more
    if ( $bundle_num >= 5.036 ) {
        _drop_bare( use => warnings => $doc );
        _drop_bare( no  => indirect => $doc );
    }

    return;
}

my sub _insert_version_stmt ( $self, $doc, $old_num = version->parse( 'v5.8' )->numify ) {
    my $version_stmt =
      PPI::Document->new( \sprintf "use %s;\n", $self->version );
    my $insert_point = $doc->schild(0);

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
    else {
        $insert_point->insert_before( $_->remove ) for $version_stmt->elements;
    }

    # cleanup features enabled by the new version
    _remove_enabled_features( $self, $doc, $old_num );
}

my sub _try_compile ( $file ) {

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

my sub _try_bump_ppi_safely ( $self, $doc, $version_limit ) {
    my $version  = version->parse( $self->version );
    my $filename = $doc->filename;
    $version_limit = version->parse($version_limit);

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
          version->parse( 'v5.' . ( ( split /\./, $version )[1] - 2 ) );
    }

    return $version;
}

# PUBLIC METHOS

sub bump_ppi ( $self, $doc ) {
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
            my ( $old_num, $new_num ) = map version->parse($_)->numify,
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

sub bump ( $self, $code, $source = 'input code' ) {
    return $code unless length $code;    # don't touch the empty string

    my $doc = PPI::Document->new( \$code );
    croak "Parsing failed" unless defined $doc;

    return $self->bump_ppi($doc)->serialize;
}

sub bump_file ( $self, $file ) {
    $file = Path::Tiny->new($file);
    my $code   = $file->slurp;
    my $bumped = $self->bump( $code, $file );
    if ( $bumped ne $code ) {
        $file->spew($bumped);
        return !!1;
    }
    return;
}

sub bump_file_safely ( $self, $file, $version_limit = undef ) {
    $file = Path::Tiny->new($file);
    my $code = $file->slurp;
    my $doc  = PPI::Document->new( \$code, filename => $file );
    croak "Parsing failed" unless defined $doc;
    $version_limit //= do {
        my @version_stmts = _version_stmts($doc);
        @version_stmts
          ? version->parse( $version_stmts[0]->version )->normal =~ s/\.0\z//r
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

=head1 ATTRIBUTES

=head2 version

The target version to bump to.

The constructor accepts both forms of Perl versions, regular
(e.g. C<v5.36>) and floating-point (e.g. C<5.036>).

To protect against simple mistaks (e.g. passing C<5.36> instead of
C<v5.36>), the constructor does some sanity checking, and checks that
the given version:

=over 4

=item *

is greater than or equal to C<v5.10>,

=item *

is lower than the version of the Perl currently running,

=item *

is even (this module targets stable Perl versionsi only).

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

=cut
