/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <math.h>
#ifdef freebsd
#  include <sys/types.h>
#  include <sys/ioctl.h>
#  include <termios.h>
#  include <libutil.h>
#  include <pcap.h>
#else
#  include <termio.h>
#endif
#include <unistd.h>
#ifndef freebsd
#  include <pty.h>
#endif
#include <sys/wait.h>

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSNotification.h>
#include <gnustep/base/Unicode.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSView.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSWindowController.h>
#include <AppKit/PSOperators.h>


static void get_zombies(void)
{
	int status,pid;
	while ((pid=waitpid(-1,&status,WNOHANG))>0)
	{
//		printf("got %i\n",pid);
	}
}


/*
lots borrowed from linux/drivers/char/console.c, GNU GPL:ed
*/
/*
 *  linux/drivers/char/console.c
 *
 *  Copyright (C) 1991, 1992  Linus Torvalds
 */

#include "charmaps.h"

#define set_translate(charset,foo) _set_translate(charset)
static const unichar *_set_translate(int charset)
{
	if (charset<0 || charset>=4)
		return translate_maps[0];
	return translate_maps[charset];
}

typedef struct
{
	unichar ch;
	unsigned char color;
	unsigned char attr;
} screen_char_t;


static NSString *TerminalViewEndOfInput=@"TerminalViewEndOfInput";

@interface TerminalView : NSView <RunLoopEvents>
{
	NSFont *font;
	float fx,fy,fx0,fy0;

	int master_fd;

	int sx,sy;
	screen_char_t *screen;

	int x,y;
	unsigned int tab_stop[8];

	int top,bottom;

