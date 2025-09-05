#!/bin/sh

# Xcode Cloud CI Pre-build Script for Flutter iOS App
# This script runs before Xcode builds the iOS app
# It installs Flutter, gets dependencies, and configures iOS

set -e

echo "🚀 Starting Xcode Cloud CI Pre-build Script"
echo "📅 $(date)"
echo "🖥️  Environment: $CI_XCODE_PROJECT_NAME"

# Environment variables
FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "📂 Script directory: $SCRIPT_DIR"
echo "📂 Project root: $PROJECT_ROOT"
echo "🔧 Flutter version: $FLUTTER_VERSION"

# Change to project root
cd "$PROJECT_ROOT"

# Check if Flutter is already installed
if command -v flutter >/dev/null 2>&1; then
    echo "✅ Flutter is already available"
    flutter --version
else
    echo "📦 Installing Flutter $FLUTTER_VERSION..."
    
    # Download and install Flutter
    FLUTTER_DIR="$HOME/flutter"
    if [ ! -d "$FLUTTER_DIR" ]; then
        echo "⬇️  Downloading Flutter..."
        git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    else
        echo "🔄 Updating existing Flutter installation..."
        cd "$FLUTTER_DIR"
        git fetch
        git checkout stable
        git pull
        cd "$PROJECT_ROOT"
    fi
    
    # Add Flutter to PATH
    export PATH="$FLUTTER_DIR/bin:$PATH"
    
    # Verify Flutter installation
    flutter --version
    echo "✅ Flutter installed successfully"
fi

# Configure Flutter
echo "⚙️  Configuring Flutter..."
flutter config --no-analytics
flutter config --enable-ios

# Verify Flutter doctor (but don't fail if there are warnings)
echo "🩺 Running Flutter doctor..."
flutter doctor || echo "⚠️  Flutter doctor completed with warnings (this is normal in CI)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Verify pubspec.lock exists
if [ ! -f "pubspec.lock" ]; then
    echo "❌ pubspec.lock not found after pub get"
    exit 1
fi

# Generate iOS configuration (this creates Flutter/Generated.xcconfig)
echo "🍎 Generating iOS configuration..."
flutter build ios --config-only --no-tree-shake-icons --verbose

# Navigate to iOS directory
cd ios

# Verify Generated.xcconfig was created and has content
GENERATED_CONFIG="Flutter/Generated.xcconfig"
if [ ! -f "$GENERATED_CONFIG" ]; then
    echo "❌ $GENERATED_CONFIG was not generated"
    echo "📂 Contents of Flutter directory:"
    ls -la Flutter/ || echo "Flutter directory does not exist"
    exit 1
fi

if [ ! -s "$GENERATED_CONFIG" ]; then
    echo "❌ $GENERATED_CONFIG is empty"
    exit 1
fi

echo "✅ Generated.xcconfig created successfully:"
echo "📄 Content preview:"
head -10 "$GENERATED_CONFIG"

# Check CocoaPods installation
if ! command -v pod >/dev/null 2>&1; then
    echo "📦 Installing CocoaPods..."
    gem install cocoapods --no-document
else
    echo "✅ CocoaPods is already installed"
    pod --version
fi

# CRITICAL FIX: Clean CocoaPods completely to prevent infinite loop
echo "🧹 Cleaning CocoaPods completely to prevent infinite loop..."
rm -rf Pods
rm -rf .symlinks  
rm -f Podfile.lock
rm -rf ~/Library/Caches/CocoaPods 2>/dev/null || true
pod cache clean --all 2>/dev/null || true

# PRODUCTION-GRADE: Ensure Flutter framework is available before pod install
echo "🔧 Ensuring Flutter framework is available..."
FLUTTER_FRAMEWORK_PATH="$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
if [ ! -d "$FLUTTER_FRAMEWORK_PATH" ]; then
    echo "📦 Downloading Flutter iOS framework..."
    cd "$PROJECT_ROOT"
    flutter precache --ios
    cd ios
fi

# Copy Flutter framework to project for plugin compatibility
echo "📋 Setting up Flutter framework for plugins..."
mkdir -p Flutter
if [ -d "$FLUTTER_FRAMEWORK_PATH" ] && [ ! -d "Flutter/Flutter.framework" ]; then
    cp -R "$FLUTTER_FRAMEWORK_PATH" "Flutter/Flutter.framework"
    echo "✅ Flutter.framework copied for plugin compatibility"
fi

# Install CocoaPods with enhanced verification
echo "🍎 Installing CocoaPods dependencies with target verification..."
pod install --repo-update --verbose

# CRITICAL VERIFICATION: Check both Runner and ShareExtension targets
echo "🔍 Verifying CocoaPods targets (BREAKING INFINITE LOOP)..."

# Verify Runner target files
RUNNER_FILES=(
    "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
    "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
)

echo "📋 Checking Runner target files..."
for file in "${RUNNER_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# Verify ShareExtension target files (should exist with fixed Podfile)
SHARE_EXTENSION_FILES=(
    "Pods/Target Support Files/Pods-ShareExtension/Pods-ShareExtension.debug.xcconfig"
    "Pods/Target Support Files/Pods-ShareExtension/Pods-ShareExtension.release.xcconfig"
)

echo "📋 Checking ShareExtension target files..."
SHARE_EXTENSION_EXISTS=false
for file in "${SHARE_EXTENSION_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
        SHARE_EXTENSION_EXISTS=true
    fi
done

if [ "$SHARE_EXTENSION_EXISTS" = false ]; then
    echo "⚠️  ShareExtension CocoaPods files not found - checking configuration..."
    echo "📂 Available target support files:"
    find "Pods/Target Support Files" -name "*.xcconfig" 2>/dev/null | head -10 || echo "No xcconfig files found"
    
    # This is not necessarily an error with minimal ShareExtension config
    echo "ℹ️  ShareExtension using minimal configuration - this may be expected"
fi

# Count installed pods for verification
if [ -f "Podfile.lock" ]; then
    pod_count=$(grep -c "^  " Podfile.lock 2>/dev/null || echo "0")
    echo "📊 Total pods installed: $pod_count"
    
    if [ "$pod_count" -lt 5 ]; then
        echo "⚠️  Unusually low pod count - verifying installation..."
        echo "📄 Podfile.lock content preview:"
        head -20 Podfile.lock
    fi
fi

# Verify Podfile.lock was created
if [ ! -f "Podfile.lock" ]; then
    echo "❌ Podfile.lock was not created"
    exit 1
fi

echo "✅ Podfile.lock created successfully"

# Set proper permissions for generated files
echo "🔒 Setting file permissions..."
chmod +r Flutter/Generated.xcconfig
chmod -R +r Pods/

# Create a summary of what was installed
echo "📊 Installation Summary:"
echo "• Flutter version: $(flutter --version | head -1)"
echo "• CocoaPods version: $(pod --version)"
echo "• Generated.xcconfig size: $(wc -c < "$GENERATED_CONFIG") bytes"
echo "• Podfile.lock size: $(wc -c < "Podfile.lock") bytes"
echo "• Number of pods installed: $(grep -c "^  " Podfile.lock || echo "0")"

# Final verification
echo "🔍 Final verification..."
if [ -s "$GENERATED_CONFIG" ] && [ -f "Podfile.lock" ] && [ -d "Pods" ]; then
    echo "✅ All required files are present and valid"
    echo "🎉 CI Pre-build script completed successfully!"
else
    echo "❌ Verification failed"
    echo "📂 Current directory contents:"
    ls -la
    exit 1
fi

echo "⏱️  Script completed at: $(date)"
