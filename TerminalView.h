/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef TerminalView_h
#define TerminalView_h

#include <AppKit/NSView.h>

extern NSString
	*TerminalViewEndOfInputNotification,
	*TerminalViewTitleDidChangeNotification;

typedef struct
{
	unichar ch;
	unsigned char color;
	unsigned char attr;
} screen_char_t;

@interface TerminalView : NSView
{
	NSFont *font;
	float fx,fy,fx0,fy0;

	int master_fd;

	int sx,sy;
	screen_char_t *screen;

	struct
	{
		int x0,y0,x1,y1;
	} dirty;

	int x,y;
	unsigned int tab_stop[8];

	int top,bottom;

	unsigned int unich;

	NSString *title;

#define TITLE_BUF_SIZE 255
	char title_buf[TITLE_BUF_SIZE+1];
	int title_len, title_type;

	NSString *title_window,*title_miniwindow;

enum { ESnormal, ESesc, ESsquare, ESgetpars, ESgotpars, ESfunckey,
	EShash, ESsetG0, ESsetG1, ESpercent, ESignore, ESnonstd,
	ESpalette, EStitle_semi, EStitle_buf } ESstate;
	int vc_state;

	unsigned char decscnm,decom,decawm,deccm,decim;
	unsigned char ques;
	unsigned char charset,utf,utf_count,disp_ctrl,toggle_meta;

	const unichar *translate;

	unsigned int intensity,underline,reverse,blink; /* 2 1 1 1 */
	unsigned int color,def_color;
#define foreground (color & 0x0f)
#define background (color & 0xf0)

#define NPAR 16
	int npar;
	int par[NPAR];

	int saved_x,saved_y;
	unsigned int s_intensity,s_underline,s_blink,s_reverse,s_charset,s_color;

	int G0_charset,G1_charset,saved_G0,saved_G1;
}

-(NSString *) windowTitle;
-(NSString *) miniwindowTitle;

+(NSFont *) terminalFont;

@end

#endif

