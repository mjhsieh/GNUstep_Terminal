/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <math.h>
#include <sys/wait.h>

#include <Foundation/NSString.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSScroller.h>
#include <AppKit/GSHbox.h>
#include <AppKit/PSOperators.h>

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
	NSRect	contentRect, windowRect;
	NSSize	contentSize, minSize;

	font=[TerminalView terminalFont];
	fx=[font boundingRectForFont].size.width;
	fy=[font boundingRectForFont].size.height;

	scroller_width=[NSScroller scrollerWidth];

	// calc the rects for our window
	contentSize = NSMakeSize (fx * 80 + scroller_width + 1, fy * 25 + 1);
	minSize = NSMakeSize (fx * 20 + scroller_width + 1, fy * 10 + 1);

	// add the borders to the size
	contentSize.width += 8;
	minSize.width += 8;
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"AddYBorders"]) {
		contentSize.height += 8;
		minSize.height += 8;
	}

	contentRect = NSMakeRect (100, 100, contentSize.width, contentSize.height);

	win=[[NSWindow alloc] initWithContentRect: contentRect
		styleMask: NSClosableWindowMask|NSTitledWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
		backing: NSBackingStoreRetained
		defer: YES];
	if (!(self=[super initWithWindow: win])) return nil;

	windowRect = [win frame];
	minSize.width += windowRect.size.width - contentSize.width;
	minSize.height += windowRect.size.height - contentSize.height;

	[win setTitle: @"Terminal"];
	[win setDelegate: self];

	[win setContentSize: contentSize];
	[win setResizeIncrements: NSMakeSize (fx , fy)];
	[win setMinSize: minSize];

	hb=[[GSHbox alloc] init];

	scroller=[[NSScroller alloc] initWithFrame: NSMakeRect(0,0,[NSScroller scrollerWidth],fy)];
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

	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"AddYBorders"])
		[tv setBorder: 4 : 4];
	else
		[tv setBorder: 4 : 0];

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


static NSMutableArray *idle_list;

-(void) windowWillClose: (NSNotification *)n
{
	get_zombies();
	[idle_list removeObject: self];
	[self autorelease];
}

-(void) _becameIdle
{
	NSDebugLLog(@"idle",@"%@ _becameIdle",self);

	if (close_on_idle)
	{
		[self close];
		return;
	}

	[idle_list addObject: self];
	NSDebugLLog(@"idle",@"idle list: %@",idle_list);

	{
		NSString *t;

		t=[[self window] title];
		t=[t stringByAppendingString: _(@" (idle)")];
		[[self window] setTitle: t];

		t=[[self window] miniwindowTitle];
		t=[t stringByAppendingString: _(@" (idle)")];
		[[self window] setMiniwindowTitle: t];
	}
}

-(void) _becameNonIdle
{
	NSDebugLLog(@"idle",@"%@ _becameNonIdle",self);
	[idle_list removeObject: self];
	NSDebugLLog(@"idle",@"idle list: %@",idle_list);
}


-(TerminalView *) terminalView
{
	return tv;
}

-(void) setShouldCloseWhenIdle: (BOOL)should
{
	close_on_idle=should;
}


+(void) initialize
{
	if (!idle_list)
		idle_list=[[NSMutableArray alloc] init];
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
	NSDebugLLog(@"idle",@"get idle window from idle list: %@",idle_list);
	if ([idle_list count])
		return [idle_list objectAtIndex: 0];
	return [self newTerminalWindow];
}

@end

