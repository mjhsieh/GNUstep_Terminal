/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/
/*
lots borrowed from linux/drivers/char/console.c, GNU GPL:ed
*/
/*
 *  linux/drivers/char/console.c
 *
 *  Copyright (C) 1991, 1992  Linus Torvalds
 */

#include <math.h>
#include <unistd.h>

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

#include <Foundation/NSBundle.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSUserDefaults.h>
#include <gnustep/base/Unicode.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/DPSOperators.h>

#include "TerminalView.h"


NSString
	*TerminalViewEndOfInputNotification=@"TerminalViewEndOfInput",
	*TerminalViewTitleDidChangeNotification=@"TerminalViewTitleDidChange";


#define ADD_DIRTY(ax0,ay0,asx,asy) do { \
		if (dirty.x0==-1) \
		{ \
			dirty.x0=(ax0); \
			dirty.y0=(ay0); \
			dirty.x1=(ax0)+(asx); \
			dirty.y1=(ay0)+(asx); \
		} \
		else \
		{ \
			if (dirty.x0>(ax0)) dirty.x0=(ax0); \
			if (dirty.y0>(ay0)) dirty.y0=(ay0); \
			if (dirty.x1<(ax0)+(asx)) dirty.x1=(ax0)+(asx); \
			if (dirty.y1<(ay0)+(asy)) dirty.y1=(ay0)+(asy); \
		} \
	} while (0)


@interface TerminalView (private) <RunLoopEvents>
@end

@implementation TerminalView

#define SCREEN(x,y) (screen[(y)*sx+(x)])

-(void) _setAttrs: (screen_char_t)sch : (float)x0 : (float)y0 : (NSGraphicsContext *)gc
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

	DPSsethsbcolor(gc,bh,bs,bb);
	DPSrectfill(gc,x0,y0,fx,fy);

	DPSsethsbcolor(gc,h,s,b);

	if (ul)
		DPSrectfill(gc,x0,y0,fx,1);
}

-(void) drawRect: (NSRect)r
{
	int ix,iy;
	unsigned char buf[8];
	unsigned char *pbuf=buf;
	int dlen;
	NSGraphicsContext *cur=GSCurrentContext();
	int x0,y0,x1,y1;

	int total_draw=0;

	NSDebugLLog(@"draw",@"drawRect: (%g %g)+(%g %g) %i\n",
		r.origin.x,r.origin.y,r.size.width,r.size.height,
		draw_all);
	x0=floor(r.origin.x/fx);
	x1=ceil((r.origin.x+r.size.width)/fx);
	if (x0<0) x0=0;
	if (x1>=sx) x1=sx;

	y1=floor(r.origin.y/fy);
	y0=ceil((r.origin.y+r.size.height)/fy);
	y0=sy-y0;
	y1=sy-y1;
	if (y0<0) y0=0;
	if (y1>=sy) y1=sy;

	NSDebugLLog(@"draw",@"dirty (%i %i)-(%i %i)\n",x0,y0,x1,y1);

	if (draw_all)
	{
		DPSsetgray(cur,0.0);
		DPSrectfill(cur,r.origin.x,r.origin.y,r.size.width,r.size.height);
	}

	[font set];

	for (ix=x0;ix<x1;ix++)
		for (iy=y0;iy<y1;iy++)
		{
			if (!(SCREEN(ix,iy).attr&0x80) && !draw_all)
				continue;
			SCREEN(ix,iy).attr&=0x7f;
			total_draw++;
			[self _setAttrs: SCREEN(ix,iy) : ix*fx:(sy-1-iy)*fy : cur];

			if (SCREEN(ix,iy).ch!=0 && SCREEN(ix,iy).ch!=32)
			{
				dlen=sizeof(buf)-1;
				GSFromUnicode(&pbuf,&dlen,&SCREEN(ix,iy).ch,1,NSUTF8StringEncoding,NULL,GSUniTerminate);
				DPSmoveto(cur,ix*fx+fx0,(sy-1-iy)*fy+fy0);
				DPSshow(cur,buf);
			}
		}

	DPSsetrgbcolor(cur,0.2,0.2,1.0);
	DPSrectstroke(cur,cursor_x*fx,(sy-1-cursor_y)*fy,fx,fy);

	NSDebugLLog(@"draw",@"total_draw=%i",total_draw);

	draw_all=NO;
}

