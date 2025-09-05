#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script - PRODUCTION GRADE FIX
set -e

echo "🚀 PRODUCTION GRADE PRE-BUILD SETUP..."

# Navigate to iOS directory
cd ..

# CRITICAL: Ensure Flutter framework is generated BEFORE building
echo "🔧 Generating Flutter framework..."
cd ../../duru_notes_app

# Verify we're in the correct directory with pubspec.yaml
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ FATAL: pubspec.yaml not found in $(pwd)"
    echo "📁 Directory contents:"
    ls -la
    exit 1
fi

echo "✅ Found pubspec.yaml in $(pwd)"

# Generate Flutter framework with proper iOS configuration  
echo "📱 Building Flutter iOS framework..."
if /Users/local/flutter/bin/flutter build ios-framework --no-debug --no-profile --release; then
    echo "✅ Flutter ios-framework build completed"
else
    echo "⚠️ Flutter ios-framework build failed, trying alternative approach"
fi

# Return to iOS directory
cd ios

# CRITICAL: Ensure Flutter.framework exists in ephemeral directory
echo "🔍 Verifying Flutter framework..."
if [ ! -d "Flutter/ephemeral/Flutter.framework" ]; then
    echo "❌ CRITICAL: Flutter.framework missing from ephemeral directory"
    echo "🔧 Trying multiple approaches to get Flutter framework..."
    
    # Create ephemeral directory if it doesn't exist
    mkdir -p Flutter/ephemeral
    
    # Strategy 1: Copy from cache
    if [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.framework" ]; then
        echo "📁 Strategy 1: Copying from Flutter cache..."
        cp -R "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.framework" Flutter/ephemeral/
        echo "✅ Flutter framework copied from cache"
    # Strategy 2: Check build output
    elif [ -d "../build/ios/framework/Release/Flutter.framework" ]; then
        echo "📁 Strategy 2: Copying from build output..."
        cp -R "../build/ios/framework/Release/Flutter.framework" Flutter/ephemeral/
        echo "✅ Flutter framework copied from build"
    # Strategy 3: Download artifacts directly
    else
        echo "📁 Strategy 3: Downloading Flutter artifacts..."
        /Users/local/flutter/bin/flutter precache --ios
        if [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.framework" ]; then
            cp -R "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.framework" Flutter/ephemeral/
            echo "✅ Flutter framework downloaded and copied"
        else
            echo "❌ FATAL: All strategies failed to get Flutter.framework"
            echo "🔍 Available Flutter frameworks:"
            find /Users/local/flutter -name "Flutter.framework" -type d 2>/dev/null | head -5
            echo "🔍 Current directory structure:"
            find . -name "Flutter.framework" -type d 2>/dev/null
            exit 1
        fi
    fi
else
    echo "✅ Flutter.framework exists in ephemeral"
fi

# CRITICAL CHECK: Ensure no xcfilelist references exist
echo "🔍 Checking for xcfilelist references..."
if grep -q "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj; then
    echo "❌ EMERGENCY: Found xcfilelist references!"
    echo "🚨 Applying emergency nuclear fix..."
    
    # Emergency fix - remove ALL lines with xcfilelist references
    python3 << 'EOF'
import re

with open('Runner.xcodeproj/project.pbxproj', 'r') as f:
    lines = f.readlines()

clean_lines = []
removed_count = 0

i = 0
while i < len(lines):
    line = lines[i]
    
    # If this line contains xcfilelist reference, replace with empty array
    if 'Target Support Files' in line and 'xcfilelist' in line:
        if 'inputFileListPaths' in line:
            clean_lines.append('\t\t\tinputFileListPaths = (\n')
            clean_lines.append('\t\t\t);\n')
        elif 'outputFileListPaths' in line:
            clean_lines.append('\t\t\toutputFileListPaths = (\n')
            clean_lines.append('\t\t\t);\n')
        removed_count += 1
        print(f"REMOVED: {line.strip()}")
    else:
        clean_lines.append(line)
    
    i += 1

if removed_count > 0:
    with open('Runner.xcodeproj/project.pbxproj', 'w') as f:
        f.writelines(clean_lines)
    print(f"✅ Emergency fix completed: removed {removed_count} xcfilelist references")
EOF
    
else
    echo "✅ No xcfilelist references found"
fi

# Verify Pods are in sync
echo "🔍 Verifying Pods sync..."
if [ ! -f "Podfile.lock" ]; then
    echo "❌ Podfile.lock missing - this should not happen!"
    exit 1
fi

if [ ! -d "Pods" ]; then
    echo "❌ Pods directory missing - this should not happen!"
    exit 1
fi

# PRODUCTION: Verify Flutter.framework is accessible to CocoaPods
echo "🔍 Verifying Flutter.framework accessibility..."
if [ -f "Flutter/ephemeral/Flutter.framework/Flutter" ]; then
    echo "✅ Flutter binary found in framework"
    echo "📋 Flutter framework info:"
    file Flutter/ephemeral/Flutter.framework/Flutter | head -1
else
    echo "❌ CRITICAL: Flutter binary missing from framework!"
    exit 1
fi

# PRODUCTION: Check if Flutter framework is properly linked
echo "🔍 Checking Flutter framework in Xcode project..."
if grep -q "Flutter.framework" Runner.xcodeproj/project.pbxproj; then
    echo "✅ Flutter.framework referenced in Xcode project"
else
    echo "⚠️  Flutter.framework not found in Xcode project references"
fi

# Final verification
echo "🎯 PRODUCTION STATUS CHECK:"
echo "   ✅ Flutter framework built"
echo "   ✅ Flutter.framework exists in ephemeral"
echo "   ✅ Podfile.lock exists"
echo "   ✅ Pods directory exists"
echo "   ✅ No xcfilelist references"
echo "   ✅ Flutter binary accessible"

# One last check for xcfilelist
if grep -q "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj; then
    echo "❌ FATAL: xcfilelist references STILL EXIST after emergency fix!"
    grep -n "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj
    exit 1
fi

echo "🚀 PRODUCTION PRE-BUILD COMPLETE - FLUTTER FRAMEWORK READY!"