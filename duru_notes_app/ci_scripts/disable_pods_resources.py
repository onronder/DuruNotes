#!/usr/bin/env python3

"""
Disable Pods Resources Script Warning Helper
This script helps fix the CocoaPods warning about missing output files
by modifying the Xcode project to include proper output specifications.
"""

import os
import sys
import re
import json
from pathlib import Path


def find_xcode_project():
    """Find the Runner.xcodeproj file in the ios directory."""
    ios_dir = Path("ios")
    if not ios_dir.exists():
        print("❌ ios directory not found")
        return None
    
    project_file = ios_dir / "Runner.xcodeproj" / "project.pbxproj"
    if not project_file.exists():
        print("❌ Runner.xcodeproj/project.pbxproj not found")
        return None
    
    return project_file


def backup_project_file(project_file):
    """Create a backup of the project file."""
    backup_file = f"{project_file}.backup"
    with open(project_file, 'r') as src, open(backup_file, 'w') as dst:
        dst.write(src.read())
    print(f"✅ Backup created: {backup_file}")
    return backup_file


def fix_copy_pods_resources(project_file):
    """Fix the Copy Pods Resources build phase to include output files."""
    print("🔧 Fixing Copy Pods Resources build phase...")
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Pattern to find Copy Pods Resources build phases
    pattern = r'(\/\* \[CP\] Copy Pods Resources \*\/ = \{[^}]+name = "\[CP\] Copy Pods Resources";[^}]+\};)'
    
    matches = re.findall(pattern, content)
    if not matches:
        print("⚠️  No Copy Pods Resources build phases found")
        return False
    
    print(f"🔍 Found {len(matches)} Copy Pods Resources build phase(s)")
    
    modified = False
    for match in matches:
        # Check if outputFileListPaths is already present
        if 'outputFileListPaths' in match:
            print("✅ Output file list paths already present")
            continue
        
        # Add outputFileListPaths before runOnlyForDeploymentPostprocessing
        new_match = match.replace(
            'runOnlyForDeploymentPostprocessing = 0;',
            'outputFileListPaths = (\n\t\t\t\t"${PODS_ROOT}/Target Support Files/Pods-Runner/Pods-Runner-resources-${CONFIGURATION}-output-files.xcfilelist",\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;'
        )
        
        if new_match != match:
            content = content.replace(match, new_match)
            modified = True
            print("✅ Added output file list paths")
    
    if modified:
        with open(project_file, 'w') as f:
            f.write(content)
        print("✅ Project file updated successfully")
        return True
    else:
        print("ℹ️  No modifications needed")
        return False


def verify_fix(project_file):
    """Verify that the fix was applied correctly."""
    print("🔍 Verifying fix...")
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Check for the presence of outputFileListPaths in Copy Pods Resources phases
    copy_pods_pattern = r'\/\* \[CP\] Copy Pods Resources \*\/ = \{[^}]+outputFileListPaths[^}]+\};'
    matches = re.findall(copy_pods_pattern, content)
    
    if matches:
        print(f"✅ Verification successful: Found {len(matches)} properly configured Copy Pods Resources phase(s)")
        return True
    else:
        print("❌ Verification failed: outputFileListPaths not found in Copy Pods Resources phases")
        return False


def main():
    """Main function to fix CocoaPods resource warnings."""
    print("🚀 CocoaPods Resources Warning Fix Script")
    print("📅 Starting at:", os.popen('date').read().strip())
    
    # Check if we're in the right directory
    if not os.path.exists("pubspec.yaml"):
        print("❌ pubspec.yaml not found. Please run this script from the Flutter project root.")
        sys.exit(1)
    
    # Find the Xcode project file
    project_file = find_xcode_project()
    if not project_file:
        sys.exit(1)
    
    print(f"📂 Found project file: {project_file}")
    
    # Create backup
    backup_file = backup_project_file(project_file)
    
    try:
        # Apply the fix
        success = fix_copy_pods_resources(project_file)
        
        if success:
            # Verify the fix
            if verify_fix(project_file):
                print("🎉 Fix applied and verified successfully!")
                print("📝 The CocoaPods warning should be resolved in your next build.")
            else:
                print("❌ Fix verification failed")
                sys.exit(1)
        else:
            print("ℹ️  No changes were needed")
        
        print(f"💾 Backup available at: {backup_file}")
        print("🔄 You may need to run 'pod install' again after this change")
        
    except Exception as e:
        print(f"❌ Error applying fix: {e}")
        print(f"🔄 Restoring from backup: {backup_file}")
        
        # Restore from backup
        with open(backup_file, 'r') as src, open(project_file, 'w') as dst:
            dst.write(src.read())
        
        sys.exit(1)


if __name__ == "__main__":
    main()
