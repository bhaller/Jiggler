//
//  SSCPUView.h
//  eyeballs
//
//  Created by bhaller on Wed Jun 06 2001.
//  Copyright (c) 2002 Ben Haller. All rights reserved.
//

#import <AppKit/AppKit.h>

#include <sys/time.h>
#include <sys/resource.h>


// This is an edited-down version of a class from Eyeballs.  It is a bit gratuitous for it to be a class here, obviously...

@interface SSCPU : NSObject
{
}

+ (int)busyIndex;

@end
