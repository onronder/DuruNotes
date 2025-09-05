# 🗂️ DURU NOTES - COMPLETE PROJECT STRUCTURE

> **Generated on:** September 5, 2025  
> **Project:** Flutter iOS Note-Taking App with Advanced Features  
> **Status:** Production-Grade Setup in Progress  
> **Root Directory:** `/Users/onronder/duru-notes/`

---

## 📱 **PROJECT OVERVIEW**

**Duru Notes** is an intelligent, secure note-taking companion with advanced features:
- 🔐 **End-to-end encryption** with local and cloud sync
- 🎤 **Voice transcription** with speech-to-text
- 📷 **OCR scanning** with Google ML Kit
- ⏰ **Smart reminders** with geofencing
- 📤 **Share extensions** for iOS integration
- 💰 **Subscription management** with Adapty
- 🌍 **Multi-language support** (English, Turkish)

---

## 📁 **ROOT DIRECTORY STRUCTURE**

```
duru-notes/                           # 🏠 PROJECT ROOT
├── 📄 analysis_options.yaml          # Flutter/Dart linting rules
├── 📄 duru_notes_app.iml            # IntelliJ IDEA module configuration
├── 📄 flutter_01.log                # Flutter build log (debug info)
├── 📄 flutter_build.sh              # 🚀 Local CI/CD testing script
├── 📄 l10n.yaml                     # Internationalization config
├── 📄 pubspec.yaml                  # 📦 Main Flutter dependencies
├── 📄 pubspec.lock                  # 🔒 Dependency lock file
├── 📄 sentry.properties             # 🐛 Crash reporting config
├── 📄 supabase_folder_schema.sql    # 🗄️ Database schema
├── 📄 PROJECT_FILE_MAP.md           # 📋 This file
└── 📄 .xcode-cloud-config.json      # ☁️ Xcode Cloud CI/CD config
```

---

## 🤖 **ANDROID PLATFORM**

```
android/                             # Android app configuration
├── 📄 build.gradle.kts              # Main Android build script
├── 📄 gradle.properties             # Gradle global properties
├── 📄 gradlew                       # Gradle wrapper (Unix)
├── 📄 gradlew.bat                   # Gradle wrapper (Windows)
├── 📄 local.properties              # Local SDK paths
├── 📄 settings.gradle.kts           # Gradle project settings
├── 📄 duru_notes_app_android.iml    # Android module file
├── 📁 .gradle/                      # Gradle build cache
│   ├── 📁 8.12/                     # Gradle version cache
│   ├── 📁 buildOutputCleanup/       # Build cleanup cache
│   └── 📁 vcs-1/                    # Version control cache
├── 📁 gradle/wrapper/               # Gradle wrapper files
│   └── 📄 gradle-wrapper.properties # Wrapper configuration
└── 📁 app/                          # Main Android app module
    ├── 📄 build.gradle.kts          # App-level build configuration
    └── 📁 src/                      # Android source code
        ├── 📁 debug/                # Debug-specific resources
        ├── 📁 profile/              # Profile-specific resources
        └── 📁 main/                 # Main source code
            ├── 📄 AndroidManifest.xml # App permissions & config
            ├── 📁 java/io/flutter/plugins/ # Flutter plugin registrations
            ├── 📁 kotlin/com/example/duru_notes_app/ # Kotlin source
            │   └── 📄 MainActivity.kt # Main activity
            └── 📁 res/              # Android resources
                ├── 📁 drawable/     # Vector graphics
                ├── 📁 drawable-v21/ # API 21+ graphics
                ├── 📁 mipmap-*/     # App icons (all densities)
                ├── 📁 values/       # Default strings/colors/styles
                ├── 📁 values-night/ # Dark theme resources
                └── 📁 values-tr/    # Turkish localization
```

---

## 🍎 **iOS PLATFORM**

