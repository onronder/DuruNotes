# Phase 2.3: Handwriting & Drawing Implementation Plan
**Feature**: Handwriting & Drawing Support
**Status**: 📋 Ready to Start
**Dependencies**: ✅ Phase 2.1 & 2.2 Complete
**Estimated Time**: 4-6 weeks
**Priority**: HIGH

---

## Executive Summary

Phase 2.3 adds handwriting and drawing capabilities to Duru Notes, enabling users to create sketch notes, annotate content, and capture handwritten ideas. This phase includes a Flutter-based drawing canvas, professional drawing tools, and integration with platform-specific APIs for optimized stylus input.

---

## Prerequisites ✅

All prerequisites met:
- ✅ Phase 2.1 Complete (Organization Features)
- ✅ Phase 2.2 Flutter Layer Complete (Attachment handling ready)
- ✅ Encrypted attachment storage working
- ✅ Test suite stable (97.6% passing)
- ✅ Core infrastructure mature

---

## Feature Requirements

### Must-Have (P0)
1. **Flutter Drawing Canvas**
   - Custom painter implementation
   - Touch input support
   - Smooth stroke rendering
   - Multi-touch handling (pinch to zoom, pan)
   - Background color selection

2. **Drawing Tools**
   - ✏️ **Pen**: Variable width, pressure sensitivity
   - 🖍️ **Highlighter**: Semi-transparent overlay
   - 🧹 **Eraser**: Point and stroke eraser modes
   - 📐 **Lasso**: Selection tool for moving/resizing

3. **Undo/Redo System**
   - Command pattern implementation
   - Stack-based history
   - Memory-efficient storage
   - Limit to 50 actions

4. **Attachment Integration**
   - Save drawings as encrypted attachments
   - PNG export with transparency
   - Thumbnail generation
   - Inline display in notes

5. **Editor Embedding**
   - Inline drawing widget in markdown editor
   - Tap to edit existing drawings
   - Create new drawing from toolbar
   - Preview mode

### Should-Have (P1)
1. **Stylus Support**
   - iOS PencilKit integration
   - Android Stylus API integration
   - Pressure sensitivity
   - Palm rejection
   - Tilt detection (where supported)

2. **Advanced Tools**
   - Color picker with presets
   - Line thickness selector
   - Shape tools (line, rectangle, circle)
   - Text tool for labels

3. **Export Options**
   - SVG export (vector format)
   - PDF export
   - Image export (PNG, JPEG)
   - Share drawings

### Nice-to-Have (P2)
1. **Layers**
   - Multiple drawing layers
   - Layer visibility toggle
   - Layer reordering

2. **Templates**
   - Grid backgrounds
   - Lined paper
   - Dot grid
   - Custom backgrounds

3. **Collaboration** (Future)
   - Real-time drawing sync
   - Multi-user drawings

---

## Technical Architecture

### Component Structure

```
lib/features/drawing/
├── domain/
│   ├── entities/
│   │   ├── drawing.dart            # Drawing entity
│   │   ├── stroke.dart             # Individual stroke
│   │   ├── drawing_tool.dart       # Tool configuration
│   │   └── drawing_layer.dart      # Layer entity (P2)
│   └── repositories/
│       └── drawing_repository.dart  # Drawing persistence
├── data/
│   ├── repositories/
│   │   └── drawing_repository_impl.dart
│   └── models/
│       ├── drawing_dto.dart
│       └── stroke_dto.dart
├── presentation/
│   ├── widgets/
│   │   ├── drawing_canvas.dart      # Main canvas widget
│   │   ├── drawing_toolbar.dart     # Tool selector
│   │   ├── color_picker.dart        # Color selection
│   │   └── stroke_controls.dart     # Width/opacity
│   ├── controllers/
│   │   ├── drawing_controller.dart  # Canvas state management
│   │   └── tool_controller.dart     # Tool state
│   └── screens/
│       └── drawing_editor_screen.dart
├── services/
│   ├── drawing_service.dart         # Business logic
│   ├── undo_redo_service.dart       # History management
│   ├── export_service.dart          # Export functionality
│   └── stylus_service.dart          # Platform stylus integration
└── platform/
    ├── ios/
    │   └── pencil_kit_integration.dart
    └── android/
        └── stylus_api_integration.dart
```

