//
//  CocoaExtra.h
//  Trisection
//
//  Created by bhaller on Thu May 17 2001.
//  Copyright (c) 2001 Ben Haller. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import <QuickTime/Movies.h>

#if 0
// Short-circuit to NSLocalizedString, passing nil for the comment so we don't inflate our binary
#define SSLocalizedString(key, comment) NSLocalizedString(key, nil)
#define SSLocalizedStringFromTable(key, table, comment) NSLocalizedStringFromTable(key, table, nil)
#else
// Test and log if a given key is not correctly defined
#define SSLocalizedString(key, comment) SSTestLocalizedString(key)
#define SSLocalizedStringFromTable(key, table, comment) SSTestLocalizedStringFromTable(key, table)

NSString *SSTestLocalizedString(NSString *key);
NSString *SSTestLocalizedStringFromTable(NSString *key, NSString *table);
#endif

static inline SInt32 StSRandomIntBetween(SInt32 start, SInt32 end) { return (SInt32)((random() % (end - start + 1)) + start); }

@interface NSTextView (SSCocoaExtra)

- (void)fixText:(NSString *)text toGoToLink:(NSString *)url;

@end

@interface NSTextField (SSCocoaExtra)

- (void)fixText:(NSString *)text toGoToLink:(NSString *)url;

@end

@interface WhiteView : NSView
@end

@interface BlueView : NSView
@end

NSModalResponse SSRunAlertPanel(NSString *title, NSString *msg, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...);
NSModalResponse SSRunInformationalAlertPanel(NSString *title, NSString *msg, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...);
NSModalResponse SSRunCriticalAlertPanel(NSString *title, NSString *msg, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...);

@interface NSScreen (SSScreens)

+ (NSScreen *)primaryScreen;

@end

@interface NSWindow (SSWindowCentering)

- (void)centerOnPrimaryScreen;

@end

@interface NSArray (SSRunLoopExtra)

+ (NSArray *)allRunLoopModes;		// default, modal panel, and event tracking
+ (NSArray *)standardRunLoopModes;	// default and modal panel

@end

@interface NSApplication (SSApplicationIcon)

- (NSImage *)SSApplicationIconScaledToSize:(NSSize)finalSize;

@end


// Front end to power management...
BOOL RunningOnBatteryOnly(void);

// Find out if the screen is locked (Apple Menu > Lock Screen)
BOOL ScreenIsLocked(void);




