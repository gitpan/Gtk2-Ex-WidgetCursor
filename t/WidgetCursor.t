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
use Test::More tests => 11;

use Scalar::Util;
use Gtk2;
use Gtk2::Ex::WidgetCursor;

ok ($Gtk2::Ex::WidgetCursor::VERSION >= 1);
ok (Gtk2::Ex::WidgetCursor->VERSION >= 1);

SKIP: {
  if (! Gtk2->init_check) { skip 'due to no DISPLAY available', 9; }


  #---------------------------------------------------------------------------
  # invisible_cursor

  # Perl-Gtk2 1.181 prints warnings for undef (ie. NULL) to
  # Gtk2::Gdk::Display->open, so use an actual name
  #
  my $display_name = Gtk2::Gdk::Display->get_default->get_name;

  # same invisible object on repeat calls
  is (Gtk2::Ex::WidgetCursor->invisible_cursor(),
      Gtk2::Ex::WidgetCursor->invisible_cursor());

  # different invisible object on different displays
  {
    my $d1 = Gtk2::Gdk::Display->get_default;
    my $d2 = Gtk2::Gdk::Display->open ($display_name);
    my $c1 = Gtk2::Ex::WidgetCursor->invisible_cursor ($d1);
    my $c2 = Gtk2::Ex::WidgetCursor->invisible_cursor ($d2);
    isnt ($c1, $c2);
  }

  # an invisible cursor hung on a display doesn't keep that object alive
  # forever
  {
    my $d = Gtk2::Gdk::Display->open ($display_name);
    my $c = Gtk2::Ex::WidgetCursor->invisible_cursor ($d);
    my $weak = $d;
    Scalar::Util::weaken ($weak);
    $d->close;
    $d = undef;
    ok (! defined $weak);
  }

  #---------------------------------------------------------------------------
  # WidgetCursor

  # WidgetCursor should be garbage collected
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    my $weak = $wobj;
    Scalar::Util::weaken ($weak);
    $wobj = undef;
    ok (! defined $weak);
  }

  # WidgetCursor on a realized widget should be garbage collected
  {
    my $widget = Gtk2::Window->new ('toplevel');
    $widget->show;
    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    my $weak = $wobj;
    Scalar::Util::weaken ($weak);
    $wobj = undef;
    ok (! defined $weak);
  }

  # WidgetCursor doesn't keep widget alive forever
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widget => $widget);
    my $weak = $widget;
    Scalar::Util::weaken ($weak);
    $widget = undef;
    ok (! defined $weak);
  }

  # WidgetCursor doesn't keep widgets array alive forever
  {
    my $widget1 = Gtk2::Label->new ('hi');
    my $widget2 = Gtk2::Label->new ('bye');
    my $wobj = Gtk2::Ex::WidgetCursor->new (widgets => [$widget1, $widget2]);

    my $weak1 = $widget1;
    Scalar::Util::weaken ($weak1);
    $widget1 = undef;
    ok (! defined $weak1);

    my $weak2 = $widget2;
    Scalar::Util::weaken ($weak2);
    $widget2 = undef;
    ok (! defined $weak2);
  }

  # WidgetCursor add_widgets doesn't keep widget alive forever
  {
    my $widget = Gtk2::Label->new ('hi');
    my $wobj = Gtk2::Ex::WidgetCursor->new;
    $wobj->add_widgets ($widget);
    my $weak = $widget;
    Scalar::Util::weaken ($weak);
    $widget = undef;
    ok (! defined $weak);
  }

};

exit 0;
