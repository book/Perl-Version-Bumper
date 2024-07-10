package Perl::Version::Bumper;

use v5.28;
use warnings;
use Sub::StrictDecl;
use Path::Tiny;
use PPI::Document;
use Carp qw( carp croak );

use Moo;
use namespace::clean;

use experimental 'signatures';

has version => (
    is      => 'ro',
    default => 'v5.28',
);

my $base_minor = 40;     # Perl 5.40.0 was released
my $base_year  = 124;    # in 2024 (offset by 1900)

around BUILDARGS => sub ( $orig, $class, @args ) {
    my $args = $class->$orig(@args);
    if ( $args->{version} ) {
        my $version = version->parse( $args->{version} );
        my ( $major, $minor ) = $version->{version}->@*;
        croak "Major version number must be 5, not $major"
          if $major != 5;
        croak "Minor version number must be even, not $minor"
          if $minor % 2;
        my $latest_minor = $base_minor + ( (localtime)[5] - $base_year ) * 2;
        croak sprintf
          "Minor version number $minor > %d (is the year %d already?)",
          $latest_minor, 1900 + $base_year + ( $minor - $base_minor ) / 2
          if $minor > $latest_minor;
        $args->{version} = $version->normal =~ s/\.0\z//r;
    }
    $args;
};

my sub _insert_version_stmt ( $self, $doc ) {
    my $version_stmt =
      PPI::Document->new( \sprintf "use %s;\n", $self->version );
    my $insert_point = $doc->schild(0);
    $insert_point->insert_before( $_->remove ) for $version_stmt->elements;
}

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
              my ( $old_str, $new_str ) = ( $use_v->version, $self->version );
            if ( $old_num <= $new_num && $old_str ne $new_str ) {

                # remove non-significant elements since previous newline
                while ( my $prev_sibling = $use_v->previous_sibling ) {
                    last if $prev_sibling->significant;
                    last if $prev_sibling =~ /\n\z/;
                    $prev_sibling->remove;
                }

                # remove non-significant elements until next newline (included)
                while ( my $next_sibling = $use_v->next_sibling ) {
                    last if $next_sibling->significant;
                    my $content = $next_sibling->content;
                    $next_sibling->remove;
                    last if $content eq "\n";
                }
                $use_v->remove;
                _insert_version_stmt( $self, $doc );
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
