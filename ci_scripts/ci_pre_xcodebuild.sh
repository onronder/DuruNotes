#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script for Flutter
# This script runs just before Xcode builds

set -e

echo "🚀 Starting pre-xcodebuild setup for Duru Notes..."

# Debug environment
echo "📍 Current directory: $(pwd)"
echo "📍 CI_WORKSPACE: ${CI_WORKSPACE:-'Not set'}"

# Navigate to Flutter project
if [ -d "duru_notes_app" ]; then
    cd duru_notes_app
    echo "📂 Moved to duru_notes_app/"
else
    echo "❌ duru_notes_app not found!"
    ls -la
    exit 1
fi

# Ensure Flutter is available
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    exit 1
fi

echo "✅ Flutter available: $(flutter --version | head -1)"

# Final check before build
echo "🔍 Final pre-build verification..."

# Verify iOS directory
if [ ! -d "ios" ]; then
    echo "❌ ios directory missing!"
    exit 1
fi

cd ios

# Verify critical files
if [ ! -f "Flutter/Generated.xcconfig" ]; then
    echo "❌ Generated.xcconfig missing!"
    echo "🔧 Attempting to regenerate..."
    cd ..
    flutter build ios --config-only --no-tree-shake-icons
    cd ios
fi

# Verify Pods
if [ ! -d "Pods" ]; then
    echo "❌ Pods directory missing!"
    echo "🔧 Running pod install..."
    pod install --repo-update
fi

# Final attempt to fix the xcfilelist issue
PODS_TARGET_DIR="Pods/Target Support Files/Pods-Runner"
if [ -d "$PODS_TARGET_DIR" ]; then
    echo "✅ Pods Target Support Files found"
    
    # Last resort: Create the files Xcode expects
    echo "🔧 Creating expected xcfilelist structure..."
    
    # Try to create the absolute path directory
    TARGET_DIR="/Target Support Files/Pods-Runner"
    sudo mkdir -p "$TARGET_DIR" 2>/dev/null || mkdir -p "/tmp$TARGET_DIR" 2>/dev/null || echo "⚠️ Cannot create absolute path directory"
    
    # Copy the files if they exist
    for file in "Pods-Runner-resources-Release-input-files.xcfilelist" "Pods-Runner-resources-Release-output-files.xcfilelist"; do
        if [ -f "$PODS_TARGET_DIR/$file" ]; then
            sudo cp "$PODS_TARGET_DIR/$file" "$TARGET_DIR/" 2>/dev/null || \
            cp "$PODS_TARGET_DIR/$file" "/tmp$TARGET_DIR/" 2>/dev/null || \
            echo "⚠️ Could not copy $file to absolute path"
        fi
    done
else
    echo "❌ Pods Target Support Files not found!"
fi

echo "✅ Pre-xcodebuild setup completed!"

# Return to project root
cd ../..