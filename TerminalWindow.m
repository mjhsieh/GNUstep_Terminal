/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <math.h>
#include <sys/wait.h>

#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSScroller.h>
#include <AppKit/GSHbox.h>

#include "TerminalWindow.h"

#include "TerminalView.h"


/* TODO: this needs cleaning up. chances are this will interfere
with NSTask */
static void get_zombies(void)
{
	int status,pid;
	while ((pid=waitpid(-1,&status,WNOHANG))>0)
	{
//		printf("got %i\n",pid);
	}
}


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

	win=[[NSWindow alloc] initWithContentRect: NSMakeRect(100,100,fx*(80+scroller_width),fy*25)
		styleMask: NSClosableWindowMask|NSTitledWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
		backing: NSBackingStoreRetained
		defer: YES];
	if (!(self=[super initWithWindow: win])) return nil;

	[win setTitle: @"Terminal"];
	[win setDelegate: self];

	[win setResizeIncrements: NSMakeSize(fx,fy)];
	[win setContentSize: NSMakeSize(fx*(80+scroller_width),fy*25+1)];

	hb=[[GSHbox alloc] init];

	scroller=[[NSScroller alloc] initWithFrame: NSMakeRect(0,0,[NSScroller scrollerWidth]-1,fy)];
	[scroller setArrowsPosition: NSScrollerArrowsMaxEnd];
	[scroller setEnabled: YES];
	[scroller setAutoresizingMask: NSViewHeightSizable];
	[hb addView: scroller  enablingXResizing: NO];
	[scroller release];

	tv=[[TerminalView alloc] init];
	[tv setIgnoreResize: YES];
	[tv setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	[tv setScroller: scroller];
	[hb addView: tv];
	[tv release];
	[win makeFirstResponder: tv];
	[tv setIgnoreResize: NO];

	[win setContentView: hb];
	DESTROY(hb);

	[win release];

	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(_becameIdle)
		name: TerminalViewBecameIdleNotification
		object: tv];
	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(_becameNonIdle)
		name: TerminalViewBecameNonIdleNotification
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


-(void) _becameIdle
{
	if (close_on_idle)
		[self close];
}

-(void) _becameNonIdle
{
}


-(TerminalView *) terminalView
{
	return tv;
}

-(void) setShouldCloseWhenIdle: (BOOL)should
{
	close_on_idle=should;
}


+(TerminalWindowController *) newTerminalWindow
{
	TerminalWindowController *twc;

	twc=[[self alloc] init];
	[twc showWindow: self];
	return twc;
}

+(TerminalWindowController *) idleTerminalWindow
{
	return [self newTerminalWindow];
}

@end

