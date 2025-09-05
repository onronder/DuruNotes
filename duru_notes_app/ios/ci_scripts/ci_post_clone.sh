#!/bin/sh

# Hata durumunda script'in durmasını ve komutları göstermesini sağlar
set -e
set -x

echo "### Starting ci_post_clone.sh script..."

# Flutter'ın stabil (stable) versiyonunu kuruyoruz
echo "### Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /Users/local/flutter
export PATH="/Users/local/flutter/bin:$PATH"

# Flutter kurulumunu doğruluyoruz
echo "### Verifying Flutter installation..."
flutter doctor -v

# Projenin ana çalışma dizinine gidiyoruz ($CI_WORKSPACE, Xcode Cloud'un proje dosyalarını klonladığı yerdir)
echo "### Navigating to project root directory..."
cd $CI_WORKSPACE

# Flutter bağımlılıklarını temizleyip yeniden yüklüyoruz
echo "### Cleaning and getting Flutter dependencies..."
flutter clean
flutter pub get

# ÖNEMLİ ADIM: Flutter'a iOS projesini yeniden yapılandırmasını ve hazırlamasını söylüyoruz.
# Bu komut, podspec bulunamadı hatasını kesin olarak çözer.
echo "### Preparing iOS project for build..."
flutter build ios --no-codesign

# iOS klasörüne gidiyoruz
echo "### Navigating to iOS directory..."
cd ios

# CocoaPods entegrasyonunu tamamen sıfırlayıp, güncel podları kuruyoruz
echo "### Resetting and installing CocoaPods..."
pod deintegrate
pod install --repo-update

echo "### ci_post_clone.sh script finished successfully."