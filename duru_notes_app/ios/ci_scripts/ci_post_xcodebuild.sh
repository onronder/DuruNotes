#!/bin/sh

# Xcode Cloud Post-Xcodebuild Script - Production Cleanup
set -e

echo "🧹 POST-BUILD CLEANUP AND VERIFICATION..."

# Navigate to iOS directory  
cd ..

echo "📊 Build completion status check:"

# Check if build products exist
if [ -d "/Volumes/workspace/build.xcarchive" ]; then
    echo "✅ Archive created successfully"
    ls -la /Volumes/workspace/build.xcarchive/Products/Applications/ 2>/dev/null || echo "⚠️ No applications in archive"
else
    echo "❌ Archive not found - build may have failed"
fi

# Check for common build artifacts
if [ -f "/Volumes/workspace/DerivedData/Logs/Build/*.xcactivitylog" ]; then
    echo "📋 Build logs available for debugging"
fi

echo "🎯 POST-BUILD COMPLETE"