### Data Models

#### Drawing Entity
```dart
class Drawing {
  final String id;
  final String noteId;
  final List<Stroke> strokes;
  final Size canvasSize;
  final Color backgroundColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DrawingLayer> layers; // P2

  Drawing({
    required this.id,
    required this.noteId,
    required this.strokes,
    required this.canvasSize,
    this.backgroundColor = Colors.white,
    required this.createdAt,
    required this.updatedAt,
    this.layers = const [],
  });
}
```

#### Stroke Entity
```dart
class Stroke {
  final String id;
  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity;
  final DrawingTool tool;
  final BlendMode? blendMode; // For highlighter
  final List<double>? pressureValues; // For stylus

  Stroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    this.opacity = 1.0,
    required this.tool,
    this.blendMode,
    this.pressureValues,
  });
}
```

#### Drawing Tool
```dart
enum DrawingTool {
  pen,
  highlighter,
  eraser,
  lasso,
  line,      // P1
  rectangle, // P1
  circle,    // P1
  text,      // P1
}

class ToolConfiguration {
  final DrawingTool tool;
  final Color color;
  final double width;
  final double opacity;

  ToolConfiguration({
    required this.tool,
    this.color = Colors.black,
    this.width = 2.0,
    this.opacity = 1.0,
  });
}
```

---

## Implementation Phases

### Phase 1: Core Canvas (Week 1)
**Duration**: 5-7 days

#### Deliverables
1. **Custom Painter Implementation**
   - Basic canvas rendering
   - Touch input handling
   - Stroke collection
   - Paint configuration

2. **Drawing Controller**
   - State management (Riverpod)
   - Stroke storage
   - Canvas size management
   - Dirty state tracking

3. **Basic Toolbar**
   - Tool selection (pen only initially)
   - Color picker
   - Width selector
   - Clear canvas button

#### Files to Create
- `lib/features/drawing/presentation/widgets/drawing_canvas.dart`
- `lib/features/drawing/presentation/controllers/drawing_controller.dart`
- `lib/features/drawing/domain/entities/stroke.dart`
- `lib/features/drawing/domain/entities/drawing_tool.dart`

#### Tests to Write
- Canvas widget tests
- Controller state tests
- Touch input simulation tests

---

### Phase 2: Drawing Tools (Week 2)
**Duration**: 5-7 days

#### Deliverables
1. **Pen Tool**
   - Variable width support
   - Smooth curve interpolation
   - Anti-aliasing

2. **Highlighter Tool**
   - Semi-transparent rendering
   - Overlay blend mode
   - Optimized opacity

3. **Eraser Tool**
   - Point eraser (erase at touch point)
   - Stroke eraser (remove entire strokes)
   - Visual feedback

4. **Enhanced Toolbar**
   - Tool switching
   - Tool-specific controls
   - Preview indicators

#### Files to Create
- `lib/features/drawing/services/pen_tool_service.dart`
- `lib/features/drawing/services/highlighter_tool_service.dart`
- `lib/features/drawing/services/eraser_tool_service.dart`
- `lib/features/drawing/presentation/widgets/drawing_toolbar.dart`

#### Tests to Write
- Tool behavior tests
- Eraser logic tests
- Toolbar interaction tests

---

### Phase 3: Undo/Redo & Persistence (Week 3)
**Duration**: 5-7 days

#### Deliverables
1. **Undo/Redo System**
   - Command pattern implementation
   - History stack (limit 50)
   - Undo/redo buttons
   - Keyboard shortcuts (Cmd+Z, Cmd+Shift+Z)

2. **Drawing Persistence**
   - Save drawings to encrypted storage
   - Drawing repository implementation
   - JSON serialization
   - Thumbnail generation

3. **Drawing Entity**
   - Complete entity model
   - Drawing DTO for serialization
   - Migration from sketch to drawing

#### Files to Create
- `lib/features/drawing/services/undo_redo_service.dart`
- `lib/features/drawing/domain/entities/drawing.dart`
- `lib/features/drawing/data/models/drawing_dto.dart`
- `lib/features/drawing/data/repositories/drawing_repository_impl.dart`

