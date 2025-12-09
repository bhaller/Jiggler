//
//  AppDelegate.m
//  Jiggler
//
//  Created by Ben Haller on Sat Aug 02 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import "AppDelegate.h"
#import "CocoaExtra.h"
#import "SSPanels.h"
#import "SSVersionChecker.h"
#import "PrefsController.h"
#import "JigglerOverlayWindow.h"
#import "TimedQuitController.h"
#import "SSCPU.h"

#import <ApplicationServices/ApplicationServices.h>
#include <IOKit/pwr_mgt/IOPMLib.h>


static NSString *JiggleMasterSwitchDefaultsKey = @"JiggleMasterSwitch";	// BOOL, YES is jiggling on


/*
// This block is for GetBSDProcessList() below; see Technical Q&A QA1123, Getting List of All Processes on Mac OS X
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/sysctl.h>
typedef struct kinfo_proc kinfo_proc;
*/

double JigglerIdleTime(void);


double JigglerIdleTime(void)
{
    // NXIdleTime is dead; use CGEventSourceSecondsSinceLastEventType on 10.6 and later
    return CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType);
}


// Declare that we are weak-linking UpdateSystemActivity(); see its use below for comments
extern OSErr UpdateSystemActivity(UInt8 activity) __attribute__((weak_import));


@interface NSImage (JigglerTinting)

- (NSImage *)imageTintedWithColor:(NSColor *)tint;

@end

@implementation NSImage (JigglerTinting)

// from http://stackoverflow.com/questions/1413135/tinting-a-grayscale-nsimage-or-ciimage
- (NSImage *)imageTintedWithColor:(NSColor *)tint
{
	NSImage *image = [[self copy] autorelease];
	if (tint) {
		[image lockFocus];
		[tint set];
		NSRect imageRect = {NSZeroPoint, [image size]};
		NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
		[image unlockFocus];
	}
	return image;
}

@end


@implementation AppDelegate {
	IOPMAssertionID _userActivityAssertion;
}

#pragma mark Launch and Termination

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	
	//[self checkJiggleTime];
	
	// We check with a repeating timer, to avoid issues with rescheduling and such.
	// We do it this frequently because we need to notice activity to fade out our overlay.
	jiggleTimer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(periodicJiggleStatusCheck:) userInfo:nil repeats:YES];
	[jiggleTimer setTolerance:0.10];	// no need to be incredibly precise; allow the system to save energy
	
	[runLoop addTimer:jiggleTimer forMode:NSRunLoopCommonModes];
	[runLoop addTimer:jiggleTimer forMode:NSModalPanelRunLoopMode];
	[runLoop addTimer:jiggleTimer forMode:NSEventTrackingRunLoopMode];
	
	// Watch iTunes
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(iTunesChanged:) name:@"com.apple.iTunes.playerInfo" object:nil];
	iTunesIsPlaying = [self iTunesIsPlayingNow];
	
	// Watch Workspace
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(applicationListChanged:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(applicationListChanged:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(mountedDevicesChanged:) name:NSWorkspaceDidMountNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(mountedDevicesChanged:) name:NSWorkspaceDidUnmountNotification object:nil];
	
	// Set up our status item
	NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
	CGFloat barThickness = [statusBar thickness];
	NSStatusItem *statusItem = [statusBar statusItemWithLength:NSSquareStatusItemLength];
	
	[statusItem setMenu:[self statusItemMenu]];
	[self setStatusItem:statusItem];
	
	// Prepare our status item icon variants
	NSImage *jigglerImage = [NSImage imageNamed:NSImageNameApplicationIcon];
	
	scaledJigglerImage = [jigglerImage copy];
	
	[scaledJigglerImage setSize:NSMakeSize(barThickness - 2, barThickness - 2)];
	
	scaledJigglerImageRed = [[scaledJigglerImage imageTintedWithColor:[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.4]] retain];
	scaledJigglerImageGreen = [[scaledJigglerImage imageTintedWithColor:[NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:0.3]] retain];
	
	[self fixStatusItemIcon];
	
	// Set up our master switch, which remembers its last setting
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	[userDefaults registerDefaults:@{JiggleMasterSwitchDefaultsKey: @"YES"}];
	jiggleMasterSwitch = [userDefaults boolForKey:JiggleMasterSwitchDefaultsKey];
	[self fixMasterSwitchUI];
	
	// Check that we have the Accessibility access we need; see https://stackoverflow.com/a/53617674/2752221
	if (@available(macOS 15.0, *))
	{
		NSDictionary *opts = [NSDictionary dictionaryWithObjectsAndKeys:(id)kCFBooleanFalse, (id)kAXTrustedCheckOptionPrompt, nil];
		(void)AXIsProcessTrustedWithOptions((CFDictionaryRef)opts);
	}
	else if (!AXIsProcessTrusted())
	{
		NSModalResponse retval = SSRunCriticalAlertPanel(@"Turn on accessibility", @"Jiggler needs to control the mouse cursor to function.  To enable this capability, please select the Jiggler checkbox in Security & Privacy > Accessibility, and then restart Jiggler (which will quit now).", @"Turn On Accessibility", @"Quit", nil);
		
		if (retval == NSAlertFirstButtonReturn)
		{
			NSString *prefPage = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
			
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:prefPage]];
		}
		
		[NSApp terminate:nil];
	}
	
	// Prevent app nap; see https://lapcatsoftware.com/articles/prevent-app-nap.html
    activityToken = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep reason:@"No napping on the job!"];
	[activityToken retain];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
	
	[statusBar removeStatusItem:[self statusItem]];
	[self setStatusItem:nil];
	
	// Release our anti-App-Nap token
    [[NSProcessInfo processInfo] endActivity:activityToken];
	[activityToken release];
	activityToken = nil;
}


