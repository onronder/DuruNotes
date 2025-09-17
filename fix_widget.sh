#!/bin/bash

echo "🔧 Fixing iOS Widget Setup..."

# Clean everything first
echo "📱 Cleaning build artifacts..."
cd /Users/onronder/duru-notes
rm -rf build/ios
rm -rf ios/Pods
rm -rf ios/Podfile.lock
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Install pods
echo "🔨 Installing CocoaPods..."
cd ios
pod install

# Build with Flutter (without tree-shake for icons)
echo "🏗️ Building iOS app with widget..."
cd ..
flutter build ios --release --no-tree-shake-icons

# Now open Xcode for final build
echo "✅ Opening Xcode..."
echo "📝 IMPORTANT: In Xcode, please:"
echo "   1. Select 'Runner' scheme (not DuruNotesWidgetExtension)"
echo "   2. Select your device"
echo "   3. Press Cmd+R to run"
echo ""
echo "The widget should then appear in your widget gallery!"

open ios/Runner.xcworkspace
