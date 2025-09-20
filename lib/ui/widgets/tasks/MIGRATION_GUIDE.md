# Task Model Migration Guide

## Overview
The codebase currently has two task models:
1. **UiNoteTask** (deprecated) - A temporary UI model in `lib/models/note_task.dart`
2. **NoteTask** (recommended) - The actual Drift-generated database model in `lib/data/local/app_db.dart`

## Key Differences

### Status Enums
- **UiTaskStatus**: `pending`, `inProgress`, `completed`, `cancelled`
- **TaskStatus**: `open`, `completed`, `cancelled`

### Priority Enums
- **UiTaskPriority**: `none`, `low`, `medium`, `high`, `urgent`
- **TaskPriority**: `low`, `medium`, `high`, `urgent`

## Migration Steps

### 1. Update Imports
Replace:
```dart
import 'package:duru_notes/models/note_task.dart';
```

With:
```dart
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/widgets/tasks/task_model_converter.dart';
```

### 2. Convert Task Models
Use the `TaskModelConverter` class to convert between models:

```dart
// Convert database task to UI task (temporary)
UiNoteTask uiTask = TaskModelConverter.dbTaskToUiTask(dbTask);

// Convert UI task to database companion for saving
NoteTasksCompanion companion = TaskModelConverter.uiTaskToDbCompanion(uiTask);
```

### 3. Update Widget Code
Replace references to:
- `TaskStatus` → `UiTaskStatus` (temporarily, then migrate to database `TaskStatus`)
- `TaskPriority` → `UiTaskPriority` (temporarily, then migrate to database `TaskPriority`)
- `NoteTask` → `UiNoteTask` (temporarily, then migrate to database `NoteTask`)

### 4. Use the Adapter Widget
For gradual migration, use `TaskWidgetAdapter`:

```dart
TaskWidgetAdapter(
  dbTask: myDatabaseTask, // Or uiTask: myUiTask
  builder: (task) => MyTaskWidget(task: task),
)
```

## Temporary Compatibility
All five task widget files have been marked with:
- `// ignore_for_file: deprecated_member_use` to suppress warnings
- `// TODO: Migrate to use NoteTask from app_db.dart` as reminders

## Files Affected
1. `lib/ui/widgets/tasks/task_card.dart`
2. `lib/ui/widgets/tasks/task_tree_node.dart`
3. `lib/ui/widgets/tasks/task_widget_factory.dart`
4. `lib/ui/widgets/tasks/base_task_widget.dart`
5. `lib/ui/widgets/tasks/task_list_item.dart`

## Benefits of Migration
- Single source of truth for task data
- Eliminates duplicate model maintenance
- Ensures consistency with database schema
- Reduces risk of data inconsistency
- Simplifies testing and maintenance
