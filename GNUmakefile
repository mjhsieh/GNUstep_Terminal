include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Terminal

#PACKAGE_NAME = BundleBrowser
#CVS_MODULE_NAME = BundleBrowser
#CVS_OPTIONS = -d/opt/cvsroot
#VERSION = 0.9

ADDITIONAL_OBJCFLAGS += -Wall -O2

Terminal_OBJC_FILES = \
	main.m

Terminal_LDFLAGS = -lutil

#Terminal_LOCALIZED_RESOURCE_FILES = Localizable.strings
#Terminal_LANGUAGES = English Swedish

MAKE_STRINGS_OPTIONS = --aggressive-match --aggressive-remove

include $(GNUSTEP_MAKEFILES)/application.make