#### Tests to Write
- Undo/redo tests
- Serialization tests
- Repository tests
- Thumbnail generation tests

---

### Phase 4: Editor Integration (Week 4)
**Duration**: 5-7 days

#### Deliverables
1. **Inline Drawing Widget**
   - Embedded in markdown editor
   - Tap to edit
   - Preview mode
   - Fullscreen mode

2. **Drawing Editor Screen**
   - Full-featured drawing interface
   - Save/cancel actions
   - Drawing toolbar
   - Status indicators

3. **Note Attachment**
   - Create drawing from note
   - Attach drawing to note
   - Display drawing thumbnails
   - Delete drawing attachments

#### Files to Create
- `lib/features/drawing/presentation/screens/drawing_editor_screen.dart`
- `lib/features/drawing/presentation/widgets/inline_drawing_widget.dart`
- `lib/features/drawing/services/drawing_service.dart`

#### Tests to Write
- Editor screen tests
- Integration tests
- Attachment tests

---

### Phase 5: Stylus Integration (Week 5) - P1
**Duration**: 5-7 days

#### Deliverables
1. **iOS PencilKit Integration**
   - PencilKit wrapper
   - Pressure sensitivity
   - Palm rejection
   - Tilt detection
   - Double-tap to switch tools

2. **Android Stylus API Integration**
   - MotionEvent processing
   - Pressure sensitivity
   - Stylus button support
   - Palm rejection

3. **Platform Service**
   - Abstract stylus interface
   - Platform-specific implementations
   - Capability detection
   - Fallback to touch

#### Files to Create
- `ios/Runner/PencilKitBridge.swift`
- `android/app/src/main/kotlin/StylusHandler.kt`
- `lib/features/drawing/platform/ios/pencil_kit_integration.dart`
- `lib/features/drawing/platform/android/stylus_api_integration.dart`
- `lib/features/drawing/services/stylus_service.dart`

#### Tests to Write
- Platform channel tests
- Stylus detection tests
- Fallback behavior tests

---

### Phase 6: Advanced Features (Week 6) - P1
**Duration**: 5-7 days

#### Deliverables
1. **Advanced Tools**
   - Lasso selection tool
   - Shape tools (line, rectangle, circle)
   - Text tool
   - Fill tool

2. **Export Functionality**
   - PNG export
   - SVG export (vector)
   - PDF export
   - Share drawings

3. **Polish & Performance**
   - Optimize rendering
   - Memory management
   - Smooth animations
   - Loading states

#### Files to Create
- `lib/features/drawing/services/lasso_tool_service.dart`
- `lib/features/drawing/services/shape_tool_service.dart`
- `lib/features/drawing/services/export_service.dart`

#### Tests to Write
- Export tests
- Shape tool tests
- Performance tests

---

## Dependencies & Packages

### Flutter Packages
```yaml
dependencies:
  # Drawing
  flutter_drawing_board: ^0.3.0  # Alternative: custom implementation
  perfect_freehand: ^2.0.0       # Smooth stroke rendering

  # Image Processing
  image: ^4.0.0                   # PNG/JPEG export
  flutter_svg: ^2.0.0             # SVG export

  # Platform Channels
  flutter_platform_alert: ^0.6.0

  # State Management (already included)
  flutter_riverpod: ^2.4.0

  # Storage (already included)
  path_provider: ^2.1.0
```

### Native Dependencies

#### iOS (Podfile)
```ruby
# PencilKit support (iOS 13.0+)
platform :ios, '13.0'
```

#### Android (build.gradle)
```gradle
android {
    compileSdkVersion 34
    minSdkVersion 21  // Stylus APIs available from API 21
}
```

---

## Storage & Encryption

### Drawing Storage Format

#### Database Schema
```sql
-- Drawings table
CREATE TABLE drawings (
    id UUID PRIMARY KEY,
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    canvas_width REAL NOT NULL,
    canvas_height REAL NOT NULL,
    background_color TEXT,
    thumbnail_path TEXT,
    drawing_data BYTEA,  -- Encrypted JSON
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID NOT NULL,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_drawings_note ON drawings(note_id);
CREATE INDEX idx_drawings_user ON drawings(user_id);
```

