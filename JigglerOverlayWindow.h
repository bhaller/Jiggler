//
//  JigglerOverlayWindow.h
//  Jiggler
//
//  Created by Ben Haller on Wed Aug 25 2004.
//  Copyright (c) 2004 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface JigglerOverlayWindow : NSObject
{
	NSWindow *overlayWindow;
	
	float currentAlpha;
	BOOL activated, isOrderedIn, scheduledTimer;
}

+ (void)activateOverlay;
+ (void)deactivateOverlay;

+ (BOOL)isActivated;

// Toggle whether the overlay window passes mouse events through to whatever
// is behind it.  Used by the click-jiggle path so that a synthetic click
// delivered at the cursor location does not get absorbed by the overlay if
// the user has parked the cursor on top of it (issue #18).  Returns the
// previous flag value so callers can restore it.  No-op (returns NO) when
// the overlay window has not been created yet.
+ (BOOL)setOverlayIgnoresMouseEvents:(BOOL)flag;

@end
