#!/bin/sh

# Xcode Cloud Pre-Build Script for Flutter
# Runs before Xcode builds the project

set -e

echo "🚀 Starting Xcode Cloud pre-build for Duru Notes..."

# Environment setup
export FLUTTER_ROOT="$HOME/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"
export COCOAPODS_PARALLEL_CODE_SIGN=true

# Install Flutter if not present
if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
    flutter config --no-analytics
    flutter precache --ios
fi

# Verify Flutter
echo "✅ Flutter version:"
flutter --version

# Navigate to Flutter project
echo "📂 Navigating to project: $CI_WORKSPACE"
cd $CI_WORKSPACE

# Find the Flutter project directory
if [ -d "duru_notes_app" ]; then
    cd duru_notes_app
    echo "📂 Found Flutter project in duru_notes_app/"
elif [ -f "pubspec.yaml" ]; then
    echo "📂 Using current directory as Flutter project"
else
    echo "❌ Could not find Flutter project!"
    exit 1
fi

# Clean everything
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

# Clean CocoaPods completely
echo "🍎 Cleaning CocoaPods..."
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Install CocoaPods dependencies
echo "📦 Installing CocoaPods dependencies..."
pod install --repo-update

# Verify critical files exist
echo "🔍 Verifying generated files..."

# Check Generated.xcconfig
if [ -f "Flutter/Generated.xcconfig" ]; then
    echo "✅ Generated.xcconfig exists"
    echo "📄 Content preview:"
    head -5 Flutter/Generated.xcconfig
else
    echo "❌ Generated.xcconfig missing!"
    # Try to regenerate
    cd ..
    flutter build ios --config-only --no-tree-shake-icons
    cd ios
    if [ ! -f "Flutter/Generated.xcconfig" ]; then
        echo "❌ Failed to generate Generated.xcconfig"
        exit 1
    fi
fi

# Check CocoaPods resource files
PODS_RESOURCES_DIR="Pods/Target Support Files/Pods-Runner"
REQUIRED_XCFILELISTS=(
    "Pods-Runner-resources-Release-input-files.xcfilelist"
    "Pods-Runner-resources-Release-output-files.xcfilelist"
)

for file in "${REQUIRED_XCFILELISTS[@]}"; do
    if [ -f "$PODS_RESOURCES_DIR/$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing!"
        echo "📂 Available files in $PODS_RESOURCES_DIR:"
        ls -la "$PODS_RESOURCES_DIR/" || echo "Directory doesn't exist"
        exit 1
    fi
done

# Check if Xcode project can find the files
echo "🔍 Testing Xcode project configuration..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -dry-run || echo "⚠️ Dry run failed, but continuing..."

echo "✅ Pre-build setup completed successfully!"
echo "📊 Project structure:"
echo "   - Flutter project: $(pwd)/.."
echo "   - iOS project: $(pwd)"
echo "   - Generated.xcconfig: $(ls -la Flutter/Generated.xcconfig)"
echo "   - Pods resources: $(ls -la "$PODS_RESOURCES_DIR/" | grep xcfilelist | wc -l) xcfilelist files"

cd ..