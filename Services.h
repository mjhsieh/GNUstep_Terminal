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

#define INPUT_NO      0
#define INPUT_STDIN   1
#define INPUT_CMDLINE 2

#define ACCEPT_STRING    1
#define ACCEPT_FILENAMES 2

#define TYPE_BACKGROUND 0

@interface TerminalServices : NSObject
{
}

+(void) updateServicesPlist;

+(NSDictionary *) terminalServicesDictionary;

@end

#endif

