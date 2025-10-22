//
//  JigglerOverlayWindow.m
//  Jiggler
//
//  Created by Ben Haller on Wed Aug 25 2004.
//  Copyright (c) 2004 Stick Software. All rights reserved.
//

#import "JigglerOverlayWindow.h"


static NSString *JigglerOverlayHorizontalPositionDefaultsKey = @"OverlayHorizontalPosition";
static NSString *JigglerOverlayVerticalPositionDefaultsKey = @"OverlayVerticalPosition";


@interface JigglerOverlayWindow (PrivateAPI)

+ (JigglerOverlayWindow *)sharedOverlayWindow;

- (void)scheduleTimer;

- (void)activate;
- (void)deactivate;
- (BOOL)isActivated;

@end


@interface JigglerOverlayView : NSImageView

@end


@implementation JigglerOverlayWindow

+ (void)activateOverlay
{
	JigglerOverlayWindow *sharedOverlay = [JigglerOverlayWindow sharedOverlayWindow];
	
	[sharedOverlay activate];
}

+ (void)deactivateOverlay
{
	JigglerOverlayWindow *sharedOverlay = [JigglerOverlayWindow sharedOverlayWindow];
	
	[sharedOverlay deactivate];
}

+ (BOOL)isActivated
{
	JigglerOverlayWindow *sharedOverlay = [JigglerOverlayWindow sharedOverlayWindow];
	
	return [sharedOverlay isActivated];
}

+ (JigglerOverlayWindow *)sharedOverlayWindow
{
	static JigglerOverlayWindow *sharedOverlay = nil;
	
	if (!sharedOverlay)
		sharedOverlay = [[JigglerOverlayWindow alloc] init];
	
	return sharedOverlay;
}

