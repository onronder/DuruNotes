#!/bin/sh

# Hata durumunda script'in hemen durmasını ve çalıştırılan komutları terminalde göstermesini sağlar.
set -e
set -x

echo "### Starting ci_post_clone.sh script..."
# Script'in doğru yerden çalıştığını teyit etmek için mevcut konumu yazdırıyoruz.
echo "### Script is running from: $(pwd)"

# Flutter'ın stabil (stable) versiyonunu kuruyoruz.
echo "### Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /Users/local/flutter
export PATH="/Users/local/flutter/bin:$PATH"

# Flutter kurulumunu ve versiyonunu doğruluyoruz.
echo "### Verifying Flutter installation..."
flutter doctor -v

# Flutter projesinin kök dizinine gitmemiz gerekiyor.
# Script'imiz şu an 'duru_notes_app/ios/ci_scripts' içinde olduğundan, 3 dizin yukarı çıkmalıyız.
cd ../../..

# Doğru dizinde olduğumuzu kontrol edelim.
echo "### Now in Flutter project root: $(pwd)"

# Flutter projesini temizleyip pub paketlerini yüklüyoruz.
echo "### Cleaning and getting Flutter dependencies..."
flutter clean
flutter pub get

# iOS klasörüne geri dönüyoruz.
echo "### Navigating back to iOS directory..."
cd duru_notes_app/ios

# Son olarak CocoaPods kurulumunu yapıyoruz.
echo "### Resetting and installing CocoaPods..."
pod deintegrate
pod install --repo-update

echo "### ci_post_clone.sh script finished successfully."