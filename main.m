/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSView.h>
#include <AppKit/NSMenu.h>


#include "TerminalWindow.h"
#include "TerminalView.h"
#include "PreferencesWindowController.h"


@interface NSMenu (helpers)
-(id <NSMenuItem>) addItemWithTitle: (NSString *)s;
-(id <NSMenuItem>) addItemWithTitle: (NSString *)s  action: (SEL)sel;
@end
@implementation NSMenu (im_lazy)
-(id <NSMenuItem>) addItemWithTitle: (NSString *)s
{
	return [self addItemWithTitle: s  action: NULL  keyEquivalent: nil];
}

-(id <NSMenuItem>) addItemWithTitle: (NSString *)s  action: (SEL)sel
{
	return [self addItemWithTitle: s  action: sel  keyEquivalent: nil];
}
@end


@interface Terminal : NSObject
{
	PreferencesWindowController *pwc;
}

@end

@implementation Terminal

- init
{
	if (!(self=[super init])) return nil;
	return self;
}

-(void) dealloc
{
	DESTROY(pwc);
	[super dealloc];
}


/*

display
 cursor color
 cursor invert
 font
 bold font
 intensity handling
 colors?

specific
 keyboard mappings?
 terminal emulation
 close on shell exit
 shell to run
 environment

services


general

*/

@class TerminalViewDisplayPrefs;
@class TerminalServicesPrefs;

-(void) openPreferences: (id)sender
{
	if (!pwc)
	{
		NSObject<PrefBox> *pb;
		pwc=[[PreferencesWindowController alloc] init];

		pb=[[TerminalViewDisplayPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);

		pb=[[TerminalServicesPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);
	}
	[pwc showWindow: self];
}


-(void) applicationWillTerminate: (NSNotification *)n
{
}


-(void) applicationWillFinishLaunching: (NSNotification *)n
{
	NSMenu *menu,*m/*,*m2*/;

	[TerminalView registerPasteboardTypes];

	menu=[[NSMenu alloc] init];

	/* 'Info' menu */
	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"Preferences...")
		action: @selector(openPreferences:)];
	[m addItemWithTitle: _(@"Info")
		action: @selector(orderFrontStandardInfoPanel:)];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Info")]];
	[m release];

	/* 'Terminal' menu */
	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"New window")
		action: @selector(openWindow:)
		keyEquivalent: @"n"];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Terminal")]];
	[m release];

	/* 'Edit' menu */
	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"Cut")
		action: @selector(cut:)
		keyEquivalent: @"x"];
	[m addItemWithTitle: _(@"Copy")
		action: @selector(copy:)
		keyEquivalent: @"c"];
	[m addItemWithTitle: _(@"Paste")
		action: @selector(paste:)
		keyEquivalent: @"v"];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Edit")]];
	[m release];

	/* 'Windows' menu */
	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"Close")
		action: @selector(performClose:)
		keyEquivalent: @"w"];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Windows")]];
	[NSApp setWindowsMenu: m];
	[m release];

	m=[[NSMenu alloc] init];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Services")]];
	[NSApp setServicesMenu: m];
	[m release];

	[menu addItemWithTitle: _(@"Hide")
		action: @selector(hide:)
		keyEquivalent: @"h"];

	[menu addItemWithTitle: _(@"Quit")
		action: @selector(terminate:)
		keyEquivalent: @"q"];

	[NSApp setMainMenu: menu];
	[menu release];
}

-(void) openWindow: (id)sender
{
	TerminalWindowController *twc;
	twc=[TerminalWindowController newTerminalWindow];
	[twc setShouldCloseWhenIdle: YES];
	[[twc terminalView] runShell];
}


@class TerminalServices;

-(void) applicationDidFinishLaunching: (NSNotification *)n
{
	[NSApp setServicesProvider: [[TerminalServices alloc] init]];
	[self openWindow: self];
}

@end



int main(int argc, char **argv)
{
	CREATE_AUTORELEASE_POOL(arp);

	[NSApplication sharedApplication];

	[NSApp setDelegate: [[Terminal alloc] init]];
	[NSApp run];

	DESTROY(arp);
	return 0;
}

