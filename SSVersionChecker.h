//
//  SSVersionChecker.h
//  Stick Software subsystem
//
//  Created by Ben Haller on Mon May 19 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SSVersionChecker : NSObject
{
	BOOL _finishedLoading;
	NSMutableData *_receivedData;
}

+ (SSVersionChecker *)sharedVersionChecker;

- (void)askUserAboutAutomaticVersionCheck;							// runs a panel, whether the user has answered before or not
- (BOOL)shouldDoAutomaticVersionCheckAskIfNecessary:(BOOL)flag;		// runs a panel only if the user has not expressed an opinion before AND flag is true

- (void)beginBackgroundCheckIfNecessary;							// can be called early to start the background check, to avoid showing the progress panel
- (void)checkForNewVersionUserRequested:(BOOL)flag;					// does an immediate, synchronous check (unless a background check has already completed)

@end
