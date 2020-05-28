//
//  SSProgressPanel.m
//  Stick Software subsystem
//
//  Created by Ben Haller on Thu Jul 31 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import "SSProgressPanel.h"
#import "CocoaExtra.h"


@interface SSProgressPanel (Private)

- (void)makeProgressWindow;

@end

@implementation SSProgressPanel

+ (SSProgressPanel *)progressPanelModalForWindow:(NSWindow *)window title:(NSString *)title subtitle:(NSString *)subtitle determinate:(BOOL)determinate
{
	return [[[SSProgressPanel alloc] initModalForWindow:window title:title subtitle:subtitle determinate:determinate] autorelease];
}

- (id)initModalForWindow:(NSWindow *)window title:(NSString *)title subtitle:(NSString *)subtitle determinate:(BOOL)determinate
{
	if (self = [super init])
	{
		modalWindow = window;
		titleString = [title retain];
		subtitleString = [subtitle retain];
		isDeterminate = determinate;
		
		minValue = 0.0;
		maxValue = 1.0;
		progress = 0.0;
		thresholdTime = 0.20;
	}
	
	return self;
}

- (BOOL)isDeterminate
{
	return isDeterminate;
}

- (void)setDeterminate:(BOOL)flag
{
	if (flag != isDeterminate)
	{
		isDeterminate = flag;
		
		[progressIndicator setIndeterminate:!isDeterminate];
		
		if (isDeterminate)
		{
			[progressIndicator setMinValue:minValue];
			[progressIndicator setMaxValue:maxValue];
			[progressIndicator setDoubleValue:progress];
		}
	}
}

- (void)dealloc
{
	if (progressWindow)
		[self finish];
	
	[titleString release];
	titleString = nil;
	
	[subtitleString release];
	subtitleString = nil;
	
	[elapsedTimeBase release];
	elapsedTimeBase = nil;
	
	[lastUpdateTime release];
	lastUpdateTime = nil;
	
	[super dealloc];
}

- (void)start
{
	if (!elapsedTimeBase)
	{
		// Remember the time we started at, so we can figure how long we've got without showing our panel
		elapsedTimeBase = [[NSDate alloc] init];
		
		// Uncomment this to make our panel be visible as soon as a task is started,
		// bypassing the time to completion calculations.
		//[self forceVisible];
	}
}

- (void)startNewTask
{
	[elapsedTimeBase release];
	elapsedTimeBase = nil;
	
	[lastUpdateTime release];
	lastUpdateTime = nil;
	
	if (isDeterminate)
		[self setProgress:0.0];
	
	[self start];
}

- (void)startNewTaskAndSetMaxValue:(double)value
{
	[self setMaxValue:value];
	[self startNewTask];
}

- (void)finish
{
	if (progressWindow)
	{
		// Stop our modal loop or sheet
		if (modalWindow)
			[NSApp endSheet:progressWindow];
		else
			[NSApp endModalSession:modalSession];
		
		// Close our window, which releases itself
		[progressWindow close];
		progressWindow = nil;
		
		// Nil out the views inside our window, which have now been released
		progressIndicator = nil;
		progressTitle = nil;
		progressSubtitle = nil;
	}
	
	// Forget our elapsed time
	[elapsedTimeBase release];
	elapsedTimeBase = nil;
}

- (void)finishAndRelease
{
	[self finish];
	[self release];
}

- (double)minValue
{
	if (!isDeterminate)
		NSLog(@"minValue called on an indeterminate SSProgressPanel");
	
	return minValue;
}

- (void)setMinValue:(double)value
{
	if (isDeterminate)
	{
		minValue = value;
		
		if (progressIndicator)
			[progressIndicator setMinValue:value];

		if (progress < minValue)
			[self setProgress:minValue];
	}
	else
		NSLog(@"setMinValue: called on an indeterminate SSProgressPanel");
}

- (double)maxValue
{
	if (!isDeterminate)
		NSLog(@"maxValue called on an indeterminate SSProgressPanel");
	
	return maxValue;
}

- (void)setMaxValue:(double)value
{
	if (isDeterminate)
	{
		maxValue = value;
		
		if (progressIndicator)
			[progressIndicator setMaxValue:value];
		
		if (progress > maxValue)
			[self setProgress:maxValue];
	}
	else
		NSLog(@"setMaxValue: called on an indeterminate SSProgressPanel");
}

- (double)progress
{
	if (!isDeterminate)
		NSLog(@"progress called on an indeterminate SSProgressPanel");

	return progress;
}

- (void)_setProgress:(double)value
{
	if (isDeterminate)
	{
		if (value < minValue) value = minValue;
		if (value > maxValue) value = maxValue;
		progress = value;
		
		if (!elapsedTimeBase)
			[self start];
	}
	else
		NSLog(@"setProgress: called on an indeterminate SSProgressPanel");
}

