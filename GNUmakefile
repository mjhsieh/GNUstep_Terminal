include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Terminal

PACKAGE_NAME = Terminal
CVS_MODULE_NAME = Terminal
CVS_OPTIONS = -d/opt/cvsroot
VERSION = 0.1.3

ADDITIONAL_OBJCFLAGS += -Wall -O2 -D$(subst -,_,$(GNUSTEP_HOST_OS))

Terminal_OBJC_FILES = \
	main.m \
	TerminalView.m

Terminal_LDFLAGS = -lutil

Terminal_LOCALIZED_RESOURCE_FILES = Localizable.strings
Terminal_LANGUAGES = English Swedish

Terminal_APPLICATION_ICON = Terminal.tiff
Terminal_RESOURCE_FILES = Terminal.tiff

MAKE_STRINGS_OPTIONS = --aggressive-match --aggressive-remove

include $(GNUSTEP_MAKEFILES)/application.make

