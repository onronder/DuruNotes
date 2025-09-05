#!/bin/bash

# Production-Grade Flutter Framework Fix Script
# Ensures Flutter.framework is properly linked for all plugins

set -e

echo "🔧 PRODUCTION-GRADE FLUTTER FRAMEWORK FIX"
echo "=========================================="

# Get Flutter root from Generated.xcconfig or detect it
if [ -f "Flutter/Generated.xcconfig" ]; then
    FLUTTER_ROOT=$(grep "FLUTTER_ROOT=" Flutter/Generated.xcconfig | cut -d'=' -f2)
    echo "📋 Flutter root from Generated.xcconfig: $FLUTTER_ROOT"
else
    FLUTTER_ROOT="${FLUTTER_ROOT:-$(which flutter | sed 's/\/bin\/flutter$//')}"
    echo "📋 Flutter root from PATH: $FLUTTER_ROOT"
fi

if [ -z "$FLUTTER_ROOT" ] || [ ! -d "$FLUTTER_ROOT" ]; then
    echo "❌ Flutter root not found or invalid: $FLUTTER_ROOT"
    exit 1
fi

echo "📂 Flutter root: $FLUTTER_ROOT"

# Ensure we're in the iOS directory
if [ ! -f "Podfile" ]; then
    echo "❌ Not in iOS directory - Podfile not found"
    exit 1
fi

echo "📍 Current directory: $(pwd)"

# Step 1: Ensure Flutter.framework exists in the correct location
FLUTTER_FRAMEWORK_SOURCE="$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
FLUTTER_FRAMEWORK_DEST="Flutter/Flutter.framework"

echo "🔍 Checking Flutter.framework..."

if [ ! -d "$FLUTTER_FRAMEWORK_SOURCE" ]; then
    echo "⚠️  Flutter.framework not found in cache, triggering download..."
    cd ..
    flutter precache --ios
    cd ios
fi

if [ -d "$FLUTTER_FRAMEWORK_SOURCE" ]; then
    echo "✅ Flutter.framework found in cache"
    
    # Remove existing framework if it exists
    if [ -d "$FLUTTER_FRAMEWORK_DEST" ]; then
        rm -rf "$FLUTTER_FRAMEWORK_DEST"
    fi
    
    # Create Flutter directory if it doesn't exist
    mkdir -p Flutter
    
    # Copy the framework
    cp -R "$FLUTTER_FRAMEWORK_SOURCE" "$FLUTTER_FRAMEWORK_DEST"
    echo "✅ Flutter.framework copied to project"
    
    # Verify critical files exist
    if [ -f "$FLUTTER_FRAMEWORK_DEST/Headers/Flutter.h" ]; then
        echo "✅ Flutter.h header verified"
    else
        echo "❌ Flutter.h header missing"
        exit 1
    fi
    
    if [ -f "$FLUTTER_FRAMEWORK_DEST/Flutter" ]; then
        echo "✅ Flutter binary verified"
    else
        echo "❌ Flutter binary missing"
        exit 1
    fi
else
    echo "❌ Cannot find Flutter.framework in cache"
    exit 1
fi

# Step 2: Update framework permissions
echo "🔒 Setting framework permissions..."
chmod -R +r "$FLUTTER_FRAMEWORK_DEST"

# Step 3: Verify framework architecture
echo "🏗️ Verifying framework architecture..."
if command -v lipo >/dev/null 2>&1; then
    lipo -info "$FLUTTER_FRAMEWORK_DEST/Flutter" || echo "⚠️  Could not read framework architecture"
fi

# Step 4: Create symbolic link for backward compatibility
if [ ! -L "Flutter.framework" ]; then
    ln -sf "Flutter/Flutter.framework" "Flutter.framework"
    echo "✅ Created Flutter.framework symbolic link"
fi

echo "🎉 Flutter.framework setup completed successfully!"
echo "📊 Framework size: $(du -sh $FLUTTER_FRAMEWORK_DEST | cut -f1)"