- (void)makeVisibleIfNecessary
{
	// If we haven't yet shown our panel, decide whether we should
	if (!progressWindow)
	{
		double elapsedTime = [self elapsedTime];
		
		// We never bring up our panel before a certain threshold, since our time-to-completion estimates
		// may be very inaccurate at the start, and we don't want to flash for very brief tasks.
		if (elapsedTime > thresholdTime)
		{
			if (isDeterminate)
			{
				double estimatedTimeToCompletion = [self estimatedTimeToCompletion];
				
				if (estimatedTimeToCompletion > 1.0)
				{
					//NSLog(@"progress == %f, max == %f, elapsedTime == %f, estimatedTimeToCompletion == %f; forcing panel visible", progress, maxValue, elapsedTime, estimatedTimeToCompletion);
					[self forceVisible];
				}
			}
			else
			{
				[self forceVisible];
			}
		}
	}
}

- (void)setProgress:(double)value
{
	if (isDeterminate)
	{
		if (value < minValue) value = minValue;
		if (value > maxValue) value = maxValue;
		progress = value;
		
		if (!elapsedTimeBase)
			[self start];
		
		[progressIndicator setDoubleValue:progress];
	}
	else
		NSLog(@"setProgress: called on an indeterminate SSProgressPanel");
	
	[self makeVisibleIfNecessary];
}

- (void)_giveTime
{
	if (!elapsedTimeBase)
		NSLog(@"-_giveTime called without having started a task");
	
	// We only give time if our panel has been put up.  Otherwise, the enabling of menu items and such will be wrong.
	if (progressWindow)
	{
		if (modalWindow)
		{
			// If we're running as a sheet, we give time to the main event loop in the default mode
			NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate date] inMode:NSDefaultRunLoopMode dequeue:YES];
			
			if (event)
				[NSApp sendEvent:event];
		}
		else
		{
			// If we're running as a modal panel, we give time to the modal run loop
			[NSApp runModalSession:modalSession];
		}
	}
	else if (giveTimeToRunLoop)
	{
		// We spin the run loop, which allows URL fetches to proceed even though we're not processing events right now
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
	}
}

- (BOOL)giveTime
{
	BOOL refreshTimeElapsed = NO;
	
	// -setProgress: does this for determinate tasks; we do it for indeterminate ones
	if (!elapsedTimeBase)
		[self start];

	if (!lastUpdateTime)
	{
		lastUpdateTime = [[NSDate alloc] init];
		refreshTimeElapsed = YES;
	}
	else
	{
		if (-[lastUpdateTime timeIntervalSinceNow] > 0.05)
		{
			[lastUpdateTime release];
			lastUpdateTime = [[NSDate alloc] init];
			refreshTimeElapsed = YES;
		}
	}
	
	if (refreshTimeElapsed)
	{
		// -setProgress: does this for determinate tasks; we do it for indeterminate ones
		[self makeVisibleIfNecessary];
		
		[self _giveTime];
	}
	
	return !progressStopped;
}

- (BOOL)giveTimeAndSetProgress:(double)value
{
	BOOL refreshTimeElapsed = NO;
	
	if (!lastUpdateTime)
	{
		lastUpdateTime = [[NSDate alloc] init];
		refreshTimeElapsed = YES;
	}
	else
	{
		if (-[lastUpdateTime timeIntervalSinceNow] > 0.05)
		{
			[lastUpdateTime release];
			lastUpdateTime = [[NSDate alloc] init];
			refreshTimeElapsed = YES;
		}
	}
	
	if (isDeterminate)
	{
		if (refreshTimeElapsed)
			[self setProgress:value];
		else
			[self _setProgress:value];
	}
	else
		NSLog(@"giveTimeAndSetProgress: called on an indeterminate SSProgressPanel");
	
	if (refreshTimeElapsed)
		[self _giveTime];
	
	return !progressStopped;
}

- (BOOL)giveTimeToRunLoop
{
	return giveTimeToRunLoop;
}

- (void)setGiveTimeToRunLoop:(BOOL)flag
{
	giveTimeToRunLoop = flag;
}

- (NSString *)title
{
	return titleString;
}

- (void)setTitle:(NSString *)title
{
	if (![titleString isEqualToString:title])
	{
		[title retain];
		[titleString release];
		titleString = title;
		
		if (progressTitle)
			[progressTitle setStringValue:(titleString ? titleString : @"")];
	}
}

- (NSString *)subtitle
{
	return subtitleString;
}

- (void)setSubtitle:(NSString *)subtitle
{
	if (![subtitleString isEqualToString:subtitle])
	{
		[subtitle retain];
		[subtitleString release];
		subtitleString = subtitle;
		
		if (progressSubtitle)
			[progressSubtitle setStringValue:(subtitleString ? subtitleString : @"")];
	}
}

- (BOOL)isVisible
{
	return (progressWindow ? YES : NO);
}

