/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSColorPanel.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSColorWell.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSBox.h>
#include <AppKit/GSVbox.h>
#include <AppKit/GSHbox.h>

#include "TerminalViewPrefs.h"


NSString *TerminalViewDisplayPrefsDidChangeNotification=
	@"TerminalViewDisplayPrefsDidChangeNotification";

static NSUserDefaults *ud;

static NSString
	*TerminalFontKey=@"TerminalFont",
	*TerminalFontSizeKey=@"TerminalFontSize",
	*BoldTerminalFontKey=@"BoldTerminalFont",
	*BoldTerminalFontSizeKey=@"BoldTerminalFontSize",
	*CursorStyleKey=@"CursorStyle",

	*CursorColorRKey=@"CursorColorR",
	*CursorColorGKey=@"CursorColorG",
	*CursorColorBKey=@"CursorColorB",
	*CursorColorAKey=@"CursorColorA";


static NSFont *terminalFont,*boldTerminalFont;

static float brightness[3]={0.6,0.8,1.0};
static float saturation[3]={1.0,1.0,0.75};

static int cursorStyle;
static NSColor *cursorColor;


@implementation TerminalViewDisplayPrefs

+(void) initialize
{
	if (!ud)
	{
		NSString *s;
		float size;

		ud=[NSUserDefaults standardUserDefaults];

		size=[ud floatForKey: TerminalFontSizeKey];
		s=[ud stringForKey: TerminalFontKey];
		if (!s)
			terminalFont=[NSFont userFixedPitchFontOfSize: size];
		else
			terminalFont=[NSFont fontWithName: s  size: size];

		size=[ud floatForKey: BoldTerminalFontSizeKey];
		s=[ud stringForKey: BoldTerminalFontKey];
		if (!s)
			boldTerminalFont=[NSFont userFixedPitchFontOfSize: size];
		else
			boldTerminalFont=[NSFont fontWithName: s  size: size];

		cursorStyle=[ud integerForKey: CursorStyleKey];
		if ([ud objectForKey: CursorColorRKey])
		{
			float r,g,b,a;
			r=[ud floatForKey: CursorColorRKey];
			g=[ud floatForKey: CursorColorGKey];
			b=[ud floatForKey: CursorColorBKey];
			a=[ud floatForKey: CursorColorAKey];
			cursorColor=[[NSColor colorWithCalibratedRed: r
				green: g
				blue: b
				alpha: a] retain];
		}
		else
		{
			cursorColor=[[NSColor whiteColor] retain];
		}
	}
}

+(NSFont *) terminalFont
{
	return terminalFont;
}

+(NSFont *) boldTerminalFont
{
	return boldTerminalFont;
}

+(const float *) brightnessForIntensities
{
	return brightness;
}
+(const float *) saturationForIntensities
{
	return saturation;
}

+(int) cursorStyle
{
	return cursorStyle;
}

+(NSColor *) cursorColor
{
	return cursorColor;
}


-(void) save
{
	if (!top) return;

	cursorStyle=[pb_cursorStyle indexOfSelectedItem];
	[ud setInteger: cursorStyle
		forKey: CursorStyleKey];

	{
		DESTROY(cursorColor);
		cursorColor=[w_cursorColor color];
		cursorColor=[[cursorColor colorUsingColorSpaceName: NSCalibratedRGBColorSpace] retain];
		[ud setFloat: [cursorColor redComponent]
			forKey: CursorColorRKey];
		[ud setFloat: [cursorColor greenComponent]
			forKey: CursorColorGKey];
		[ud setFloat: [cursorColor blueComponent]
			forKey: CursorColorBKey];
		[ud setFloat: [cursorColor alphaComponent]
			forKey: CursorColorAKey];
	}

	terminalFont=[f_terminalFont font];
	[ud setFloat: [terminalFont pointSize]
		forKey: TerminalFontSizeKey];
	[ud setObject: [terminalFont fontName]
		forKey: TerminalFontKey];

	boldTerminalFont=[f_boldTerminalFont font];
	[ud setFloat: [boldTerminalFont pointSize]
		forKey: BoldTerminalFontSizeKey];
	[ud setObject: [boldTerminalFont fontName]
		forKey: BoldTerminalFontKey];
}

-(void) revert
{
	NSFont *f;

	[pb_cursorStyle selectItemAtIndex: [[self class] cursorStyle]];
	[w_cursorColor setColor: [[self class] cursorColor]];

	f=[[self class] terminalFont];
	[f_terminalFont setStringValue: [NSString stringWithFormat: @"%@ %0.1f",[f fontName],[f pointSize]]];
	[f_terminalFont setFont: f];

	f=[[self class] boldTerminalFont];
	[f_boldTerminalFont setStringValue: [NSString stringWithFormat: @"%@ %0.1f",[f fontName],[f pointSize]]];
	[f_boldTerminalFont setFont: f];
}


-(NSString *) name
{
	return _(@"Display");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"Display")];
	[b sizeToFit];
}

-(void) willHide
{
}

