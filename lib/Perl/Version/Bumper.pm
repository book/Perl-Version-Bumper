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
        croak "Minor version number must be even, not $minor"
          if $minor % 2;
        $args->{version} = $version->normal =~ s/\.0\z//r;
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

my sub _drop_statement ($stmt) {

    # remove non-significant elements before the statement
    while ( my $prev_sibling = $stmt->previous_sibling ) {
        last if $prev_sibling->significant;
        last if $prev_sibling =~ /\n\z/;
        $prev_sibling->remove;
    }

    # remove non-significant elements after the statement
    # if there was no significant element before it on the same line
    $stmt->document->index_locations;
    if (  !$stmt->sprevious_sibling
        || $stmt->sprevious_sibling->location->[0] ne $stmt->location->[0] )
    {
        # remove non-significant elements until next newline (included)
        while ( my $next_sibling = $stmt->next_sibling ) {
            last if $next_sibling->significant;
            my $content = $next_sibling->content;
            $next_sibling->remove;
            last if $content eq "\n";
        }
        $stmt->document->flush_locations;
    }

    # and finally remove it
    $stmt->remove;
}

my sub _drop_bare_use ( $module, $doc ) {
    my $use_module = $doc->find(
        sub ( $root, $elem ) {
            return 1
              if $elem->isa('PPI::Statement::Include')
              && $elem->module eq $module
              && !$elem->arguments;    # bare use module
            return;                    # only top-level
        }
    );
    if ( ref $use_module ) {
        _drop_statement($_) for @$use_module;
    }
    return;
}

my sub _find_use ( $module, $doc ) {
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

my sub _remove_enabled_features ( $self, $doc ) {
    my %enabled;
    my $bundle = $self->version =~ s/\Av//r;
    @enabled{ $feature::feature_bundle{$bundle}->@* } = ();

    # extra features to remove, not listed in %feature::feature_bundle
    my $bundle_num = version->parse( $self->version )->numify;
    @enabled{qw( postderef lexical_subs )} = ()
      if $bundle_num >= 5.026;

    # drop features enabled in this bundle
    for my $module (qw( feature experimental )) {
        for my $use_line ( grep $_->type eq 'use',_find_use( $module => $doc ) ) {
            my @old_args = _ppi_list_to_perl_list( $use_line->arguments );
            my @new_args = grep !exists $enabled{$_}, @old_args;
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

    # drop experimental warnings
    for my $warn_line ( grep $_->type eq 'no', _find_use( warnings => $doc ) ) {
        my @old_args = _ppi_list_to_perl_list( $warn_line->arguments );
        my @new_args = grep !exists $enabled{ s/\Aexperimental:://r }, @old_args;
        next if @new_args == @old_args;    # nothing to remove
        if (@new_args) {    # replace old statement with a smaller one
            my $new_warn_line = PPI::Document->new(
                \"no warnings @{[ join ', ', map qq{'$_'}, @new_args]};" );
            $warn_line->insert_before( $_->remove )
              for $new_warn_line->elements;
            $warn_line->remove;
        }
        else { _drop_statement($warn_line); }
    }

    # strict is automatically enabled with 5.12
    # warnings are automatically enabled with 5.36
    _drop_bare_use( strict   => $doc ) if $bundle_num >= 5.012;
    _drop_bare_use( warnings => $doc ) if $bundle_num >= 5.036;

    return;
}

my sub _insert_version_stmt ( $self, $doc ) {
    my $version_stmt =
      PPI::Document->new( \sprintf "use %s;\n", $self->version );
    my $insert_point = $doc->schild(0);
    $insert_point->insert_before( $_->remove ) for $version_stmt->elements;
    _remove_enabled_features( $self, $doc );
}

# PUBLIC METHOS

sub bump ( $self, $code, $source = 'input code' ) {
    return $code unless length $code;    # don't touch the empty string

    my $doc = PPI::Document->new( \$code );
    croak "Parsing failed" unless defined $doc;

    # find if there's already a version
    my $version_stmts = $doc->find(
        sub ( $root, $elem ) {
            return 1 if $elem->isa('PPI::Statement::Include') && $elem->version;
            return '';
        }
    );

    my $bumped = $code;

    # ERROR
    if ( !defined $version_stmts ) {
        croak "Bad condition for PPI::Node->find";
    }

    # no version statement found, add one
    elsif ( !$version_stmts ) {
        _insert_version_stmt( $self, $doc );
        $bumped = $doc->serialize;
    }

    # found at least one version statement
    else {    # arrayref: found some shit

        # bail out if there's more than one `use VERSION`
        if ( @$version_stmts > 1 ) {
            carp "Found multiple use VERSION statements in $source:"
              . join ', ', map $_->version, @$version_stmts;
        }

        # drop the existing version statement
        # and add the new one at the top
        else {
            my $use_v = shift @$version_stmts;    # there's only one
            my ( $old_num, $new_num ) = map version->parse($_)->numify,
              $use_v->version, $self->version;
            if ( $old_num <= $new_num ) {
                _insert_version_stmt( $self, $doc );
                _drop_statement($use_v);
                $bumped = $doc->serialize;
            }
        }
    }

    return $bumped;
}

sub bump_file ( $self, $path ) {
    $path = Path::Tiny->new($path);
    my $code   = $path->slurp;
    my $bumped = $self->bump( $code, $path );
    $path->spew($bumped) if $bumped ne $code;
}

1;
