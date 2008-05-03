#!/usr/bin/perl

# Copyright 2008 Kevin Ryde

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


# Currently only the busy/open/rebusy gets the watch cursor on the newly
# opened window.

use strict;
use warnings;
use Gtk2 '-init';
use Gtk2::Ex::WidgetCursor;

my $toplevel = Gtk2::Window->new ('toplevel');
$toplevel->set_name ("my_toplevel_1");
$toplevel->signal_connect (destroy => sub {
                             print "busynew.pl: quit\n";
                             Gtk2->main_quit;
                           });

my $vbox = Gtk2::VBox->new;
$toplevel->add ($vbox);

{
  my $button = Gtk2::Button->new_with_label ("Busy and Open");
  $button->signal_connect (clicked => sub {
                             print "run.pl: busy\n";
                             Gtk2::Ex::WidgetCursor->busy;
                             my $toplevel = Gtk2::Window->new ('toplevel');
                             $toplevel->set_size_request (100, 100);

                             print "run.pl: show\n";
                             $toplevel->show_all;
                             sleep (2);

                             print "run.pl: flush\n";
                             $toplevel->get_display->flush;
                             sleep (2);
                           });
  $vbox->pack_start ($button, 1,1,0);
}

{
  my $button = Gtk2::Button->new_with_label ("Busy / Open / Re-Busy");
  $button->signal_connect (clicked => sub {
                             print "run.pl: busy\n";
                             Gtk2::Ex::WidgetCursor->busy;
                             my $toplevel = Gtk2::Window->new ('toplevel');
                             $toplevel->set_size_request (100, 100);
                             $toplevel->show_all;

                             Gtk2::Ex::WidgetCursor->busy;
                             print "run.pl: sleep now\n";
                             sleep (4);
                           });
  $vbox->pack_start ($button, 1,1,0);
}

$toplevel->show_all;
Gtk2->main;
exit 0;
