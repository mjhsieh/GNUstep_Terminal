/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef TerminalView_h
#define TerminalView_h

#include <AppKit/NSView.h>


extern NSString
	*TerminalViewEndOfInputNotification,
	*TerminalViewTitleDidChangeNotification;


#include "Terminal.h"

/* TODO: this is slightly ugly */
@class TerminalParser_Linux;


@class NSScroller;

@interface TerminalView : NSView <TerminalScreen>
{
	NSScroller *scroller;

	NSFont *font;
	float fx,fy,fx0,fy0;

	struct
	{
		int x0,y0,x1,y1;
	} dirty;

	int master_fd;

	int max_scrollback;
	int sb_length,current_scroll;
	screen_char_t *sbuf;

	int sx,sy;
	screen_char_t *screen;

	int cursor_x,cursor_y;
	int current_x,current_y;

	NSString *title_window,*title_miniwindow;

	NSObject<TerminalParser> *tp;

	BOOL draw_all;
}

-(void) setScroller: (NSScroller *)sc;

-(NSString *) windowTitle;
-(NSString *) miniwindowTitle;

+(NSFont *) terminalFont;

@end


#endif