	unsigned int unich;

enum { ESnormal, ESesc, ESsquare, ESgetpars, ESgotpars, ESfunckey,
	EShash, ESsetG0, ESsetG1, ESpercent, ESignore, ESnonstd,
	ESpalette } ESstate;
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

#define csi_J(foo,vpar) [self _csi_J: vpar]
#define csi_K(foo,vpar) [self _csi_K: vpar]
#define csi_L(foo,vpar) [self _csi_L: vpar]
#define csi_M(foo,vpar) [self _csi_M: vpar]
#define csi_P(foo,vpar) [self _csi_P: vpar]
#define csi_X(foo,vpar) [self _csi_X: vpar]
#define csi_at(foo,vpar) [self _csi_at: vpar]
#define csi_m(foo) [self _csi_m]

-(void) _csi_J: (int)vpar;
-(void) _csi_K: (int)vpar;
-(void) _csi_L: (unsigned int)vpar;
-(void) _csi_M: (unsigned int)vpar;
-(void) _csi_P: (unsigned int)vpar;
-(void) _csi_X: (int)vpar;
-(void) _csi_at: (unsigned int)vpar;
-(void) _csi_m;

-(void) _default_attr;

-(void) sendCString: (const char *)msg;

@end

@implementation TerminalView

#define SCREEN(x,y) (screen[(y)*sx+(x)])

-(void) _setAttrs: (screen_char_t)sch : (float)x0 : (float)y0
{
	int fg,bg;
	float h,s,b;
	float bh,bs,bb;

	int in,ul,bl,re;

static const float col_h[8]={  0,240,120,180,  0,300, 60,  0};
static const float col_s[8]={0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0};
/*static const float col[16][3]={
{0.90, 0.70, 0.20},
{0.00, 0.00, 0.66},
{0.00, 0.66, 0.00},
{0.00, 0.66, 0.66},

{0.66, 0.00, 0.00},
{0.66, 0.00, 0.66},
{0.66, 0.66, 0.00},
{0.66, 0.66, 0.66},

{0.33, 0.33, 0.33},
{0.00, 0.00, 1.00},
{0.00, 1.00, 0.00},
{0.00, 1.00, 1.00},

{1.00, 0.00, 0.00},
{1.00, 0.00, 1.00},
{1.00, 1.00, 0.00},
{1.00, 1.00, 1.00},
};*/
	fg=sch.color&0x0f;
	bg=(sch.color&0xf0)>>4;

	in=sch.attr&3;
	ul=sch.attr&4;
	re=sch.attr&8;
	bl=sch.attr&16;

	bb=0.6;
	if (bg>=8)
		bg-=8,bb=1.0;
	if (bg==0)
		bb=0.0;
	bs=col_s[bg];
	bh=col_h[bg]/360.0;

	if (fg>=8)
	{
		in++;
		fg-=8;
	}

	if (in==0)
		b=0.6;
	else if (in==1)
		b=0.8;
	else
		b=1.0;

	if (fg==0)
		b=0.0;

	h=col_h[fg]/360.0;
	s=col_s[fg];
	if (in==2)
		s*=0.75;

	if (re)
	{
		float t;
#define SWAP(x,y) t=x; x=y; y=t;

		SWAP(h,bh)
		SWAP(s,bs)
		SWAP(b,bb)
#undef SWAP
	}

	PSsethsbcolor(bh,bs,bb);
	PSrectfill(x0,y0,fx,fy);

	PSsethsbcolor(h,s,b);

	if (ul)
		PSrectfill(x0,y0,fx,1);
}

-(void) drawRect: (NSRect)r
{
	int ix,iy;
	unsigned char buf[8];
	unsigned char *pbuf=buf;
	int dlen;
	NSGraphicsContext *cur=GSCurrentContext();

	DPSsetgray(cur,0.0);
	DPSrectfill(cur,r.origin.x,r.origin.y,r.size.width,r.size.height);

//	DPSsetgray(cur,1.0);
	[font set];

	for (ix=0;ix<sx;ix++)
		for (iy=0;iy<sy;iy++)
		{
			if (SCREEN(ix,iy).ch)
			{
				[self _setAttrs: SCREEN(ix,iy) : ix*fx:(sy-1-iy)*fy];

				dlen=sizeof(buf)-1;
				GSFromUnicode(&pbuf,&dlen,&SCREEN(ix,iy).ch,1,NSUTF8StringEncoding,NULL,GSUniTerminate);
				DPSmoveto(cur,ix*fx+fx0,(sy-1-iy)*fy+fy0);
				DPSshow(cur,buf);
			}
		}

	DPSsetrgbcolor(cur,0.2,0.2,1.0);
	DPSrectstroke(cur,x*fx,(sy-1-y)*fy,fx,fy);
}


-(void) keyDown: (NSEvent *)e
{
/* TODO: what do we do with non-ascii characters? */
	NSString *s=[e charactersIgnoringModifiers];
	unsigned int mask=[e modifierFlags];
	unichar ch,ch2;
	const char *str;

/*	NSLog(@"got key flags=%08x  repeat=%i '%@' '%@' %4i %04x %i %04x %i\n",
		[e modifierFlags],[e isARepeat],[e characters],[e charactersIgnoringModifiers],[e keyCode],
		[[e characters] characterAtIndex: 0],[[e characters] length],
		[[e charactersIgnoringModifiers] characterAtIndex: 0],[[e charactersIgnoringModifiers] length]);*/

	if ([s length]>1)
	{
		int i;
		s=[e characters];
		for (i=0;i<[s length];i++)
		{
			unichar uc=[s characterAtIndex: 0];
			if (uc>256)
				NSBeep();
			else
				write(master_fd,&uc,1);
		}
		return;
	}

	ch=[s characterAtIndex: 0];
	str=NULL;
	ch2=0;
	switch (ch)
	{
	case NSUpArrowFunctionKey   : str="\e[A"; break;
	case NSDownArrowFunctionKey : str="\e[B"; break;
	case NSLeftArrowFunctionKey : str="\e[D"; break;
	case NSRightArrowFunctionKey: str="\e[C"; break;

	case NSF1FunctionKey : str="\e[[A"; break;
	case NSF2FunctionKey : str="\e[[B"; break;
	case NSF3FunctionKey : str="\e[[C"; break;
	case NSF4FunctionKey : str="\e[[D"; break;
	case NSF5FunctionKey : str="\e[[E"; break;

	case NSF6FunctionKey : str="\e[17~"; break;
	case NSF7FunctionKey : str="\e[18~"; break;
	case NSF8FunctionKey : str="\e[19~"; break;
	case NSF9FunctionKey : str="\e[20~"; break;
	case NSF10FunctionKey: str="\e[21~"; break;
	case NSF11FunctionKey: str="\e[23~"; break;
	case NSF12FunctionKey: str="\e[24~"; break;

	case NSF13FunctionKey: str="\e[25~"; break;
	case NSF14FunctionKey: str="\e[26~"; break;
	case NSF15FunctionKey: str="\e[28~"; break;
	case NSF16FunctionKey: str="\e[29~"; break;
	case NSF17FunctionKey: str="\e[31~"; break;
	case NSF18FunctionKey: str="\e[32~"; break;
	case NSF19FunctionKey: str="\e[33~"; break;
	case NSF20FunctionKey: str="\e[34~"; break;

	case NSHomeFunctionKey    : str="\e[1~"; break;
	case NSInsertFunctionKey  : str="\e[2~"; break;
	case NSDeleteFunctionKey  : str="\e[3~"; break;
	case NSEndFunctionKey     : str="\e[4~"; break;
	case NSPageUpFunctionKey  : str="\e[5~"; break;
	case NSPageDownFunctionKey: str="\e[6~"; break;

	case 8: ch2=0x7f; break;
	case 3: ch2=0x0d; break;

	default:
	{
		int i;
		s=[e characters];
		for (i=0;i<[s length];i++)
		{
			unichar uc=[s characterAtIndex: 0];
			if (uc>256)
				NSBeep();
			else
				write(master_fd,&uc,1);
		}
		return;
	}
	}

	if (mask&NSCommandKeyMask)
		write(master_fd,"\e",1);

	if (str)
		[self sendCString: str];
	else if (ch2>256)
		NSBeep();
	else if (ch2>0)
		write(master_fd,&ch2,1);
}

-(BOOL) acceptsFirstResponder
{
	return YES;
}


-(void) sendCString: (const char *)msg
{
	int len=strlen(msg);
	write(master_fd,msg,len);
}

#define video_num_columns sx
#define video_num_lines sy
#define video_erase_char 0

#define gotoxy(foo,new_x,new_y) do { \
	int min_y, max_y; \
 \
	if (new_x < 0) \
		x = 0; \
	else \
		if (new_x >= video_num_columns) \
			x = video_num_columns - 1; \
		else \
			x = new_x; \
	if (decom) { \
		min_y = top; \
		max_y = bottom; \
	} else { \
		min_y = 0; \
		max_y = video_num_lines; \
	} \
	if (new_y < min_y) \
		y = min_y; \
	else if (new_y >= max_y) \
		y = max_y - 1; \
	else \
		y = new_y; \
} while (0)

