//
//  PrefsController.h
//  Jiggler
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
	
	IBOutlet NSMatrix *jiggleStyleRadio;
    IBOutlet NSSlider *jiggleDistanceSlider;
	
	IBOutlet NSButton *onlyWithCPUUsageCheckbox;
    IBOutlet NSSlider *cpuUsageSlider;
    IBOutlet NSTextField *cpuUsageTextfield;
    
	IBOutlet NSButton *onlyWithRemovableWritableDisksCheckbox;
    
	IBOutlet NSButton *onlyWithITunesPlayingCheckbox;
    
	IBOutlet NSButton *onlyWithApplicationsNamedXCheckbox;
    IBOutlet NSPopUpButton *onlyWithIdentityPopUp;
	IBOutlet NSTextField *applicationNameComponentTextfield;
    
    IBOutlet NSButton *notWhenScreenLockedCheckbox;
	
    IBOutlet NSButton *notOnBatteryCheckbox;

    IBOutlet NSButton *notWithFrontAppsNamedXCheckbox;
	IBOutlet NSTextField *frontAppsNameComponentTextfield;

	// Cached values
	int jiggleSeconds;
	BOOL showJigglerIconWhenJiggling;
	BOOL jiggleOnlyWhenIdle;
	
	int jiggleStyle;
	float jiggleDistance;	// 0 to 20; returned to the client transformed, jiggleDistance * jiggleDistance + 10
	
	BOOL onlyWithCPUUsage;
    int cpuUsageThreshold;
    
    BOOL onlyWithRemovableWritableDisks;
    
    BOOL onlyWithITunesPlaying;
    
    BOOL onlyWithApplicationsNamedX;
    int onlyWithIdentityTag;
	NSString *applicationNameComponent;
	NSArray *applicationNameComponents;
    
    BOOL notWhenScreenLocked;
	
    BOOL notOnBattery;
    
    BOOL notWithFrontAppsNamedX;
	NSString *frontAppNameComponent;
	NSArray *frontAppNameComponents;
}

+ (PrefsController *)sharedPrefsController;

- (void)showWindow;
- (void)closeWindow;

// API for getting specific prefs values
- (int)jiggleSeconds;
- (BOOL)showJigglerIconWhenJiggling;
- (BOOL)jiggleOnlyWhenIdle;

- (int)jiggleStyle;							// 0 == standard, 1 == "Zen", 2 == "click jiggle"
- (int)jiggleDistance;

- (BOOL)onlyWithCPUUsage;
- (int)cpuUsageThreshold;

- (BOOL)onlyWithRemovableWritableDisks;

- (BOOL)onlyWithITunesPlaying;

- (BOOL)onlyWithApplicationsNamedX;
- (int)onlyWithIdentityTag;                 // 0 == app, 1 == process
- (NSArray *)applicationNameComponents;

- (BOOL)notWhenScreenLocked;

- (BOOL)notOnBattery;

- (BOOL)notWithFrontAppsNamedX;
- (NSArray *)frontAppNameComponents;

// Actions and internals
- (IBAction)jiggleTimeChanged:(id)sender;
- (IBAction)showJigglerIconWhenJigglingChanged:(id)sender;
- (IBAction)jiggleOnlyWhenIdleChanged:(id)sender;

- (IBAction)jiggleStyleChanged:(id)sender;
- (IBAction)jiggleDistanceSliderChanged:(id)sender;

- (IBAction)onlyWithCPUUsageChanged:(id)sender;
- (IBAction)cpuUsageSliderChanged:(id)sender;

- (IBAction)onlyWithRemovableWritableDisksChanged:(id)sender;

- (IBAction)onlyWithITunesPlayingChanged:(id)sender;

- (IBAction)onlyWithIdentityPopUpChanged:(id)sender;
- (IBAction)onlyWithApplicationsNamedXChanged:(id)sender;

- (IBAction)notWhenScreenLockedChanged:(id)sender;

- (IBAction)notOnBatteryChanged:(id)sender;

- (IBAction)onlyWithFrontAppsNamedXChanged:(id)sender;

// Launch on Login
- (BOOL)launchOnLogin;
- (void)setLaunchOnLogin:(BOOL)launchOnLogin;

- (IBAction)launchOnLoginChanged:(id)sender;

@end


























