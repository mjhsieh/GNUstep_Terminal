include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Terminal

PACKAGE_NAME = Terminal
CVS_MODULE_NAME = Terminal
CVS_OPTIONS = -d/opt/cvsroot
VERSION = 0.0.2

ADDITIONAL_OBJCFLAGS += -Wall -O2

Terminal_OBJC_FILES = \
	main.m

Terminal_LDFLAGS = -lutil

#Terminal_LOCALIZED_RESOURCE_FILES = Localizable.strings
#Terminal_LANGUAGES = English Swedish

MAKE_STRINGS_OPTIONS = --aggressive-match --aggressive-remove

include $(GNUSTEP_MAKEFILES)/application.make

