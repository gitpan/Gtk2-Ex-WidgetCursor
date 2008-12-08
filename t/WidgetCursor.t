#!/usr/bin/perl

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
use Gtk2::Ex::WidgetCursor;
use Test::More tests => 17;

ok ($Gtk2::Ex::WidgetCursor::VERSION >= 7, 'VERSION variable');
ok (Gtk2::Ex::WidgetCursor->VERSION  >= 7, 'VERSION method');

require Gtk2;
diag ("Perl-Gtk2 version ",Gtk2->VERSION);
diag ("Perl-Glib version ",Glib->VERSION);
diag ("Compiled against Glib version ",
      Glib::MAJOR_VERSION(), ".",
      Glib::MINOR_VERSION(), ".",
      Glib::MICRO_VERSION(), ".");
diag ("Running on       Glib version ",
      Glib::major_version(), ".",
      Glib::minor_version(), ".",
      Glib::micro_version(), ".");
diag ("Compiled against Gtk version ",
      Gtk2::MAJOR_VERSION(), ".",
      Gtk2::MINOR_VERSION(), ".",
      Gtk2::MICRO_VERSION(), ".");
diag ("Running on       Gtk version ",
      Gtk2::major_version(), ".",
      Gtk2::minor_version(), ".",
      Gtk2::micro_version(), ".");

sub main_iterations {
  my $count = 0;
  while (Gtk2->events_pending) {
    $count++;
    Gtk2->main_iteration_do (0);
  }
  print "main_iterations(): ran $count events/iterations\n";
}

SKIP: {
  if (! Gtk2->init_check) { skip 'due to no DISPLAY available', 15; }


  # In Perl-Gtk2 before 1.183, passing undef, ie. NULL, to
  # Gtk2::Gdk::Display->open() prints warnings, so do it with an actual
  # $display_name string.
  #
  my $default_display = Gtk2::Gdk::Display->get_default;
  my $display_name = $default_display->get_name;

  # same invisible object on repeat calls
  is (Gtk2::Ex::WidgetCursor->invisible_cursor,
      Gtk2::Ex::WidgetCursor->invisible_cursor);

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

  # add_widgets with weakened undefs in wobj
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widgets => [ $widget ]);
    $widget = Gtk2::Label->new ('bye');
    $wobj->add_widgets ($widget);
  }

  # GtkButton when unrealized
  {
    my $widget = Gtk2::Button->new;
    my @windows = grep {defined} $widget->Gtk2_Ex_WidgetCursor_windows;
    is_deeply (\@windows, [], ref($widget).' no window when unrealized');
  }

  # GtkTextView when unrealized
  {
    my $widget = Gtk2::TextView->new;
    my @windows = grep {defined} $widget->Gtk2_Ex_WidgetCursor_windows;
    is_deeply (\@windows, [], ref($widget).' no window when unrealized');
  }

  # GtkEntry when unrealized
  {
    my $widget = Gtk2::Entry->new;
    my @windows = grep {defined} $widget->Gtk2_Ex_WidgetCursor_windows;
    is_deeply (\@windows, [], ref($widget).' no window when unrealized');
  }

  # GtkSpinButton when unrealized
  {
    my $adj = Gtk2::Adjustment->new (0, -100, 100, 1, 10, 10);
    my $widget = Gtk2::SpinButton->new ($adj, 10, 0);
    my @windows = grep {defined} $widget->Gtk2_Ex_WidgetCursor_windows;
    is_deeply (\@windows, [], ref($widget).' no window when unrealized');
  }
}

exit 0;