#define gotoxay(foo,nx,ny) gotoxy(foo,nx,decom?top+ny:ny)


#define save_cur(foo) do { \
	saved_x		= x; \
	saved_y		= y; \
	s_intensity	= intensity; \
	s_underline	= underline; \
	s_blink		= blink; \
	s_reverse	= reverse; \
	s_charset	= charset; \
	s_color		= color; \
	saved_G0	= G0_charset; \
	saved_G1	= G1_charset; \
} while (0)

#define restore_cur(foo) do { \
	gotoxy(currcons,saved_x,saved_y); \
	intensity	= s_intensity; \
	underline	= s_underline; \
	blink		= s_blink; \
	reverse		= s_reverse; \
	charset		= s_charset; \
	color		= s_color; \
	G0_charset	= saved_G0; \
	G1_charset	= saved_G1; \
	translate	= set_translate(charset ? G1_charset : G0_charset,currcons); \
} while (0)


-(void) _reset_terminal
{
	top		= 0;
	bottom		= sy;
	vc_state	= ESnormal;
	ques		= 0;

	translate	= set_translate(LAT1_MAP,currcons);
	G0_charset	= LAT1_MAP;
	G1_charset	= GRAF_MAP;

	charset		= 0;
//	report_mouse	= 0;
	utf             = 0;
	utf_count       = 0;

	disp_ctrl	= 0;
	toggle_meta	= 0;

	decscnm		= 0;
	decom		= 0;
	decawm		= 1;
	deccm		= 1;
	decim		= 0;

#if 0
	set_kbd(decarm);
	clr_kbd(decckm);
	clr_kbd(kbdapplic);
	clr_kbd(lnm);
	kbd_table[currcons].lockstate = 0;
	kbd_table[currcons].slockstate = 0;
	kbd_table[currcons].ledmode = LED_SHOW_FLAGS;
	kbd_table[currcons].ledflagstate = kbd_table[currcons].default_ledflagstate;
	set_leds();

	cursor_type = CUR_DEFAULT;
	complement_mask = s_complement_mask;
#endif

	[self _default_attr];

	tab_stop[0]= 0x01010100;
	tab_stop[1]=tab_stop[2]=tab_stop[3]=tab_stop[4]=
		tab_stop[5]=tab_stop[6]=tab_stop[7]=0x01010101;

	gotoxy(currcons,0,0);
	save_cur(currcons);
	[self _csi_J: 2];
}


-(void) _csi_J: (int) vpar
{
	unsigned int count;
	screen_char_t *start;

	switch (vpar) {
		case 0:	/* erase from cursor to end of display */
			count = sx*sy-(x+y*sx);
			start = &SCREEN(x,y);
			break;
		case 1:	/* erase from start to cursor */
			count = x+y*sx;
			start = &SCREEN(0,0);
			break;
		case 2: /* erase whole display */
			count = sx*sy;
			start = &SCREEN(0,0);
			break;
		default:
			return;
	}
	memset(start,0,sizeof(screen_char_t)*count);
}


-(void) _csi_K: (int)vpar
{
	unsigned int count;
	screen_char_t *start;

	switch (vpar) {
		case 0:	/* erase from cursor to end of line */
			count = sx-x;
			start = &SCREEN(x,y);
			break;
		case 1:	/* erase from start of line to cursor */
			count = x+1;
			start = &SCREEN(0,y);
			break;
		case 2: /* erase whole line */
			count = sx;
			start = &SCREEN(0,y);
			break;
		default:
			return;
	}
	memset(start, 0, sizeof(screen_char_t) * count);
}

-(void) _csi_X: (int)vpar /* erase the following vpar positions */
{					  /* not vt100? */
	int count;

	if (!vpar)
		vpar++;
	count = (vpar > video_num_columns-x) ? (video_num_columns-x) : vpar;

	memset(&SCREEN(x,y), video_erase_char, sizeof(screen_char_t) * count);
}


-(void) _default_attr
{
	intensity = 1;
	underline = 0;
	reverse = 0;
	blink = 0;
	color = def_color;
}

static unsigned char color_table[] = { 0, 4, 2, 6, 1, 5, 3, 7,
				       8,12,10,14, 9,13,11,15 };