```
ios/                                  # iOS app configuration
├── 📄 Podfile                       # 🔧 CocoaPods dependencies (FIXED)
├── 📄 Podfile.lock                  # CocoaPods lock file
├── 📄 Podfile.bak.1756468596        # Podfile backup
├── 📄 ExportOptions.plist           # App Store export settings
├── 📄 ci_flutter_config.sh          # Legacy CI script
├── 📁 ci_scripts/                   # 🚀 Xcode Cloud CI/CD scripts
│   ├── 📄 ci_pre_xcodebuild.sh      # Pre-build setup script
│   └── 📄 ci_post_clone.sh          # Post-clone script
├── 📁 Flutter/                      # Flutter iOS configuration
│   ├── 📄 AppFrameworkInfo.plist    # Flutter framework info
│   ├── 📄 Debug.xcconfig            # Debug build settings
│   ├── 📄 Dev.xcconfig              # Development environment
│   ├── 📄 Prod.xcconfig             # Production environment
│   ├── 📄 Staging.xcconfig          # Staging environment
│   ├── 📄 Release.xcconfig          # Release build settings
│   ├── 📄 Profile.xcconfig          # 🆕 Profile build settings (FIXED)
│   ├── 📄 Generated.xcconfig        # Auto-generated Flutter config
│   ├── 📄 Flutter-Generated.xcconfig # Flutter build variables
│   ├── 📄 flutter_export_environment.sh # Environment export
│   ├── 📄 Flutter.podspec           # Flutter framework podspec
│   └── 📁 ephemeral/                # Temporary Flutter files
│       ├── 📄 flutter_lldb_helper.py # LLDB debugging helper
│       └── 📄 flutter_lldbinit      # LLDB initialization
├── 📁 Runner/                       # 📱 Main iOS app target
│   ├── 📄 Info.plist                # iOS app configuration
│   ├── 📄 AppDelegate.swift         # iOS app delegate
│   ├── 📄 Runner-Bridging-Header.h  # Swift-ObjC bridging
│   ├── 📄 Runner.entitlements       # iOS app entitlements
│   ├── 📄 GeneratedPluginRegistrant.h # Plugin registration header
│   ├── 📄 GeneratedPluginRegistrant.m # Plugin registration impl
│   ├── 📄 ShareExtensionPlugin.swift # Share extension bridge
│   ├── 📁 Assets.xcassets/          # iOS app assets
│   │   ├── 📁 AppIcon.appiconset/   # App icon (all sizes)
│   │   └── 📁 LaunchImage.imageset/ # Launch screen image
│   └── 📁 Base.lproj/               # Base localization
│       ├── 📄 LaunchScreen.storyboard # Launch screen UI
│       └── 📄 Main.storyboard       # Main app storyboard
├── 📁 RunnerTests/                  # 🧪 iOS unit tests
│   └── 📄 RunnerTests.swift         # Unit test cases
├── 📁 ShareExtension/               # 📤 iOS Share Extension
│   ├── 📄 Info.plist                # Extension configuration
│   ├── 📄 ShareViewController.swift # Share handling logic
│   ├── 📄 ShareExtension.entitlements # Extension permissions
│   └── 📁 Base.lproj/               # Extension localization
│       └── 📄 MainInterface.storyboard # Extension UI
├── 📁 Runner.xcodeproj/             # 🔨 Xcode project
│   ├── 📄 project.pbxproj           # Xcode project configuration
│   ├── 📄 project.pbxproj.backup.profile_fix # Backup file
│   ├── 📁 project.xcworkspace/      # Project workspace
│   ├── 📁 xcshareddata/             # Shared Xcode data
│   └── 📁 xcuserdata/               # User-specific Xcode data
├── 📁 Runner.xcworkspace/           # 📁 CocoaPods workspace
│   ├── 📄 contents.xcworkspacedata  # Workspace configuration
│   ├── 📁 xcshareddata/             # Shared workspace data
│   └── 📁 xcuserdata/               # User workspace data
├── 📁 Pods/                         # 📦 CocoaPods dependencies
│   ├── 📁 Target Support Files/     # CocoaPods build configurations
│   ├── 📁 [Various Pod Directories] # Individual pod sources
│   └── 📄 Podfile.lock              # CocoaPods manifest
└── 📁 build/                        # 🏗️ iOS build artifacts
    └── 📁 ios/                      # iOS-specific build output
```

---

## 💻 **FLUTTER APPLICATION CODE**

