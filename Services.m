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
#include <Foundation/NSPathUtilities.h>
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
		int i,c=[cmdline length];
		unichar ch;
		NSMutableString *str=[cmdline mutableCopy];

		for (i=0;i<c-1;i++)
		{
			ch=[str characterAtIndex: i];
			if (ch!='%')
				continue;
			ch=[str characterAtIndex: i+1];
			if (ch=='%')
			{
				[str replaceCharactersInRange: NSMakeRange(i,1)
					withString: @""];
				continue;
			}
			if (ch=='s')
				break;
		}

		if (i==c-1)
		{
			[str appendString: @" "];
			[str appendString: [pb stringForType: NSStringPboardType]];
		}
		else
		{
			[str replaceCharactersInRange: NSMakeRange(i,2)
				withString: [pb stringForType: NSStringPboardType]];
		}
		cmdline=[str autorelease];
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


+(void) updateServicesPlist
{
	NSMutableArray *a;
	NSDictionary *d;
	NSEnumerator *e;
	NSString *name;

	d=[[NSUserDefaults standardUserDefaults]
		dictionaryForKey: @"TerminalServices"];

	a=[[NSMutableArray alloc] init];

	e=[d keyEnumerator];
	while ((name=[e nextObject]))
	{
		int i;
		NSString *key;
		NSMutableDictionary *md;
		NSDictionary *info;

		info=[d objectForKey: name];

		md=[[NSMutableDictionary alloc] init];
		[md setObject: @"Terminal" forKey: @"NSPortName"];
		[md setObject: @"terminalService" forKey: @"NSMessage"];
		[md setObject: name forKey: @"NSUserData"];

		[md setObject: [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat: @"%@-%@",@"Terminal",name],
				@"default",nil]
			forKey: @"NSMenuItem"];

		key=[info objectForKey: @"Key"];
		if (key && [key length])
		{
			[md setObject: [NSDictionary dictionaryWithObjectsAndKeys:
					key,@"default",nil]
				forKey: @"NSKeyEquivalent"];
		}

		i=[[info objectForKey: @"Input"] intValue];
		if (i==1 || i==2)
			[md setObject: [NSArray arrayWithObject: NSStringPboardType]
				forKey: @"NSSendTypes"];

		i=[[info objectForKey: @"ReturnData"] intValue];
		if (i==1)
			[md setObject: [NSArray arrayWithObject: NSStringPboardType]
				forKey: @"NSReturnTypes"];

		[a addObject: md];
		DESTROY(md);
	}

	{
		NSString *path;

		path=[NSSearchPathForDirectoriesInDomains(NSUserDirectory,NSUserDomainMask,YES)
			lastObject];
		path=[path stringByAppendingPathComponent: @"Services"];
		path=[path stringByAppendingPathComponent: @"TerminalServices.plist"];

		d=[NSDictionary dictionaryWithObject: a forKey: @"NSServices"];
		[d writeToFile: path atomically: YES];
	}
}

@end