#pragma mark UI Updating

- (void)fixMasterSwitchUI
{
	// Fix the master switch menu item to be checked or unchecked
	[_masterSwitchItem setState:(jiggleMasterSwitch ? NSControlStateValueOn : NSControlStateValueOff)];
	
	// Dim the status item icon if we are disabled
	NSStatusBarButton *statusButton = [[self statusItem] button];
	
	[statusButton setAppearsDisabled:!jiggleMasterSwitch];
}

- (void)fixStatusItemIcon
{
	NSStatusBarButton *statusButton = [[self statusItem] button];
	
	if (timedQuitTimer)
		[statusButton setImage:scaledJigglerImageRed];
	else if (jigglingActive)
		[statusButton setImage:scaledJigglerImageGreen];
	else
		[statusButton setImage:scaledJigglerImage];
}

// Now that we use NSStatusItem, we show our timed quit timer in the Timed Quit menu item
- (void)fixTimedQuitMenuItem
{
	NSString *timedQuitTitle = @"Timed Quit";
	
	if (timedQuitTimer)
	{
		int hoursRemainingToTimedQuit = minutesRemainingToTimedQuit / 60;
		int remainderAfterHoursToTimedQuit = minutesRemainingToTimedQuit - (hoursRemainingToTimedQuit * 60);
		NSString *timerString = [NSString stringWithFormat:@" (%d:%@%d)", hoursRemainingToTimedQuit, (remainderAfterHoursToTimedQuit < 10) ? @"0" : @"", remainderAfterHoursToTimedQuit];
		
		timedQuitTitle = [timedQuitTitle stringByAppendingString:timerString];
	}
	
	[[self timedQuitItem] setTitle:timedQuitTitle];
}

#pragma mark Jiggling

- (void)undeclareUserActivity
{
	// Release any previous assertion made by -declareUserActivity.
	if (_userActivityAssertion != kIOPMNullAssertionID) {
		IOPMAssertionRelease(_userActivityAssertion);
		_userActivityAssertion = kIOPMNullAssertionID;
	}
}

- (void)declareUserActivity
{
	// Release any previous assertion from this method before creating a new one
	[self undeclareUserActivity];
	
	// Bump the system activity timer, in case somebody is watching it.
	// BCH 16 June 2013: This API is unofficially deprecated in favor of IOPMAssertionCreateWithName().
	// BCH 8 February 2015: UpdateSystemActivity() is officially deprecated beginning in 10.8.
	// BCH 19 May 2016: Added weak linking protection to this, just in case Apple actually removes it.
	// I'm keeping this call to UpdateSystemActivity(UsrActivity), just to try to ensure the most complete
	// coverage possible, but the new code using IOPMAssertionCreateWithName() is probably what matters now.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	if (UpdateSystemActivity != NULL)
		UpdateSystemActivity(UsrActivity);
#pragma clang diagnostic pop
	
    // Create a short-lived "user is active" assertion to reset the system idle timer
    IOReturn result = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleDisplaySleep,   // tells macOS "the user just did something"
        kIOPMAssertionLevelOn,
        CFSTR("Jiggler Zen Jiggle Activity"),
        &_userActivityAssertion
    );
	
    if (result != kIOReturnSuccess) {
        NSLog(@"[Jiggler] Failed to declare user activity (IOReturn = 0x%x)", result);
    }
}

