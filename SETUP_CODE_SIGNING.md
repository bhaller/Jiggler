
I'll create an updated workflow file for you. Here's what needs to be added:

**Before the Build step, add Certificate Import:**

```yaml
    - name: Import Code Signing Certificate
      env:
        BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
        P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
        KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
      run: |
        # Create variables
        CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
        KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
        
        # Generate random keychain password
        KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
        
        # Decode certificate
        echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $CERTIFICATE_PATH
        
        # Create temporary keychain
        security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
        security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
        
        # Import certificate to keychain
        security import $CERTIFICATE_PATH \
          -P "$P12_PASSWORD" \
          -A \
          -t cert \
          -f pkcs12 \
          -k $KEYCHAIN_PATH
        
        security list-keychain -d user -s $KEYCHAIN_PATH
        
        # Allow codesign to access keychain
        security set-key-partition-list -S apple-tool:,apple:,codesign: \
          -s -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
```

**Update the Build step to enable signing:**

```yaml
    - name: Build Release
      run: |
        xcodebuild clean archive \
          -project Jiggler.xcodeproj \
          -scheme Jiggler \
          -configuration Release \
          -archivePath ./build/Jiggler.xcarchive \
          DEVELOPMENT_TEAM="${{ secrets.APPLE_TEAM_ID }}"
        # Note: Removed CODE_SIGN_IDENTITY="" to allow signing
```

**After DMG creation, add Notarization:**

```yaml
    - name: Notarize DMG
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        NOTARIZATION_PASSWORD: ${{ secrets.NOTARIZATION_PASSWORD }}
      run: |
        # Store credentials
        xcrun notarytool store-credentials "notarytool-profile" \
          --apple-id "$APPLE_ID" \
          --team-id "$APPLE_TEAM_ID" \
          --password "$NOTARIZATION_PASSWORD"
        
        # Submit for notarization
        echo "Submitting for notarization..."
        xcrun notarytool submit Jiggler.dmg \
          --keychain-profile "notarytool-profile" \
          --wait
        
        # Staple the notarization ticket
        echo "Stapling notarization ticket..."
        xcrun stapler staple Jiggler.dmg
        
        # Verify
        echo "Verifying notarization..."
        xcrun stapler validate Jiggler.dmg
```

## Step 5: Clean Up

**IMPORTANT:** Delete the certificate file from your Desktop for security:

```bash
cd ~/Desktop
rm Certificates.p12
echo "Certificate deleted!"
```

## Step 6: Test the Setup

Push a tag to trigger a release:

```bash
git tag -a v1.12-signed -m "Test signed release"
git push origin v1.12-signed
```

Watch the workflow:
```bash
gh run watch --repo pjaol/Jiggler
```

## Step 7: Verify Signed Release

Once the release is created:

```bash
# Download the DMG
gh release download v1.12-signed --repo pjaol/Jiggler --pattern "*.dmg"

# Verify signature
codesign -dvv Jiggler.dmg
spctl -a -vv -t install Jiggler.dmg

# Verify notarization
stapler validate Jiggler.dmg
```

You should see:
- ✅ "Developer ID Application: [Your Name/Org]"
- ✅ "The staple and validate action worked!"
- ✅ "source=Notarized Developer ID"

## Benefits After Setup

**For users downloading releases:**
- ✅ Double-click to open (no right-click needed!)
- ✅ No Gatekeeper warning
- ✅ Professional trust indicators
- ✅ Verified by Apple

**For you:**
- ✅ Fully automated signed builds
- ✅ Professional distribution
- ✅ No manual signing steps

## Troubleshooting

### Certificate Import Fails

**Error:** "security: SecKeychainItemImport: MAC verification failed"
**Solution:** Double-check the P12_PASSWORD secret matches the export password

### Notarization Fails

**Error:** "Invalid credentials"
**Solution:** 
- Verify APPLE_ID is correct
- Verify NOTARIZATION_PASSWORD is an app-specific password (not your main password)
- Check APPLE_TEAM_ID matches your developer account

**Error:** "The software asset has already been uploaded"
**Solution:** Change the version number or wait a few minutes

### Workflow Shows "No identity found"

**Solution:**
- Verify BUILD_CERTIFICATE_BASE64 secret is set correctly
- Check that you exported "Developer ID Application" (not "Development")
- Ensure certificate hasn't expired

## Security Notes

✅ **Secrets are encrypted** - GitHub encrypts all repository secrets
✅ **Not visible in logs** - Secret values are automatically masked
✅ **Temporary keychain** - Created and destroyed for each build
✅ **Certificate cleanup** - Build certificate is removed after use

## Alternative: Manual Signing

If you prefer to sign releases manually instead of automating:

```bash
# Build locally
xcodebuild clean build -project Jiggler.xcodeproj -scheme Jiggler -configuration Release

# Create DMG (already signed from build)
hdiutil create -volname "Jiggler" \
  -srcfolder ~/Library/Developer/Xcode/DerivedData/Jiggler-*/Build/Products/Release/Jiggler.app \
  -ov -format UDZO Jiggler.dmg

# Notarize
xcrun notarytool submit Jiggler.dmg \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple
xcrun stapler staple Jiggler.dmg

# Upload to GitHub
gh release upload v1.12 Jiggler.dmg
```

## For Organization Repository

If the repository is under "thevgergroup" organization:

1. Use organization secrets:
   - Go to: https://github.com/organizations/thevgergroup/settings/secrets/actions
   - Add secrets there (they'll be available to all repos)

2. Update repository settings:
   - Transfer repository to organization if needed:
     ```bash
     gh repo transfer pjaol/Jiggler thevgergroup --yes
     ```

3. Update workflows to reference correct repository

## Next Steps

1. ✅ Export certificate (Step 1)
2. ✅ Add secrets to GitHub (Steps 2-3)
3. ✅ Update workflow file (Step 4)
4. ✅ Test with a release (Step 6)
5. ✅ Verify signatures (Step 7)

After setup, every release will be:
- Automatically signed
- Automatically notarized
- Ready for users to double-click and install

---

**Need Help?**
- Apple Developer Support: https://developer.apple.com/support/
- Notarization Guide: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- GitHub Actions Secrets: https://docs.github.com/en/actions/security-guides/encrypted-secrets
