# Copyright 2007, 2008 Kevin Ryde

# This file is part of Gtk2-Ex-WidgetCursor.
#
# Gtk2-Ex-WidgetCursor is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2, or (at your option) any
# later version.
#
# Gtk2-Ex-WidgetCursor is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gtk2-Ex-WidgetCursor.  If not, see <http://www.gnu.org/licenses/>.

package Gtk2::Ex::WidgetCursor;
use strict;
use warnings;
use Gtk2;
use List::Util;
use Scalar::Util;

our $VERSION = 1;

# set this to 1 for some diagnostic prints
use constant DEBUG => 0;


#------------------------------------------------------------------------------
# Cribs on widgets using gdk_window_set_cursor directly:
#
# GtkAboutDialog  [not handled]
#     Puts "email" and "link" tags on text in credits GtkTextView and then
#     does set_cursor on entering or leaving those.
#
# GtkCombo        [ok mostly]
#     Does a single set_cursor for a 'top-left-arrow' on a GtkEventBox in
#     its popup when realized.  We dig that out for include_children,
#     primarily so a busy() shows the watch on the popup window if happens
#     to be open at the time.  Of course GtkCombo is one of the
#     ever-lengthening parade of working and well-defined widgets you're not
#     meant to use any more.
#
# GtkCurve        [not handled]
#     Multiple set_cursor calls according to mode and motion.  A rarely used
#     widget so ignore it for now.
#
# GtkEntry        [ok]
#     Uses a private GdkWindow subwindow with a GDK_CURSOR_XTERM when
#     sensitive.  That window isn't presented in the public fields/functions
#     but we can dig it out with $win->get_children.  We treat that
#     subwindow as the widget window, and then do a toggle sensitive to get
#     back the insertion cursor when no more WidgetCursor settings.
#     gdk_window_get_children() is fast since Gtk maintains the list of
#     children itself (as opposed to the way plain Xlib queries the server).
#
#     The subwindow is 4 pixels smaller in height than the enclosing one, so
#     to be perfect we would have to set both windows.  For now the
#     enclosing window ends up inheriting its parent (which isn't too
#     terrible for just 4 pixels).
#
# GtkFileChooser  [probably ok]
#     Sets a GDK_CURSOR_WATCH temporarily when busy.  That probably kills
#     any WidgetCursor setting, but probably GtkFileChooser isn't something
#     you'll manipulate externally.
#
# GtkLabel        [not handled]
#     Puts GDK_XTERM on a private selection window when sensitive and
#     selectable text, or something.  This misses out on include_children
#     for now.
#
# GtkLinkButton   [not handled]
#     A no-window widget which does set_cursor on its windowed parent for
#     entry and leave events, making a mess of any WidgetCursor on that
#     parent.
#
# GtkPaned        [not handled]
#     Puts a cursor on its GdkWindow handle when sensitive.  Not covered by
#     include_children for now.
#
# GtkRecentChooser  [probably ok]
#     A GDK_WATCH when busy, similar to GtkFileChooser above.  Hopefully ok
#     most of the time with no special attention.
#
# GtkStatusBar    [not handled]
#     A cursor on its private grip GdkWindow.
#
# GtkTextView     [ok]
#     Sets a GDK_XTERM insertion point cursor on its "text window", when
#     sensitive.  We treat that as its window and override as necessary,
#     then trick it into putting back the insertion point by toggling
#     "sensitive".
#


#------------------------------------------------------------------------------

# @wobjs is all the WidgetCursor objects which currently exist, sorted from
# highest to lowest priority, and from newest to oldest among those of equal
# priority
#
# Elements are weakened so they don't keep the objects alive.  The DESTROY
# method strips undefs from here, but not sure if undef could still be seen
# in here by certain funcs at certain times.
#
my @wobjs = ();