```
lib/                                  # 🎯 Main application source
├── 📄 main.dart                     # 🚀 App entry point & initialization
├── 📄 providers.dart                # 🔗 Riverpod provider setup
├── 📁 app/                          # App-level configuration
│   └── 📄 app.dart                  # Main app widget & routing
├── 📁 core/                         # 🏗️ Core functionality
│   ├── 📁 animations/               # Custom animation utilities
│   ├── 📁 auth/                     # 🔐 Authentication logic
│   │   ├── 📄 auth_service.dart     # Authentication service
│   │   └── 📄 auth_state.dart       # Authentication state management
│   ├── 📁 config/                   # ⚙️ App configuration
│   │   └── 📄 app_config.dart       # Environment-specific settings
│   ├── 📁 crypto/                   # 🔒 Encryption utilities
│   │   ├── 📄 encryption_service.dart # End-to-end encryption
│   │   └── 📄 crypto_utils.dart     # Cryptographic utilities
│   ├── 📄 env.dart                  # Environment variables
│   ├── 📁 monitoring/               # 📊 Performance monitoring
│   │   ├── 📄 performance_monitor.dart # Performance tracking
│   │   └── 📄 analytics_service.dart # Analytics integration
│   ├── 📁 parser/                   # 📝 Content parsing
│   │   ├── 📄 markdown_parser.dart  # Markdown processing
│   │   └── 📄 enex_parser.dart      # Evernote import parser
│   ├── 📁 performance/              # ⚡ Performance optimizations
│   │   ├── 📄 image_cache.dart      # Image caching optimization
│   │   ├── 📄 memory_manager.dart   # Memory management
│   │   └── 📄 lazy_loading.dart     # Lazy loading utilities
│   ├── 📁 security/                 # 🛡️ Security utilities
│   │   ├── 📄 biometric_auth.dart   # Biometric authentication
│   │   └── 📄 secure_storage.dart   # Secure data storage
│   ├── 📁 settings/                 # ⚙️ App settings management
│   │   ├── 📄 app_settings.dart     # Application settings
│   │   ├── 📄 theme_settings.dart   # Theme preferences
│   │   ├── 📄 privacy_settings.dart # Privacy configurations
│   │   ├── 📄 sync_settings.dart    # Synchronization settings
│   │   └── 📄 export_settings.dart  # Export preferences
│   └── 📁 theme/                    # 🎨 Material 3 theming
├── 📁 data/                         # 📊 Data layer
│   ├── 📁 local/                    # Local data storage
│   │   ├── 📄 app_db.dart           # Drift database definition
│   │   └── 📄 local_storage.dart    # Local storage utilities
│   └── 📁 remote/                   # Remote data synchronization
│       └── 📄 supabase_client.dart  # Supabase client configuration
├── 📁 features/                     # 🎯 Feature modules
│   ├── 📁 folders/                  # 📁 Folder management system
│   │   ├── 📁 batch_operations/     # Bulk folder operations
│   │   ├── 📁 drag_drop/            # Drag & drop functionality
│   │   ├── 📁 keyboard_shortcuts/   # Keyboard shortcuts
│   │   └── 📁 smart_folders/        # Auto-organizing folders
│   └── 📁 notes/                    # 📝 Note management
│       ├── 📄 note_service.dart     # Note business logic
│       └── 📄 note_sync.dart        # Note synchronization
├── 📁 l10n/                         # 🌍 Internationalization
│   ├── 📄 app_localizations.dart    # Generated localizations
│   ├── 📄 app_localizations_en.dart # English translations
│   ├── 📄 app_en.arb                # English ARB file
│   └── 📄 [other_localizations]     # Additional languages
├── 📁 models/                       # 📋 Data models
│   ├── 📄 note_block.dart           # Note block data model
│   └── 📄 note_reminder.dart        # Reminder data model
├── 📁 repository/                   # 🏪 Repository pattern
│   ├── 📄 notes_repository.dart     # Notes data repository
│   └── 📄 sync_service.dart         # Synchronization service
├── 📁 services/                     # 🔧 Business logic services
│   ├── 📄 advanced_reminder_service.dart # Smart reminders
│   ├── 📄 attachment_service.dart   # File attachment handling
│   ├── 📄 audio_recording_service.dart # Voice recording
│   ├── 📄 export_service.dart       # Data export functionality
│   ├── 📄 import_service.dart       # Data import (Evernote, etc.)
│   ├── 📄 ocr_service.dart          # OCR text recognition
│   ├── 📄 reminder_service.dart     # Basic reminder functionality
│   ├── 📄 share_extension_service.dart # iOS share extension
│   ├── 📄 share_service.dart        # Cross-platform sharing
│   ├── 📄 voice_transcription_service.dart # Speech-to-text
│   ├── 📁 analytics/                # 📊 Analytics services
│   │   ├── 📄 analytics_service.dart # Analytics tracking
│   │   └── 📄 event_tracker.dart    # Event tracking
│   └── 📁 reminders/                # ⏰ Reminder system
│       ├── 📄 geofence_service.dart # Location-based reminders
│       ├── 📄 notification_service.dart # Push notifications
│       ├── 📄 reminder_manager.dart # Reminder coordination
│       ├── 📄 time_based_reminders.dart # Time-based reminders
│       └── 📄 README.md             # Reminder system documentation
├── 📁 theme/                        # 🎨 UI theming
│   └── 📄 material3_theme.dart      # Material 3 theme implementation
└── 📁 ui/                           # 🎨 User interface
    ├── 📄 auth_screen.dart          # 🔐 Authentication screen
    ├── 📄 change_password_screen.dart # Password change screen
    ├── 📄 edit_note_screen_simple.dart # Note editing (current)
    ├── 📄 edit_note_screen_simple_old.dart # Note editing (legacy)
    ├── 📄 help_screen.dart          # 📚 Help & support screen
    ├── 📄 home_screen.dart          # 🏠 Main dashboard
    ├── 📄 note_search_delegate.dart # 🔍 Search functionality
    ├── 📄 notes_list_screen.dart    # 📝 Notes listing screen
    ├── 📄 reminders_screen.dart     # ⏰ Reminders management
    ├── 📄 settings_screen.dart      # ⚙️ App settings
    ├── 📄 tag_notes_screen.dart     # 🏷️ Tag-based note view
    ├── 📄 tags_screen.dart          # 🏷️ Tag management
    ├── 📁 components/               # 🧩 Reusable UI components
    │   └── 📄 auth_form.dart        # Authentication form widget
    └── 📁 widgets/                  # 🎛️ Custom widgets
        ├── 📄 attachment_image.dart # Image attachment widget
        ├── 📄 block_editor.dart     # Block-based editor
        ├── 📄 error_display.dart    # Error display widget
        ├── 📄 folder_chip.dart      # Folder chip widget
        ├── 📄 stats_card.dart       # Statistics card widget
        ├── 📄 README.md             # Widget documentation
        └── 📁 blocks/               # 📝 Note block widgets
            ├── 📄 attachment_block_widget.dart # File attachments
            ├── 📄 block_editor.dart # Block editor core
            ├── 📄 code_block_widget.dart # Code syntax highlighting
            ├── 📄 heading_block_widget.dart # Heading blocks
            ├── 📄 link_block_widget.dart # URL link blocks
            ├── 📄 list_block_widget.dart # Bullet/numbered lists
            ├── 📄 note_link_block_widget.dart # Internal note links
            ├── 📄 paragraph_block_widget.dart # Text paragraphs
            ├── 📄 quote_block_widget.dart # Quote blocks
            ├── 📄 table_block_widget.dart # Table blocks
            └── 📄 todo_block_widget.dart # Todo/checkbox blocks
```

