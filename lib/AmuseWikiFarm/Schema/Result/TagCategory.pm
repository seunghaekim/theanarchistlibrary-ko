use utf8;
package AmuseWikiFarm::Schema::Result::TagCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AmuseWikiFarm::Schema::Result::TagCategory - Linking table from Tag to Category

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<tag_category>

=cut

__PACKAGE__->table("tag_category");

=head1 ACCESSORS

=head2 tag_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 category_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "tag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tag_id>

=item * L</category_id>

=back

=cut

__PACKAGE__->set_primary_key("tag_id", "category_id");

=head1 RELATIONS

=head2 category

Type: belongs_to

Related object: L<AmuseWikiFarm::Schema::Result::Category>

=cut

__PACKAGE__->belongs_to(
  "category",
  "AmuseWikiFarm::Schema::Result::Category",
  { id => "category_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 tag

Type: belongs_to

Related object: L<AmuseWikiFarm::Schema::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "tag",
  "AmuseWikiFarm::Schema::Result::Tag",
  { tag_id => "tag_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-04-01 14:52:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Vv2pIkXV/q11r5khCKyxiw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;