-(BOOL) isOpaque
{
	return YES;
}


-(void) keyDown: (NSEvent *)e
{
/* TODO: what do we do with non-ascii characters? */
	NSString *s=[e charactersIgnoringModifiers];
	unsigned int mask=[e modifierFlags];
	unichar ch,ch2;
	const char *str;

	NSDebugLLog(@"key",@"got key flags=%08x  repeat=%i '%@' '%@' %4i %04x %i %04x %i\n",
		[e modifierFlags],[e isARepeat],[e characters],[e charactersIgnoringModifiers],[e keyCode],
		[[e characters] characterAtIndex: 0],[[e characters] length],
		[[e charactersIgnoringModifiers] characterAtIndex: 0],[[e charactersIgnoringModifiers] length]);

	if ([s length]>1)
	{
		int i;
		s=[e characters];
		NSDebugLLog(@"key",@" writing '%@'\n",s);
		for (i=0;i<[s length];i++)
		{
			unichar uc=[s characterAtIndex: 0];
			if (uc>256)
			{
				NSDebugLLog(@"key",@"  couldn't send %04x",uc);
				NSBeep();
			}
			else
			{
				NSDebugLLog(@"key",@"  send %04x",uc);
				write(master_fd,&uc,1);
			}
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
	{
		NSDebugLLog(@"key",@"  meta");
		write(master_fd,"\e",1);
	}

	if (str)
	{
		NSDebugLLog(@"key",@"  send '%s'",str);
		[self ts_sendCString: str];
	}
	else if (ch2>256)
	{
		NSDebugLLog(@"key",@"  couldn't send %04x",ch2);
		NSBeep();
	}
	else if (ch2>0)
	{
		NSDebugLLog(@"key",@"  send %02x",ch2);
		write(master_fd,&ch2,1);
	}
}

-(BOOL) acceptsFirstResponder
{
	return YES;
}


-(void) ts_sendCString: (const char *)msg
{
	int len=strlen(msg);
	write(master_fd,msg,len);
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

//	get_zombies();

//	printf("got event %i %i\n",(int)data,t);
	total=0;
	dirty.x0=-1;

	current_x=cursor_x;
	current_y=cursor_y;

while (1)
{
{
	fd_set s;
	struct timeval tv;
	FD_ZERO(&s);
	FD_SET(master_fd,&s);
	tv.tv_sec=0;
	tv.tv_usec=0;
	if (!select(master_fd+1,&s,NULL,NULL,&tv)) break;
}

	size=read(master_fd,buf,1);
	if (size==0) break;
	if (size<0)
	{
//		get_zombies();
		[[NSNotificationCenter defaultCenter]
			postNotificationName: TerminalViewEndOfInputNotification
			object: self];
		break;
	}
//	printf("got %i bytes, %02x '%c'\n",size,buf[0],buf[0]);


	[tp processByte: buf[0]];

	total++;
	if (total>=8192)
		break; /* give other things a chance */
}

	if (cursor_x!=current_x || cursor_y!=current_y)
	{
		ADD_DIRTY(current_x,current_y,1,1);
		SCREEN(current_x,current_y).attr|=0x80;
		ADD_DIRTY(cursor_x,cursor_y,1,1);
	}

	if (dirty.x0>=0)
	{
		NSRect dr;
//		NSLog(@"dirty=(%i %i)-(%i %i)\n",dirty.x0,dirty.y0,dirty.x1,dirty.y1);
		dr.origin.x=dirty.x0*fx;
		dr.origin.y=dirty.y0*fy;
		dr.size.width=(dirty.x1-dirty.x0)*fx;
		dr.size.height=(dirty.y1-dirty.y0)*fy;
		dr.origin.y=fy*sy-(dr.origin.y+dr.size.height);
//		NSLog(@"-> dirty=(%g %g)+(%g %g)\n",dirty.origin.x,dirty.origin.y,dirty.size.width,dirty.size.height);
		[self setNeedsDisplayInRect: dr];
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

	if (cursor_x>sx) cursor_x=sx-1;
	if (cursor_y>sy) cursor_y=sy-1;

	[tp setTerminalScreenWidth: sx height: sy];

	ws.ws_row=nsy;
	ws.ws_col=nsx;
	ioctl(master_fd,TIOCSWINSZ,&ws);

	draw_all=YES;
	[self setNeedsDisplay: YES];
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
		font=[TerminalView terminalFont];
		r=[font boundingRectForFont];
		fx=r.size.width;
		fy=r.size.height;
		/* TODO: clear up font metrics issues with xlib/backart */
		fx0=fabs(r.origin.x);
		if (r.origin.y<0)
			fy0=fy+r.origin.y;
		else
			fy0=r.origin.y;
		NSDebugLLog(@"term",@"Bounding (%g %g)+(%g %g)",fx0,fy0,fx,fy);
	}

	screen=malloc(sizeof(screen_char_t)*sx*sy);
	memset(screen,0,sizeof(screen_char_t)*sx*sy);
	draw_all=YES;

	tp=[[TerminalParser_Linux alloc] initWithTerminalScreen: self
		width: sx  height: sy];

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
//	get_zombies();

	DESTROY(tp);

	free(screen);
	screen=NULL;

	DESTROY(title_window);
	DESTROY(title_miniwindow);

	[super dealloc];
}


-(NSString *) windowTitle
{
	return title_window;
}

-(NSString *) miniwindowTitle
{
	return title_miniwindow;
}


+(NSFont *) terminalFont
{
	NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
	if ([ud stringForKey: @"TerminalFont"])
	{
		return [NSFont fontWithName: [ud stringForKey: @"TerminalFont"]
			size: [ud floatForKey: @"TerminalFontSize"]];
	}
	return [NSFont userFixedPitchFontOfSize: 0];
}


-(void) ts_setTitle: (NSString *)new_title  type: (int)title_type
{
	NSDebugLLog(@"ts",@"setTitle: %@  type: %i",new_title,title_type);
	if (title_type==1)
		ASSIGN(title_miniwindow,new_title);
	else if (title_type==2)
		ASSIGN(title_window,new_title);
	[[NSNotificationCenter defaultCenter]
		postNotificationName: TerminalViewTitleDidChangeNotification
		object: self];
}


-(void) ts_goto: (int)x:(int)y
{
	NSDebugLLog(@"ts",@"goto: %i:%i",x,y);
	cursor_x=x;
	cursor_y=y;
}

-(void) ts_putChar: (screen_char_t)ch  count: (int)c  at: (int)x:(int)y
{
	int i;
	screen_char_t *s;

	NSDebugLLog(@"ts",@"putChar: '%c' %02x %02x count: %i at: %i:%i",
		ch.ch,ch.color,ch.attr,c,x,y);

	if (y<0 || y>=sy) return;
	if (x+c>sx)
		c=sx-x;
	if (x<0)
	{
		c-=x;
		x=0;
	}
	s=&SCREEN(x,y);
	ch.attr|=0x80;
	for (i=0;i<c;i++)
		*s++=ch;
	ADD_DIRTY(x,y,c,1);
}

-(void) ts_putChar: (screen_char_t)ch  count: (int)c  offset: (int)ofs
{
	int i;
	screen_char_t *s;

	NSDebugLLog(@"ts",@"putChar: '%c' %02x %02x count: %i offset: %i",
		ch.ch,ch.color,ch.attr,c,ofs);

	if (ofs+c>sx*sy)
		c=sx*sy-ofs;
	if (ofs<0)
	{
		c-=ofs;
		ofs=0;
	}
	s=&SCREEN(ofs,0);
	ch.attr|=0x80;
	for (i=0;i<c;i++)
		*s++=ch;
	ADD_DIRTY(0,0,sx,sy); /* TODO */
}

-(void) ts_scrollUp: (int)t:(int)b  rows: (int)nr  save: (BOOL)save
{
	screen_char_t *d, *s;

	NSDebugLLog(@"ts",@"scrollUp: %i:%i  rows: %i  save: %i",
		t,b,nr,save);

	if (t+nr >= b)
		nr = b - t - 1;
	if (b > sy || t >= b || nr < 1)
		return;
	d = &SCREEN(0,t);
	s = &SCREEN(0,t+nr);
	if (current_y>=t && current_y<=b)
	{
		SCREEN(current_x,current_y).attr|=0x80; /* TODO? */
	}
	memmove(d, s, (b-t-nr) * sx * sizeof(screen_char_t));
	{
		float x0,y0,w,h,dx,dy;
		x0=0;
		w=fx*sx;
		y0=(t+nr)*fy;
		h=(b-t-nr)*fy;
		dx=0;
		dy=t*fy;
		y0=sy*fy-y0-h;
		dy=sy*fy-dy-h;
		[self lockFocus];
		DPScomposite(GSCurrentContext(),x0,y0,w,h,[self gState],dx,dy,NSCompositeCopy);
		[self unlockFocus];
	}
	ADD_DIRTY(0,0,sx,sy);
}

-(void) ts_scrollDown: (int)t:(int)b  rows: (int)nr
{
	screen_char_t *s;
	unsigned int step;

	NSDebugLLog(@"ts",@"scrollDown: %i:%i  rows: %i",
		t,b,nr);

	if (t+nr >= b)
		nr = b - t - 1;
	if (b > sy || t >= b || nr < 1)
		return;
	s = &SCREEN(0,t);
	step = sx * nr;
	if (current_y>=t && current_y<=b)
	{
		SCREEN(current_x,current_y).attr|=0x80; /* TODO? */
	}
	memmove(s + step, s, (b-t-nr)*sx*sizeof(screen_char_t));
	{
		float x0,y0,w,h,dx,dy;
		x0=0;
		w=fx*sx;
		y0=(t)*fy;
		h=(b-t-nr)*fy;
		dx=0;
		dy=(t+nr)*fy;
		y0=sy*fy-y0-h;
		dy=sy*fy-dy-h;
		[self lockFocus];
		DPScomposite(GSCurrentContext(),x0,y0,w,h,[self gState],dx,dy,NSCompositeCopy);
		[self unlockFocus];
	}
	ADD_DIRTY(0,0,sx,sy);
}

-(void) ts_shiftRow: (int)y  at: (int)x0  delta: (int)delta
{
	screen_char_t *s,*d;
	int x1,c;
	NSDebugLLog(@"ts",@"shiftRow: %i  at: %i  delta: %i",
		y,x0,delta);

	if (y<0 || y>=sy) return;
	if (x0<0 || x0>=sx) return;

	s=&SCREEN(x0,y);
	x1=x0+delta;
	c=sx-x0;
	if (x1<0)
	{
		x0-=x1;
		c+=x1;
		x1=0;
	}
	if (x1+c>sx)
		c=sx-x1;
	d=&SCREEN(x1,y);
	memmove(d,s,sizeof(screen_char_t)*c);
	draw_all=YES;
	ADD_DIRTY(0,0,sx,sy);
	/* TODO!! */
}

-(screen_char_t) ts_getCharAt: (int)x:(int)y
{
	NSDebugLLog(@"ts",@"getCharAt: %i:%i",x,y);
	return SCREEN(x,y);
}

@end
