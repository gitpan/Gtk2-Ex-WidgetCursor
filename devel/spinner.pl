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


# Some experimenting with Gtk2::Entry.


use strict;
use warnings;
use Gtk2 '-init';
use Gtk2::Ex::WidgetCursor;
use Data::Dumper;

my $toplevel = Gtk2::Window->new ('toplevel');
$toplevel->signal_connect (destroy => sub {
                             print __FILE__.": quit\n";
                             Gtk2->main_quit;
                           });

my $vbox = Gtk2::VBox->new;
$toplevel->add ($vbox);

my $eventbox = Gtk2::EventBox->new;
$vbox->pack_start ($eventbox, 1,1,0);

my $adj = Gtk2::Adjustment->new (0, -100, 100, 1, 10, 10);
my $spin = Gtk2::SpinButton->new ($adj, 10, 0);
$spin->set_name ('myspinner');
print "spinner initial flags ",$spin->flags,"\n";

$eventbox->add ($spin);

{
  my $wc = Gtk2::Ex::WidgetCursor->new (widget => $spin,
                                        cursor => 'umbrella');
  my $check = Gtk2::CheckButton->new_with_label ("Umbrella");
  $check->signal_connect
    ('notify::active' => sub {
       print __FILE__.": set umbrella ",$check->get_active,"\n";
       $wc->active ($check->get_active);
     });
  $vbox->pack_start ($check, 1,1,0);
}
{
  my $button = Gtk2::Button->new_with_label ("Busy Shortly");
  $button->signal_connect
    (clicked => sub {
       Glib::Timeout->add (1000, sub {
                             print __FILE__.": busy\n";
                             Gtk2::Ex::WidgetCursor->busy;
                             sleep (4);
                             return 0; # stop timer
                           });
     });
  $vbox->pack_start ($button, 1,1,0);
}

$toplevel->show_all;

print "Spin sibling windows ",
  Dumper ([ Gtk2::Ex::WidgetCursor::_widget_sibling_windows ($spin) ]);

$spin->signal_connect
  (map_event => sub {

     printf "eventbox win %#x\n",$eventbox->window->XID;

     my $win = $spin->window;
     # $win->set_cursor (Gtk2::Gdk::Cursor->new ('boat'));
     my ($width,$height) = $win->get_size;
     print __FILE__.": spinner\n";
     print "  flags ",$spin->flags,"\n";
     print "  window ",sprintf('%#x',$win->XID),
       " ${width}x${height} ",$win->get_window_type,"  $win\n";

     foreach my $win ($win->get_children) {
       my ($width,$height) = $win->get_size;
       print "    subwin ",sprintf('%#x',$win->XID),
         " ${width}x${height} ",$win->get_window_type,"  $win\n";
       # $win->set_cursor (Gtk2::Gdk::Cursor->new ('umbrella'));
     }
   });
$spin->signal_connect
  (state_changed => sub { print __FILE__,": state_changed ",Dumper(\@_); });

Gtk2->main;
exit 0;
