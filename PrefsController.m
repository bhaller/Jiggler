//
//  PrefsController.m
//  PhotoReviewer
//
//  Created by Ben Haller on Wed Jul 23 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import "PrefsController.h"
#import "CocoaExtra.h"
#import "AppDelegate.h"


// User defaults keys
static NSString *JiggleTimeDefaultsKey = @"JiggleTime";							// version 1.3 and before: -1 = 20 secs, 0 = 40 secs, >=1 is number of minutes
static NSString *JiggleSecondsDefaultsKey = @"JiggleSeconds";					// version 1.4 and later: the actual number of seconds between jiggles (minimum 5)
static NSString *ShowIconWhenJigglingDefaultsKey = @"ShowIconWhenJiggling";
static NSString *JiggleOnlyWhenIdleDefaultsKey = @"JiggleOnlyWhenIdle";
static NSString *ZenJiggleDefaultsKey = @"ZenJiggle";

static NSString *OnlyWithCPUUsageDefaultsKey = @"OnlyWithCPUUsage";
static NSString *CPUUsageThresholdDefaultsKey = @"CPUUsageThreshold";
static NSString *OnlyWithRemovableWritableDisksDefaultsKey = @"OnlyWithRemovableWritableDisks";
static NSString *OnlyWithITunesPlayingDefaultsKey = @"OnlyWithITunesPlaying";
static NSString *OnlyWithApplicationsNamedXDefaultsKey = @"OnlyWithApplicationsNamedX";
static NSString *OnlyWithIdentityDefaultsKey = @"OnlyWithIdentity";
static NSString *ApplicationNameComponentDefaultsKey = @"ApplicationNameComponent";
static NSString *NotOnBatteryDefaultsKey = @"NotOnBattery";
static NSString *NotWithFrontAppsNamedXDefaultsKey = @"NotWithFrontAppsNamedX";
static NSString *FrontAppNameComponentDefaultsKey = @"FrontAppNameComponent";
static NSString *NotWithWifiBssidDefaultKey=@"NotWhenWifiBssid";
static NSString *WifiBssidNameDefaultKey=@"WifiBssidComponent";


@implementation PrefsController

static PrefsController *sharedPrefsController = nil;

+ (PrefsController *)sharedPrefsController
{
	if (!sharedPrefsController)
		[[[PrefsController alloc] init] autorelease];
	
	return sharedPrefsController;
}

