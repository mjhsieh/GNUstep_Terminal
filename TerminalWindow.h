/*
copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#ifndef TerminalWindow_h
#define TerminalWindow_h

@class TerminalView;

#include <AppKit/NSWindowController.h>

NSString *TerminalWindowNoMoreActiveWindowsNotification;

@interface TerminalWindowController : NSWindowController
{
	TerminalView *tv;
	BOOL close_on_idle;
}

+(TerminalWindowController *) newTerminalWindow;
+(TerminalWindowController *) idleTerminalWindow;

+(int) numberOfActiveWindows;
+(void) checkActiveWindows;

- init;

-(TerminalView *) terminalView;

-(void) setShouldCloseWhenIdle: (BOOL)should_close;

@end

#endif

