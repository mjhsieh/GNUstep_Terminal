/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
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
#include <sys/time.h>
#include <sys/types.h>
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
#include <AppKit/NSApplication.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSScroller.h>
#include <AppKit/DPSOperators.h>

#include "TerminalView.h"

#include "TerminalViewPrefs.h"


@interface NSView (unlockfocus)
-(void) unlockFocusNeedsFlush: (BOOL)flush;
@end


NSString
	*TerminalViewEndOfInputNotification=@"TerminalViewEndOfInput",
	*TerminalViewTitleDidChangeNotification=@"TerminalViewTitleDidChange";


#define ADD_DIRTY(ax0,ay0,asx,asy) do { \
		if (dirty.x0==-1) \
		{ \
			dirty.x0=(ax0); \
			dirty.y0=(ay0); \
			dirty.x1=(ax0)+(asx); \
			dirty.y1=(ay0)+(asy); \
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
	NSFont *f,*current_font=nil;

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

	if (current_scroll)
	{
		int ry;
		screen_char_t *ch;
		for (ix=x0;ix<x1;ix++)
			for (iy=y0;iy<y1;iy++)
			{
				ry=iy+current_scroll;
				if (ry>=0)
					ch=&SCREEN(ix,ry);
				else
					ch=&sbuf[ix+(max_scrollback+ry)*sx];

				if (!(ch->attr&0x80) && !draw_all)
					continue;

				ch->attr&=0x7f;
				total_draw++;
				[self _setAttrs: *ch : ix*fx:(sy-1-iy)*fy : cur];
	
				if (ch->ch!=0 && ch->ch!=32)
				{
					dlen=sizeof(buf)-1;
					GSFromUnicode(&pbuf,&dlen,&ch->ch,1,NSUTF8StringEncoding,NULL,GSUniTerminate);
					DPSmoveto(cur,ix*fx+fx0,(sy-1-iy)*fy+fy0);

					if ((ch->attr&3)==2)
						f=boldFont;
					else
						f=font;
					if (f!=current_font)
					{
						[f set];
						current_font=f;
					}

					DPSshow(cur,buf);
				}

				if (ch->attr&0x40)
					DPScompositerect(cur,ix*fx,(sy-1-iy)*fy,fx,fy,NSCompositeHighlight);
			}

	}
	else
	{
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

					if ((SCREEN(ix,iy).attr&3)==2)
						f=boldFont;
					else
						f=font;
					if (f!=current_font)
					{
						[f set];
						current_font=f;
					}

					DPSshow(cur,buf);
				}

				if (SCREEN(ix,iy).attr&0x40)
					DPScompositerect(cur,ix*fx,(sy-1-iy)*fy,fx,fy,NSCompositeHighlight);
			}
	}

	[[TerminalViewDisplayPrefs cursorColor] set];
	switch ([TerminalViewDisplayPrefs cursorStyle])
	{
	case CURSOR_LINE:
		DPSrectfill(cur,cursor_x*fx,(sy-1-cursor_y+current_scroll)*fy,fx,fy*0.1);
		break;
	case CURSOR_BLOCK_STROKE:
		DPSrectstroke(cur,cursor_x*fx,(sy-1-cursor_y+current_scroll)*fy,fx,fy);
		break;
	case CURSOR_BLOCK_FILL:
		DPSrectfill(cur,cursor_x*fx,(sy-1-cursor_y+current_scroll)*fy,fx,fy);
		break;
	case CURSOR_BLOCK_INVERT:
		DPScompositerect(cur,cursor_x*fx,(sy-1-cursor_y+current_scroll)*fy,fx,fy,
			NSCompositeHighlight);
		break;
	}

	NSDebugLLog(@"draw",@"total_draw=%i",total_draw);

	draw_all=NO;
}

-(BOOL) isOpaque
{
	return YES;
}


-(void) _sendString: (NSString *)s
{
	int i;
	unsigned char tmp;
	unichar ch;
	for (i=0;i<[s length];i++)
	{
		ch=[s characterAtIndex: i];
		if (ch>256)
			NSBeep();
		else
		{
			tmp=ch;
			write(master_fd,&tmp,1);
		}
	}
}