-(void) _csi_m
{
	int i;

	for (i=0;i<=npar;i++)
		switch (par[i]) {
			case 0:	/* all attributes off */
				[self _default_attr];
				break;
			case 1:
				intensity = 2;
				break;
			case 2:
				intensity = 0;
				break;
			case 4:
				underline = 1;
				break;
			case 5:
				blink = 1;
				break;
			case 7:
				reverse = 1;
				break;
			case 10: /* ANSI X3.64-1979 (SCO-ish?)
				  * Select primary font, don't display
				  * control chars if defined, don't set
				  * bit 8 on output.
				  */
				translate = set_translate(charset == 0
						? G0_charset
						: G1_charset,currcons);
				disp_ctrl = 0;
				toggle_meta = 0;
				break;
			case 11: /* ANSI X3.64-1979 (SCO-ish?)
				  * Select first alternate font, lets
				  * chars < 32 be displayed as ROM chars.
				  */
				translate = set_translate(IBMPC_MAP,currcons);
				disp_ctrl = 1;
				toggle_meta = 0;
				break;
			case 12: /* ANSI X3.64-1979 (SCO-ish?)
				  * Select second alternate font, toggle
				  * high bit before displaying as ROM char.
				  */
				translate = set_translate(IBMPC_MAP,currcons);
				disp_ctrl = 1;
				toggle_meta = 1;
				break;
			case 21:
			case 22:
				intensity = 1;
				break;
			case 24:
				underline = 0;
				break;
			case 25:
				blink = 0;
				break;
			case 27:
				reverse = 0;
				break;
			case 38: /* ANSI X3.64-1979 (SCO-ish?)
				  * Enables underscore, white foreground
				  * with white underscore (Linux - use
				  * default foreground).
				  */
				color = (def_color & 0x0f) | background;
				underline = 1;
				break;
			case 39: /* ANSI X3.64-1979 (SCO-ish?)
				  * Disable underline option.
				  * Reset colour to default? It did this
				  * before...
				  */
				color = (def_color & 0x0f) | background;
				underline = 0;
				break;
			case 49:
				color = (def_color & 0xf0) | foreground;
				break;
			default:
				if (par[i] >= 30 && par[i] <= 37)
					color = color_table[par[i]-30]
						| background;
				else if (par[i] >= 40 && par[i] <= 47)
					color = (color_table[par[i]-40]<<4)
						| foreground;
				break;
		}
}

#define scrup(foo,t,b,nr) do { \
	screen_char_t *d, *s; \
	int scrup_nr=nr; \
 \
	if (t+scrup_nr >= b) \
		scrup_nr = b - t - 1; \
	if (b > video_num_lines || t >= b || scrup_nr < 1) \
		return; \
	d = &SCREEN(0,t); \
	s = &SCREEN(0,t+scrup_nr); \
	memmove(d, s, (b-t-scrup_nr) * sx*sizeof(screen_char_t)); \
	memset(d + (b-t-scrup_nr) * video_num_columns, video_erase_char, sizeof(screen_char_t)*sx*scrup_nr); \
} while (0)

#define scrdown(foo,t,b,nr) do { \
	screen_char_t *s; \
	unsigned int step; \
	int scrdown_nr=nr; \
 \
	if (t+scrdown_nr >= b) \
		scrdown_nr = b - t - 1; \
	if (b > video_num_lines || t >= b || scrdown_nr < 1) \
		return; \
	s = &SCREEN(0,t); \
	step = video_num_columns * scrdown_nr; \
	memmove(s + step, s, (b-t-scrdown_nr)*sx*sizeof(screen_char_t)); \
	memset(s, video_erase_char, sizeof(screen_char_t)*step); \
} while (0)


#define insert_char(foo,nr) do { \
	screen_char_t *p, *q = &SCREEN(x,y); \
 \
	p = q + video_num_columns - nr - x; \
	while (--p >= q) \
		p[nr]=*p; \
	memset(q, video_erase_char, nr*sizeof(screen_char_t)); \
} while (0)

#define delete_char(foo,nr) do { \
	unsigned int i = x; \
	screen_char_t *p = &SCREEN(x,y); \
 \
	while (++i <= video_num_columns - nr) { \
		*p=p[nr]; \
		p++; \
	} \
	memset(p, video_erase_char, nr*sizeof(screen_char_t)); \
} while (0)



-(void) _csi_at: (unsigned int)nr
{
	if (nr > video_num_columns - x)
		nr = video_num_columns - x;
	else if (!nr)
		nr = 1;
	insert_char(currcons, nr);
}

-(void) _csi_L: (unsigned int)nr
{
	if (nr > video_num_lines - y)
		nr = video_num_lines - y;
	else if (!nr)
		nr = 1;

	scrdown(foo,y,bottom,nr);
}

-(void) _csi_P: (unsigned int)nr
{
	if (nr > video_num_columns - x)
		nr = video_num_columns - x;
	else if (!nr)
		nr = 1;
	delete_char(currcons, nr);
}

-(void) _csi_M: (unsigned int)nr
{
	if (nr > video_num_lines - y)
		nr = video_num_lines - y;
	else if (!nr)
		nr=1;
	scrup(foo,y,bottom,nr);
}

#define set_kbd(foo)
#define clr_kbd(foo)


