#!/bin/sh

# Xcode Cloud Post-Clone Script for Flutter
# This script runs after the repository is cloned

set -e

echo "🚀 Starting Duru Notes post-clone setup..."

# Set up environment variables
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

# Install Flutter
if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
fi

# Verify Flutter
echo "✅ Flutter version:"
flutter --version
flutter doctor --android-licenses || true

# Navigate to the Flutter project
cd duru_notes_app

# Clean and prepare
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Generate iOS files
echo "🔧 Generating iOS configuration..."
flutter build ios --config-only --no-tree-shake-icons

# Fix CocoaPods integration
echo "🍎 Setting up CocoaPods..."
cd ios

# Clean pods completely
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Fresh pod installation
pod install --repo-update

# Verify and fix file paths
echo "🔧 Fixing file paths for CI..."

# Ensure Generated.xcconfig has correct content
if [ ! -f "Flutter/Generated.xcconfig" ]; then
    echo "❌ Generated.xcconfig missing, regenerating..."
    cd ..
    flutter build ios --config-only --no-tree-shake-icons
    cd ios
fi

# Check and fix xcfilelist files
PODS_TARGET_DIR="Pods/Target Support Files/Pods-Runner"
echo "🔧 Fixing xcfilelist path issues for Xcode Cloud..."

# Ensure xcfilelist files exist
if [ ! -f "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" ]; then
    echo "❌ xcfilelist files missing, regenerating pods..."
    pod deintegrate
    pod install --repo-update
fi

# Create absolute path versions for Xcode Cloud
WORKSPACE_ROOT="$CI_WORKSPACE/duru_notes_app"
if [ -n "$CI_WORKSPACE" ]; then
    echo "🔧 Creating absolute path xcfilelist files for Xcode Cloud..."
    
    # Create absolute path versions
    sed "s|\${PODS_ROOT}|$WORKSPACE_ROOT/ios/Pods|g" "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" > "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files-absolute.xcfilelist"
    sed "s|\${PODS_ROOT}|$WORKSPACE_ROOT/ios/Pods|g" "$PODS_TARGET_DIR/Pods-Runner-resources-Release-output-files.xcfilelist" > "$PODS_TARGET_DIR/Pods-Runner-resources-Release-output-files-absolute.xcfilelist"
    
    echo "✅ Created absolute path xcfilelist files"
fi

# Verify generated files
echo "🔍 Verifying generated files..."
ls -la Flutter/Generated.xcconfig || echo "❌ Generated.xcconfig missing"
ls -la "$PODS_TARGET_DIR/" || echo "❌ Pods target files missing"

# Show xcfilelist content for debugging
echo "📄 xcfilelist content sample:"
head -3 "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" || echo "❌ Cannot read xcfilelist"

# Fix Xcode project paths for CI/CD
echo "🔧 Running Xcode path fixes..."
cd "$PROJECT_ROOT"
./ci_scripts/fix_xcode_paths.sh
./ci_scripts/ci_final_fix.sh

echo "✅ Post-clone setup completed successfully!"

# Return to project root
cd "$PROJECT_ROOT"
