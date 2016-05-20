//
//  AppDelegate.h
//  Jiggler
//
//  Created by Ben Haller on Sat Aug 02 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject
{
	BOOL jiggleMasterSwitch;	// YES if we are enabled for jiggling (as set by the user)
	BOOL jigglingActive;		// YES if we are jiggling right now (conditions are met, delay has gone by, etc.)
	
	// Jiggle timer
	NSTimer *jiggleTimer;
	NSDate *timeOfLastJiggle;
	
	// Jiggle mouse location management
	BOOL haveSetMouseLocation;
	CGPoint lastSetMouseLocation;
	BOOL haveGotUserMouseLocation;
	CGPoint lastUserMouseLocation;
	CGPoint avoidMouseLocation;
	
	// Timed quit support
	NSTimer *timedQuitTimer;
	int minutesRemainingToTimedQuit;
	
	// Spying on iTunes
	BOOL iTunesIsPlaying;
	BOOL jiggleConditionsLikelyToHaveChanged;
	
	// Status bar icon variants
	NSImage *scaledJigglerImage;
	NSImage *scaledJigglerImageRed;
	NSImage *scaledJigglerImageGreen;
}

@property (retain) IBOutlet NSMenu *statusItemMenu;
@property (retain) IBOutlet NSMenuItem *masterSwitchItem;
@property (retain) IBOutlet NSMenuItem *timedQuitItem;
@property (retain) NSStatusItem *statusItem;

- (IBAction)showAbout:(id)sender;
- (IBAction)showReadMe:(id)sender;
- (IBAction)showProductHomePage:(id)sender;
- (IBAction)showStickSoftwarePage:(id)sender;
- (IBAction)sendStickSoftwareEmail:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)checkVersionNow:(id)sender;
- (IBAction)automaticVersionChecking:(id)sender;

- (IBAction)timedQuit:(id)sender;
- (IBAction)cancelTimedQuit:(id)sender;

- (IBAction)jiggleMasterSwitchChanged:(id)sender;

@end
