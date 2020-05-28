//
//  SSPanels.h
//  Stick Software subsystem
//
//  Created by Ben Haller on Wed May 22 2002.
//  Copyright (c) 2002 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSWindow (SSPanelCreation)

// These methods are the simplest way to run the standard panels
+ (void)runStandardSSAboutPanelWithURLDictionary:(NSDictionary *)urlDict hideOnDeactivate:(BOOL)hideOnDeactivate;

// These should generally not be used; the functions above will determine the best values for most of these parameters
+ (NSWindow *)standardSSAboutPanelForAppName:(NSString *)appName versionString:(NSString *)versionString icon:(NSImage *)iconImage urlDictionary:(NSDictionary *)urlDict hideOnDeactivate:(BOOL)hideFlag;

@end
