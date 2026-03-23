# Menu Bar Icon Issue on macOS 26

## Status: INVESTIGATING

The newly built Jiggler app doesn't appear to show its menu bar icon reliably on macOS 26.3.1, despite the app running correctly.

## What We Know

### ✅ Working Correctly
- App builds successfully with no errors
- App launches and runs (verified via `ps aux`)
- Status item creation code executes (verified via logs)
- Control Center status item scenes are requested (seen in system logs)
- App is registered with LaunchServices
- Icon resources are present in the app bundle
- Info.plist is configured correctly

### ❓ Unclear
- Whether the menu bar icon appears at all
- Whether Bartender 6 is hiding it
- Whether macOS 26 beta has a regression with NSStatusItem
- Whether the old installed version (`/Applications/Jiggler.app`) shows its icon correctly

## Investigation Steps Taken

1. ✅ Built app successfully with xcodebuild
2. ✅ Verified app launches and runs
3. ✅ Checked system logs - status item scenes requested from Control Center
4. ✅ Verified icon resources exist in bundle (AppIcon.icns)
5. ✅ Compared binary strings between old and new versions
6. ✅ Verified Info.plist icon configuration
7. ❓ Need user confirmation: Does `/Applications/Jiggler.app` show its icon?

## Code Analysis

The status item creation code in `AppDelegate.m` lines 102-120:

```objective-c
// Set up our status item
NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
CGFloat barThickness = [statusBar thickness];
NSStatusItem *statusItem = [statusBar statusItemWithLength:NSSquareStatusItemLength];

[statusItem setMenu:[self statusItemMenu]];
[self setStatusItem:statusItem];

// Prepare our status item icon variants
NSImage *jigglerImage = [NSImage imageNamed:NSImageNameApplicationIcon];

scaledJigglerImage = [jigglerImage copy];
[scaledJigglerImage setSize:NSMakeSize(barThickness - 2, barThickness - 2)];

scaledJigglerImageRed = [[scaledJigglerImage imageTintedWithColor:...] retain];
scaledJigglerImageGreen = [[scaledJigglerImage imageTintedWithColor:...] retain];

[self fixStatusItemIcon];
```

This code is standard and should work correctly.

## System Logs Evidence

From `log stream` output:
```
[com.apple.BoardServices:XPCErrors] [C:1] Alloc com.apple.controlcenter.statusitems
[com.apple.FrontBoard:SceneExtension] Realizing settings extension __NSStatusItemSceneHostSettings__
[com.apple.FrontBoard:Common] Requesting scene <FBSScene...> from com.apple.controlcenter.statusitems
[com.apple.FrontBoard:Common] Request for <FBSScene...> complete!
```

This shows the status item is being created and Control Center is handling it.

## Possible Causes

### 1. Bartender 6 Hiding the Icon
**Likelihood: HIGH**

Bartender 6 is running and actively manages menu bar items. It may be:
- Automatically hiding new menu bar items
- Not detecting the Jiggler icon properly
- Having compatibility issues with macOS 26

**Test:**
- Temporarily quit Bartender 6
- Launch newly built Jiggler
- Check if icon appears

**Commands:**
```bash
killall Bartender
sleep 2
open ~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app
```

### 2. macOS 26 Beta Bug with NSStatusItem
**Likelihood: MEDIUM**

macOS 26 is in beta (26.3.1) and may have regressions with:
- NSStatusItem API
- Control Center status item integration
- Status bar icon rendering

**Evidence:**
- macOS 26 has had other beta issues (xcodebuild plugin loading, etc.)
- Status items on macOS 26 use new Control Center integration
- Beta OS versions commonly have UI bugs

**Test:**
- Compare with `/Applications/Jiggler.app` (older build)
- If old version shows icon but new doesn't, it's likely a build issue
- If neither shows icon, it's likely an OS/Bartender issue

### 3. Icon Not Loading Correctly
**Likelihood: LOW**

The icon file might not be:
- Included in the bundle correctly (but we verified it's there)
- The correct format for macOS 26 (but .icns should work)
- Loading due to `NSImageNameApplicationIcon` not resolving

**Test:**
```bash
# Check icon in bundle
ls -la ~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app/Contents/Resources/AppIcon.icns

# Verify icon can be displayed
qlmanage -p ~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app/Contents/Resources/AppIcon.icns
```

### 4. App Needs Code Signing for Status Bar
**Likelihood: LOW**

Some macOS features require code signing, but:
- We built with CODE_SIGNING_REQUIRED=NO
- Old version might be signed while new isn't
- Status bar items shouldn't require signing

**Test:**
```bash
# Check code signature
codesign -dvv /Applications/Jiggler.app
codesign -dvv ~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app
```

## Next Steps

### For User to Test

1. **Kill all Jiggler instances:**
   ```bash
   killall -9 Jiggler
   ```

2. **Test old installed version:**
   ```bash
   open /Applications/Jiggler.app
   ```
   - **Question:** Does the icon appear in your menu bar?
   - **Question:** Is it visible in the main menu bar or in Bartender's submenu?

3. **Test with Bartender disabled:**
   ```bash
   killall Bartender
   open ~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app
   ```
   - **Question:** Does the icon appear now?

4. **Check Bartender settings:**
   - Open Bartender preferences
   - Look for Jiggler in the list of menu bar items
   - Check if it's set to "Hide" or "Show"

### For Developer to Investigate

If the issue persists:

1. Add debug logging to `fixStatusItemIcon` method
2. Check if `[[self statusItem] button]` returns nil
3. Verify `scaledJigglerImage` is not nil
4. Try setting a solid color image instead of the app icon
5. Test on macOS 25 (Sequoia) to see if it's macOS 26-specific

## Workaround

If the icon doesn't appear but the app works:
- The app is still functional
- Jiggling should still work
- Access preferences via Activity Monitor:
  1. Open Activity Monitor
  2. Find "Jiggler" process
  3. Double-click it
  4. Use "Sample" to verify it's running

## Related Issues

- [xcodebuild plugin loading issue](XCODEBUILD_ISSUE.md) - also a macOS 26 beta bug
- macOS 26.3.1 is a beta OS with known issues

---

**Created:** March 19, 2026
**Status:** Needs user testing to determine root cause
**Priority:** Medium (app functions but UI missing)