- (id)init
{
	if (sharedPrefsController == nil)
	{
		if (self = [super init])
		{
			NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
			
			// Set up our default values; should probably be in +initialize, but this gets called right away anyway...
			[userDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithInt:5], JiggleTimeDefaultsKey,						// use the old key as a minimum time value
                                            [NSNumber numberWithInt:-1], JiggleSecondsDefaultsKey,					// use -1 as a flag value for "no value set for the new key"
                                            @"YES", ShowIconWhenJigglingDefaultsKey,
											@"YES", JiggleOnlyWhenIdleDefaultsKey,
											
											@"NO", ZenJiggleDefaultsKey,
                                            
                                            @"NO", OnlyWithCPUUsageDefaultsKey,
                                            [NSNumber numberWithInt:20], CPUUsageThresholdDefaultsKey,
                                            
                                            @"NO", OnlyWithRemovableWritableDisksDefaultsKey,
                                            
                                            @"NO", OnlyWithITunesPlayingDefaultsKey,
                                            
                                            @"NO", OnlyWithApplicationsNamedXDefaultsKey,
                                            [NSNumber numberWithInt:0], OnlyWithIdentityDefaultsKey,
                                            @"", ApplicationNameComponentDefaultsKey,
                                            
                                            @"NO", NotOnBatteryDefaultsKey,
                                            
                                            @"NO", NotWithFrontAppsNamedXDefaultsKey,
                                            @"", FrontAppNameComponentDefaultsKey,
                                            
                                            @"NO", NotWithWifiBssidDefaultKey,
                                            @"", WifiBssidNameDefaultKey,
											
											[NSNumber numberWithBool:YES], @"NSAppSleepDisabled",	// completely disable App Nap; we want to always be live, that's kind of the point
                                            
                                            nil]];
			
			// Read our de facto values into our caches
			jiggleSeconds = [userDefaults integerForKey:JiggleSecondsDefaultsKey];
			
			if (jiggleSeconds < 0)
			{
				int jiggleTime;		// old defaults key: -1 is 20 seconds, 0 is 40 seconds, positive integers are a number of minutes
				
				jiggleTime = [userDefaults integerForKey:JiggleTimeDefaultsKey];
				
				if (jiggleTime == -1)
					jiggleSeconds = 20;
				else if (jiggleTime == 0)
					jiggleSeconds = 40;
				else
					jiggleSeconds = jiggleTime * 60;
			}
			
			if (jiggleSeconds < 5)
				jiggleSeconds = 5;
			if (jiggleSeconds > 60 * 60 * 24)
				jiggleSeconds = 60 * 60 * 24;
			
			showJigglerIconWhenJiggling = [userDefaults boolForKey:ShowIconWhenJigglingDefaultsKey];
			jiggleOnlyWhenIdle = [userDefaults boolForKey:JiggleOnlyWhenIdleDefaultsKey];
			
			zenJiggle = [userDefaults boolForKey:ZenJiggleDefaultsKey];

			onlyWithCPUUsage = [userDefaults boolForKey:OnlyWithCPUUsageDefaultsKey];
            cpuUsageThreshold = [userDefaults integerForKey:CPUUsageThresholdDefaultsKey];
            
			onlyWithRemovableWritableDisks = [userDefaults boolForKey:OnlyWithRemovableWritableDisksDefaultsKey];
            
			onlyWithITunesPlaying = [userDefaults boolForKey:OnlyWithITunesPlayingDefaultsKey];
            
			onlyWithApplicationsNamedX = [userDefaults boolForKey:OnlyWithApplicationsNamedXDefaultsKey];
            onlyWithIdentityTag = [userDefaults integerForKey:OnlyWithIdentityDefaultsKey];
			applicationNameComponent = [[userDefaults stringForKey:ApplicationNameComponentDefaultsKey] retain];
			[applicationNameComponents release];
			applicationNameComponents = nil;
            
			notOnBattery = [userDefaults boolForKey:NotOnBatteryDefaultsKey];
            
			notWithFrontAppsNamedX = [userDefaults boolForKey:NotWithFrontAppsNamedXDefaultsKey];
			frontAppNameComponent = [[userDefaults stringForKey:FrontAppNameComponentDefaultsKey] retain];
			[frontAppNameComponents release];
			frontAppNameComponents = nil;
            
            notWhenWifiBssid = [userDefaults boolForKey:NotWithWifiBssidDefaultKey];
            wifiBssid = [[userDefaults stringForKey:WifiBssidNameDefaultKey] retain];
            [wifiBssids release];
            wifiBssids = nil;
		}
		
		sharedPrefsController = [self retain];
	}
	else
	{
		[self dealloc];
	}
	
	return sharedPrefsController;
}

- (void)setJiggleTimeTextfieldString
{
	if (jiggleSeconds < 60)
		[jiggleTimeTextfield setStringValue:[NSString stringWithFormat:@"(Set to %d seconds)", jiggleSeconds]];
	else if (jiggleSeconds == 60)
		[jiggleTimeTextfield setStringValue:@"(Set to 1 minute)"];
	else if (jiggleSeconds < 60 * 60)
		[jiggleTimeTextfield setStringValue:[NSString stringWithFormat:@"(Set to %.1f minutes)", jiggleSeconds / 60.0]];
	else if (jiggleSeconds == 60 * 60)
		[jiggleTimeTextfield setStringValue:@"(Set to 1 hour)"];
	else
		[jiggleTimeTextfield setStringValue:[NSString stringWithFormat:@"(Set to %.1f hours)", jiggleSeconds / (60.0 * 60.0)]];
}

