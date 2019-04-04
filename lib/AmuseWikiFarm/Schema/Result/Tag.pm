use utf8;
package AmuseWikiFarm::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AmuseWikiFarm::Schema::Result::Tag - Nestable tags

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

=head1 TABLE: C<tag>

=cut

__PACKAGE__->table("tag");

=head1 ACCESSORS

=head2 tag_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 site_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 uri

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 parent_tag_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "tag_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "site_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "uri",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "parent_tag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tag_id>

=back

=cut

__PACKAGE__->set_primary_key("tag_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<site_id_uri_unique>

=over 4

=item * L</site_id>

=item * L</uri>

=back

=cut

__PACKAGE__->add_unique_constraint("site_id_uri_unique", ["site_id", "uri"]);

=head1 RELATIONS

=head2 parent_tag

Type: belongs_to

Related object: L<AmuseWikiFarm::Schema::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "parent_tag",
  "AmuseWikiFarm::Schema::Result::Tag",
  { tag_id => "parent_tag_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 site

Type: belongs_to

Related object: L<AmuseWikiFarm::Schema::Result::Site>

=cut

__PACKAGE__->belongs_to(
  "site",
  "AmuseWikiFarm::Schema::Result::Site",
  { id => "site_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 tag_bodies

Type: has_many

Related object: L<AmuseWikiFarm::Schema::Result::TagBody>

=cut

__PACKAGE__->has_many(
  "tag_bodies",
  "AmuseWikiFarm::Schema::Result::TagBody",
  { "foreign.tag_id" => "self.tag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_categories

Type: has_many

Related object: L<AmuseWikiFarm::Schema::Result::TagCategory>

=cut

__PACKAGE__->has_many(
  "tag_categories",
  "AmuseWikiFarm::Schema::Result::TagCategory",
  { "foreign.tag_id" => "self.tag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_titles

Type: has_many

Related object: L<AmuseWikiFarm::Schema::Result::TagTitle>

=cut

__PACKAGE__->has_many(
  "tag_titles",
  "AmuseWikiFarm::Schema::Result::TagTitle",
  { "foreign.tag_id" => "self.tag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tags

Type: has_many

Related object: L<AmuseWikiFarm::Schema::Result::Tag>

=cut

__PACKAGE__->has_many(
  "tags",
  "AmuseWikiFarm::Schema::Result::Tag",
  { "foreign.parent_tag_id" => "self.tag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 categories

Type: many_to_many

Composing rels: L</tag_categories> -> category

=cut

__PACKAGE__->many_to_many("categories", "tag_categories", "category");

=head2 titles

Type: many_to_many

Composing rels: L</tag_titles> -> title

=cut

__PACKAGE__->many_to_many("titles", "tag_titles", "title");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-04-01 14:52:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TJv+dOS58FGiMyuDeHXr+Q

use AmuseWikiFarm::Log::Contextual;
use Text::Amuse::Functions qw/muse_to_object
                              muse_format_line
                             /;

sub children {
    return shift->tags;
}

sub parent {
    return shift->parent_tag;
}

sub is_root {
    return !shift->parent_tag_id;
}

sub ancestors {
    my $self = shift;
    my @ancestors;
    my $rec = $self;
    my $max = 0;
    # max 10 as deep. Seems even too much
    while (++$max < 10 and $rec = $rec->parent) {
        push @ancestors, $rec;
    }
    return @ancestors;
}

sub full_uri {
    my $self = shift;
    my @path = ($self->uri, (map { $_->uri } $self->ancestors));
    return join('/', '', tags => reverse(@path));
}

sub update_from_params {
    my ($self, $params) = @_;
    Dlog_debug { "Updating " . $self->full_uri . " with $_" } $params;
    my $site = $self->site;
    my @locales = $site->supported_locales;
    my $guard = $self->result_source->schema->txn_scope_guard;
    $self->tag_bodies->search({ lang => \@locales })->delete;
    foreach my $lang (@locales) {
        my %body = (
                    title_muse => $params->{'title_' . $lang} || '',
                    body_muse => $params->{'body_' . $lang} || '',
                    lang => $lang,
                   );
        $body{title_html} = muse_format_line(html => $body{title_muse}, $lang);
        $body{body_html} = muse_to_object($body{body_muse})->as_html;
        $self->add_to_tag_bodies(\%body);
    }
    my $parent;
    if ($params->{parent_tag_id} and $site->tags->find($params->{parent_tag_id})) {
        $parent = $params->{parent_tag_id};
    }
    $self->update({ parent_tag_id => $parent });
    $guard->commit;
}

# we do all the languages in a single page, to simplify
sub prepare_form_tokens {
    my $self = shift;
    my @out;
    foreach my $lang ($self->site->supported_locales) {
        my $desc = $self->tag_bodies->find({ lang => $lang });
        push @out, {
                    lang => $lang,
                    title => {
                              param_name => 'title_' . $lang,
                              param_value => $desc ? $desc->title_muse : '',
                             },
                    body => {
                             param_name => 'body_' . $lang,
                             param_value => $desc ? $desc->body_muse : '',
                            },
                    title_html => $desc ? $desc->title_html : '',
                    body_html =>  $desc ? $desc->body_html  : '',
                   };
    }
    return \@out;
}

sub as_html {
    my ($self, $lang, $depth) = @_;
    $depth ||= 0;
    $lang ||= 'en';
    # this is not to be pretty.
    # First, retrieve the body.
    my $root_indent = '  ' x $depth;
    my $indent = $root_indent . '  ';
    my $html = "\n" . $root_indent . "<div>\n";
    if ($depth == 0) {
        my $desc = $self->tag_bodies->not_empty->find_by_lang($lang) ||
          $self->tag_bodies->not_empty->find_by_lang('en');
        my $title = $desc ? $desc->title_html : '';
        my $body = $desc ? $desc->body_html : '';
        $html .= $indent . sprintf('<div><strong>%s</strong></div><div>%s</div>',
                                  $title, $body) . "\n";
    }
    my @list;
    my $titles = $self->titles->published_all;
    while (my $title = $titles->next) {
        push @list, [ $title->author_title, $title->full_uri ];
    }
    my $cats = $self->categories->active_only->sorted;
    while (my $cat = $cats->next) {
        push @list, [ $cat->name, $cat->full_uri ];
    }
    if (@list) {
        $html .= join("",
                      $indent . "<ul>\n",
                      (map { $indent . sprintf(' <li><a href="%s">%s</li>', $_->[1], $_->[0]) . "\n" } @list),
                      $indent . "</ul>\n");
    }

    $depth++;
    if ($depth > 10) {
        log_error { "Recursion too deep! on $html" };
        return $html;
    }
    my $children = $self->children;
    my @children_html;
    while (my $child = $children->next) {
        push @children_html, $child->as_html($lang, $depth);
    }
    if (@children_html) {
        $html .= join("",
                      $indent . "<ul>\n",
                      (map { $indent . '<li>' . $_ . "\n" . $indent . "</li>\n" } @children_html),
                      $indent . "</ul>\n");
    }
    $html .= $root_indent . "</div>";
    return $html;
}

__PACKAGE__->meta->make_immutable;
1;
