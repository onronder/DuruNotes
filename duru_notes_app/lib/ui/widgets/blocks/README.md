# Block Editor Widgets

This directory contains the modular block editor components for the Duru Notes app. Each widget is specialized for a specific block type, following the Single Responsibility Principle.

## Architecture Overview

```
ModularBlockEditor (Orchestrator)
├── ParagraphBlockWidget (Text content)
├── HeadingBlockWidget (Headings H1-H3)
├── TodoBlockWidget (Checklists)
├── CodeBlockWidget (Code with syntax highlighting)
├── QuoteBlockWidget (Quoted text)
├── TableBlockWidget (Data tables)
└── AttachmentBlockWidget (File attachments)
```

## Core Concepts

### Block Structure

All blocks follow a consistent data structure:

```dart
class NoteBlock {
  final NoteBlockType type;
  final Object data;
  
  const NoteBlock({
    required this.type,
    required this.data,
  });
}
```

### Block Types

```dart
enum NoteBlockType {
  paragraph,    // Plain text
  heading1,     // H1 heading
  heading2,     // H2 heading  
  heading3,     // H3 heading
  quote,        // Quoted text
  code,         // Code block
  todo,         // Checkbox item
  table,        // Data table
  attachment,   // File attachment
}
```

## Widget Components

### 1. ParagraphBlockWidget

**File:** `paragraph_block_widget.dart`

**Purpose:** Handles plain text paragraphs and headings with customizable styling.

**Features:**
- Multiline text editing
- Custom font size and weight
- Responsive auto-growing height
- Customizable hint text

**Usage:**
```dart
ParagraphBlockWidget(
  block: block,
  controller: textController,
  onChanged: (updatedBlock) => handleBlockChange(updatedBlock),
  onDelete: () => deleteBlock(index),
  fontSize: 16.0,
  fontWeight: FontWeight.normal,
  hintText: 'Start typing...',
)
```

**Heading Variant:**
```dart
HeadingBlockWidget(
  block: block,
  controller: textController,
  onChanged: handleBlockChange,
  onDelete: deleteBlock,
  level: 1, // 1, 2, or 3
)
```

### 2. TodoBlockWidget

**File:** `todo_block_widget.dart`

**Purpose:** Interactive checklist items with completion tracking.

**Features:**
- Checkbox state management
- Strikethrough styling for completed items
- Todo summary widget for overview
- Visual feedback for completion status

**Data Structure:**
```dart
class TodoBlockData {
  final String text;
  final bool checked;
  
  const TodoBlockData({
    required this.text,
    required this.checked,
  });
}
```

**Usage:**
```dart
TodoBlockWidget(
  block: todoBlock,
  controller: textController,
  onChanged: (updatedBlock) {
    final todoData = updatedBlock.data as TodoBlockData;
    print('Todo "${todoData.text}" is ${todoData.checked ? "complete" : "pending"}');
  },
  onDelete: deleteTodo,
)
```

**Summary Widget:**
```dart
TodoSummaryWidget(
  todos: allTodoBlocks,
  showProgress: true, // Shows completion progress bar
)
```

### 3. CodeBlockWidget

**File:** `code_block_widget.dart`

**Purpose:** Code editing with syntax highlighting and language support.

**Features:**
- Language selection dropdown
- Monospace font styling
- Copy-to-clipboard functionality
- Code preview for read-only mode
- Syntax highlighting (basic)

**Data Structure:**
```dart
class CodeBlockData {
  final String code;
  final String? language;
  
  const CodeBlockData({
    required this.code,
    this.language,
  });
}
```

**Supported Languages:**
- Dart, JavaScript, TypeScript
- Python, Java, Kotlin, Swift
- Go, Rust, C++, C, C#
- PHP, Ruby, Shell, SQL
- HTML, CSS, JSON, XML, YAML, Markdown

**Usage:**
```dart
CodeBlockWidget(
  block: codeBlock,
  controller: codeController,
  onChanged: updateCodeBlock,
  onDelete: deleteCodeBlock,
  hintText: 'Enter your code here...',
)
```

### 4. QuoteBlockWidget

**File:** `quote_block_widget.dart`

**Purpose:** Styled quotations with distinctive visual formatting.

**Features:**
- Left border styling
- Italic typography
- Quote icon indicator
- Attribution support
- Background highlighting

