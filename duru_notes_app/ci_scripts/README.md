# Xcode Cloud CI/CD Scripts for Duru Notes

This directory contains the CI/CD scripts and configurations for building Duru Notes iOS app on Xcode Cloud.

## Overview

These scripts fix the common Xcode Cloud CI/CD issues for Flutter iOS apps:

1. **Missing CI Scripts**: Xcode Cloud expects `ci_pre_xcodebuild.sh` and `ci_post_xcodebuild.sh`
2. **Missing Flutter Configuration**: `ios/Flutter/Generated.xcconfig` not being generated in CI
3. **CocoaPods Sync Issues**: Pods directory not properly regenerated in CI
4. **Build Script Warnings**: CocoaPods scripts lacking output file specifications

## Files

### `ci_pre_xcodebuild.sh`
**Main CI script that runs before Xcode builds the iOS app**

- Installs Flutter 3.35.2 (stable channel)
- Runs `flutter pub get` to install dependencies
- Generates iOS configuration with `flutter build ios --config-only`
- Installs CocoaPods dependencies with `pod install`
- Verifies all required files exist
- Provides detailed logging and error handling

### `ci_post_xcodebuild.sh`
**Post-build script for verification and cleanup**

- Checks build success/failure status
- Logs build artifacts and app size information
- Provides debugging information if build fails
- Performs cleanup of temporary files
- Generates comprehensive build reports

### `disable_pods_resources.py`
**Helper script to fix CocoaPods resource warnings**

- Fixes the "Run script build phase '[CP] Copy Pods Resources' will be run during every build" warning
- Adds proper output file specifications to Xcode project
- Creates backup before making changes
- Can be run manually if needed

## Usage

### Automatic (Xcode Cloud)

These scripts are automatically executed by Xcode Cloud when you push to the `main` branch:

1. `ci_pre_xcodebuild.sh` runs before the build
2. Xcode builds the iOS app
3. `ci_post_xcodebuild.sh` runs after the build

### Manual Testing (Local Development)

Use the `flutter_build.sh` script in the project root to test locally:

```bash
# Basic build test
./flutter_build.sh

# Clean build with verbose output
./flutter_build.sh --clean --verbose

# Skip tests and only build iOS
./flutter_build.sh --skip-tests

# Get help
./flutter_build.sh --help
```

### Manual CocoaPods Fix

If you encounter CocoaPods warnings locally:

```bash
# Run the CocoaPods fix script
cd ci_scripts
python3 disable_pods_resources.py
```

## Configuration

### Environment Variables

The following environment variables are set in `.xcode-cloud-config.json`:

- `FLUTTER_VERSION`: "3.35.2" (Flutter version to install)
- `COCOAPODS_PARALLEL_CODE_SIGN`: "true" (Enable parallel code signing)
- `COCOAPODS_DISABLE_STATS`: "true" (Disable CocoaPods analytics)
- `TREE_SHAKE_ICONS`: "false" (Disable icon tree shaking)
- `FLUTTER_BUILD_MODE`: "release" (Build in release mode)
- `CI`: "true" (Indicate CI environment)
- `XCODE_CLOUD`: "true" (Indicate Xcode Cloud environment)

### Required Files

The scripts ensure these critical files exist:

- `pubspec.lock` (Flutter dependencies)
- `ios/Flutter/Generated.xcconfig` (Flutter iOS configuration)
- `ios/Podfile.lock` (CocoaPods dependencies)
- `ios/Pods/` directory (CocoaPods installation)

## Troubleshooting

### Common Issues

1. **"The sandbox is not in sync with the Podfile.lock"**
   - Fixed by `ci_pre_xcodebuild.sh` running `pod install`

2. **"Run script build phase '[CP] Copy Pods Resources' will be run during every build"**
   - Fixed by optimized `ios/Podfile` and `disable_pods_resources.py`

3. **"Generated.xcconfig must exist"**
   - Fixed by `ci_pre_xcodebuild.sh` running `flutter build ios --config-only`

4. **Flutter not found in CI**
   - Fixed by `ci_pre_xcodebuild.sh` installing Flutter 3.35.2

### Debug Information

The scripts provide extensive logging:

- ✅ Success messages (green)
- ⚠️ Warning messages (yellow)  
- ❌ Error messages (red)
- 📊 Information messages (blue)

### Build Verification

The post-build script checks:

- App bundle size and location
- Framework dependencies
- Archive creation
- Flutter and CocoaPods versions
- Build artifacts and logs

## Dependencies

### Flutter Dependencies (from pubspec.yaml)

Key dependencies that require special handling:

- `google_mlkit_text_recognition` (Native iOS frameworks)
- `flutter_secure_storage` (Keychain access)
- `receive_sharing_intent` (Share extension support)
- `sentry_flutter` (Crash reporting)
- Various other native plugins

### iOS Configuration

- **Deployment Target**: iOS 14.0
- **Swift Version**: 5.0
- **Xcode Version**: Latest compatible
- **CocoaPods**: Latest stable

## Maintenance

### Updating Flutter Version

1. Update `FLUTTER_VERSION` in `.xcode-cloud-config.json`
2. Test locally with `flutter_build.sh`
3. Update this README if needed

### Adding New Dependencies

1. Add to `pubspec.yaml`
2. Test locally with `flutter_build.sh --clean`
3. Verify CI build works

### Modifying Scripts

1. Test changes locally first
2. Verify script permissions (`chmod +x`)
3. Test with `flutter_build.sh`
4. Update this documentation

## Support

If you encounter issues:

1. Check the Xcode Cloud build logs
2. Run `flutter_build.sh --verbose` locally
3. Verify all required files exist
4. Check Flutter and CocoaPods versions
5. Review this documentation

## Version History

- **v1.0**: Initial implementation
  - Created CI scripts for Xcode Cloud
  - Fixed CocoaPods sync issues
  - Added comprehensive logging and verification
  - Implemented local testing capabilities