#### Encrypted Format
```json
{
  "version": "1.0",
  "canvasSize": {"width": 800, "height": 600},
  "backgroundColor": "#FFFFFF",
  "strokes": [
    {
      "id": "uuid",
      "tool": "pen",
      "color": "#000000",
      "width": 2.0,
      "opacity": 1.0,
      "points": [[x, y], [x, y], ...],
      "pressureValues": [0.5, 0.7, ...],  // Optional
      "timestamp": "2025-11-21T12:00:00Z"
    }
  ],
  "layers": []  // P2 feature
}
```

### File Storage
- **Location**: `{app_documents}/drawings/`
- **Format**: Encrypted JSON + PNG thumbnail
- **Naming**: `{drawing_id}.json.enc` and `{drawing_id}_thumb.png`
- **Encryption**: Same encryption service as notes
- **Max Size**: 10MB per drawing (configurable)

---

## UI/UX Design

### Drawing Editor Layout

```
┌─────────────────────────────────────────────┐
│  ←  Save        Drawing Title        Done   │ ← Header
├─────────────────────────────────────────────┤
│  🖊️  🖍️  🧹  📐  │  ⬜  🔴  🔵  🟢  🟡       │ ← Toolbar
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│              Canvas Area                    │ ← Canvas
│                                             │
│                                             │
├─────────────────────────────────────────────┤
│  ↩️  ↪️  │  ━  ━━  ━━━  │  ▢  50%         │ ← Controls
└─────────────────────────────────────────────┘
```

### Tool Icons
- Pen: ✏️
- Highlighter: 🖍️
- Eraser: 🧹
- Lasso: 📐
- Undo: ↩️
- Redo: ↪️

### Color Palette (Default)
- Black: `#000000`
- Red: `#FF0000`
- Blue: `#0000FF`
- Green: `#00FF00`
- Yellow: `#FFFF00`
- Orange: `#FFA500`
- Purple: `#800080`
- Gray: `#808080`

---

## Testing Strategy

### Unit Tests
1. **Stroke Tests**
   - Point interpolation
   - Pressure mapping
   - Serialization

2. **Tool Tests**
   - Pen rendering
   - Highlighter blend modes
   - Eraser logic

3. **Undo/Redo Tests**
   - Command execution
   - Stack limits
   - State restoration

### Widget Tests
1. **Canvas Tests**
   - Touch input
   - Multi-touch gestures
   - Zoom and pan

2. **Toolbar Tests**
   - Tool selection
   - Color picker
   - Width controls

### Integration Tests
1. **Drawing Creation**
   - Create new drawing
   - Add strokes
   - Save drawing

2. **Drawing Editing**
   - Load existing drawing
   - Modify strokes
   - Update drawing

3. **Note Integration**
   - Attach drawing to note
   - Display drawing in note
   - Delete drawing attachment

### Performance Tests
1. **Rendering Performance**
   - 1000+ strokes
   - Frame rate monitoring
   - Memory usage

2. **Storage Performance**
   - Save time
   - Load time
   - Thumbnail generation time

---

## Performance Considerations

### Rendering Optimization
1. **Canvas Caching**
   - Cache strokes as bitmap
   - Only repaint dirty regions
   - Use `RepaintBoundary`

2. **Stroke Simplification**
   - Douglas-Peucker algorithm
   - Reduce point count
   - Maintain visual quality

3. **Memory Management**
   - Limit undo stack
   - Clear old thumbnails
   - Compress stored data

### Storage Optimization
1. **Compression**
   - GZIP JSON data
   - PNG with compression level 6
   - Limit thumbnail size (200x200)

2. **Lazy Loading**
   - Load drawings on demand
   - Stream large drawings
   - Paginate stroke data

---

## Security Considerations

### Encryption
- ✅ All drawing data encrypted at rest
- ✅ Same encryption key as notes
- ✅ Secure thumbnail storage
- ✅ No plaintext metadata leakage

### Validation
- ✅ Maximum drawing size (10MB)
- ✅ Maximum stroke count (10,000)
- ✅ Input sanitization
- ✅ File type verification

### Privacy
- ✅ No telemetry on drawing content
- ✅ Local processing only
- ✅ User owns all data
- ✅ No cloud backup without consent

---

## Migration Strategy

