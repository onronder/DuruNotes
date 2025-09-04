#!/bin/sh

set -e

echo "Starting ci_post_clone.sh script..."

# Navigate to iOS directory
cd "$CI_PRIMARY_REPOSITORY_PATH/duru_notes_app/ios"

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

# Install Flutter if not available
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable ~/flutter
    export PATH="$PATH:$HOME/flutter/bin"
    flutter doctor
fi

# Navigate to Flutter project root to run flutter pub get
cd "$CI_PRIMARY_REPOSITORY_PATH/duru_notes_app"
echo "Running flutter pub get..."
flutter pub get || $HOME/flutter/bin/flutter pub get

# Navigate back to iOS directory
cd "$CI_PRIMARY_REPOSITORY_PATH/duru_notes_app/ios"

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