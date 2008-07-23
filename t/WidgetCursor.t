# Copyright 2007, 2008 Kevin Ryde

# This file is part of Gtk2-Ex-WidgetCursor.
#
# Gtk2-Ex-WidgetCursor is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# Gtk2-Ex-WidgetCursor is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gtk2-Ex-WidgetCursor.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Test::More tests => 16;

use Scalar::Util;
use Gtk2;
use Gtk2::Ex::WidgetCursor;

ok ($Gtk2::Ex::WidgetCursor::VERSION >= 5);
ok (Gtk2::Ex::WidgetCursor->VERSION >= 5);

sub main_iterations {
  my $count = 0;
  while (Gtk2->events_pending) {
    $count++;
    Gtk2->main_iteration_do (0);
  }
  print "main_iterations(): ran $count events/iterations\n";
}

SKIP: {
  if (! Gtk2->init_check) { skip 'due to no DISPLAY available', 14; }


  # In Perl-Gtk2 before 1.183, passing undef, ie. NULL, to
  # Gtk2::Gdk::Display->open() prints warnings, so do it with an actual
  # $display_name string.
  #
  my $default_display = Gtk2::Gdk::Display->get_default;
  my $display_name = $default_display->get_name;

  # same invisible object on repeat calls
  is (Gtk2::Ex::WidgetCursor->invisible_cursor(),
      Gtk2::Ex::WidgetCursor->invisible_cursor());

  # different invisible object on different displays
 SKIP: {
    my $d1 = $default_display;
    my $d2 = Gtk2::Gdk::Display->open ($display_name);
    if ($d1 == $d2) {
      skip 'due to only one GdkDisplay available', 1;
    }
    my $c1 = Gtk2::Ex::WidgetCursor->invisible_cursor ($d1);
    my $c2 = Gtk2::Ex::WidgetCursor->invisible_cursor ($d2);
    isnt ($c1, $c2);
  }

  # an invisible cursor hung on a display doesn't keep that object alive
  # forever
 SKIP: {
    require Scalar::Util;
    my $d = Gtk2::Gdk::Display->open ($display_name);
    if ($d == $default_display) {
      skip 'due to only one GdkDisplay available', 1;
    }
    my $c = Gtk2::Ex::WidgetCursor->invisible_cursor ($d);
    my $weak = $d;
    Scalar::Util::weaken ($weak);
    $d->close;
    $d = undef;
    is ($weak, undef);
  }


  # WidgetCursor should be garbage collected
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    Scalar::Util::weaken ($wobj);
    is ($wobj, undef);
  }

  # two WidgetCursors should be garbage collected
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj1 = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    my $wobj2 = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    Scalar::Util::weaken ($wobj1);
    Scalar::Util::weaken ($wobj2);
    is ($wobj1, undef);
    is ($wobj2, undef);
  }

  # WidgetCursor on a realized widget should be garbage collected
  {
    my $widget = Gtk2::Window->new ('toplevel');
    $widget->show;
    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    Scalar::Util::weaken ($wobj);
    is ($wobj, undef);
  }

  # WidgetCursor doesn't keep widget alive forever
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    Scalar::Util::weaken ($widget);
    is ($widget, undef);
  }

  # WidgetCursor doesn't keep widgets array alive forever
  {
    my $widget1 = Gtk2::Label->new ('hi');
    my $widget2 = Gtk2::Label->new ('bye');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widgets => [$widget1, $widget2]);

    Scalar::Util::weaken ($widget1);
    is ($widget1, undef);

    Scalar::Util::weaken ($widget2);
    is ($widget2, undef);
  }

  # WidgetCursor add_widgets doesn't keep widget alive forever
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new;
    $wobj->add_widgets ($widget);
    Scalar::Util::weaken ($widget);
    is ($widget, undef);
  }

  # GtkButton special finding of event window
  {
    my $toplevel = Gtk2::Window->new ('toplevel');
    my $button = Gtk2::Button->new ('hi');
    $toplevel->add ($button);

    my $ewkey = 'Gtk2::Ex::WidgetCursor.event_window';

    $button->realize;
    isa_ok ($button->Gtk2_Ex_WidgetCursor_window, 'Gtk2::Gdk::Window');

    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $button,
                                            active => 1);
    isa_ok ($button->{$ewkey}, 'Gtk2::Gdk::Window');

    $button->unrealize;
    main_iterations();
    ok (! defined $button->{$ewkey},  # only weakened away, not !exists()
        'GtkButton lose cached event_window on unrealize');
    my $win = $button->Gtk2_Ex_WidgetCursor_window;
    is ($win, undef, 'GtkButton no window when unrealized');

    $toplevel->destroy;
  }

  # GtkEntry when unrealized
  {
    my $widget = Gtk2::Entry->new;
    my $win = $widget->Gtk2_Ex_WidgetCursor_window;
    is ($win, undef, 'GtkEntry no window when unrealized');
  }
}

exit 0;