- (void)createOverlayWindow
{
	NSScreen *mainScreen = [[NSScreen screens] objectAtIndex:0];
	// Prefer the mainScreen accessor on macOS 15+ to ensure proper centering
	if (@available(macOS 15.0, *))
	{
		NSScreen *main = [NSScreen mainScreen];
		if (main) mainScreen = main;
	}
	NSRect screenFrame = [mainScreen frame];
	NSRect contentRect;
	JigglerOverlayView *iconView;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSNumber *horizontalPosition = [defaults objectForKey:JigglerOverlayHorizontalPositionDefaultsKey];
	NSNumber *verticalPosition = [defaults objectForKey:JigglerOverlayVerticalPositionDefaultsKey];
	
	// Figure out a centered rect for the overlay
	contentRect.size.width = 200;
	contentRect.size.height = 200;
	contentRect.origin.x = screenFrame.origin.x + floor((screenFrame.size.width - contentRect.size.width) / 2.0);
	contentRect.origin.y = screenFrame.origin.y + floor((screenFrame.size.height - contentRect.size.height) / 2.0);
	
	// Use our defaults window location if it exists
	// On macOS 15+, skip restoring saved position to ensure centering
	if (@available(macOS 15.0, *))
	{
		// do nothing; keep centered on main screen
	}
	else
	{
		if (horizontalPosition && verticalPosition)
		{
			int horizontalInt = [horizontalPosition intValue];
			int verticalInt = [verticalPosition intValue];
			NSRect defaultBasedRect = NSMakeRect(horizontalInt, verticalInt, contentRect.size.width, contentRect.size.height);
			NSArray *screens = [NSScreen screens];
			int i, c;
			
			for (i = 0, c = (int)[screens count]; i < c; ++i)
			{
				NSScreen *screen = [screens objectAtIndex:i];
				NSRect frame = [screen frame];
				
				if (NSIntersectsRect(frame, defaultBasedRect))
				{
					NSRect intersection = NSIntersectionRect(frame, defaultBasedRect);
					float intersectionSize = intersection.size.width * intersection.size.height;
					
					if (intersectionSize >= 400.0)
					{
						// We have a screen on which our defaults-based frame will lie, so we can use it.
						contentRect = defaultBasedRect;
						break;
					}
				}
			}
		}
	}
	
	// Make our overlay window
	overlayWindow = [[NSWindow alloc] initWithContentRect:contentRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
	[overlayWindow setCanHide:NO];
	[overlayWindow setHasShadow:NO];
	[overlayWindow setHidesOnDeactivate:NO];
	[overlayWindow setExcludedFromWindowsMenu:YES];
	[overlayWindow setOpaque:NO];
	[overlayWindow setReleasedWhenClosed:NO];
	[overlayWindow setLevel:NSScreenSaverWindowLevel - 20];
	[overlayWindow setAlphaValue:0.0];
	[overlayWindow setBackgroundColor:[NSColor clearColor]];
	[overlayWindow setIgnoresMouseEvents:NO];
	
	// Configure our behavior with Spaces / Exposé / Mission Control
	[overlayWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces |
										 NSWindowCollectionBehaviorStationary |
										 NSWindowCollectionBehaviorIgnoresCycle |
										 NSWindowCollectionBehaviorFullScreenAuxiliary |
										 NSWindowCollectionBehaviorFullScreenDisallowsTiling];
	
	// Make our icon view
	iconView = [[JigglerOverlayView alloc] initWithFrame:NSMakeRect(0, 0, contentRect.size.width, contentRect.size.height)];
	[iconView setEditable:NO];
	[iconView setImageAlignment:NSImageAlignCenter];
	[iconView setImageFrameStyle:NSImageFrameGrayBezel];
	[iconView setImageScaling:NSImageScaleNone];
	[iconView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	
	// Make our icon view be our content view
	[overlayWindow setContentView:iconView];
	[iconView release];
}

- (void)timer:(id)unused
{
	float targetAlpha;
	BOOL needsAnotherUpdate;
	
	// We no longer have a scheduled timer
	scheduledTimer = NO;
	
	// Figure out what our target and new alpha are
	if (activated)
		targetAlpha = 1.0;
	else
		targetAlpha = 0.0;
	
	if (activated)
	{
		currentAlpha += 0.025;
		
		if (currentAlpha < targetAlpha - 0.01)
		{
			needsAnotherUpdate = YES;
		}
		else
		{
			currentAlpha = targetAlpha;
			needsAnotherUpdate = NO;
		}
	}
	else
	{
		currentAlpha -= 0.1;	// fade out much faster than we fade in
		
		if (currentAlpha > targetAlpha + 0.01)
		{
			needsAnotherUpdate = YES;
		}
		else
		{
			currentAlpha = targetAlpha;
			needsAnotherUpdate = NO;
		}
	}
	
	// If we will need another update, schedule it now for greater timing precision
	if (needsAnotherUpdate)
		[self scheduleTimer];
	
	// And finally, do our update for this tick
	[overlayWindow setAlphaValue:currentAlpha];
	
	if (currentAlpha < 0.01)
	{
		if (isOrderedIn)
		{
			[overlayWindow orderOut:nil];
			isOrderedIn = NO;
		}
	}
	else
	{
		if (!isOrderedIn)
		{
			[overlayWindow orderBack:nil];
			isOrderedIn = YES;
		}
	}
}

- (void)scheduleTimer
{
	if (!scheduledTimer)
	{
		[self performSelector:@selector(timer:) withObject:nil afterDelay:0.05 inModes:@[NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode]];
		scheduledTimer = YES;
	}
}

- (void)activate
{
    NSLog(@"+++ activate");
	if (!overlayWindow)
		[self createOverlayWindow];
	
	activated = YES;
	[self scheduleTimer];
}

- (void)deactivate
{
    NSLog(@"--- deactivate");
	activated = NO;
	[self scheduleTimer];
}

- (BOOL)isActivated
{
	return activated;
}

@end

@implementation JigglerOverlayView

- (void)mouseDown:(NSEvent *)event
{
    if ([event type] == NSEventTypeLeftMouseDown)
    {
        NSWindow *eventWindow = [event window];
		NSPoint locInWindow = [event locationInWindow];
		NSRect locInWindowRect = NSMakeRect(locInWindow.x, locInWindow.y, 1, 1);
        NSPoint startMouse = [eventWindow convertRectToScreen:locInWindowRect].origin;	// these NSRect shenanigans are because convertBaseToScreen: has been deprecated, for no apparent reason...
		NSRect windowFrame = [eventWindow frame];
		
        do
        {
            NSPoint nextLocInWindow = [event locationInWindow];
			NSRect nextLocInWindowRect = NSMakeRect(nextLocInWindow.x, nextLocInWindow.y, 1, 1);
			NSPoint nextMouse = [eventWindow convertRectToScreen:nextLocInWindowRect].origin;	// these NSRect shenanigans are because convertBaseToScreen: has been deprecated, for no apparent reason...
            int dx = (nextMouse.x - startMouse.x), dy = (nextMouse.y - startMouse.y);
            
            startMouse = nextMouse;
			
			windowFrame.origin.x += dx;
			windowFrame.origin.y += dy;
            
			[eventWindow setFrame:windowFrame display:YES];
			
            [[NSUserDefaults standardUserDefaults] setInteger:(int)windowFrame.origin.x forKey:JigglerOverlayHorizontalPositionDefaultsKey];
            [[NSUserDefaults standardUserDefaults] setInteger:(int)windowFrame.origin.y forKey:JigglerOverlayVerticalPositionDefaultsKey];
            
            if ([event type] == NSEventTypeLeftMouseUp)
                break;
        }
		while ((event = [eventWindow nextEventMatchingMask:(NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]));
    }
}

@end