sub new {
  my ($class, %self) = @_;
  my $self = bless \%self, $class;

  # widget=> and/or widgets=> params merged, copied and weakened
  my @array;
  if (my $widget = delete $self->{'widget'}) { push @array, $widget; }
  if (my $aref = $self->{'widgets'}) { push @array, @{$self->{'widgets'}}; }
  foreach (@array) { Scalar::Util::weaken ($_); }
  $self->{'widgets'} = \@array;
  $self->{'installed_widgets'} = [];

  # insertion in @wobjs according to priority
  my $pos;
  for ($pos = 0; $pos < @wobjs; $pos++) {
    if (($self->{'priority'}||0) >= ($wobjs[$pos]->{'priority'}||0)) {
      last;
    }
  }
  splice @wobjs,$pos,0, $self;
  Scalar::Util::weaken ($wobjs[$pos]);

  if ($self->{'active'}) {
    _wobj_activated ($self);
  }
  return $self;
}

sub DESTROY {
  my ($self) = @_;
  if (DEBUG) { print "DESTROY $self\n"; }
  @wobjs = grep {defined $_ && $_ != $self} @wobjs;
  if ($self->{'active'}) {
    _wobj_deactivated ($self);
  }
}

# get or set "active"
sub active {
  my ($self, $newval) = @_;
  if (@_ < 2) { return $self->{'active'}; }  # get

  # set
  $newval = ($newval ? 1 : 0);  # don't capture arbitrary input
  my $oldval = $self->{'active'};
  $self->{'active'} = $newval;
  if ($oldval && ! $newval) {
    _wobj_deactivated ($self);
  } elsif ($newval && ! $oldval) {
    _wobj_activated ($self);
  }
}

# newly turned off or destroyed
sub _wobj_deactivated {
  my ($self) = @_;
  my $aref = $self->{'installed_widgets'};
  $self->{'installed_widgets'} = [];
  foreach my $widget (@$aref) {
    _update_widget ($widget);
  }
}

# newly turned on or created on
sub _wobj_activated {
  my ($self) = @_;

  if ($self->{'include_children'}) {
    # go through widgets in other wobjs as well as ourselves since they may
    # be affected if they're children of one of ours (%done skips duplicates
    # among the lists)
    my %done;
    foreach my $wobj (@wobjs) {
      foreach my $widget (@{$wobj->{'widgets'}}) {
        $done{$widget} ||= do { _update_widget ($widget); 1 };
      }
    }

    # special handling for children of certain types that might be present
    # deep in the tree
    foreach my $widget (@{$self->{'widgets'}}) {
      if (! $widget) { next; } # possible undef by weakening

      foreach my $widget (_container_recursively ($widget)) {
        if ($widget->isa('Gtk2::Entry')
            || $widget->isa('Gtk2::TextView')
            || _widget_is_combo_eventbox ($widget)) {
          $done{$widget} ||= do { _update_widget ($widget); 1 };
        }
      }
    }

  } else {
    # simple non-include-children for this wobj, look only at its immediate
    # widgets
    foreach my $widget (@{$self->{'widgets'}}) {
      _update_widget ($widget);
    }
  }
}

