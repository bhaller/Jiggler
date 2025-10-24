//
// Prefix header for all source files of the 'Jiggler' target in the 'Jiggler' project
//

#ifdef __OBJC__
    #import <Cocoa/Cocoa.h>
#endif

#if !defined(DEBUG)
    #define NSLog(...) do {} while (0)
    #define NSLogv(fmt, args) do {} while (0)
#endif
