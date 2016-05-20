//
//  SSVersionChecker.m
//  Stick Software subsystem
//
//  Created by Ben Haller on Mon May 19 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import "SSVersionChecker.h"
#import "CocoaExtra.h"
#import "SSProgressPanel.h"


static NSString *VersionCheckingEnabledDefaultsKey = @"DoVersionCheck";


@implementation SSVersionChecker

+ (SSVersionChecker *)sharedVersionChecker
{
	static SSVersionChecker *sharedChecker = nil;
	
	if (!sharedChecker)
	{
		sharedChecker = [[SSVersionChecker alloc] init];
	}
	
	return sharedChecker;
}

- (id)init
{
	if (self = [super init])
	{
		_receivedData = [[NSMutableData data] retain];
	}
	
	return self;
}

- (void)dealloc
{
	[_receivedData release];
	_receivedData = nil;
	
	[super dealloc];
}

- (void)askUserAboutAutomaticVersionCheck
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *doCheck;
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSDictionary *infoDict = [mainBundle infoDictionary];
	NSString *appName = [infoDict objectForKey:(NSString *)kCFBundleNameKey];
	NSString *message = SSLocalizedString(@"Version Check offer panel text", @"Version Check offer panel text");
	
	message = [NSString stringWithFormat:message, appName, appName];
	
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert addButtonWithTitle:SSLocalizedString(@"Yes button", @"Yes button")];
	[alert addButtonWithTitle:SSLocalizedString(@"No button", @"No button")];
	[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
	[alert setInformativeText:message];
	[alert setAlertStyle:NSInformationalAlertStyle];
	
	NSModalResponse retval = [alert runModal];
	
	[alert release];
	
	if (retval == NSAlertFirstButtonReturn)
		doCheck = @"YES";
	else
		doCheck = @"NO";
	
	[defaults setObject:doCheck forKey:VersionCheckingEnabledDefaultsKey];
	[defaults synchronize];
}

- (BOOL)shouldDoAutomaticVersionCheckAskIfNecessary:(BOOL)flag
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *doCheck = [defaults stringForKey:VersionCheckingEnabledDefaultsKey];
	
	if (!doCheck && flag)
	{
		[self askUserAboutAutomaticVersionCheck];
		doCheck = [defaults stringForKey:VersionCheckingEnabledDefaultsKey];
	}
	
	return ([doCheck isEqual:@"YES"] ? YES : NO);
}

- (BOOL)webVersion:(NSString *)webVersionString isLaterThanAppVersion:(NSString *)appVersionString
{
	NSArray *alphaWebComponents = [webVersionString componentsSeparatedByString:@"a"];
	NSArray *alphaAppComponents = [appVersionString componentsSeparatedByString:@"a"];
	BOOL webVersionIsAlpha = (([alphaWebComponents count] > 1) ? YES : NO);
	BOOL appVersionIsAlpha = (([alphaAppComponents count] > 1) ? YES : NO);
	NSArray *betaWebComponents = [[alphaWebComponents objectAtIndex:0] componentsSeparatedByString:@"b"];
	NSArray *betaAppComponents = [[alphaAppComponents objectAtIndex:0] componentsSeparatedByString:@"b"];
	BOOL webVersionIsBeta = (([betaWebComponents count] > 1) ? YES : NO);
	BOOL appVersionIsBeta = (([betaAppComponents count] > 1) ? YES : NO);
	NSArray *webComponents = [[betaWebComponents objectAtIndex:0] componentsSeparatedByString:@"."];
	NSArray *appComponents = [[betaAppComponents objectAtIndex:0] componentsSeparatedByString:@"."];
	BOOL webVersionIsFinal = !(webVersionIsAlpha || webVersionIsBeta);
	BOOL appVersionIsFinal = !(appVersionIsAlpha || appVersionIsBeta);
	int i, cWeb, cApp, cMin;
	
	cWeb = [webComponents count];
	cApp = [appComponents count];
	cMin = MIN(cWeb, cApp);
	
	// Compare digits that line up; if one has a higher value, it wins.
	for (i = 0; i < cMin; ++i)
	{
		int webIntValue = [[webComponents objectAtIndex:i] intValue];
		int appIntValue = [[appComponents objectAtIndex:i] intValue];
		
		if (webIntValue > appIntValue) return YES;
		if (webIntValue < appIntValue) return NO;
	}
	
	// If one has an extra component (6.2.1 versus 6.2), that one wins.
	if (cWeb > cApp) return YES;
	if (cApp > cWeb) return NO;
	
	// Now we look for patterns like 6.2b7 versus 6.2b8, or 6.2a7 versus 6.2b1, or any such things.
	if (webVersionIsAlpha && (appVersionIsBeta || appVersionIsFinal)) return NO;
	if (webVersionIsBeta && appVersionIsFinal) return NO;
	
	if (appVersionIsAlpha && (webVersionIsBeta || webVersionIsFinal)) return YES;
	if (appVersionIsBeta && webVersionIsFinal) return YES;
	
	if (appVersionIsAlpha && webVersionIsAlpha)
	{
		int appAlphaBuildNumber = [[alphaAppComponents objectAtIndex:1] intValue];
		int webAlphaBuildNumber = [[alphaWebComponents objectAtIndex:1] intValue];
		
		if (webAlphaBuildNumber > appAlphaBuildNumber) return YES;
		if (appAlphaBuildNumber > webAlphaBuildNumber) return NO;
	}
	
	if (appVersionIsBeta && webVersionIsBeta)
	{
		int appBetaBuildNumber = [[betaAppComponents objectAtIndex:1] intValue];
		int webBetaBuildNumber = [[betaWebComponents objectAtIndex:1] intValue];
		
		if (webBetaBuildNumber > appBetaBuildNumber) return YES;
		if (appBetaBuildNumber > webBetaBuildNumber) return NO;
	}
	
	return NO;
}