sub _update_widget {
  my ($widget) = @_;
  if (! $widget) { return; }  # possible undef from weakening
  if (DEBUG) { print "_update_widget $widget  ", $widget->get_name, "\n"; }

  # find wobj with priority on this $widget
  my $wobj = List::Util::first
    { $_->{'active'} && _wobj_applies_to_widget($_,$widget)} @wobjs;

  my $old_wobj = $widget->{__PACKAGE__,'installed'};
  if (DEBUG) { print "  wobj was ",$old_wobj||'undef',
                 " now ",$wobj||'undef',"\n"; }
  if (($wobj||0) == ($old_wobj||0)) { return; } # unchanged

  if (! $wobj) {
    # no wobj applies to this widget any more
    delete $widget->{__PACKAGE__,'installed'};

    # nasty hack to put Gtk2::Entry or Gtk2::TextView back to their
    # GDK_XTERM insertion bar when sensitive and no more WidgetCursor
    # settings
    if (($widget->isa('Gtk2::Entry') || $widget->isa('Gtk2::TextView'))
        && $widget->sensitive) {
      if (DEBUG) { print "  toggle sensitive\n"; }
      $widget->set_sensitive(0);
      $widget->set_sensitive(1);
      return;
    }

    if (my $win = _widget_window ($widget)) {
      my $cursor = undef;

      # hack to put Gtk2::Combo popup back to its normal GDK_TOP_LEFT_ARROW
      if (_widget_is_combo_eventbox ($widget)) {
        $cursor = Gtk2::Gdk::Cursor->new_for_display ($widget->get_display,
                                                      'top-left-arrow');
      }
      if (DEBUG) { print "  set_cursor back to ",$cursor||'undef',"\n"; }
      $win->set_cursor ($cursor);
    }
    return;
  }

  # install wobj on this widget

  my $win = _widget_window ($widget);
  if (! $win) {
    if (DEBUG) { print "  not realized, defer setting\n"; }
    $widget->{__PACKAGE__,'realize_id'} ||=
      $widget->signal_connect (realize => \&_do_widget_realize);
    return;
  }

  # remember this widget under wobj
  { my $aref = $wobj->{'installed_widgets'};
    push @$aref, $widget;
    Scalar::Util::weaken ($aref->[-1]);
  }

  # note this wobj under the widget
  $widget->{__PACKAGE__,'installed'} = $wobj;
  Scalar::Util::weaken ($widget->{__PACKAGE__,'installed'});

  # and finally actually set the cursor
  my $cursor = _resolve_cursor ($wobj, $widget);
  if (DEBUG) { print "  set_cursor ",$cursor||'undef',"\n"; }
  $win->set_cursor ($cursor);
}

# 'realized' handler on a WidgetCursor affected widget
sub _do_widget_realize {
  my ($widget) = @_;
  if (DEBUG) { print "now realized\n"; }
  $widget->signal_handler_disconnect
    (delete $widget->{__PACKAGE__,'realize_id'});
  _update_widget ($widget);
}

# return the window in $widget we'll act on, incorporating hacks for core
# classes with multiple windows
sub _widget_window {
  my ($widget) = @_;
  if ($widget->isa ('Gtk2::TextView')) {
    return $widget->get_window ('text');
  }
  my $win = $widget->window or return undef;
  # for GtkEntry act on the subwindow, but because that subwindow isn't a
  # documented feature check there is indeed a subwindow
  if ($widget->isa('Gtk2::Entry')) {
    my ($subwin) = $win->get_children;
    if ($subwin) { return $subwin; }
  }
  return $win;
}

# Return true if $wobj is applicable to $widget, either because $widget is
# in its widgets list or is a child of one of them for "include_children".
# Note $w->is_ancestor($w) is false, ie. it doesn't include itself.
#
sub _wobj_applies_to_widget {
  my ($wobj, $widget) = @_;
  return List::Util::first
    { defined $_ # possible weakening during destroy
        && ($_ == $widget
            || ($wobj->{'include_children'} && $widget->is_ancestor($_))) }
      @{$wobj->{'widgets'}};
}

# get or set "cursor"
sub cursor {
  my ($self, $newval) = @_;
  if (@_ < 2) { return $self->{'cursor'}; }

  my $oldval = $self->{'cursor'};
  $self->{'cursor'} = $newval;
  if (! $self->{'active'} || _cursor_equal ($oldval, $newval)) { return; }

  foreach my $widget (@{$self->{'installed_widgets'}}) {
    my $win = _widget_window ($widget) or next; # only realized widgets change
    if (DEBUG) { print "wobj cursor update $win\n"; }
    $win->set_cursor (_resolve_cursor ($self, $widget))
  }
}

# return true if two cursor settings $x and $y are the same
sub _cursor_equal {
  my ($x, $y) = @_;
  return ((! defined $x && ! defined $y)      # undef == undef
          || (ref $x && ref $y && $x == $y)   # objects identical address
          || (defined $x && defined $y && $x eq $y));  # strings by value
}

# get widgets in wobj
sub widgets {
  my ($self) = @_;
  return grep {defined} @{$self->{'widgets'}};
}