-(void) keyDown: (NSEvent *)e
{
/* TODO: what do we do with non-ascii characters? */
	NSString *s=[e charactersIgnoringModifiers];
	unsigned int mask=[e modifierFlags];
	unichar ch,ch2;
	unsigned char tmp;
	const char *str;

	NSDebugLLog(@"key",@"got key flags=%08x  repeat=%i '%@' '%@' %4i %04x %i %04x %i\n",
		[e modifierFlags],[e isARepeat],[e characters],[e charactersIgnoringModifiers],[e keyCode],
		[[e characters] characterAtIndex: 0],[[e characters] length],
		[[e charactersIgnoringModifiers] characterAtIndex: 0],[[e charactersIgnoringModifiers] length]);

	if ([s length]>1)
	{
		s=[e characters];
		NSDebugLLog(@"key",@" writing '%@'\n",s);
		[self _sendString: s];
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
		s=[e characters];
		[self _sendString: s];
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
		tmp=ch2;
		NSDebugLLog(@"key",@"  send %02x",ch2);
		write(master_fd,&tmp,1);
	}
}

-(void) paste: (id)sender
{
	NSPasteboard *pb=[NSPasteboard generalPasteboard];
	NSString *type;
	NSString *str;

	type=[pb availableTypeFromArray: [NSArray arrayWithObject: NSStringPboardType]];
	if (!type)
		return;
	str=[pb stringForType: NSStringPboardType];
	[self _sendString: str];
}


-(NSString *) _selectionAsString
{
	int ofs=max_scrollback*sx;
	NSMutableString *mstr;
	NSString *tmp;
	unichar buf[32];
	unichar ch;
	int len;
	int i,j;

	if (selection.length==0)
		return nil;

	mstr=[[NSMutableString alloc] init];
	j=selection.location+selection.length;
	len=0;
	for (i=selection.location;i<j;i++)
	{
		if (i%sx==0 && i>selection.location)
		{
			buf[len++]='\n';
			if (len==32)
			{
				tmp=[[NSString alloc] initWithCharacters: buf length: 32];
				[mstr appendString: tmp];
				DESTROY(tmp);
				len=0;
			}
		}
		if (i<0)
			ch=sbuf[ofs+i].ch;
		else
			ch=screen[i].ch;
		if (ch)
		{
			buf[len++]=ch;
			if (len==32)
			{
				tmp=[[NSString alloc] initWithCharacters: buf length: 32];
				[mstr appendString: tmp];
				DESTROY(tmp);
				len=0;
			}
		}
	}

	if (len)
	{
		tmp=[[NSString alloc] initWithCharacters: buf length: len];
		[mstr appendString: tmp];
		DESTROY(tmp);
	}

	return AUTORELEASE(mstr);
}

-(void) _setSelection: (struct selection_range)s
{
	int i,j,ofs2;
	if (!s.length && !selection.length)
		return;
	if (s.length==selection.length && s.location==selection.location)
		return;

	if (s.location<-sb_length*sx)
	{
		s.length+=sb_length*sx+s.location;
		s.location=-sb_length*sx;
	}
	if (s.location+s.length>sx*sy)
	{
		s.length=sx*sy-s.location;
	}
	if (s.length<0)
		s.length=0;

	ofs2=max_scrollback*sx;

	j=selection.location+selection.length;
	if (j>s.location)
		j=s.location;

	for (i=selection.location;i<j && i<0;i++)
	{
		sbuf[ofs2+i].attr&=0xbf;
		sbuf[ofs2+i].attr|=0x80;
	}
	for (;i<j;i++)
	{
		screen[i].attr&=0xbf;
		screen[i].attr|=0x80;
	}

	i=s.location+s.length;
	if (i<selection.location)
		i=selection.location;
	j=selection.location+selection.length;
	for (;i<j && i<0;i++)
	{
		sbuf[ofs2+i].attr&=0xbf;
		sbuf[ofs2+i].attr|=0x80;
	}
	for (;i<j;i++)
	{
		screen[i].attr&=0xbf;
		screen[i].attr|=0x80;
	}

	i=s.location;
	j=s.location+s.length;
	for (;i<j && i<0;i++)
	{
		if (!(sbuf[ofs2+i].attr&0x40))
			sbuf[ofs2+i].attr|=0xc0;
	}
	for (;i<j;i++)
	{
		if (!(screen[i].attr&0x40))
			screen[i].attr|=0xc0;
	}

	selection=s;
	[self setNeedsDisplay: YES];
}

