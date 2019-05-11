package AmuseWikiFarm::Controller::Category;
use Moose;
with qw/AmuseWikiFarm::Role::Controller::HumanLoginScreen
        AmuseWikiFarm::Role::Controller::Listing/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use AmuseWikiFarm::Utils::Amuse qw/muse_naming_algo/;
use AmuseWikiFarm::Log::Contextual;

=head1 NAME

AmuseWikiFarm::Controller::Category - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 Category listing

=head3 authors

The list of authors

=head3 authors/<name>

Details about the author <name>

=head3 topics

The list of topics

=head3 topics/<name>

=cut

sub root :Chained('/site') :PathPart('') :CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->stash(please_index => 1);
}

sub legacy_topics :Chained('root') :PathPart('topics') :Args {
    my ($self, $c, @args) = @_;
    $c->detach(legacy_category =>  [ topic => @args ]);
}

sub legacy_authors :Chained('root') :PathPart('authors') :Args {
    my ($self, $c, @args) = @_;
    $c->detach(legacy_category => [ author => @args ]);
}

sub legacy_category :Private {
    my ($self, $c, @args) = @_;
    my $uri;
    my %map = (
               1 => 'category_list_display',
               2 => 'single_category_display',
               3 => 'single_category_by_lang_display',
              );
    if (my $action = $map{scalar(@args)}) {
        $c->response->redirect($c->uri_for_action("/category/$action", \@args),
                               301);
        $c->detach;
    }
    else {
        $c->detach('/not_found');
    }
}



sub category :Chained('root') :PathPart('category') :CaptureArgs(1) {
    my ($self, $c, $type) = @_;
    my $name;
    if ($type eq 'topic') {
        $name = $c->loc('Topics');

    }
    elsif ($type eq 'author') {
        $name = $c->loc('Authors');
    }
    else {
        $c->detach('/not_found');
        return;
    }
    my $site = $c->stash->{site};
    my %search;
    if ($c->user_exists) {
        $search{deferred} = 1;
    }
    elsif ($site->show_preview_when_deferred) {
        $search{deferred_with_teaser} = 1;
    }
    my $rs = $site->categories->by_type($type)
      ->with_active_flag_on
      ->with_texts(%search,
                   sort => $c->req->params->{sorting});
    $c->stash(
              page_title => $name,
              nav => $type,
              categories_rs => $rs,
              f_class => $type,
              breadcrumbs  => [
                               {
                                uri => $c->uri_for_action('/category/category_list_display',
                                                          [ $type ]),
                                label => $name,
                               }
                              ],
             );
}

sub category_list_display :Chained('category') :PathPart('') :Args(0) {
    my ($self, $c) = @_;
    my $list = $c->stash->{categories_rs}->listing_tokens;
    Dlog_debug { "List is $_" } $list;
    $c->stash(list => $list,
              template => 'category.tt');
}

sub select_texts :Chained('category') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $uri) = @_;
    my $canonical = muse_naming_algo($uri);
    my $cat = $c->stash->{categories_rs}->find({ uri => $canonical });
    my $site = $c->stash->{site};
    if ($cat) {
        log_debug { "Category id is " . $cat->id; };
        if ($cat->uri ne $uri) {
            $c->response->redirect($c->uri_for($cat->full_uri));
            $c->detach();
            return;
        }
        my $texts_rs = $cat->titles->texts_only;
        $c->stash(texts => $texts_rs,
                  category_object => $cat,
                  category_uri => $canonical,
                 );
    }
    else {
        $c->stash(uri => $canonical);
        $c->detach('/not_found');
    }
}

# chained from AmuseWikiFarm::Role::Controller::Listing;

sub single_category :Chained('filter_texts') :PathPart('') :CaptureArgs(0) {
    my ($self, $c) = @_;
    my $cat = delete $c->stash->{category_object};
    my $uri = delete $c->stash->{category_uri};
    my $site = $c->stash->{site};

        my $current_locale = $c->stash->{current_locale_code};
        my $category_description = $cat->localized_desc($current_locale);
        # the unescaping happens when calling $c->loc
        my $page_title = $c->stash->{lh}->site_loc($cat->name);
        $c->stash(page_title => $page_title,
                  template => 'category-details.tt',
                  category_canonical_name => $uri,
                  category_description => $category_description,
                  meta_description => ( $category_description ? $category_description->html_body : $page_title),
                  category => $cat);
        # Prepare the links for multisite, if needed
        my $multi = {
                         cat_uri_all => $c->uri_for_action('/category/single_category_display',
                                                           [ $c->stash->{f_class}, $uri ]),
                         cat_uri_lang => $c->uri_for_action('/category/single_category_by_lang_display',
                                                            [
                                                             $c->stash->{f_class},
                                                             $uri,
                                                             $current_locale,
                                                            ]),
                         cat_lang_name => $c->stash->{current_locale_name},
                         default_lang_code => $current_locale,
                         active => $site->multilanguage ? 1 : 0,
                        };
        $c->stash(multilang => $multi);

        push @{$c->stash->{breadcrumbs}},
          {
           uri => $c->uri_for_action('/category/single_category_display',
                                     [ $c->stash->{f_class}, $uri ]),
           label => $c->stash->{lh}->site_loc($cat->name),
          };

}