# add widgets to wobj
sub add_widgets {
  my ($self, @widgets) = @_;
  my $aref = $self->{'widgets'};

  # only those not already in our list
  @widgets = grep { my $widget = @_;
                    ! List::Util::first {$_==$widget} @$aref } @widgets;
  if (! @widgets) { return; }

  foreach my $widget (@widgets) {
    push @$aref, $widget;
    Scalar::Util::weaken ($aref->[-1]);
  }

  if ($self->{'include_children'}) {
    # for include_children must have a deep look down through the new
    # widgets, let the full code of _wobj_activated() do that (though it's a
    # little wasteful to look again at the previously covered widgets)
    _wobj_activated ($self);

  } else {
    # for ordinary only the newly added widgets might change
    foreach my $widget (@widgets) {
      _update_widget ($widget);
    }
  }
}

# return an actual Gtk2::Gdk::Cursor from what may be only a string setting 
sub _resolve_cursor {
  my ($wobj, $widget) = @_;
  my $cursor = $wobj->{'cursor'};

  if (! defined $cursor || ref $cursor) {
    # undef or cursor object
    return $cursor;

  } elsif ($cursor eq 'invisible') {
    # call through $wobj in case someone has subclassed us
    return $wobj->invisible_cursor ($widget);

  } else {
    # string cursor name -- we only ever resolve" here when widget is
    # realized, so get_display() won't be undef
    my $display = $widget->get_display;
    return Gtk2::Gdk::Cursor->new_for_display ($display, $cursor);
  }
}

# return $widget and all its contained children, grandchildren, etc
sub _container_recursively {
  my ($widget) = @_;
  if ($widget->can('get_children')) {
    return $widget, map { (_container_recursively($_)) } $widget->get_children;
  } else {
    return $widget
  }
}

# return true if $widget is the Gtk2::EventBox child of a Gtk2::Combo popup
# window (it's a child of the popup window, not of the Combo itself)
sub _widget_is_combo_eventbox {
  my ($widget) = @_;
  return ($widget->isa('Gtk2::EventBox')
          && $widget->get_parent->get_name eq 'gtk-combo-popup-window');
}


#------------------------------------------------------------------------------

# Could think about documenting this idle level to the world, maybe like the
# following, but would it be any use?
#
# =item C<$Gtk2::Ex::WidgetCursor::busy_idle_priority>
#
# The priority level of the (C<< Glib::Idle->add >>) handler installed by
# C<busy>.  This is C<G_PRIORITY_DEFAULT_IDLE - 10> by default, which is
# designed to stay busy through Gtk resizing and redrawing at around
# C<G_PRIORITY_HIGH_IDLE>, but end the busy before ordinary "default idle"
# tasks.
#
# You can change this depending what things you set running at what idle
# levels and where you consider the application no longer busy for user
# purposes.  But note changing this variable only affects future C<busy>
# calls, not any currently active one.
#
use constant BUSY_IDLE_PRIORITY => Glib::G_PRIORITY_DEFAULT_IDLE - 10;

my $busy_wc;
my $busy_id;

# flush the Gtk2::Gdk::Display's of all the given widgets, if they're mapped
# (with the idea being if they're unmapped there's nothing to see so no need
# to flush)
#
sub _flush_mapped_widgets {
  my %done;
  if (DEBUG) { print "_flush_mapped_widgets:"; }
  foreach my $widget (@_) {
    if ($widget->mapped) {
      my $display = $widget->get_display;
      if (DEBUG) { print "  $display\n"; }
      $done{$display} ||= do { $display->flush; 1 };
    }
  }
}

sub unbusy {
  my ($class) = @_;
  if ($busy_id) {
    Glib::Source->remove ($busy_id);
    $busy_id = undef;
  }
  if ($busy_wc) {
    my @widgets = $busy_wc->widgets;
    $busy_wc = undef;
    # flush to show new cursors immediately, per busy() below
    _flush_mapped_widgets (@widgets);
  }
}

