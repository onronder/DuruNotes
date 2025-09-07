# 🚀 TestFlight Deployment Guide - Duru Notes

## ✅ **Prerequisites Checklist**

### **1. Apple Developer Account**
- [ ] Active Apple Developer Program membership ($99/year)
- [ ] Access to App Store Connect (https://appstoreconnect.apple.com)
- [ ] Valid signing certificates and provisioning profiles

### **2. App Configuration**
- ✅ **Bundle ID**: `com.fittechs.duruNotesApp`
- ✅ **App Name**: "Duru Notes App"
- ✅ **Version**: 1.0.0+1 (from pubspec.yaml)
- ✅ **Permissions**: Camera, Microphone, Location, Photos, Notifications
- ✅ **App Icon**: Configured
- ✅ **Launch Screen**: Configured

## 🔧 **Step 1: App Store Connect Setup**

### **Create App Record**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in details:
   - **Platform**: iOS
   - **Name**: "Duru Notes"
   - **Primary Language**: English (US)
   - **Bundle ID**: `com.fittechs.duruNotesApp`
   - **SKU**: `duru-notes-ios` (unique identifier)

### **App Information**
```
Name: Duru Notes
Subtitle: Intelligent Note-Taking Companion
Category: Productivity
Content Rights: Does Not Use Third-Party Content
Age Rating: 4+ (No Objectionable Content)
```

### **Privacy Policy & Terms**
- **Privacy Policy URL**: Required for TestFlight
- **Terms of Service**: Optional but recommended

## 🛠️ **Step 2: Prepare Release Build**

### **Update Version Numbers**
```bash
# Update pubspec.yaml version before each release
version: 1.0.0+1  # Format: major.minor.patch+buildNumber
```

### **Build Release Archive**
```bash
cd /Users/onronder/duru-notes/duru_notes_app

# Clean previous builds
flutter clean
flutter pub get

# Build for iOS release
flutter build ios --release --no-tree-shake-icons

# Open Xcode for archiving
open ios/Runner.xcworkspace
```

## 📱 **Step 3: Xcode Archive & Upload**

### **In Xcode:**
1. **Select Device Target**: "Any iOS Device (arm64)"
2. **Product Menu** → **Archive**
3. **Wait for build** (may take 5-10 minutes)
4. **Organizer Window** opens automatically
5. **Distribute App** → **App Store Connect**
6. **Upload** → **Next** → **Upload**

### **Alternative: Command Line Upload**
```bash
# After flutter build ios --release
cd ios
xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive

# Upload to App Store Connect
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ \
  -exportOptionsPlist ExportOptions.plist
```

## 🔍 **Step 4: App Store Connect Configuration**

### **TestFlight Settings**
1. **App Store Connect** → **Your App** → **TestFlight**
2. **Test Information**:
   - **What to Test**: "Initial release of Duru Notes with core note-taking features"
   - **Test Details**: Describe key features to test
3. **Test Information** → **Review Notes**: Internal testing notes

### **Internal Testing**
- Add internal testers (up to 100 people)
- No App Review required
- Immediate access after upload processing

### **External Testing** (Optional)
- Add external testers (up to 10,000 people)
- Requires App Review (1-7 days)
- Public link available

## 📋 **Step 5: App Metadata**

### **App Store Information**
```
Name: Duru Notes
Subtitle: Intelligent Note-Taking Companion
Description: 
Duru Notes is your intelligent, secure note-taking companion designed for modern productivity. Create, organize, and sync your notes across devices with advanced features like voice transcription, OCR text scanning, location-based reminders, and end-to-end encryption.

Key Features:
• 📝 Rich text editing with markdown support
• 🎤 Voice-to-text transcription
• 📷 OCR text scanning from images
• 📍 Location-based reminders
• 🔒 End-to-end encryption
• 📁 Smart folder organization
• 🔄 Cross-device synchronization
• 🌙 Beautiful dark mode

Keywords: notes, productivity, voice transcription, OCR, reminders, encryption
```

### **Screenshots Required**
- **6.7" Display** (iPhone 14 Pro Max): 1290 x 2796 pixels
- **6.5" Display** (iPhone 11 Pro Max): 1242 x 2688 pixels
- **5.5" Display** (iPhone 8 Plus): 1242 x 2208 pixels

### **App Privacy**
Based on your permissions, declare:
- **Location**: For location-based reminders
- **Camera**: For document scanning
- **Microphone**: For voice notes
- **Photos**: For image attachments
- **Device ID**: For sync across devices

## 🚨 **Important Notes**

### **Bundle ID Requirements**
- ✅ Your bundle ID `com.fittechs.duruNotesApp` is properly configured
- ✅ Must match exactly in App Store Connect
- ✅ Cannot be changed after first submission

### **Code Signing**
- Need valid Distribution Certificate
- Need App Store Provisioning Profile
- Must be signed by the same Apple Developer account

### **Testing Recommendations**
1. **Internal Testing First**: Test with team members
2. **Core Features**: Note creation, editing, sync, search
3. **Permissions**: Test camera, microphone, location access
4. **Dark/Light Mode**: Verify theme switching works
5. **Performance**: Test on older devices

## 🎯 **Quick Start Commands**

```bash
# 1. Prepare release build
cd /Users/onronder/duru-notes/duru_notes_app
flutter clean && flutter pub get
flutter build ios --release --no-tree-shake-icons

# 2. Open Xcode for archiving
open ios/Runner.xcworkspace

# 3. In Xcode: Product → Archive → Distribute App
```

## 📊 **TestFlight Timeline**

- **Upload Processing**: 10-30 minutes
- **Internal Testing**: Immediate (after processing)
- **External Testing**: 1-7 days (App Review required)
- **App Store Review**: 24-48 hours (for full release)

## 🔗 **Useful Links**

- [App Store Connect](https://appstoreconnect.apple.com)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

## ⚠️ **Common Issues & Solutions**

### **Build Issues**
- Use `--no-tree-shake-icons` flag for release builds
- Ensure all dependencies are up to date
- Clean build folder if issues persist

### **Upload Issues**
- Check code signing certificates
- Verify bundle ID matches App Store Connect
- Ensure version number is higher than previous uploads

### **Review Issues**
- Provide clear app description
- Include privacy policy if collecting data
- Test all declared permissions work correctly

---

**Ready to deploy?** Follow the steps above and your Duru Notes app will be live on TestFlight! 🎉