- (void)showWindow
{
    if (!preferencesWindow)
	{
		[[NSBundle mainBundle] loadNibNamed:@"Preferences" owner:self topLevelObjects:NULL];
		
		[preferencesWindow retain];		// we own this panel, so we retain it; could make it a retain property instead, whatever
		
		// We want command-W to close us, but we have no File menu, so we use a transparent button to make it work
		[invisibleCloseButton setTransparent:YES];
		
		// Set up our launch on login checkbox, which is not backed by a pref kept by us
		[launchOnLoginCheckbox setState:([self launchOnLogin] ? NSOnState : NSOffState)];
		
		// Set the jiggle time slider.  It has values from 0 to 5, with ticks at each integer, for 5 secs, 1 min, 5 min, 1 hour, 5 hours, and 24 hours.
		// We treat each segment of that slider range as an independent linear scale, so it's a bit complicated...
		if (jiggleSeconds < 60)
			[jiggleTimeSlider setFloatValue:(jiggleSeconds - 5) / (60.0 - 5.0)];													// 5 seconds to 60 seconds
		else if (jiggleSeconds < 60 * 5)
			[jiggleTimeSlider setFloatValue:(jiggleSeconds - 60) / (60.0 * 5.0 - 60.0) + 1.0];										// 1 minute to 5 minutes
		else if (jiggleSeconds < 60 * 60)
			[jiggleTimeSlider setFloatValue:(jiggleSeconds - 60 * 5) / (60.0 * 60.0 - 60.0 * 5) + 2.0];								// 5 minutes to 1 hour
		else if (jiggleSeconds < 60 * 60 * 5)
			[jiggleTimeSlider setFloatValue:(jiggleSeconds - 60 * 60) / (60.0 * 60.0 * 5.0 - 60.0 * 60.0) + 3.0];					// 1 hour to 5 hours
		else
			[jiggleTimeSlider setFloatValue:(jiggleSeconds - 60 * 60 * 5.0) / (60.0 * 60.0 * 24.0 - 60.0 * 60.0 * 5.0) + 4.0];		// 5 hours to 24 hours
		
		// Set other control states
		[self setJiggleTimeTextfieldString];
		[showJigglerIconWhenJigglingButton setState:showJigglerIconWhenJiggling];
		[jiggleOnlyWhenIdleRadio selectCellWithTag:(jiggleOnlyWhenIdle ? 1 : 0)];
		
		[zenJiggleCheckbox setState:zenJiggle];
		
		[onlyWithCPUUsageCheckbox setState:onlyWithCPUUsage];
        [cpuUsageSlider setEnabled:onlyWithCPUUsage];
		[cpuUsageSlider setIntValue:cpuUsageThreshold];
		[cpuUsageTextfield setStringValue:[NSString stringWithFormat:@"%d%%", cpuUsageThreshold]];
		
		[onlyWithRemovableWritableDisksCheckbox setState:onlyWithRemovableWritableDisks];
        
		[onlyWithITunesPlayingCheckbox setState:onlyWithITunesPlaying];
        
		[onlyWithApplicationsNamedXCheckbox setState:(onlyWithApplicationsNamedX && [applicationNameComponent length])];
        [onlyWithIdentityPopUp selectItemWithTag:onlyWithIdentityTag];
        [onlyWithIdentityPopUp setEnabled:onlyWithApplicationsNamedX];
		[applicationNameComponentTextfield setStringValue:applicationNameComponent];
        [applicationNameComponentTextfield setEnabled:onlyWithApplicationsNamedX];
        
		[notOnBatteryCheckbox setState:notOnBattery];
        
		[notWithFrontAppsNamedXCheckbox setState:(notWithFrontAppsNamedX && [frontAppNameComponent length])];
		[frontAppsNameComponentTextfield setStringValue:frontAppNameComponent];
        [frontAppsNameComponentTextfield setEnabled:notWithFrontAppsNamedX];
        
        [notWhenWifiBssidCheckbox setState:(notWhenWifiBssid && [wifiBssid length])];
        [wifiBssidTextField setStringValue:wifiBssid];
        [wifiBssidTextField setEnabled:notWhenWifiBssid];
        
		[preferencesWindow centerOnPrimaryScreen];
		[preferencesWindow setReleasedWhenClosed:NO];
	}
	
	[NSApp activateIgnoringOtherApps:YES];
    [preferencesWindow makeKeyAndOrderFront:nil];
	[preferencesWindow makeFirstResponder:preferencesWindow];
}

- (void)closeWindow
{
	[preferencesWindow close];
}

- (int)jiggleSeconds
{
	return jiggleSeconds;
}

- (BOOL)showJigglerIconWhenJiggling
{
	return showJigglerIconWhenJiggling;
}

- (BOOL)jiggleOnlyWhenIdle
{
	return jiggleOnlyWhenIdle;
}

