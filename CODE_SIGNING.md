# Code Signing and Notarization Guide

## Current Status: Unsigned

The current builds are **unsigned**, which means:

### What Works ✅
- App functions perfectly on your own Mac
- You can run it locally without issues
- All features work correctly
- Automated builds work in CI/CD

### What Doesn't Work ❌
- **Gatekeeper will block it** when other users download it
- Users see: "Jiggler cannot be opened because it is from an unidentified developer"
- No automatic security verification
- Not listed in Security & Privacy settings properly

## User Experience Without Signing

When users download the unsigned app:

1. **Double-click Jiggler.app** → Gatekeeper blocks it
2. **Error message:** "Jiggler cannot be opened because it is from an unidentified developer"
3. **Workaround required:**
   - Right-click → Open
   - Click "Open" in the dialog
   - Or: System Settings → Privacy & Security → Click "Open Anyway"

This is **annoying but not a blocker** - users CAN still run it, just with extra steps.

## Why Sign and Notarize?

### Benefits of Signing
- App runs immediately when downloaded
- No scary warning messages
- Users trust it more
- Professional appearance
- Required for Mac App Store distribution

### Benefits of Notarization
- Apple verifies the app is malware-free
- Gatekeeper allows it to run immediately
- Better user experience
- Builds user trust

## How to Add Code Signing

### Prerequisites

You need:
1. **Apple Developer Account** ($99/year)
   - Sign up at: https://developer.apple.com/programs/
2. **Developer ID Certificate**
   - Type: "Developer ID Application"
   - For distributing outside the Mac App Store
3. **Xcode with your Apple ID signed in**

### Step 1: Get a Developer ID Certificate

```bash
# Open Xcode
# Go to: Xcode → Settings → Accounts
# Click your Apple ID → Manage Certificates
# Click + → Select "Developer ID Application"
# Certificate will be downloaded automatically
```

### Step 2: Update Project Settings

In Xcode:
1. Open `Jiggler.xcodeproj`
2. Select project → Jiggler target → Signing & Capabilities
3. Enable "Automatically manage signing"
4. Select your Team (your Apple ID)
5. Or manually select your "Developer ID Application" certificate

### Step 3: Update GitHub Actions Workflows

For signing in CI/CD, you need to:

1. **Export your certificate**
   ```bash
   # In Keychain Access:
   # Find "Developer ID Application: Your Name"
   # Right-click → Export → Save as .p12 file
   # Set a password
   ```

2. **Add secrets to GitHub**
   ```bash
   # Convert certificate to base64
   base64 -i certificate.p12 | pbcopy

   # Add to GitHub:
   # Settings → Secrets and variables → Actions → New repository secret
   # Name: BUILD_CERTIFICATE_BASE64
   # Value: (paste the base64 string)

   # Also add:
   # Name: P12_PASSWORD
   # Value: (your certificate password)
   ```

3. **Update workflow files**

Edit `.github/workflows/release.yml` to import the certificate before building:

```yaml
- name: Import Code Signing Certificate
  env:
    BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
    P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
  run: |
    # Create temporary keychain
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    KEYCHAIN_PASSWORD=$(uuidgen)

    # Decode certificate
    echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $RUNNER_TEMP/certificate.p12

    # Create keychain
    security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
    security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

    # Import certificate
    security import $RUNNER_TEMP/certificate.p12 \
      -P "$P12_PASSWORD" \
      -A \
      -t cert \
      -f pkcs12 \
      -k $KEYCHAIN_PATH

    security list-keychain -d user -s $KEYCHAIN_PATH

    # Set partition list
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
      -s -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

- name: Build Release
  run: |
    xcodebuild clean archive \
      -project Jiggler.xcodeproj \
      -scheme Jiggler \
      -configuration Release \
      -archivePath ./build/Jiggler.xcarchive
      # Remove CODE_SIGN_IDENTITY="" etc - let it sign naturally
```

### Step 4: Notarize the App

After building, notarize with Apple:

```bash
# Store credentials (one time)
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# Notarize (in CI/CD)
xcrun notarytool submit Jiggler.dmg \
  --keychain-profile "notarytool-profile" \
  --wait

# Staple the notarization ticket
xcrun stapler staple Jiggler.app
```

## Simplified Approach: Sign Releases Only

If you don't want to set up full CI/CD signing:

1. **Build releases locally on your Mac** (where you have the certificate)
2. **Sign and notarize manually**
3. **Upload to GitHub manually**

```bash
# Build
xcodebuild clean build \
  -project Jiggler.xcodeproj \
  -scheme Jiggler \
  -configuration Release

# Create DMG (already signed from build)
hdiutil create -volname "Jiggler" \
  -srcfolder ./build/Release/Jiggler.app \
  -ov -format UDZO Jiggler.dmg

# Notarize
xcrun notarytool submit Jiggler.dmg \
  --keychain-profile "notarytool-profile" \
  --wait

# Staple
xcrun stapler staple Jiggler.dmg

# Create release
gh release create v1.11 Jiggler.dmg --title "Jiggler 1.11" --notes "Release notes here"
```

## For the Original Maintainer

If you're submitting this to the upstream project, suggest:

1. **The maintainer should handle signing** (they likely already have a certificate)
2. **Document that unsigned builds are for testing**
3. **Only official releases should be signed**
4. **Keep the unsigned CI builds** for quick testing

## Alternative: Self-Signed for Testing

For personal/internal use only:

```bash
# Create self-signed certificate
# Keychain Access → Certificate Assistant → Create a Certificate
# Name: "Jiggler Developer"
# Identity Type: Self Signed Root
# Certificate Type: Code Signing

# Build with it (users still need to trust it manually)
xcodebuild build -project Jiggler.xcodeproj CODE_SIGN_IDENTITY="Jiggler Developer"
```

⚠️ **This doesn't help with Gatekeeper** - users still need to right-click → Open.

## Recommendation

**For your fork:**
- ✅ Keep unsigned builds in CI/CD (works for testing)
- ✅ Document that users need to right-click → Open
- ⏳ Add signing later if you distribute widely

**For upstream contribution:**
- ✅ Keep the CI/CD workflows unsigned (maintainer handles signing)
- ✅ Document the workflows are for automated testing
- ✅ Maintainer can add signing secrets if they want automated signed builds

## Current Release Status

Your v1.11 release at https://github.com/pjaol/Jiggler/releases is:
- ✅ Built successfully
- ✅ DMG and ZIP available
- ❌ Not signed
- ❌ Not notarized

**Users can still use it** by right-clicking → Open.

## Summary

| Scenario | Unsigned (Current) | Signed | Signed + Notarized |
|----------|-------------------|--------|-------------------|
| Local testing | ✅ Works | ✅ Works | ✅ Works |
| Downloaded by others | ⚠️  Right-click required | ⚠️  Right-click required | ✅ Works immediately |
| CI/CD builds | ✅ Easy | 🔧 Requires secrets | 🔧 Requires secrets + notarization |
| Cost | Free | $99/year | $99/year |
| Professional | ⚠️  Looks suspicious | ✅ Trusted | ✅✅ Fully trusted |

---

**Bottom line:** Unsigned works but isn't ideal for public distribution. For a personal fork, it's fine. For official releases, signing and notarization provide a much better user experience.