- (BOOL)isInAScreen:(NSPoint)point
{
	NSArray *screens = [NSScreen screens];
	int i, c;
	
	// Do a boundary check against all attached screens to make sure we're in bounds.
	// We stay out of corners, to avoid making screensavers kick in and such.  This
	// also avoids an issue where setting the mouse point outside bounds makes it jump
	// to a safe initial starting location and ignore set commands.
	for (i = 0, c = (int)[screens count]; i < c; ++i)
	{
		NSScreen *screen = [screens objectAtIndex:i];
		NSRect frame = NSInsetRect([screen frame], 3, 3);
		
		if (NSPointInRect(point, frame))
			return YES;
	}
	
	return NO;
}

- (void)_setJiggleAvoidPoint
{
	NSPoint mouseLocation = [NSEvent mouseLocation];
	NSScreen *primaryScreen = [NSScreen primaryScreen];
	NSRect screenFrame = [primaryScreen frame];
	CGPoint cgMouseLocation;
	
	// Convert our current mouse location into CG coordinates
	cgMouseLocation.x = mouseLocation.x;
	cgMouseLocation.y = screenFrame.size.height - mouseLocation.y;
	
	// Remember the current point, so we can avoid it
	avoidMouseLocation.x = cgMouseLocation.x;
	avoidMouseLocation.y = cgMouseLocation.y;
}

- (void)_jiggleMouse:(id)unused
{
	NSPoint mouseLocation = [NSEvent mouseLocation];
	NSScreen *primaryScreen = [NSScreen primaryScreen];
	NSRect screenFrame = [primaryScreen frame];
	CGPoint cgMouseLocation, newLocation;
	NSPoint newKitLocation;
	
	// Convert our current mouse location into CG coordinates
	cgMouseLocation.x = mouseLocation.x;
	cgMouseLocation.y = screenFrame.size.height - mouseLocation.y;
	
	// If we've set the mouse, check to see if it has changed; if it has, the user has moved the mouse
	if (!haveGotUserMouseLocation || (haveSetMouseLocation && ((lastSetMouseLocation.x != cgMouseLocation.x) || (lastSetMouseLocation.y != cgMouseLocation.y))))
	{
		haveGotUserMouseLocation = YES;
		lastUserMouseLocation.x = cgMouseLocation.x;
		lastUserMouseLocation.y = cgMouseLocation.y;
	}
	
	// Figure out the distance scale we want to move over
	int baseTolerance = [[PrefsController sharedPrefsController] jiggleDistance];
	
	if (baseTolerance < 10) baseTolerance = 10;
	if (baseTolerance > 410) baseTolerance = 410;
	
	// Find a suitable new mouse location.  A suitable location is sufficiently close to the last seen user-set mouse
	// location, to limit our drift.  It is not equal to the location the mouse was at at the start of the current
	// jiggle, so that apps watching the mouse location periodically will see it change.  And it is on a monitor,
	// not too close to the edge of a monitor, to avoid problems with moving offscreen or into sleep corners.
    int tryCount = 0;
    
	do
	{
        // give up after a bunch of tries
        if (++tryCount > 100)
            return;
        
        // after trying for a while, broaden our scope; something is wrong; we used to hang occasionally without this
        int tolerance = (tryCount < 20) ? baseTolerance : (baseTolerance + tryCount - 20);
        
		do
		{
			newLocation.x = cgMouseLocation.x + StSRandomIntBetween(-tolerance, tolerance);
		}
		while (fabs(newLocation.x - lastUserMouseLocation.x) > 2 * tolerance);
		
		do
		{
			newLocation.y = cgMouseLocation.y + StSRandomIntBetween(-tolerance, tolerance);
		}
		while (fabs(newLocation.y - lastUserMouseLocation.y) > 2 * tolerance);
		
		newKitLocation.x = newLocation.x;
		newKitLocation.y = screenFrame.size.height - newLocation.y;
	}
	while (((newLocation.x == avoidMouseLocation.x) && (newLocation.y == avoidMouseLocation.y)) || ![self isInAScreen:newKitLocation]);
	
	// Set the mouse location to our new location.
    CGEventSourceRef sourceRef = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    
    if (sourceRef)
    {
        CFTimeInterval oldSuppressionInterval = CGEventSourceGetLocalEventsSuppressionInterval(sourceRef);
        
        // turn off local event suppression so user mouse/keyboard events don't get eaten during the jiggle period
        CGEventSourceSetLocalEventsSuppressionInterval(sourceRef, 0.0);
        
        // move the mouse
        CGEventRef eventMoved = CGEventCreateMouseEvent(sourceRef, kCGEventMouseMoved, newLocation, kCGMouseButtonLeft);
        CGEventPost(kCGHIDEventTap, eventMoved);    // kCGHIDEventTap ensures that everybody sees our posted event, no matter how low-level they are
        
        // restore the old local event suppression period
        CGEventSourceSetLocalEventsSuppressionInterval(sourceRef, oldSuppressionInterval);
        
        // clean up
        CFRelease(eventMoved);
        CFRelease(sourceRef);
        
        // Remember where we set the mouse to, so we can tell if the user moves it on us
        haveSetMouseLocation = YES;
        lastSetMouseLocation.x = newLocation.x;
        lastSetMouseLocation.y = newLocation.y;
    }
}

