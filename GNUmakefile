# copyright 2002 Alexander Malmberg <alexander@malmberg.org>
#
# This file is a part of Terminal.app. Terminal.app is free software; you
# can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation; version 2
# of the License. See COPYING or main.m for more information.

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Terminal

PACKAGE_NAME = Terminal
CVS_MODULE_NAME = terminal
CVS_OPTIONS = -d alexm@subversions.gnu.org:/cvsroot/terminal
VERSION = 0.9.3

ADDITIONAL_OBJCFLAGS += -Wall -O2 -D$(subst -,_,$(GNUSTEP_HOST_OS))

Terminal_OBJC_FILES = \
	main.m \
	\
	Services.m \
	ServicesPrefs.m \
	ServicesParameterWindowController.m \
	\
	TerminalWindow.m \
	TerminalWindowPrefs.m \
	\
	TerminalView.m \
	TerminalViewPrefs.m \
	\
	TerminalParser_Linux.m \
	TerminalParser_LinuxPrefs.m \
	\
	PreferencesWindowController.m \
	autokeyviewchain.m \
	\
	Label.m

Terminal_LDFLAGS = -lutil

Terminal_LOCALIZED_RESOURCE_FILES = Localizable.strings
Terminal_LANGUAGES = English Swedish German French

Terminal_APPLICATION_ICON = Terminal.tiff
Terminal_RESOURCE_FILES = \
	Terminal.tiff DefaultTerminalServices.svcs \
	cursor_line.tiff cursor_stroked.tiff cursor_filled.tiff \
	cursor_inverted.tiff

MAKE_STRINGS_OPTIONS = --aggressive-match --aggressive-remove

include $(GNUSTEP_MAKEFILES)/application.make

