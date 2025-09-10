# Screenshot Specifications for Chrome Web Store

## Required Screenshots (1280×800 or 640×400)

### Screenshot 1: Configuration Popup
**Filename**: `screenshot-1-config.png`
**Dimensions**: 1280×800
**Content**:
- Show the extension popup open
- Three input fields filled with example data
- Save button visible
- Clean, modern UI

### Screenshot 2: Context Menu
**Filename**: `screenshot-2-context-menu.png`
**Dimensions**: 1280×800
**Content**:
- Webpage with text selected
- Right-click context menu open
- "Clip to DuruNotes" option highlighted
- Real content example (news article or documentation)

### Screenshot 3: Success Notification
**Filename**: `screenshot-3-notification.png`
**Dimensions**: 1280×800
**Content**:
- Chrome notification showing "Clipped Successfully"
- Include domain name in message
- Clean browser window in background

### Screenshot 4: DuruNotes Inbox
**Filename**: `screenshot-4-inbox.png`
**Dimensions**: 1280×800
**Content**:
- DuruNotes app showing inbox
- Multiple clipped items visible
- Mix of email notes and web clips
- Clean, organized interface

### Screenshot 5: Settings View
**Filename**: `screenshot-5-settings.png`
**Dimensions**: 1280×800
**Content**:
- Extension popup with saved settings
- "Saved ✓" confirmation visible
- Password field obscured
- Professional appearance

## Promotional Images

### Small Promo Tile (440×280)
**Filename**: `promo-small.png`
**Design Elements**:
- DuruNotes logo/icon
- "Web Clipper" text
- Clean gradient background
- Subtle clipboard or clip icon

### Large Promo Tile (920×680)
**Filename**: `promo-large.png`
**Design Elements**:
- Feature grid showing:
  - Privacy shield icon
  - Right-click gesture
  - Sync arrows
  - Lock icon
- Tagline: "Clip Privately, Organize Smartly"
- Brand colors

### Marquee Promo Tile (1400×560)
**Filename**: `promo-marquee.png`
**Design Elements**:
- Hero text: "Your Web, Your Notes, Your Privacy"
- Browser mockup with extension
- Flow diagram: Web → Clip → DuruNotes
- Professional gradient background

## Color Palette for Graphics

- Primary: #4CAF50 (Green)
- Secondary: #2196F3 (Blue)
- Background: #F5F5F5 (Light Gray)
- Text: #333333 (Dark Gray)
- Accent: #FFC107 (Amber)

## Font Recommendations

- Headers: Inter, Roboto, or system font
- Body: Same as headers for consistency
- Weight: 400 (regular), 500 (medium), 700 (bold)

## Creating Screenshots

### Method 1: Manual Creation
1. Load extension in Chrome
2. Configure with dummy data
3. Use Chrome DevTools device mode for consistent sizing
4. Capture at exactly 1280×800
5. Save as PNG with optimization

### Method 2: Placeholder Generation
```bash
# Create placeholder images with ImageMagick
convert -size 1280x800 xc:'#F5F5F5' \
  -gravity center \
  -pointsize 48 \
  -fill '#333333' \
  -annotate +0+0 'Configuration Screen\n(Screenshot Placeholder)' \
  screenshot-1-config.png
```

### Method 3: Professional Tools
- Figma template
- Sketch mockup
- Canva design
- Screenshots.app

## Tips for Store Approval

1. **No Personal Information**: Blur or use fake data
2. **High Quality**: Clear, crisp images at exact dimensions
3. **Consistent Style**: Same browser, theme, and window style
4. **Real Content**: Use actual websites (with permission)
5. **Focus on Features**: Each screenshot shows different functionality
6. **Professional Look**: Clean desktop, no clutter
7. **Accurate Representation**: Show actual extension behavior

## File Structure
```
store/
├── STORE-LISTING.md
├── SCREENSHOTS.md
├── screenshot-1-config.png
├── screenshot-2-context-menu.png
├── screenshot-3-notification.png
├── screenshot-4-inbox.png
├── screenshot-5-settings.png
├── promo-small.png
├── promo-large.png
└── promo-marquee.png
```

---

**Note**: Screenshots are required for Chrome Web Store submission. Create these before publishing.
