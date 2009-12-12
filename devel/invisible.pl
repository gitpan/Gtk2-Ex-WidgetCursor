#!/usr/bin/perl

# Copyright 2009 Kevin Ryde

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


# A grab bag of cursor things turned on and off and interacting or not.
# Run it and click the buttons and move the mouse around to try stuff.


use strict;
use warnings;
use List::Util;
use Gtk2 '-init';
use Gtk2::Ex::WidgetCursor;

use FindBin;
my $progname = $FindBin::Script;

if (List::Util::first {$_->{'nick'} eq 'blank-cursor'}
    Glib::Type->list_values('Gtk2::Gdk::CursorType')) {
  print "have blank-cursor\n";
} else {
  print "no blank-cursor\n";
}

my $toplevel = Gtk2::Window->new ('toplevel');
$toplevel->signal_connect (destroy => sub {
                             print "$progname: quit\n";
                             Gtk2->main_quit;
                           });

$toplevel->realize;

my $win = $toplevel->window;
my $display = $win->get_display;
my $cursor = Gtk2::Gdk::Cursor->new_for_display ($display, 'blank-cursor');
print $cursor,"\n";
$win->set_cursor ($cursor);

my $pspec = $win->find_property ('cursor');
if ($pspec) {
  print "win has cursor property\n";
  my $get = $win->get('cursor');
  my $type = $get->type;
  print "  $get type='$type'\n";
} else {
  print "no cursor property\n";
}

$toplevel->show_all;
Gtk2->main;
exit 0;
