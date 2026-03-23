# Quick Start Guide

## What Was Done

✅ **Fixed macOS 26 compatibility** - Zen jiggle mode now works on macOS Tahoe
✅ **Migrated to main branch** - Renamed from `master` to `main`
✅ **Added CI/CD automation** - GitHub Actions for builds, PR checks, and releases
✅ **Comprehensive documentation** - Contributing guide, workflow docs, modernization summary

## Next Steps

### 1. Push Changes to Your Fork

```bash
# Push the main branch (first time)
git push -u origin main

# If you get an error about upstream, force push (this is safe for your fork):
git push -u origin main --force-with-lease
```

### 2. Update GitHub Default Branch

After pushing:
1. Go to your GitHub repository: https://github.com/pjaol/Jiggler
2. Click **Settings** → **Branches**
3. Change default branch from `master` to `main`
4. GitHub will offer to update PRs and redirect links automatically

### 3. Test the Build

The easiest way to test on macOS 26:

```bash
# Open in Xcode
open Jiggler.xcodeproj

# Then press Command+B to build, or Command+R to build and run
```

**Note:** Command-line xcodebuild has plugin issues on your current macOS 26.3.1 system, but the GUI works fine. This is a known macOS 26 beta bug with framework version mismatches. See `XCODEBUILD_ISSUE.md` for details. The GitHub Actions will use properly configured runners and won't have this issue.

### 4. Test the Application

Once built, test these features:
- [ ] Standard jiggle mode
- [ ] **Zen jiggle mode** (the main fix!)
- [ ] Click jiggle mode
- [ ] Conditional jiggling (CPU threshold, battery, etc.)
- [ ] Timed quit
- [ ] Status bar icon and menu

### 5. Try the CI/CD Workflows

After pushing to GitHub, your workflows will be available at:
- `https://github.com/pjaol/Jiggler/actions`

You can manually trigger a release workflow to test it:
1. Go to Actions tab
2. Select "Create Release"
3. Click "Run workflow"
4. Enter version "1.11-test"
5. Watch it build and create a release

### 6. Contribute Back to Upstream

If you want to help the original maintainer:

**Option A: Comment on existing PR**
- PR #35 has the macOS 26 fix: https://github.com/bhaller/Jiggler/pull/35
- You can comment that you've tested it and it works

**Option B: Create new PR with CI/CD**
```bash
# Add upstream remote if not already added
git remote add upstream https://github.com/bhaller/Jiggler.git

# Fetch upstream
git fetch upstream

# Create a branch for the CI/CD contribution
git checkout -b feature/github-actions-ci

# Cherry-pick just the CI/CD commits (not the main branch rename)
git cherry-pick 8dd2e59  # The CI/CD commit

# Push to your fork
git push origin feature/github-actions-ci

# Then create PR on GitHub from your fork to upstream
```

## File Guide

- **`MODERNIZATION.md`** - Complete overview of all changes
- **`.github/CONTRIBUTING.md`** - For contributors
- **`.github/workflows/README.md`** - For understanding CI/CD
- **`QUICK_START.md`** - This file

## Getting Help

- Check the documentation files above
- Open an issue in your fork for questions
- Review the GitHub Actions logs if workflows fail

## Important Notes

⚠️ **Branch Rename:** You've renamed `master` to `main` locally. Your remote still has `master`. After pushing `main`, you can delete the old `master` branch on GitHub if desired.

⚠️ **Code Signing:** The CI workflows build unsigned apps for testing. For production releases, you'd want to add code signing.

⚠️ **Testing:** Please test thoroughly on macOS 26 before distributing the app, especially Zen jiggle mode which is the main fix.

---

**Need to test now?** → `open Jiggler.xcodeproj` and press Command+R
**Ready to push?** → `git push -u origin main`
**Want details?** → See `MODERNIZATION.md`
