# Jiggler

> A free macOS utility to keep your Mac awake

[![Build Status](https://github.com/pjaol/Jiggler/actions/workflows/build.yml/badge.svg)](https://github.com/pjaol/Jiggler/actions)
[![macOS](https://img.shields.io/badge/macOS-10.15%2B-blue)](https://github.com/pjaol/Jiggler/releases)
[![License](https://img.shields.io/badge/license-GPL%20v3-green)](LICENSE)

**Jiggler** is a simple menu bar application that prevents your Mac from going to sleep, activating the screensaver, or dimming the display. Perfect for presentations, long downloads, video rendering, or any task where you need your Mac to stay awake without changing system settings.

## Features

### Three Jiggle Modes

- **Standard Jiggle** - Moves the mouse cursor slightly every few seconds
- **Zen Jiggle** - Keeps your Mac awake without moving the cursor (invisible to the user)
- **Click Jiggle** - Simulates mouse clicks without cursor movement

### Smart Conditional Jiggling

Jiggler can automatically enable/disable based on:

- **CPU Usage** - Only jiggle when CPU usage is above a threshold
- **Music Playback** - Jiggle when iTunes/Music is playing
- **Battery Status** - Only jiggle when on AC power
- **Running Applications** - Jiggle when specific apps are running
- **Screen Lock Status** - Respect screen lock settings

### Additional Features

- **Timed Quit** - Automatically stop jiggling after a specified duration
- **Menu Bar Icon** - Visual feedback with color-coded status
  - Normal: Default icon
  - Green: Actively jiggling
  - Red: Timed quit active
- **Overlay Window** - Optional visual indicator when jiggling is active
- **Configurable Settings** - Adjust jiggle interval, distance, and conditions

## Installation

### Download

**Latest Release:** [Jiggler v1.11](https://github.com/pjaol/Jiggler/releases/latest)

Choose either:
- **Jiggler.dmg** - Disk image installer
- **Jiggler.zip** - Simple archive

### Important: First-Time Launch

**This app is unsigned**, so macOS Gatekeeper will block it on first launch.

**For DMG:**
1. Download and open `Jiggler.dmg`
2. Drag Jiggler to Applications folder
3. **Right-click** on Jiggler.app in Applications
4. Select **"Open"** from the context menu
5. Click **"Open"** in the security dialog
6. After this first time, you can launch normally

**For ZIP:**
1. Download and extract `Jiggler.zip`
2. Move Jiggler.app to Applications folder
3. **Right-click** on Jiggler.app
4. Select **"Open"** from the context menu
5. Click **"Open"** in the security dialog

**Why is this needed?**
This build is not code-signed with an Apple Developer certificate (costs $99/year). The app is safe and open-source - you're just telling macOS you trust it by using right-click → Open instead of double-clicking.

### Permissions Required

Jiggler needs **Accessibility permissions** to control the mouse:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Find **Jiggler** in the list
3. Toggle it **ON**
4. Restart Jiggler

## Usage

### Basic Usage

1. **Launch Jiggler** - Look for the stick figure icon in your menu bar
2. **Click the icon** - Access the menu
3. **Enable "Master Switch"** - Start jiggling
4. The icon turns **green** when actively jiggling

### Configure Settings

Click the menu bar icon → **Preferences** to access:

- **Jiggle Style** - Standard, Zen, or Click mode
- **Jiggle Timing** - How often to jiggle (5 seconds to 24 hours)
- **Jiggle Distance** - How far to move the cursor
- **Conditional Settings** - CPU, battery, apps, etc.
- **Launch at Login** - Start automatically when you log in

### Timed Quit

Need Jiggler to run for a specific duration?

1. Click menu bar icon → **Timed Quit**
2. Set hours and minutes
3. The icon turns **red** to indicate timed mode
4. Jiggler will automatically quit when time expires

## System Requirements

- macOS 10.15 (Catalina) or later
- Apple Silicon (M1/M2/M3) and Intel Macs supported
- Tested on macOS 26 (Tahoe), 15 (Sequoia), and 14 (Sonoma)

## Building from Source

### Prerequisites

- Xcode 12 or later
- macOS 10.15+ SDK

### Build Instructions

```bash
# Clone the repository
git clone https://github.com/pjaol/Jiggler.git
cd Jiggler

# Build with Xcode
open Jiggler.xcodeproj
# Press ⌘+B to build, ⌘+R to run

# Or build from command line
xcodebuild -project Jiggler.xcodeproj \
  -scheme Jiggler \
  -configuration Release
```

The built app will be in:
```
~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app
```

## Documentation

- **[MODERNIZATION.md](MODERNIZATION.md)** - Recent changes and improvements
- **[CODE_SIGNING.md](CODE_SIGNING.md)** - How to sign and notarize the app
- **[CONTRIBUTING.md](.github/CONTRIBUTING.md)** - Guidelines for contributors
- **[AUTOMATION_SUMMARY.md](AUTOMATION_SUMMARY.md)** - CI/CD automation details

## Contributing

Contributions are welcome! This project now has automated builds and PR validation.

### How to Contribute

1. **Fork** this repository
2. **Create a branch** for your feature
3. **Make your changes** with clear commit messages
4. **Push** to your fork
5. **Open a Pull Request**

Our CI will automatically:
- Build your changes
- Run code quality checks
- Report any issues

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for detailed guidelines.

## Known Issues & Limitations

- **Unsigned Build:** Requires right-click → Open on first launch (Gatekeeper warning)
- **Accessibility Required:** Needs accessibility permissions to function
- **iTunes References:** Some UI still references "iTunes" instead of "Music.app"

See the [issue tracker](https://github.com/pjaol/Jiggler/issues) for more details.

## Changelog

### Version 1.11 (March 2026)
- **Fixed:** Zen jiggle mode compatibility with macOS 26 (Tahoe)
- **Updated:** Power management API to modern `IOPMAssertionDeclareUserActivity()`
- **Removed:** Deprecated `UpdateSystemActivity()` calls
- **Added:** GitHub Actions CI/CD automation
- **Improved:** Documentation and build processes

### Version 1.10 (November 2025)
- General code and logic cleanup
- Bug fixes for macOS 15 compatibility

[Full changelog](https://github.com/pjaol/Jiggler/releases)

## License

Copyright © 2025 Ben Haller. All rights reserved.

Jiggler is free software licensed under the [GNU General Public License v3.0](LICENSE).

You can redistribute it and/or modify it under the terms of the GPL v3 as published by the Free Software Foundation. See the [LICENSE](LICENSE) file for details.

## Links

- **Original Project:** [bhaller/Jiggler](https://github.com/bhaller/Jiggler)
- **Home Page:** [sticksoftware.com/software/Jiggler.html](http://www.sticksoftware.com/software/Jiggler.html)
- **Stick Software:** [www.sticksoftware.com](http://www.sticksoftware.com)

## About

Jiggler is a [Stick Software](http://www.sticksoftware.com) product. If you like it, please check out their other software!

This fork includes modern CI/CD automation, macOS 26 compatibility fixes, and improved documentation. The core Jiggler functionality and user experience remain unchanged.

## Show Your Support

If Jiggler helps you, consider:
- Starring this repository
- Contributing bug fixes or features
- Reporting issues to help improve it
- Sharing it with others who might find it useful

---

**Note:** This is a community-maintained fork with modern build automation and macOS 26 support. The original project by Ben Haller can be found at [bhaller/Jiggler](https://github.com/bhaller/Jiggler).