- (BOOL)zenJiggle
{
	return zenJiggle;
}

- (BOOL)onlyWithCPUUsage
{
	return onlyWithCPUUsage;
}

- (int)cpuUsageThreshold
{
    return cpuUsageThreshold;
}

- (BOOL)onlyWithRemovableWritableDisks
{
	return onlyWithRemovableWritableDisks;
}

- (BOOL)onlyWithITunesPlaying
{
	return onlyWithITunesPlaying;
}

- (BOOL)onlyWithApplicationsNamedX
{
	return onlyWithApplicationsNamedX;
}

- (int)onlyWithIdentityTag
{
    return onlyWithIdentityTag;
}

- (NSArray *)applicationNameComponents
{
	if (!applicationNameComponents && [applicationNameComponent length])
	{
		NSMutableArray *newAppNameComponents = [[NSMutableArray alloc] init];
		NSArray *uncorrectedComponents = [applicationNameComponent componentsSeparatedByString:@","];
		NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\""];
		int i, c;
		
		for (i = 0, c = [uncorrectedComponents count]; i < c; ++i)
		{
			NSString *uncorrectedComponent = [uncorrectedComponents objectAtIndex:i];
			NSString *correctedString = [uncorrectedComponent stringByTrimmingCharactersInSet:trimSet];
			
			if ([correctedString length])
				[newAppNameComponents addObject:correctedString];
		}
		
		applicationNameComponents = (NSArray *)newAppNameComponents;
	}
	
	return applicationNameComponents;
}

- (BOOL)notOnBattery
{
	return notOnBattery;
}

- (BOOL)notWithFrontAppsNamedX
{
	return notWithFrontAppsNamedX;
}

- (NSArray *)frontAppNameComponents
{
	if (!frontAppNameComponents && [frontAppNameComponent length])
	{
		NSMutableArray *newAppNameComponents = [[NSMutableArray alloc] init];
		NSArray *uncorrectedComponents = [frontAppNameComponent componentsSeparatedByString:@","];
		NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\""];
		int i, c;
		
		for (i = 0, c = [uncorrectedComponents count]; i < c; ++i)
		{
			NSString *uncorrectedComponent = [uncorrectedComponents objectAtIndex:i];
			NSString *correctedString = [uncorrectedComponent stringByTrimmingCharactersInSet:trimSet];
			
			if ([correctedString length])
				[newAppNameComponents addObject:correctedString];
		}
		
		frontAppNameComponents = (NSArray *)newAppNameComponents;
	}
	
	return frontAppNameComponents;
}

- (NSArray *)wifiBssids
{
    if(!wifiBssids && [wifiBssid length]) {
        NSMutableArray *newWifiBssidComponents = [[NSMutableArray alloc] init];
        NSArray *uncorrectedComponents = [wifiBssid componentsSeparatedByString:@","];
        NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\""];
        int i, c;
        for(i=0, c=[uncorrectedComponents count]; i< c; ++i) {
            NSString *uncorrectedComponent = [uncorrectedComponents objectAtIndex:i];
            NSString *correctedString = [uncorrectedComponent stringByTrimmingCharactersInSet:trimSet];
            if ([correctedString length]) {
                [newWifiBssidComponents addObject:correctedString];
            }
        }
        
        wifiBssids = (NSArray *)newWifiBssidComponents;
    }
    return wifiBssids;
}

- (IBAction)jiggleTimeChanged:(id)sender
{
	float newValue = [sender floatValue];
	int newSeconds;
	
	if (fabs(round(newValue) - newValue) < 0.006)
		newValue = round(newValue);
	
	if (newValue < 1.0)
		newSeconds = round((newValue - 0.0) * 55.0 + 5.0);										// 0 to 1   ->   5 seconds to 60 seconds
	else if (newValue < 2.0)
		newSeconds = round((newValue - 1.0) * 60.0 * 4.0 + 60.0);								// 1 to 2   ->   1 minute to 5 minutes
	else if (newValue < 3.0)
		newSeconds = round((newValue - 2.0) * 60.0 * 55.0 + 60.0 * 5.0);						// 2 to 3   ->   5 minutes to 60 minutes
	else if (newValue < 4.0)
		newSeconds = round((newValue - 3.0) * 60.0 * 60.0 * 4.0 + 60.0 * 60.0);					// 3 to 4   ->   1 hour to 5 hours
	else
		newSeconds = round((newValue - 4.0) * 60.0 * 60.0 * 19.0 + 60.0 * 60.0 * 5.0);			// 4 to 5   ->   5 hours to 24 hours
	
	if (newSeconds != jiggleSeconds)
	{
		jiggleSeconds = newSeconds;
		[[NSUserDefaults standardUserDefaults] setInteger:jiggleSeconds forKey:JiggleSecondsDefaultsKey];
		
		[self setJiggleTimeTextfieldString];
	}
}

