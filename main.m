/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <math.h>
#include <sys/wait.h>

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSView.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSWindowController.h>
#include <AppKit/NSScroller.h>
#include <AppKit/GSHbox.h>


#include "TerminalView.h"


static void get_zombies(void)
{
	int status,pid;
	while ((pid=waitpid(-1,&status,WNOHANG))>0)
	{
//		printf("got %i\n",pid);
	}
}


@interface TerminalWindowController : NSWindowController
{
	TerminalView *tv;
}

- init;
@end

@implementation TerminalWindowController
- init
{
	NSWindow *win;
	NSFont *font;
	NSScroller *scroller;
	GSHbox *hb;
	float fx,fy;
	int scroller_width;

	font=[TerminalView terminalFont];
	fx=[font boundingRectForFont].size.width;
	fy=[font boundingRectForFont].size.height;

	scroller_width=ceil([NSScroller scrollerWidth]/fx);

	win=[[NSWindow alloc] initWithContentRect: NSMakeRect(100,100,fx*(80+scroller_width),fy*24)
		styleMask: NSClosableWindowMask|NSTitledWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
		backing: NSBackingStoreRetained
		defer: YES];
	if (!(self=[super initWithWindow: win])) return nil;

	[win setTitle: @"Terminal"];
	[win setDelegate: self];

	[win setResizeIncrements: NSMakeSize(fx,fy)];
	[win setContentSize: NSMakeSize(fx*(80+scroller_width)+1,fy*24+1)];

	hb=[[GSHbox alloc] init];

	scroller=[[NSScroller alloc] initWithFrame: NSMakeRect(0,0,scroller_width*fx-1,fy*24)];
	[scroller setArrowsPosition: NSScrollerArrowsMaxEnd];
	[scroller setEnabled: YES];
	[scroller setAutoresizingMask: NSViewHeightSizable];
	[hb addView: scroller  enablingXResizing: NO];
	[scroller release];

	tv=[[TerminalView alloc] init];
	[tv setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	[tv setScroller: scroller];
	[hb addView: tv];
	[tv release];
	[win makeFirstResponder: tv];

	[win setContentView: hb];
	DESTROY(hb);

	[win release];

	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(close)
		name: TerminalViewEndOfInputNotification
		object: tv];
	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(_updateTitle:)
		name: TerminalViewTitleDidChangeNotification
		object: tv];

	return self;
}


-(void) _updateTitle: (NSNotification *)n
{
	[[self window] setTitle: [tv windowTitle]];
	[[self window] setMiniwindowTitle: [tv miniwindowTitle]];
}


-(void) dealloc
{
	[[NSNotificationCenter defaultCenter]
		removeObserver: self];
	[super dealloc];
}

-(void) windowWillClose: (NSNotification *)n
{
	get_zombies();
	[self autorelease];
}

@end


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
	[super dealloc];
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
	[m addItemWithTitle: _(@"Copy")
		action: @selector(copy:)
		keyEquivalent: @"c"];
	[m addItemWithTitle: _(@"Cut")
		action: @selector(cut:)
		keyEquivalent: @"x"];
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
	twc=[[TerminalWindowController alloc] init];
	[twc showWindow: self];
}

-(void) applicationDidFinishLaunching: (NSNotification *)n
{
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