sub busy {
  my ($class) = @_;
  my @widgets = Gtk2::Window->list_toplevels;
  if (DEBUG) { print "busy on toplevels ",join(' ',@widgets),"\n"; }

  if ($busy_wc) {
    $busy_wc->add_widgets (@widgets);
  } else {
    if (DEBUG) { print "$class->busy: new\n"; }
    $busy_wc = $class->new (widgets          => \@widgets,
                            cursor           => 'watch',
                            include_children => 1,
                            priority         => 1000,
                            active           => 1);
  }
  _flush_mapped_widgets (@widgets);
  $busy_id ||= Glib::Idle->add (\&_busy_idle_handler, undef,
                                BUSY_IDLE_PRIORITY);
}

# Call unbusy through $busy_wc to allow for possible subclassing.
# Using unbusy does a flush, which is often unnecessary but will ensure that
# if there's lower priority idles still to act then our cursors go out
# before any time they take.
#
sub _busy_idle_handler {
  my ($widget) = @_;
  if (DEBUG) { print "_busy_idle_handler: finished\n"; }
  $busy_id = undef;
  if ($busy_wc) { $busy_wc->unbusy; }
  return 0; # remove idle handler, one run only
}


#------------------------------------------------------------------------------

sub invisible_cursor {
  my ($class, $target) = @_;
  my $display;

  if (! defined $target) {
    $display = Gtk2::Gdk::Display->get_default
      || die "Gtk2::Ex::WidgetCursor->invisible_cursor(): no default display";

  } elsif ($target->isa('Gtk2::Gdk::Display')) {
    $display = $target;

  } else {
    $display = $target->get_display
      || die "Gtk2::Ex::WidgetCursor->invisible_cursor(): get_display undef on $target";
  }

  return ($display->{__PACKAGE__,'invisible_cursor'}
          ||= do {
            if (DEBUG) { print "invisible_cursor new for $display\n"; }
            my $window = $display->get_default_screen->get_root_window;
            my $mask = Gtk2::Gdk::Bitmap->create_from_data ($window, "\0", 1, 1);
            my $color = Gtk2::Gdk::Color->new (0,0,0);
            Gtk2::Gdk::Cursor->new_from_pixmap ($mask,$mask, $color,$color, 0,0);
          });
}


#------------------------------------------------------------------------------
1;
__END__

=head1 NAME

Gtk2::Ex::WidgetCursor -- mouse pointer cursor management for widgets

=head1 SYNOPSIS

 use Gtk2::Ex::WidgetCursor;
 my $wc = Gtk2::Ex::WidgetCursor->new (widget => $widget,
                                       cursor => 'fleur',
                                       active => 1);

 # show wristwatch while whole program blocked
 Gtk2::Ex::WidgetCursor->busy;

 # bonus invisible cursor creator
 my $cursor = Gtk2::Ex::WidgetCursor->invisible_cursor;

=head1 DESCRIPTION

WidgetCursor manages the mouse pointer cursor shown in widget windows;
ie. the cursor as set by C<Gtk2::Gdk::Window::set_cursor>.  A "busy"
mechanism can display a wristwatch on all windows when the whole application
is blocked.

The plain GdkWindow C<set_cursor> lacks even a corresponding C<get_cursor>,
which makes it difficult for add-ons or independent parts of an application
to cooperate with what cursor should be shown at different times or in
various modes.  To that end a C<Gtk2::Ex::WidgetCursor> object represents a
desired cursor in one or more widgets.  When made "active" and when it's the
newest or highest priority then the specified cursor is set onto those
widget window(s).  If the C<WidgetCursor> object is later made inactive or
destroyed then the next highest C<WidgetCursor> takes effect, etc.

The idea is to have say a base WidgetCursor for an overall widget mode, then
something else temporarily while dragging, an perhaps a wristwatch "busy"
indication trumping one or both (like the global "busy" mechanism below).

The F<examples> subdirectory in the sources has some variously contrived
example programs.

=head1 WIDGETCURSOR OBJECTS

=over 4