- (BOOL)checkRunningAppsForAppNameContaining:(NSArray *)nameComponents mustBeDockApp:(BOOL)mustBeDockApp mustBeFront:(BOOL)mustBeFront
{
	NSArray *processList = [[NSWorkspace sharedWorkspace] runningApplications];
	int i, processCount, j, componentCount;
	
	for (i = 0, processCount = (int)[processList count]; i < processCount; ++i)
	{
		NSRunningApplication *app = [processList objectAtIndex:i];
		NSString *processName = [app localizedName];
		NSApplicationActivationPolicy activationPolicy = [app activationPolicy];
        BOOL isActive = [app isActive];
        
        NSLog(@"process name: %@, is dock app == %@, is active == %@", processName, (activationPolicy == NSApplicationActivationPolicyRegular) ? @"YES" : @"NO", isActive ? @"YES" : @"NO");
        
        if (mustBeDockApp && (activationPolicy != NSApplicationActivationPolicyRegular))
            continue;
        
        if (mustBeFront && !isActive)
            continue;
        
		for (j = 0, componentCount = (int)[nameComponents count]; j < componentCount; ++j)
		{
			NSString *appNameComponent = [nameComponents objectAtIndex:j];
			
			if ([processName rangeOfString:appNameComponent options:NSCaseInsensitiveSearch].location != NSNotFound)
				return YES;
		}
	}
	
	return NO;
}

- (BOOL)checkMountedVolumesForCandidateDisks
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *volumeURLs = [fm mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsRemovableKey, NSURLVolumeIsReadOnlyKey] options:0];
	int i, c;
	
	for (i = 0, c = (int)[volumeURLs count]; i < c; ++i)
	{
		NSURL *url = [volumeURLs objectAtIndex:i];
		NSNumber *isRemovableNum = nil;
		NSNumber *isReadOnlyNum = nil;
		BOOL gotRemovable = [url getResourceValue:&isRemovableNum forKey:NSURLVolumeIsRemovableKey error:NULL];
		BOOL gotReadOnly = [url getResourceValue:&isReadOnlyNum forKey:NSURLVolumeIsReadOnlyKey error:NULL];
		
		if (gotRemovable && gotReadOnly)
		{
			if ([isRemovableNum boolValue] && ![isReadOnlyNum boolValue])
				return YES;
		}
	}
	
	return NO;
}

- (BOOL)cpuUsageOverThreshold:(int)cpuUsageThreshold
{
	int cpuBusyIndex = [SSCPU busyIndex];
	
    NSLog(@"busy index %d", cpuBusyIndex);
    
	if (cpuBusyIndex >= cpuUsageThreshold)
		return YES;
	else
		return NO;
}

- (BOOL)iTunesIsRunningNow
{
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSArray *runningApps = [ws runningApplications];
	int i, c;
	BOOL iTunesIsRunning = NO;
	
	for (i = 0, c = (int)[runningApps count]; i < c; ++i)
	{
		NSRunningApplication *runningApp = [runningApps objectAtIndex:i];
		NSString *runningAppLocalizedName = [runningApp localizedName];
		NSString *runningAppBundleIdentifier = [runningApp bundleIdentifier];
		
		NSLog(@"index %d: name %@ bundle id %@", i, runningAppLocalizedName, runningAppBundleIdentifier);
		
		if ([runningAppLocalizedName isEqualToString:@"iTunes"] || [runningAppBundleIdentifier isEqualToString:@"com.apple.iTunes"])
		{
			iTunesIsRunning = YES;
			break;
		}
	}
	
	return iTunesIsRunning;
}

- (BOOL)iTunesIsPlayingNow
{
	if ([self iTunesIsRunningNow])
	{
		NSAppleScript *iTunesScript = [[NSAppleScript alloc] initWithSource:@"tell application \"iTunes\"\nget player state\nend tell"];
		NSDictionary *errorDict = nil;
		NSAppleEventDescriptor *returnDesc = nil;
		
		returnDesc = [iTunesScript executeAndReturnError:&errorDict];
		[iTunesScript autorelease];
		
		return [[returnDesc stringValue] isEqualToString:@"kPSP"];
	}
	
	return NO;
}

