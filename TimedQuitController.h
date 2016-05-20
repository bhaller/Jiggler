//
//  TimedQuitController.h
//  Jiggler
//
//  Created by Ben Haller on Wed Aug 25 2004.
//  Copyright (c) 2004 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TimedQuitController : NSObject
{
    IBOutlet NSPanel *timedQuitPanel;

    IBOutlet NSTextField *hoursTextfield;
    IBOutlet NSTextField *minutesTextfield;
	
    IBOutlet NSButton *okButton;
	
	int hoursToQuit, minutesToQuit;
}

+ (int)runPanelForMinutesUntilQuit;

- (IBAction)cancelClicked:(id)sender;
- (IBAction)okClicked:(id)sender;

@end
