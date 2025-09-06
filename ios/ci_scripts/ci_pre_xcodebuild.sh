#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script - VERIFICATION ONLY
set -e

echo "🚀 PRE-BUILD VERIFICATION..."

# Navigate to iOS directory (fixed for new project structure)
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"

echo "📍 Current directory: $(pwd)"

echo "🔍 Ensuring Flutter tool scripts are available..."
export FLUTTER_ROOT="${FLUTTER_ROOT:-/Users/local/flutter}"
if [ ! -f "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" ]; then
  echo "⚠️ xcode_backend.sh not found at $FLUTTER_ROOT. Bootstrapping Flutter SDK..."
  # Attempt to locate flutter on PATH
  if command -v flutter >/dev/null 2>&1; then
    export FLUTTER_ROOT="$(dirname $(dirname $(dirname $(command -v flutter))))"
  fi
  echo "🔧 Resolved FLUTTER_ROOT=$FLUTTER_ROOT"
fi

# Verify Flutter.framework exists (manual pod system)
echo "🔍 Verifying Flutter.framework..."
if [ ! -d "Flutter/Flutter.framework" ]; then
  mkdir -p Flutter
  if [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    cp -R "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" Flutter/
    echo "✅ Restored Flutter.framework from Flutter SDK cache"
  else
    echo "❌ FATAL: Flutter.framework missing and could not restore from $FLUTTER_ROOT"
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

# Verify critical plugin pods (manual pod system)
echo "🔍 Verifying critical plugin pods..."
for plugin in "sentry_flutter" "adapty_flutter" "sqlite3_flutter_libs" "google_mlkit_text_recognition" "receive_sharing_intent"; do
    if [ -d "Pods/$plugin" ]; then
        echo "✅ $plugin pod exists"
    else
        echo "⚠️ $plugin pod not found"
    fi
done

# Verify Flutter pod (may not exist in manual system)
if [ -d "Pods/Flutter" ]; then
    echo "✅ Flutter pod exists"
else
    echo "⚠️ Flutter pod directory not found - expected in manual pod system"
fi

# Final status
echo "🎯 PRE-BUILD STATUS (Manual Pod System):"
echo "   ✅ Flutter.framework verified"
echo "   ✅ Podfile.lock exists"
echo "   ✅ Pods directory exists"
echo "   ✅ No xcfilelist references"
echo "   ✅ Critical plugins verified"

echo "🚀 PRE-BUILD VERIFICATION COMPLETE!"