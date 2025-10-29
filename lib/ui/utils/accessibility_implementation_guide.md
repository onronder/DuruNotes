# Accessibility Implementation Guide

## Overview
This guide provides comprehensive instructions for implementing WCAG 2.1 AA accessibility compliance across the Duru Notes Flutter application using the A11yHelper utility class.

## Current Status
- **Utility Created**: `/lib/ui/utils/accessibility_helper.dart`
- **Files Updated**: 3/93 (3.2%)
  - ✅ `/lib/ui/components/duru_note_card.dart`
  - ✅ `/lib/ui/components/duru_task_card.dart`
  - ✅ `/lib/ui/widgets/task_item_widget.dart`

## Accessibility Helper Usage

### 1. Basic Button Semantics

```dart
// BEFORE
IconButton(
  icon: Icon(Icons.delete),
  onPressed: onDelete,
)

// AFTER
A11yHelper.iconButton(
  label: 'Delete note',
  hint: 'Permanently removes this note',
  onPressed: onDelete,
  child: IconButton(
    icon: Icon(Icons.delete),
    onPressed: onDelete,
  ),
)
```

### 2. Card/List Item Semantics

```dart
// BEFORE
InkWell(
  onTap: onTap,
  child: Container(...),
)

// AFTER
A11yHelper.noteCard(
  title: noteTitle,
  content: noteContent,
  date: formattedDate,
  isPinned: isPinned,
  hasAttachments: hasAttachments,
  hasTasks: hasTasks,
  isSelected: isSelected,
  onTap: onTap,
  onLongPress: onLongPress,
  child: InkWell(
    onTap: onTap,
    child: Container(...),
  ),
)
```

### 3. Checkbox Semantics

```dart
// BEFORE
Checkbox(
  value: isCompleted,
  onChanged: onChanged,
)

// AFTER
A11yHelper.checkbox(
  label: taskTitle,
  value: isCompleted,
  hint: isCompleted ? 'Mark as incomplete' : 'Mark as complete',
  onTap: () => onChanged?.call(!isCompleted),
  child: Checkbox(
    value: isCompleted,
    onChanged: onChanged,
  ),
)
```

### 4. Excluding Decorative Elements

When the parent has semantics, exclude child visual elements:

```dart
// Decorative icons (parent has semantic label)
A11yHelper.decorative(
  Icon(Icons.pin_fill, size: 14, color: accentColor),
)

// Text already described in parent semantic label
ExcludeSemantics(
  child: Text(title),
)
```

### 5. Menu Items

```dart
A11yHelper.menuItem(
  label: 'Edit',
  hint: 'Edit this note',
  icon: Icons.edit,
  onTap: onEdit,
  child: ListTile(
    leading: Icon(Icons.edit),
    title: Text('Edit'),
    onTap: onEdit,
  ),
)
```

### 6. Focus Indicators

```dart
A11yHelper.focusable(
  focusNode: myFocusNode,
  autofocus: false,
  focusColor: Colors.blue,
  borderRadius: BorderRadius.circular(8),
  child: myWidget,
)
```

### 7. Live Announcements

```dart
// Announce state changes to screen readers
A11yHelper.announce(context, 'Task completed');

// Polite (doesn't interrupt)
A11yHelper.announcePolite(context, 'Changes saved');

// Assertive (interrupts current announcement)
A11yHelper.announceAssertive(context, 'Error occurred');
```

## Priority File List

### Priority 1 - Core Interactions (20 files)
✅ Completed:
1. `/lib/ui/components/duru_note_card.dart`
2. `/lib/ui/components/duru_task_card.dart`
3. `/lib/ui/widgets/task_item_widget.dart`

🔲 Remaining:
4. `/lib/ui/components/duru_button.dart` (if exists)
5. `/lib/ui/widgets/note_item_widget.dart` (if exists)
6. `/lib/ui/dialogs/goals_dialog.dart`
7. `/lib/ui/dialogs/data_migration_dialog.dart`
8. `/lib/ui/dialogs/task_metadata_dialog.dart`
9. `/lib/ui/modern_edit_note_screen.dart`
10. `/lib/ui/notes_list_screen.dart`
11. `/lib/ui/task_list_screen.dart`
12. `/lib/ui/enhanced_task_list_screen.dart`
13. `/lib/ui/home_screen.dart`
14. `/lib/ui/screens/modern_home_screen.dart`
15. `/lib/ui/screens/task_management_screen.dart`