-(void) _clearSelection
{
	struct selection_range s;
	s.location=s.length=0;
	[self _setSelection: s];
}


-(void) copy: (id)sender
{
	NSPasteboard *pb=[NSPasteboard generalPasteboard];
	NSString *s=[self _selectionAsString];
	if (!s)
	{
		NSBeep();
		return;
	}
	[pb declareTypes: [NSArray arrayWithObject: NSStringPboardType]
		owner: self];
	[pb setString: s forType: NSStringPboardType];
}


-(BOOL) writeSelectionToPasteboard: (NSPasteboard *)pb
	types: (NSArray *)t
{
	int i;
	[pb declareTypes: t  owner: self];
	for (i=0;i<[t count];i++)
	{
		if ([[t objectAtIndex: i] isEqual: NSStringPboardType])
		{
			[pb setString: [self _selectionAsString]
				forType: NSStringPboardType];
			return YES;
		}
	}
	return NO;
}

-(BOOL) readSelectionFromPasteboard: (NSPasteboard *)pb
{ /* TODO: is it really necessary to implement this? */
	return YES;
}

-(id) validRequestorForSendType: (NSString *)st
	returnType: (NSString *)rt
{
	if (!selection.length)
		return nil;
	if (st!=nil && ![st isEqual: NSStringPboardType])
		return nil;
	if (rt!=nil)
		return nil;
	return self;
}


-(void) mouseDown: (NSEvent *)e
{
	int ofs0,ofs1,first;
	NSPoint p;
	struct selection_range s;

	first=YES;
	ofs0=0; /* get compiler to shut up */
	while ([e type]!=NSLeftMouseUp)
	{
		p=[e locationInWindow];

		p=[self convertPoint: p  fromView: nil];
		p.x=floor(p.x/fx);
		if (p.x<0) p.x=0;
		if (p.x>=sx) p.x=sx-1;
		p.y=ceil(p.y/fy);
		if (p.y<0) p.y=0;
		if (p.y>sy) p.y=sy;
		p.y=sy-p.y+current_scroll;
		ofs1=((int)p.x)+((int)p.y)*sx;

		if (first)
		{
			ofs0=ofs1;
			first=0;
		}

		if (ofs1>ofs0)
		{
			s.location=ofs0;
			s.length=ofs1-ofs0;
		}
		else
		{
			s.location=ofs1;
			s.length=ofs0-ofs1;
		}

		[self _setSelection: s];
		[self displayIfNeeded];

		e=[NSApp nextEventMatchingMask: NSLeftMouseDownMask|NSLeftMouseUpMask|
		                                NSLeftMouseDraggedMask|NSMouseMovedMask
			untilDate: [NSDate distantFuture]
			inMode: NSEventTrackingRunLoopMode
			dequeue: YES];
	}
}


-(void) scrollWheel: (NSEvent *)e
{
	float delta=[e deltaY];
	int new_scroll;
	int mult;

	if ([e modifierFlags]&NSShiftKeyMask)
		mult=1;
	else if ([e modifierFlags]&NSControlKeyMask)
		mult=sy;
	else
		mult=5;

	new_scroll=current_scroll-delta*mult;
	if (new_scroll>0)
		new_scroll=0;
	if (new_scroll<-sb_length)
		new_scroll=-sb_length;

	if (new_scroll==current_scroll)
		return;
	current_scroll=new_scroll;

	if (sb_length)
		[scroller setFloatValue: (current_scroll+sb_length)/(float)(sb_length)
			knobProportion: sy/(float)(sy+sb_length)];
	else
		[scroller setFloatValue: 1.0 knobProportion: 1.0];

	draw_all=YES;
	[self setNeedsDisplay: YES];
}


