#import "CSSegmentedHandle.h"

NSString *CSNoSegmentsException=@"CSNoSegmentsException";
NSString *CSSizeOfSegmentUnknownException=@"CSSizeOfSegmentUnknownException";

@implementation CSSegmentedHandle

-(id)initWithName:(NSString *)descname
{
	if(self=[super initWithName:name])
	{
		count=0;
		currindex=NSNotFound;
		currhandle=nil;
		segmentends=NULL;
	}
	return self;
}

-(id)initAsCopyOf:(CSSegmentedHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		count=other->count;
		currindex=other->currindex;
		currhandle=[other->currhandle copy];

		size_t size=count*sizeof(segmentends[0]);
		segmentends=malloc(size);
		memcpy(segmentends,other->segmentends,size);
	}
	return self;
}

-(void)dealloc
{
	[currhandle release];
	free(segmentends);
	[super dealloc];
}

-(CSHandle *)currentHandle
{
	[self _open];
	return currhandle;
}

-(off_t)fileSize
{
	[self _open];
	return segmentends[count-1];
}

-(off_t)offsetInFile
{
	[self _open];
	off_t start=0;
	if(currindex>0) start=segmentends[currindex-1];
	return start+[currhandle offsetInFile];
}

-(BOOL)atEndOfFile
{
	[self _open];
	return currindex==count-1 && [currhandle atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	[self _open];
	for(NSInteger i=0;i<count;i++)
	{
		if(offs<segmentends[i])
		{
			[self _setCurrentIndex:i];

			off_t start=0;
			if(currindex>0) start=segmentends[currindex-1];
			[currhandle seekToFileOffset:offs-start];

			return;
		}
	}
	[self _raiseEOF];
}

-(void)seekToEndOfFile
{
	[self _open];
	[self _setCurrentIndex:count-1];
	[currhandle seekToEndOfFile];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	[self _open];

	int total=0;
	for(;;)
	{
		off_t actual=[currhandle readAtMost:num-total toBuffer:((char *)buffer)+total];
		total+=actual;
		if(total==num || currindex==count-1) return total;

		[self _setCurrentIndex:currindex+1];
		[currhandle seekToFileOffset:0];
	}
}

-(NSString *)name
{
	return [NSString stringWithFormat:@"%@, and %ld more combined",[[self currentHandle] name],(long)[self numberOfSegments]-1];
}




-(NSInteger)numberOfSegments { return 0; }

-(off_t)segmentSizeAtIndex:(NSInteger)index { return 0; }

-(CSHandle *)handleAtIndex:(NSInteger)index { return nil; }




-(void)_open
{
	if(currindex!=NSNotFound) return;

	count=[self numberOfSegments];
	if(count<1) [self _raiseNoSegments];

	segmentends=malloc(count*sizeof(segmentends[0]));

	off_t total=0;
	for(NSInteger i=0;i<count-1;i++)
	{
		off_t size=[self segmentSizeAtIndex:i];
		if(size==CSHandleMaxLength) [self _raiseSizeUnknownForSegment:i];
		total+=size;
		segmentends[i]=total;
	}

	off_t size=[self segmentSizeAtIndex:count-1];
	if(size==CSHandleMaxLength) segmentends[count-1]=CSHandleMaxLength;
	else segmentends[count-1]=total+size;

	[self _setCurrentIndex:0];
}

-(void)_setCurrentIndex:(NSInteger)newindex
{
	if(currindex!=newindex)
	{
		currindex=newindex;
		[currhandle release];
		currhandle=nil;
		currhandle=[[self handleAtIndex:newindex] retain];
	}
}

-(void)_raiseNoSegments
{
	[NSException raise:CSNoSegmentsException format:@"No segments for CSSegmentedHandle."];
}

-(void)_raiseSizeUnknownForSegment:(NSInteger)i
{
	[NSException raise:CSSizeOfSegmentUnknownException
	format:@"Size of CSSegmentedHandle segment %ld (%@) unknown.",i,[self handleAtIndex:i]];
}

@end
