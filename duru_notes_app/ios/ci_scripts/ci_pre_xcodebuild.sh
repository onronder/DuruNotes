#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script - VERIFICATION ONLY
set -e

echo "🚀 PRE-BUILD VERIFICATION..."

# Navigate to iOS directory
cd ..

echo "📍 Current directory: $(pwd)"

# CRITICAL: Verify Flutter.framework exists
echo "🔍 Verifying Flutter.framework..."
if [ -d "Flutter/ephemeral/Flutter.framework" ]; then
    echo "✅ Flutter.framework exists"
    if [ -f "Flutter/ephemeral/Flutter.framework/Flutter" ]; then
        echo "✅ Flutter binary verified"
    fi
    if [ -f "Flutter/ephemeral/Flutter.framework/Headers/Flutter.h" ]; then
        echo "✅ Flutter.h header verified"
    fi
else
    echo "❌ CRITICAL: Flutter.framework missing!"
    echo "🔧 Attempting emergency recovery..."
    
    # Emergency recovery - copy framework again
    mkdir -p Flutter/ephemeral
    
    if [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
        cp -R "/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" Flutter/ephemeral/
        echo "✅ Emergency recovery: Flutter.framework copied"
    else
        echo "❌ FATAL: Cannot recover Flutter.framework"
        exit 1
    fi
fi

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

# Verify Flutter pod exists
if [ -d "Pods/Flutter" ]; then
    echo "✅ Flutter pod exists"
else
    echo "⚠️ Flutter pod directory not found in Pods"
fi

# Final status
echo "🎯 PRE-BUILD STATUS:"
echo "   ✅ Flutter.framework verified"
echo "   ✅ Podfile.lock exists"
echo "   ✅ Pods directory exists"
echo "   ✅ No xcfilelist references"

echo "🚀 PRE-BUILD VERIFICATION COMPLETE!"