**Usage:**
```dart
QuoteBlockWidget(
  block: quoteBlock,
  controller: quoteController,
  onChanged: updateQuote,
  onDelete: deleteQuote,
  hintText: 'Enter quote...',
)
```

**Preview Variants:**
```dart
// Basic quote preview
QuoteBlockPreview(
  text: 'The only way to do great work is to love what you do.',
  attribution: 'Steve Jobs',
)

// Inspirational quote card
InspirationalQuoteWidget(
  quote: 'Innovation distinguishes between a leader and a follower.',
  author: 'Steve Jobs',
  onTap: () => showQuoteDetails(),
)
```

### 5. TableBlockWidget

**File:** `table_block_widget.dart`

**Purpose:** Dynamic data tables with editing capabilities.

**Features:**
- Add/remove rows and columns
- Cell-by-cell editing
- Responsive horizontal scrolling
- Table size indicators
- Read-only preview mode

**Data Structure:**
```dart
class TableBlockData {
  final List<List<String>> rows;
  
  const TableBlockData({
    required this.rows,
  });
}
```

**Usage:**
```dart
TableBlockWidget(
  block: tableBlock,
  onChanged: updateTable,
  onDelete: deleteTable,
)
```

**Operations:**
- **Add Row:** Appends empty row with same column count
- **Add Column:** Adds empty cell to each existing row
- **Remove Row:** Removes last row (minimum 1 row)
- **Remove Column:** Removes last column (minimum 1 column)

### 6. AttachmentBlockWidget

**File:** `attachment_block_widget.dart`

**Purpose:** File attachments with preview and management capabilities.

**Features:**
- File type detection and icons
- Image preview with caching
- File metadata display
- Attachment replacement
- View/download functionality

**Data Structure:**
```dart
class AttachmentBlockData {
  final String filename;
  final String url;
  
  const AttachmentBlockData({
    required this.filename,
    required this.url,
  });
}
```

**Supported File Types:**
- **Images:** JPG, PNG, GIF, WebP, BMP, SVG
- **Documents:** PDF, DOC, DOCX, TXT, MD
- **Spreadsheets:** XLS, XLSX, CSV
- **Presentations:** PPT, PPTX
- **Media:** MP4, MOV, AVI, MP3, WAV, FLAC
- **Archives:** ZIP, RAR, 7Z

**Usage:**
```dart
AttachmentBlockWidget(
  block: attachmentBlock,
  onChanged: updateAttachment,
  onDelete: deleteAttachment,
)
```

## ModularBlockEditor

**File:** `modular_block_editor.dart`

**Purpose:** Orchestrates all block widgets and provides the main editor interface.

**Features:**
- Dynamic block creation and deletion
- Block type selection menu
- Read-only mode support
- Block limit enforcement
- Consistent theming across all blocks

**Usage:**
```dart
ModularBlockEditor(
  blocks: noteBlocks,
  onChanged: (updatedBlocks) => saveNote(updatedBlocks),
  readOnly: false,
  maxBlocks: 50, // Optional limit
)
```

**Block Creation:**
```dart
// Add block programmatically
editor.addBlock(NoteBlockType.paragraph);

// User-initiated through UI
PopupMenuButton<NoteBlockType>(
  onSelected: editor.addBlock,
  itemBuilder: (context) => [
    PopupMenuItem(value: NoteBlockType.paragraph, child: Text('Paragraph')),
    PopupMenuItem(value: NoteBlockType.heading1, child: Text('Heading 1')),
    // ... other block types
  ],
)
```

## Theming and Styling

All widgets respect the app's theme and provide consistent styling:

### Color Scheme
```dart
// Primary actions and highlights
Theme.of(context).colorScheme.primary

// Surface backgrounds
Theme.of(context).colorScheme.surfaceContainerHighest

// Text colors with opacity
Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
```

### Typography
```dart
// Heading styles
Theme.of(context).textTheme.headlineMedium  // H1
Theme.of(context).textTheme.headlineSmall  // H2
Theme.of(context).textTheme.titleLarge     // H3

// Body text
Theme.of(context).textTheme.bodyLarge      // Paragraphs
Theme.of(context).textTheme.bodyMedium     // Secondary text
```

## State Management

### Controller Management
Each text-based widget manages its own `TextEditingController`:

