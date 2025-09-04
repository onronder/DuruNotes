#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script
set -e

echo "🔧 Pre-build verification..."
cd duru_notes_app/ios

# Verify Podfile.lock exists
if [ ! -f "Podfile.lock" ]; then
    echo "❌ Podfile.lock missing! Running pod install..."
    pod install --repo-update
fi

# Verify Pods directory exists
if [ ! -d "Pods" ]; then
    echo "❌ Pods directory missing! Running pod install..."
    pod install --repo-update
fi

# Check if Pods are in sync
echo "🔍 Checking Pod sync status..."
pod install --deployment

# Fix the xcfilelist paths if needed
echo "📝 Checking Xcode project file..."

# Create a Python script to verify and fix the project file
cat > fix_project.py << 'EOF'
import re

# Read the project file
with open('Runner.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Find the [CP] Copy Pods Resources script phase
pattern = r'(13EE8994B2C84C0AD4C3F233 /\* \[CP\] Copy Pods Resources \*/.*?showEnvVarsInLog = 0;\s*};)'
match = re.search(pattern, content, re.DOTALL)

modified = False
if match:
    script_phase = match.group(1)
    
    # Check if it still has problematic file list paths
    if '"${PODS_ROOT}/Target Support Files/' in script_phase:
        print("Found problematic xcfilelist paths, removing...")
        
        # Remove the input and output file list paths
        new_phase = re.sub(
            r'inputFileListPaths = \([^)]*\);',
            'inputFileListPaths = (\n\t\t\t);',
            script_phase
        )
        new_phase = re.sub(
            r'outputFileListPaths = \([^)]*\);', 
            'outputFileListPaths = (\n\t\t\t);',
            new_phase
        )
        
        content = content.replace(script_phase, new_phase)
        modified = True
        print("✅ Removed xcfilelist paths")
    else:
        print("✅ Project file already fixed")
else:
    print("⚠️ [CP] Copy Pods Resources phase not found")

if modified:
    # Write the fixed content back
    with open('Runner.xcodeproj/project.pbxproj', 'w') as f:
        f.write(content)
    print("✅ Project file updated")
EOF

# Run the Python script
python3 fix_project.py

# Clean up
rm fix_project.py

echo "✅ Pre-build verification complete!"
echo "📊 Final status:"
echo "   - Podfile.lock: $([ -f Podfile.lock ] && echo '✅ Exists' || echo '❌ Missing')"
echo "   - Pods directory: $([ -d Pods ] && echo '✅ Exists' || echo '❌ Missing')"
echo "   - Generated.xcconfig: $([ -f Flutter/Generated.xcconfig ] && echo '✅ Exists' || echo '❌ Missing')"