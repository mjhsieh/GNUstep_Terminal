/*
copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#include <Foundation/NSNotification.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSBox.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSColorPanel.h>
#include <AppKit/NSColorWell.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSTextField.h>
#include <GNUstepGUI/GSVbox.h>
#include <GNUstepGUI/GSHbox.h>
#include "Label.h"

#include "TerminalViewPrefs.h"


NSString *TerminalViewDisplayPrefsDidChangeNotification=
	@"TerminalViewDisplayPrefsDidChangeNotification";

static NSUserDefaults *ud;


static NSString
	*TerminalFontKey=@"TerminalFont",
	*TerminalFontSizeKey=@"TerminalFontSize",
	*BoldTerminalFontKey=@"BoldTerminalFont",
	*BoldTerminalFontSizeKey=@"BoldTerminalFontSize",
	*UseMultiCellGlyphsKey=@"UseMultiCellGlyphs",
	*CursorStyleKey=@"CursorStyle",
	*ScrollBackLinesKey=@"ScrollBackLines",

	*CursorColorRKey=@"CursorColorR",
	*CursorColorGKey=@"CursorColorG",
	*CursorColorBKey=@"CursorColorB",
	*CursorColorAKey=@"CursorColorA";


static NSFont *terminalFont,*boldTerminalFont;

static BOOL useMultiCellGlyphs;

static float brightness[3]={0.6,0.8,1.0};
static float saturation[3]={1.0,1.0,0.75};

static int cursorStyle;
static NSColor *cursorColor;

static int scrollBackLines;


@implementation TerminalViewDisplayPrefs

+(void) initialize
{
	if (!ud)
		ud=[NSUserDefaults standardUserDefaults];

	if (!cursorColor)
	{
		NSString *s;
		float size;


		size=[ud floatForKey: TerminalFontSizeKey];
		s=[ud stringForKey: TerminalFontKey];
		if (!s)
			terminalFont=[[NSFont userFixedPitchFontOfSize: size] retain];
		else
		{
			terminalFont=[[NSFont fontWithName: s  size: size] retain];
			if (!terminalFont)
				terminalFont=[[NSFont userFixedPitchFontOfSize: size] retain];
		}

		size=[ud floatForKey: BoldTerminalFontSizeKey];
		s=[ud stringForKey: BoldTerminalFontKey];
		if (!s)
			boldTerminalFont=[[NSFont userFixedPitchFontOfSize: size] retain];
		else
		{
			boldTerminalFont=[[NSFont fontWithName: s  size: size] retain];
			if (!boldTerminalFont)
				boldTerminalFont=[[NSFont userFixedPitchFontOfSize: size] retain];
		}

		useMultiCellGlyphs=[ud boolForKey: UseMultiCellGlyphsKey];

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

		scrollBackLines=[ud integerForKey: ScrollBackLinesKey];
		if (scrollBackLines<=0)
			scrollBackLines=256;
	}
}

+(NSFont *) terminalFont
{
	NSFont *f=[terminalFont screenFont];
	if (f)
		return f;
	return terminalFont;
}

+(NSFont *) boldTerminalFont
{
	NSFont *f=[boldTerminalFont screenFont];
	if (f)
		return f;
	return boldTerminalFont;
}

+(BOOL) useMultiCellGlyphs
{
	return useMultiCellGlyphs;
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

+(int) scrollBackLines
{
	return scrollBackLines;
}


-(void) save
{
	if (!top) return;

	cursorStyle=[[m_cursorStyle selectedCell] tag];
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

	ASSIGN(terminalFont,[f_terminalFont font]);
	[ud setFloat: [terminalFont pointSize]
		forKey: TerminalFontSizeKey];
	[ud setObject: [terminalFont fontName]
		forKey: TerminalFontKey];

	ASSIGN(boldTerminalFont,[f_boldTerminalFont font]);
	[ud setFloat: [boldTerminalFont pointSize]
		forKey: BoldTerminalFontSizeKey];
	[ud setObject: [boldTerminalFont fontName]
		forKey: BoldTerminalFontKey];

	scrollBackLines=[f_scrollBackLines intValue];
	[ud setInteger: scrollBackLines
		forKey: ScrollBackLinesKey];

	useMultiCellGlyphs=!![b_useMultiCellGlyphs state];
	[ud setBool: useMultiCellGlyphs
		forKey: UseMultiCellGlyphsKey];

	[[NSNotificationCenter defaultCenter]
		postNotificationName: TerminalViewDisplayPrefsDidChangeNotification
		object: self];
}

-(void) revert
{
	NSFont *f;

	[b_useMultiCellGlyphs setState: useMultiCellGlyphs];

	[m_cursorStyle selectCellWithTag: [[self class] cursorStyle]];
	[w_cursorColor setColor: [[self class] cursorColor]];

	f=[isa terminalFont];
	[f_terminalFont setStringValue: [NSString stringWithFormat: @"%@ %0.1f",[f fontName],[f pointSize]]];
	[f_terminalFont setFont: f];

	f=[isa boldTerminalFont];
	[f_boldTerminalFont setStringValue: [NSString stringWithFormat: @"%@ %0.1f",[f fontName],[f pointSize]]];
	[f_boldTerminalFont setFont: f];

	[f_scrollBackLines setIntValue: scrollBackLines];
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
		[top setDefaultMinYMargin: 2];

		[top addView: [[[NSView alloc] init] autorelease] enablingYResizing: YES];

		{
			NSTextField *f;
			NSButton *b;
			GSHbox *hb;

			hb=[[GSHbox alloc] init];
			[hb setDefaultMinXMargin: 4];
			[hb setAutoresizingMask: NSViewWidthSizable];

			f=[NSTextField newLabel: _(@"Scroll-back length in lines:")];
			[f setAutoresizingMask: 0];
			[hb addView: f  enablingXResizing: NO];
			DESTROY(f);

			f_scrollBackLines=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
			[f sizeToFit];
			[hb addView: f  enablingXResizing: YES];
			DESTROY(f);

			[top addView: hb enablingYResizing: NO];
			DESTROY(hb);

			[top addView: [[[NSView alloc] init] autorelease] enablingYResizing: YES];

			{
				NSBox *b;
				GSTable *t;
				NSColorWell *w;

				b=[[NSBox alloc] init];
				[b setAutoresizingMask: NSViewMinXMargin|NSViewMaxXMargin];
				[b setTitle: _(@"Cursor")];

				t=[[GSTable alloc] initWithNumberOfRows: 2 numberOfColumns: 2];
				[t setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];

				f=[NSTextField newLabel: _(@"Style:")];
				[f setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin|NSViewMaxYMargin];
				[t putView: f  atRow: 0 column: 0  withXMargins: 2 yMargins: 2];
				DESTROY(f);

				{
					NSMatrix *m;
					NSButtonCell *b=[NSButtonCell new];
					NSSize s;

					[b setImagePosition: NSImageOnly];
					[b setHighlightsBy: NSChangeBackgroundCellMask];
					[b setShowsStateBy: NSChangeBackgroundCellMask];

					m=m_cursorStyle=[[NSMatrix alloc] initWithFrame: NSMakeRect(0,0,1,1)
						mode: NSRadioModeMatrix
						prototype: b
						numberOfRows: 1
						numberOfColumns: 4];

					[[m cellAtRow: 0 column: 0] setImage: [NSImage imageNamed: @"cursor_line"]];
					[[m cellAtRow: 0 column: 1] setImage: [NSImage imageNamed: @"cursor_stroked"]];
					[[m cellAtRow: 0 column: 2] setImage: [NSImage imageNamed: @"cursor_filled"]];
					[[m cellAtRow: 0 column: 3] setImage: [NSImage imageNamed: @"cursor_inverted"]];
					[[m cellAtRow: 0 column: 0] setTag: 0];
					[[m cellAtRow: 0 column: 1] setTag: 1];
					[[m cellAtRow: 0 column: 2] setTag: 2];
					[[m cellAtRow: 0 column: 3] setTag: 3];

					s=[[m cellAtRow: 0 column: 0] cellSize];
					s.width+=6;
					s.height+=6;
					[m setCellSize: s];
					[m sizeToCells];

					[t putView: m  atRow: 0 column: 1  withXMargins: 2 yMargins: 2];
					DESTROY(m);
				}


				f=[NSTextField newLabel: _(@"Color:")];
				[f setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin|NSViewMaxYMargin];
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

			[top addView: [[[NSView alloc] init] autorelease] enablingYResizing: YES];


			b=b_useMultiCellGlyphs=[[NSButton alloc] init];
			[b setTitle: _(@"Handle wide (multi-cell) glyphs")];
			[b setButtonType: NSSwitchButton];
			[b sizeToFit];
			[top addView: b enablingYResizing: NO];
			DESTROY(b);


			hb=[[GSHbox alloc] init];
			[hb setDefaultMinXMargin: 4];
			[hb setAutoresizingMask: NSViewWidthSizable];

			f=[NSTextField newLabel: _(@"Bold font:")];
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

			f=[NSTextField newLabel: _(@"Normal font:")];
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


			[top addView: [[[NSView alloc] init] autorelease] enablingYResizing: YES];
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

/*
TODO: The return type here should be (void), but due to forwarding issues in
-base, it has to be (id) to avoid a return type mismatch error
*/
-(id) changeFont: (id)sender
{
	NSFont *f;

	if (!f_cur) return nil;
	f=[sender convertFont: [f_cur font]];
	if (!f) return nil;

	[f_cur setStringValue: [NSString stringWithFormat: @"%@ %0.1f",[f fontName],[f pointSize]]];
	[f_cur setFont: f];

	return nil;
}

