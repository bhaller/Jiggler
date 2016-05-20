//
//  SSPanels.m
//  PhotoReviewer
//
//  Created by Ben Haller on Wed May 22 2002.
//  Copyright (c) 2002 Stick Software. All rights reserved.
//

#import "SSPanels.h"
#import "CocoaExtra.h"


NSString *paidUserNameDefaultsKey = @"PaidUserName";

NSWindow *ssAboutPanel = nil;


#define leftTextLeftMargin 83
#define rightTextRightMargin 66
#define whiteBandHeight 74
#define bodyMarginWidth 20
#define feeTextRightMargin 30
#define buttonEdgeMargin 23

@interface NSApplication (SSPanelCreation)
- (void)SSAboutWindowWillClose:(NSNotification *)note;
@end

@implementation NSApplication (SSPanelCreation)

- (void)SSAboutWindowWillClose:(NSNotification *)note
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:ssAboutPanel];
	ssAboutPanel = nil;
}

@end

@implementation NSWindow (SSPanelCreation)

+ (void)runStandardSSAboutPanelWithURLDictionary:(NSDictionary *)urlDict hideOnDeactivate:(BOOL)hideOnDeactivate
{
    if (!ssAboutPanel)
	{
		NSBundle *mainBundle = [NSBundle mainBundle];
		NSDictionary *infoDictionary = [mainBundle infoDictionary];
		NSString *appName = [infoDictionary objectForKey:(NSString *)kCFBundleNameKey];
		NSString *versionString = [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
		
		ssAboutPanel = [[NSWindow standardSSAboutPanelForAppName:appName versionString:versionString icon:[NSApp SSApplicationIconScaledToSize:NSMakeSize(48, 48)] urlDictionary:urlDict hideOnDeactivate:hideOnDeactivate] retain];
		
		[[NSNotificationCenter defaultCenter] addObserver:NSApp selector:@selector(SSAboutWindowWillClose:) name:NSWindowWillCloseNotification object:ssAboutPanel];
	}
    
	[NSApp activateIgnoringOtherApps:YES];
    [ssAboutPanel makeKeyAndOrderFront:nil];
}

+ (NSWindow *)standardSSAboutPanelForAppName:(NSString *)appName versionString:(NSString *)versionString icon:(NSImage *)iconImage urlDictionary:(NSDictionary *)urlDict hideOnDeactivate:(BOOL)hideFlag
{
	NSString *fullVersionString = SSLocalizedString(@"Version %@", @"For the About box and splash panel");
	NSString *authorString = SSLocalizedString(@"By Ben Haller (%@)", @"The authorship string in the About window");
	NSString *stickString = SSLocalizedString(@"Visit %@ for more!", @"The Stick Software URL string in the About window");
	NSString *copyrightString = SSLocalizedString(@"Copyright 2016 Stick Software, Ben Haller.  All Rights Reserved.", @"The copyright string in the About window");
	NSString *bodyString = SSLocalizedString(@"About panel body text", @"The body text in the About panel");
	
	NSString *completedVersionString = [NSString stringWithFormat:fullVersionString, versionString];
	NSString *emailString = @"bhaller@sticksoftware.com";
	NSString *completedAuthorString = [NSString stringWithFormat:authorString, emailString];
	NSString *urlString = @"www.sticksoftware.com";
	NSString *completedStickString = [NSString stringWithFormat:stickString, urlString];
	
	NSFont *lucida24 = [NSFont fontWithName:@"LucidaGrande" size:24];
	NSFont *lucida13 = [NSFont fontWithName:@"LucidaGrande" size:13];
	NSFont *lucida11 = [NSFont fontWithName:@"LucidaGrande" size:11];
	NSDictionary *lucida24dict = [NSDictionary dictionaryWithObject:lucida24 forKey:NSFontAttributeName];
	NSDictionary *lucida13dict = [NSDictionary dictionaryWithObject:lucida13 forKey:NSFontAttributeName];
	NSDictionary *lucida11dict = [NSDictionary dictionaryWithObject:lucida11 forKey:NSFontAttributeName];
	NSSize appNameSize = [appName sizeWithAttributes:lucida24dict];
	NSSize completedVersionSize = [completedVersionString sizeWithAttributes:lucida13dict];
	NSSize completedAuthorSize = [completedAuthorString sizeWithAttributes:lucida11dict];
	NSSize completedStickSize = [completedStickString sizeWithAttributes:lucida11dict];
	NSSize copyrightSize = [copyrightString sizeWithAttributes:lucida11dict];
	
	int leftTextWidth = MAX(appNameSize.width, completedVersionSize.width) + 15;
	int rightTextWidth = MAX(completedAuthorSize.width, completedStickSize.width) + 15;
	int copyrightWidth = copyrightSize.width + 70;
	int panelWidth = MAX(500, MAX(leftTextWidth + leftTextLeftMargin + rightTextWidth + rightTextRightMargin + 15, copyrightWidth));
	int bodyHeight, panelHeight;
	NSTextView *bodyView = [[NSTextView alloc] initWithFrame:NSMakeRect(20, 91, panelWidth - (bodyMarginWidth + bodyMarginWidth), 1000)];
	NSLayoutManager *lm = [bodyView layoutManager];
	NSTextContainer *tc = [bodyView textContainer];
	
	[bodyView setString:bodyString];
	[bodyView setFont:lucida11];
	[bodyView setEditable:NO];
	[bodyView setDrawsBackground:NO];
	
	[lm glyphRangeForTextContainer:tc];
	bodyHeight = [lm usedRectForTextContainer:tc].size.height + 5;
	panelHeight = bodyHeight + 188;
	
	[bodyView setFrame:NSMakeRect(20, 91, panelWidth - (bodyMarginWidth + bodyMarginWidth), bodyHeight)];
	
	//NSLog(@"panelWidth == %d, panelHeight == %d", panelWidth, panelHeight);
	
	{
	NSRect contentRect = NSMakeRect(0, 0, panelWidth, panelHeight);
	NSWindow *aboutWindow = [[NSPanel alloc] initWithContentRect:contentRect styleMask:(NSTitledWindowMask | NSClosableWindowMask) backing:NSBackingStoreBuffered defer:YES];
	NSView *contentView = [aboutWindow contentView];
	NSRect topThirdRect = NSMakeRect(0, contentRect.size.height - (whiteBandHeight - 1), contentRect.size.width, whiteBandHeight);
	NSView *topThird = [[WhiteView alloc] initWithFrame:topThirdRect];
	NSRect middleThirdRect = NSMakeRect(0, whiteBandHeight - 1, contentRect.size.width, contentRect.size.height - (whiteBandHeight + whiteBandHeight - 3));
	NSView *middleThird = [[BlueView alloc] initWithFrame:middleThirdRect];
	NSRect bottomThirdRect = NSMakeRect(0, 0, contentRect.size.width, whiteBandHeight);
	NSView *bottomThird = [[WhiteView alloc] initWithFrame:bottomThirdRect];
	NSBox *upperDivider = [[NSBox alloc] initWithFrame:NSMakeRect(0, topThirdRect.origin.y, contentRect.size.width, 1)];
	NSBox *lowerDivider = [[NSBox alloc] initWithFrame:NSMakeRect(0, middleThirdRect.origin.y, contentRect.size.width, 1)];
	NSImageView *appIconView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, topThirdRect.origin.y + 12, 48, 48)];
	NSImageView *stickIconView = [[NSImageView alloc] initWithFrame:NSMakeRect(panelWidth - 48, topThirdRect.origin.y + 12, 34, 50)];
	NSTextField *appNameView = [[NSTextField alloc] initWithFrame:NSMakeRect(leftTextLeftMargin, topThirdRect.origin.y + 31, leftTextWidth, 29)];
	NSTextField *versionView = [[NSTextField alloc] initWithFrame:NSMakeRect(leftTextLeftMargin + 2, topThirdRect.origin.y + 12, leftTextWidth - 2, 17)];
	NSTextField *authorView = [[NSTextField alloc] initWithFrame:NSMakeRect(panelWidth - (rightTextWidth + rightTextRightMargin), topThirdRect.origin.y + 40, rightTextWidth, 14)];
	NSTextField *stickView = [[NSTextField alloc] initWithFrame:NSMakeRect(panelWidth - (rightTextWidth + rightTextRightMargin), topThirdRect.origin.y + 18, rightTextWidth, 14)];
	NSTextField *copyrightView = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 27, contentRect.size.width, 14)];
	NSArray *urlKeys;
	int i;
	
	[upperDivider setBoxType:NSBoxSeparator];
	[lowerDivider setBoxType:NSBoxSeparator];
	[appIconView setEditable:NO];
	[appIconView setImage:iconImage];
	[stickIconView setEditable:NO];
	[stickIconView setImage:[NSImage imageNamed:@"stickman5.16G"]];
	[appNameView setStringValue:appName];
	[appNameView setFont:lucida24];
	[appNameView setEditable:NO];
	[appNameView setBordered:NO];
	[versionView setStringValue:completedVersionString];
	[versionView setFont:lucida13];
	[versionView setEditable:NO];
	[versionView setBordered:NO];
	[authorView setStringValue:completedAuthorString];
	[authorView setFont:lucida11];
	[authorView setEditable:NO];
	[authorView setSelectable:YES];
	[authorView setBordered:NO];
	[authorView setAlignment:NSRightTextAlignment];
	[stickView setStringValue:completedStickString];
	[stickView setFont:lucida11];
	[stickView setEditable:NO];
	[stickView setSelectable:YES];
	[stickView setBordered:NO];
	[stickView setAlignment:NSRightTextAlignment];
	[copyrightView setStringValue:copyrightString];
	[copyrightView setFont:lucida11];
	[copyrightView setEditable:NO];
	[copyrightView setSelectable:YES];
	[copyrightView setBordered:NO];
	[copyrightView setAlignment:NSCenterTextAlignment];
	
	[contentView addSubview:topThird];		[topThird release];
	[contentView addSubview:middleThird];	[middleThird release];
	[contentView addSubview:bottomThird];	[bottomThird release];
	[contentView addSubview:upperDivider];	[upperDivider release];
	[contentView addSubview:lowerDivider];	[lowerDivider release];
	[contentView addSubview:appIconView];	[appIconView release];
	[contentView addSubview:stickIconView];	[stickIconView release];
	[contentView addSubview:appNameView];	[appNameView release];
	[contentView addSubview:versionView];	[versionView release];
	[contentView addSubview:authorView];	[authorView release];
	[contentView addSubview:stickView];		[stickView release];
	[contentView addSubview:copyrightView];	[copyrightView release];
	[contentView addSubview:bodyView];		[bodyView release];
	
	[authorView fixText:emailString toGoToLink:@"mailto:bhaller@sticksoftware.com"];
	[stickView fixText:urlString toGoToLink:@"http://www.sticksoftware.com/"];
	
	urlKeys = [urlDict allKeys];
	
	for (i = 0; i < [urlKeys count]; ++i)
	{
		NSString *otherUrlKey = [urlKeys objectAtIndex:i];
		NSString *otherUrlString = [urlDict objectForKey:otherUrlKey];
		
		[bodyView fixText:otherUrlKey toGoToLink:otherUrlString];
	}
	
    [aboutWindow centerOnPrimaryScreen];
	[aboutWindow setReleasedWhenClosed:YES];
	[aboutWindow setHidesOnDeactivate:hideFlag];
	
	return [aboutWindow autorelease];
	}
}

@end
