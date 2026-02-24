# Jiggler - Randomize Jiggle Times Feature

## Summary
Added a new feature to randomize jiggle intervals between a configurable minimum and maximum time, providing more natural and unpredictable mouse movement patterns.

## New Features

### Randomized Jiggle Times
- Added "Randomize jiggle times" checkbox in Preferences
- When enabled, exposes minimum and maximum jiggle time sliders
- Random interval is calculated once per jiggle cycle using `arc4random_uniform()`
- Interval remains constant until jiggle occurs, then recalculates for next cycle
- Prevents interval from changing on every 0.25-second check

### UI Enhancements
- Added dynamic mode label showing "Standard Jiggle" or "Randomized Jiggle"
- Mutual exclusion: standard slider disabled when randomize is enabled, and vice versa
- Min/max sliders automatically enforce min ≤ max constraint
- Improved UI layout with consistent spacing between elements
- Optimized window height and margins for better visual balance

## Technical Implementation

### New Files Modified
- `PrefsController.h` - Added outlets for randomize controls
- `PrefsController.m` - Implemented randomize logic and UI management
- `AppDelegate.h` - Added `currentJiggleInterval` variable
- `AppDelegate.m` - Implemented interval calculation and randomization
- `Base.lproj/Preferences.xib` - Updated UI layout

### Key Implementation Details

**Randomization Logic:**
- `currentJiggleInterval` stores the active interval (initialized to 0)
- On first check or when 0: calculate initial interval (random or fixed)
- Use this interval consistently until jiggle occurs
- After jiggle completes: recalculate next interval
- This prevents the interval from changing every 0.25 seconds during checks

**Helper Methods Added:**
- `sliderValueToSeconds:` - Converts slider position (0-5) to seconds
- `secondsToSliderValue:` - Converts seconds to slider position (0-5)
- `updateJiggleModeLabel` - Updates mode label based on checkbox state

**User Defaults Keys:**
- `RandomizeJiggleTimes` - Boolean for randomize feature
- `MinJiggleSeconds` - Minimum jiggle interval (default: 5 seconds)
- `MaxJiggleSeconds` - Maximum jiggle interval (default: 60 seconds)

## Code Optimizations

### Refactoring
- Extracted duplicate slider-to-seconds conversion logic into helper methods
- Eliminated ~60 lines of repetitive code
- Simplified slider initialization using helper methods

### Debug Cleanup
- Removed all debug NSLog statements from production code:
  - `SSCPU.m` - Removed CPU tick logging
  - `JigglerOverlayWindow.m` - Removed activate/deactivate logging
  - `TimedQuitController.m` - Removed text field change logging
  - `AppDelegate.m` - Removed idle time and jiggle condition logging
- Kept essential error logging for system-level issues

### Documentation
- Added comprehensive comments explaining randomization logic
- Clarified `currentJiggleInterval` variable purpose
- Documented interval calculation timing

## UI Layout Changes

### Final Coordinates (y-axis from bottom):
- Launch on login: y=807
- Helper text: y=771
- Mode label: y=743
- Time between jiggles: y=715
- Randomize checkbox: y=653
- Min/max controls: y=628 to y=543
- Show icon checkbox: y=517
- Jiggle only when idle: y=465
- Jiggle style: y=405
- Window height: 835 pixels

### Spacing Improvements
- Top margin: ~28 pixels
- Bottom margin: ~29 pixels
- Consistent spacing between all UI elements
- No overlapping elements

## Testing Recommendations

1. Test randomize feature with various min/max combinations
2. Verify mutual exclusion between standard and randomized modes
3. Test edge cases: min=max, very large intervals, very small intervals
4. Confirm interval changes only after jiggle completes, not during checks
5. Verify UI layout on different screen sizes
6. Test accessibility permissions handling

## Compatibility
- macOS 10.13+ (existing requirement)
- No breaking changes to existing functionality
- Backward compatible with existing preferences

## Files Changed
- `PrefsController.h`
- `PrefsController.m`
- `AppDelegate.h`
- `AppDelegate.m`
- `Base.lproj/Preferences.xib`
- `SSCPU.m`
- `JigglerOverlayWindow.m`
- `TimedQuitController.m`

## Build Status
✅ All files compile without errors or warnings
✅ No diagnostics issues detected
✅ Code ready for GitHub submission