### From Existing Sketches
If users have existing sketch data:

1. **Detection**
   - Scan notes for sketch metadata
   - Identify convertible sketches

2. **Conversion**
   - Convert to new format
   - Generate thumbnails
   - Create drawing entities

3. **Cleanup**
   - Remove old sketch data
   - Update note references
   - Verify integrity

---

## Success Criteria

### Phase 1 Complete When:
✅ User can draw basic strokes
✅ Canvas renders smoothly (>30 FPS)
✅ Touch input responsive (<16ms)
✅ Colors and widths adjustable

### Phase 2 Complete When:
✅ Pen, highlighter, eraser functional
✅ Tool switching seamless
✅ Visual feedback clear
✅ Tool behaviors correct

### Phase 3 Complete When:
✅ Undo/redo working (50 actions)
✅ Drawings persist correctly
✅ Thumbnails generated
✅ Encryption verified

### Phase 4 Complete When:
✅ Drawings embedded in notes
✅ Editor screen functional
✅ Save/load reliable
✅ UI polished

### Phase 5 Complete When:
✅ Stylus input working (iOS + Android)
✅ Pressure sensitivity mapped
✅ Palm rejection active
✅ Fallback to touch works

### Phase 6 Complete When:
✅ All tools implemented
✅ Export working (PNG, SVG, PDF)
✅ Performance optimized
✅ Bug-free experience

---

## Risk Assessment

### High Risk 🔴
1. **Performance on Low-End Devices**
   - **Mitigation**: Stroke simplification, caching, testing on low-end devices

2. **Platform-Specific Bugs**
   - **Mitigation**: Extensive platform testing, fallback implementations

### Medium Risk 🟡
1. **Memory Usage with Large Drawings**
   - **Mitigation**: Memory profiling, lazy loading, size limits

2. **Stylus API Inconsistencies**
   - **Mitigation**: Graceful degradation, touch fallback

### Low Risk 🟢
1. **Storage Encryption Overhead**
   - **Mitigation**: Benchmarking, optimization if needed

---

## Timeline & Milestones

| Week | Phase | Deliverable | Status |
|------|-------|-------------|--------|
| 1 | Core Canvas | Basic drawing canvas | 📋 Planned |
| 2 | Drawing Tools | Pen, highlighter, eraser | 📋 Planned |
| 3 | Undo/Redo | History system + persistence | 📋 Planned |
| 4 | Editor Integration | Inline widgets + editor screen | 📋 Planned |
| 5 | Stylus Integration | iOS + Android stylus support | 📋 Planned |
| 6 | Advanced Features | Export + polish | 📋 Planned |

---

## Next Steps

### Immediate (Week 1)
1. Set up drawing feature directory structure
2. Implement basic Custom Painter
3. Create DrawingController with Riverpod
4. Build basic toolbar UI
5. Implement pen tool
6. Write initial tests

### Week 2
1. Implement highlighter tool
2. Implement eraser tool
3. Add color picker
4. Add width controls
5. Enhance toolbar
6. Write tool tests

### Week 3
1. Implement undo/redo system
2. Create Drawing entity
3. Implement DrawingRepository
4. Add persistence layer
5. Generate thumbnails
6. Write persistence tests

---

## Related Documentation

- **Phase 2.2 Complete Guide**: Quick Capture implementation
- **Encryption Documentation**: Secure attachment storage
- **Test Fixes Summary**: Current test suite status
- **Master Implementation Plan**: Overall project roadmap

---

## Conclusion

Phase 2.3 brings powerful handwriting and drawing capabilities to Duru Notes. With a 6-week timeline and clear deliverables, this phase will transform Duru Notes into a comprehensive note-taking app supporting both text and visual content.

**Ready to Start**: ✅ All prerequisites met
**Estimated Effort**: 4-6 weeks (120-180 hours)
**Team Required**: 1-2 Flutter developers
**Complexity**: MEDIUM-HIGH

---

**Document Status**: ✅ Complete
**Plan Status**: 📋 Ready for Implementation
**Next Action**: Begin Phase 1 (Core Canvas)

---

**Date**: November 21, 2025
**Author**: Development Team
**Phase**: Track 2, Phase 2.3 (Handwriting & Drawing)
**Version**: 1.0

