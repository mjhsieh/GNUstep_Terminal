/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>
*/

#ifndef Services_h
#define Services_h

#define Key @"Key"
#define ReturnData @"ReturnData"
#define Commandline @"Commandline"
#define Input @"Input"
#define Type @"Type"
#define AcceptTypes @"AcceptTypes"

@interface TerminalServices : NSObject
{
}

+(void) updateServicesPlist;

@end

#endif