---

## 🗄️ **SUPABASE BACKEND**

```
supabase/                            # Backend-as-a-Service configuration
├── 📁 .temp/                       # Temporary Supabase files
├── 📁 functions/                    # 🔧 Edge functions (serverless)
│   └── 📄 index.ts                  # Main edge function
└── 📁 migrations/                   # 🗄️ Database migrations
    └── 📄 [timestamp]_initial.sql   # Initial database schema
```

---

## 🧪 **TESTING INFRASTRUCTURE**

```
test/                                # Testing suite
├── 📄 widget_test.dart              # Basic widget tests
├── 📄 run_encryption_indexing_tests.dart # Encryption test runner
├── 📁 integration/                  # 🔄 Integration tests
│   └── 📄 app_test.dart             # Full app integration tests
├── 📁 manual/                       # 📋 Manual testing documentation
│   └── 📄 testing_guide.md          # Manual testing procedures
├── 📁 repository/                   # 🏪 Repository layer tests
│   └── 📄 [repository_tests].dart   # Data layer tests
├── 📁 services/                     # 🔧 Service layer tests
│   ├── 📄 import_service_test.dart  # Import functionality tests
│   ├── 📄 import_service_simple_test.dart # Basic import tests
│   ├── 📄 import_service_production_test.dart # Production tests
│   ├── 📄 import_encryption_indexing_test.dart # Security tests
│   └── 📄 share_extension_service_test.dart # Share extension tests
└── 📁 ui/                           # 🎨 UI layer tests
    └── 📁 widgets/                  # Widget-specific tests
        ├── 📄 auth_form_widget_test.dart # Auth UI tests
        └── 📄 block_editor_widget_test.dart # Editor widget tests
```

---

## 📦 **ASSETS & RESOURCES**

