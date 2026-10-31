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
    my ( @ws_before, @ws_after, @nl );
    my %has;    # keep track of the other content on the line

    # record non-significant elements before the statement
    my $prev = $stmt;
    while ( $prev = $prev->previous_sibling ) {
        $has{stmt_before}++, last
          if $prev->significant;
        last if $prev =~ /\n\z/;
        push @ws_before, $prev;
    }

    # record non-significant elements until newline (included) or statement
    my $next = ($stmt);
  AFTER:
    while ( $next = $next->next_sibling ) {
        if ( $next->significant ) {    # might be a compound statement
            for my $child ( $next->children ) {
                last if $child->significant;
                push @ws_after, $child;
                last AFTER if $child =~ /\n\z/;
            }
            $has{stmt_after}++;
            last;
        }
        $has{comment_kept}++, last     # keep comment
          if $next->isa('PPI::Token::Comment') && $keep_comments;
        push @ws_after, $next;
        last if $next =~ /\n\z/;
    }

    # keep the final newline separate, if any
    push @nl, pop @ws_after if $ws_after[-1] =~ /\n\z/;

    # collect everything we want to drop
    my @to_drop = ($stmt);
    push @to_drop, @ws_before
      if $has{stmt_before}
      || ( !$has{stmt_after} && !$has{comment_kept} );
    push @to_drop, @ws_after
      if !$has{stmt_before}
      || ( !$has{stmt_after} && !$has{comment_kept} );
    push @to_drop, @nl
      if !$has{stmt_before} && !$has{stmt_after};

    # and drop it all
    $_->remove for @to_drop;
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

Remove the PPI statement passed as an argument from its parent document.

C<$keep_comments> is a boolean argument indicating if the end-of-line
comments immediately following the statement should be preserved or not
(the default is false).

Indentation is kept if anything other than the statement remains on the
line (e.g., another statement or end-of-line comment).

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2024-2026 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