-(NSView *) willShow
{
	if (!top)
	{
		top=[[GSVbox alloc] init];
		[top setDefaultMinYMargin: 4];

		{
			NSTextField *f;
			NSButton *b;
			GSHbox *hb;

			{
				NSBox *b;
				GSTable *t;
				NSPopUpButton *pb;
				NSColorWell *w;

				b=[[NSBox alloc] init];
//				[b setAutoresizingMask: NSViewWidthSizable];
				[b setTitle: _(@"Cursor")];

				t=[[GSTable alloc] initWithNumberOfRows: 2 numberOfColumns: 2];
				[t setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];

				f=[[NSTextField alloc] init];
				[f setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin|NSViewMaxYMargin];
				[f setStringValue: _(@"Style:")];
				[f setEditable: NO];
				[f setDrawsBackground: NO];
				[f setBordered: NO];
				[f setBezeled: NO];
				[f setSelectable: NO];
				[f sizeToFit];
				[t putView: f  atRow: 0 column: 0  withXMargins: 2 yMargins: 2];
				DESTROY(f);

				pb_cursorStyle=pb=[[NSPopUpButton alloc] init];
				[pb setAutoenablesItems: NO];
				[pb addItemWithTitle: _(@"Line")];
				[pb addItemWithTitle: _(@"Stroked block")];
				[pb addItemWithTitle: _(@"Filled block")];
				[pb addItemWithTitle: _(@"Inverted block")];
				[pb sizeToFit];
				[t putView: pb  atRow: 0 column: 1  withXMargins: 2 yMargins: 2];
				DESTROY(pb);


				f=[[NSTextField alloc] init];
				[f setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin|NSViewMaxYMargin];
				[f setStringValue: _(@"Color:")];
				[f setEditable: NO];
				[f setDrawsBackground: NO];
				[f setBordered: NO];
				[f setBezeled: NO];
				[f setSelectable: NO];
				[f sizeToFit];
				[t putView: f  atRow: 1 column: 0  withXMargins: 2 yMargins: 2];
				DESTROY(f);

				w_cursorColor=w=[[NSColorWell alloc] initWithFrame: NSMakeRect(0,0,40,30)];
				[t putView: w  atRow: 1 column: 1  withXMargins: 2 yMargins: 2];
				DESTROY(w);

				[[NSColorPanel sharedColorPanel] setShowsAlpha: YES];


				[t sizeToFit];
				[b setContentView: t];
				[b sizeToFit];
				[top addView: b enablingYResizing: NO];
				DESTROY(b);
			}

			hb=[[GSHbox alloc] init];
			[hb setDefaultMinXMargin: 4];
			[hb setAutoresizingMask: NSViewWidthSizable];

			f=[[NSTextField alloc] init];
			[f setStringValue: _(@"Bold font:")];
			[f setEditable: NO];
			[f setDrawsBackground: NO];
			[f setBordered: NO];
			[f setBezeled: NO];
			[f setSelectable: NO];
			[f sizeToFit];
			[f setAutoresizingMask: 0];
			[hb addView: f  enablingXResizing: NO];
			DESTROY(f);

			f_boldTerminalFont=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
			[f setEditable: NO];
			[hb addView: f  enablingXResizing: YES];
			DESTROY(f);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Pick font...")];
			[b setTarget: self];
			[b setAction: @selector(_pickBoldTerminalFont:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			[top addView: hb enablingYResizing: NO];
			DESTROY(hb);


			hb=[[GSHbox alloc] init];
			[hb setDefaultMinXMargin: 4];
			[hb setAutoresizingMask: NSViewWidthSizable];

			f=[[NSTextField alloc] init];
			[f setStringValue: _(@"Normal font:")];
			[f setEditable: NO];
			[f setDrawsBackground: NO];
			[f setBordered: NO];
			[f setBezeled: NO];
			[f setSelectable: NO];
			[f sizeToFit];
			[f setAutoresizingMask: 0];
			[hb addView: f  enablingXResizing: NO];
			DESTROY(f);

			f_terminalFont=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
			[f setEditable: NO];
			[hb addView: f  enablingXResizing: YES];
			DESTROY(f);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Pick font...")];
			[b setTarget: self];
			[b setAction: @selector(_pickTerminalFont:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			[top addView: hb enablingYResizing: NO];
			DESTROY(hb);
		}

		[self revert];
	}
	return top;
}

-(void) dealloc
{
	DESTROY(top);
	[super dealloc];
}


-(void) _pickFont
{
	NSFontManager *fm=[NSFontManager sharedFontManager];
	[fm setSelectedFont: [f_cur font] isMultiple: NO];
	[fm orderFrontFontPanel: self];
}

-(void) _pickTerminalFont: (id)sender
{
	f_cur=f_terminalFont;
	[self _pickFont];
}

-(void) _pickBoldTerminalFont: (id)sender
{
	f_cur=f_boldTerminalFont;
	[self _pickFont];
}

-(void) changeFont: (id)sender
{
	NSFont *f;

	if (!f_cur) return;
	f=[sender convertFont: [f_cur font]];
	if (!f) return;

	[f_cur setStringValue: [NSString stringWithFormat: @"%@ %0.1f",[f fontName],[f pointSize]]];
	[f_cur setFont: f];
}

@end

