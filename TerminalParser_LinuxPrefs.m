/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSBox.h>
#include <AppKit/GSTable.h>
#include <AppKit/GSVbox.h>
#include "Label.h"

#include "TerminalParser_LinuxPrefs.h"


static NSUserDefaults *ud;


static NSString
	*TerminalParser_LinuxPrefsDidChangeNotification=
		@"TerminalParser_LinuxPrefsDidChangeNotification",
	*InputCharacterSetKey=@"Linux_InputCharacterSet";


static NSString *inputCharacterSet;


typedef struct
{
	NSString *name;
	NSString *display_name;
} character_set_choice_t;

static character_set_choice_t cs_choices[]={
{@"utf-8"             ,__(@"UTF-8")},
{@"iso-8859-1"        ,__(@"West Europe, latin1")},
{@"iso-8859-2"        ,__(@"East Europe, latin2")},
{@"big-5"             ,__(@"Chinese")},
{nil                  ,__(@"Custom, leave unchanged")},
{nil,nil}
};


@implementation TerminalParser_LinuxPrefs

+(void) initialize
{
	if (!ud)
	{
		ud=[NSUserDefaults standardUserDefaults];

		inputCharacterSet=[ud stringForKey: InputCharacterSetKey];
		if (!inputCharacterSet)
			inputCharacterSet=@"iso-8859-1";
	}
}

+(const char *) inputCharacterSet
{
	return [inputCharacterSet cString];
}


-(void) save
{
	int i;

	if (!top) return;

	i=[pb_inputCharacterSet indexOfSelectedItem];
	if (cs_choices[i].name!=nil)
	{
		inputCharacterSet=cs_choices[i].name;
		[ud setObject: inputCharacterSet  forKey: InputCharacterSetKey];

		[[NSNotificationCenter defaultCenter]
			postNotificationName: TerminalParser_LinuxPrefsDidChangeNotification
			object: self];
	}
}

-(void) revert
{
	int i;
	character_set_choice_t *c;
	for (i=0,c=cs_choices;c->name;i++,c++)
	{
		if (c->name &&
		    [c->name caseInsensitiveCompare: inputCharacterSet]==NSOrderedSame)
			break;
	}
	[pb_inputCharacterSet selectItemAtIndex: i];
}


-(NSString *) name
{
	return _(@"'linux' terminal parser");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"'linux'\nparser")];
	[b sizeToFit];
}

-(void) willHide
{
}

-(NSView *) willShow
{
	if (!top)
	{
		GSVbox *top2;

		top2=[[GSVbox alloc] init];

		top=[[GSVbox alloc] init];
		[top setAutoresizingMask: NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin|NSViewMaxYMargin];
		[top setDefaultMinYMargin: 2];

		{
			NSTextField *f;
			NSPopUpButton *pb;
			int i;
			character_set_choice_t *c;

			pb_inputCharacterSet=pb=[[NSPopUpButton alloc] init];
			[pb setAutoresizingMask: NSViewMinXMargin|NSViewMaxXMargin];
			[pb setAutoenablesItems: NO];
			for (i=0,c=cs_choices;c->display_name;i++,c++)
			{
				NSString *name;
				if (c->name)
					name=[NSString stringWithFormat: @"%@ (%@)",
						_(c->display_name),c->name];
				else
					name=_(c->display_name);
				[pb addItemWithTitle: name];
			}
			[pb sizeToFit];
			[top addView: pb enablingYResizing: NO];
			DESTROY(pb);

			f=[NSTextField newLabel: _(@"Input character set:")];
			[top addView: f enablingYResizing: NO];
			DESTROY(f);
		}

		[top2 addView: top enablingYResizing: YES];
		DESTROY(top);
		top=top2;

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

