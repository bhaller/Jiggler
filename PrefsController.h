//
//  PrefsController.h
//  PhotoReviewer
//
//  Created by Ben Haller on Wed Jul 23 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PrefsController : NSObject
{
	// Outlets from Preferences.nib
    IBOutlet NSPanel *preferencesWindow;
	
	IBOutlet NSButton *invisibleCloseButton;
	
	IBOutlet NSButton *launchOnLoginCheckbox;
	
	IBOutlet NSSlider *jiggleTimeSlider;
	IBOutlet NSTextField *jiggleTimeTextfield;
	IBOutlet NSButton *showJigglerIconWhenJigglingButton;
	IBOutlet NSMatrix *jiggleOnlyWhenIdleRadio;
	
	IBOutlet NSButton *zenJiggleCheckbox;
	
	IBOutlet NSButton *onlyWithCPUUsageCheckbox;
    IBOutlet NSSlider *cpuUsageSlider;
    IBOutlet NSTextField *cpuUsageTextfield;
    
	IBOutlet NSButton *onlyWithRemovableWritableDisksCheckbox;
    
	IBOutlet NSButton *onlyWithITunesPlayingCheckbox;
    
	IBOutlet NSButton *onlyWithApplicationsNamedXCheckbox;
    IBOutlet NSPopUpButton *onlyWithIdentityPopUp;
	IBOutlet NSTextField *applicationNameComponentTextfield;
    
    IBOutlet NSButton *notOnBatteryCheckbox;

    IBOutlet NSButton *notWithFrontAppsNamedXCheckbox;
	IBOutlet NSTextField *frontAppsNameComponentTextfield;

    
    IBOutlet NSButton *notWhenWifiBssidCheckbox;
    IBOutlet NSTextField *wifiBssidTextField;
    
	// Cached values
	int jiggleSeconds;
	BOOL showJigglerIconWhenJiggling;
	BOOL jiggleOnlyWhenIdle;
	
	BOOL zenJiggle;
	
	BOOL onlyWithCPUUsage;
    int cpuUsageThreshold;
    
    BOOL onlyWithRemovableWritableDisks;
    
    BOOL onlyWithITunesPlaying;
    
    BOOL onlyWithApplicationsNamedX;
    int onlyWithIdentityTag;
	NSString *applicationNameComponent;
	NSArray *applicationNameComponents;
    
    BOOL notOnBattery;
    
    BOOL notWithFrontAppsNamedX;
	NSString *frontAppNameComponent;
	NSArray *frontAppNameComponents;
    
    BOOL notWhenWifiBssid;
    NSString *wifiBssid;
    NSArray *wifiBssids;
}

+ (PrefsController *)sharedPrefsController;

- (void)showWindow;
- (void)closeWindow;

// API for getting specific prefs values
- (int)jiggleSeconds;
- (BOOL)showJigglerIconWhenJiggling;
- (BOOL)jiggleOnlyWhenIdle;

- (BOOL)zenJiggle;

- (BOOL)onlyWithCPUUsage;
- (int)cpuUsageThreshold;

- (BOOL)onlyWithRemovableWritableDisks;

- (BOOL)onlyWithITunesPlaying;

- (BOOL)onlyWithApplicationsNamedX;
- (int)onlyWithIdentityTag;                 // 0 == app, 1 == process
- (NSArray *)applicationNameComponents;

- (BOOL)notOnBattery;

- (BOOL)notWithFrontAppsNamedX;
- (NSArray *)frontAppNameComponents;
- (NSArray *)wifiBssids;

// Actions and internals
- (IBAction)jiggleTimeChanged:(id)sender;
- (IBAction)showJigglerIconWhenJigglingChanged:(id)sender;
- (IBAction)jiggleOnlyWhenIdleChanged:(id)sender;

- (IBAction)zenJiggleChanged:(id)sender;

- (IBAction)onlyWithCPUUsageChanged:(id)sender;
- (IBAction)cpuUsageSliderChanged:(id)sender;

- (IBAction)onlyWithRemovableWritableDisksChanged:(id)sender;

- (IBAction)onlyWithITunesPlayingChanged:(id)sender;

- (IBAction)onlyWithIdentityPopUpChanged:(id)sender;
- (IBAction)onlyWithApplicationsNamedXChanged:(id)sender;

- (IBAction)notOnBatteryChanged:(id)sender;

- (IBAction)onlyWithFrontAppsNamedXChanged:(id)sender;

- (IBAction)onlyWhenWifiIsConnectedChanged:(id)sender;

// Launch on Login
- (BOOL)launchOnLogin;
- (void)setLaunchOnLogin:(BOOL)launchOnLogin;

- (IBAction)launchOnLoginChanged:(id)sender;

@end


























