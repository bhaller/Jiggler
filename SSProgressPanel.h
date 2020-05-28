//
//  SSProgressPanel.h
//  Stick Software subsystem
//
//  Created by Ben Haller on Thu Jul 31 2003.
//  Copyright (c) 2003 Stick Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// This class provides an object capable of running a progress panel or sheet in an intelligent manner.
// The class takes care of all of the details of running the panel, responding to a press of the Stop
// button, constructing the panel (without the use of a nib), and so forth.  It also provides an
// automatic mechanism that can keep the panel from becoming visible unless it is expected to run
// for a significant length of time, to avoid briefly flashing progress panels cluttering an app.

@interface SSProgressPanel : NSObject <NSWindowDelegate>
{
	// Ivars for the panel's UI elements
	NSPanel *progressWindow;
	NSProgressIndicator *progressIndicator;
	NSTextField *progressTitle;
	NSTextField *progressSubtitle;
	
	// This flag keeps track of whether the Stop button has been pressed by the user
	BOOL progressStopped;
	
	// These ivars keep track of state requested via the API.
	// This state may not be able to be set on the panel itself,
	// because the panel may not have been constructed yet.
	NSString *titleString;
	NSString *subtitleString;
	BOOL isDeterminate, giveTimeToRunLoop;
	double minValue, maxValue, progress, thresholdTime;
	
	// We are either running as a sheet in modalWindow, or we are running as a modal panel using modalSession.  Or, our
	// panel is not yet visible, in which case progressWindow is nil, which should be checked before using these ivars.
	NSWindow *modalWindow;
	NSModalSession modalSession;
	
	// Our elapsed time base.  This is the time at which we were started, so we can determine
	// how long the task has been running and whether we want to show our panel or not.
	NSDate *elapsedTimeBase;
	
	// This is the time at which the UI was last updated, allowing us to consolidate
	// multiple updates until it is necessary for us to let one pass through.
	NSDate *lastUpdateTime;
}

// Initialization.  A panel will not be shown at this point, and the "elapsed time" clock used to decide whether to
// show a panel or not will not begin running here.  Those things occur the first time -setProgress: is called
// (or -giveTimeAndSetProgress:), or when -start is called explicitly.
+ (SSProgressPanel *)progressPanelModalForWindow:(NSWindow *)window title:(NSString *)title subtitle:(NSString *)subtitle determinate:(BOOL)determinate;

- (id)initModalForWindow:(NSWindow *)window title:(NSString *)title subtitle:(NSString *)subtitle determinate:(BOOL)determinate;

- (BOOL)isDeterminate;
- (void)setDeterminate:(BOOL)flag;

// -start may be called to start the "elapsed time" counter that determines
// when our panel is actually shown.  A panel may be shown at the point
// -start is called.  -start is implicitly called by -setProgress:.
- (void)start;

// This resets our elapsed time base, allowing time estimates to be correct even when the panel is used for multiple tasks.
- (void)startNewTask;

// This resets our elapsed time base, allowing time estimates to be correct even when the panel is used for multiple tasks.
// This version of the API takes a max value, for determinate tasks, since it is typical to set the max value at the start of a task.
- (void)startNewTaskAndSetMaxValue:(double)value;

// -finish should be called when the client code is finished using the panel.
// It stops the modal loop that may be running, disposes of the panel, etc.
// The object is left in a state identical to its state after construction,
// so it may be reused immediately if so desired, or it may be released.
- (void)finish;
- (void)finishAndRelease;

// Getting and setting the min and max values and the current value
- (double)minValue;
- (void)setMinValue:(double)value;

- (double)maxValue;
- (void)setMaxValue:(double)value;

- (double)progress;
- (void)setProgress:(double)value;

// -giveTime runs the run loop in the default mode, for sheets, or gives
// the modal loop time, for modal panels.  It does nothing if our panel is
// not yet shown, since in that case giving the event loop time is not safe.
// It returns NO if the user has clicked the Stop button, YES otherwise,
// so the return indicates whether the task "should continue".  This is the
// standard "spin" method for indeterminate progress panels.
- (BOOL)giveTime;

// This method is identical to -giveTime, but also sets the progress to the
// given value.  This is the standard "spin" method for determinate progress.
- (BOOL)giveTimeAndSetProgress:(double)value;

// Normally, time is not given to the run loop unless and until the panel is
// shown.  If the run loop needs to spin in order for the task being performed
// to proceed, then we need to give time to it.  This is NO by default.
- (BOOL)giveTimeToRunLoop;
- (void)setGiveTimeToRunLoop:(BOOL)flag;

// Getting and setting the title and subtitle strings.
// These can be changed during the run of the progress panel.
- (NSString *)title;
- (void)setTitle:(NSString *)title;

- (NSString *)subtitle;
- (void)setSubtitle:(NSString *)subtitle;

// -isVisible returns YES if our panel has actually been constructed and
// shown (which may be done in a delayed fashion).  -forceVisible makes
// the panel get constructed and shown immediately.
- (BOOL)isVisible;
- (void)forceVisible;

// -isStoppedByUser returns YES is the user has clicked the "Stop" button.
// -performStop: lets the same effect be achieved programmatically.
// A stopped panel remains entirely functional; it merely records that it has
// been stopped.  The responsibility for noticing that fact lies with the caller.
- (BOOL)isStoppedByUser;
- (IBAction)performStop:(id)sender;

// Timing: elapsed and estimated to completion
- (NSTimeInterval)elapsedTime;
- (NSTimeInterval)estimatedTotalTime;
- (NSTimeInterval)estimatedTimeToCompletion;

// The threshold time is the length of time that must elapse, at a minimum, before
// our panel is shown.  It is 0.2 (seconds) by default.  Normally, this value is
// good for any given task, but if a task has a short expected duration that it is
// usually completed in, you might adjust the threshold time to avoid displaying
// the progress panel in that xpected case.
- (double)thresholdTime;
- (void)setThresholdTime:(double)time;

@end




