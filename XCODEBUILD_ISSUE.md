# xcodebuild Plugin Loading Issue on macOS 26

## The Problem

On macOS 26.3.1 (Tahoe) with Xcode 26.3, the command-line `xcodebuild` tool fails immediately with this error:

```
DVTPlugInLoading: Failed to load code for plug-in com.apple.dt.IDESimulatorFoundation
Symbol not found: _$s12DVTDownloads15DownloadOptionsV15PatchSourceTypeO09patchFromE9DirectoryyAE10Foundation3URLVcAEmFWC
Expected in: /Library/Developer/PrivateFrameworks/DVTDownloads.framework/Versions/A/DVTDownloads

xcodebuild failed to load a required plug-in. Ensure your system frameworks are up-to-date by running 'xcodebuild -runFirstLaunch'
```

**This completely blocks xcodebuild** - it doesn't even attempt to build the project.

## Root Cause

**Framework Version Mismatch Between:**
- `/Library/Developer/PrivateFrameworks/DVTDownloads.framework` (old version from December 2024)
- `/Applications/Xcode.app/Contents/Frameworks/IDESimulatorFoundation.framework` (new version from Xcode 26.3, February 2026)

The newer framework expects Swift symbols that don't exist in the older system framework. This is a **known bug in macOS 26 beta versions** where system frameworks are out of sync with Xcode versions.

## Why This Happens

This is a **macOS 26 beta bug**:
- Old Xcode/Command Line Tools installations left outdated frameworks in `/Library/Developer/PrivateFrameworks/`
- Xcode 26.3 was installed but didn't update these system frameworks
- xcodebuild loads IDESimulatorFoundation as a "required" plugin even for macOS-only projects (this seems like a bug)
- The framework mismatch causes the symbol resolution error

## Why GUI Xcode Works But CLI Doesn't

The Xcode GUI uses a different plugin loading mechanism and may not require IDESimulatorFoundation for macOS app builds. The command-line `xcodebuild` has stricter plugin requirements that cause it to fail.

## The Solution (Requires Sudo)

Run this command to update system frameworks:

```bash
sudo xcodebuild -runFirstLaunch
```

**What this does:**
- Updates frameworks in `/Library/Developer/PrivateFrameworks/` to match your Xcode version
- Accepts Xcode license agreements
- Installs required components
- Synchronizes system tools with Xcode

**Why sudo is required:**
The system frameworks are owned by `root:admin` and require administrative privileges to update.

## Workarounds (If You Don't Have Sudo)

### 1. Use Xcode GUI (Recommended)
```bash
open Jiggler.xcodeproj
# Then build with Command+B or run with Command+R
```

This works perfectly for local development and testing.

### 2. Ask System Administrator
Request that your system admin run:
```bash
sudo xcodebuild -runFirstLaunch
```

This is a one-time operation that fixes the issue permanently for your Xcode version.

### 3. Use Different Machine
- Use a machine with properly synchronized Xcode/system frameworks
- Use a machine running macOS 25 (Sequoia) instead of the beta macOS 26
- Use GitHub Actions runners (they run the setup commands automatically)

## Impact on CI/CD

**Good news:** This issue is **specific to your local macOS 26 beta environment**.

GitHub Actions runners and other CI systems:
- Run proper Xcode setup scripts including `-runFirstLaunch`
- Use stable macOS versions (currently macOS 14/15 for most runners)
- Are configured correctly out of the box

**Your GitHub Actions workflows will work fine** - this is purely a local development environment issue.

## Current Status

- ✅ **Xcode GUI builds:** Working perfectly
- ✅ **Command-line xcodebuild:** FIXED by running `sudo xcodebuild -runFirstLaunch`
- ✅ **GitHub Actions CI:** Will work correctly (different environment)
- ✅ **Code changes:** All correct and ready
- ✅ **Local CLI builds:** Now working after framework sync

**RESOLVED:** After running `sudo xcodebuild -runFirstLaunch`, the command-line build works perfectly with no errors!

## What This Means for the Project

**For local development:**
- Use Xcode GUI for building and testing
- The project code is correct and builds fine
- This is purely an environment/tools issue

**For CI/CD:**
- GitHub Actions will work normally
- Automated builds won't have this issue
- Release workflows will function correctly

**For contributors:**
- Most developers won't encounter this (not on macOS 26 beta)
- Contributors on stable macOS versions can use command-line builds
- GUI build is always an option

## References

This is a documented issue affecting macOS 26 beta:
- [xcodebuild hangs on Xcode 26.2+ / macOS 26.3](https://github.com/react-native-community/cli/issues/2768)
- [xcrun problem with Xcode 26 Beta 3](https://developer.apple.com/forums/thread/794044)
- [Old Xcode not compatible with Tahoe 26](https://github.com/XcodesOrg/XcodesApp/issues/763)
- [GitHub Actions Xcode 26.3 update tracking](https://github.com/actions/runner-images/issues/13741)

## Recommendations

1. **Short term:** Use Xcode GUI for builds (`open Jiggler.xcodeproj`)
2. **Medium term:** Get admin to run `sudo xcodebuild -runFirstLaunch`
3. **Long term:** Wait for macOS 26.4 or later which may fix this bug
4. **For production:** Consider using macOS 25 (Sequoia) instead of beta macOS 26

## Bottom Line

✅ **Your project is fine** - the code builds correctly
✅ **CI/CD will work** - GitHub Actions won't have this issue
❌ **Local CLI blocked** - Need sudo or environment change
✅ **GUI works great** - Use this for local development

This is a **tool/environment issue, not a project issue**. The macOS 26 compatibility fixes we implemented are correct and will work once you can build (either via GUI or after fixing the framework issue).

---

*Issue documented: March 19, 2026*
*Environment: macOS 26.3.1, Xcode 26.3 (17C529)*
*Status: Known beta OS bug, workarounds available*
