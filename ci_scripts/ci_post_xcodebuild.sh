#!/bin/sh

# Xcode Cloud CI Post-build Script for Flutter iOS App
# This script runs after Xcode builds the iOS app
# It performs verification, logging, and cleanup

set -e

echo "🏁 Starting Xcode Cloud CI Post-build Script"
echo "📅 $(date)"
echo "🖥️  Environment: $CI_XCODE_PROJECT_NAME"

# Environment variables and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/ios/build"

echo "📂 Script directory: $SCRIPT_DIR"
echo "📂 Project root: $PROJECT_ROOT"
echo "📂 Build directory: $BUILD_DIR"

# Change to project root
cd "$PROJECT_ROOT"

# Function to log file sizes in human-readable format
log_file_size() {
    if [ -f "$1" ]; then
        size=$(du -h "$1" | cut -f1)
        echo "📦 $1: $size"
    else
        echo "❌ $1: File not found"
    fi
}

# Check build status from environment variables
if [ "$CI_XCODEBUILD_EXIT_CODE" = "0" ]; then
    echo "✅ Build completed successfully!"
    BUILD_SUCCESS=true
else
    echo "❌ Build failed with exit code: $CI_XCODEBUILD_EXIT_CODE"
    BUILD_SUCCESS=false
fi

# Log build information
echo "📊 Build Information:"
echo "• Project: ${CI_XCODE_PROJECT_NAME:-Unknown}"
echo "• Scheme: ${CI_XCODE_SCHEME:-Unknown}"
echo "• Configuration: ${CI_XCODE_CONFIGURATION:-Unknown}"
echo "• Platform: ${CI_XCODE_PLATFORM:-Unknown}"
echo "• Build number: ${CI_BUILD_NUMBER:-Unknown}"
echo "• Branch: ${CI_BRANCH:-Unknown}"
echo "• Commit: ${CI_COMMIT:-Unknown}"

# Check for build artifacts
echo "🔍 Checking build artifacts..."

if [ "$BUILD_SUCCESS" = true ]; then
    # Look for the built app
    APP_PATH=""
    if [ -d "$BUILD_DIR/Build/Products/Release-iphoneos/Runner.app" ]; then
        APP_PATH="$BUILD_DIR/Build/Products/Release-iphoneos/Runner.app"
    elif [ -d "$BUILD_DIR/Build/Products/Debug-iphoneos/Runner.app" ]; then
        APP_PATH="$BUILD_DIR/Build/Products/Debug-iphoneos/Runner.app"
    fi

    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        echo "✅ App bundle found: $APP_PATH"
        
        # Log app bundle size
        app_size=$(du -sh "$APP_PATH" | cut -f1)
        echo "📦 App bundle size: $app_size"
        
        # Log app info if available
        if [ -f "$APP_PATH/Info.plist" ]; then
            echo "📄 App Information:"
            if command -v plutil >/dev/null 2>&1; then
                bundle_id=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null || echo "Unknown")
                version=$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Info.plist" 2>/dev/null || echo "Unknown")
                build=$(plutil -extract CFBundleVersion raw "$APP_PATH/Info.plist" 2>/dev/null || echo "Unknown")
                echo "  • Bundle ID: $bundle_id"
                echo "  • Version: $version"
                echo "  • Build: $build"
            fi
        fi
        
        # Check for frameworks and dependencies
        frameworks_dir="$APP_PATH/Frameworks"
        if [ -d "$frameworks_dir" ]; then
            framework_count=$(find "$frameworks_dir" -name "*.framework" | wc -l | tr -d ' ')
            echo "📚 Frameworks included: $framework_count"
            
            # Log largest frameworks
            echo "📊 Largest frameworks:"
            find "$frameworks_dir" -name "*.framework" -exec du -sh {} \; | sort -hr | head -5
        fi
    else
        echo "⚠️  App bundle not found in expected locations"
    fi
    
    # Look for archive
    ARCHIVE_PATH=""
    if [ -d "$BUILD_DIR/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release-iphoneos" ]; then
        ARCHIVE_PATH="$BUILD_DIR/Build/Intermediates.noindex/ArchiveIntermediates/Runner"
    fi
    
    if [ -n "$ARCHIVE_PATH" ] && [ -d "$ARCHIVE_PATH" ]; then
        echo "✅ Archive found: $ARCHIVE_PATH"
        archive_size=$(du -sh "$ARCHIVE_PATH" | cut -f1)
        echo "📦 Archive size: $archive_size"
    fi
    
    # Log Flutter-specific information
    echo "🔍 Flutter Build Information:"
    if [ -f "pubspec.yaml" ]; then
        app_version=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 || echo "Unknown")
        echo "  • App version from pubspec.yaml: $app_version"
    fi
    
    if [ -f "ios/Flutter/Generated.xcconfig" ]; then
        echo "  • Generated.xcconfig size: $(wc -c < ios/Flutter/Generated.xcconfig) bytes"
        
        # Log Flutter root and version from config
        if grep -q "FLUTTER_ROOT" ios/Flutter/Generated.xcconfig; then
            flutter_root=$(grep "FLUTTER_ROOT" ios/Flutter/Generated.xcconfig | cut -d'=' -f2)
            echo "  • Flutter root: $flutter_root"
        fi
    fi
    
    # CocoaPods information
    if [ -f "ios/Podfile.lock" ]; then
        pod_count=$(grep -c "^  " ios/Podfile.lock || echo "0")
        echo "  • CocoaPods dependencies: $pod_count"
        cocoapods_version=$(grep "COCOAPODS:" ios/Podfile.lock | cut -d' ' -f2 || echo "Unknown")
        echo "  • CocoaPods version: $cocoapods_version"
    fi