- (void)setJigglingActive:(BOOL)active
{
	// This is called whenever we make a decision about jiggling being on or off.  It responds to a change in
	// jiggling state; if the state is the same, it does nothing.  (Actions that should be done each jiggle,
	// such as actually moving the mouse, happen outside of this method; this is for state changes only.)
	PrefsController *prefs = [PrefsController sharedPrefsController];
	BOOL showIconWhenJiggling = [prefs showJigglerIconWhenJiggling];
	
	if (jigglingActive != active)
	{
		jigglingActive = active;
		
		if (jigglingActive)
		{
			if (showIconWhenJiggling)
				[JigglerOverlayWindow activateOverlay];
			
			[self fixStatusItemIcon];
		}
		else
		{
			// Release any previous assertion whenever jiggling goes inactive.  The -declareUserActivity
			// assertion of activity seems to last a while before it expires, so we need to undeclare
			// or we won't fall asleep for a while even though all of the jiggle conditions are met.
			[self undeclareUserActivity];
			
			if (showIconWhenJiggling)
				[JigglerOverlayWindow deactivateOverlay];
			
			[self fixStatusItemIcon];
		}
	}
}

- (BOOL)jiggleConditionsMet
{
	if (!jiggleMasterSwitch)
		return NO;
	
	PrefsController *prefs = [PrefsController sharedPrefsController];
	BOOL onlyWithCPUUsage = [prefs onlyWithCPUUsage];
    int cpuUsageThreshold = [prefs cpuUsageThreshold];
	BOOL onlyWithRemovableWritableDisks = [prefs onlyWithRemovableWritableDisks];
	NSArray *applicationNameComponents = [prefs applicationNameComponents];
    BOOL mustBeDockApp = ([prefs onlyWithIdentityTag] == 0);    // 0 means the user wants apps only, 1 means any process
	BOOL onlyWithApplicationsNamedX = ([prefs onlyWithApplicationsNamedX] && [applicationNameComponents count]);
	BOOL onlyWithITunesPlaying = [prefs onlyWithITunesPlaying];
	
	// If no conditions are set, then the conditions are met
	if (!onlyWithCPUUsage && !onlyWithRemovableWritableDisks && !onlyWithApplicationsNamedX && !onlyWithITunesPlaying)
    {
		return YES;
	}
    
	// If we have conditions, check them; if any one is met, we return YES
	if (onlyWithApplicationsNamedX && [self checkRunningAppsForAppNameContaining:applicationNameComponents mustBeDockApp:mustBeDockApp mustBeFront:NO])
    {
        NSLog(@"jiggleConditionsMet: app matching name is running");
		return YES;
	}
	if (onlyWithRemovableWritableDisks && [self checkMountedVolumesForCandidateDisks])
    {
        NSLog(@"jiggleConditionsMet: mounted removable writable disk present");
		return YES;
	}
	if (onlyWithCPUUsage && [self cpuUsageOverThreshold:cpuUsageThreshold])
    {
        NSLog(@"jiggleConditionsMet: cpu usage is high");
		return YES;
	}
	if (onlyWithITunesPlaying && ([self iTunesIsRunningNow] && iTunesIsPlaying))
    {
        NSLog(@"jiggleConditionsMet: iTunes is playing");
		return YES;
	}
	
	// If we have conditions and none of them are met, then we return NO
    NSLog(@"jiggleConditionsMet: NO");
	return NO;
}

