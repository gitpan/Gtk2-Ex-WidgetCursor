#!/usr/bin/perl

# Copyright 2010 Kevin Ryde

# TestWithoutGtk2Things.pm is shared by several distributions.
#
# TestWithoutGtk2Things.pm is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# TestWithoutGtk2Things.pm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with TestWithoutGtk2Things.pm.  If not, see <http://www.gnu.org/licenses/>.

package TestWithoutGtk2Things;
use strict;
use warnings;

sub import {
  my ($class, @functions) = @_;
  my $verbose = 0;
  my $count = 0;

  foreach my $thing (@functions) {
    if ($thing eq 'verbose') {
      $verbose++;

    } elsif ($thing eq 'insert_with_values') {
      require Gtk2;
      print STDERR "TestWithoutGtk2Things: without ListStore,TreeStore $thing per Gtk pre-2.6\n";
      $count++;

      Gtk2::ListStore->can('insert_with_values'); # force autoload
      Gtk2::TreeStore->can('insert_with_values'); # force autoload

      { no warnings 'once';
        undef *Gtk2::ListStore::insert_with_values;
        undef *Gtk2::TreeStore::insert_with_values;
      }
      
      if (Gtk2::ListStore->can('insert_with_values')) {
        die 'Oops, Gtk2::ListStore can still insert_with_values()';
      }
      if (Gtk2::TreeStore->can('insert_with_values')) {
        die 'Oops, Gtk2::ListStore can still insert_with_values()';
      }
      
      {
        my $store = Gtk2::ListStore->new ('Glib::String');
        if (eval { $store->insert_with_values(0, 0=>'foo'); 1 }) {
          die 'Oops, Gtk2::ListStore can store->insert_with_values()';
        }
      }
      {
        my $store = Gtk2::TreeStore->new ('Glib::String');
        if (eval { $store->insert_with_values(undef, 0, 0=>'foo'); 1 }) {
          die 'Oops, Gtk2::TreeStore can store->insert_with_values()';
        }
      }
      
    } elsif ($thing eq 'blank-cursor') {
      require Gtk2;
      print STDERR "TestWithoutGtk2Things: without Gtk2::Gdk::CursorType $thing per Gtk pre-2.16\n";
      $count++;
      
      no warnings 'redefine';
      {
        my $orig = Glib::Type->can('list_values'); # force autoload
        *Glib::Type::list_values = sub {
          my ($class, $package) = @_;
          my @result = &$orig (@_);
          if ($package eq 'Gtk2::Gdk::CursorType') {
            @result = grep {$_->{'nick'} ne 'blank-cursor'} @result;
          }
          return @result;
        };
      }
      foreach my $func ('new', 'new_for_display') {
        my $orig = Gtk2::Gdk::Cursor->can($func); # force autoload
        my $new = sub {
          my $cursor_type = $_[-1];
          if ($cursor_type eq 'blank-cursor') {
            require Carp;
            Carp::croak ('TestWithoutGtk2Things: no blank-cursor');
          }
          goto $orig;
        };
        my $func = "Gtk2::Gdk::Cursor::$func";
        no strict 'refs';
        *$func = $new;
      }      
      
    } else {
      die "Unknown thing to disable: $thing";
    }
  }
  if ($verbose) {
    print STDERR "TestWithoutGtk2Things: count $count\n";
  }
}

1;
__END__

=head1 NAME

TestWithoutGtk2Things - disable selected Gtk2 methods for testing

=head1 SYNOPSIS

 perl -MTestWithoutGtk2Things=insert_with_values foo.t

 use TestWithoutGtk2Things 'insert_with_values';

=head1 DESCRIPTION

Work in progress ... !

=head1 SEE ALSO

L<Test::Without::Module>

=head1 COPYRIGHT

Copyright 2010 Kevin Ryde

F<TestWithoutGtk2Things.pm> is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option) any
later version.

F<TestWithoutGtk2Things.pm> is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along with
F<TestWithoutGtk2Things.pm>.  If not, see L<http://www.gnu.org/licenses/>.

=cut
