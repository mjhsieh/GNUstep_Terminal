/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef TerminalWindow_h
#define TerminalWindow_h

@class TerminalView;

#include <AppKit/NSWindowController.h>

@interface TerminalWindowController : NSWindowController
{
	TerminalView *tv;
	BOOL close_on_exit;
}

+(TerminalWindowController *) newTerminalWindow;
+(TerminalWindowController *) idleTerminalWindow;

- init;

-(TerminalView *) terminalView;

-(void) setShouldCloseOnEOF: (BOOL)should_close;

@end

#endif