=item C<< Gtk2::Ex::WidgetCursor->new (key => value, ...) >>

Create a new C<WidgetCursor> object.  Parameters are taken in key/value
style,

    widget             single widget
    widgets            array reference for multiple widgets
    cursor             string or object
    active             boolean
    priority           default 0
    include_children   boolean

For example,

    $wc = Gtk2::Ex::WidgetCursor->new (widget => $widget,
                                       cursor => 'fleur',
                                       active => 1);

C<cursor> can be any of

=over 4

=item *

A C<Gtk2::Gdk::Cursor> object.  If your program uses multiple displays then
remember the cursor object must be from the same display as the widget(s).

=item *

A string name of a cursor from the C<Gtk2::Gdk::CursorType> enum, such as
C<"hand1"> (see L<Gtk2::Gdk::Cursor> for the full list).

=item *

The special string name C<"invisible"> to have no cursor at all.

=item *

C<undef> to inherit the parent window's cursor, which often means the
default little pointing arrow of the root window.

=back

C<active> can be set to make the new cursor take effect immediately,
otherwise the C<active()> function below turns it on when desired.

C<include_children> means all the children of the given widgets are affected
too.  Normally the cursor in a child widget overrides anything in its
parents (the way C<set_cursor> does at the window level).  But with
C<include_children> a setting in a parent applies to the children too, with
priority level and newest applied as usual.

Optional C<priority> is a number.  The default is level 0 and higher values
are higher priority.  A low value (ie. negative) can act as a fallback, or a
high value can trump other added cursors.

=item C<< $wc->active ([$newval]) >>

Get or set the "active" state of C<$wc>.

=item C<< $wc->cursor ([$cursor]) >>

Get or set the cursor of C<$wc>.  Any cursor setting in the style of C<new>
above can be given.  Eg.

    $wc->cursor ('umbrella');

=item C<< $wc->widgets () >>

Return the widgets currently in C<$wc>.  Eg.

    my @array = $wc->widgets;

or if you know you're only acting on one widget then say

    my ($widget) = $wc->widgets;

=item C<< $wc->add_widgets ($widget, $widget, ...) >>

Add widgets to C<$wc>.  Any widgets already in C<$wc> are ignored.

=back

WidgetCursor objects can operate on unrealized widgets.  The cursor settings
take effect if/when the widgets are realized.

A WidgetCursor object only keeps weak references to its widget(s), so the
mere fact there's a desired cursor won't keep them alive forever.  Garbage
collected widgets drop out of the widgets list set.  In particular this
means it's safe to hold a WidgetCursor within a widget's own hash without
creating a circular reference.  Eg.

    my $widget = Gtk2::DrawingArea->new;
    $widget->{'base_cursor'} = Gtk2::Ex::WidgetCursor->new
                                 (widget => $widget,
                                  cursor => 'hand1',
                                  active => 1,
                                  priority => -10);

=head1 APPLICATION BUSY

C<busy> is a global mechanism setting a watch cursor on all windows to tell
the user the program is doing CPU-intensive work and might not iterate the
main loop to draw or interact for a while.

If your busy state isn't CPU-intensive, but instead say waiting for a timer
or a read from a socket, then this is not what you want, it'll turn off too
soon.  (Instead simply make a C<WidgetCursor> with a C<"watch"> and turn it
on or off at your start and end points; see for instance
F<examples/timebusy.pl> in the sources.)

=over 4

=item C<< Gtk2::Ex::WidgetCursor->busy () >>

Show the C<"watch"> cursor (a little wristwatch) in all the application's
current toplevel and popup windows.  An idle handler
(C<< Glib::Idle->add >>) removes the watch automatically upon returning to
the main loop.

The X queue is flushed to set the cursor immediately, so the program can go
straight into its work.  For example

    Gtk2::Ex::WidgetCursor->busy;
    foreach my $i (1 .. 1_000_000) {
      # do much number crunching
    }

C<busy> uses a C<WidgetCursor> object as described above and so cooperates
with application uses of that.  Priority level 1000 is set to trump other
cursor settings.