- (void)periodicJiggleStatusCheck:(id)unused
{
	static unsigned int callout_counter = 0;
	int i;
	PrefsController *prefs = [PrefsController sharedPrefsController];
	double idleTime = -1.0;
	double jiggleSeconds = [prefs jiggleSeconds];
	double timeSinceLastJiggle = (timeOfLastJiggle ? -[timeOfLastJiggle timeIntervalSinceNow] : 100000.0);
	BOOL jiggleOnlyWhenIdle = [prefs jiggleOnlyWhenIdle];
	BOOL notOnBattery = [prefs notOnBattery];
	BOOL notWhenScreenLocked = [prefs notWhenScreenLocked];
	NSArray *frontAppNameComponents = [prefs frontAppNameComponents];
	BOOL notWithFrontAppsNamedX = ([prefs notWithFrontAppsNamedX] && [frontAppNameComponents count]);
	BOOL jiggleConditionsTested = NO;
	BOOL jiggleConditionsMet = NO;
	
	// Keep track of callouts, so we can skip operations on some callouts for lower CPU usage
	// Each callout is 0.25 seconds, so ((callout_counter & 0x0F) == 0) gives you every 4.0 seconds...
	callout_counter++;
	
	// Check for conditions under which jiggling is forbidden; if any are true, turn off jiggling immediately
	// and return.  There are no cases under which jiggling occurs, or stays on when active, with these conditions.
	if ((notOnBattery && RunningOnBatteryOnly()) ||
		(notWithFrontAppsNamedX && [self checkRunningAppsForAppNameContaining:frontAppNameComponents mustBeDockApp:YES mustBeFront:YES]) ||
		(notWhenScreenLocked && ScreenIsLocked()))
	{
		[self setJigglingActive:NO];
		return;
	}
	
	// If a mouse button is down, we don't jiggle; we don't want to interfere with dragging.  There are 32 buttons
	// to check!  If we're set to jiggle only when idle, then a mouse button being down makes us stop jiggling;
	// a mouse button being down is "non-idle".  (Probably this would also reset the system activity timer, but
	// there have been system versions where that wasn't true, I think, so we check here to be sure.)  If we're
	// set to jiggle even when idle, then a mouse button being down doesn't make us stop jiggling if we're doing
	// so already, but we return here so that we don't start jiggling while the button is down.
	for (int buttonIndex = 0; buttonIndex < 32; ++buttonIndex)
	{
		if (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, buttonIndex))
		{
			if (jiggleOnlyWhenIdle)
				[self setJigglingActive:NO];
			return;
		}
	}
	
	// If jiggling is active, check for user activity since our last jiggle and wake up if appropriate
	if (jigglingActive)
	{
		// Get the system idle time if we haven't already fetched it
		if (jiggleOnlyWhenIdle && (idleTime < 0.0))
			idleTime = JigglerIdleTime();
		
		// The code below schedules mouse moves for up to 0.34 seconds beyond timeOfLastJiggle, so 0.4 gives us
		// a little wiggle room so that our own jiggling activity doesn't cause us to stop jiggling
		if (jiggleOnlyWhenIdle && (idleTime < timeSinceLastJiggle - 0.4))
		{
			NSLog(@"idleTime %f, timeSinceLastJiggle %f, delta = %f, deactivating", idleTime, timeSinceLastJiggle, timeSinceLastJiggle - idleTime);
			[self setJigglingActive:NO];
		}
		else if (((callout_counter & 0x0F) == 0) || jiggleConditionsLikelyToHaveChanged)
		{
			if (!jiggleConditionsTested)
			{
				jiggleConditionsMet = [self jiggleConditionsMet];
				jiggleConditionsTested = YES;
				jiggleConditionsLikelyToHaveChanged = NO;
			}
			
			if (!jiggleConditionsMet)
				[self setJigglingActive:NO];
		}
	}
	
#if 0
	// BCH 12/9/2025: This is debugging code that is normally disabled since it logs quite a bit.
	if (YES)
	{
		if (idleTime < 0.0)
			idleTime = JigglerIdleTime();
			
		NSLog(@"JigglerIdleTime() == %f, jiggleSeconds == %f, timeSinceLastJiggle == %f", idleTime, jiggleSeconds, timeSinceLastJiggle);
	}
	else
		NSLog(@"jiggleSeconds == %f, timeSinceLastJiggle == %f", jiggleSeconds, timeSinceLastJiggle);
