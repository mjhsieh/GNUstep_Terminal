/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSBox.h>
#include <AppKit/GSTable.h>
#include <AppKit/GSVbox.h>
#include "Label.h"

#include "TerminalWindowPrefs.h"


static NSUserDefaults *ud;


static NSString
	*WindowCloseBehaviorKey=@"WindowCloseBehavior",
	*WindowHeightKey=@"WindowHeight",
	*WindowWidthKey=@"WindowWidth",
	*AddYBordersKey=@"AddYBorders";


static int windowCloseBehavior;
static int windowWidth,windowHeight;
static BOOL addYBorders;


@implementation TerminalWindowPrefs

+(void) initialize
{
	if (!ud)
	{
		ud=[NSUserDefaults standardUserDefaults];

		windowCloseBehavior=[ud integerForKey: WindowCloseBehaviorKey];
		windowWidth=[ud integerForKey: WindowWidthKey];
		windowHeight=[ud integerForKey: WindowHeightKey];
		addYBorders=[ud boolForKey: AddYBordersKey];

		if (windowWidth<=0)
			windowWidth=80;
		if (windowHeight<=0)
			windowHeight=25;
	}
}

+(int) windowCloseBehavior
{
	return windowCloseBehavior;
}

+(int) defaultWindowWidth
{
	return windowWidth;
}
+(int) defaultWindowHeight
{
	return windowHeight;
}

+(BOOL) addYBorders
{
	return addYBorders;
}


-(void) save
{
	if (!top) return;

	windowCloseBehavior=[pb_close indexOfSelectedItem];
	[ud setInteger: windowCloseBehavior  forKey: WindowCloseBehaviorKey];

	addYBorders=[b_addYBorders state];
	[ud setBool: addYBorders  forKey: AddYBordersKey];

	windowWidth=[tf_width intValue];
	windowHeight=[tf_height intValue];

	if (windowWidth<=0)
		windowWidth=80;
	if (windowHeight<=0)
		windowHeight=25;

	[ud setInteger: windowWidth  forKey: WindowWidthKey];
	[ud setInteger: windowHeight  forKey: WindowHeightKey];
}

-(void) revert
{
	[pb_close selectItemAtIndex: windowCloseBehavior];

	[tf_width setIntValue: windowWidth];
	[tf_height setIntValue: windowHeight];

	[b_addYBorders setState: addYBorders];
}


-(NSString *) name
{
	return _(@"Terminal Window");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"Terminal\nWindow")];
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

		[top addView: [[[NSView alloc] init] autorelease] enablingYResizing: YES];

		{
			NSTextField *f;


			{
				NSPopUpButton *pb;
				pb_close=pb=[[NSPopUpButton alloc] init];
				[pb setAutoresizingMask: NSViewMinXMargin|NSViewMaxXMargin];
				[pb setAutoenablesItems: NO];
				[pb addItemWithTitle: _(@"Close new windows when idle")];
				[pb addItemWithTitle: _(@"Don't close new windows")];
				[pb sizeToFit];
				[top addView: pb enablingYResizing: NO];
				DESTROY(pb);
			}

			{
				NSBox *b;
				GSTable *t;

				b=[[NSBox alloc] init];
				[b setAutoresizingMask: NSViewWidthSizable];
				[b setTitle: _(@"Default size")];

				t=[[GSTable alloc] initWithNumberOfRows: 2 numberOfColumns: 2];

				f=[NSTextField newLabel: _(@"Width:")];
				[f setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin|NSViewMaxYMargin];
				[t putView: f atRow: 1 column: 0
					withXMargins: 2 yMargins: 2];
				tf_width=f=[[NSTextField alloc] init];
				[f setAutoresizingMask: NSViewWidthSizable];
				[f sizeToFit];
				[t putView: f atRow: 1 column: 1];

				f=[NSTextField newLabel: _(@"Height:")];
				[f setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin|NSViewMaxYMargin];
				[t putView: f atRow: 0 column: 0
					withXMargins: 2 yMargins: 2];
				tf_height=f=[[NSTextField alloc] init];
				[f setAutoresizingMask: NSViewWidthSizable];
				[f sizeToFit];
				[t putView: f atRow: 0 column: 1];

				[b setContentView: t];
				[b sizeToFit];
				DESTROY(t);

				[top addView: b enablingYResizing: NO];
				DESTROY(b);
			}

			{
				NSButton *b;

				b=b_addYBorders=[[NSButton alloc] init];
				[b setAutoresizingMask: NSViewMinXMargin|NSViewMaxXMargin];
				[b setButtonType: NSSwitchButton];
				[b setTitle: _(@"Add top and bottom border")];
				[b sizeToFit];
				[top addView: b enablingYResizing: NO];
			}
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