### Priority 2 - Forms and Inputs (15 files)
16. `/lib/ui/auth_screen.dart`
17. `/lib/ui/change_password_screen.dart`
18. `/lib/ui/widgets/template_picker_sheet.dart`
19. `/lib/ui/widgets/calendar_task_sheet.dart`
20. `/lib/features/templates/create_template_dialog.dart` (if exists)

### Priority 3 - Navigation and Lists (25 files)
21. `/lib/ui/note_search_delegate.dart`
22. `/lib/ui/modern_search_screen.dart`
23. `/lib/ui/saved_search_management_screen.dart`
24. `/lib/ui/tags_screen.dart`
25. `/lib/ui/tag_notes_screen.dart`
26. `/lib/ui/settings_screen.dart`
27. `/lib/ui/help_screen.dart`
28. `/lib/ui/reminders_screen.dart`
29. `/lib/ui/productivity_analytics_screen.dart`

### Priority 4 - Remaining Components (33 files)
30. All block widgets (`/lib/ui/widgets/blocks/*`)
31. All analytics widgets (`/lib/ui/widgets/analytics/*`)
32. All shared widgets (`/lib/ui/widgets/shared/*`)
33. Settings components
34. Animation components

## Implementation Patterns by Widget Type

### List/Grid Items

```dart
Widget buildListItem(BuildContext context, int index, int total) {
  return A11yHelper.listItem(
    label: itemTitle,
    index: index,
    totalCount: total,
    hint: 'Double tap to open',
    value: itemSubtitle,
    onTap: onTap,
    child: ListTile(...),
  );
}
```

### Text Fields

```dart
A11yHelper.textField(
  label: 'Note title',
  hint: 'Enter a title for your note',
  value: currentValue,
  enabled: !isReadOnly,
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
  child: TextFormField(
    validator: (value) {
      if (value?.isEmpty ?? true) {
        return 'Email is required'; // Announced to screen reader
      }
      return null;
    },
  ),
)
```

### Empty States

```dart
if (items.isEmpty) {
  return A11yHelper.emptyState(
    label: 'No notes found',
    hint: 'Tap the add button to create your first note',
    child: EmptyStateWidget(...),
  );
}
```

### Dialogs

```dart
A11yHelper.dialog(
  title: 'Delete Note',
  description: 'This action cannot be undone',
  child: AlertDialog(...),
)
```

### Bottom Sheets

```dart
A11yHelper.bottomSheet(
  title: 'Note options',
  child: Container(...),
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
  label: 'Learn more about accessibility',
  hint: 'Opens in browser',
  onTap: onTap,
  child: Text('Learn more'),
)
```

## Testing Accessibility

### Manual Testing with Screen Reader

#### iOS (VoiceOver)
1. Settings > Accessibility > VoiceOver > Enable
2. Navigate through app using swipe gestures
3. Verify all interactive elements are announced
4. Verify semantic labels are descriptive
5. Test focus order is logical

#### Android (TalkBack)
1. Settings > Accessibility > TalkBack > Enable
2. Navigate through app using swipe gestures
3. Verify all interactive elements are announced
4. Verify semantic labels are descriptive
5. Test focus order is logical

### Keyboard Navigation Testing
1. Connect keyboard to device
2. Use Tab key to navigate
3. Verify focus indicators appear
4. Verify focus order is logical
5. Test Enter/Space for activation

### Automated Testing

