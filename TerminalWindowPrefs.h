/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef TerminalWindowPrefs_h
#define TerminalWindowPrefs_h

#include "PrefBox.h"


@class GSVbox,NSTextField,NSButton,NSPopUpButton;

@interface TerminalWindowPrefs : NSObject <PrefBox>
{
	GSVbox *top;

	NSPopUpButton *pb_close;
	NSTextField *tf_width,*tf_height;
	NSButton *b_addYBorders;
}

+(int) windowCloseBehavior;

+(int) defaultWindowWidth;
+(int) defaultWindowHeight;

+(BOOL) addYBorders;

@end


#endif
