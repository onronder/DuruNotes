#!/bin/sh

set -e

echo "Starting ci_post_clone.sh script..."

# Navigate to iOS directory
cd "$CI_WORKSPACE/duru_notes_app/ios"

echo "Current directory: $(pwd)"
echo "Listing directory contents:"
ls -la

# Install CocoaPods if not installed
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
else
    echo "CocoaPods is already installed"
fi

# Clean any existing pods
echo "Cleaning existing pods..."
rm -rf Pods
rm -f Podfile.lock

# Install pods
echo "Running pod install..."
pod install --repo-update

echo "Pod installation completed"
echo "Listing Pods directory:"
ls -la Pods/

echo "ci_post_clone.sh script completed successfully"