@end


static NSString
	*LoginShellKey=@"LoginShell",
	*ShellKey=@"Shell";

static NSString *shell;
static BOOL loginShell;

@implementation TerminalViewShellPrefs

+(void) initialize
{
	if (!ud)
		ud=[NSUserDefaults standardUserDefaults];

	if (!shell)
	{
		loginShell=[ud boolForKey: LoginShellKey];
		shell=[ud stringForKey: ShellKey];
		if (!shell && getenv("SHELL"))
			shell=[NSString stringWithCString: getenv("SHELL")];
		if (!shell)
			shell=@"/bin/sh";
		shell=[shell retain];
	}
}

+(NSString *) shell
{
	return shell;
}

+(BOOL) loginShell
{
	return loginShell;
}


-(void) save
{
	if (!top) return;

	if ([b_loginShell state])
		loginShell=YES;
	else
		loginShell=NO;
	[ud setBool: loginShell forKey: LoginShellKey];

	DESTROY(shell);
	shell=[[tf_shell stringValue] copy];
	[ud setObject: shell forKey: ShellKey];
}

-(void) revert
{
	[b_loginShell setState: loginShell];
	[tf_shell setStringValue: shell];
}


-(NSString *) name
{
	return _(@"Shell");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"Shell")];
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

			b=b_loginShell=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewMinYMargin];
			[b setTitle: _(@"Start as login-shell")];
			[b setButtonType: NSSwitchButton];
			[b sizeToFit];
			[top addView: b enablingYResizing: YES];
			DESTROY(b);

			tf_shell=f=[[NSTextField alloc] init];
			[f sizeToFit];
			[f setAutoresizingMask: NSViewWidthSizable];
			[top addView: f enablingYResizing: NO];
			DESTROY(f);

			f=[NSTextField newLabel: _(@"Shell:")];
			[f setAutoresizingMask: NSViewMaxYMargin];
			[f sizeToFit];
			[top addView: f enablingYResizing: YES];
			DESTROY(f);
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