sub single_category_display :Chained('single_category') :PathPart('') :Args(0) {
    my ($self, $c) = @_;
    my @args = ($c->stash->{f_class},
                $c->stash->{category_canonical_name});
    $self->_stash_pager($c,
                        '/category/single_category_display',
                        @args);
}

sub single_category_by_lang :Chained('single_category') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $lang) = @_;
    my $texts = delete $c->stash->{texts};
    if ($lang eq 'edit' or $lang eq 'delete') {
        $c->response->redirect($c->uri_for_action('/category/edit_category_description',
                                                  [
                                                   $c->stash->{f_class},
                                                   $c->stash->{category_canonical_name},
                                                   $c->stash->{current_locale_code},
                                                  ]));
        $c->detach();
        return;
    }
    elsif (my $category_lang = $c->stash->{site}->known_langs->{$lang}) {
        my $category_description = $c->stash->{category}->localized_desc($lang);
        my $filtered = $texts->search({ lang => $lang });
        $c->stash(
                  texts => $filtered,
                  category_language => $lang,
                  category_description => $category_description,
                 );

        if ($category_description) {
            $c->stash(meta_description => $category_description->html_body);
        }
        $c->stash->{multilang}->{filtered} = $category_lang;
        $c->stash->{multilang}->{code} = $lang;
        $c->stash->{multilang}->{active} = 1;
        if ($c->stash->{multilang}->{code} ne $c->stash->{multilang}->{default_lang_code}) {
            $c->stash->{multilang}->{cat_uri_selected} =
              $c->uri_for_action('/category/single_category_by_lang_display',
                                 [ $c->stash->{f_class}, $c->stash->{category_canonical_name}, $lang ]);
        }
    }
    else {
        $c->detach('/not_found');
    }
}

sub single_category_by_lang_display :Chained('single_category_by_lang') :PathPart('') :Args(0) {
    my ($self, $c) = @_;
    my @args = ($c->stash->{f_class},
                $c->stash->{category_canonical_name},
                $c->stash->{category_language});
    $self->_stash_pager($c, '/category/single_category_by_lang_display', @args);
}

sub category_editing_auth :Chained('single_category_by_lang') :PathPart('') :CaptureArgs(0) {
    my ($self, $c) = @_;
    if ($self->check_login($c)) {
        return 1;
    }
    else {
        die "Unreachable";
    }
}

sub edit_category_description :Chained('category_editing_auth') :PathPart('edit') :Args(0) {
    my ($self, $c) = @_;
    my $lang = $c->stash->{category_language};
    if ($lang && $c->request->body_params->{update}) {
        if (my $muse = $c->request->body_params->{desc_muse}) {
            $c->stash->{category}->category_descriptions
              ->update_description($lang, $muse, $c->user->get('username'));
        }
        my $dest = $c->uri_for_action('/category/single_category_by_lang_display',
                                      [ $c->stash->{f_class},
                                        $c->stash->{category}->uri,
                                        $lang,
                                      ]);
        $c->response->redirect($dest);
        $c->detach();
        return;
    }
    else {
        $c->stash(
                  template => 'category-details-edit.tt',
                  load_markitup_css => 1,
                 );
    }
}

sub delete_category_by_lang :Chained('category_editing_auth') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;
    my @args = ($c->stash->{f_class},
                $c->stash->{category_canonical_name},
                $c->stash->{category_language});
    my $action = '/category/single_category_by_lang_display';
    if ($c->request->body_params->{delete}) {
        if (my $cat = $c->stash->{category_description}) {
            log_info { "Deleting description for " . $cat->category->name .
                         " (" . $cat->lang . ") by " . $c->user->get('username')};

            $cat->delete;
        }
    }
    else {
        # it's a get, bounce to edit
        $action = '/category/edit_category_description';
    }
    my $ret = $c->uri_for_action($action, \@args);
    $c->response->redirect($ret);
}


=encoding utf8

=head1 AUTHOR

Marco Pessotto <melmothx@gmail.com>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
