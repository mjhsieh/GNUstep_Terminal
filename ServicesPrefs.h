/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef ServicesPrefs_h
#define ServicesPrefs_h

#include "PrefBox.h"

@class NSMutableDictionary,NSMutableArray;
@class GSVbox,NSTableView,NSPopUpButton,NSTextField;

@interface TerminalServicesPrefs : NSObject <PrefBox>
{
	NSMutableDictionary *services;
	NSMutableArray *service_list;
	int current;

	GSVbox *top;
	NSTableView *list;
	NSPopUpButton *pb_input,*pb_output,*pb_type;
	NSTextField *tf_name,*tf_cmdline,*tf_key;

	NSButton *cb_string,*cb_filenames;
}

@end

#endif