-(BOOL) acceptsFirstResponder
{
	return YES;
}
-(BOOL) becomeFirstResponder
{
	return YES;
}
-(BOOL) resignFirstResponder
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
	num_scrolls=0;
	dirty.x0=-1;

	current_x=cursor_x;
	current_y=cursor_y;

	[self _clearSelection]; /* TODO? */

	NSDebugLLog(@"term",@"receiving output");

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
		if (size<=0)
		{
//			get_zombies();
			[[NSNotificationCenter defaultCenter]
				postNotificationName: TerminalViewEndOfInputNotification
				object: self];
			break;
		}
//		printf("got %i bytes, %02x '%c'\n",size,buf[0],buf[0]);


		[tp processByte: buf[0]];

		total++;
		if (total>=8192 || num_scrolls>100)
			break; /* give other things a chance */
	}

	if (cursor_x!=current_x || cursor_y!=current_y)
	{
		ADD_DIRTY(current_x,current_y,1,1);
		SCREEN(current_x,current_y).attr|=0x80;
		ADD_DIRTY(cursor_x,cursor_y,1,1);
	}

	NSDebugLLog(@"term",@"done (%i %i) (%i %i)\n",
		dirty.x0,dirty.y0,dirty.x1,dirty.y1);

	if (dirty.x0>=0)
	{
		NSRect dr;

		if (sb_length)
			[scroller setFloatValue: (current_scroll+sb_length)/(float)(sb_length)
				knobProportion: sy/(float)(sy+sb_length)];
		else
			[scroller setFloatValue: 1.0 knobProportion: 1.0];

//		NSLog(@"dirty=(%i %i)-(%i %i)\n",dirty.x0,dirty.y0,dirty.x1,dirty.y1);
		dr.origin.x=dirty.x0*fx;
		dr.origin.y=dirty.y0*fy;
		dr.size.width=(dirty.x1-dirty.x0)*fx;
		dr.size.height=(dirty.y1-dirty.y0)*fy;
		dr.origin.y=fy*sy-(dr.origin.y+dr.size.height);
//		NSLog(@"-> dirty=(%g %g)+(%g %g)\n",dirty.origin.x,dirty.origin.y,dirty.size.width,dirty.size.height);
		[self setNeedsDisplayInRect: dr];

		if (current_scroll!=0)
		{ /* TODO */
			current_scroll=0;
			draw_all=YES;
			[self setNeedsDisplay: YES];
		}
	}
}


