/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSButton.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSTableView.h>
#include <AppKit/NSTableColumn.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSBox.h>
#include <AppKit/GSVbox.h>
#include <AppKit/GSHbox.h>

#include "ServicesPrefs.h"

#include "Services.h"


@implementation TerminalServicesPrefs

-(void) _update
{
	NSString *name,*new_name;
	NSMutableDictionary *d;
	int i;

	if (current<0)
		return;

	name=[service_list objectAtIndex: current];
	new_name=[tf_name stringValue];
	if (![new_name length])
		new_name=name;
	d=[services objectForKey: name];
	if (!d)
		d=[[NSMutableDictionary alloc] init];

	[d setObject: [tf_key stringValue]
		forKey: Key];
	[d setObject: [tf_cmdline stringValue]
		forKey: Commandline];
	[d setObject: [NSString stringWithFormat: @"%i",[pb_input indexOfSelectedItem]]
		forKey: Input];
	[d setObject: [NSString stringWithFormat: @"%i",[pb_output indexOfSelectedItem]]
		forKey: ReturnData];
	[d setObject: [NSString stringWithFormat: @"%i",[pb_type indexOfSelectedItem]]
		forKey: Type];

	i=0;
	if ([cb_string state]) i|=1;
	if ([cb_filenames state]) i|=2;
	[d setObject: [NSString stringWithFormat: @"%i",i]
		forKey: AcceptTypes];

	if (![name isEqual: new_name])
	{
		[services setObject: d
			forKey: new_name];
		[services removeObjectForKey: name];
		[service_list replaceObjectAtIndex: current
			withObject: new_name];
		[list reloadData];
	}
}


-(void) save
{
	if (!services) return;
	if (!top) return;

	[self _update];

	[[NSUserDefaults standardUserDefaults]
		setObject: services
		forKey: @"TerminalServices"];

	[TerminalServices updateServicesPlist];
}

-(void) revert
{
	NSDictionary *d;

	[list deselectAll: self];
	DESTROY(services);
	DESTROY(service_list);

	services=[[NSMutableDictionary alloc] init];
	d=[[NSUserDefaults standardUserDefaults]
		dictionaryForKey: @"TerminalServices"];
	if (!d)
	{
		NSDictionary *defaults;

		defaults=[NSDictionary dictionaryWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource: @"DefaultTerminalServices"
				ofType: @"plist"]];

		d=defaults;
	}

	{
		NSEnumerator *e=[d keyEnumerator];
		NSString *key;
		while ((key=[e nextObject]))
		{
			[services setObject: [[d objectForKey: key] mutableCopy]
				forKey: key];
		}
	}

	service_list=[[services allKeys] mutableCopy];

	[list reloadData];
	current=-1;
	[self tableViewSelectionDidChange: nil];
}


-(int) numberOfRowsInTableView: (NSTableView *)tv
{
	return [service_list count];
}

-(id) tableView: (NSTableView *)tv  objectValueForTableColumn: (NSTableColumn *)tc  row: (int)row
{
	return [service_list objectAtIndex: row];
}

-(void) tableViewSelectionDidChange: (NSNotification *)n
{
	int r=[list selectedRow];

	if (current>=0)
		[self _update];

	if (r>=0)
	{
		int i;
		NSString *name,*s;
		NSDictionary *d;

		name=[service_list objectAtIndex: r];
		d=[services objectForKey: name];

		[tf_name setEditable: YES];
		[tf_cmdline setEditable: YES];
		[tf_key setEditable: YES];
		[pb_input setEnabled: YES];
		[pb_output setEnabled: YES];
		[pb_type setEnabled: YES];
		[cb_string setEnabled: YES];
		[cb_filenames setEnabled: YES];

		[tf_name setStringValue: name];

		s=[d objectForKey: Key];
		[tf_key setStringValue: s?s:@""];

		s=[d objectForKey: Commandline];
		[tf_cmdline setStringValue: s?s:@""];

		i=[[d objectForKey: Type] intValue];
		if (i<0 || i>0) i=0;
		[pb_type selectItemAtIndex: i];

		i=[[d objectForKey: Input] intValue];
		if (i<0 || i>2) i=0;
		[pb_input selectItemAtIndex: i];

		i=[[d objectForKey: ReturnData] intValue];
		if (i<0 || i>1) i=0;
		[pb_output selectItemAtIndex: i];

		if ([d objectForKey: AcceptTypes])
		{
			i=[[d objectForKey: AcceptTypes] intValue];
			[cb_string setState: !!(i&1)];
			[cb_filenames setState: !!(i&2)];
		}
		else
		{
			[cb_string setState: 1];
			[cb_filenames setState: 0];
		}
	}
	else
	{
		[tf_name setEditable: NO];
		[tf_cmdline setEditable: NO];
		[tf_key setEditable: NO];
		[pb_input setEnabled: NO];
		[pb_output setEnabled: NO];
		[pb_type setEnabled: NO];
		[cb_string setEnabled: NO];
		[cb_filenames setEnabled: NO];

		[tf_name setStringValue: @""];
		[tf_key setStringValue: @""];
		[tf_cmdline setStringValue: @""];
	}

	current=r;
}