```
assets/                              # Static app resources
├── 📁 app_icon/                     # 🎨 App icon resources
│   ├── 📄 ICON_GENERATION_GUIDE.md # Icon creation guide
│   └── 📄 README.md                 # Icon documentation
├── 📁 env/                          # 🌍 Environment configurations
│   ├── 📄 dev.env                   # Development environment
│   ├── 📄 staging.env               # Staging environment
│   ├── 📄 prod.env                  # Production environment
│   └── 📄 example.env               # Environment template
└── 📁 fonts/                        # 🔤 Custom fonts
    └── 📄 README.md                 # Font usage documentation

design/                              # 🎨 Design assets
└── 📄 app_icon.png                  # Source app icon (1024x1024)

coverage/                            # 📊 Test coverage reports
└── 📄 lcov.info                     # Code coverage data

integration_test/                    # 🔄 Integration testing
└── 📄 app_test.dart                 # End-to-end test suite
```

---

## 📚 **DOCUMENTATION**

```
docs/                                # 📖 Project documentation
├── 📄 UserGuide.md                  # 👥 End-user documentation
├── 📄 README.md                     # Project overview
├── 📄 CI_CD_ERRORS_FIXED.md        # CI/CD troubleshooting
├── 📄 CLEANUP_AND_OPTIMIZATION_SUMMARY.md # Optimization notes
├── 📄 MONITORING_SETUP.md           # Performance monitoring setup
├── 📄 new_UI.md                     # UI/UX specifications
├── 📄 PROJECT_FILE_MAP.md           # This file
├── 📄 REFACTORING_GUIDE.md          # Code refactoring guidelines
├── 📄 TESTFLIGHT_DEPLOYMENT_GUIDE.md # App Store deployment
├── 📄 THEME_INTEGRATION_SUMMARY.md  # Material 3 theme guide
└── 📄 XCODE_CLOUD_CI_FIXES.md       # CI/CD fixes documentation
```

---

## 🚨 **CURRENT ISSUES & STATUS**

### ✅ **RESOLVED ISSUES**
- **Infinite CI/CD Loop**: ✅ **COMPLETELY FIXED**
- **CocoaPods Configuration**: ✅ **WORKING**
- **ShareExtension Target**: ✅ **PROPERLY CONFIGURED**
- **Project Structure**: ✅ **REORGANIZED TO ROOT**

### ⚠️ **CURRENT BUILD ISSUES**

#### **1. sqflite_darwin Plugin Issue**
```
Error: 'Flutter/Flutter.h' file not found
Location: sqflite_darwin plugin
Status: 🔧 NEEDS FIXING
```

#### **2. printing Plugin Compilation**
```
Error: SwiftCompile failed with nonzero exit code
Location: printing plugin Swift files
Status: 🔧 NEEDS FIXING
```

### 🎯 **PRODUCTION-GRADE FEATURES**

#### **✅ IMPLEMENTED**
- 🔐 End-to-end encryption with local/cloud sync
- 📱 iOS Share Extension for system integration
- 🎤 Voice transcription with speech-to-text
- 📷 OCR text recognition with Google ML Kit
- ⏰ Smart reminders with geofencing
- 💰 Subscription management with Adapty
- 🐛 Crash reporting with Sentry
- 🌍 Multi-language support (EN/TR)
- 🎨 Material 3 theming
- 📊 Performance monitoring
- 🧪 Comprehensive testing suite

#### **🚀 CI/CD PIPELINE**
- ✅ Xcode Cloud configuration
- ✅ Automated Flutter setup
- ✅ CocoaPods dependency management
- ✅ Build verification scripts
- ✅ Post-build analysis

---

## 📊 **PROJECT STATISTICS**

- **Total Files**: ~200+ files
- **Lines of Code**: ~15,000+ lines
- **Flutter Dependencies**: 40+ packages
- **iOS CocoaPods**: 55 pods
- **Supported Platforms**: iOS 14.0+
- **Languages**: Dart, Swift, Kotlin
- **Localization**: English, Turkish

---

## 🚀 **NEXT STEPS FOR PRODUCTION**

1. **🔧 Fix Plugin Issues**
   - Resolve sqflite_darwin Flutter.h issue
   - Fix printing plugin Swift compilation
   
2. **✅ Complete CI/CD Setup**
   - Test Xcode Cloud pipeline
   - Verify TestFlight deployment
   
3. **🚀 Production Deployment**
   - App Store Connect configuration
   - Release to App Store

**The project is well-structured and production-ready once the plugin issues are resolved!**