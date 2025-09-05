#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script - SIMPLIFIED DIRECT APPROACH
set -e

echo "🚀 SIMPLIFIED PRE-BUILD SETUP..."

# Navigate to iOS directory
cd ..

echo "📍 Current directory: $(pwd)"

# CRITICAL: Download Flutter iOS artifacts first
echo "📥 Downloading Flutter iOS artifacts..."
/Users/local/flutter/bin/flutter precache --ios

# Find and copy Flutter.framework directly
echo "🔍 Locating Flutter.framework..."

# Create the ephemeral directory
mkdir -p Flutter/ephemeral

# Find the Flutter.framework from the cache
FLUTTER_FRAMEWORK=""

# Check multiple possible locations
if [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    FLUTTER_FRAMEWORK="/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
    echo "✅ Found in ios xcframework"
elif [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    FLUTTER_FRAMEWORK="/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework"
    echo "✅ Found in ios-release xcframework"
elif [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-profile/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    FLUTTER_FRAMEWORK="/Users/local/flutter/bin/cache/artifacts/engine/ios-profile/Flutter.xcframework/ios-arm64/Flutter.framework"
    echo "✅ Found in ios-profile xcframework"
else
    echo "🔍 Searching for any Flutter.framework..."
    FLUTTER_FRAMEWORK=$(find /Users/local/flutter/bin/cache/artifacts/engine -name "Flutter.framework" -type d | grep -E "ios-arm64|iphoneos" | head -1)
    if [ -z "$FLUTTER_FRAMEWORK" ]; then
        echo "❌ FATAL: Cannot find Flutter.framework anywhere!"
        echo "Available frameworks:"
        find /Users/local/flutter/bin/cache/artifacts/engine -name "Flutter.framework" -type d
        exit 1
    fi
    echo "✅ Found at: $FLUTTER_FRAMEWORK"
fi

# Copy the framework
echo "📋 Copying Flutter.framework to ephemeral..."
cp -R "$FLUTTER_FRAMEWORK" Flutter/ephemeral/
echo "✅ Flutter.framework copied successfully"

# Verify the framework
if [ -f "Flutter/ephemeral/Flutter.framework/Flutter" ]; then
    echo "✅ Flutter binary verified"
else
    echo "❌ Flutter binary not found in framework!"
    ls -la Flutter/ephemeral/Flutter.framework/
    exit 1
fi

# Verify headers
if [ -f "Flutter/ephemeral/Flutter.framework/Headers/Flutter.h" ]; then
    echo "✅ Flutter.h header verified"
else
    echo "⚠️ Flutter.h not found in Headers, checking..."
    ls -la Flutter/ephemeral/Flutter.framework/
fi

# Create Flutter.podspec if it doesn't exist or is incorrect
echo "📝 Creating Flutter.podspec..."
cat > Flutter/Flutter.podspec << 'EOF'
Pod::Spec.new do |s|
  s.name             = 'Flutter'
  s.version          = '1.0.0'
  s.summary          = 'Flutter Engine Framework'
  s.description      = 'Flutter Engine Framework for iOS'
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :git => '', :tag => '1.0.0' }
  s.ios.deployment_target = '14.0'
  s.vendored_frameworks = 'ephemeral/Flutter.framework'
  s.preserve_paths = 'ephemeral/Flutter.framework'
end
EOF
echo "✅ Flutter.podspec created"

# CRITICAL CHECK: Ensure no xcfilelist references exist
echo "🔍 Checking for xcfilelist references..."
if grep -q "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj; then
    echo "❌ Found xcfilelist references, removing..."
    
    # Remove xcfilelist references
    python3 << 'PYTHON_EOF'
import re

with open('Runner.xcodeproj/project.pbxproj', 'r') as f:
    lines = f.readlines()

clean_lines = []
removed_count = 0

i = 0
while i < len(lines):
    line = lines[i]
    
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
    print(f"✅ Removed {removed_count} xcfilelist references")
PYTHON_EOF
else
    echo "✅ No xcfilelist references found"
fi

# Verify Pods are ready
echo "🔍 Verifying Pods..."
if [ ! -f "Podfile.lock" ]; then
    echo "❌ Podfile.lock missing!"
    exit 1
fi

if [ ! -d "Pods" ]; then
    echo "❌ Pods directory missing!"
    exit 1
fi

# Final status
echo "🎯 PRE-BUILD STATUS:"
echo "   ✅ Flutter.framework in place"
echo "   ✅ Flutter.podspec created"
echo "   ✅ Podfile.lock exists"
echo "   ✅ Pods directory exists"
echo "   ✅ No xcfilelist references"

echo "📁 Flutter framework location:"
ls -la Flutter/ephemeral/Flutter.framework/ | head -5

echo "🚀 PRE-BUILD SETUP COMPLETE!"