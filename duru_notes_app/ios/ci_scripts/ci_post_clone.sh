#!/bin/sh

# Xcode Cloud Post-Clone Script - ULTIMATE FLUTTER FIX
set -e

echo "Starting ci_post_clone.sh script..."

# Navigate to iOS directory
cd "$CI_PRIMARY_REPOSITORY_PATH/duru_notes_app/ios"

echo "Current directory: $(pwd)"

# List directory contents for debugging
echo "Listing directory contents:"
ls -la

# Check if CocoaPods is installed
if command -v pod >/dev/null 2>&1; then
    echo "CocoaPods is already installed"
else
    echo "Installing CocoaPods..."
    gem install cocoapods
fi

# Install Flutter if not present
if [ ! -d "/Users/local/flutter" ]; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git /Users/local/flutter
else
    echo "Flutter already installed"
fi

# Set Flutter path
export PATH="/Users/local/flutter/bin:$PATH"

# Download Flutter dependencies
echo "Downloading Flutter dependencies..."
/Users/local/flutter/bin/flutter doctor -v

# CRITICAL: Download iOS artifacts BEFORE anything else
echo "Precaching iOS artifacts..."
/Users/local/flutter/bin/flutter precache --ios

# ULTIMATE FIX: Let Flutter generate its own framework setup
echo "🚨 ULTIMATE FIX: Running Flutter build to generate proper framework structure..."

# Navigate to Flutter project root for build
cd ..

# Clean any previous builds
rm -rf ios/Flutter/ephemeral/* 2>/dev/null || true

# Generate Flutter framework properly using Flutter's own tools
echo "📱 Building Flutter framework using Flutter tools..."
/Users/local/flutter/bin/flutter build ios --no-codesign --release

# Navigate back to iOS directory
cd ios

# At this point Flutter should have generated its own framework structure
echo "🔍 Checking Flutter framework structure..."
if [ -d "Flutter/ephemeral/Flutter.framework" ]; then
    echo "✅ Flutter framework exists"
    ls -la Flutter/ephemeral/Flutter.framework/
else
    echo "⚠️ Flutter framework not in ephemeral, checking other locations..."
    find Flutter -name "Flutter.framework" -type d 2>/dev/null || echo "No Flutter.framework found"
fi

# Check if Flutter generated its build products
if [ -d "../build/ios" ]; then
    echo "✅ Flutter build directory exists"
    ls -la ../build/ios/
else
    echo "⚠️ No Flutter build directory found"
fi

# Now run Flutter pub get to ensure dependencies are resolved
echo "Running flutter pub get..."
cd ..
/Users/local/flutter/bin/flutter pub get
cd ios

# Clean any existing pods to force fresh installation
echo "Cleaning existing pods..."
rm -rf Pods Podfile.lock 2>/dev/null || true

# CRITICAL: Let Flutter set up the iOS integration properly
echo "🔧 Setting up Flutter iOS integration..."
cd ..
/Users/local/flutter/bin/flutter build ios --config-only
cd ios

# Now run pod install - Flutter should have set everything up correctly
echo "Running pod install..."
pod install --repo-update

echo "Pod installation completed"

# Verify Flutter pod exists now
if [ -d "Pods/Flutter" ]; then
    echo "✅ Flutter pod directory exists"
    ls -la Pods/Flutter/ 2>/dev/null || echo "Flutter pod empty"
else
    echo "⚠️ Still no Flutter pod directory"
    echo "Available pods:"
    ls -la Pods/ | head -10
fi

# Final verification of framework
echo "🔍 Final Flutter framework verification..."
if [ -d "Flutter/ephemeral/Flutter.framework" ]; then
    echo "✅ Flutter.framework in ephemeral"
    if [ -f "Flutter/ephemeral/Flutter.framework/Flutter" ]; then
        echo "✅ Flutter binary exists"
    fi
    if [ -f "Flutter/ephemeral/Flutter.framework/Headers/Flutter.h" ]; then
        echo "✅ Flutter.h header exists"
    fi
elif [ -f "Flutter/Flutter.framework/Flutter" ]; then
    echo "✅ Flutter.framework in Flutter directory"
else
    echo "⚠️ Searching for Flutter framework..."
    find . -name "Flutter.framework" -type d 2>/dev/null || echo "No Flutter framework found anywhere"
fi

echo "ci_post_clone.sh script completed successfully"