- (NSString *)versionStringFromFullString:(NSString *)fullString bundleIdentifier:(NSString *)bundleIdentifier
{
	NSArray *lines = [fullString componentsSeparatedByString:@"\n"];
	int i, c;
	
	for (i = 0, c = [lines count]; i < c; ++i)
	{
		NSString *line = [lines objectAtIndex:i];
		
		if ([line hasPrefix:bundleIdentifier])
		{
			NSArray *components = [line componentsSeparatedByString:@" "];
			
			if ([components count] == 2)
				return [components objectAtIndex:1];
		}
	}
	
	return nil;
}

- (void)compareVersionWithVersionData:(NSData *)versionData tellUserNegativeResult:(BOOL)flag
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *bundleIdentifier = [mainBundle bundleIdentifier];
	NSDictionary *infoDictionary = [mainBundle infoDictionary];
	NSString *appVersionString = [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
	NSString *bundleName = [infoDictionary objectForKey:(NSString *)kCFBundleNameKey];
	NSString *versionDataString = (versionData ? [[[NSString alloc] initWithData:versionData encoding:NSMacOSRomanStringEncoding] autorelease] : nil);
	NSString *webVersionString = [self versionStringFromFullString:versionDataString bundleIdentifier:bundleIdentifier];
	
#if 0
	NSLog(@"6.1 is later than 6.0: %@", [self webVersion:@"6.1" isLaterThanAppVersion:@"6.0"] ? @"YES" : @"NO");
	NSLog(@"6.0 is later than 6.1: %@", [self webVersion:@"6.0" isLaterThanAppVersion:@"6.1"] ? @"YES" : @"NO");
	NSLog(@"6.1.1 is later than 6.1: %@", [self webVersion:@"6.1.1" isLaterThanAppVersion:@"6.1"] ? @"YES" : @"NO");
	NSLog(@"6.1 is later than 6.1.1: %@", [self webVersion:@"6.1" isLaterThanAppVersion:@"6.1.1"] ? @"YES" : @"NO");
	NSLog(@"6.1 is later than 6.1b1: %@", [self webVersion:@"6.1" isLaterThanAppVersion:@"6.1b1"] ? @"YES" : @"NO");
	NSLog(@"6.1b1 is later than 6.1: %@", [self webVersion:@"6.1b1" isLaterThanAppVersion:@"6.1"] ? @"YES" : @"NO");
	NSLog(@"6.1 is later than 6.1a1: %@", [self webVersion:@"6.1" isLaterThanAppVersion:@"6.1a1"] ? @"YES" : @"NO");
	NSLog(@"6.1a1 is later than 6.1: %@", [self webVersion:@"6.1a1" isLaterThanAppVersion:@"6.1"] ? @"YES" : @"NO");
	NSLog(@"6.1b1 is later than 6.1a1: %@", [self webVersion:@"6.1b1" isLaterThanAppVersion:@"6.1a1"] ? @"YES" : @"NO");
	NSLog(@"6.1a1 is later than 6.1b1: %@", [self webVersion:@"6.1a1" isLaterThanAppVersion:@"6.1b1"] ? @"YES" : @"NO");
	NSLog(@"6.1a2 is later than 6.1a1: %@", [self webVersion:@"6.1a2" isLaterThanAppVersion:@"6.1a1"] ? @"YES" : @"NO");
	NSLog(@"6.1a1 is later than 6.1a2: %@", [self webVersion:@"6.1a1" isLaterThanAppVersion:@"6.1a2"] ? @"YES" : @"NO");
	NSLog(@"6.1b2 is later than 6.1b1: %@", [self webVersion:@"6.1b2" isLaterThanAppVersion:@"6.1b1"] ? @"YES" : @"NO");
	NSLog(@"6.1b1 is later than 6.1b2: %@", [self webVersion:@"6.1b1" isLaterThanAppVersion:@"6.1b2"] ? @"YES" : @"NO");
#endif

	if (!webVersionString)
	{
		NSString *mailURLString;
		NSURL *mailURL;
		
		mailURLString = @"mailto:versioncheck@sticksoftware.com?subject=Version%20check%20error&body=No%20entry%20found%20for%20";
		mailURLString = [mailURLString stringByAppendingString:bundleName];
		mailURLString = [mailURLString stringByAppendingString:@"%20("];
		mailURLString = [mailURLString stringByAppendingString:bundleIdentifier];
		mailURLString = [mailURLString stringByAppendingString:@").%0D%0DThis%20email%20was%20automatically%20generated.%0D%0D"];
		mailURL = [NSURL URLWithString:mailURLString];
		
		if (mailURL)
		{
			NSAlert *alert = [[NSAlert alloc] init];
			
			[alert addButtonWithTitle:SSLocalizedString(@"OK button", @"OK button")];
			[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
			[alert setInformativeText:SSLocalizedString(@"Version Check info unavailable error (sending email)", @"Version Check info unavailable error (sending email)")];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			[alert runModal];
			[alert release];
			
			[[NSWorkspace sharedWorkspace] openURL:mailURL];
		}
		else
		{
			NSLog(@"mailURL didn't create from string:\n%@", mailURLString);
			
			NSAlert *alert = [[NSAlert alloc] init];
			
			[alert addButtonWithTitle:SSLocalizedString(@"OK button", @"OK button")];
			[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
			[alert setInformativeText:SSLocalizedString(@"Version Check info unavailable error", @"Version Check info unavailable error")];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			[alert runModal];
			[alert release];
		}
	}
	else if ([self webVersion:webVersionString isLaterThanAppVersion:appVersionString])
	{
		NSString *message = [NSString stringWithFormat:SSLocalizedString(@"Version Check new version available", @"Version Check new version available"),
			bundleName, webVersionString, appVersionString];
		
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert addButtonWithTitle:SSLocalizedString(@"Yes button", @"Yes button")];
		[alert addButtonWithTitle:SSLocalizedString(@"No button", @"No button")];
		[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
		[alert setInformativeText:message];
		[alert setAlertStyle:NSInformationalAlertStyle];
		
		NSModalResponse retval = [alert runModal];
		
		[alert release];
		
		if (retval == NSAlertFirstButtonReturn)
		{
			NSString *productURLString = [NSString stringWithFormat:@"http://www.sticksoftware.com/software/%@.dmg.gz", bundleName];
			NSURL *productURL = [NSURL URLWithString:productURLString];
			
			if (!productURL || ![[NSWorkspace sharedWorkspace] openURL:productURL])
			{
				NSAlert *failalert = [[NSAlert alloc] init];
				
				[failalert addButtonWithTitle:SSLocalizedString(@"OK button", @"OK button")];
				[failalert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
				[failalert setInformativeText:SSLocalizedString(@"Version Check download failed error", @"Version Check download failed error")];
				[failalert setAlertStyle:NSWarningAlertStyle];
				
				[failalert runModal];
				[failalert release];
			}
		}
	}
	else if (flag)
	{
		NSString *message = [NSString stringWithFormat:SSLocalizedString(@"Version Check up to date", @"Version Check up to date"), bundleName, appVersionString];
		
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert addButtonWithTitle:SSLocalizedString(@"OK button", @"OK button")];
		[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
		[alert setInformativeText:message];
		[alert setAlertStyle:NSInformationalAlertStyle];
		
		[alert runModal];
		[alert release];
	}
}

- (void)beginBackgroundCheckIfNecessary
{
	BOOL doCheck = [self shouldDoAutomaticVersionCheckAskIfNecessary:NO];
	
	if (doCheck)
	{
		NSString *versionFileURLString = @"http://www.sticksoftware.com/versions";
		NSURL *versionFileURL = [NSURL URLWithString:versionFileURLString];
		NSURLRequest *request = [NSURLRequest requestWithURL:versionFileURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		
		[_receivedData setLength:0];

		if (connection)
		{
			_finishedLoading = NO;
			//NSLog(@"beginning background version check");
		}
		else
		{
			_finishedLoading = YES;
			//NSLog(@"background version check could not be initiated");
		}
	}
}

- (void)checkForNewVersionUserRequested:(BOOL)flag
{
	BOOL doCheck = (flag || [self shouldDoAutomaticVersionCheckAskIfNecessary:YES]);
	
	if (doCheck)
	{
		NSString *versionFileURLString = @"http://www.sticksoftware.com/versions";
		NSURL *versionFileURL = [NSURL URLWithString:versionFileURLString];
		NSURLRequest *request = [NSURLRequest requestWithURL:versionFileURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		
		[_receivedData setLength:0];

		if (connection)
		{
			SSProgressPanel *progressPanel;
			BOOL loadCancelledByUser = NO;
			
			_finishedLoading = NO;
			
			progressPanel = [[SSProgressPanel progressPanelModalForWindow:nil title:SSLocalizedString(@"Version Check", @"Version Check panels title") subtitle:SSLocalizedString(@"Checking for a new version...", @"Version Check progress string") determinate:NO] retain];
			[progressPanel setGiveTimeToRunLoop:YES];
			[progressPanel setThresholdTime:1.0];
			[progressPanel startNewTask];
			
			while (!_finishedLoading && ([progressPanel elapsedTime] < (flag ? 15.0 : 5.0)))
			{
				if (![progressPanel giveTime])
				{
					loadCancelledByUser = YES;
					break;
				}
			}
			
			[progressPanel finishAndRelease];
			
			if (loadCancelledByUser)
			{
				[connection cancel];
				return;
			}
		}
		else
		{
			_finishedLoading = YES;
			//NSLog(@"version check could not be initiated");
		}
		
		if ([_receivedData length])
		{
			[self compareVersionWithVersionData:_receivedData tellUserNegativeResult:flag];
		}
		else
		{
			if (flag)
			{
				NSAlert *alert = [[NSAlert alloc] init];
				
				[alert addButtonWithTitle:SSLocalizedString(@"OK button", @"OK button")];
				[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
				[alert setInformativeText:SSLocalizedString(@"Version Check network unavailable error (short version)", @"Version Check network unavailable error (short version)")];
				[alert setAlertStyle:NSWarningAlertStyle];
				
				[alert runModal];
				[alert release];
			}
			else
			{
				NSAlert *alert = [[NSAlert alloc] init];
				
				[alert addButtonWithTitle:SSLocalizedString(@"OK button", @"OK button")];
				[alert setMessageText:SSLocalizedString(@"Version Check", @"Version Check panels title")];
				[alert setInformativeText:SSLocalizedString(@"Version Check network unavailable error (long version)", @"Version Check network unavailable error (long version)")];
				[alert setAlertStyle:NSWarningAlertStyle];
				
				[alert runModal];
				[alert release];
			}
		}
	}
}


//
//	NSURLConection delegate methods
//

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
#pragma unused (connection, response)
	[_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
#pragma unused (connection)
	[_receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
#pragma unused (connection, error)
	[connection release];
	
	[_receivedData setLength:0];
	
	_finishedLoading = YES;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[connection release];
	
	_finishedLoading = YES;
}

@end