else
    # Build failed - provide debugging information
    echo "🔍 Build Failure Analysis:"
    
    # Check for common Flutter/iOS build issues
    echo "📋 Checking for common issues..."
    
    # Check if Generated.xcconfig exists
    if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
        echo "❌ Missing ios/Flutter/Generated.xcconfig - run 'flutter build ios --config-only'"
    else
        echo "✅ ios/Flutter/Generated.xcconfig exists"
    fi
    
    # Check Podfile.lock
    if [ ! -f "ios/Podfile.lock" ]; then
        echo "❌ Missing ios/Podfile.lock - run 'pod install' in ios directory"
    else
        echo "✅ ios/Podfile.lock exists"
    fi
    
    # Check Pods directory
    if [ ! -d "ios/Pods" ]; then
        echo "❌ Missing ios/Pods directory - run 'pod install' in ios directory"
    else
        echo "✅ ios/Pods directory exists"
    fi
    
    # Check for build logs
    if [ -d "$BUILD_DIR" ]; then
        echo "📂 Build directory contents:"
        find "$BUILD_DIR" -name "*.log" -o -name "*.txt" | head -10
    fi
fi

# Performance metrics
echo "📈 Performance Metrics:"
if command -v df >/dev/null 2>&1; then
    echo "💾 Disk usage:"
    df -h . | tail -1
fi

if command -v free >/dev/null 2>&1; then
    echo "🧠 Memory usage:"
    free -h | head -2
elif command -v vm_stat >/dev/null 2>&1; then
    echo "🧠 Memory usage (macOS):"
    vm_stat | head -5
fi

# Cleanup temporary files (but preserve important build artifacts)
echo "🧹 Cleaning up temporary files..."

# Clean Flutter build cache but preserve iOS build
if [ -d "build" ]; then
    # Only clean non-iOS build artifacts
    find build -name "*.tmp" -delete 2>/dev/null || true
    find build -name "*.log" -delete 2>/dev/null || true
    echo "✅ Cleaned temporary build files"
fi

# Clean CocoaPods cache if build failed
if [ "$BUILD_SUCCESS" = false ]; then
    echo "🧹 Cleaning CocoaPods cache due to build failure..."
    cd ios
    rm -rf ~/Library/Caches/CocoaPods 2>/dev/null || true
    rm -rf Pods/.build 2>/dev/null || true
    cd ..
fi

# Final summary
echo "📋 Final Summary:"
if [ "$BUILD_SUCCESS" = true ]; then
    echo "🎉 Build completed successfully!"
    echo "✅ All post-build checks passed"
    
    # Set success indicators for further processing
    export CI_POST_BUILD_SUCCESS=true
else
    echo "❌ Build failed"
    echo "🔍 Check the build logs and common issues listed above"
    
    # Set failure indicators
    export CI_POST_BUILD_SUCCESS=false
fi

echo "⏱️  Post-build script completed at: $(date)"

# Exit with the same code as the build
exit "${CI_XCODEBUILD_EXIT_CODE:-0}"
