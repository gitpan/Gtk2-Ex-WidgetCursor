#!/usr/bin/perl

# Copyright 2010 Kevin Ryde

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
use Test::More;

use lib 't';
use MyTestHelpers;

BEGIN {
  require Gtk2;
  Gtk2->disable_setlocale;  # leave LC_NUMERIC alone for version nums
  Gtk2->init_check
    or plan skip_all => 'due to no DISPLAY available';

  plan tests => 3;

 SKIP: { eval 'use Test::NoWarnings; 1'
           or skip 'Test::NoWarnings not available', 1; }
}

{
  package MyOverloadWidget;
  use Glib::Object::Subclass 'Gtk2::DrawingArea';
  use Carp;
  use overload '+' => \&add, fallback => 1;
  sub add {
    my ($x, $y, $swap) = @_;
    croak "I am not in the adding mood";
  }
}

require Gtk2::Ex::WidgetCursor;

{
  my $widget = MyOverloadWidget->new;
  ok (! eval { my $x = $widget+0; 1 },
      'widget+0 throws error');

  my $toplevel = Gtk2::Window->new;
  $toplevel->add ($widget);
  $toplevel->show_all;
  MyTestHelpers::main_iterations();

  my $wobj = Gtk2::Ex::WidgetCursor->new (widgets => [$toplevel,$widget],
                                          active => 1,
                                          include_children => 1,
                                          cursor => 'invisible');
  Gtk2::Ex::WidgetCursor->busy;

  $toplevel->destroy;
  ok (1);
}

exit 0;
