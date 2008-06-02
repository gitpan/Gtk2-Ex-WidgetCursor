#!/usr/bin/perl

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

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile
  (NAME         => 'Gtk2-Ex-WidgetCursor',
   ABSTRACT     => 'Mouse pointer cursor management for Gtk widgets.',
   VERSION_FROM => 'lib/Gtk2/Ex/WidgetCursor.pm',
   AUTHOR       => 'Kevin Ryde <user42@zip.com.au>',
   LICENSE      => 'gpl',
   SIGN         => 1,

   PREREQ_PM    => {
                    # any version should be ok
                    'Gtk2' => 0,

                    # actually Gtk2 requires perl 5.8, which has
                    # Scalar::Util builtin already
                    'Scalar::Util' => 0,
                   },

   clean        => { FILES => "WidgetCursor.html" },
  );

sub MY::postamble {
  return <<'MAKE_FRAG';

lint:
	perl -MO=Lint lib/Gtk2/Ex/WidgetCursor.pm
	podchecker lib/Gtk2/Ex/WidgetCursor.pm

myman:
	mv MANIFEST MANIFEST.old
	touch SIGNATURE
	(make manifest 2>&1; diff -u MANIFEST.old MANIFEST) |less

WidgetCursor.html: lib/Gtk2/Ex/WidgetCursor.pm Makefile
	-perl -MPod::Simple::HTML -e Pod::Simple::HTML::go \
	  lib/Gtk2/Ex/WidgetCursor.pm >WidgetCursor.html

# find files in the dist with mod times this year, but without this year in
# the copyright line
copyright-years-check: Gtk2-Ex-WidgetCursor-$(VERSION).tar.gz
	year=`date +%Y`; \
	tar tvfz Gtk2-Ex-WidgetCursor-$(VERSION).tar.gz \
	| grep $$year- \
	| sed 's:^.*Gtk2-Ex-WidgetCursor-$(VERSION)/::' \
	| (result=0; \
	  while read i; do \
	    case $$i in \
	      '' | */ \
	      | debian/changelog | debian/compat | debian/control \
	      | t/pod.t \
	      | COPYING | MANIFEST | SIGNATURE | META.yml) \
	      continue ;; \
	    esac; \
	    if test -e "$(srcdir)/$$i"; then f="$(srcdir)/$$i"; \
	    else f="$$i"; fi; \
	    if ! grep -q "Copyright.*$$year" $$f; then \
	      echo "$$i:1: this file"; \
	      grep Copyright $$f; \
	      result=1; \
	    fi; \
	  done; \
	  exit $$result)

debug-constants-check:
	if egrep -n 'DEBUG => [^0]' $(TO_INST_PM); then exit 1; else exit 0; fi


MAKE_FRAG
}