@end


static NSString
	*CommandAsMetaKey=@"CommandAsMeta",
	*DoubleEscapeKey=@"DoubleEscape";

static BOOL commandAsMeta,doubleEscape;

@implementation TerminalViewKeyboardPrefs

+(void) initialize
{
	if (!ud)
		ud=[NSUserDefaults standardUserDefaults];

	commandAsMeta=[ud boolForKey: CommandAsMetaKey];
	doubleEscape=[ud boolForKey: DoubleEscapeKey];
}

+(BOOL) commandAsMeta
{
	return commandAsMeta;
}

+(BOOL) doubleEscape
{
	return doubleEscape;
}


-(void) save
{
	if (!top) return;

	if ([b_commandAsMeta state])
		commandAsMeta=YES;
	else
		commandAsMeta=NO;
	[ud setBool: commandAsMeta forKey: CommandAsMetaKey];

	if ([b_doubleEscape state])
		doubleEscape=YES;
	else
		doubleEscape=NO;
	[ud setBool: doubleEscape forKey: DoubleEscapeKey];
}

-(void) revert
{
	[b_commandAsMeta setState: commandAsMeta];
	[b_doubleEscape setState: doubleEscape];
}


-(NSString *) name
{
	return _(@"Keyboard");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"Keyboard")];
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
		[top setDefaultMinYMargin: 8];

		{
			NSButton *b;

			b=b_commandAsMeta=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewMinYMargin|NSViewMaxYMargin|NSViewWidthSizable];
			[b setTitle:
				_(@"Treat the command key as meta.\n"
				  @"\n"
				  @"Note that with this enabled, you won't be\n"
				  @"able to access menu entries with the\n"
				  @"keyboard.")];
			[b setButtonType: NSSwitchButton];
			[b sizeToFit];
			[top addView: b enablingYResizing: YES];
			DESTROY(b);

			[top addSeparator];

			b=b_doubleEscape=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewMinYMargin|NSViewMaxYMargin|NSViewWidthSizable];
			[b setTitle:
				_(@"Send a double escape for the escape key.\n"
				  @"\n"
				  @"This means that the escape key will be\n"
				  @"recognized faster by many programs, but\n"
				  @"you can't use it as a substitute for meta.")];
			[b setButtonType: NSSwitchButton];
			[b sizeToFit];
			[top addView: b enablingYResizing: YES];
			DESTROY(b);
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

@end