#endif
	
	// If we last jiggled jiggleSeconds ago (or longer), it's time for another jiggle as long as conditions are met.
	if (timeSinceLastJiggle > jiggleSeconds)
	{
		// Get the system idle time if we haven't already fetched it
		if (jiggleOnlyWhenIdle && (idleTime < 0.0))
			idleTime = JigglerIdleTime();
		
		if (!jiggleOnlyWhenIdle || (idleTime > jiggleSeconds))
		{
			if (!jiggleConditionsTested)
			{
				jiggleConditionsMet = [self jiggleConditionsMet];
				jiggleConditionsTested = YES;
				jiggleConditionsLikelyToHaveChanged = NO;
			}
			
			if (jiggleConditionsMet)
			{
				int jiggleStyle = [prefs jiggleStyle];
                
				if (jiggleStyle == 1)
				{
					// Zen jiggle: skip actually moving the mouse.  Of course some apps watch the cursor position rather
					// than looking at the system idle time, so Zen jiggle may fail to jiggle some apps; caveat jigglor...
				}
				else if (jiggleStyle == 2)
				{
					// Click jiggle: click the mouse once, at the current cursor location, without moving the mouse
					NSPoint mouseLocation = [NSEvent mouseLocation];
					NSScreen *primaryScreen = [NSScreen primaryScreen];
					NSRect screenFrame = [primaryScreen frame];
					CGPoint cgMouseLocation;
					
					cgMouseLocation.x = mouseLocation.x;
					cgMouseLocation.y = screenFrame.size.height - mouseLocation.y;
					
					// Create and post the mouse-down and mouse-up events
					CGEventRef click_down = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, cgMouseLocation, kCGMouseButtonLeft);
					CGEventRef click_up = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, cgMouseLocation, kCGMouseButtonLeft);
					
                    if (click_down && click_up)
                    {
                        CGEventPost(kCGHIDEventTap, click_down);
                        usleep(10000);
                        CGEventPost(kCGHIDEventTap, click_up);
                        
                        CFRelease(click_down);
                        CFRelease(click_up);
                    }
                    else
                    {
                        static bool beenHere = false;
                        
                        if (!beenHere)
                        {
                            NSLog(@"Jiggler was unable to create mouse click events.");
                            beenHere = true;
                        }
                    }
				}
				else	// jiggleStyle == 0, and bad values
				{
					// Standard jiggle: move the mouse a bunch of times
					// Remember the current mouse point, so we can avoid hitting it exactly
					[self _setJiggleAvoidPoint];
					
					// Schedule a bunch of mouse-moves
					for (i = 0; i < 35; ++i)
						[self performSelector:@selector(_jiggleMouse:) withObject:nil afterDelay:(double)i / 100.0 inModes:@[NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode]];
				}
				
				// This is shared functionality across all jiggle styles; it implements the base "zen jiggle"
				// functionality and the various bookkeeping activities needed when jiggling occurs.
				[self declareUserActivity];
				
				[timeOfLastJiggle release];
				timeOfLastJiggle = [[NSDate alloc] init];
				
				[self setJigglingActive:YES];
			}
			else
			{
				// We've determined that we've been idle long enough, but our jiggle conditions have not been met.  They aren't
				// likely to change with great rapidity, so to avoid burning CPU, we will set our timer so that we don't check
				// too often.  If we put it to ((now - jiggleSeconds) + 5), we recheck jiggle conditions every 5 seconds.
				[timeOfLastJiggle release];
				timeOfLastJiggle = [[NSDate dateWithTimeIntervalSinceNow:(-jiggleSeconds) + 5] retain];
			}
		}
		else
		{
			// Set timeOfLastJiggle to reduce the amount of work we do on this callout in the future
			[timeOfLastJiggle release];
			timeOfLastJiggle = [[NSDate dateWithTimeIntervalSinceNow:-idleTime] retain];
		}
	}
}

#if 0
// BCH 12/9/2025: I think this got disabled because the GetDimmingTimeout() function disappeared on us...?  It was
// actually a nice thing that Jiggler checked this and warned the user, because people would get confused when
// their screensaver came on even though Jiggler was enabled (because their jiggle time was too long).  But I
// don't know whether there's any way to get the screensaver/sleep time nowadays.
- (void)checkJiggleTime
{
	double jiggleSeconds = [[PrefsController sharedPrefsController] jiggleTime] * 60.0;
	double screensaverDelay = GetDimmingTimeout();
	
	NSLog(@"screensaverDelay = %f", screensaverDelay);
	
	if (jiggleSeconds >= screensaverDelay)
		NSRunCriticalAlertPanel(SSLocalizedString(@"Jiggler", @"Jiggle time warning panel title"), SSLocalizedString(@"The jiggle time you currently have set is longer than your screensaver or sleep delay, so Jiggler may not keep your machine alert.  You may wish to change your jiggle time in Jiggler's Preferences panel.", @"Jiggle time warning panel text"), SSLocalizedStringFromTable(@"OK button", @"Base", @"OK button"), nil, nil);
}

// Add to Localizable.strings:

/*
 *	These strings are used to build the panel that warns the user that their chosen jiggle time may be too long
 */

/* Jiggle time warning panel title */
"Jiggler" = "Jiggler";

/* Jiggle time warning panel text */
"The jiggle time you currently have set is longer than your screensaver or sleep delay, so Jiggler may not keep your machine alert.  You may wish to change your jiggle time in Jiggler's Preferences panel.";

#endif

- (void)iTunesChanged:(NSNotification *)note
{
	NSDictionary *ui = [note userInfo];
	NSString *playerState = [ui objectForKey:@"Player State"];
	
	iTunesIsPlaying = (playerState && [playerState isEqualToString:@"Playing"]);
	jiggleConditionsLikelyToHaveChanged = YES;
	
	// Bump our jiggle code for immediate action if appropriate
	[self periodicJiggleStatusCheck:nil];
	
	NSLog(@"iTunesChanged:");
}

- (void)applicationListChanged:(NSNotification *)note
{
	jiggleConditionsLikelyToHaveChanged = YES;
	
	// Bump our jiggle code for immediate action if appropriate
	[self periodicJiggleStatusCheck:nil];
	
	NSLog(@"applicationListChanged:");
}

- (void)mountedDevicesChanged:(NSNotification *)note
{
	jiggleConditionsLikelyToHaveChanged = YES;
	
	// Bump our jiggle code for immediate action if appropriate
	[self periodicJiggleStatusCheck:nil];
	
	NSLog(@"mountedDevicesChanged:");
}


#pragma mark IB Actions

