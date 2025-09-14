# App Icon Update Guide for Duru Notes

## Quick Update Instructions

### Option 1: Automatic Update (Recommended)

1. **Place your new app_icon.png file** in the project directory
2. **Run the update script**:
   ```bash
   ./update_app_icon.sh app_icon.png
   ```

### Option 2: Manual Update

1. **Replace the icon file**:
   ```bash
   # Backup existing icon
   cp design/app_icon.png design/app_icon_old_backup.png
   
   # Copy your new icon to the design folder
   cp app_icon.png design/app_icon.png
   ```

2. **Generate all icon sizes**:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

3. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   ```

## Icon Requirements

For best results, your app_icon.png should be:
- **Size**: 1024x1024 pixels (minimum)
- **Format**: PNG with transparency support
- **Design**: Square format (will be automatically rounded on iOS)
- **Safe area**: Keep important elements within the center 80% to account for platform masks

## Generated Icon Locations

### iOS Icons
Located in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Generated sizes:
- 20x20 (@1x, @2x, @3x)
- 29x29 (@1x, @2x, @3x)
- 40x40 (@1x, @2x, @3x)
- 60x60 (@2x, @3x)
- 76x76 (@1x, @2x)
- 83.5x83.5 (@2x)
- 1024x1024 (@1x)

### Android Icons
Located in: `android/app/src/main/res/`

Generated densities:
- mipmap-mdpi (48x48)
- mipmap-hdpi (72x72)
- mipmap-xhdpi (96x96)
- mipmap-xxhdpi (144x144)
- mipmap-xxxhdpi (192x192)

## Verification Steps

### iOS
1. Build the iOS app:
   ```bash
   flutter build ios
   ```
2. Open in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. Check the app icon in:
   - Project navigator → Runner → Assets.xcassets → AppIcon

### Android
1. Build the Android app:
   ```bash
   flutter build apk
   ```
2. Check icons in Android Studio or directly in:
   ```bash
   ls -la android/app/src/main/res/mipmap-*/
   ```

## Troubleshooting

### Icon not updating on device/simulator?

**iOS:**
- Delete the app from simulator/device
- Clean build folder: `flutter clean`
- Rebuild and reinstall

**Android:**
- Uninstall the app completely
- Clear app data and cache
- Run `flutter clean`
- Rebuild and reinstall

### Icon appears stretched or distorted?

- Ensure your source icon is exactly square (1:1 ratio)
- Check that the image is at least 1024x1024 pixels
- Verify PNG format with transparency

### Platform-specific considerations

**iOS:**
- iOS automatically applies rounded corners
- Don't include rounded corners in your design
- Apple may reject icons with alpha channels/transparency in the App Store icon (1024x1024)

**Android:**
- Android 8.0+ supports adaptive icons
- Consider creating adaptive icon layers for better system integration
- Background and foreground layers can be configured separately

## Configuration File

The icon configuration is in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "design/app_icon.png"
  # Optional configurations:
  # android_adaptive_icon_background: "#ffffff"
  # android_adaptive_icon_foreground: "design/app_icon_foreground.png"
  # ios_remove_alpha_channel: true  # For App Store submission
```

## Next Steps

After updating the icon:

1. **Test on devices**: Install on real devices to verify appearance
2. **Check different themes**: Test with light/dark mode
3. **App Store/Play Store**: Update store listings with new icon
4. **Marketing materials**: Update any promotional materials

---

*Icon update completed on: [Current Date]*
