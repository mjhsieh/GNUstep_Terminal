/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <math.h>
#include <sys/wait.h>

#include <Foundation/NSString.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSNotification.h>
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


@interface BlackView : NSView
@end

@implementation BlackView
-(BOOL) isOpaque
{
	return YES;
}
-(void) drawRect: (NSRect)r
{
	PSsetgray(0.0);
	PSrectfill(r.origin.x,r.origin.y,r.size.width,r.size.height);
}
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

	win=[[NSWindow alloc] initWithContentRect: NSMakeRect(100,100,fx*(80+scroller_width),fy*25)
		styleMask: NSClosableWindowMask|NSTitledWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
		backing: NSBackingStoreRetained
		defer: YES];
	if (!(self=[super initWithWindow: win])) return nil;

	[win setTitle: @"Terminal"];
	[win setDelegate: self];

	[win setResizeIncrements: NSMakeSize(fx,fy)];
	[win setContentSize: NSMakeSize(fx*(80+scroller_width)+1,fy*25+1)];

	hb=[[GSHbox alloc] init];

	scroller=[[NSScroller alloc] initWithFrame: NSMakeRect(0,0,[NSScroller scrollerWidth],fy)];
	[scroller setArrowsPosition: NSScrollerArrowsMaxEnd];
	[scroller setEnabled: YES];
	[scroller setAutoresizingMask: NSViewHeightSizable];
	[hb addView: scroller  enablingXResizing: NO];
	[scroller release];

	{
		NSView *v=[[BlackView alloc] initWithFrame: NSMakeRect(0,0,(scroller_width*fx-[NSScroller scrollerWidth])/2,fy)];
		[v setAutoresizingMask: NSViewHeightSizable];
		[hb addView: v  enablingXResizing: NO];
		DESTROY(v);
	}

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

