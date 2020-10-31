//
//  CocoaExtra.m
//  Trisection
//
//  Created by bhaller on Thu May 17 2001.
//  Copyright (c) 2001 Ben Haller. All rights reserved.
//

#import "CocoaExtra.h"
#import <ExceptionHandling/NSExceptionHandler.h>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>

#import <IOKit/hidsystem/event_status_driver.h>


NSString *SSTestLocalizedString(NSString *key)
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *localizedString = [mainBundle localizedStringForKey:key value:@"*** error" table:nil];
	
	if ([localizedString isEqualToString:@"*** error"])
	{
		localizedString = [NSString stringWithFormat:@"*%@*", key];
		NSLog(@"No value found for key \"%@\"", key);
	}
	else
	{
		// Uncomment this to log successful key lookups
		//NSLog(@"key \"%@\" produced value \"%@\"", key, localizedString);
	}
	
	return localizedString;
}

NSString *SSTestLocalizedStringFromTable(NSString *key, NSString *table)
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *localizedString = [mainBundle localizedStringForKey:key value:@"*** error" table:table];
	
	if ([localizedString isEqualToString:@"*** error"])
	{
		localizedString = [NSString stringWithFormat:@"*%@*", key];
		NSLog(@"No value found for key \"%@\"", key);
	}
	else
	{
		// Uncomment this to log successful key lookups
		//NSLog(@"key \"%@\" produced value \"%@\"", key, localizedString);
	}
	
	return localizedString;
}

@implementation NSTextView (SSCocoaExtra)

// This is the best solution I've found so far to the problem of how to get clickable links into a window using
// NSLinkAttribute.  This circumvents three different problems.  One is that standalone textviews created in IB
// have a black background that is difficult or impossible to get rid of.  Another is that somebody along the
// way strips off link attributes when you copy text and paste it into IB, so even if you get a proper string
// with the link attribute set up, you can't get it into a textview in IB; the attribute is lost.  Finally,
// IB is really not very happy about textviews that are not contained by scrollviews anyway, so it makes life
// in IB easier to avoid creating standalone textviews.  This solution is gross, but it works.
- (void)fixText:(NSString *)text toGoToLink:(NSString *)url
{
    NSString *tvString = [self string];
    NSRange urlRange = [tvString rangeOfString:text options:NSBackwardsSearch];
	NSTextStorage *ts;
	
    ts = [self textStorage];
    [ts beginEditing];
    if ((urlRange.location != 0) && (urlRange.location != NSNotFound))
    {
		[ts addAttribute:NSLinkAttributeName value:[NSURL URLWithString:url] range:urlRange];
		[ts addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:urlRange];
		[ts addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:urlRange];
    }
    [ts endEditing];
}

@end

@implementation NSTextField (SSCocoaExtra)

// This is the best solution I've found so far to the problem of how to get clickable links into a window using
// NSLinkAttribute.  This circumvents three different problems.  One is that standalone textviews created in IB
// have a black background that is difficult or impossible to get rid of.  Another is that somebody along the
// way strips off link attributes when you copy text and paste it into IB, so even if you get a proper string
// with the link attribute set up, you can't get it into a textview in IB; the attribute is lost.  Finally,
// IB is really not very happy about textviews that are not contained by scrollviews anyway, so it makes life
// in IB easier to avoid creating standalone textviews.  This solution is gross, but it works.
- (void)fixText:(NSString *)text toGoToLink:(NSString *)url
{
    NSString *tfString = [self stringValue];
    NSRange urlRange = [tfString rangeOfString:text options:NSBackwardsSearch];
    int length = (int)[tfString length];
	NSMutableParagraphStyle *pStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    NSTextView *tv;
    NSTextStorage *ts;
	NSRect viewFrame = [self frame];
	
    [pStyle setAlignment:[self alignment]];
	
    tv = [[NSTextView alloc] initWithFrame:viewFrame];
    [tv setString:tfString];
    [tv setEditable:NO];
    [tv setSelectable:YES];
    [tv setRichText:YES];
    [tv setDrawsBackground:NO];
    [tv setTextContainerInset:NSMakeSize(0, 0)];
    [tv setTextColor:self.textColor];
    [[tv textContainer] setLineFragmentPadding:1.0];
    
    ts = [tv textStorage];
    [ts beginEditing];
    [ts addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(0, length)];
    [ts addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(0, length)];
    if ((urlRange.location != 0) && (urlRange.location != NSNotFound))
    {
		[ts addAttribute:NSLinkAttributeName value:[NSURL URLWithString:url] range:urlRange];
		[ts addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:urlRange];
		[ts addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:urlRange];
    }
    [ts endEditing];
	
	[tv setFrame:viewFrame];			// set the frame again, to counteract an apparent AppKit bug...
    [[self superview] addSubview:tv];
    [tv release];
    [self removeFromSuperview];
}

