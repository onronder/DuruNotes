# Task Management System Documentation

## Overview

The task management system in Duru Notes provides a comprehensive solution for tracking actionable items within notes. It seamlessly integrates with the existing note-taking functionality while providing dedicated task views, calendar integration, and synchronization capabilities.

## Architecture

### Database Layer

#### Task Model (`NoteTask`)
The task system uses a dedicated `note_tasks` table with the following key fields:

```sql
- id: Unique task identifier
- noteId: Reference to parent note
- content: Task description
- status: TaskStatus enum (open/completed/cancelled)
- priority: TaskPriority enum (low/medium/high/urgent)
- dueDate: Optional due date
- completedAt: Completion timestamp
- position: Position within note
- reminderId: Optional reminder reference
- parentTaskId: For subtask hierarchy
```

#### Indexes
Optimized indexes for common queries:
- `idx_note_tasks_note_id`: Tasks by note
- `idx_note_tasks_due_date`: Open tasks by due date
- `idx_note_tasks_status`: Tasks by status
- `idx_note_tasks_reminder_id`: Tasks with reminders
- `idx_note_tasks_parent`: Subtasks

### Service Layer

#### TaskService
Core service for task operations:
- Create, update, delete tasks
- Toggle completion status
- Query tasks by various criteria
- Get task statistics
- Manage subtasks

#### NoteTaskSyncService
Synchronizes tasks between note content and database:
- Parses markdown checkboxes (`- [ ]` and `- [x]`)
- Maintains bidirectional sync
- Handles task reordering
- Supports metadata extraction (due dates, priorities)

#### TaskRepository
Handles backend synchronization:
- Syncs tasks with Supabase
- Manages pending operations for offline support
- Provides realtime updates
- Ensures data consistency

## UI Components

### Task List Screen
Main task management interface with three views:

1. **All Tasks View**
   - List of all tasks
   - Filtering options (today, week, overdue, priority)
   - Sorting capabilities (due date, priority, alphabetical)
   - Toggle completed tasks visibility

2. **Tasks by Date View**
   - Groups tasks by date categories
   - Shows overdue, today, tomorrow, week sections
   - Visual priority indicators

3. **Calendar View**
   - Monthly calendar grid
   - Visual task indicators on dates
   - Task count badges
   - Bottom sheet for daily task details

### Task Features

#### Priority Levels
- **Low**: Gray indicator
- **Medium**: Blue indicator (default)
- **High**: Orange indicator
- **Urgent**: Red indicator

#### Task Metadata in Notes
Tasks can include metadata using special syntax:
- Due date: `@due(2024-12-25)`
- Priority: `!high`, `!urgent`, `!low`
- Example: `- [ ] Complete report @due(2024-12-25) !high`

## Integration with Notes

### Checkbox Synchronization
The system automatically:
1. Extracts tasks from note checkboxes
2. Creates database entries for tracking
3. Syncs completion status bidirectionally
4. Preserves task position and context

### Note Editor Integration
When editing notes:
- Checkbox toggles update task status
- New checkboxes create tasks automatically
- Deleted checkboxes mark tasks as deleted
- Task reordering is preserved

## Backend Integration

### Supabase Migration
The system includes a complete SQL migration (`20250114_note_tasks.sql`) that:
- Creates the `note_tasks` table
- Sets up Row Level Security (RLS)
- Provides utility functions for statistics
- Implements auto-complete for subtasks

### Key Backend Features
- User-scoped data with RLS
- Automatic timestamp updates
- Task statistics function
- Calendar data aggregation
- Subtask cascading completion

## Best Practices

### Performance
- Uses indexed queries for fast lookups
- Implements stream-based updates for real-time UI
- Batches position updates for reordering
- Lazy-loads task data as needed

### Data Integrity
- Maintains content hash for deduplication
- Soft deletes for recovery
- Position tracking for accurate sync
- Parent-child relationships for subtasks

### User Experience
- Instant visual feedback on actions
- Offline-first with background sync
- Contextual task creation from notes
- Smart date grouping and sorting

## Usage Examples

### Creating a Task in a Note
```markdown
## Project Tasks
- [ ] Design database schema @due(2024-12-20) !high
- [ ] Implement API endpoints
- [x] Write documentation !urgent
```

### Programmatic Task Creation
```dart
final taskService = ref.read(taskServiceProvider);
await taskService.createTask(
  noteId: 'note123',
  content: 'Review pull request',
  priority: TaskPriority.high,
  dueDate: DateTime.now().add(Duration(days: 2)),
);
```

### Watching Task Updates
```dart
final taskStream = taskService.watchOpenTasks();
taskStream.listen((tasks) {
  // Update UI with new task list
});
```

## Testing

### Unit Tests
Test coverage includes:
- Task CRUD operations
- Checkbox parsing logic
- Sync mechanism
- Priority and status management

### Integration Tests
- Note-task synchronization
- Backend sync with conflict resolution
- Offline operation queue
- Real-time updates

### Manual Testing Checklist
- [ ] Create task from note checkbox
- [ ] Toggle task completion in note
- [ ] Create standalone task
- [ ] Set and modify due dates
- [ ] Change task priorities
- [ ] View tasks in calendar
- [ ] Filter and sort tasks
- [ ] Delete and recover tasks
- [ ] Sync across devices
- [ ] Offline task creation

## Migration Guide

### For Existing Users
1. Database migration runs automatically on app update
2. Existing checkboxes in notes are parsed and imported
3. Task positions are preserved
4. No data loss or manual intervention required

### For Developers
1. Run database migration: `supabase migration up`
2. Regenerate Drift code: `dart run build_runner build`
3. Update providers if needed
4. Test sync functionality

## Troubleshooting

### Common Issues

1. **Tasks not syncing**
   - Check network connectivity
   - Verify user authentication
   - Review pending operations queue

2. **Duplicate tasks**
   - Check content hash generation
   - Verify position tracking
   - Review sync timing

3. **Calendar not showing tasks**
   - Ensure tasks have due dates
   - Check date parsing logic
   - Verify timezone handling

## Future Enhancements

### Planned Features
- Task templates
- Recurring tasks
- Task dependencies
- Time tracking
- Task attachments
- Collaborative task assignment
- Smart suggestions
- Natural language due dates
- Task analytics dashboard
- Export to calendar apps

### API Extensions
- Bulk task operations
- Advanced search filters
- Task history tracking
- Undo/redo support
- Conflict resolution strategies

## Conclusion

The task management system provides a robust, production-ready solution for managing actionable items within Duru Notes. It follows best practices for:
- Offline-first architecture
- Real-time synchronization
- User experience design
- Performance optimization
- Data integrity

The system is fully integrated with the existing note infrastructure while providing dedicated task management capabilities that rival standalone task applications.