- (IBAction)showJigglerIconWhenJigglingChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != showJigglerIconWhenJiggling)
	{
		showJigglerIconWhenJiggling = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:ShowIconWhenJigglingDefaultsKey];
	}
}

- (IBAction)jiggleOnlyWhenIdleChanged:(id)sender
{
	BOOL newState = ([[sender selectedCell] tag] ? YES : NO);
	
	if (newState != jiggleOnlyWhenIdle)
	{
		jiggleOnlyWhenIdle = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:JiggleOnlyWhenIdleDefaultsKey];
	}
}

- (IBAction)zenJiggleChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != zenJiggle)
	{
		zenJiggle = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:ZenJiggleDefaultsKey];
	}
}

- (IBAction)onlyWithCPUUsageChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != onlyWithCPUUsage)
	{
		onlyWithCPUUsage = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:OnlyWithCPUUsageDefaultsKey];
        
        [cpuUsageSlider setEnabled:onlyWithCPUUsage];
	}
}

- (IBAction)cpuUsageSliderChanged:(id)sender
{
    int newValue = [cpuUsageSlider intValue];
    
    if (newValue != cpuUsageThreshold)
    {
        cpuUsageThreshold = newValue;
		[[NSUserDefaults standardUserDefaults] setInteger:newValue forKey:CPUUsageThresholdDefaultsKey];
        
        [cpuUsageTextfield setStringValue:[NSString stringWithFormat:@"%d%%", newValue]];
    }
}

- (IBAction)onlyWithRemovableWritableDisksChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != onlyWithRemovableWritableDisks)
	{
		onlyWithRemovableWritableDisks = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:OnlyWithRemovableWritableDisksDefaultsKey];
	}
}

- (IBAction)onlyWithITunesPlayingChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != onlyWithITunesPlaying)
	{
		onlyWithITunesPlaying = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:OnlyWithITunesPlayingDefaultsKey];
	}
}

- (IBAction)onlyWithApplicationsNamedXChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != onlyWithApplicationsNamedX)
	{
		onlyWithApplicationsNamedX = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:OnlyWithApplicationsNamedXDefaultsKey];
		
        [onlyWithIdentityPopUp setEnabled:onlyWithApplicationsNamedX];
        [applicationNameComponentTextfield setEnabled:onlyWithApplicationsNamedX];
        
		if (onlyWithApplicationsNamedX)
		{
			[applicationNameComponentTextfield selectText:nil];
			[preferencesWindow makeFirstResponder:applicationNameComponentTextfield];
		}
	}
}

- (IBAction)onlyWithIdentityPopUpChanged:(id)sender
{
	int newTag = [[onlyWithIdentityPopUp selectedItem] tag];
	
	if (newTag != onlyWithIdentityTag)
	{
		onlyWithIdentityTag = newTag;
		[[NSUserDefaults standardUserDefaults] setInteger:newTag forKey:OnlyWithIdentityDefaultsKey];
	}
}

- (IBAction)onlyWithFrontAppsNamedXChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != notWithFrontAppsNamedX)
	{
		notWithFrontAppsNamedX = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:NotWithFrontAppsNamedXDefaultsKey];
		
        [frontAppsNameComponentTextfield setEnabled:notWithFrontAppsNamedX];
        
		if (notWithFrontAppsNamedX)
		{
			[frontAppsNameComponentTextfield selectText:nil];
			[preferencesWindow makeFirstResponder:frontAppsNameComponentTextfield];
		}
	}
}