@end

@implementation WhiteView

- (void)drawRect:(NSRect)rect
{
    [[NSColor whiteColor] set];
    NSRectFill(rect);
}

@end

@implementation BlueView

- (void)drawRect:(NSRect)rect
{
    [[NSColor colorWithCalibratedRed:0.93 green:0.93 blue:1.0 alpha:1.0] set];
    NSRectFill(rect);
}

@end

NSModalResponse SSRunAlertPanel(NSString *title, NSString *msg, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...)
{
	va_list params;
	NSString *resolvedMessage;
	
	va_start(params, otherButton);
	resolvedMessage = [[NSString alloc] initWithFormat:msg arguments:params];
	va_end(params);
	
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert addButtonWithTitle:defaultButton];
	if (alternateButton)
		[alert addButtonWithTitle:alternateButton];
	if (otherButton)
		[alert addButtonWithTitle:otherButton];
	[alert setMessageText:title];
	[alert setInformativeText:resolvedMessage];
	[alert setAlertStyle:NSAlertStyleWarning];
	
	NSModalResponse value = [alert runModal];
	
	[alert release];
	[resolvedMessage release];
	
    return value;
}

NSModalResponse SSRunInformationalAlertPanel(NSString *title, NSString *msg, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...)
{
	va_list params;
	NSString *resolvedMessage;
	
	va_start(params, otherButton);
	resolvedMessage = [[NSString alloc] initWithFormat:msg arguments:params];
	va_end(params);
	
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert addButtonWithTitle:defaultButton];
	if (alternateButton)
		[alert addButtonWithTitle:alternateButton];
	if (otherButton)
		[alert addButtonWithTitle:otherButton];
	[alert setMessageText:title];
	[alert setInformativeText:resolvedMessage];
	[alert setAlertStyle:NSAlertStyleInformational];
	
	NSModalResponse value = [alert runModal];
	
	[alert release];
	[resolvedMessage release];
	
    return value;
}

NSModalResponse SSRunCriticalAlertPanel(NSString *title, NSString *msg, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...)
{
	va_list params;
	NSString *resolvedMessage;
	
	va_start(params, otherButton);
	resolvedMessage = [[NSString alloc] initWithFormat:msg arguments:params];
	va_end(params);
	
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert addButtonWithTitle:defaultButton];
	if (alternateButton)
		[alert addButtonWithTitle:alternateButton];
	if (otherButton)
		[alert addButtonWithTitle:otherButton];
	[alert setMessageText:title];
	[alert setInformativeText:resolvedMessage];
	[alert setAlertStyle:NSAlertStyleCritical];
	
	NSModalResponse value = [alert runModal];
	
	[alert release];
	[resolvedMessage release];
	
    return value;
}

@implementation NSScreen (SSScreens)

// Returns the screen with an origin of (0, 0); +mainScreen returns the screen which the key window is currently on, which is not often what we want.
+ (NSScreen *)primaryScreen
{
	NSArray *screens = [NSScreen screens];
	int i, c;
	
	for (i = 0, c = (int)[screens count]; i < c; ++i)
	{
		NSScreen *screen = [screens objectAtIndex:i];
		NSRect frame = [screen frame];
		
		if ((frame.origin.x == 0) && (frame.origin.y == 0))
			return screen;
	}
	
	return nil;
}

@end

@implementation NSWindow (SSWindowCentering)

- (void)centerOnPrimaryScreen
{
	NSScreen *primaryScreen = [NSScreen primaryScreen];
	NSRect screenFrame = [primaryScreen visibleFrame];
	NSRect windowFrame = [self frame];
	NSRect newFrame = NSMakeRect(
		screenFrame.origin.x + floor((screenFrame.size.width - windowFrame.size.width) / 2.0),
		screenFrame.origin.y + floor(((screenFrame.size.height - windowFrame.size.height) * 2.0) / 3.0),
		windowFrame.size.width,
		windowFrame.size.height);
		
	//NSLog(@"centerOnPrimaryScreen called for window %p with frame %@.  New frame == %@.", self, NSStringFromRect(windowFrame), NSStringFromRect(newFrame));
	
	if (!NSEqualRects(windowFrame, newFrame))
		[self setFrame:newFrame display:YES];
}

