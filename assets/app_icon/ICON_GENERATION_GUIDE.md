# Duru Notes Icon Generation Guide

## Quick Setup Instructions

### 1. Install flutter_launcher_icons
```bash
flutter pub add --dev flutter_launcher_icons
```

### 2. Add Configuration to pubspec.yaml
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/app_icon/master_icon.png"
  min_sdk_android: 21
  web:
    generate: true
    image_path: "assets/app_icon/master_icon.png"
  windows:
    generate: true
    image_path: "assets/app_icon/master_icon.png"
    icon_size: 48
  macos:
    generate: true
    image_path: "assets/app_icon/master_icon.png"
  adaptive_icon_background: "#2563EB"
  adaptive_icon_foreground: "assets/app_icon/adaptive_foreground.png"
```

### 3. Generate Icons
```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

## Icon Design Specifications

### Master Icon Requirements
- **Format**: PNG with transparency
- **Size**: 1024x1024px minimum
- **DPI**: 300+ for print quality
- **Color Space**: sRGB
- **Compression**: Lossless PNG

### Design Concept for Duru Notes

#### Visual Elements
1. **Primary Symbol**: Modern note/document icon
   - Clean rectangular shape with subtle corner radius
   - Minimalist line representing text content
   
2. **Security Indicator**: Small lock or shield overlay
   - Positioned in bottom-right corner
   - Sized at ~25% of main icon
   - Uses secondary color for contrast

3. **Intelligence Element**: Subtle brain or lightbulb
   - Optional enhancement for "smart notes" concept
   - Integrated into document design
   - Very subtle, not overwhelming

#### Color Scheme
```
Primary Blue: #2563EB (RGB: 37, 99, 235)
Secondary Amber: #F59E0B (RGB: 245, 158, 11)
Background: #FFFFFF (White)
Text/Lines: #1E293B (Slate 800)
Accent: #E2E8F0 (Slate 200)
```

#### Typography (if text included)
- **Font**: San Francisco (iOS) / Roboto (Android)
- **Weight**: Medium (500)
- **Size**: Proportional to icon size
- **Color**: Slate 800 (#1E293B)

## Platform-Specific Considerations

### iOS Icons
- **No rounded corners** in source (iOS applies automatically)
- **No drop shadows** or glows
- **Fill entire square** canvas
- **Test on various backgrounds** (light/dark)

### Android Adaptive Icons
- **Foreground**: Main icon elements (can extend beyond safe zone)
- **Background**: Solid color or simple pattern
- **Safe Zone**: 66dp diameter circle in center
- **Mask**: System applies circle, square, or rounded square

### Brand Guidelines

#### Do's ✅
- Keep design simple and recognizable
- Use consistent colors across all sizes
- Ensure readability at 29x29px (smallest iOS size)
- Follow platform-specific guidelines
- Test on various device backgrounds

#### Don'ts ❌
- Use fine details that disappear at small sizes
- Include text (except for very simple wordmarks)
- Use more than 3-4 colors
- Copy other app designs
- Use low-resolution source images

## File Organization

### Directory Structure
```
assets/app_icon/
├── master_icon.png              # 1024x1024 main source
├── adaptive_foreground.png      # Android adaptive foreground
├── splash_icon.png              # Splash screen version
└── generated/                   # Auto-generated files
    ├── ios/
    └── android/
```

### Naming Conventions
- Use descriptive names
- Include size in filename for manual icons
- Follow platform conventions
- Use lowercase with underscores

## Testing Checklist

### Visual Testing
- [ ] Readable at 20x20px
- [ ] Consistent across all generated sizes
- [ ] Good contrast on light backgrounds
- [ ] Good contrast on dark backgrounds
- [ ] No pixelation or artifacts
- [ ] Colors appear correct on different screens

### Platform Testing
- [ ] iOS: Test on multiple device types
- [ ] Android: Test adaptive icon with different masks
- [ ] Verify proper installation and display
- [ ] Check app drawer/home screen appearance
- [ ] Validate settings menu appearance

### Store Requirements
- [ ] No trademark violations
- [ ] Original artwork only
- [ ] Appropriate content rating
- [ ] High quality and professional
- [ ] Consistent with app purpose

## Manual Icon Creation (Alternative)

If not using automated generation, create these sizes manually:

### iOS Sizes (PNG, no transparency for App Store)
```
1024x1024 - App Store
180x180   - iPhone @3x
120x120   - iPhone @2x, iPad Spotlight @2x
152x152   - iPad @2x
87x87     - Settings @3x
80x80     - Spotlight @2x
76x76     - iPad @1x
60x60     - Notification @3x
58x58     - Settings @2x
40x40     - Spotlight @1x, Notification @2x
29x29     - Settings @1x
20x20     - Notification @1x
```

### Android Sizes (PNG)
```
512x512 - Play Store
192x192 - XXXHDPI
144x144 - XXHDPI
96x96   - XHDPI
72x72   - HDPI
48x48   - MDPI
```

## Integration Steps

### 1. Place Source Files
```bash
# Copy your master icon
cp your_icon.png assets/app_icon/master_icon.png

# Copy adaptive foreground (if different)
cp your_adaptive.png assets/app_icon/adaptive_foreground.png
```

### 2. Update pubspec.yaml
Add the flutter_icons configuration shown above.

### 3. Generate
```bash
flutter pub run flutter_launcher_icons:main
```

### 4. Verify
Check that icons appear in:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `android/app/src/main/res/mipmap-*/`

### 5. Test
```bash
flutter run
```

Verify icons appear correctly on device/simulator.

## Troubleshooting

### Common Issues
1. **Icon appears blurry**: Source resolution too low
2. **Colors look different**: Check color space (use sRGB)
3. **Generation fails**: Verify file paths in pubspec.yaml
4. **iOS icons have white background**: Remove transparency for App Store icon

### Quality Validation
```bash
# Check file sizes
ls -la ios/Runner/Assets.xcassets/AppIcon.appiconset/
ls -la android/app/src/main/res/mipmap-*/

# Verify no corruption
file assets/app_icon/master_icon.png
```

---

*Create your master icon following these guidelines, then run the generation process to create all required sizes automatically.*