- (void)forceVisible
{
	if (!progressWindow)
	{
		[self makeProgressWindow];
		
		if (!isDeterminate)
			[progressIndicator startAnimation:nil];
		
		if (modalWindow)
			[modalWindow beginSheet:progressWindow completionHandler:NULL];
		else
			modalSession = [NSApp beginModalSessionForWindow:progressWindow];
	}
}

- (BOOL)isStoppedByUser
{
	return progressStopped;
}

- (IBAction)performStop:(id)sender
{
#pragma unused (sender)
	progressStopped = YES;
}

- (NSTimeInterval)elapsedTime
{
	NSTimeInterval elapsedTime = 0.0;
	
	if (elapsedTimeBase)
		elapsedTime = -[elapsedTimeBase timeIntervalSinceNow];
	else
		NSLog(@"elapsedTime called on an SSProgressPanel that has not been started");
	
	return elapsedTime;
}

- (NSTimeInterval)estimatedTotalTime
{
	NSTimeInterval estimatedTotalTime = 0.0;
	
	if (isDeterminate)
	{
		if (elapsedTimeBase)
		{
			NSTimeInterval elapsedTime = [self elapsedTime];
			double fractionCompleted = ((progress - minValue) / (maxValue - minValue));
			
			estimatedTotalTime = elapsedTime / fractionCompleted;
		}
		else
			NSLog(@"estimatedTotalTime called on an unstarted SSProgressPanel");
	}
	else
		NSLog(@"estimatedTotalTime called on an indeterminate SSProgressPanel");
	
	return estimatedTotalTime;
}

- (NSTimeInterval)estimatedTimeToCompletion
{
	NSTimeInterval estimatedTimeToCompletion = 0.0;
	
	if (isDeterminate)
	{
		if (elapsedTimeBase)
		{
			NSTimeInterval elapsedTime = [self elapsedTime];
			double fractionCompleted = ((progress - minValue) / (maxValue - minValue));
			
			estimatedTimeToCompletion = (elapsedTime / fractionCompleted) - elapsedTime;
		}
		else
			NSLog(@"estimatedTimeToCompletion called on an unstarted SSProgressPanel");
	}
	else
		NSLog(@"estimatedTimeToCompletion called on an indeterminate SSProgressPanel");
	
	return estimatedTimeToCompletion;
}

- (double)thresholdTime
{
	return thresholdTime;
}

- (void)setThresholdTime:(double)newThresholdTime
{
	thresholdTime = newThresholdTime;
}

@end

@implementation SSProgressPanel (Private)

- (void)makeProgressWindow
{
	NSSize panelSize = NSMakeSize(331, 128);
	NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(24, panelSize.height - (16 + 64), 64, 64)];
	NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(panelSize.width - 110, 11, 90, 34)];
	NSString *buttonString = SSLocalizedStringFromTable(@"Stop button", @"Base", @"Stop button");
	NSView *contentView;
	NSFont *lucida13bold = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
	NSFont *lucida13 = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	NSFont *lucida11 = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	
	progressWindow = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, panelSize.width, panelSize.height) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[progressWindow setReleasedWhenClosed:YES];
	[progressWindow setDelegate:self];
	[progressWindow setHidesOnDeactivate:NO];
	
	progressTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(104, panelSize.height - (15 + 17), panelSize.width - 136, 17)];
	progressSubtitle = [[NSTextField alloc] initWithFrame:NSMakeRect(104, panelSize.height - (41 + 28), panelSize.width - 136, 28)];

	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(105, 18, panelSize.width - 227, 20)];
	
	contentView = [progressWindow contentView];
	
	[iconView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	[contentView addSubview:iconView];
	[iconView release];
	
	[progressTitle setStringValue:(titleString ? titleString : @"")];
	[progressTitle setFont:lucida13bold];
	[progressTitle setEditable:NO];
	[progressTitle setBordered:NO];
	[progressTitle setDrawsBackground:NO];
	[contentView addSubview:progressTitle];
	[progressTitle release];
	
	[progressSubtitle setStringValue:(subtitleString ? subtitleString : @"")];
	[progressSubtitle setFont:lucida11];
	[progressSubtitle setEditable:NO];
	[progressSubtitle setBordered:NO];
	[progressSubtitle setDrawsBackground:NO];
	[contentView addSubview:progressSubtitle];
	[progressSubtitle release];
	
	[cancelButton setTitle:buttonString];
	[cancelButton setFont:lucida13];
	[cancelButton setBezelStyle:NSRoundedBezelStyle];
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(performStop:)];
	[contentView addSubview:cancelButton];
	[cancelButton release];

	[progressIndicator setIndeterminate:!isDeterminate];
	[progressIndicator setUsesThreadedAnimation:YES];
	
	if (isDeterminate)
	{
		[progressIndicator setMinValue:minValue];
		[progressIndicator setMaxValue:maxValue];
		[progressIndicator setDoubleValue:progress];
	}
	
	[contentView addSubview:progressIndicator];
	[progressIndicator release];
	
	progressStopped = NO;
}

@end




