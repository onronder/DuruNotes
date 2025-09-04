#!/usr/bin/env python3

"""
Fix Xcode Profile Configuration Script
This script fixes the missing Profile.xcconfig reference in the Xcode project
that causes CocoaPods integration issues.
"""

import os
import sys
import re
import uuid
from pathlib import Path


def generate_xcode_uuid():
    """Generate a unique ID in the format Xcode uses."""
    return ''.join(str(uuid.uuid4()).upper().split('-'))[:24]


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
    backup_file = f"{project_file}.backup.profile_fix"
    with open(project_file, 'r') as src, open(backup_file, 'w') as dst:
        dst.write(src.read())
    print(f"✅ Backup created: {backup_file}")
    return backup_file


def fix_profile_configuration(project_file):
    """Fix the Profile.xcconfig reference in the Xcode project."""
    print("🔧 Fixing Profile.xcconfig reference in Xcode project...")
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate a new UUID for Profile.xcconfig
    profile_uuid = generate_xcode_uuid()
    
    # Check if Profile.xcconfig is already referenced
    if 'Profile.xcconfig' in content:
        print("✅ Profile.xcconfig already referenced in project")
        return False
    
    # Find the Release.xcconfig file reference to use as a template
    release_pattern = r'(\w+) /\* Release\.xcconfig \*/ = \{isa = PBXFileReference; lastKnownFileType = text\.xcconfig; name = Release\.xcconfig; path = Flutter/Release\.xcconfig; sourceTree = "<group>"; \};'
    release_match = re.search(release_pattern, content)
    
    if not release_match:
        print("❌ Could not find Release.xcconfig reference pattern")
        return False
    
    release_uuid = release_match.group(1)
    print(f"📍 Found Release.xcconfig UUID: {release_uuid}")
    
    # Step 1: Add Profile.xcconfig file reference
    profile_file_ref = f'\t\t{profile_uuid} /* Profile.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = Profile.xcconfig; path = Flutter/Profile.xcconfig; sourceTree = "<group>"; }};'
    
    # Insert after Release.xcconfig file reference
    release_line = f'{release_uuid} /* Release.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = Release.xcconfig; path = Flutter/Release.xcconfig; sourceTree = "<group>"; }};'
    content = content.replace(release_line, release_line + '\n' + profile_file_ref)
    
    # Step 2: Add Profile.xcconfig to the Flutter group
    # Find the Flutter group children section
    flutter_group_pattern = r'(29B97314FDCFA39411CA2CEA /\* Flutter \*/ = \{[^}]+children = \([^)]+)(\);)'
    flutter_match = re.search(flutter_group_pattern, content, re.DOTALL)
    
    if flutter_match:
        # Add Profile.xcconfig reference to the Flutter group
        children_section = flutter_match.group(1)
        if profile_uuid not in children_section:
            new_children = children_section + f'\n\t\t\t\t{profile_uuid} /* Profile.xcconfig */,'
            content = content.replace(flutter_match.group(1), new_children)
    else:
        print("⚠️  Could not find Flutter group to add Profile.xcconfig reference")
    
    # Step 3: Update the Profile build configuration to use Profile.xcconfig
    # Find the Runner target's Profile configuration
    profile_config_pattern = r'(249021D4217E4FDB00AE95B9 /\* Profile \*/ = \{[^}]+baseConfigurationReference = )(\w+)( /\* Release\.xcconfig \*/;)'
    
    def replace_base_config(match):
        return match.group(1) + profile_uuid + ' /* Profile.xcconfig */;'
    
    content = re.sub(profile_config_pattern, replace_base_config, content)
    
    # Write the updated content
    with open(project_file, 'w') as f:
        f.write(content)
    
    print(f"✅ Added Profile.xcconfig reference with UUID: {profile_uuid}")
    print("✅ Updated Profile build configuration to use Profile.xcconfig")
    return True


def verify_fix(project_file):
    """Verify that the fix was applied correctly."""
    print("🔍 Verifying fix...")
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Check for Profile.xcconfig file reference
    if 'Profile.xcconfig' not in content:
        print("❌ Profile.xcconfig file reference not found")
        return False
    
    # Check for correct Profile build configuration
    profile_config_pattern = r'249021D4217E4FDB00AE95B9 /\* Profile \*/ = \{[^}]+baseConfigurationReference = \w+ /\* Profile\.xcconfig \*/;'
    if not re.search(profile_config_pattern, content, re.DOTALL):
        print("❌ Profile build configuration not using Profile.xcconfig")
        return False
    
    print("✅ Verification successful: Profile.xcconfig properly configured")
    return True


def main():
    """Main function to fix Profile.xcconfig configuration."""
    print("🚀 Xcode Profile Configuration Fix Script")
    print("📅 Starting at:", os.popen('date').read().strip())
    
    # Check if we're in the right directory
    if not os.path.exists("pubspec.yaml"):
        print("❌ pubspec.yaml not found. Please run this script from the Flutter project root.")
        sys.exit(1)
    
    # Check if Profile.xcconfig exists
    profile_config = Path("ios/Flutter/Profile.xcconfig")
    if not profile_config.exists():
        print("❌ ios/Flutter/Profile.xcconfig not found. Please create it first.")
        sys.exit(1)
    
    print("✅ ios/Flutter/Profile.xcconfig exists")
    
    # Find the Xcode project file
    project_file = find_xcode_project()
    if not project_file:
        sys.exit(1)
    
    print(f"📂 Found project file: {project_file}")
    
    # Create backup
    backup_file = backup_project_file(project_file)
    
    try:
        # Apply the fix
        success = fix_profile_configuration(project_file)
        
        if success:
            # Verify the fix
            if verify_fix(project_file):
                print("🎉 Fix applied and verified successfully!")
                print("📝 The CocoaPods Profile configuration issue should be resolved.")
                print("🔄 Please run 'pod install' again to verify the fix.")
            else:
                print("❌ Fix verification failed")
                sys.exit(1)
        else:
            print("ℹ️  No changes were needed")
        
        print(f"💾 Backup available at: {backup_file}")
        
    except Exception as e:
        print(f"❌ Error applying fix: {e}")
        print(f"🔄 Restoring from backup: {backup_file}")
        
        # Restore from backup
        with open(backup_file, 'r') as src, open(project_file, 'w') as dst:
            dst.write(src.read())
        
        sys.exit(1)


if __name__ == "__main__":
    main()
