/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#include <Foundation/NSString.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSData.h>
#include <AppKit/NSPasteboard.h>

#include "Services.h"


@implementation TerminalServices


-(NSDictionary *) _serviceInfoForName: (NSString *)name
{
	NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
	NSDictionary *d;
	d=[ud dictionaryForKey: @"TerminalServices"];
	d=[d objectForKey: name];
	if (!d || ![d isKindOfClass: [NSDictionary class]])
		return nil;
	return d;
}


-(void) terminalService: (NSPasteboard *)pb
	userData: (NSString *)name
	error: (NSString **)error
{
	NSDictionary *info=[self _serviceInfoForName: name];

	int type,input,ret_data;
	NSString *cmdline;
	NSString *data;

	NSDebugLLog(@"service",@"run service %@\n",name);
	if (!info)
	{
		NSString *s=
			_(@"There is no terminal service called '%@'.\n"
			  @"Your services list is probably out-of-date.\n"
			  @"Run 'make_services' to update it.");

		*error=[[NSString stringWithFormat: s, name] retain];
		return;
	}

	type=[[info objectForKey: @"Type"] intValue];
	ret_data=[[info objectForKey: @"ReturnData"] intValue];
	input=[[info objectForKey: @"Input"] intValue];
	cmdline=[info objectForKey: @"Commandline"];

	NSDebugLLog(@"service",@"cmdline='%@' %i %i %i",cmdline,type,ret_data,input);

	data=nil;
	if (input==1)
	{
		data=[pb stringForType: NSStringPboardType];
	}
	else if (input==2)
	{
		cmdline=[[cmdline stringByAppendingString: @" "]
			stringByAppendingString: [pb stringForType: NSStringPboardType]];
	}

	switch (type)
	{
	case 0:
	{
		NSTask *t=[[NSTask alloc] init];
		NSPipe *stdin,*stdout;
		NSFileHandle *in,*out;

		[t setLaunchPath: @"/bin/sh"];
		[t setArguments: [NSArray arrayWithObjects: @"-c",cmdline,nil]];

		NSDebugLLog(@"service",@"t=%@",t);

		stdin=[[NSPipe alloc] init];
		[t setStandardInput: stdin];
		in=[stdin fileHandleForWriting];
		stdout=[[NSPipe alloc] init];
		[t setStandardOutput: stdout];
		out=[stdout fileHandleForReading];

		NSDebugLLog(@"service",@"launching");
		[t launch];

		if (data)
		{
			NSDebugLLog(@"service",@"writing data");
			[in writeData: [data dataUsingEncoding: NSUTF8StringEncoding]];
		}
		[in closeFile];

		NSDebugLLog(@"service",@"waitUntilExit");
		[t waitUntilExit];

		if (ret_data)
		{
			NSString *s;
			NSData *result;
			NSDebugLLog(@"service",@"get result");
			result=[out readDataToEndOfFile];
			NSDebugLLog(@"service",@"got data |%@|",result);
			s=[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
			NSDebugLLog(@"service",@"= '%@'",s);

			[pb declareTypes: [NSArray arrayWithObject: NSStringPboardType]
				owner: self];
			[pb setString: s  forType: NSStringPboardType];
			DESTROY(s);
		}

		NSDebugLLog(@"service",@"clean up");
		DESTROY(stdin);
		DESTROY(stdout);
		DESTROY(t);
	}
		break;

	}
	NSDebugLLog(@"service",@"return");
}

@end

