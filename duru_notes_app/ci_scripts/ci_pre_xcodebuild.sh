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

# Clean previous CocoaPods installation
echo "🧹 Cleaning previous CocoaPods installation..."
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Install CocoaPods dependencies
echo "🍎 Installing CocoaPods dependencies..."
pod install --repo-update --verbose

# Verify critical CocoaPods files exist
echo "🔍 Verifying CocoaPods installation..."
REQUIRED_PODS_FILES=(
    "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
    "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
    "Pods/Target Support Files/Pods-Runner/Pods-Runner-resources.sh"
)

for file in "${REQUIRED_PODS_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        echo "📂 Contents of Pods directory:"
        find Pods -name "*.xcconfig" -o -name "*.sh" | head -20
        exit 1
    fi
done

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