#define set_mode(foo,on_off) [self _set_mode: on_off]
-(void) _set_mode: (int) on_off
{
	int i;

	for (i=0; i<=npar; i++)
		if (ques) switch(par[i]) {	/* DEC private modes set/reset */
			case 1:			/* Cursor keys send ^[Ox/^[[x */
				if (on_off)
					set_kbd(decckm);
				else
					clr_kbd(decckm);
				break;
			case 3:	/* 80/132 mode switch unimplemented */
				NSLog(@"ignore _set_mode 3");
#if 0
				deccolm = on_off;
				(void) vc_resize(video_num_lines, deccolm ? 132 : 80);
				/* this alone does not suffice; some user mode
				   utility has to change the hardware regs */
#endif
				break;
			case 5:			/* Inverted screen on/off */
				if (decscnm != on_off) {
					decscnm = on_off;
				}
				break;
			case 6:			/* Origin relative/absolute */
				decom = on_off;
				gotoxay(currcons,0,0);
				break;
			case 7:			/* Autowrap on/off */
				decawm = on_off;
				break;
			case 8:			/* Autorepeat on/off */
				NSLog(@"ignore _set_mode 8");
#if 0
				if (on_off)
					set_kbd(decarm);
				else
					clr_kbd(decarm);
#endif
				break;
			case 9:
				NSLog(@"ignore _set_mode 9");
#if 0
				report_mouse = on_off ? 1 : 0;
#endif
				break;
			case 25:		/* Cursor on/off */
				deccm = on_off;
				break;
			case 1000:
				NSLog(@"ignore _set_mode 1000");
#if 0
				report_mouse = on_off ? 2 : 0;
#endif
				break;
		} else switch(par[i]) {		/* ANSI modes set/reset */
			case 3:			/* Monitor (display ctrls) */
				disp_ctrl = on_off;
				break;
			case 4:			/* Insert Mode on/off */
				decim = on_off;
				break;
			case 20:		/* Lf, Enter == CrLf/Lf */
				NSLog(@"ignore _set_mode 20");
#if 0
				if (on_off)
					set_kbd(lnm);
				else
					clr_kbd(lnm);
#endif
				break;
		}
}


#define setterm_command(foo) [self _setterm_command]
-(void) _setterm_command
{
	NSLog(@"ignore _setterm_command %i\n",par[0]);
	switch(par[0]) {
#if 0
		case 1:	/* set color for underline mode */
			if (can_do_color && par[1] < 16) {
				ulcolor = color_table[par[1]];
				if (underline)
					update_attr(currcons);
			}
			break;
		case 2:	/* set color for half intensity mode */
			if (can_do_color && par[1] < 16) {
				halfcolor = color_table[par[1]];
				if (intensity == 0)
					update_attr(currcons);
			}
			break;
		case 8:	/* store colors as defaults */
			def_color = attr;
			if (hi_font_mask == 0x100)
				def_color >>= 1;
			default_attr(currcons);
			update_attr(currcons);
			break;
		case 9:	/* set blanking interval */
			blankinterval = ((par[1] < 60) ? par[1] : 60) * 60 * HZ;
			poke_blanked_console();
			break;
		case 10: /* set bell frequency in Hz */
			if (npar >= 1)
				bell_pitch = par[1];
			else
				bell_pitch = DEFAULT_BELL_PITCH;
			break;
		case 11: /* set bell duration in msec */
			if (npar >= 1)
				bell_duration = (par[1] < 2000) ?
					par[1]*HZ/1000 : 0;
			else
				bell_duration = DEFAULT_BELL_DURATION;
			break;
		case 12: /* bring specified console to the front */
			if (par[1] >= 1 && vc_cons_allocated(par[1]-1))
				set_console(par[1] - 1);
			break;
		case 13: /* unblank the screen */
			poke_blanked_console();
			break;
		case 14: /* set vesa powerdown interval */
			vesa_off_interval = ((par[1] < 60) ? par[1] : 60) * 60 * HZ;
			break;
#endif
	}
}


-(void) processChar: (unsigned char)c
{
#define lf() do { \
	if (y+1==bottom) \
	{ \
		scrup(foo,top,bottom,1); \
	} \
	else if (y<sy-1) \
		y++; \
} while (0)

#define ri() do { \
	if (y==top) \
	{ \
		scrdown(foo,top,bottom,1); \
	} \
	else if (y>0) \
		y--; \
} while (0)

#define cr() do { x=0; } while (0)


#define cursor_report(foo,bar) do { \
	char buf[40]; \
 \
	sprintf(buf, "\033[%d;%dR", y + (decom ? top+1 : 1), x+1); \
	[self sendCString: buf]; \
} while (0)

#define status_report(foo) do { \
	[self sendCString: "\033[0n"]; \
} while (0)