- (IBAction)showAbout:(id)sender
{
	NSDictionary *linkDict = [NSDictionary dictionaryWithObjectsAndKeys:
							  @"http://www.sticksoftware.com/", @"www.sticksoftware.com",
							  @"http://www.gnu.org/licenses/", @"http://www.gnu.org/licenses/",
							  @"https://github.com/bhaller/Jiggler", @"https://github.com/bhaller/Jiggler",
							  nil];
	
	[NSWindow runStandardSSAboutPanelWithURLDictionary:linkDict hideOnDeactivate:NO];
}

- (IBAction)showReadMe:(id)sender
{
	NSString *readmePath = [[NSBundle mainBundle] pathForResource:@"Read Me" ofType:@"html"];
	NSURL *readmeURL = [NSURL fileURLWithPath:readmePath];
	
	[[NSWorkspace sharedWorkspace] openURL:readmeURL];
}

- (IBAction)showProductHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sticksoftware.com/software/Jiggler.html"]];
}

- (IBAction)showStickSoftwarePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sticksoftware.com/"]];
}

- (IBAction)sendStickSoftwareEmail:(id)sender
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSDictionary *infoDictionary = [mainBundle infoDictionary];
	NSString *appVersionString = [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
	NSString *bundleName = [infoDictionary objectForKey:(NSString *)kCFBundleNameKey];
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:support@sticksoftware.com?subject=%@%%20%@", bundleName, appVersionString]]];
}

- (IBAction)showPreferences:(id)sender
{
	[[PrefsController sharedPrefsController] showWindow];
}

- (IBAction)checkVersionNow:(id)sender
{
	[[SSVersionChecker sharedVersionChecker] checkForNewVersionUserRequested:YES];
}

- (IBAction)automaticVersionChecking:(id)sender
{
	[[SSVersionChecker sharedVersionChecker] askUserAboutAutomaticVersionCheck];
}

- (IBAction)jiggleMasterSwitchChanged:(id)sender
{
	jiggleMasterSwitch = !jiggleMasterSwitch;
	
	if (!jiggleMasterSwitch)
		[self cancelTimedQuit:nil];
	
	[[NSUserDefaults standardUserDefaults] setBool:jiggleMasterSwitch forKey:JiggleMasterSwitchDefaultsKey];
	[self fixMasterSwitchUI];
	
	// There's probably no need to call -setJigglingActive:NO here, or do any similar actions;
	// the user can only turn off the jiggle master switch via the mouse or keyboard, so the
	// jiggle state is probably already off due to that activity, or will turn off momentarily.
	// Note that -jiggleConditionsMet checks jiggleMasterSwitch, so the next time it is called
	// jiggling will turn off due to that flag being NO anyway, too.
}


#pragma mark Timed Quit

- (void)_timedQuitTimer:(id)unused
{
	--minutesRemainingToTimedQuit;
	
	[self fixTimedQuitMenuItem];
	
	// If we're out of time, quit.  We do this with a slight delay so our icon shows 0:00 for a moment first.
	// We also limit this perform to default mode only, so we don't quit in the middle of a model panel or a tracking loop
	if (minutesRemainingToTimedQuit <= 0)
		[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.5 inModes:@[NSDefaultRunLoopMode]];
}

- (IBAction)timedQuit:(id)sender
{
	minutesRemainingToTimedQuit = [TimedQuitController runPanelForMinutesUntilQuit];
	
	if (minutesRemainingToTimedQuit)
	{
		NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
		
		timedQuitTimer = [NSTimer timerWithTimeInterval:60.0 target:self selector:@selector(_timedQuitTimer:) userInfo:nil repeats:YES];
		[runLoop addTimer:timedQuitTimer forMode:NSRunLoopCommonModes];
		[runLoop addTimer:timedQuitTimer forMode:NSModalPanelRunLoopMode];		// not clear whether this is part of NSRunLoopCommonModes...
		[runLoop addTimer:timedQuitTimer forMode:NSEventTrackingRunLoopMode];	// not clear whether this is part of NSRunLoopCommonModes...
		
		[self fixTimedQuitMenuItem];
		[self fixStatusItemIcon];
	}
}

- (IBAction)cancelTimedQuit:(id)sender
{
	if (timedQuitTimer)
	{
		[timedQuitTimer invalidate];
		timedQuitTimer = nil;
		
		minutesRemainingToTimedQuit = 0;
		
		[self fixTimedQuitMenuItem];
		[self fixStatusItemIcon];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(timedQuit:))
		return ((timedQuitTimer || !jiggleMasterSwitch) ? NO : YES);
	if (action == @selector(cancelTimedQuit:))
		return (timedQuitTimer ? YES : NO);
	
	return YES;
}

@end




























