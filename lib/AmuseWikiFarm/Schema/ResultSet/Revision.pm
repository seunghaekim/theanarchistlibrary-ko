package AmuseWikiFarm::Schema::ResultSet::Revision;

use utf8;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';


=head2 pending

Return a list of pending revisions

=cut

sub pending {
    return shift->search({ 'me.status' => 'pending' },
                         { order_by => { -desc => 'updated' }});
}

=head2 not_published

Return a list of revisions not yet published

=cut

sub not_published {
    return shift->search({ 'me.status' => { '!=' => 'published'  } },
                         { order_by => { -desc => 'updated' } });
}


=head2 published_older_than($datetime)

Return the resultset for the published revision older than the
datetime object passed as argument.

=cut

sub published_older_than {
    my ($self, $time) = @_;
    die unless $time && $time->isa('DateTime');
    my $format_time = $self->result_source->schema->storage->datetime_parser
      ->format_datetime($time);
    return $self->search({
                          'me.status' => 'published',
                          updated => { '<' => $format_time },
                         });
}

=head2 as_list

Return an arrayref of the revisions, leaving the uncommitted texts at
the end.

=cut

sub as_list {
    my $self = shift;
    my (@top, @bottom);
    while (my $rev = $self->next) {
        if ($rev->status && $rev->status eq 'pending') {
            push @top, $rev;
        }
        else {
            push @bottom, $rev;
        }
    }
    return [ @top, @bottom ];
}

1;
