/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef ServicesParameterWindowController_h
#define ServicesParameterWindowController_h

#include <AppKit/NSWindowController.h>

@class NSTextField;

@interface TerminalServicesParameterWindowController : NSWindowController
{
	NSTextField *tf_cmdline;
}

+(NSString *) getCommandlineFrom: (NSString *)cmdline
	selectRange: (NSRange)r
	service: (NSString *)service_name;

@end

#endif

