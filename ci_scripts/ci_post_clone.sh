#!/bin/sh

# Xcode Cloud Post-Clone Script for Flutter
set -e

echo "🚀 Starting Duru Notes CI setup..."
echo "📍 Working directory: $(pwd)"
echo "📁 Contents:"
ls -la

# Install Flutter if needed
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
    flutter config --no-analytics
    flutter precache --ios
fi

echo "✅ Flutter version:"
flutter --version

# Navigate to Flutter project
cd duru_notes_app
echo "📂 In Flutter project: $(pwd)"

# Clean everything first
echo "🧹 Deep cleaning..."
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf ios/Flutter/Generated.xcconfig
rm -rf ios/Flutter/flutter_export_environment.sh

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate iOS configuration files
echo "🔧 Generating iOS configuration..."
flutter build ios --config-only --no-tree-shake-icons

# Navigate to iOS directory
cd ios
echo "📱 In iOS directory: $(pwd)"

# Ensure CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "📦 Installing CocoaPods..."
    sudo gem install cocoapods
fi

# Install Pods with verbose output
echo "🍎 Installing CocoaPods dependencies..."
pod install --repo-update --verbose

# Verify Podfile.lock exists
if [ ! -f "Podfile.lock" ]; then
    echo "❌ Podfile.lock not created!"
    exit 1
fi

echo "✅ Podfile.lock created successfully"

# Verify Pods directory exists
if [ ! -d "Pods" ]; then
    echo "❌ Pods directory not created!"
    exit 1
fi

echo "✅ Pods directory created successfully"

# List Pods contents for debugging
echo "📁 Pods structure:"
ls -la Pods/ | head -20

echo "✅ CI post-clone setup completed successfully!"