#define VT102ID "\033[?6c"
#define respond_ID(foo) do { [self sendCString: VT102ID]; } while (0)


	switch (c)
	{
	case 0:
		return;
	case 7:
		NSBeep();
		return;
	case 8:
		if (x>0) x--;
		return;
	case 9:
		while (x < sx - 1) {
			x++;
			if (tab_stop[x >> 5] & (1 << (x & 31)))
				break;
		}
		return;
	case 10: case 11: case 12:
		lf();
/*		if (!is_kbd(lnm))*/
			return;
	case 13:
		cr();
		return;
	case 14:
		charset = 1;
		translate = set_translate(G1_charset,currcons);
		disp_ctrl = 1;
		return;
	case 15:
		charset = 0;
		translate = set_translate(G0_charset,currcons);
		disp_ctrl = 0;
		return;
	case 24: case 26:
		vc_state = ESnormal;
		return;
	case 27:
		vc_state = ESesc;
		return;
	case 127:
//		del(currcons);
		return;
	case 128+27:
		vc_state = ESsquare;
		return;
	}
	switch(vc_state) {
	case ESesc:
		vc_state = ESnormal;
		switch (c) {
		case '[':
			vc_state = ESsquare;
			return;
		case ']':
			vc_state = ESnonstd;
			return;
		case '%':
			vc_state = ESpercent;
			return;
		case 'E':
			cr();
			lf();
			return;
		case 'M':
			ri();
			return;
		case 'D':
			lf();
			return;
		case 'H':
			tab_stop[x >> 5] |= (1 << (x & 31));
			return;
		case 'Z':
			respond_ID(foo);
			return;
		case '7':
			save_cur(currcons);
			return;
		case '8':
			restore_cur(currcons);
			return;
		case '(':
			vc_state = ESsetG0;
			return;
		case ')':
			vc_state = ESsetG1;
			return;
		case '#':
			vc_state = EShash;
			return;
		case 'c':
			[self _reset_terminal];
			return;
		case '>':  /* Numeric keypad */
			NSLog(@"ignore	ESesc >  keypad");
#if 0
			clr_kbd(kbdapplic);
#endif
			return;
		case '=':  /* Appl. keypad */
			NSLog(@"ignore	ESesc =  keypad");
#if 0
			set_kbd(kbdapplic);
#endif
			return;
		}
		return;
	case ESnonstd:
		NSLog(@"ignore palette sequence");
#if 0
		if (c=='P') {   /* palette escape sequence */
			for (npar=0; npar<NPAR; npar++)
				par[npar] = 0 ;
			npar = 0 ;
			vc_state = ESpalette;
			return;
		} else if (c=='R') {   /* reset palette */
			reset_palette(currcons);
			vc_state = ESnormal;
		} else
#endif
			vc_state = ESnormal;
		return;
	case ESpalette:
		NSLog(@"ignore palette sequence (2)");
#if 0
		if ( (c>='0'&&c<='9') || (c>='A'&&c<='F') || (c>='a'&&c<='f') ) {
			par[npar++] = (c>'9' ? (c&0xDF)-'A'+10 : c-'0') ;
			if (npar==7) {
				int i = par[0]*3, j = 1;
				palette[i] = 16*par[j++];
				palette[i++] += par[j++];
				palette[i] = 16*par[j++];
				palette[i++] += par[j++];
				palette[i] = 16*par[j++];
				palette[i] += par[j];
				set_palette(currcons);
				vc_state = ESnormal;
			}
		} else
#endif
			vc_state = ESnormal;
		return;
	case ESsquare:
		for(npar = 0 ; npar < NPAR ; npar++)
			par[npar] = 0;
		npar = 0;
		vc_state = ESgetpars;
		if (c == '[') { /* Function key */
			vc_state=ESfunckey;
			return;
		}
		ques = (c=='?');
		if (ques)
			return;
	case ESgetpars:
		if (c==';' && npar<NPAR-1) {
			npar++;
			return;
		} else if (c>='0' && c<='9') {
			par[npar] *= 10;
			par[npar] += c-'0';
			return;
		} else vc_state=ESgotpars;
	case ESgotpars:
		vc_state = ESnormal;
		switch(c) {
		case 'h':
			set_mode(currcons,1);
			return;
		case 'l':
			set_mode(currcons,0);
			return;
		case 'c':
			NSLog(@"ignore ESgotpars c");
#if 0
			if (ques) {
				if (par[0])
					cursor_type = par[0] | (par[1]<<8) | (par[2]<<16);
				else
					cursor_type = CUR_DEFAULT;
				return;
			}
#endif
			break;
		case 'm':
//			NSLog(@"ignore ESgotpars m"); nothing?
			break;
		case 'n':
			if (!ques) {
				if (par[0] == 5)
					status_report(tty);
				else if (par[0] == 6)
					cursor_report(currcons,tty);
			}
			return;
		}
		if (ques) {
			ques = 0;
			return;
		}
		switch(c) {
		case 'G': case '`':
			if (par[0]) par[0]--;
			gotoxy(currcons,par[0],y);
			return;
		case 'A':
			if (!par[0]) par[0]++;
			gotoxy(currcons,x,y-par[0]);
			return;
		case 'B': case 'e':
			if (!par[0]) par[0]++;
			gotoxy(currcons,x,y+par[0]);
			return;
		case 'C': case 'a':
			if (!par[0]) par[0]++;
			gotoxy(currcons,x+par[0],y);
			return;
		case 'D':
			if (!par[0]) par[0]++;
			gotoxy(currcons,x-par[0],y);
			return;
		case 'E':
			if (!par[0]) par[0]++;
			gotoxy(currcons,0,y+par[0]);
			return;
		case 'F':
			if (!par[0]) par[0]++;
			gotoxy(currcons,0,y-par[0]);
			return;
		case 'd':
			if (par[0]) par[0]--;
			gotoxay(currcons,x,par[0]);
			return;
		case 'H': case 'f':
			if (par[0]) par[0]--;
			if (par[1]) par[1]--;
			gotoxay(currcons,par[1],par[0]);
			return;
		case 'J':
			csi_J(currcons,par[0]);
			return;
		case 'K':
			csi_K(currcons,par[0]);
			return;
		case 'L':
			csi_L(currcons,par[0]);
			return;
		case 'M':
			csi_M(currcons,par[0]);
			return;
		case 'P':
			csi_P(currcons,par[0]);
			return;
		case 'c':
			if (!par[0])
				respond_ID(tty);
			return;
		case 'g':
			if (!par[0])
				tab_stop[x >> 5] &= ~(1 << (x & 31));
			else if (par[0] == 3) {
				tab_stop[0] =
					tab_stop[1] =
					tab_stop[2] =
					tab_stop[3] =
					tab_stop[4] = 0;
			}
			return;
		case 'm':
			csi_m(currcons);
			return;
		case 'q': /* DECLL - but only 3 leds */
			/* map 0,1,2,3 to 0,1,2,4 */
			NSLog(@"ignore ESgotpars q");
#if 0
			if (par[0] < 4)
				setledstate(kbd_table + currcons,
					    (par[0] < 3) ? par[0] : 4);
#endif
			return;
		case 'r':
			if (!par[0])
				par[0]++;
			if (!par[1])
				par[1] = video_num_lines;
			/* Minimum allowed region is 2 lines */
			if (par[0] < par[1] &&
			    par[1] <= video_num_lines) {
				top=par[0]-1;
				bottom=par[1];
				gotoxay(currcons,0,0);
			}
			return;
		case 's':
			save_cur(currcons);
			return;
		case 'u':
			restore_cur(currcons);
			return;
		case 'X':
			csi_X(currcons, par[0]);
			return;
		case '@':
			csi_at(currcons,par[0]);
			return;
		case ']': /* setterm functions */
			setterm_command(currcons);
			return;
		}
		return;
	case ESpercent:
		vc_state = ESnormal;
		switch (c) {
		case '@':  /* defined in ISO 2022 */
			utf = 0;
			return;
		case 'G':  /* prelim official escape code */
		case '8':  /* retained for compatibility */
			utf = 1;
			return;
		}
		return;
	case ESfunckey:
		vc_state = ESnormal;
		return;
	case EShash:
		vc_state = ESnormal;
		NSLog(@"ignore EShash");
#if 0
		if (c == '8') {
			/* DEC screen alignment test. kludge :-) */
			video_erase_char =
				(video_erase_char & 0xff00) | 'E';
			csi_J(currcons, 2);
			video_erase_char =
				(video_erase_char & 0xff00) | ' ';
			do_update_region(currcons, origin, screenbuf_size/2);
		}
#endif
		return;
	case ESsetG0:
		if (c == '0')
			G0_charset = GRAF_MAP;
		else if (c == 'B')
			G0_charset = LAT1_MAP;
		else if (c == 'U')
			G0_charset = IBMPC_MAP;
		else if (c == 'K')
			G0_charset = USER_MAP;
		if (charset == 0)
			translate = set_translate(G0_charset,currcons);
		vc_state = ESnormal;
		return;
	case ESsetG1:
		if (c == '0')
			G1_charset = GRAF_MAP;
		else if (c == 'B')
			G1_charset = LAT1_MAP;
		else if (c == 'U')
			G1_charset = IBMPC_MAP;
		else if (c == 'K')
			G1_charset = USER_MAP;
		if (charset == 1)
			translate = set_translate(G1_charset,currcons);
		vc_state = ESnormal;
		return;
	default:
		vc_state = ESnormal;

		if (utf && c>0x7f)
		{
			if (utf_count && (c&0xc0)==0x80)
			{
				unich=(unich<<6)|(c&0x3f);
				utf_count--;
				if (utf_count)
					return;
			}
			else
			{
				if ((c & 0xe0) == 0xc0)
				{
					utf_count = 1;
					unich = (c & 0x1f);
				}
				else if ((c & 0xf0) == 0xe0)
				{
					utf_count = 2;
					unich = (c & 0x0f);
				}
				else if ((c & 0xf8) == 0xf0)
				{
					utf_count = 3;
					unich = (c & 0x07);
				}
				else if ((c & 0xfc) == 0xf8)
				{
					utf_count = 4;
					unich = (c & 0x03);
				}
				else if ((c & 0xfe) == 0xfc)
				{
					utf_count = 5;
					unich = (c & 0x01);
				}
				else
					utf_count = 0;
				return;
			}
		}
		else
		{
			unich=translate[toggle_meta ? (c|0x80) : c];
		}

		if (x>=sx && decawm)
		{
			cr();
			lf();
		}
		SCREEN(x,y).ch=unich;
		SCREEN(x,y).color=color;
		SCREEN(x,y).attr=(intensity)|(underline<<2)|(reverse<<3)|(blink<<4);
		if (x<sx)
			x++;
		return;
	}
}