-(void) _removeService: (id)sender
{
	NSString *name;
	if (current<0)
		return;
	[list deselectAll: self];

	name=[service_list objectAtIndex: current];
	[services removeObjectForKey: name];
	[service_list removeObjectAtIndex: current];

	[list reloadData];
	current=-1;
	[self tableViewSelectionDidChange: nil];
}

-(void) _addService: (id)sender
{
	NSString *n=_(@"Unnamed service");
	[service_list addObject: n];
	[list reloadData];
	[list selectRow: [service_list count]-1 byExtendingSelection: NO];
}


-(NSString *) name
{
	return _(@"Terminal services");
}

-(void) setupButton: (NSButton *)b
{
	[b setTitle: _(@"Terminal\nservices")];
	[b sizeToFit];
}

-(void) willHide
{
}

-(NSView *) willShow
{
	if (!top)
	{
		GSHbox *hb;
	
		top=[[GSVbox alloc] init];
		[top setDefaultMinYMargin: 4];
		
		{
			GSHbox *hb;
			NSButton *b;

			hb=[[GSHbox alloc] init];
			[hb setDefaultMinXMargin: 4];
			[hb setAutoresizingMask: NSViewMinXMargin];

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Add")];
			[b setTarget: self];
			[b setAction: @selector(_addService:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Remove")];
			[b setTarget: self];
			[b setAction: @selector(_removeService:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			b=[[NSButton alloc] init];
			[b setTitle: _(@"Export...")];
			[b setTarget: self];
			[b setAction: @selector(_exportServices:)];
			[b sizeToFit];
			[hb addView: b  enablingXResizing: NO];
			DESTROY(b);

			[top addView: hb enablingYResizing: NO];
			DESTROY(hb);
		}

		hb=[[GSHbox alloc] init];
		[hb setDefaultMinXMargin: 4];
		[hb setAutoresizingMask: NSViewWidthSizable];

		{
			NSPopUpButton *b;
			GSVbox *vb;

			vb=[[GSVbox alloc] init];
			[vb setDefaultMinYMargin: 4];
			[vb setAutoresizingMask: NSViewMaxXMargin];

			b=pb_output=[[NSPopUpButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setAutoenablesItems: NO];
			[b addItemWithTitle: _(@"Ignore output")];
			[b addItemWithTitle: _(@"Return output")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			b=pb_input=[[NSPopUpButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setAutoenablesItems: NO];
			[b addItemWithTitle: _(@"No input")];
			[b addItemWithTitle: _(@"Input in stdin")];
			[b addItemWithTitle: _(@"Input on command line")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			b=pb_type=[[NSPopUpButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setAutoenablesItems: NO];
			[b addItemWithTitle: _(@"Run in background")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			[hb addView: vb enablingXResizing: YES];
			DESTROY(vb);
		}

		{
			NSButton *b;
			NSBox *box;
			GSVbox *vb;

			box=[[NSBox alloc] init];
			[box setTitle: _(@"Accept types")];
			[box setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin];

			vb=[[GSVbox alloc] init];
			[vb setDefaultMinYMargin: 4];

			b=cb_filenames=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setButtonType: NSSwitchButton];
			[b setTitle: _(@"Filenames")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			b=cb_string=[[NSButton alloc] init];
			[b setAutoresizingMask: NSViewWidthSizable];
			[b setButtonType: NSSwitchButton];
			[b setTitle: _(@"Plain text")];
			[b sizeToFit];
			[vb addView: b enablingYResizing: NO];
			[b release];

			[box setContentView: vb];
			[box sizeToFit];
			DESTROY(vb);
			[hb addView: box enablingXResizing: YES];
			DESTROY(box);
		}

		[top addView: hb enablingYResizing: NO];
		DESTROY(hb);

		{
			GSTable *t;
			NSTextField *f;


			t=[[GSTable alloc] initWithNumberOfRows: 3 numberOfColumns: 2];
			[t setAutoresizingMask: NSViewWidthSizable];
			[t setXResizingEnabled: NO forColumn: 0];
			[t setXResizingEnabled: YES forColumn: 1];

			f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewMinXMargin];
			[f setStringValue: _(@"Name:")];
			[f setEditable: NO];
			[f setDrawsBackground: NO];
			[f setBordered: NO];
			[f setBezeled: NO];
			[f setSelectable: NO];
			[f sizeToFit];
			[f setAutoresizingMask: 0];
			[t putView: f atRow: 2 column: 0 withXMargins: 2 yMargins: 2];
			DESTROY(f);

			tf_name=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable];
			[f sizeToFit];
			[t putView: f atRow: 2 column: 1];
			DESTROY(f);


			f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewMinXMargin];
			[f setStringValue: _(@"Key:")];
			[f setEditable: NO];
			[f setDrawsBackground: NO];
			[f setBordered: NO];
			[f setBezeled: NO];
			[f setSelectable: NO];
			[f sizeToFit];
			[f setAutoresizingMask: 0];
			[t putView: f atRow: 1 column: 0 withXMargins: 2 yMargins: 2];
			DESTROY(f);

			tf_key=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable];
			[f sizeToFit];
			[t putView: f atRow: 1 column: 1];
			DESTROY(f);


			f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewMinXMargin];
			[f setStringValue: _(@"Command line:")];
			[f setEditable: NO];
			[f setDrawsBackground: NO];
			[f setBordered: NO];
			[f setBezeled: NO];
			[f setSelectable: NO];
			[f sizeToFit];
			[f setAutoresizingMask: 0];
			[t putView: f atRow: 0 column: 0 withXMargins: 2 yMargins: 2];
			DESTROY(f);

			tf_cmdline=f=[[NSTextField alloc] init];
			[f setAutoresizingMask: NSViewWidthSizable];
			[f sizeToFit];
			[t putView: f atRow: 0 column: 1];
			DESTROY(f);


			[top addView: t enablingYResizing: NO];
			DESTROY(t);
		}

		{
			NSScrollView *sv;
			NSTableColumn *c_name;

			sv=[[NSScrollView alloc] init];
			[sv setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
			[sv setHasVerticalScroller: YES];
			[sv setHasHorizontalScroller: NO];

			c_name=[[NSTableColumn alloc] initWithIdentifier: @"Name"];
			[c_name setEditable: NO];
			[c_name setResizable: YES];

			list=[[NSTableView alloc] initWithFrame: [[sv contentView] frame]];
			[list setAllowsMultipleSelection: NO];
			[list setAllowsColumnSelection: NO];
			[list setAllowsEmptySelection: NO];
			[list addTableColumn: c_name];
			DESTROY(c_name);
			[list setAutoresizesAllColumnsToFit: YES];
			[list setDataSource: self];
			[list setDelegate: self];
			[list setHeaderView: nil];
			[list setCornerView: nil];

			[sv setDocumentView: list];
			[top addView: sv enablingYResizing: YES];
			[list release];
			DESTROY(sv);
		}

		current=-1;
		[self revert];
	}
	return top;
}

-(void) dealloc
{
	DESTROY(top);
	DESTROY(services);
	DESTROY(service_list);
	[super dealloc];
}

@end