- (IBAction)onlyWhenWifiIsConnectedChanged:(id)sender {
    BOOL newState = [sender state];
    
    if (newState != notWhenWifiBssid)
    {
        notWhenWifiBssid = newState;
        [[NSUserDefaults standardUserDefaults] setBool:newState forKey:NotWithWifiBssidDefaultKey];
        
        [wifiBssidTextField setEnabled:notWhenWifiBssid];
        
        if (notWhenWifiBssid)
        {
            [wifiBssidTextField selectText:nil];
            [preferencesWindow makeFirstResponder:wifiBssidTextField];
        }
    }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	
	if (object == applicationNameComponentTextfield)
	{
		[applicationNameComponent release];
		applicationNameComponent = [[applicationNameComponentTextfield stringValue] retain];
		[applicationNameComponents release];
		applicationNameComponents = nil;
		
		[[NSUserDefaults standardUserDefaults] setObject:applicationNameComponent forKey:ApplicationNameComponentDefaultsKey];
	}
	if (object == frontAppsNameComponentTextfield)
	{
		[frontAppNameComponent release];
		frontAppNameComponent = [[frontAppsNameComponentTextfield stringValue] retain];
		[frontAppNameComponents release];
		frontAppNameComponents = nil;
		
		[[NSUserDefaults standardUserDefaults] setObject:frontAppNameComponent forKey:FrontAppNameComponentDefaultsKey];
	}
    if(object == wifiBssidTextField) {
        [wifiBssid release];
        wifiBssid = [[wifiBssidTextField stringValue] retain];
        [wifiBssids release];
        wifiBssids = nil;
        
        [[NSUserDefaults standardUserDefaults] setObject:wifiBssid forKey:WifiBssidNameDefaultKey];
    }
}

- (IBAction)notOnBatteryChanged:(id)sender
{
	BOOL newState = [sender state];
	
	if (newState != notOnBattery)
	{
		notOnBattery = newState;
		[[NSUserDefaults standardUserDefaults] setBool:newState forKey:NotOnBatteryDefaultsKey];
	}
}

#pragma Launch on Login

// This code courtesy of Catalin Stan at http://stackoverflow.com/questions/23625255/how-can-i-make-program-automatically-startup-on-login
// Note that it would not work with sandboxing, and would likely have problems on the Mac App Store.

- (BOOL)launchOnLogin 
{
	BOOL loginItemFound = FALSE;
	LSSharedFileListRef loginItemsListRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	if (loginItemsListRef)
	{
		CFArrayRef snapshotRef = LSSharedFileListCopySnapshot(loginItemsListRef, NULL);
		NSArray *loginItems = [NSMakeCollectable(snapshotRef) autorelease];
		NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
		
		for (id item in loginItems)
		{
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
			CFURLRef itemURLRef = LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL);
			NSURL *itemURL = (NSURL *)[(id)itemURLRef autorelease];
			
			if ([itemURL isEqual:bundleURL])
			{
				loginItemFound = YES;
				break;
			}
		}
		
		CFRelease(loginItemsListRef);
	}
	
	return loginItemFound;
}

- (void)setLaunchOnLogin:(BOOL)launchOnLogin
{
	LSSharedFileListRef loginItemsListRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	if (loginItemsListRef)
	{
		NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
		
		if (launchOnLogin)
		{
			NSDictionary *properties = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"com.apple.loginitem.HideOnLaunch"];
			LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsListRef, kLSSharedFileListItemLast, NULL, NULL, (CFURLRef)bundleURL, (CFDictionaryRef)properties,NULL);
			if (itemRef)
				CFRelease(itemRef);
		}
		else
		{
			CFArrayRef snapshotRef = LSSharedFileListCopySnapshot(loginItemsListRef, NULL);
			NSArray *loginItems = [(id)snapshotRef autorelease];
			
			for (id item in loginItems)
			{
				LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
				CFURLRef itemURLRef = LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL);
				NSURL *itemURL = (NSURL *)[(id)itemURLRef autorelease];
				
				if ([itemURL isEqual:bundleURL])
					LSSharedFileListItemRemove(loginItemsListRef, itemRef);
			}
		}
		
		CFRelease(loginItemsListRef);
	}
}

- (IBAction)launchOnLoginChanged:(id)sender
{
	BOOL newState = [sender state];
	
	[self setLaunchOnLogin:newState];
}

@end

































