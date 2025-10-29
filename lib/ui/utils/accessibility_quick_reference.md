# Accessibility Quick Reference Card

## Import
```dart
import 'package:duru_notes/ui/utils/accessibility_helper.dart';
```

## Common Patterns

### Buttons & Icon Buttons
```dart
A11yHelper.iconButton(
  label: 'Delete note',
  hint: 'Permanently removes this note',
  onPressed: onDelete,
  child: IconButton(...),
)
```

### Cards (Notes/Tasks)
```dart
// Note Card
A11yHelper.noteCard(
  title: noteTitle,
  content: preview,
  date: 'Updated today',
  isPinned: true,
  hasAttachments: false,
  onTap: onTap,
  child: widget,
)

// Task Card
A11yHelper.taskCard(
  title: taskTitle,
  isCompleted: false,
  dueDate: 'Due tomorrow',
  priority: 'High',
  onTap: onTap,
  onToggle: onToggle,
  child: widget,
)
```

### Checkboxes
```dart
A11yHelper.checkbox(
  label: 'Task title',
  value: isChecked,
  hint: isChecked ? 'Mark incomplete' : 'Mark complete',
  onTap: () => toggle(),
  child: Checkbox(...),
)
```

### List Items
```dart
A11yHelper.listItem(
  label: itemTitle,
  index: index,
  totalCount: total,
  hint: 'Double tap to open',
  onTap: onTap,
  child: ListTile(...),
)
```

### Text Fields
```dart
A11yHelper.textField(
  label: 'Note title',
  hint: 'Enter a title',
  enabled: true,
  child: TextField(...),
)
```

### Form Fields with Validation
```dart
A11yHelper.formField(
  label: 'Email',
  hint: 'Your email address',
  errorText: validator(value),
  required: true,
  child: TextFormField(...),
)
```

### Empty States
```dart
A11yHelper.emptyState(
  label: 'No notes found',
  hint: 'Tap the add button to create your first note',
  child: EmptyWidget(...),
)
```

### Dialogs
```dart
A11yHelper.dialog(
  title: 'Delete Note',
  description: 'This cannot be undone',
  child: AlertDialog(...),
)
```

### Menu Items
```dart
A11yHelper.menuItem(
  label: 'Edit',
  hint: 'Edit this note',
  icon: Icons.edit,
  onTap: onEdit,
  child: ListTile(...),
)
```

### Focus Indicators
```dart
A11yHelper.focusable(
  focusNode: myNode,
  focusColor: Colors.blue,
  child: widget,
)
```

### Decorative Elements (Exclude)
```dart
// Icons that are just visual (parent has semantic label)
A11yHelper.decorative(
  Icon(Icons.pin_fill),
)

// Text already in parent semantic label
ExcludeSemantics(
  child: Text(title),
)
```

### Live Announcements
```dart
// Normal announcement
A11yHelper.announce(context, 'Task completed');

// Polite (doesn't interrupt)
A11yHelper.announcePolite(context, 'Changes saved');

// Assertive (interrupts)
A11yHelper.announceAssertive(context, 'Error occurred');
```

### Headers
```dart
A11yHelper.header(
  label: 'Recent Notes',
  child: Text('Recent Notes', style: heading),
)
```

### Images
```dart
A11yHelper.image(
  label: 'Profile picture of John Doe',
  hint: 'Tap to change',
  child: Image.network(url),
)
```

### Links
```dart
A11yHelper.link(
  label: 'Learn more',
  hint: 'Opens in browser',
  onTap: launchUrl,
  child: Text('Learn more'),
)
```

## Decision Tree

```
Is this widget interactive?
├─ YES → Does it trigger an action?
│  ├─ Button/IconButton → Use A11yHelper.button() or iconButton()
│  ├─ Card/List item → Use A11yHelper.card(), noteCard(), or taskCard()
│  ├─ Checkbox → Use A11yHelper.checkbox()
│  ├─ Toggle/Switch → Use A11yHelper.toggle()
│  └─ Custom gesture → Use A11yHelper.tappable()
│
└─ NO → Is it informative?
   ├─ YES → Does it convey important info?
   │  ├─ Header/Title → Use A11yHelper.header()
   │  ├─ Image → Use A11yHelper.image()
   │  ├─ Error/Success → Use A11yHelper.errorMessage() / successMessage()
   │  └─ Status → Use A11yHelper.liveRegion()
   │
   └─ NO (Decorative) → Use A11yHelper.decorative() or ExcludeSemantics
```

## Checklist for Each Widget

- [ ] Interactive elements have semantic labels
- [ ] Labels are descriptive (not just "Button" or "Item")
- [ ] Hints explain what will happen
- [ ] Decorative elements excluded from semantics
- [ ] Parent semantic label doesn't duplicate child content
- [ ] Focus indicators visible when focused
- [ ] State changes announced to screen reader
- [ ] Tested with VoiceOver/TalkBack

## Common Mistakes

### ❌ Don't Do This
```dart
// Vague label
A11yHelper.button(label: 'More', child: ...)

// Duplicate semantics
Semantics(
  label: 'Delete',
  child: IconButton(tooltip: 'Delete', ...) // Already has semantics
)

// Missing semantics on custom gesture
GestureDetector(onTap: onTap, child: Container(...))
```

### ✅ Do This
```dart
// Descriptive label
A11yHelper.button(
  label: 'More options for ${noteTitle}',
  hint: 'Opens menu with edit, share, and delete',
  child: ...
)

// Exclude child semantics
A11yHelper.iconButton(
  label: 'Delete note',
  child: IconButton(...) // Semantics excluded by helper
)

// Add semantics to custom gestures
A11yHelper.button(
  label: 'Open note',
  onTap: onTap,
  child: GestureDetector(onTap: onTap, child: Container(...))
)
```

## Testing Commands

```bash
# Analyze accessibility files
flutter analyze lib/ui/utils/accessibility_helper.dart

# Run all tests
flutter test

# Run with screen reader
# iOS: Settings > Accessibility > VoiceOver
# Android: Settings > Accessibility > TalkBack
```

## Widget Test Example

```dart
testWidgets('Note card has proper semantics', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DuruNoteCard(
          note: testNote,
          onTap: () {},
        ),
      ),
    ),
  );

  // Verify semantic label exists
  expect(
    find.bySemanticsLabel(RegExp('.*${testNote.title}.*')),
    findsOneWidget,
  );

  // Verify button semantics
  expect(
    find.bySemanticsLabel(RegExp('More options.*')),
    findsOneWidget,
  );
});
```

## Quick Wins

1. **All IconButtons**: Wrap with `A11yHelper.iconButton()`
2. **All Cards**: Use `A11yHelper.noteCard()` or `taskCard()`
3. **All GestureDetectors**: Wrap with appropriate semantic helper
4. **All Decorative Icons**: Wrap with `A11yHelper.decorative()`
5. **All State Changes**: Call `A11yHelper.announce()`

## Priority Order

1. **Buttons** (highest impact, easiest to fix)
2. **Cards/List Items** (core user interaction)
3. **Form Fields** (accessibility requirement)
4. **Empty States** (helps users understand state)
5. **Decorative Elements** (clean up duplicate announcements)

## Resources

- Full API: `/lib/ui/utils/accessibility_helper.dart`
- Implementation Guide: `/lib/ui/utils/accessibility_implementation_guide.md`
- Examples: See updated files in `/lib/ui/components/` and `/lib/ui/widgets/`