=item C<< Gtk2::Ex::WidgetCursor->unbusy () >>

Explicitly remove the watch cursor setup by C<busy> above.  The X request
queue is flushed to ensure any cursor change appears immediately.  If
C<busy> is not active then do nothing.

It's unlikely you'll need C<unbusy>, because if your program hasn't yet
reached the idle handler in the main loop then it's probably still busy!
But perhaps if most of your work is done then you could unbusy while the
remainder is finishing up.

=back

Currently if you open a new toplevel window while in a C<busy> then you must
call C<< Gtk2::Ex::WidgetCursor->busy () >> a second time to make that new
window show the wristwatch.  Perhaps that can be done automatically in the
future, since the intention of C<busy> is to cover all application windows.

=head1 INVISIBLE CURSOR

The following is the C<"invisible"> cursor used by WidgetCursor above, made
available for general use.  Gtk has code for this in C<GtkEntry> and
C<GtkTextView>, but as of Gtk 2.12 doesn't make it available to
applications.

=over 4

=item C<< Gtk2::Ex::WidgetCursor->invisible_cursor ([$target]) >>

Return a C<Gtk2::Gdk::Cursor> object which is invisible, ie. displays no
cursor at all.  This is the sort of "no pixels set" cursor described in the
Gtk reference manual (under C<gdk_cursor_new> for instance).

With no arguments (or C<undef>) the cursor is for the default display per
C<< Gtk2::Gdk::Display->get_default >>.  If your program only uses one
display then that's all you need.

    my $cursor = Gtk2::Ex::WidgetCursor->invisible_cursor;

For multiple displays note that a cursor is a per-display resource, so you
must pass a C<$target>.  This can be a C<Gtk2::Gdk::Display> itself or
anything with a C<get_display> method, which includes C<Gtk2::Widget>,
C<Gtk2::Gdk::Window> (or any C<Gtk2::Gdk::Drawable>), another
C<Gtk2::Gdk::Cursor>, etc.

    my $cursor = Gtk2::Ex::WidgetCursor->invisible_cursor ($widget);

When passing a widget as the target note the display comes from its toplevel
C<Gtk2::Window> parent, so the widget must have been added in as a child
somewhere under a toplevel (or be a toplevel itself of course).  Until then
C<get_display> returns undef and C<invisible_cursor> will croak.

The invisible cursor is cached against the display, so repeated calls don't
make a new one every time.

=back

=head1 LIMITATIONS

WidgetCursor settings are applied to the widget windows without paying
attention to which among them are "no-window" and thus using their parents'
windows.  If different no-window children have a common windowed parent then
WidgetCursor won't notice and the result will probably come out wrong.  For
now it's suggested you either always give a windowed widget, or at least
always the same no-window child.

In the future it might be possible to have cursors on no-window widgets with
WidgetCursor using enter/leave the same way C<Gtk2::LinkButton> does for its
hand cursor.  But windowed widgets are best for cursor settings normally,
since they let the X server take care of the cursor as the mouse moves
around.

Reparenting widgets subject to an C<include_children> probably doesn't quite
work.  If it involves a new realize it probably works, otherwise probably
not.  Moving widgets is unusual, so in practice this isn't too bad.  Doing
the right thing in all cases might need a lot of C<add> or C<parent> signal
connections.

Widgets doing C<Gtk2::Gdk::Window::set_cursor> themselves generally defeat
the WidgetCursor mechanism.  WidgetCursor has some special handling for
C<Gtk2::Entry> and C<Gtk2::TextView> (their insertion point cursor), but a
few other core widgets have problems.  The worst affected currently is
C<Gtk2::LinkButton>.  Hopefully this will improve in the future, though the
ill effects may be as little as an C<include_children> not in fact
"including" children of the offending types.

=head1 SEE ALSO

L<Gtk2::Gdk::Cursor>, L<Gtk2::Widget>, L<Gtk2::Gdk::Window>,
L<Gtk2::Gdk::Display>
