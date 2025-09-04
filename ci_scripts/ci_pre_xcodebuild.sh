#!/bin/sh

# Xcode Cloud Pre-Xcodebuild Script
set -e

echo "🔧 Pre-build setup..."
cd duru_notes_app/ios

# Fix the xcfilelist paths by modifying the project file
echo "📝 Fixing Xcode project file..."

# Create a Python script to fix the project file
cat > fix_project.py << 'EOF'
import re

# Read the project file
with open('Runner.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Find and fix the [CP] Copy Pods Resources script phase
# This regex finds the script phase with its ID
pattern = r'(13EE8994B2C84C0AD4C3F233 /\* \[CP\] Copy Pods Resources \*/.*?showEnvVarsInLog = 0;\s*};)'
match = re.search(pattern, content, re.DOTALL)

if match:
    script_phase = match.group(1)
    print("Found [CP] Copy Pods Resources script phase")
    
    # Remove the input and output file list paths to avoid absolute path issues
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
    
    # Also add inputPaths and outputPaths as empty to prevent warnings
    if 'inputPaths = ' not in new_phase:
        new_phase = re.sub(
            r'(files = \(\s*\);)',
            r'\1\n\t\t\tinputPaths = (\n\t\t\t);',
            new_phase
        )
    if 'outputPaths = ' not in new_phase:
        new_phase = re.sub(
            r'(inputPaths = \([^)]*\);)',
            r'\1\n\t\t\toutputPaths = (\n\t\t\t);',
            new_phase
        )
    
    content = content.replace(script_phase, new_phase)
    print("✅ Removed xcfilelist paths from script phase")
else:
    print("⚠️ Script phase not found - may already be fixed")

# Write the fixed content back
with open('Runner.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Project file updated")
EOF

# Run the Python script
python3 fix_project.py

# Clean up
rm fix_project.py

echo "✅ Pre-build setup complete!"