-(void) _resizeTerminalTo: (NSSize)size
{
	int nsx,nsy;
	struct winsize ws;
	screen_char_t *nscreen,*nsbuf;
	int iy,ny;
	int copy_sx;

	nsx=size.width/fx;
	nsy=size.height/fy;

	NSDebugLLog(@"term",@"_resizeTerminalTo: (%g %g) %i %i (%g %g)\n",
		size.width,size.height,
		nsx,nsy,
		nsx*fx,nsy*fy);

	if (ignore_resize)
	{
		NSDebugLLog(@"term",@"ignored");
		return;
	}

	if (nsx<1) nsx=1;
	if (nsy<1) nsy=1;

	if (nsx==sx && nsy==sy)
	{
		/* Do a complete redraw anyway. Even though we don't really need it,
		the resize ight have caused other things to overwrite our part of the
		window. */
		draw_all=YES;
		return;
	}

	[self _clearSelection]; /* TODO? */

	nscreen=malloc(nsx*nsy*sizeof(screen_char_t));
	nsbuf=malloc(nsx*max_scrollback*sizeof(screen_char_t));
	if (!nscreen || !nsbuf)
	{
		NSLog(@"Failed to allocate screen buffer!");
		return;
	}
	memset(nscreen,0,sizeof(screen_char_t)*nsx*nsy);
	memset(nsbuf,0,sizeof(screen_char_t)*nsx*max_scrollback);

	copy_sx=sx;
	if (copy_sx>nsx)
		copy_sx=nsx;

//	NSLog(@"copy %i+%i %i  (%ix%i)-(%ix%i)\n",start,num,copy_sx,sx,sy,nsx,nsy);

/* TODO: handle resizing and scrollback */
	for (iy=-sb_length;iy<sy;iy++)
	{
		screen_char_t *src,*dst;
		ny=iy-sy+nsy;
		if (ny<-max_scrollback)
			continue;

		if (iy<0)
			src=&sbuf[sx*(max_scrollback+iy)];
		else
			src=&screen[sx*iy];

		if (ny<0)
			dst=&nsbuf[nsx*(max_scrollback+ny)];
		else
			dst=&nscreen[nsx*ny];

		memcpy(dst,src,copy_sx*sizeof(screen_char_t));
	}

	sb_length=sb_length+sy-nsy;
	if (sb_length>max_scrollback)
		sb_length=max_scrollback;
	if (sb_length<0)
		sb_length=0;

	sx=nsx;
	sy=nsy;
	free(screen);
	free(sbuf);
	screen=nscreen;
	sbuf=nsbuf;

	if (cursor_x>sx) cursor_x=sx-1;
	if (cursor_y>sy) cursor_y=sy-1;

	if (sb_length)
		[scroller setFloatValue: (current_scroll+sb_length)/(float)(sb_length)
			knobProportion: sy/(float)(sy+sb_length)];
	else
		[scroller setFloatValue: 1.0 knobProportion: 1.0];

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
	sy=25;

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
		boldFont=[TerminalViewDisplayPrefs boldTerminalFont];
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

	max_scrollback=256;
	sbuf=malloc(sizeof(screen_char_t)*sx*max_scrollback);
	memset(sbuf,0,sizeof(screen_char_t)*sx*max_scrollback);

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


-(void) _updateScroll: (id)sender
{
	int new_scroll;
	int part=[scroller hitPart];
	BOOL update=YES;

	if (part==NSScrollerKnob ||
	    part==NSScrollerKnobSlot)
	{
		float f=[scroller floatValue];
		new_scroll=(f-1.0)*sb_length;
		update=NO;
	}
	else if (part==NSScrollerDecrementLine)
		new_scroll=current_scroll-1;
	else if (part==NSScrollerDecrementPage)
		new_scroll=current_scroll-sy/2;
	else if (part==NSScrollerIncrementLine)
		new_scroll=current_scroll+1;
	else if (part==NSScrollerIncrementPage)
		new_scroll=current_scroll+sy/2;
	else
		return;

	if (new_scroll>0)
		new_scroll=0;
	if (new_scroll<-sb_length)
		new_scroll=-sb_length;

	if (new_scroll!=current_scroll)
	{
		current_scroll=new_scroll;
		draw_all=YES;
		[self setNeedsDisplay: YES];

		if (update)
		{
			if (sb_length)
				[scroller setFloatValue: (current_scroll+sb_length)/(float)(sb_length)
					knobProportion: sy/(float)(sy+sb_length)];
			else
				[scroller setFloatValue: 1.0 knobProportion: 1.0];
		}
	}
}

-(void) setScroller: (NSScroller *)sc
{
	[scroller setTarget: nil];
	ASSIGN(scroller,sc);
	if (sb_length)
		[scroller setFloatValue: (current_scroll+sb_length)/(float)(sb_length)
			knobProportion: sy/(float)(sy+sb_length)];
	else
		[scroller setFloatValue: 1.0 knobProportion: 1.0];
	[scroller setTarget: self];
	[scroller setAction: @selector(_updateScroll:)];
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

	[scroller setTarget: nil];
	DESTROY(scroller);

	free(screen);
	free(sbuf);
	screen=NULL;
	sbuf=NULL;

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
	return [TerminalViewDisplayPrefs terminalFont];
}


-(void) ts_setTitle: (NSString *)new_title  type: (int)title_type
{
	NSDebugLLog(@"ts",@"setTitle: %@  type: %i",new_title,title_type);
	if (title_type==1 || title_type==0)
		ASSIGN(title_miniwindow,new_title);
	if (title_type==2 || title_type==0)
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
	if (cursor_x>=sx) cursor_x=sx-1;
	if (cursor_x<0) cursor_x=0;
	if (cursor_y>=sy) cursor_y=sy-1;
	if (cursor_y<0) cursor_y=0;
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

	if (save && t==0 && b==sy) /* TODO? */
	{
		int num;
		if (nr<max_scrollback)
		{
			memmove(sbuf,&sbuf[sx*nr],sizeof(screen_char_t)*sx*(max_scrollback-nr));
			num=nr;
		}
		else
			num=max_scrollback;

		if (num<sy)
		{
			memmove(&sbuf[sx*(max_scrollback-num)],screen,num*sx*sizeof(screen_char_t));
		}
		else
		{
			memmove(&sbuf[sx*(max_scrollback-num)],screen,sy*sx*sizeof(screen_char_t));

			/* TODO: should this use video_erase_char? */
			memset(&sbuf[sx*(max_scrollback-num+sy)],0,sx*(num-sy)*sizeof(screen_char_t));
		}
		sb_length+=num;
		if (sb_length>max_scrollback)
			sb_length=max_scrollback;
	}

	if (t+nr >= b)
		nr = b - t - 1;
	if (b > sy || t >= b || nr < 1)
		return;
	d = &SCREEN(0,t);
	s = &SCREEN(0,t+nr);

	if (current_y>=t && current_y<=b)
	{
		SCREEN(current_x,current_y).attr|=0x80; /* TODO? */
		/*
		TODO: does this properly handle the case when the cursor is in
		an area that gets scrolled 'over'?
		*/
	}
	memmove(d, s, (b-t-nr) * sx * sizeof(screen_char_t));
	if (!current_scroll)
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
		[self unlockFocusNeedsFlush: NO];
		num_scrolls++;
	}
	ADD_DIRTY(0,t,sx,b-t); /* TODO */
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
	if (!current_scroll)
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
		[self unlockFocusNeedsFlush: NO];
		num_scrolls++;
	}
	ADD_DIRTY(0,t,sx,b-t); /* TODO */
}

