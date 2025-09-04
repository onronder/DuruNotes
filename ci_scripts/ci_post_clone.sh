#!/bin/sh

# Xcode Cloud Post-Clone Script - BULLETPROOF VERSION
set -e

echo "🚀 Starting BULLETPROOF Duru Notes CI setup..."
echo "📍 Working directory: $(pwd)"

# Install Flutter
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
    flutter config --no-analytics
    flutter precache --ios
fi

echo "✅ Flutter version:"
flutter --version

# Navigate to Flutter project
cd duru_notes_app
echo "📂 In Flutter project: $(pwd)"

# STEP 1: Complete clean slate
echo "🧹 NUCLEAR CLEAN - removing ALL artifacts..."
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf ios/Flutter/Generated.xcconfig ios/Flutter/flutter_export_environment.sh

# STEP 2: Flutter setup
echo "📦 Flutter setup..."
flutter pub get
flutter build ios --config-only --no-tree-shake-icons

# STEP 3: CocoaPods setup
cd ios
echo "🍎 Installing CocoaPods..."

# Ensure CocoaPods is available
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
fi

# Fresh pod install
pod install --repo-update --verbose

# STEP 4: THE CRITICAL FIX - Remove xcfilelist after pod install
echo "🔧 CRITICAL: Removing xcfilelist references (the root cause)..."

python3 << 'EOF'
import re

project_file = 'Runner.xcodeproj/project.pbxproj'
print(f"Fixing {project_file}...")

with open(project_file, 'r') as f:
    content = f.read()

original_content = content

# Remove xcfilelist references with multiple patterns to catch all variations
patterns = [
    # Standard format
    r'inputFileListPaths = \(\s*"[^"]*Target Support Files[^"]*",?\s*\);',
    r'outputFileListPaths = \(\s*"[^"]*Target Support Files[^"]*",?\s*\);',
    # Multi-line format
    r'inputFileListPaths = \(\s*"[^"]*Target Support Files[^"]*",?\s*\);',
    r'outputFileListPaths = \(\s*"[^"]*Target Support Files[^"]*",?\s*\);',
    # Any other variations
    r'(inputFileListPaths|outputFileListPaths) = \([^)]*Target Support Files[^)]*\);',
]

for pattern in patterns:
    matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
    if matches:
        print(f"Found {len(matches)} matches for pattern")
        content = re.sub(pattern, lambda m: m.group(0).split('=')[0] + '= (\n\t\t\t);', content)

# Write back the fixed content
if content != original_content:
    with open(project_file, 'w') as f:
        f.write(content)
    print("✅ Successfully removed xcfilelist references!")
else:
    print("ℹ️ No xcfilelist references found to remove")

# Verify the fix
with open(project_file, 'r') as f:
    verify_content = f.read()

if 'Target Support Files' in verify_content and 'xcfilelist' in verify_content:
    print("❌ WARNING: xcfilelist references still exist!")
    lines = verify_content.split('\n')
    for i, line in enumerate(lines, 1):
        if 'Target Support Files' in line and 'xcfilelist' in line:
            print(f"Line {i}: {line.strip()}")
else:
    print("✅ VERIFIED: No xcfilelist references remain")
EOF

# STEP 5: Verification
echo "🔍 Final verification..."
echo "   - Podfile.lock: $([ -f Podfile.lock ] && echo '✅ Exists' || echo '❌ Missing')"
echo "   - Pods directory: $([ -d Pods ] && echo '✅ Exists' || echo '❌ Missing')"
echo "   - Generated.xcconfig: $([ -f Flutter/Generated.xcconfig ] && echo '✅ Exists' || echo '❌ Missing')"

# Check for xcfilelist references one more time
if grep -q "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj; then
    echo "❌ CRITICAL ERROR: xcfilelist references still exist!"
    exit 1
else
    echo "✅ VERIFIED: No xcfilelist references in project file"
fi

echo "✅ BULLETPROOF CI setup completed successfully!"