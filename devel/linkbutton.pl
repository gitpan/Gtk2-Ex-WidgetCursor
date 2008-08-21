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

my $inner_vbox = Gtk2::VBox->new;
$eventbox->add ($inner_vbox);

$inner_vbox->pack_start (Gtk2::Label->new ('hello'),
                         1,1,0);

my $button = Gtk2::LinkButton->new ('http://localhost/index.html');
$button->set_name ('mylinkbutton');
print "LinkButton initial flags ",$button->flags,"\n";
$inner_vbox->pack_start ($button, 1,1,0);

$inner_vbox->pack_start (Gtk2::Label->new ('world'),
                         1,1,0);


{
  my $wc = Gtk2::Ex::WidgetCursor->new (widget => $button,
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
  my $wc = Gtk2::Ex::WidgetCursor->new (widget => $eventbox,
                                        cursor => 'boat');
  my $check = Gtk2::CheckButton->new_with_label ("Boat Outer");
  $check->signal_connect
    ('notify::active' => sub {
       print __FILE__.": set boat ",$check->get_active,"\n";
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

print "LinkButton sibling windows ",
  Dumper ([ Gtk2::Ex::WidgetCursor::_widget_sibling_windows ($button) ]);

Gtk2->main;
exit 0;