-(void) ts_shiftRow: (int)y  at: (int)x0  delta: (int)delta
{
	screen_char_t *s,*d;
	int x1,c;
	NSDebugLLog(@"ts",@"shiftRow: %i  at: %i  delta: %i",
		y,x0,delta);

	if (y<0 || y>=sy) return;
	if (x0<0 || x0>=sx) return;

	if (current_y==y)
	{
		SCREEN(current_x,current_y).attr|=0x80; /* TODO? */
	}

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
	if (!current_scroll)
	{
		float cx0,y0,w,h,dx,dy;

		cx0=x0*fx;
		w=fx*c;
		dx=x1*fx;

		y0=y*fy;
		h=fy;
		dy=y0;

		y0=sy*fy-y0-h;
		dy=sy*fy-dy-h;
		[self lockFocus];
		DPScomposite(GSCurrentContext(),cx0,y0,w,h,[self gState],dx,dy,NSCompositeCopy);
		[self unlockFocusNeedsFlush: NO];
		num_scrolls++;
	}
	ADD_DIRTY(0,y,sx,1);
}

-(screen_char_t) ts_getCharAt: (int)x:(int)y
{
	NSDebugLLog(@"ts",@"getCharAt: %i:%i",x,y);
	return SCREEN(x,y);
}


-(void) setIgnoreResize: (BOOL)ignore
{
	ignore_resize=ignore;
}


+(void) registerPasteboardTypes
{
	NSArray *types=[NSArray arrayWithObject: NSStringPboardType];
	[NSApp registerServicesMenuSendTypes: types returnTypes: nil];
}

@end

