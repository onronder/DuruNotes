#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script - FINAL VERIFICATION
set -e

echo "🔧 FINAL pre-build verification..."
# Script is already in duru_notes_app/ios/ci_scripts, so go up one level
cd ..

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

# Final verification
echo "🎯 FINAL STATUS CHECK:"
echo "   ✅ Podfile.lock exists"
echo "   ✅ Pods directory exists"
echo "   ✅ No xcfilelist references"

# One last check
if grep -q "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj; then
    echo "❌ FATAL: xcfilelist references STILL EXIST after emergency fix!"
    grep -n "Target Support Files.*xcfilelist" Runner.xcodeproj/project.pbxproj
    exit 1
fi

echo "🚀 PRE-BUILD VERIFICATION COMPLETE - READY TO BUILD!"