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

#include "ServicesParameterWindowController.h"


@implementation TerminalServices


-(NSDictionary *) _serviceInfoForName: (NSString *)name
{
	NSDictionary *d;
	d=[TerminalServices terminalServicesDictionary];
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

	int type,input,ret_data,accepttypes;
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

	type=[[info objectForKey: Type] intValue];
	ret_data=[[info objectForKey: ReturnData] intValue];
	input=[[info objectForKey: Input] intValue];
	cmdline=[info objectForKey: Commandline];
	if ([info objectForKey: AcceptTypes])
		accepttypes=[[info objectForKey: AcceptTypes] intValue];
	else
		accepttypes=ACCEPT_STRING;

	NSDebugLLog(@"service",@"cmdline='%@' %i %i %i %i",
		cmdline,type,ret_data,input,accepttypes);

	data=nil;
	if (input && accepttypes&ACCEPT_STRING &&
	    (data=[pb stringForType: NSStringPboardType]))
	{
	}
	else if (input && accepttypes&ACCEPT_FILENAMES &&
	    (data=[pb propertyListForType: NSFilenamesPboardType]))
	{
		NSDebugLLog(@"service",@"got filenames '%@' '%@' %i",data,[data class],[data isProxy]);
	}

	NSDebugLLog(@"service",@"got data '%@'",data);

	if (input==INPUT_STDIN)
	{
		if ([data isKindOfClass: [NSArray class]])
			data=[(NSArray *)data componentsJoinedByString: @"\n"];
	}
	else if (input==INPUT_CMDLINE)
	{
		if (data && [data isKindOfClass: [NSArray class]])
			data=[(NSArray *)data componentsJoinedByString: @" "];
	}

	{
		int i,c=[cmdline length];
		BOOL add_args;
		NSMutableString *str=[cmdline mutableCopy];
		unichar ch;
		int p_pos;

		add_args=YES;
		p_pos=-1;
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
			if (ch=='s' && data && input==2)
			{
				add_args=NO;
				[str replaceCharactersInRange: NSMakeRange(i,2)
					withString: data];
				i+=[data length];
				continue;
			}
			if (ch=='p')
			{
				p_pos=i;
				continue;
			}
		}

		if (input==INPUT_CMDLINE && data && add_args)
		{
			[str appendString: @" "];
			[str appendString: data];
		}
		cmdline=[str autorelease];

		if (p_pos!=-1)
		{
			cmdline=[TerminalServicesParameterWindowController
				getCommandlineFrom: cmdline  selectRange: NSMakeRange(p_pos,2)
				service: name];
			if (!cmdline)
			{
				*error=[_(@"Service aborted by user.") retain];
				return;
			}
		}
	}

	switch (type)
	{
	case TYPE_BACKGROUND:
	{
		NSTask *t=[[[NSTask alloc] init] autorelease];
		NSPipe *sin,*sout;
		NSFileHandle *in,*out;

		[t setLaunchPath: @"/bin/sh"];
		[t setArguments: [NSArray arrayWithObjects: @"-c",cmdline,nil]];

		NSDebugLLog(@"service",@"t=%@",t);

		sin=[[[NSPipe alloc] init] autorelease];
		[t setStandardInput: sin];
		in=[sin fileHandleForWriting];
		sout=[[[NSPipe alloc] init] autorelease];
		[t setStandardOutput: sout];
		out=[sout fileHandleForReading];

		NSDebugLLog(@"service",@"launching");
		[t launch];

		if (data)
		{
			NSDebugLLog(@"service",@"writing data");
			[in writeData: [data dataUsingEncoding: NSUTF8StringEncoding]];
		}
		[in closeFile];

/*		NSDebugLLog(@"service",@"waitUntilExit");
		[t waitUntilExit];*/

		if (ret_data)
		{
			NSString *s;
			NSData *result;
			NSDebugLLog(@"service",@"get result");
			result=[out readDataToEndOfFile];
			NSDebugLLog(@"service",@"got data |%@|",result);
			s=[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
			s=[s autorelease];
			NSDebugLLog(@"service",@"= '%@'",s);

			if (accepttypes==(ACCEPT_STRING|ACCEPT_FILENAMES))
				[pb declareTypes: [NSArray arrayWithObjects:
						NSStringPboardType,NSFilenamesPboardType,nil]
					owner: self];
			else if (accepttypes==ACCEPT_FILENAMES)
				[pb declareTypes: [NSArray arrayWithObjects:
						NSFilenamesPboardType,nil]
					owner: self];
			else if (accepttypes==ACCEPT_STRING)
				[pb declareTypes: [NSArray arrayWithObjects:
						NSStringPboardType,nil]
					owner: self];

			if (accepttypes&ACCEPT_FILENAMES)
			{
				NSMutableArray *ma=[[[NSMutableArray alloc] init] autorelease];
				int i,c=[s length];
				NSRange cur;

				for (i=0;i<c;)
				{
					for (;i<c && [s characterAtIndex: i]<=32;i++) ;
					if (i==c)
						break;
					cur.location=i;
					for (;i<c && [s characterAtIndex: i]>32;i++) ;
					cur.length=i-cur.location;
					[ma addObject: [s substringWithRange: cur]];
				}

				NSDebugLLog(@"service",@"returning filenames: %@",ma);
				[pb setPropertyList: ma forType: NSFilenamesPboardType];
			}

			if (accepttypes&ACCEPT_STRING)
				[pb setString: s  forType: NSStringPboardType];

			NSDebugLLog(@"service",@"return is set");
		}
		else
		{
			NSDebugLLog(@"service",@"ignoring output");
			[out closeFile];
			[t waitUntilExit];
		}

		NSDebugLLog(@"service",@"clean up");
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

	d=[TerminalServices terminalServicesDictionary];

	a=[[NSMutableArray alloc] init];

	e=[d keyEnumerator];
	while ((name=[e nextObject]))
	{
		int i;
		NSString *key;
		NSMutableDictionary *md;
		NSDictionary *info;
		NSArray *types;

		info=[d objectForKey: name];

		md=[[NSMutableDictionary alloc] init];
		[md setObject: @"Terminal" forKey: @"NSPortName"];
		[md setObject: @"terminalService" forKey: @"NSMessage"];
		[md setObject: name forKey: @"NSUserData"];

		[md setObject: [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat: @"%@/%@",@"Terminal",name],
				@"default",nil]
			forKey: @"NSMenuItem"];

		key=[info objectForKey: Key];
		if (key && [key length])
		{
			[md setObject: [NSDictionary dictionaryWithObjectsAndKeys:
					key,@"default",nil]
				forKey: @"NSKeyEquivalent"];
		}

		if ([info objectForKey: AcceptTypes])
			i=[[info objectForKey: AcceptTypes] intValue];
		else
			i=ACCEPT_STRING;
		if (i==(ACCEPT_STRING|ACCEPT_FILENAMES))
			types=[NSArray arrayWithObjects: NSStringPboardType,NSFilenamesPboardType,nil];
		else if (i==ACCEPT_FILENAMES)
			types=[NSArray arrayWithObjects: NSFilenamesPboardType,nil];
		else if (i==ACCEPT_STRING)
			types=[NSArray arrayWithObjects: NSStringPboardType,nil];
		else
			types=nil;

		i=[[info objectForKey: Input] intValue];
		if (types && (i==INPUT_STDIN || i==INPUT_CMDLINE))
			[md setObject: types
				forKey: @"NSSendTypes"];

		i=[[info objectForKey: ReturnData] intValue];
		if (types && i==1)
			[md setObject: types
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


+(NSDictionary *) terminalServicesDictionary
{
	NSDictionary *d;

	d=[[NSUserDefaults standardUserDefaults]
		dictionaryForKey: @"TerminalServices"];
	if (d) return d;

	d=[NSDictionary dictionaryWithContentsOfFile:
		[[NSBundle mainBundle] pathForResource: @"DefaultTerminalServices"
			ofType: @"svcs"]];
	d=[d objectForKey: @"TerminalServices"];
	return d;
}

@end

