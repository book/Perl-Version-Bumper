use v5.10;

package Perl::Version::Bumper::Helper::PPI;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw(
    drop_statement
);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub drop_statement {
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
        my ( $next, @to_drop ) = ($stmt);
        while ( $next = $next->next_sibling ) { 
            if ( $next->significant ) {    # might be a compound statement
                for my $child ( $next->children ) {
                    last if $child->significant;
                    push @to_drop, $child;
                    last if $child =~ /\n\z/;
                }
                last;
            }
            push @to_drop, $next;
	    last if $next =~ /\n\z/;
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

1;

__END__

=head1 NAME

Perl::Version::Bumper::Helper::PPI - Basic PPI editing function

=head1 SYNOPSIS

    use Perl::Version::Bumper::Helper::PPI ':all';

    # drop the first use/require/no line in a document
    my $stmt = $doc->find( 'PPI::Statement::Include' )->[0];
    drop_statement( $stmt );

=head1 DESCRIPTION

This module provides a collection of helper functions used by
L<Perl::Version::Bumper> to edit L<PPI> documents.

All the functions can be exported by name. None are exported by default.

=head1 FUNCTIONS

The following I<functions> can be optionally exported.
The C<:all> export tag will export them all at once.

=head2 drop_statement

    drop_statement( $stmt, $keep_comments );

Remove the PPI statement passed as an argument from its document.
The preceding whitespace is removed, as well as any non-significant
tokens after (white space and comments).

C<$keep_comments> is a boolean argument indicating if the end-of-line
comments following the statement should be preserved or not (the default
is false, meaning the comments will be removed).

When the statement is not the only significant code on the line, 

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2024-2026 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