-(NSDate *) timedOutEvent: (void *)data type: (RunLoopEventType)t
	forMode: (NSString *)mode
{
	NSLog(@"timedOutEvent:type:forMode: ignored");
	return nil;
}

-(void) receivedEvent: (void *)data
	type: (RunLoopEventType)t
	extra: (void *)extra
	forMode: (NSString *)mode
{
	char buf[8];
	int size,total;
//	BOOL needs_update=NO;

	get_zombies();

//	printf("got event %i %i\n",(int)data,t);
	total=0;
while (1)
{
{
	fd_set s;
	struct timeval tv;
	FD_ZERO(&s);
	FD_SET(master_fd,&s);
	tv.tv_sec=0;
	tv.tv_usec=0;
	if (!select(master_fd+1,&s,NULL,NULL,&tv)) return;
}

	size=read(master_fd,buf,1);
	if (size==0) return;
	if (size<0)
	{
		get_zombies();
		[[NSNotificationCenter defaultCenter]
			postNotificationName: TerminalViewEndOfInput
			object: self];
		return;
	}
//	printf("got %i bytes, %02x '%c'\n",size,buf[0],buf[0]);

	[self processChar: buf[0]];

	[self setNeedsDisplay: YES];

	total++;
	if (total>=4096)
		return; /* give other things a chance */
}
}


