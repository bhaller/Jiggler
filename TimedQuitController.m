//
//  TimedQuitController.m
//  Jiggler
//
//  Created by Ben Haller on Wed Aug 25 2004.
//  Copyright (c) 2004 Stick Software. All rights reserved.
//

#import "TimedQuitController.h"
#import "CocoaExtra.h"


static NSString *TimedQuitHoursDefaultsKey = @"TimedQuitHours";
static NSString *TimedQuitMinutesDefaultsKey = @"TimedQuitMinutes";


@interface TimedQuitController (PrivateAPI)

- (int)runForMinutesUntilQuit;

@end


@implementation TimedQuitController

+ (int)runPanelForMinutesUntilQuit
{
	static TimedQuitController *sharedController;
	
	if (!sharedController)
		sharedController = [[TimedQuitController alloc] init];
	
	return [sharedController runForMinutesUntilQuit];
}

- (void)loadFromDefaults
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	hoursToQuit = [userDefaults integerForKey:TimedQuitHoursDefaultsKey];
	minutesToQuit = [userDefaults integerForKey:TimedQuitMinutesDefaultsKey];
	
	if (hoursToQuit < 0)
		hoursToQuit = 0;
	if (hoursToQuit > 99)
		hoursToQuit = 0;
	if (minutesToQuit < 0)
		minutesToQuit = 0;
	if (minutesToQuit > 59)
		minutesToQuit = 59;
	
	if ((hoursToQuit == 0) && (minutesToQuit == 0))
		hoursToQuit = 2;
}

- (void)saveToDefaults
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	[userDefaults setInteger:hoursToQuit forKey:TimedQuitHoursDefaultsKey];
	[userDefaults setInteger:minutesToQuit forKey:TimedQuitMinutesDefaultsKey];
}

- (id)init
{
	if (self = [super init])
	{
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		
		// Set up our default values
		[userDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:2], TimedQuitHoursDefaultsKey,
			[NSNumber numberWithInt:0], TimedQuitMinutesDefaultsKey,
			nil]];
		
		[self loadFromDefaults];
	}
	
	return self;
}

- (void)readValues
{
	hoursToQuit = [hoursTextfield intValue];
	minutesToQuit = [minutesTextfield intValue];
}

- (void)fixEnabling
{
	if ((hoursToQuit > 0) || (minutesToQuit > 0))
		[okButton setEnabled:YES];
	else
		[okButton setEnabled:NO];
}

- (void)prepareWindow
{
    if (!timedQuitPanel)
	{
		[[NSBundle mainBundle] loadNibNamed:@"TimedQuit" owner:self topLevelObjects:NULL];
		
		[timedQuitPanel retain];	// we own this panel, so we retain it; could make it a retain property instead, whatever
	}
	
    [hoursTextfield setIntValue:hoursToQuit];
	[minutesTextfield setIntValue:minutesToQuit];
	
	[self fixEnabling];
}

- (int)runForMinutesUntilQuit
{
	int resultCode;
	
	[self prepareWindow];
	
	[timedQuitPanel setInitialFirstResponder:hoursTextfield];
	[timedQuitPanel makeFirstResponder:hoursTextfield];
	[hoursTextfield selectText:nil];
	
	resultCode = [NSApp runModalForWindow:timedQuitPanel];
	[timedQuitPanel close];
	
	if (resultCode == NSAlertFirstButtonReturn)
	{
		[self readValues];
		[self saveToDefaults];
		
		return ((hoursToQuit * 60) + minutesToQuit);
	}
	
	return 0;
}

- (void)updateTextFieldFromState:(NSTextField *)textfield
{
	if (textfield == hoursTextfield)
		[textfield setIntValue:hoursToQuit];
	if (textfield == minutesTextfield)
		[textfield setIntValue:minutesToQuit];
	
	[textfield selectText:nil];
}

- (BOOL)checkString:(NSString *)string againstValue:(int)value
{
	NSString *checkString = [NSString stringWithFormat:@"%d", value];
	
	return [checkString isEqualToString:string];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	
	if (object == hoursTextfield)
	{
		//NSLog(@"controlTextDidChange: called for hoursTextfield");
		hoursToQuit = [hoursTextfield intValue];
		
		if ((hoursToQuit < 0) || (hoursToQuit > 99) || ![self checkString:[hoursTextfield stringValue] againstValue:hoursToQuit])
		{
			hoursToQuit = ((hoursToQuit <= 0) ? 0 : 99);
			[self performSelector:@selector(updateTextFieldFromState:) withObject:hoursTextfield afterDelay:0.0 inModes:[NSArray allRunLoopModes]];
			NSBeep();
		}
		
		[self fixEnabling];
	}
	if (object == minutesTextfield)
	{
		//NSLog(@"controlTextDidChange: called for minutesTextfield");
		minutesToQuit = [minutesTextfield intValue];
		
		if ((minutesToQuit < 0) || (minutesToQuit > 59) || ![self checkString:[minutesTextfield stringValue] againstValue:minutesToQuit])
		{
			minutesToQuit = ((minutesToQuit <= 0) ? 0 : 59);
			[self performSelector:@selector(updateTextFieldFromState:) withObject:minutesTextfield afterDelay:0.0 inModes:[NSArray allRunLoopModes]];
			NSBeep();
		}
		
		[self fixEnabling];
	}
}

- (IBAction)okClicked:(id)sender
{
	[NSApp stopModalWithCode:NSAlertFirstButtonReturn];
}

- (IBAction)cancelClicked:(id)sender
{
	[NSApp stopModalWithCode:NSAlertSecondButtonReturn];
}

@end
