# Task Widget Migration TODO Tracker

## Overview
This document tracks the migration of task widgets from the deprecated `UiNoteTask` model to the production `NoteTask` database model.

## Current Status
✅ **Migration Infrastructure Ready**
- `TaskModelConverter` - Provides bidirectional conversion between models
- `TaskWidgetAdapter` - Adapter widget for gradual migration
- `UnifiedTaskCallbacks` - Callback interface for both models
- `MIGRATION_GUIDE.md` - Step-by-step migration instructions

⚠️ **Widgets Still Using Deprecated Model**
The following widgets need migration to use the adapter pattern:

## Migration TODO List

### Phase 1: Apply Adapter Pattern (In Progress)
- [x] `lib/ui/widgets/tasks/task_card.dart`
  - Status: ✅ PARTIALLY MIGRATED - Supports both models via adapter
  - Issues Fixed: onEdit callback, popup menu breaks
  - Remaining: Still uses UiTaskStatus/UiTaskPriority internally
  - Priority: HIGH
  
- [x] `lib/ui/widgets/tasks/task_list_item_migrated.dart`
  - Status: ✅ FULLY MIGRATED - New implementation with UnifiedTaskCallbacks
  - Action: Replace old task_list_item.dart with this version
  - Priority: HIGH
  
- [ ] `lib/ui/widgets/tasks/task_list_item.dart`
  - Status: ❌ STILL USING LEGACY - Extends BaseTaskWidget, uses old TaskCallbacks
  - Issues: Missing task ID in callbacks, switch statements fixed but not migrated
  - Priority: HIGH
  
- [ ] `lib/ui/widgets/tasks/base_task_widget.dart`
  - Status: ❌ STILL LEGACY - Uses UiNoteTask and old TaskCallbacks
  - Action: Needs complete rewrite or deprecation
  - Priority: HIGH
  
- [ ] `lib/ui/widgets/tasks/task_tree_node.dart`
  - Status: ❌ STILL LEGACY - Extends BaseTaskWidget, uses old callbacks
  - Issues: Switch statements fixed but not migrated to UnifiedTaskCallbacks
  - Priority: MEDIUM
  
- [ ] `lib/ui/widgets/tasks/task_widget_factory.dart`
  - Status: ❌ NOT MIGRATED - Still creates legacy widgets
  - Action: Update factory to use new migrated widgets
  - Priority: MEDIUM

### Phase 2: Update Screen Integration (Next Sprint)
- [ ] Find all screens using task widgets
- [ ] Update screens to pass database NoteTask instead of UiNoteTask
- [ ] Update callbacks to use UnifiedTaskCallbacks interface
- [ ] Test task CRUD operations with new model

### Phase 3: Remove Deprecated Code (Future)
- [ ] Remove UiNoteTask, UiTaskStatus, UiTaskPriority from `lib/models/note_task.dart`
- [ ] Remove TaskModelConverter (no longer needed)
- [ ] Remove TaskWidgetAdapter (widgets use NoteTask directly)
- [ ] Update all imports to use only `app_db.dart`

## Migration Pattern

### Before (Current)
```dart
class TaskCard extends StatelessWidget {
  final UiNoteTask task;
  
  TaskCard({required this.task});
  // ...
}
```

### After Phase 1 (With Adapter)
```dart
class TaskCard extends StatelessWidget {
  final NoteTask task; // Accept database model
  
  TaskCard({required this.task});
  
  @override
  Widget build(BuildContext context) {
    return TaskWidgetAdapter(
      dbTask: task,
      builder: (uiTask) => _buildCard(uiTask),
    );
  }
  
  Widget _buildCard(UiNoteTask task) {
    // Existing implementation unchanged
  }
}
```

### After Phase 3 (Final)
```dart
class TaskCard extends StatelessWidget {
  final NoteTask task; // Direct database model
  
  TaskCard({required this.task});
  // Implementation using NoteTask directly
}
```

## Testing Checklist
- [ ] Task creation with new model
- [ ] Task status updates
- [ ] Task priority changes
- [ ] Task deletion
- [ ] Subtask relationships
- [ ] Task-note associations
- [ ] Due date handling
- [ ] Label/tag management

## Risk Mitigation
1. **Gradual Migration**: Use adapter pattern to avoid breaking changes
2. **Feature Flag**: Consider feature flag for rollback capability
3. **Testing**: Comprehensive test coverage before removing deprecated code
4. **Documentation**: Keep MIGRATION_GUIDE.md updated

## Success Criteria
- ✅ All task widgets work with database NoteTask model
- ✅ No references to UiNoteTask in production code
- ✅ All task CRUD operations functional
- ✅ No regression in task functionality
- ✅ Improved type safety and consistency

## Timeline
- **Week 1**: Apply adapter pattern to all widgets
- **Week 2**: Update screen integration
- **Week 3**: Testing and bug fixes
- **Week 4**: Remove deprecated code (if stable)

## Notes
- The adapter pattern allows production screens to start using database models immediately
- Existing screens using UiNoteTask will continue to work during migration
- Priority should be given to high-traffic widgets (TaskCard, TaskListItem)
- Consider creating automated migration script for large codebases

## Contact
For questions about the migration:
- Review `lib/ui/widgets/tasks/MIGRATION_GUIDE.md`
- Check `TaskModelConverter` for conversion logic
- See `TaskWidgetAdapter` for usage examples
