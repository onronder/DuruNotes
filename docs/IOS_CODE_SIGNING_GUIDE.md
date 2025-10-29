# iOS Code Signing Configuration Guide

## Current Status
The `ios/ExportOptions.plist` file contains placeholders that must be replaced before iOS deployment can succeed.

## Placeholders to Replace

### File: `ios/ExportOptions.plist`
```xml
Line 18: <string>YOUR_TEAM_ID</string>
Line 26: <string>YOUR_PROVISIONING_PROFILE_NAME</string>
Line 28: <string>YOUR_SHARE_EXTENSION_PROFILE_NAME</string>
```

## Option 1: Direct File Update (Recommended for Testing)

### Step 1: Find Your Team ID
1. Go to [Apple Developer Account](https://developer.apple.com/account/)
2. Navigate to "Membership" in the sidebar
3. Your Team ID is a 10-character string (e.g., `ABC123XYZ9`)

### Step 2: Find Your Provisioning Profile Names
1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Find the provisioning profile for:
   - **Main App**: `com.fittechs.duruNotesApp`
   - **Share Extension**: `com.fittechs.duruNotesApp.ShareExtension`
3. Copy the exact profile names

### Step 3: Update ExportOptions.plist
Replace the placeholders in `ios/ExportOptions.plist`:
```xml
<key>teamID</key>
<string>YOUR_ACTUAL_TEAM_ID</string>

<key>provisioningProfiles</key>
<dict>
    <key>com.fittechs.duruNotesApp</key>
    <string>Your Actual Main App Profile Name</string>
    <key>com.fittechs.duruNotesApp.ShareExtension</key>
    <string>Your Actual Share Extension Profile Name</string>
</dict>
```

### ⚠️ Security Note
If you commit these values to git, ensure they're not sensitive. Team IDs and profile names are generally safe to commit.

## Option 2: Dynamic Replacement in CI (Recommended for Production)

Add these secrets to GitHub Actions:
- `IOS_TEAM_ID`
- `IOS_PROVISIONING_PROFILE_NAME`
- `IOS_SHARE_EXTENSION_PROFILE_NAME`

Then modify `.github/workflows/deploy-production.yml` to replace placeholders before build:

```yaml
- name: Configure ExportOptions
  run: |
    sed -i '' 's/YOUR_TEAM_ID/${{ secrets.IOS_TEAM_ID }}/g' ios/ExportOptions.plist
    sed -i '' 's/YOUR_PROVISIONING_PROFILE_NAME/${{ secrets.IOS_PROVISIONING_PROFILE_NAME }}/g' ios/ExportOptions.plist
    sed -i '' 's/YOUR_SHARE_EXTENSION_PROFILE_NAME/${{ secrets.IOS_SHARE_EXTENSION_PROFILE_NAME }}/g' ios/ExportOptions.plist
```

## Option 3: Use Automatic Signing (Alternative)

If you prefer automatic signing (though not recommended for CI):

1. Update `ios/ExportOptions.plist`:
```xml
<key>signingStyle</key>
<string>automatic</string>
```

2. Remove the `provisioningProfiles` section entirely

**Note**: This requires Xcode to be logged in with your Apple ID, which doesn't work well in CI environments.

## Current Deployment Blocker

The iOS build in `.github/workflows/deploy-production.yml` line 177 uses:
```yaml
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

This will fail with placeholders. Choose Option 1 or Option 2 above before deploying.

## Verification

After updating, verify locally:
```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

If successful, the configuration is correct.
