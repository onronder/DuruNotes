# Duru Notes App Icons & Splash Screens

This directory contains all the app icons and splash screens for Duru Notes across different platforms and resolutions.

## App Icon Specifications

### iOS Icons Required
- **App Store**: 1024x1024px (PNG, no transparency)
- **iPhone**: 
  - 180x180px (60pt @3x)
  - 120x120px (60pt @2x)
- **iPad**:
  - 152x152px (76pt @2x)
  - 76x76px (76pt @1x)
- **Settings**:
  - 87x87px (29pt @3x)
  - 58x58px (29pt @2x)
  - 29x29px (29pt @1x)
- **Spotlight**:
  - 120x120px (40pt @3x)
  - 80x80px (40pt @2x)
  - 40x40px (40pt @1x)
- **Notification**:
  - 60x60px (20pt @3x)
  - 40x40px (20pt @2x)
  - 20x20px (20pt @1x)

### Android Icons Required
- **Launcher Icons**:
  - 192x192px (XXXHDPI)
  - 144x144px (XXHDPI)
  - 96x96px (XHDPI)
  - 72x72px (HDPI)
  - 48x48px (MDPI)
- **Adaptive Icons** (API 26+):
  - 108x108px foreground/background layers
- **Play Store**: 512x512px (PNG, no transparency)

### Design Guidelines

#### Visual Identity
- **Primary Color**: #2563EB (Blue 600)
- **Secondary Color**: #F59E0B (Amber 500)
- **Background**: #FFFFFF (White) or #F8FAFC (Slate 50)
- **Text/Icon**: #1E293B (Slate 800)

#### Icon Concept
The Duru Notes icon should represent:
1. **Note-taking**: Document/paper element
2. **Intelligence**: Brain/lightbulb element
3. **Security**: Lock/shield element
4. **Simplicity**: Clean, modern design

#### Design Elements
- **Main Symbol**: Stylized note/document with a secure lock overlay
- **Typography**: Clean, modern sans-serif for any text
- **Style**: Minimal, flat design with subtle gradients
- **Corners**: Rounded corners following platform guidelines

## Splash Screen Specifications

### iOS Launch Screen
- **Storyboard-based**: Uses Auto Layout constraints
- **Universal**: Works across all device sizes
- **Assets**: Background color + logo
- **Dimensions**: Logo should be 120x120pt maximum

### Android Splash Screen
- **API 31+ (Android 12)**: Uses new splash screen API
- **Legacy**: Traditional drawable-based splash
- **Assets**: 
  - Icon: 288x288dp (adaptive)
  - Background: Solid color or simple drawable

## File Structure
```
assets/app_icon/
├── README.md                 # This file
├── ios/
│   ├── Icon-App-1024x1024.png    # App Store
│   ├── Icon-App-60x60@2x.png     # iPhone
│   ├── Icon-App-60x60@3x.png     # iPhone
│   ├── Icon-App-76x76.png        # iPad
│   ├── Icon-App-76x76@2x.png     # iPad
│   ├── Icon-App-29x29.png        # Settings
│   ├── Icon-App-29x29@2x.png     # Settings
│   ├── Icon-App-29x29@3x.png     # Settings
│   ├── Icon-App-40x40.png        # Spotlight
│   ├── Icon-App-40x40@2x.png     # Spotlight
│   ├── Icon-App-40x40@3x.png     # Spotlight
│   ├── Icon-App-20x20.png        # Notification
│   ├── Icon-App-20x20@2x.png     # Notification
│   └── Icon-App-20x20@3x.png     # Notification
├── android/
│   ├── mipmap-mdpi/
│   │   └── ic_launcher.png        # 48x48
│   ├── mipmap-hdpi/
│   │   └── ic_launcher.png        # 72x72
│   ├── mipmap-xhdpi/
│   │   └── ic_launcher.png        # 96x96
│   ├── mipmap-xxhdpi/
│   │   └── ic_launcher.png        # 144x144
│   ├── mipmap-xxxhdpi/
│   │   └── ic_launcher.png        # 192x192
│   ├── adaptive/
│   │   ├── ic_launcher_foreground.xml
│   │   └── ic_launcher_background.xml
│   └── play_store.png             # 512x512
├── splash/
│   ├── ios/
│   │   ├── LaunchImage.png        # 1x
│   │   ├── LaunchImage@2x.png     # 2x
│   │   └── LaunchImage@3x.png     # 3x
│   └── android/
│       ├── splash_icon.png        # 288x288dp
│       └── splash_background.xml
└── source/
    ├── master_icon.svg            # Source vector file
    ├── master_icon.ai             # Adobe Illustrator source
    └── color_palette.aco          # Color swatches
```

## Generation Tools

### Recommended Tools
1. **flutter_launcher_icons** package for automated generation
2. **Adobe Illustrator** or **Figma** for design
3. **ImageOptim** for compression
4. **Icon Slate** (macOS) for batch resizing

### Automated Generation
Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/app_icon/source/master_icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#2563EB"
  adaptive_icon_foreground: "assets/app_icon/source/adaptive_foreground.png"
```

## Quality Checklist

### Before Submission
- [ ] All required sizes generated
- [ ] No transparency in App Store/Play Store icons
- [ ] Icons appear crisp at all sizes
- [ ] Colors match brand guidelines
- [ ] No copyright violations
- [ ] Proper file naming conventions
- [ ] Optimized file sizes
- [ ] Tested on various device backgrounds
- [ ] Accessibility considerations met
- [ ] Platform-specific guidelines followed

### Testing
- [ ] Test on light/dark backgrounds
- [ ] Verify readability at small sizes
- [ ] Check visual consistency across platforms
- [ ] Validate in various contexts (home screen, settings, etc.)

## Brand Guidelines Compliance

### App Store Guidelines
- No Apple logos or references
- No misleading representations
- Consistent with app functionality
- High quality and professional appearance

### Play Store Guidelines
- Original artwork only
- Clear and recognizable at all sizes
- Consistent with Material Design principles
- No violent or inappropriate content

---

*Note: Replace placeholder icons with actual high-resolution assets before production release.*