```dart
// Automatic controller creation
TextEditingController? _createControllerForBlock(NoteBlock block) {
  switch (block.type) {
    case NoteBlockType.paragraph:
      return TextEditingController(text: block.data as String);
    case NoteBlockType.table:
      return null; // Table manages its own controllers
    // ...
  }
}

// Proper disposal
@override
void dispose() {
  for (final controller in _controllers) {
    controller?.dispose();
  }
  super.dispose();
}
```

### Change Propagation
```dart
void _updateBlock(int index, NoteBlock updatedBlock) {
  setState(() {
    _blocks[index] = updatedBlock;
  });
  widget.onChanged(List.from(_blocks)); // Immutable copy
}
```

## Performance Optimizations

### Focused Re-renders
- Only affected block widgets rebuild on changes
- Text controllers prevent unnecessary widget rebuilds
- List separation minimizes rendering scope

### Memory Management
- Automatic controller disposal
- Image caching for attachments
- Lazy loading of block widgets

### Input Optimization
```dart
// Debounced text input (implemented in individual widgets)
Timer? _debounceTimer;

void _onTextChanged(String text) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 300), () {
    widget.onChanged(updatedBlock);
  });
}
```

## Testing Strategy

Each widget has comprehensive unit tests covering:

### Widget Tests
```dart
testWidgets('should display block content correctly', (tester) async {
  await tester.pumpWidget(createTestWidget());
  expect(find.text('Expected content'), findsOneWidget);
});

testWidgets('should handle user interactions', (tester) async {
  await tester.tap(find.byIcon(Icons.delete_outline));
  expect(onDeleteCalled, isTrue);
});
```

### Integration Tests
```dart
testWidgets('should update block data on text change', (tester) async {
  await tester.enterText(find.byType(TextField), 'New content');
  expect(capturedBlock.data, equals('New content'));
});
```

## Accessibility

All widgets implement proper accessibility features:

### Semantic Labels
```dart
IconButton(
  icon: Icon(Icons.delete_outline),
  onPressed: onDelete,
  tooltip: 'Delete paragraph', // Screen reader support
)
```

### Focus Management
```dart
TextField(
  autofocus: isNewBlock,
  focusNode: blockFocusNode,
  // ...
)
```

### Contrast and Sizing
- Sufficient color contrast for all text
- Touch targets meet minimum size requirements
- Scalable text respects system font size settings

## Migration Guide

### From BlockEditor

```dart
// Old way
BlockEditor(
  blocks: blocks,
  onChanged: onChanged,
)

// New way
ModularBlockEditor(
  blocks: blocks,
  onChanged: onChanged,
  readOnly: false, // New parameter
  maxBlocks: null, // New parameter
)
```

### Custom Block Types

To add a new block type:

1. **Define the block type:**
```dart
enum NoteBlockType {
  // existing types...
  customBlock,
}
```

2. **Create the data class:**
```dart
class CustomBlockData {
  final String customProperty;
  const CustomBlockData({required this.customProperty});
}
```

3. **Implement the widget:**
```dart
class CustomBlockWidget extends StatelessWidget {
  // Implementation following the same pattern
}
```

4. **Add to ModularBlockEditor:**
```dart
case NoteBlockType.customBlock:
  return CustomBlockWidget(/* ... */);
```

## Best Practices

### Widget Design
- Keep widgets focused on single responsibility
- Provide clear public APIs
- Handle edge cases gracefully
- Include proper error boundaries

### Performance
- Dispose resources properly
- Use const constructors where possible
- Implement efficient change detection
- Minimize widget rebuilds

### User Experience
- Provide immediate visual feedback
- Include helpful tooltips and hints
- Handle loading states gracefully
- Support keyboard navigation

## Future Enhancements

### Planned Features
1. **Drag-and-drop reordering**
2. **Block templates and snippets**
3. **Advanced markdown support**
4. **Real-time collaboration**
5. **Plugin architecture for custom blocks**

### Extension Points
```dart
abstract class BlockPlugin {
  NoteBlockType get type;
  Widget buildEditor(NoteBlock block);
  Widget buildPreview(NoteBlock block);
  bool canHandle(NoteBlock block);
}
```

## Support

For questions about the block editor widgets:

1. Review the unit tests for usage examples
2. Check the `REFACTORING_GUIDE.md` for architecture decisions
3. Examine individual widget implementations
4. Use the ModularBlockEditor as the primary entry point
