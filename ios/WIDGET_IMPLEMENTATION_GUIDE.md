# iOS Widget Implementation Guide for Duru Notes

## Prerequisites
- Xcode 16.4 or later
- Physical iOS device (widgets don't appear properly in simulator)
- Apple Developer account configured

## Step-by-Step Implementation

### 1. Open Xcode
```bash
open ios/Runner.xcworkspace
```

### 2. Create Widget Extension Target

1. In Xcode, click on the **Runner** project (blue icon at top)
2. Click the **"+"** button at bottom of targets list
3. Select **iOS → Application Extension → Widget Extension**
4. Configure:
   - **Product Name:** `DuruNotesWidget`
   - **Team:** Select your team (Fittechs Yazilim Anonim Sirketi)
   - **Organization Identifier:** `com.fittechs.duruNotesApp`
   - **Bundle Identifier:** Will auto-fill as `com.fittechs.duruNotesApp.DuruNotesWidget`
   - **Include Configuration Intent:** ✅ Check this
   - **Project:** Runner
   - **Embed in Application:** Runner
5. Click **Finish**
6. When asked "Activate scheme?", click **Cancel**

### 3. Configure App Groups (CRITICAL!)

#### For Runner Target:
1. Select **Runner** target
2. Go to **Signing & Capabilities** tab
3. Click **"+ Capability"**
4. Add **"App Groups"**
5. Click **"+"** under App Groups
6. Enter: `group.com.fittechs.durunotes`
7. Ensure it's checked ✅

#### For Widget Target:
1. Select **DuruNotesWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **"+ Capability"**
4. Add **"App Groups"**
5. Click **"+"** under App Groups
6. Enter: `group.com.fittechs.durunotes` (MUST be identical!)
7. Ensure it's checked ✅

### 4. Replace Auto-Generated Files

Delete the auto-generated files in DuruNotesWidget folder and add our custom implementation.

### 5. Add Widget Bridge to Runner

Create a bridge file in Runner to communicate with the widget.

### 6. Build and Test

1. Clean build folder: **Cmd+Shift+K**
2. Build: **Cmd+B**
3. Run on device: **Cmd+R**

### 7. Important Notes

- Widgets only appear when built in **Release** mode
- Use `flutter build ios --release` for production builds
- The app must run at least once before the widget appears
- Search for "Duru" in the widget gallery

## Troubleshooting

### Widget Not Appearing
1. Ensure App Groups are configured correctly
2. Build in Release mode
3. Check that widget extension is embedded in Runner target
4. Restart device if necessary

### Build Errors
1. Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
2. Clean Flutter: `flutter clean`
3. Reinstall pods: `cd ios && pod install`

## File Structure
```
ios/
├── Runner/
│   └── WidgetBridge.swift
└── DuruNotesWidget/
    ├── DuruNotesWidget.swift
    ├── DuruNotesWidgetBundle.swift
    ├── Info.plist
    └── Assets.xcassets/
```