Add to your widget tests:

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

  // Find semantic widgets
  expect(
    find.bySemanticsLabel('Test Note. Updated today'),
    findsOneWidget,
  );

  // Verify button semantics
  expect(
    find.bySemanticsLabel('More options for Test Note'),
    findsOneWidget,
  );
});
```

## Common Mistakes to Avoid

### 1. Duplicate Semantics
❌ **Wrong**: Adding semantics when child already has them
```dart
Semantics(
  label: 'Delete',
  child: IconButton(
    icon: Icon(Icons.delete),
    tooltip: 'Delete', // Already has semantics
  ),
)
```

✅ **Correct**: Use excludeSemantics on child
```dart
A11yHelper.iconButton(
  label: 'Delete note',
  hint: 'Permanently removes this note',
  child: IconButton(
    icon: Icon(Icons.delete),
    // Tooltip is excluded by A11yHelper
  ),
)
```

### 2. Missing Semantics on Custom Gestures
❌ **Wrong**: GestureDetector without semantics
```dart
GestureDetector(
  onTap: onTap,
  child: Container(...),
)
```

✅ **Correct**: Add button semantics
```dart
A11yHelper.button(
  label: 'Open note',
  onTap: onTap,
  child: GestureDetector(
    onTap: onTap,
    child: Container(...),
  ),
)
```

### 3. Not Excluding Decorative Elements
❌ **Wrong**: Icons in cards when card has semantic label
```dart
A11yHelper.noteCard(
  title: 'My Note',
  isPinned: true,
  child: Row(
    children: [
      Icon(Icons.pin), // Will be announced separately
      Text('My Note'),
    ],
  ),
)
```

✅ **Correct**: Exclude decorative icons
```dart
A11yHelper.noteCard(
  title: 'My Note',
  isPinned: true, // Already in semantic label
  child: Row(
    children: [
      A11yHelper.decorative(Icon(Icons.pin)),
      ExcludeSemantics(child: Text('My Note')),
    ],
  ),
)
```

### 4. Vague Labels
❌ **Wrong**: Generic labels
```dart
A11yHelper.button(
  label: 'More', // Not descriptive
  child: IconButton(...),
)
```

✅ **Correct**: Descriptive labels
```dart
A11yHelper.button(
  label: 'More options for ${noteTitle}',
  hint: 'Open menu with edit, share, and delete actions',
  child: IconButton(...),
)
```

## Success Criteria

### WCAG 2.1 AA Compliance Checklist

- [ ] **1.1.1 Non-text Content**: All images, icons, and decorative elements have appropriate alt text or are marked as decorative
- [ ] **1.3.1 Info and Relationships**: Semantic markup used for all interactive elements
- [ ] **2.1.1 Keyboard**: All functionality available via keyboard
- [ ] **2.4.3 Focus Order**: Focus order is logical and meaningful
- [ ] **2.4.7 Focus Visible**: Focus indicators visible on all focusable elements
- [ ] **3.2.4 Consistent Identification**: Components with same functionality have consistent labels
- [ ] **4.1.2 Name, Role, Value**: All UI components have accessible name and role
- [ ] **4.1.3 Status Messages**: State changes announced via live regions

### Automated Test Coverage

- [ ] All interactive widgets have semantic tests
- [ ] Focus navigation tests pass
- [ ] Screen reader announcement tests pass
- [ ] Keyboard navigation tests pass

### Manual Test Results

- [ ] VoiceOver (iOS) navigation successful
- [ ] TalkBack (Android) navigation successful
- [ ] Keyboard navigation successful
- [ ] Focus indicators visible and clear
- [ ] All labels descriptive and helpful

## Next Steps

1. **Complete Priority 1 files** (17 remaining)
   - Focus on core user interactions
   - Test thoroughly with screen readers

2. **Complete Priority 2 files** (15 files)
   - Forms and input validation
   - Ensure error messages are accessible

3. **Complete Priority 3 files** (25 files)
   - Navigation components
   - List views with proper indexing

4. **Complete Priority 4 files** (33 files)
   - Remaining components
   - Analytics and charts with data tables for screen readers

5. **Comprehensive Testing**
   - Run automated tests
   - Manual screen reader testing
   - Keyboard navigation testing
   - User testing with accessibility needs

## Resources

- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [iOS Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Android Accessibility Guide](https://developer.android.com/guide/topics/ui/accessibility)

## Contact

For questions or issues with accessibility implementation, refer to:
- Flutter Accessibility Documentation
- WCAG 2.1 AA Guidelines
- A11yHelper source code at `/lib/ui/utils/accessibility_helper.dart`