-(void) _resizeTerminalTo: (NSSize)size
{
	int nsx,nsy;
	struct winsize ws;
	screen_char_t *nscreen;
	int iy,start,num,copy_sx;

	nsx=size.width/fx;
	nsy=size.height/fy;
	if (nsx==sx && nsy==sy) return;

	nscreen=malloc(nsx*nsy*sizeof(screen_char_t));
	if (!nscreen)
	{
		NSLog(@"Failed to allocate screen buffer!");
		return;
	}
	memset(nscreen,0,sizeof(screen_char_t)*nsx*nsy);

	num=nsy;
	if (num>sy)
		num=sy;
	start=sy-num;

	copy_sx=sx;
	if (copy_sx>nsx)
		copy_sx=nsx;

//	NSLog(@"copy %i+%i %i  (%ix%i)-(%ix%i)\n",start,num,copy_sx,sx,sy,nsx,nsy);

	for (iy=start;iy<start+num;iy++)
	{
		memcpy(&nscreen[nsx*(iy-start)],&screen[sx*iy],copy_sx*sizeof(screen_char_t));
	}

	sx=nsx;
	sy=nsy;
	free(screen);
	screen=nscreen;

	if (x>sx) x=sx-1;
	if (y>sy) y=sy-1;

	top=0;
	bottom=sy;

	ws.ws_row=nsy;
	ws.ws_col=nsx;
	ioctl(master_fd,TIOCSWINSZ,&ws);
}


-(void) setFrame: (NSRect)frame
{
	[super setFrame: frame];
	[self _resizeTerminalTo: frame.size];
}

-(void) setFrameSize: (NSSize)size
{
	[super setFrameSize: size];
	[self _resizeTerminalTo: size];
}


- initWithFrame: (NSRect)frame
{
	int ret;
	NSRunLoop *rl;
	struct winsize ws;

	sx=80;
	sy=24;

	ws.ws_row=sy;
	ws.ws_col=sx;
	ret=forkpty(&master_fd,NULL,NULL,&ws);
	if (ret<0)
	{
		NSLog(_(@"Unable to spawn process: %m."));
		return nil;
	}

	if (ret==0)
	{
		const char *shell=getenv("SHELL");
		if (!shell) shell="/bin/sh";
		putenv("TERM=linux");
		execl(shell,shell,NULL);
		fprintf(stderr,"Unable to spawn shell '%s': %m!",shell);
		exit(1);
	}


	if (!(self=[super initWithFrame: frame])) return nil;

	{
		NSRect r;
		font=[NSFont userFixedPitchFontOfSize: 14];
		r=[font boundingRectForFont];
		fx=r.size.width;
		fy=r.size.height;
		/* TODO: clear up font metrics issues with xlib/backart */
		fx0=fabs(r.origin.x);
		if (r.origin.y<0)
			fy0=fy+r.origin.y;
		else
			fy0=r.origin.y;
//		NSLog(@"Bounding (%g %g)+(%g %g)",fx0,fy0,fx,fy);
	}

	screen=malloc(sizeof(screen_char_t)*sx*sy);

	memset(screen,0,sizeof(screen_char_t)*sx*sy);
	color=def_color=0x07;
	[self _reset_terminal];

//	NSLog(@"Got master fd=%i",master_fd);

	rl=[NSRunLoop currentRunLoop];
	[rl addEvent: (void *)master_fd
		type: ET_RDESC
		watcher: self
		forMode: NSDefaultRunLoopMode];
	return self;
}

-(void) dealloc
{
//	NSLog(@"closing master fd=%i\n",master_fd);
	[[NSRunLoop currentRunLoop] removeEvent: (void *)master_fd
		type: ET_RDESC
		forMode: NSDefaultRunLoopMode
		all: YES];

	close(master_fd);
	get_zombies();

	free(screen);
	screen=NULL;

	[super dealloc];
}

@end


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
	float fx,fy;

	font=[NSFont userFixedPitchFontOfSize: 14];
	fx=[font boundingRectForFont].size.width;
	fy=[font boundingRectForFont].size.height;

	win=[[NSWindow alloc] initWithContentRect: NSMakeRect(100,100,fx*80,fy*24)
		styleMask: NSClosableWindowMask|NSTitledWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
		backing: NSBackingStoreRetained
		defer: YES];
	if (!(self=[super initWithWindow: win])) return nil;

	[win setTitle: @"Terminal"];
	[win setDelegate: self];

	tv=[[TerminalView alloc] init];
	[win setContentView: tv];
	[tv release];
	[win makeFirstResponder: tv];

	[win release];

	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(close)
		name: TerminalViewEndOfInput
		object: tv];

	return self;
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

