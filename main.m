/*
copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; version 2 of the License.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <Foundation/NSBundle.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSPanel.h>
#include <AppKit/NSView.h>

/* For the quit panel: */
#include <AppKit/NSButton.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSImageView.h>
#include <AppKit/NSScreen.h>
#include <GNUstepGUI/GSVbox.h>
#include <GNUstepGUI/GSHbox.h>
#include "Label.h"


#include "TerminalWindow.h"
#include "TerminalView.h"
#include "PreferencesWindowController.h"


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
	PreferencesWindowController *pwc;

	NSPanel *quitPanel;
	BOOL quitPanelOpen;
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
	[[NSNotificationCenter defaultCenter]
		removeObserver: self];

	DESTROY(pwc);
	[super dealloc];
}


@class TerminalViewDisplayPrefs;
@class TerminalViewShellPrefs;
@class TerminalViewKeyboardPrefs;
@class TerminalServicesPrefs;
@class TerminalWindowPrefs;
@class TerminalParser_LinuxPrefs;

-(void) openPreferences: (id)sender
{
	if (!pwc)
	{
		NSObject<PrefBox> *pb;
		pwc=[[PreferencesWindowController alloc] init];

		pb=[[TerminalViewDisplayPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);

		pb=[[TerminalViewShellPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);

		pb=[[TerminalViewKeyboardPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);

		pb=[[TerminalWindowPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);

		pb=[[TerminalServicesPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);

		pb=[[TerminalParser_LinuxPrefs alloc] init];
		[pwc addPrefBox: pb];
		DESTROY(pb);
	}
	[pwc showWindow: self];
}


-(void) applicationWillTerminate: (NSNotification *)n
{
}


-(void) applicationWillFinishLaunching: (NSNotification *)n
{
	NSMenu *menu,*m/*,*m2*/;

	[TerminalView registerPasteboardTypes];

	menu=[[NSMenu alloc] init];

	/* 'Info' menu */
	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"Info...")
		action: @selector(orderFrontStandardInfoPanel:)];
	[m addItemWithTitle: _(@"Preferences...")
		action: @selector(openPreferences:)];
	[m addItemWithTitle: _(@"Benchmark")
		action: @selector(benchmark:)];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Info")]];
	[m release];

	/* 'Terminal' menu */
	/* TODO: think hard about this. originally, the Terminal menu was supposed
	to have several entries. */
/*	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"New window")
		action: @selector(openWindow:)
		keyEquivalent: @"n"];
	[menu setSubmenu: m forItem: [menu addItemWithTitle: _(@"Terminal")]];
	[m release];*/
	[menu addItemWithTitle: _(@"New terminal")
		action: @selector(openWindow:)
		keyEquivalent: @"n"];

	/* 'Edit' menu */
	m=[[NSMenu alloc] init];
	[m addItemWithTitle: _(@"Cut")
		action: @selector(cut:)
		keyEquivalent: @"x"];
	[m addItemWithTitle: _(@"Copy")
		action: @selector(copy:)
		keyEquivalent: @"c"];
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
	[m addItemWithTitle: _(@"Miniaturize all")
		action: @selector(miniaturizeAll:)
		keyEquivalent: @"m"];
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

	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(noMoreActiveWindows:)
		name: TerminalWindowNoMoreActiveWindowsNotification
		object: nil];
}

-(void) openWindow: (id)sender
{
	TerminalWindowController *twc;
	twc=[TerminalWindowController newTerminalWindow];
	[[twc terminalView] runShell];
}


@class TerminalServices;

-(void) applicationDidFinishLaunching: (NSNotification *)n
{
	NSArray *args=[[NSProcessInfo processInfo] arguments];

	[NSApp setServicesProvider: [[TerminalServices alloc] init]];

	if ([args count]>1)
	{
		TerminalWindowController *twc;
		NSString *cmdline;

		args=[args subarrayWithRange: NSMakeRange(1,[args count]-1)];
		cmdline=[args componentsJoinedByString: @" "];

		twc=[TerminalWindowController newTerminalWindow];
		[[twc terminalView] runProgram: @"/bin/sh"
			withArguments: [NSArray arrayWithObjects: @"-c",cmdline,nil]
			initialInput: nil];
	}
	else
		[self openWindow: self];
}


-(NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)sender
{
	if (![TerminalWindowController numberOfActiveWindows])
		return NSTerminateNow;

	if (!quitPanel)
	{
		NSButton *b_quit,*b_dont;

		{
			GSVbox *vb=[[GSVbox alloc] init];

			[vb setBorder: 10.0];

			{
				NSButton *b;
				GSHbox *hb;

				hb=[[GSHbox alloc] init];
				[hb setAutoresizingMask: NSViewMinXMargin];

				b=b_quit=[[NSButton alloc] init];
				[b setTitle: _(@"Quit anyway")];
				[b setTarget: self];
				[b setAction: @selector(quitAnyway:)];
				[b sizeToFit];
				[hb addView: b  enablingXResizing: NO];
				DESTROY(b);

				b=b_dont=[[NSButton alloc] init];
				[b setTitle: _(@"Don't quit")];
				[b setImagePosition: NSImageRight];
				[b setImage: [NSImage imageNamed: @"common_ret"]];
				[b setTarget: self];
				[b setAction: @selector(dontQuit:)];
				[b sizeToFit];
				[hb addView: b  enablingXResizing: NO withMinXMargin: 8.0];
				DESTROY(b);

				[vb addView: hb enablingYResizing: NO];
				DESTROY(hb);
			}

			{
				NSTextField *text;

				text=[NSTextField newLabel:
					_(@"There are active windows. Quitting will close them.")];
				[text setAutoresizingMask: NSViewWidthSizable|NSViewMinYMargin];
				[text sizeToFit];

				[vb addView: text enablingYResizing: YES withMinYMargin: 8.0];
				DESTROY(text);
			}

			[vb addSeparatorWithMinYMargin: 8.0];

			{
				NSImageView *iv;
				NSTextField *title;
				GSHbox *hb;

				hb=[[GSHbox alloc] init];

				iv=[[NSImageView alloc] init];
				[iv setImage: [NSApp applicationIconImage]];
				[iv setEditable: NO];
				[iv sizeToFit];
				[hb addView: iv enablingXResizing: NO];
				DESTROY(iv);

				title=[NSTextField newLabel: _(@"Quit?")];
				[title setAutoresizingMask: NSViewMinYMargin|NSViewMaxYMargin];
				[title setFont: [NSFont systemFontOfSize: 18.0]];
				[title sizeToFit];
				[hb addView: title enablingXResizing: NO withMinXMargin: 8.0];
				DESTROY(title);

				[vb addView: hb enablingYResizing: NO withMinYMargin: 8.0];
				DESTROY(hb);
			}

			[vb sizeToFit];

			quitPanel=[[NSPanel alloc] initWithContentRect: [vb frame]
				styleMask: NSTitledWindowMask
				backing: NSBackingStoreRetained
				defer: YES];
			[quitPanel setContentView: vb];
			DESTROY(vb);
		}

		[quitPanel setTitle: _(@"Quit?")];
		[quitPanel setOneShot: YES];
		[quitPanel setHidesOnDeactivate: NO];
		[quitPanel setExcludedFromWindowsMenu: NO];

		[quitPanel setInitialFirstResponder: b_dont];
		[b_dont setNextKeyView: b_quit];
		[b_quit setNextKeyView: b_dont];
	}

	{
		/* TODO: always using +mainScreen is probably incorrect */
		NSRect r=[[NSScreen mainScreen] frame];
		NSPoint o;

		o.x=r.origin.x+r.size.width/2.0-[quitPanel frame].size.width/2.0;
		o.y=r.origin.y+r.size.height/2.0-[quitPanel frame].size.height/2.0;
		[quitPanel setFrameOrigin: o];
	}

	[quitPanel makeKeyAndOrderFront: self];
	quitPanelOpen=YES;

	return NSTerminateLater;
}

-(void) quitAnyway: (id)sender
{
	[NSApp replyToApplicationShouldTerminate: YES];
}

-(void) dontQuit: (id)sender
{
	[NSApp replyToApplicationShouldTerminate: NO];
	quitPanelOpen=NO;
	[quitPanel orderOut: self];
}

-(void) noMoreActiveWindows: (NSNotification *)n
{
	if (quitPanelOpen)
		[NSApp replyToApplicationShouldTerminate: YES];
}


-(BOOL) application: (NSApplication *)sender
	openFile: (NSString *)filename
{
	TerminalWindowController *twc;

	NSDebugLLog(@"Application",@"openFile: '%@'",filename);

	/* TODO: shouldn't ignore other apps */
	[NSApp activateIgnoringOtherApps: YES];

	twc=[TerminalWindowController newTerminalWindow];
	[[twc terminalView] runProgram: filename
		withArguments: nil
		initialInput: nil];

	return YES;
}



-(BOOL) terminalRunProgram: (NSString *)path
	withArguments: (NSArray *)args
	inDirectory: (NSString *)directory
	properties: (NSDictionary *)properties
{
	TerminalWindowController *twc;

	NSDebugLLog(@"Application",
		@"terminalRunProgram: %@ withArguments: %@ inDirectory: %@ properties: %@",
		path,args,directory,properties);

	/* TODO: shouldn't ignore other apps */
	[NSApp activateIgnoringOtherApps: YES];

	{
		id o;
		o=[properties objectForKey: @"CloseOnExit"];
		if (o && [o respondsToSelector: @selector(boolValue)] &&
		    ![o boolValue])
		{
			twc=[TerminalWindowController idleTerminalWindow];
		}
		else
		{
			twc=[TerminalWindowController newTerminalWindow];
		}
	}

	[[twc terminalView] runProgram: path
		withArguments: args
		inDirectory: directory
		initialInput: nil
		arg0: nil];

	return YES;
}

-(BOOL) terminalRunCommand: (NSString *)cmdline
	inDirectory: (NSString *)directory
	properties: (NSDictionary *)properties
{
	NSDebugLLog(@"Application",
		@"terminalRunCommand: %@ inDirectory: %@ properties: %@",
		cmdline,directory,properties);

	return [self terminalRunProgram: @"/bin/sh"
		withArguments: [NSArray arrayWithObjects: @"-c",cmdline,nil]
		inDirectory: directory
		properties: properties];
}


@end


/* TODO */
@interface TerminalViewKeyboardPrefs
-(BOOL) commandAsMeta;
@end

#include <AppKit/NSWindow.h>
#include <AppKit/NSEvent.h>

@interface NSWindow (avoid_warnings)
-(void) sendEvent: (NSEvent *)e;
@end


@interface TerminalApplication : NSApplication
@end

@implementation TerminalApplication
-(void) sendEvent: (NSEvent *)e
{
	if ([e type]==NSKeyDown && [e modifierFlags]&NSCommandKeyMask &&
	    [TerminalViewKeyboardPrefs commandAsMeta])
	{
		NSDebugLLog(@"key",@"intercepting key equivalent");
		[[e window] sendEvent: e];
		return;
	}
	[super sendEvent: e];
}
@end


int main(int argc, char **argv)
{
	CREATE_AUTORELEASE_POOL(arp);

/*	[NSObject enableDoubleReleaseCheck: YES];*/

	[TerminalApplication sharedApplication];

	[NSApp setDelegate: [[Terminal alloc] init]];
	[NSApp run];

	DESTROY(arp);
	return 0;
}

