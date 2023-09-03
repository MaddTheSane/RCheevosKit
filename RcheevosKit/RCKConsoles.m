//
//  RCKConsoles.m
//  RcheevosKit
//
//  Created by C.W. Betts on 8/29/23.
//

#import "RCKConsoles.h"
#include "rc_consoles.h"


NSString * RCKConsoleGetName(RCKConsoleIdentifier ident)
{
	const char* theName = rc_console_name(ident);
	return @(theName);
}

@implementation RCKMemoryRegion
{
	const rc_memory_regions_t *val;
	NSInteger index;
	NSString *memoryDescription;
}

-(instancetype)initWithMemoryRegions:(const rc_memory_regions_t*)regions index:(NSInteger)idx
{
	if (self = [super init]) {
		val = regions;
		index = idx;
	}
	return self;
}

- (unsigned int)startAddress
{
	return val->region[index].start_address;
}

- (unsigned int)endAddress
{
	return val->region[index].end_address;
}

- (unsigned int)realAddress
{
	return val->region[index].real_address;
}

- (RCKMemoryType)memoryType
{
	return val->region[index].type;
}

- (NSString *)memoryDescription
{
	if (!memoryDescription) {
		memoryDescription = @(val->region[index].description);
	}
	return memoryDescription;
}

+ (NSArray<RCKMemoryRegion *> *)regionsBasedOnConsole:(RCKConsoleIdentifier)ident
{
	const rc_memory_regions_t* d = rc_console_memory_regions(ident);
	if (!d) {
		return nil;
	}
	NSMutableArray *toRet = [NSMutableArray array];
	for (int i = 0; i < d->num_regions; i++) {
		RCKMemoryRegion *memRegn = [[RCKMemoryRegion alloc] initWithMemoryRegions:d index:i];
		[toRet addObject:memRegn];
	}
	return [toRet copy];
}

@end

