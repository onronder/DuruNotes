#!/bin/bash

echo "🎨 App Icon Update Script for Duru Notes"
echo "========================================"

# Check if new icon file is provided
if [ "$1" == "" ]; then
    echo "ℹ️  Usage: ./update_app_icon.sh <path_to_new_icon.png>"
    echo ""
    echo "Please provide the path to your new app icon (app_icon.png)"
    echo "The icon should be at least 1024x1024 pixels for best results."
    exit 1
fi

NEW_ICON_PATH="$1"

# Check if the new icon file exists
if [ ! -f "$NEW_ICON_PATH" ]; then
    echo "❌ Error: File not found at $NEW_ICON_PATH"
    exit 1
fi

echo ""
echo "📁 Step 1: Backing up existing icon..."
# Create backup with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -f "design/app_icon.png" ]; then
    cp design/app_icon.png "design/app_icon_backup_$TIMESTAMP.png"
    echo "✅ Existing icon backed up to: design/app_icon_backup_$TIMESTAMP.png"
else
    echo "⚠️  No existing icon found to backup"
fi

echo ""
echo "📋 Step 2: Copying new icon..."
cp "$NEW_ICON_PATH" design/app_icon.png
echo "✅ New icon copied to: design/app_icon.png"

echo ""
echo "🔧 Step 3: Generating platform-specific icons..."
echo "This will create all required icon sizes for iOS and Android"
flutter pub get
flutter pub run flutter_launcher_icons

echo ""
echo "🎯 Step 4: Verifying icon generation..."

# Check iOS icons
if [ -f "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" ]; then
    echo "✅ iOS icons generated successfully"
else
    echo "⚠️  iOS icon generation may have issues"
fi

# Check Android icons
if [ -f "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" ]; then
    echo "✅ Android icons generated successfully"
else
    echo "⚠️  Android icon generation may have issues"
fi

echo ""
echo "📱 Step 5: Platform-specific notes:"
echo ""
echo "iOS:"
echo "  - Icons have been updated in ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "  - The following sizes were generated:"
echo "    • 20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024"
echo "    • Each in @1x, @2x, @3x variants where applicable"
echo ""
echo "Android:"
echo "  - Icons have been updated in android/app/src/main/res/"
echo "  - The following densities were generated:"
echo "    • mipmap-mdpi (48x48)"
echo "    • mipmap-hdpi (72x72)"
echo "    • mipmap-xhdpi (96x96)"
echo "    • mipmap-xxhdpi (144x144)"
echo "    • mipmap-xxxhdpi (192x192)"

echo ""
echo "🧹 Step 6: Cleaning build cache..."
echo "It's recommended to clean and rebuild after changing app icons"
cd ios && pod install && cd ..
flutter clean
flutter pub get

echo ""
echo "✨ Icon update complete!"
echo ""
echo "Next steps:"
echo "1. Run 'flutter build ios' to see the new icon on iOS"
echo "2. Run 'flutter build android' to see the new icon on Android"
echo "3. For iOS, you may need to reset the simulator to see the new icon immediately"
echo "4. For Android, uninstall and reinstall the app to see the new icon"
echo ""
echo "💡 Tip: If the icon doesn't update immediately on your device/simulator:"
echo "  - iOS: Delete the app and reinstall"
echo "  - Android: Clear app data or uninstall/reinstall"
echo "  - Both: You can also try 'flutter clean' followed by rebuild"
