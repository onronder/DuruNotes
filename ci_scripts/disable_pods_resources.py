#!/usr/bin/env python3

"""
Disable problematic CocoaPods Copy Resources script phase for CI/CD
This script modifies the Xcode project to handle xcfilelist path issues
"""

import os
import re
import sys

def fix_xcode_project():
    """Fix the Xcode project file to handle CI/CD issues"""
    
    # Find the project file
    project_path = None
    if 'CI_WORKSPACE' in os.environ:
        project_path = f"{os.environ['CI_WORKSPACE']}/duru_notes_app/ios/Runner.xcodeproj/project.pbxproj"
    else:
        project_path = "ios/Runner.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        return False
    
    print(f"🔧 Fixing Xcode project: {project_path}")
    
    # Read the project file
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Find and modify the Copy Pods Resources script phase
    # Look for the script phase that references xcfilelist files
    patterns_to_fix = [
        (r'inputFileListPaths = \(\s*"\$\{PODS_ROOT\}/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-input-files\.xcfilelist",?\s*\);', 
         'inputFileListPaths = ();'),
        (r'outputFileListPaths = \(\s*"\$\{PODS_ROOT\}/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-output-files\.xcfilelist",?\s*\);', 
         'outputFileListPaths = ();'),
    ]
    
    modified = False
    for pattern, replacement in patterns_to_fix:
        if re.search(pattern, content):
            content = re.sub(pattern, replacement, content)
            modified = True
            print(f"✅ Fixed xcfilelist reference")
    
    # Alternative: Add runOnlyForDeploymentPostprocessing = 0 to disable dependency analysis
    script_phase_pattern = r'(shellScript = ".*\[CP\] Copy Pods Resources.*?";)'
    if re.search(script_phase_pattern, content, re.DOTALL):
        # Find the script phase and ensure it has runOnlyForDeploymentPostprocessing = 0
        replacement = r'\1\n\t\t\trunOnlyForDeploymentPostprocessing = 0;'
        if 'runOnlyForDeploymentPostprocessing = 0' not in content:
            content = re.sub(script_phase_pattern, replacement, content, flags=re.DOTALL)
            modified = True
            print("✅ Disabled dependency analysis for Copy Pods Resources")
    
    # Write back the modified content
    if modified:
        with open(project_path, 'w') as f:
            f.write(content)
        print("✅ Xcode project updated successfully")
        return True
    else:
        print("ℹ️ No modifications needed")
        return True

if __name__ == "__main__":
    success = fix_xcode_project()
    sys.exit(0 if success else 1)
