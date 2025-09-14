#!/bin/bash

echo "🔧 Fixing Adapty Flutter Architecture Issues"
echo "============================================"

cd ios

echo ""
echo "Step 1: Cleaning previous builds..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf Pods
rm -rf build
rm Podfile.lock 2>/dev/null

echo ""
echo "Step 2: Cleaning Flutter iOS build..."
cd ..
flutter clean
flutter pub get

echo ""
echo "Step 3: Reinstalling iOS pods with architecture fixes..."
cd ios

# Update pod repo
echo "Updating CocoaPods repository..."
pod repo update

# Install pods with proper architecture
echo "Installing pods..."
arch -x86_64 pod install --repo-update

echo ""
echo "Step 4: Fixing architecture settings in project..."
cd ..

echo ""
echo "✅ Architecture fix complete!"
echo ""
echo "Now try running the app again with:"
echo "  flutter run -d ios"
echo ""
echo "If the issue persists, try:"
echo "  1. Open Xcode: open ios/Runner.xcworkspace"
echo "  2. Select Runner project"
echo "  3. Go to Build Settings"
echo "  4. Search for 'Excluded Architectures'"
echo "  5. Add 'arm64' for 'Any iOS Simulator SDK' if running on M1/M2 Mac"
