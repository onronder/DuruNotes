#!/bin/sh

# Xcode Cloud Post-Clone Script for Flutter
# This script runs after the repository is cloned

set -e

echo "🚀 Starting Duru Notes post-clone setup..."

# Debug: Show current environment
echo "📍 Current directory: $(pwd)"
echo "📍 CI_WORKSPACE: ${CI_WORKSPACE:-'Not set'}"
echo "📁 Directory contents:"
ls -la

# Set up environment variables
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

# Install Flutter
if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
    flutter config --no-analytics
    flutter precache --ios
fi

# Verify Flutter
echo "✅ Flutter version:"
flutter --version

# Navigate to the Flutter project
echo "📂 Looking for Flutter project..."
if [ -d "duru_notes_app" ]; then
    cd duru_notes_app
    echo "📂 Found Flutter project in duru_notes_app/"
else
    echo "❌ duru_notes_app directory not found!"
    echo "📁 Available directories:"
    ls -la
    exit 1
fi

# Verify we're in the Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml not found in $(pwd)"
    exit 1
fi

echo "✅ Flutter project confirmed: $(pwd)"

# Clean and prepare
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate iOS configuration files
echo "🔧 Generating iOS configuration..."
flutter build ios --config-only --no-tree-shake-icons

# Navigate to iOS directory
cd ios

# Debug: Show iOS directory
echo "📱 iOS directory: $(pwd)"
echo "📁 iOS contents:"
ls -la

# Clean CocoaPods completely
echo "🍎 Cleaning CocoaPods..."
rm -rf Pods .symlinks Podfile.lock

# Install CocoaPods dependencies
echo "📦 Installing CocoaPods dependencies..."
pod install --repo-update

# Verify critical files exist
echo "🔍 Verifying generated files..."

# Check Generated.xcconfig
if [ -f "Flutter/Generated.xcconfig" ]; then
    echo "✅ Generated.xcconfig exists"
else
    echo "❌ Generated.xcconfig missing!"
    exit 1
fi

# Check CocoaPods resource files
PODS_TARGET_DIR="Pods/Target Support Files/Pods-Runner"
if [ -d "$PODS_TARGET_DIR" ]; then
    echo "✅ Pods Target Support Files directory exists"
    echo "📁 Contents:"
    ls -la "$PODS_TARGET_DIR/" | grep xcfilelist || echo "No xcfilelist files found"
    
    # Create the absolute path directory that Xcode Cloud expects
    echo "🔧 Creating absolute path structure for Xcode Cloud..."
    sudo mkdir -p "/Target Support Files/Pods-Runner" || mkdir -p "/tmp/Target Support Files/Pods-Runner"
    
    # Copy files to expected location
    if [ -f "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" ]; then
        sudo cp "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" "/Target Support Files/Pods-Runner/" 2>/dev/null || \
        cp "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" "/tmp/Target Support Files/Pods-Runner/" 2>/dev/null || \
        echo "⚠️ Could not copy input xcfilelist to absolute path"
    fi
    
    if [ -f "$PODS_TARGET_DIR/Pods-Runner-resources-Release-output-files.xcfilelist" ]; then
        sudo cp "$PODS_TARGET_DIR/Pods-Runner-resources-Release-output-files.xcfilelist" "/Target Support Files/Pods-Runner/" 2>/dev/null || \
        cp "$PODS_TARGET_DIR/Pods-Runner-resources-Release-output-files.xcfilelist" "/tmp/Target Support Files/Pods-Runner/" 2>/dev/null || \
        echo "⚠️ Could not copy output xcfilelist to absolute path"
    fi
    
    echo "✅ Attempted to fix absolute paths"
else
    echo "❌ Pods Target Support Files missing!"
    exit 1
fi

echo "✅ Post-clone setup completed successfully!"
echo "📊 Final verification:"
echo "   - Flutter project: $(pwd)/.."
echo "   - iOS project: $(pwd)"
echo "   - Generated.xcconfig: $(ls -la Flutter/Generated.xcconfig 2>/dev/null || echo 'Missing')"
echo "   - Pods directory: $(ls -ld Pods 2>/dev/null || echo 'Missing')"

# Return to project root
cd ../..