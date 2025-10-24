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
	jiggleTimer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(jiggleMouse:) userInfo:nil repeats:YES];
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

// vestigial code from when Jiggler was Dock-based instead of using an NSStatusItem; kept this code in case it proves useful to someone
- (void)fixAppIconForTimedQuit
{
	NSImage *appImage = [NSImage imageNamed: @"NSApplicationIcon"];
	
	if (timedQuitTimer)
	{
		int hoursRemainingToTimedQuit = minutesRemainingToTimedQuit / 60;
		int remainderAfterHoursToTimedQuit = minutesRemainingToTimedQuit - (hoursRemainingToTimedQuit * 60);
		NSString *timerString = [NSString stringWithFormat:@"%d:%@%d", hoursRemainingToTimedQuit, (remainderAfterHoursToTimedQuit < 10) ? @"0" : @"", remainderAfterHoursToTimedQuit];
		NSFont *timerFont = [NSFont fontWithName:@"Times" size:50];
		NSDictionary *timerDict = [NSDictionary dictionaryWithObjectsAndKeys:timerFont, NSFontAttributeName, nil];
		NSDictionary *timerShadowDict = [NSDictionary dictionaryWithObjectsAndKeys:timerFont, NSFontAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
		NSSize timerSize = [timerString sizeWithAttributes:timerDict];
		NSPoint timerPoint = NSMakePoint(64 - floor(timerSize.width / 2), 64);
		NSImage *newAppImage = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
		
		[newAppImage lockFocus];
		
		[appImage drawAtPoint:NSMakePoint(0, 0) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
		
		//[timerString drawAtPoint:NSMakePoint(timerPoint.x + 2, timerPoint.y - 2) withAttributes:timerShadowDict];
		for (int shadowIndex = 0; shadowIndex < 25; ++shadowIndex)
			[timerString drawAtPoint:NSMakePoint(timerPoint.x + (shadowIndex / 5) - 2, timerPoint.y + (shadowIndex % 5) - 2) withAttributes:timerShadowDict];
		
		[timerString drawAtPoint:timerPoint withAttributes:timerDict];
		
		[newAppImage unlockFocus];
		
		appImage = newAppImage;
	}
	
	[NSApp setApplicationIconImage:appImage];
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

- (void)declareUserActivity
{
    // Release any previous assertion before creating a new one
    if (_userActivityAssertion != kIOPMNullAssertionID) {
        IOPMAssertionRelease(_userActivityAssertion);
        _userActivityAssertion = kIOPMNullAssertionID;
    }

    // Create a short-lived "user is active" assertion to reset system idle timer
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

/*
 BCH 16 June 2013: -[NSWorkspace runningApplications] gives information on user processes, too, not just apps, so we don't need this code at present.
 
// This code from Technical Q&A QA1123, Getting List of All Processes on Mac OS X
static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)
// Returns a list of all BSD processes on the system.  This routine
// allocates the list and puts it in *procList and a count of the
// number of entries in *procCount.  You are responsible for freeing
// this list (use "free" from System framework).
// On success, the function returns 0.
// On error, the function returns a BSD errno value.
{
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;
    
    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);
    
    *procCount = 0;
    
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
    
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
        
        // Call sysctl with a NULL buffer.
        
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        if (err == -1) {
            err = errno;
        }
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    // Clean up and establish post conditions.
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }
    
    assert( (err == 0) == (*procList != NULL) );
    
    return err;
}

// This code from http://stackoverflow.com/questions/2518160/programmatically-check-if-a-process-is-running-on-mac
- (NSDictionary *)infoForPID:(pid_t)pid
{
    NSDictionary *ret = nil;
    ProcessSerialNumber psn = { kNoProcess, kNoProcess };
    if (GetProcessForPID(pid, &psn) == noErr) {
        CFDictionaryRef cfDict = ProcessInformationCopyDictionary(&psn,kProcessDictionaryIncludeAllInformationMask);
        ret = [NSDictionary dictionaryWithDictionary:(NSDictionary *)cfDict];
        CFRelease(cfDict);
    }
    return ret;
}

// This code from http://stackoverflow.com/questions/2518160/programmatically-check-if-a-process-is-running-on-mac
- (NSArray*)getBSDProcessList
{
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:1];
    kinfo_proc *mylist;
    size_t mycount = 0;
    mylist = (kinfo_proc *)malloc(sizeof(kinfo_proc));
    GetBSDProcessList(&mylist, &mycount);
    int k;
    for(k = 0; k < mycount; k++) {
        kinfo_proc *proc = NULL;
        proc = &mylist[k];
        NSString *fullName = [[self infoForPID:proc->kp_proc.p_pid] objectForKey:(id)kCFBundleNameKey];
        if (fullName == nil) fullName = [NSString stringWithFormat:@"%s",proc->kp_proc.p_comm];
        [ret addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        fullName,@"pname",
                        [NSString stringWithFormat:@"%d",proc->kp_proc.p_pid],@"pid",
                        [NSString stringWithFormat:@"%d",proc->kp_eproc.e_ucred.cr_uid],@"uid",
                        nil]];
    }
    free(mylist);
    return ret;
}

- (BOOL)checkRunningProcessesForProcessNameContaining:(NSArray *)nameComponents
{
	NSArray *processList = [self getBSDProcessList];
	int i, processCount, j, componentCount;
	
	for (i = 0, processCount = [processList count]; i < processCount; ++i)
	{
		NSDictionary *processDict = [processList objectAtIndex:i];
		NSString *processName = [processDict objectForKey:@"pname"];
		
		for (j = 0, componentCount = [nameComponents count]; j < componentCount; ++j)
		{
			NSString *appNameComponent = [nameComponents objectAtIndex:j];
			
			if ([processName rangeOfString:appNameComponent options:NSCaseInsensitiveSearch].location != NSNotFound)
				return YES;
		}
	}
	
	return NO;
}
*/

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
	if (jigglingActive != active)
	{
		jigglingActive = active;
		
		if (jigglingActive)
		{
			[JigglerOverlayWindow activateOverlay];
			[self fixStatusItemIcon];
		}
		else
		{
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
	
	// If we have conditions and they are not met, then we return NO
    NSLog(@"jiggleConditionsMet: NO");
	return NO;
}

- (void)jiggleMouse:(id)unused
{
	static unsigned int callout_counter = 0;
	int i;
	PrefsController *prefs = [PrefsController sharedPrefsController];
	double idleTime = -1.0;
	double jiggleSeconds = [prefs jiggleSeconds];
	double timeSinceLastJiggle = (timeOfLastJiggle ? -[timeOfLastJiggle timeIntervalSinceNow] : 100000.0);
	BOOL jiggleOnlyWhenIdle = [prefs jiggleOnlyWhenIdle];
	BOOL showIconWhenJiggling = [prefs showJigglerIconWhenJiggling];
	BOOL notOnBattery = [prefs notOnBattery];
	BOOL notWhenScreenLocked = [prefs notWhenScreenLocked];
	NSArray *frontAppNameComponents = [prefs frontAppNameComponents];
	BOOL notWithFrontAppsNamedX = ([prefs notWithFrontAppsNamedX] && [frontAppNameComponents count]);
	BOOL jiggleConditionsTested = NO;
	BOOL jiggleConditionsMet = NO;
	
	// Keep track of callouts, so we can skip operations on some callouts for lower CPU usage
	// Each callout is 0.25 seconds, so ((callout_counter & 0x0F) == 0) gives you every 4.0 seconds...
	callout_counter++;
	
	// If a mouse button is down, we don't jiggle; we don't want to interfere with dragging.  There are 32 buttons to check!
    // Similarly, short-circuit jiggling if we're on battery power only, if the user has chosen that pref.
	BOOL buttonDown = NO;
	
	for (int buttonIndex = 0; buttonIndex < 32; ++buttonIndex)
		if (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, buttonIndex))
			buttonDown = YES;
	
	if (buttonDown ||
		(notOnBattery && RunningOnBatteryOnly()) ||
		(notWithFrontAppsNamedX && [self checkRunningAppsForAppNameContaining:frontAppNameComponents mustBeDockApp:YES mustBeFront:YES]) ||
		(notWhenScreenLocked && ScreenIsLocked()))
	{
		if (jiggleOnlyWhenIdle)
			[self setJigglingActive:NO];
		return;
	}
	
	// If jiggling is active, check for user activity since our last jiggle
	if (jigglingActive)
	{
		if (!showIconWhenJiggling)
		{
			[self setJigglingActive:NO];
		}
		else
		{
			if (jiggleOnlyWhenIdle && (idleTime < 0.0))
				idleTime = JigglerIdleTime();
			
			if (jiggleOnlyWhenIdle && (idleTime < timeSinceLastJiggle - 0.4))   // the code below schedules mouse moves for up to 0.34 seconds beyond timeOfLastJiggle, so 0.4 gives us a little wiggle room
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
	}
	
#if 0
	if (YES)
	{
		if (idleTime < 0.0)
			idleTime = JigglerIdleTime();
			
		NSLog(@"JigglerIdleTime() == %f, jiggleSeconds == %f, timeSinceLastJiggle == %f", idleTime, jiggleSeconds, timeSinceLastJiggle);
	}
	else
		NSLog(@"jiggleSeconds == %f, timeSinceLastJiggle == %f", jiggleSeconds, timeSinceLastJiggle);
#endif
	
	if (timeSinceLastJiggle > jiggleSeconds)
	{
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
				
				// Bump the system activity timer, in case somebody is watching it.  Note that on 10.2.5 this does not
				// appear to properly reset NXIdleTime().  See #3362783.  This is fixed on 10.3.5, for me.
                // BCH 16 June 2013: This API is unofficially deprecated in favor of IOPMAssertionCreateWithName(), but
                // that API is more annoying to use because you have to do a start/end bracket.  Keeping this until
                // such time as it produces a compile error.
				// BCH 8 February 2015: UpdateSystemActivity() is officially deprecated beginning in 10.8.  I am going
				// to continue using it until it actually goes away.
				// BCH 19 May 2016: Added weak linking protection to this, just in case Apple actually removes it...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
				if (UpdateSystemActivity != NULL)
					UpdateSystemActivity(UsrActivity);
#pragma clang diagnostic pop
				
				// BCH 19 May 2016: Adding the new IOKit call IOPMAssertionDeclareUserActivity(), which appears to be equivalent
				// to UpdateSystemActivity(UsrActivity).  It may have slightly different effects, so I'm keeping the call to
				// UpdateSystemActivity(UsrActivity) above as well, just to try to ensure the most complete coverage possible.
				
				[self declareUserActivity];

				[timeOfLastJiggle release];
				timeOfLastJiggle = [[NSDate alloc] init];
				
				if (showIconWhenJiggling)
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
	[self jiggleMouse:nil];
	
	NSLog(@"iTunesChanged:");
}

- (void)applicationListChanged:(NSNotification *)note
{
	jiggleConditionsLikelyToHaveChanged = YES;
	
	// Bump our jiggle code for immediate action if appropriate
	[self jiggleMouse:nil];
	
	NSLog(@"applicationListChanged:");
}

- (void)mountedDevicesChanged:(NSNotification *)note
{
	jiggleConditionsLikelyToHaveChanged = YES;
	
	// Bump our jiggle code for immediate action if appropriate
	[self jiggleMouse:nil];
	
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
}


#pragma mark Timed Quit

- (void)_timedQuitTimer:(id)unused
{
	--minutesRemainingToTimedQuit;
	
	//[self fixAppIconForTimedQuit];
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
		
		//[self fixAppIconForTimedQuit];
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
		
		//[self fixAppIconForTimedQuit];
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




























