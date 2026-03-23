# GitHub Actions Workflows

This directory contains automated workflows for building, testing, and releasing Jiggler.

## Workflows

### 1. Build and Test (`build.yml`)

**Triggers:**
- Push to `main` branch
- Pull requests to `main`
- Manual trigger via workflow_dispatch

**What it does:**
- Checks out the code
- Sets up the latest stable Xcode
- Builds Jiggler in Release configuration
- Uploads build artifacts (retained for 30 days)
- Runs basic code quality checks

**Purpose:** Ensures every commit builds successfully and catches build regressions early.

### 2. PR Checks (`pr-checks.yml`)

**Triggers:**
- Pull request opened, synchronized, or reopened

**What it does:**
- Validates Xcode project structure
- Builds in Debug configuration
- Reports warnings and errors
- Checks for common code style issues
- Posts welcome comment on new PRs

**Purpose:** Helps contributors ensure their changes are ready for review before a maintainer looks at them.

### 3. Release (`release.yml`)

**Triggers:**
- Git tags matching `v*` (e.g., `v1.11`)
- Manual trigger with version number input

**What it does:**
- Builds Release configuration
- Creates DMG installer
- Creates ZIP archive
- Creates GitHub Release as draft
- Attaches DMG and ZIP to release

**Purpose:** Automates the release process, making it easy to distribute new versions.

## Using the Workflows

### For Contributors
- Your PRs will automatically trigger build and PR checks
- Watch for check results in the PR - they must pass before merge
- If checks fail, review the logs and fix the issues

### For Maintainers

#### Creating a Release

**Option 1: Using Git Tags**
```bash
# After committing all changes for the release
git tag -a v1.11 -m "Release version 1.11"
git push origin v1.11
```

**Option 2: Manual Workflow Trigger**
1. Go to Actions tab in GitHub
2. Select "Create Release" workflow
3. Click "Run workflow"
4. Enter version number (e.g., "1.11")
5. Click "Run workflow"

Both methods create a draft release that you can:
- Edit the release notes
- Test the DMG/ZIP downloads
- Publish when ready

#### Monitoring Builds
- Go to the Actions tab to see all workflow runs
- Click on any run to see detailed logs
- Failed builds show which step failed

## Workflow Configuration

### Code Signing
The workflows are currently configured to build **without code signing**:
- `CODE_SIGN_IDENTITY=""`
- `CODE_SIGNING_REQUIRED=NO`
- `CODE_SIGNING_ALLOWED=NO`

This allows CI to build successfully without certificates. For signed releases:
1. Add signing certificate to GitHub secrets
2. Modify workflows to use signing
3. See [Apple's code signing documentation](https://developer.apple.com/support/code-signing/)

### Build Artifacts
- Build artifacts are retained for 30 days
- Released DMG/ZIP files are retained indefinitely as release assets

## Troubleshooting

### Build Failures
- Check that the Xcode project builds locally first
- Ensure all source files are checked into git
- Verify project.pbxproj is not corrupted

### Workflow Not Running
- Check that workflows are enabled in repository settings
- Verify GitHub Actions is enabled for the repository
- Check branch protection rules don't block Actions

### Release Issues
- Ensure you have write permissions to the repository
- Verify `GITHUB_TOKEN` has appropriate permissions
- Check that tag format matches `v*` pattern

## Customization

### Xcode Version
To use a specific Xcode version, edit the workflow:
```yaml
- name: Set up Xcode
  uses: maxim-lobanov/setup-xcode@v1
  with:
    xcode-version: '15.0'  # Specify exact version
```

### Build Configuration
Modify the `xcodebuild` commands to change:
- Target SDK
- Deployment target
- Build settings
- Schemes

### Artifact Retention
Change retention period in `build.yml`:
```yaml
- name: Upload build artifacts
  uses: actions/upload-artifact@v4
  with:
    retention-days: 7  # Change from 30 to 7 days
```

## Future Enhancements

Potential improvements for these workflows:
- [ ] Add automated testing when tests are available
- [ ] Add code signing for release builds
- [ ] Add notarization for macOS 10.15+
- [ ] Add automated changelog generation
- [ ] Add dependency vulnerability scanning
- [ ] Add static analysis (clang-analyzer, etc.)
- [ ] Add build size tracking
- [ ] Add performance benchmarks

## Support

If you encounter issues with the workflows:
1. Check the workflow logs in the Actions tab
2. Review this documentation
3. Open an issue with workflow name and error details