@end

@implementation NSPanel (SSCocoaExtra)

// This makes command-W work to close the window, even though we have no menubar
// Note that we assume NSPanel does not implement this method, which seems to be true through 10.15...
- (BOOL)performKeyEquivalent:(NSEvent *)event
{
	NSString *chars = [event charactersIgnoringModifiers];
	NSEventModifierFlags flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
	
	if ([chars isEqualToString:@"w"] && ((flags == NSEventModifierFlagCommand) || (flags == (NSEventModifierFlagCommand | NSEventModifierFlagCapsLock))) && ([self styleMask] & NSWindowStyleMaskClosable))
	{
		[self performClose:self];
		return YES;
	}
	
	return [super performKeyEquivalent:event];
}

@end

@implementation NSApplication (SSApplicationIcon)

- (NSImage *)SSApplicationIconScaledToSize:(NSSize)finalSize
{
	NSImage *appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
	NSSize appIconSize = [appIcon size];
	NSImage *icon = [[NSImage alloc] initWithSize:finalSize];
	NSImageInterpolation savedInterpolation;
	NSGraphicsContext *context;
	
	[icon lockFocus];
	context = [NSGraphicsContext currentContext];
	savedInterpolation = [context imageInterpolation];
	[context setImageInterpolation:NSImageInterpolationHigh];
	[appIcon drawInRect:NSMakeRect(0, 0, finalSize.width, finalSize.height) fromRect:NSMakeRect(0, 0, appIconSize.width, appIconSize.height) operation:NSCompositingOperationSourceOver fraction:1.0];
	[context setImageInterpolation:savedInterpolation];
	[icon unlockFocus];
	
	return [icon autorelease];
}

@end

@implementation NSArray (SSRunLoopExtra)

+ (NSArray *)allRunLoopModes
{
    static NSArray *modes = nil;

    if (!modes)
        modes = [[NSArray alloc] initWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil];

    return modes;
}

+ (NSArray *)standardRunLoopModes
{
    static NSArray *modes = nil;

    if (!modes)
        modes = [[NSArray alloc] initWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil];

    return modes;
}

@end


#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>

static BOOL stringsAreEqual (CFStringRef a, CFStringRef b)
{
    if (a == nil || b == nil)
        return 0;
    
    return (CFStringCompare (a, b, 0) == kCFCompareEqualTo);
}

// see http://context-macosx.googlecode.com/svn-history/r138/trunk/Tools/Applications/Pennyworth/PowerObserver.m
BOOL RunningOnBatteryOnly(void)
{
    BOOL onlyBattery = NO;  // if we have no information on power, assume we're not on battery only
    
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    CFArrayRef list = IOPSCopyPowerSourcesList(blob);
    
    CFIndex count = CFArrayGetCount(list);
    
    if (count)
    {
        onlyBattery = YES;  // if we have information on power sources, then start assuming battery only, and knock that down if we find a non-battery source
        
        for (CFIndex i = 0; i < count; i++)
        {
            CFTypeRef source;
            CFDictionaryRef description;
            
            source = CFArrayGetValueAtIndex (list, i);
            description = IOPSGetPowerSourceDescription (blob, source);
            
            if (stringsAreEqual (CFDictionaryGetValue (description, CFSTR (kIOPSTransportTypeKey)), CFSTR (kIOPSInternalType)))
            {
                CFStringRef currentState = CFDictionaryGetValue (description, CFSTR (kIOPSPowerSourceStateKey));
                
                if (!stringsAreEqual(currentState, CFSTR (kIOPSBatteryPowerValue)))
                    onlyBattery = NO;
            } 
        }
    }
    
    CFRelease (list);
    CFRelease (blob);
    
    //NSLog(@"%d sources, onlyBattery == %@", count, onlyBattery ? @"YES" : @"NO");
    return onlyBattery;
}

// see https://stackoverflow.com/questions/11505255/osx-check-if-the-screen-is-locked
// and https://stackoverflow.com/questions/54346761/swift-how-to-observe-if-screen-is-locked-in-macos
BOOL ScreenIsLocked(void)
{
	CFDictionaryRef sessionDict = CGSessionCopyCurrentDictionary();
	
	if (!sessionDict)
		return NO;
	
	BOOL isLocked = ([[(NSDictionary *)sessionDict objectForKey:@"CGSSessionScreenIsLocked"] intValue] == 1);
	
	CFRelease(sessionDict);
	return isLocked;
}


































































