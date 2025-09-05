#!/bin/sh
set -e
set -x

echo "### Starting Final and Cleaned ci_post_clone.sh..."
# Proje yapısı artık standart olduğu için script, projenin kök dizininde başlayacaktır.
echo "### Current working directory: $(pwd)"

# Flutter SDK'sını kuruyoruz.
echo "### Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /Users/local/flutter
export PATH="/Users/local/flutter/bin:$PATH"

# Flutter kurulumunu doğruluyoruz.
echo "### Verifying Flutter installation..."
flutter doctor -v

# Projemiz zaten kök dizinde olduğu için klasör değiştirmeye gerek yok.
# Doğrudan Flutter komutlarını çalıştırabiliriz.
echo "### Cleaning and getting Flutter dependencies..."
flutter clean
flutter pub get

# iOS klasörüne gidip CocoaPods kurulumunu yapıyoruz.
echo "### Navigating to iOS directory..."
cd ios

echo "### Now in iOS directory: $(pwd)"
echo "### Installing Pods..."
pod deintegrate
pod install --repo-update

echo "### ✅✅✅ CI SCRIPT COMPLETED SUCCESSFULLY! ✅✅✅"