# Production-Grade Task System Improvements - Development Prompts

## 1. Link Task Records to Reminders (Persist reminderId)

### Objective
Implement bidirectional linking between tasks and their reminders to prevent duplicate notifications and enable proper reminder management when tasks are updated or snoozed.

### Current Issues
- `TaskReminderBridge.createTaskReminder()` doesn't save the returned `reminderId` back to the task
- `TaskService.updateTask()` accepts a `reminderId` parameter but it's not being called
- This causes duplicate reminders when tasks are updated since the system can't identify existing reminders

### Implementation Requirements

#### 1.1 Update TaskReminderBridge
```dart
// In lib/services/task_reminder_bridge.dart

// Update createTaskReminder method (lines 72-126)
Future<int?> createTaskReminder({
  required NoteTask task,
  Duration? beforeDueDate,
}) async {
  // ... existing implementation ...
  
  if (reminderId != null) {
    // CRITICAL: Save reminder ID back to task
    await _taskService.updateTask(
      taskId: task.id,
      reminderId: reminderId,  // This line needs to be uncommented/added
    );
    
    _logger.info('Created and linked task reminder', data: {
      'taskId': task.id,
      'reminderId': reminderId,
      'reminderTime': reminderTime.toIso8601String(),
    });
  }
  
  return reminderId;
}

// Update snoozeTaskReminder method (lines 176-225)
Future<void> snoozeTaskReminder({
  required NoteTask task,
  required Duration snoozeDuration,
}) async {
  // ... existing snooze implementation ...
  
  if (newReminderId != null) {
    // Update task with new reminder ID after snoozing
    await _taskService.updateTask(
      taskId: task.id,
      reminderId: newReminderId,
    );
  }
}
```

#### 1.2 Update Enhanced Task Service
```dart
// In lib/services/enhanced_task_service.dart

// Modify createTask to properly link reminders (lines 34-71)
@override
Future<String> createTask({
  // ... parameters ...
  bool createReminder = true,
}) async {
  final taskId = await super.createTask(/* ... */);
  
  if (createReminder && dueDate != null) {
    try {
      final task = await _db.getTaskById(taskId);
      if (task != null) {
        // Create reminder and get its ID
        final reminderId = await _reminderBridge.createTaskReminder(
          task: task,
          beforeDueDate: const Duration(hours: 1), // Default
        );
        
        // Link reminder to task
        if (reminderId != null) {
          await updateTask(
            taskId: taskId,
            reminderId: reminderId,
          );
        }
      }
    } catch (e) {
      _logger.error('Failed to create/link reminder for task $taskId: $e');
    }
  }
  
  return taskId;
}
```

### Testing Requirements
1. Create task with due date → verify `reminderId` is saved in database
2. Update task's due date → verify old reminder is cancelled and new `reminderId` is saved
3. Snooze task reminder → verify new `reminderId` replaces old one
4. Delete task → verify associated reminder is cancelled

### Performance Considerations
- Use database transactions when creating task + reminder to ensure atomicity
- Index `reminderId` column for fast lookups
- Consider batch operations for multiple task updates

### Error Handling
```dart
try {
  final reminderId = await createReminder(/* ... */);
  if (reminderId != null) {
    await updateTask(taskId: taskId, reminderId: reminderId);
  }
} catch (e) {
  // Log but don't fail task creation
  _logger.error('Reminder linking failed', error: e);
  // Consider retry mechanism for transient failures
}
```

---

## 2. Complete the Reminder Scheduling UI Path

### Objective
Fully implement the reminder scheduling UI to honor user-selected reminder times instead of using hardcoded defaults.

### Current Issues
- `TodoBlockWidget._saveTaskMetadata` has TODO at line 201-204 for reminder handling
- `HierarchicalTodoBlockWidget` always uses default 1-hour reminder regardless of user selection
- `TaskMetadataDialog` collects reminder preferences but they're not being used

### Implementation Requirements

#### 2.1 Update TodoBlockWidget
```dart
// In lib/ui/widgets/blocks/todo_block_widget.dart

Future<void> _saveTaskMetadata(TaskMetadata metadata) async {
  if (widget.noteId == null) return;
  
  try {
    final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
    
    if (_task == null) {
      // NEW TASK WITH CUSTOM REMINDER
      if (metadata.hasReminder && 
          metadata.reminderTime != null && 
          metadata.dueDate != null) {
        // Use createTaskWithReminder for custom reminder times
        final taskId = await enhancedTaskService.createTaskWithReminder(
          noteId: widget.noteId!,
          content: _text,
          dueDate: metadata.dueDate,
          reminderTime: metadata.reminderTime,
          priority: metadata.priority,
          labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
        );
      } else {
        // Create task without reminder or with default reminder
        final taskId = await enhancedTaskService.createTask(
          noteId: widget.noteId!,
          content: _text,
          priority: metadata.priority,
          dueDate: metadata.dueDate,
          labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
          createReminder: metadata.hasReminder && metadata.dueDate != null,
        );
      }
    } else {
      // UPDATE EXISTING TASK
      final oldTask = _task!;
      
      await enhancedTaskService.updateTask(
        taskId: oldTask.id,
        priority: metadata.priority,
        dueDate: metadata.dueDate,
        labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
        notes: metadata.notes,
        estimatedMinutes: metadata.estimatedMinutes,
      );
      
      // Handle reminder changes
      if (metadata.hasReminder && metadata.reminderTime != null) {
        final reminderBridge = ref.read(taskReminderBridgeProvider);
        
        if (oldTask.reminderId == null) {
          // Create new reminder
          final updatedTask = await ref.read(appDbProvider).getTaskById(oldTask.id);
          if (updatedTask != null && metadata.dueDate != null) {
            final duration = metadata.dueDate.difference(metadata.reminderTime);
            await reminderBridge.createTaskReminder(
              task: updatedTask,
              beforeDueDate: duration.abs(),
            );
          }
        } else {
          // Update existing reminder
          final updatedTask = await ref.read(appDbProvider).getTaskById(oldTask.id);
          if (updatedTask != null) {
            await reminderBridge.updateTaskReminder(updatedTask);
          }
        }
      } else if (!metadata.hasReminder && oldTask.reminderId != null) {
        // Cancel existing reminder
        await ref.read(taskReminderBridgeProvider).cancelTaskReminder(oldTask);
      }
    }
    
    await _loadTaskData();
  } catch (e) {
    _logger.error('Error saving task metadata', error: e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving task: $e')),
      );
    }
  }
}
```

#### 2.2 Update HierarchicalTodoBlockWidget
```dart
// In lib/ui/widgets/blocks/hierarchical_todo_block_widget.dart

Future<void> _saveTaskMetadata(TaskMetadata metadata) async {
  if (widget.noteId == null) return;
  
  try {
    final enhancedTaskService = ref.read(enhancedTaskServiceProvider);
    
    if (_task == null) {
      // Create new task with custom reminder time if specified
      if (metadata.hasReminder && 
          metadata.reminderTime != null && 
          metadata.dueDate != null &&
          metadata.reminderTime != metadata.dueDate) {
        // Custom reminder time specified
        await enhancedTaskService.createTaskWithReminder(
          noteId: widget.noteId!,
          content: _text,
          dueDate: metadata.dueDate,
          reminderTime: metadata.reminderTime,
          priority: metadata.priority,
          parentTaskId: widget.parentTaskId,
          labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
        );
      } else {
        // Use default reminder (1 hour before) or no reminder
        await enhancedTaskService.createTask(
          noteId: widget.noteId!,
          content: _text,
          priority: metadata.priority,
          dueDate: metadata.dueDate,
          parentTaskId: widget.parentTaskId,
          labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
          notes: metadata.notes,
          estimatedMinutes: metadata.estimatedMinutes,
          createReminder: metadata.hasReminder,
        );
      }
    } else {
      // Update existing task (similar to above)
      // ... implementation ...
    }
    
    await _loadTaskData();
  } catch (e) {
    // Error handling
  }
}
```

### Testing Requirements
1. Create task with "Remind me 1 day before" → verify reminder scheduled for correct time
2. Create task with "Remind me 2 hours before" → verify reminder scheduled correctly
3. Update existing task to add reminder → verify reminder is created
4. Update existing task to change reminder time → verify old reminder cancelled, new one created
5. Toggle reminder off → verify reminder is cancelled

### UI/UX Considerations
- Show visual confirmation when reminder is set (icon, badge)
- Display actual reminder time in task metadata
- Allow quick reminder presets (15 min, 1 hour, 1 day, 1 week before)
- Validate reminder time is before due date

---

## 3. Use Single Sync Mechanism to Avoid Duplicate Tasks

### Objective
Eliminate duplicate task creation by using only the bidirectional sync mechanism instead of running both legacy and modern sync simultaneously.

### Current Issues
- `ModernEditNoteScreen.initState()` calls both `noteTaskCoordinator.startWatchingNote()` and `taskSyncService.syncTasksForNote()`
- Legacy sync uses position-based IDs (`note123_task_0`) while bidirectional uses content hashes
- This causes tasks to be created twice with different IDs, then one set gets deleted

### Implementation Requirements

#### 3.1 Update ModernEditNoteScreen
```dart
// In lib/ui/modern_edit_note_screen.dart

@override
void initState() {
  super.initState();
  
  // ... existing initialization ...
  
  // Initialize bidirectional task sync if editing existing note
  if (widget.noteId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          // ONLY use bidirectional sync - it handles initial sync internally
          ref.read(noteTaskCoordinatorProvider).startWatchingNote(widget.noteId!);
          
          // REMOVE or comment out legacy sync
          // DO NOT CALL: taskSyncService.syncTasksForNote()
        } catch (e) {
          debugPrint('Could not start watching note: $e');
        }
      }
    });
  }
  
  // REMOVE the duplicate sync block at lines 117-127
  // This entire block should be deleted:
  // if (widget.noteId != null &&
  //     (initialBody.contains('- [ ]') || initialBody.contains('- [x]'))) {
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     try {
  //       final taskSyncService = ref.read(noteTaskSyncServiceProvider);
  //       await taskSyncService.syncTasksForNote(widget.noteId!, initialBody);
  //     } catch (e) {
  //       debugPrint('Failed to initialize task sync: $e');
  //     }
  //   });
  // }
  
  // ... rest of initState ...
}

// Also update save method to use only bidirectional sync
Future<void> _saveNote() async {
  // ... existing save logic ...
  
  final noteIdToUse = savedNote?.id ?? widget.noteId;
  if (noteIdToUse != null) {
    // Initialize bidirectional sync for new notes
    if (widget.noteId == null && mounted) {
      try {
        ref.read(noteTaskCoordinatorProvider).startWatchingNote(noteIdToUse);
      } catch (e) {
        debugPrint('Could not start watching new note: $e');
      }
    }
    
    // REMOVE legacy sync call at lines 1407-1412
    // DO NOT CALL: taskSyncService.syncTasksForNote()
  }
}
```

#### 3.2 Ensure BidirectionalTaskSyncService Handles Initial Sync
```dart
// In lib/services/bidirectional_task_sync_service.dart

Future<void> initializeBidirectionalSync(String noteId) async {
  try {
    // Perform initial sync from note to tasks
    final note = await _db.getNote(noteId);
    if (note != null) {
      // This should create any missing tasks with stable IDs
      await syncFromNoteToTasks(noteId, note.body);
    }
    
    _logger.info('Initialized bidirectional sync for note', data: {
      'noteId': noteId,
      'taskCount': _lineMappingCache[noteId]?.length ?? 0,
    });
  } catch (e, stack) {
    _logger.error('Failed to initialize bidirectional sync', 
      error: e, 
      stackTrace: stack,
      data: {'noteId': noteId}
    );
  }
}
```

### Migration Strategy
1. Add feature flag to toggle between sync mechanisms during rollout
2. Log both sync results to compare and ensure bidirectional is working correctly
3. Gradually enable for users based on success metrics
4. Remove legacy sync code after full migration

### Testing Requirements
1. Open note with tasks → verify tasks load exactly once
2. Create new note with tasks → verify tasks are created with stable IDs
3. Edit task in note → verify no duplicates appear
4. Rapid open/close note → verify no duplicate tasks created
5. Check performance metrics → should be faster with single sync

---

## 4. Preserve Task Metadata During Note Edits

### Objective
Implement a robust mechanism to preserve task metadata (labels, notes, time estimates, reminders) when tasks are edited through the note text.

### Current Issues
- Task metadata is lost when task text is edited in the note
- Content hash changes cause task to be recreated with new ID
- No mechanism to carry over non-text fields during sync

### Implementation Requirements

#### 4.1 Implement Stable Task ID Embedding
```dart
// In lib/services/bidirectional_task_sync_service.dart

// Add method to embed task IDs in note content
String _embedTaskIds(String noteContent, List<TaskLineMapping> mappings) {
  final lines = noteContent.split('\n');
  final result = <String>[];
  
  for (int i = 0; i < lines.length; i++) {
    var line = lines[i];
    
    // Check if this is a task line
    final mapping = mappings.firstWhereOrNull((m) => m.lineNumber == i);
    if (mapping != null) {
      // Embed task ID as invisible comment
      // Format: <!-- task-id:uuid -->
      final idComment = ' <!-- task-id:${mapping.taskId} -->';
      
      // Only add if not already present
      if (!line.contains('<!-- task-id:')) {
        line = line + idComment;
      }
    }
    
    result.add(line);
  }
  
  return result.join('\n');
}

// Update parsing to extract embedded IDs
TaskInfo? _parseTaskLine(String line) {
  // Extract task ID if present
  String? embeddedId;
  final idMatch = RegExp(r'<!-- task-id:([a-f0-9-]+) -->').firstMatch(line);
  if (idMatch != null) {
    embeddedId = idMatch.group(1);
    // Remove ID comment from visible text
    line = line.replaceAll(idMatch.group(0)!, '').trim();
  }
  
  // ... existing parsing logic ...
  
  return TaskInfo(
    content: content,
    isCompleted: isCompleted,
    priority: priority,
    dueDate: dueDate,
    taskId: embeddedId, // Use embedded ID if available
  );
}

// Update sync to preserve metadata
Future<void> _syncTaskFromMapping(
  TaskLineMapping mapping,
  Map<String, NoteTask> existingTasks,
) async {
  // Try to find existing task by embedded ID first
  NoteTask? existingTask;
  
  if (mapping.taskId != null) {
    existingTask = existingTasks[mapping.taskId];
  }
  
  // Fallback to content matching if no ID
  if (existingTask == null) {
    existingTask = existingTasks.values.firstWhereOrNull(
      (t) => _isSimilarContent(t.content, mapping.taskContent),
    );
  }
  
  if (existingTask != null) {
    // Update only changed fields, preserve metadata
    await _taskService.updateTask(
      taskId: existingTask.id,
      content: mapping.taskContent,
      status: mapping.isCompleted ? TaskStatus.completed : TaskStatus.open,
      priority: mapping.priority ?? existingTask.priority,
      dueDate: mapping.dueDate ?? existingTask.dueDate,
      // Preserve these fields
      labels: existingTask.labels != null 
        ? {'labels': jsonDecode(existingTask.labels!)} 
        : null,
      notes: existingTask.notes,
      estimatedMinutes: existingTask.estimatedMinutes,
      actualMinutes: existingTask.actualMinutes,
      reminderId: existingTask.reminderId,
    );
  } else {
    // Create new task
    await _createNewTask(mapping);
  }
}
```

#### 4.2 Alternative: Position-Based Matching with Fuzzy Content Matching
```dart
// More robust matching algorithm
NoteTask? _findMatchingTask(
  TaskLineMapping mapping,
  Map<String, NoteTask> existingTasks,
  List<String> noteLines,
) {
  // 1. Try exact ID match
  if (mapping.taskId != null && existingTasks.containsKey(mapping.taskId)) {
    return existingTasks[mapping.taskId];
  }
  
  // 2. Try position + fuzzy content match
  final positionMatches = existingTasks.values.where(
    (t) => t.position == mapping.lineNumber,
  ).toList();
  
  if (positionMatches.isNotEmpty) {
    // Find best content match at this position
    final bestMatch = positionMatches.reduce((a, b) {
      final scoreA = _contentSimilarityScore(a.content, mapping.taskContent);
      final scoreB = _contentSimilarityScore(b.content, mapping.taskContent);
      return scoreA > scoreB ? a : b;
    });
    
    if (_contentSimilarityScore(bestMatch.content, mapping.taskContent) > 0.7) {
      return bestMatch;
    }
  }
  
  // 3. Try content similarity across all tasks
  final contentMatches = existingTasks.values.where(
    (t) => _contentSimilarityScore(t.content, mapping.taskContent) > 0.8,
  ).toList();
  
  if (contentMatches.length == 1) {
    return contentMatches.first;
  }
  
  return null; // No match found, create new task
}

double _contentSimilarityScore(String content1, String content2) {
  // Implement Levenshtein distance or similar algorithm
  // Return score between 0 and 1
  // Consider using package:edit_distance
}
```

### Testing Requirements
1. Add labels to task, edit task text in note → verify labels preserved
2. Add reminder to task, edit task text → verify reminder preserved  
3. Add time estimate, edit task → verify estimate preserved
4. Move task to different position in note → verify metadata preserved
5. Significantly change task text → verify metadata preserved if similarity > threshold

---

## 5. Implement "Open Task" Notification Action (Deep Linking)

### Objective
Implement deep linking from task reminder notifications to open the specific task in its note context.

### Current Issues
- `TaskReminderBridge._handleOpenTaskFromNotification` only logs, doesn't navigate
- No integration with `DeepLinkService` for task notifications
- iOS notification categories not properly configured for actions

### Implementation Requirements

#### 5.1 Update TaskReminderBridge
```dart
// In lib/services/task_reminder_bridge.dart

Future<void> _handleOpenTaskFromNotification({
  required String taskId,
  required String noteId,
}) async {
  try {
    _logger.info('Opening task from notification', data: {
      'taskId': taskId,
      'noteId': noteId,
    });
    
    // Use DeepLinkService to handle navigation
    final context = navigatorKey.currentContext;
    if (context != null) {
      final deepLinkService = DeepLinkService(ref: _ref);
      await deepLinkService.handleDeepLink(
        context: context,
        payload: jsonEncode({
          'type': 'task_reminder',
          'taskId': taskId,
          'noteId': noteId,
        }),
      );
    } else {
      // Store for later if app not ready
      _pendingDeepLink = {
        'type': 'task_reminder',
        'taskId': taskId,
        'noteId': noteId,
      };
    }
  } catch (e, stack) {
    _logger.error(
      'Failed to open task from notification',
      error: e,
      stackTrace: stack,
      data: {'taskId': taskId, 'noteId': noteId},
    );
  }
}
```

#### 5.2 Configure Notification Actions
```dart
// In lib/services/notification_service.dart or initialization

Future<void> _configureNotificationActions() async {
  // Android notification actions
  const androidActions = [
    AndroidNotificationAction(
      'complete_task',
      'Complete',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      'snooze_task_15',
      'Snooze 15m',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      'open_task',
      'Open',
      showsUserInterface: true, // Opens app
      cancelNotification: false,
    ),
  ];
  
  // iOS notification category
  const iosCategory = DarwinNotificationCategory(
    'TASK_REMINDER',
    actions: [
      DarwinNotificationAction.plain(
        'complete_task',
        'Complete',
        options: {
          DarwinNotificationActionOption.destructive,
        },
      ),
      DarwinNotificationAction.plain(
        'snooze_task_15',
        'Snooze',
      ),
      DarwinNotificationAction.plain(
        'open_task',
        'Open',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
    ],
  );
  
  // Register with plugin
  await flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        notificationCategories: [iosCategory],
      ),
    ),
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );
}

Future<void> _handleNotificationResponse(
  NotificationResponse response,
) async {
  if (response.actionId == 'open_task' && response.payload != null) {
    // Parse payload and handle deep link
    final payload = jsonDecode(response.payload!);
    await _handleOpenTaskAction(payload);
  }
}
```

#### 5.3 Update DeepLinkService to Handle Task Navigation
```dart
// In lib/services/deep_link_service.dart

Future<void> _openTaskInNote(
  BuildContext context,
  String taskId,
  String noteId,
) async {
  try {
    // Get the note
    final notesRepo = _ref.read(notesRepositoryProvider);
    final note = await notesRepo.getNote(noteId);
    
    if (note == null) {
      _showTaskNotFoundMessage(context);
      return;
    }
    
    // Navigate to note editor with task highlight
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModernEditNoteScreen(
          noteId: note.id,
          initialTitle: note.title,
          initialBody: note.body,
          highlightTaskId: taskId, // New parameter
        ),
      ),
    );
    
    // After navigation, scroll to task
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTask(taskId);
    });
    
  } catch (e, stack) {
    _logger.error(
      'Failed to open task in note',
      error: e,
      stackTrace: stack,
    );
    _showErrorMessage(context, 'Could not open task');
  }
}

void _scrollToTask(String taskId) {
  // Implementation to scroll to specific task in note
  // This would require the note editor to expose scroll control
}
```

### Testing Requirements
1. Tap "Open" on task notification → app opens to correct note
2. Task is highlighted/scrolled to in the note
3. Works from background, killed state, and foreground
4. iOS and Android both handle action correctly
5. Deep link works even if task was deleted (graceful fallback)

---

## 6. Finalize Snooze Reminder Functionality

### Objective
Fully integrate SnoozeReminderService with proper snooze limits, smart scheduling, and multiple duration options.

### Current Issues
- `SnoozeReminderService` is commented out in `ReminderCoordinator` initialization
- TaskReminderBridge implements basic snoozing but doesn't check snooze limits
- Limited snooze duration options (only 15 min and 1 hour)

### Implementation Requirements

#### 6.1 Enable SnoozeReminderService
```dart
// In lib/services/reminders/reminder_coordinator.dart

class ReminderCoordinator {
  ReminderCoordinator({
    required AppDb database,
    required FlutterLocalNotificationsPlugin notificationPlugin,
  }) : _db = database,
       _plugin = notificationPlugin {
    // Initialize services
    _timeReminderService = TimeReminderService(_plugin, _db);
    _recurringReminderService = RecurringReminderService(_plugin, _db);
    
    // ENABLE SNOOZE SERVICE
    _snoozeService = SnoozeReminderService(_plugin, _db);
    
    // Start monitoring
    _startReminderMonitoring();
  }
  
  // Expose snooze service
  SnoozeReminderService get snoozeService => _snoozeService;
}
```

#### 6.2 Integrate Snooze Limits in TaskReminderBridge
```dart
// In lib/services/task_reminder_bridge.dart

Future<void> snoozeTaskReminder({
  required NoteTask task,
  required Duration snoozeDuration,
}) async {
  if (task.reminderId == null || task.dueDate == null) return;
  
  try {
    // Check snooze limit using SnoozeReminderService
    final reminder = await _db.getReminderById(task.reminderId!);
    if (reminder != null) {
      // Use SnoozeReminderService for consistent snooze handling
      final snoozeService = _reminderCoordinator.snoozeService;
      
      // Convert duration to SnoozeDuration enum
      final snoozeDurationEnum = _durationToSnoozeDuration(snoozeDuration);
      
      final success = await snoozeService.snoozeReminder(
        task.reminderId!,
        snoozeDurationEnum,
      );
      
      if (!success) {
        // Max snooze limit reached
        _logger.warning('Max snooze limit reached for task ${task.id}');
        
        // Notify user via toast or notification
        await _notifyMaxSnoozeReached(task);
        return;
      }
      
      // Update task with new reminder info if needed
      // The SnoozeReminderService handles the reminder update
      
      _logger.info('Snoozed task reminder via SnoozeService', data: {
        'taskId': task.id,
        'reminderId': task.reminderId,
        'duration': snoozeDuration.inMinutes,
      });
    }
  } catch (e, stack) {
    _logger.error(
      'Failed to snooze task reminder',
      error: e,
      stackTrace: stack,
    );
  }
}

SnoozeDuration _durationToSnoozeDuration(Duration duration) {
  if (duration.inMinutes <= 5) return SnoozeDuration.fiveMinutes;
  if (duration.inMinutes <= 15) return SnoozeDuration.fifteenMinutes;
  if (duration.inMinutes <= 30) return SnoozeDuration.thirtyMinutes;
  if (duration.inHours <= 1) return SnoozeDuration.oneHour;
  if (duration.inHours <= 2) return SnoozeDuration.twoHours;
  return SnoozeDuration.tomorrow;
}

Future<void> _notifyMaxSnoozeReached(NoteTask task) async {
  // Show notification that snooze limit reached
  await _notificationPlugin.show(
    task.id.hashCode + 1000, // Different ID to avoid conflict
    'Snooze Limit Reached',
    'This task has been snoozed 5 times. Please complete or reschedule it.',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
      ),
    ),
  );
}
```

#### 6.3 Add More Snooze Options
```dart
// Update notification actions to include more options

const androidActions = [
  AndroidNotificationAction('complete_task', 'Complete'),
  AndroidNotificationAction('snooze_task_5', '5 min'),
  AndroidNotificationAction('snooze_task_15', '15 min'),
  AndroidNotificationAction('snooze_task_60', '1 hour'),
  AndroidNotificationAction('snooze_task_tomorrow', 'Tomorrow'),
  AndroidNotificationAction('open_task', 'Open'),
];

// Handle various snooze durations
Future<void> handleTaskNotificationAction({
  required String action,
  required String payload,
}) async {
  final data = jsonDecode(payload) as Map<String, dynamic>;
  final taskId = data['taskId'] as String?;
  
  if (taskId == null) return;
  
  switch (action) {
    case 'snooze_task_5':
      await snoozeTaskReminder(
        task: await _getTask(taskId),
        snoozeDuration: const Duration(minutes: 5),
      );
      break;
    case 'snooze_task_15':
      await snoozeTaskReminder(
        task: await _getTask(taskId),
        snoozeDuration: const Duration(minutes: 15),
      );
      break;
    case 'snooze_task_60':
      await snoozeTaskReminder(
        task: await _getTask(taskId),
        snoozeDuration: const Duration(hours: 1),
      );
      break;
    case 'snooze_task_tomorrow':
      // Smart scheduling for tomorrow morning
      final tomorrow = _calculateTomorrowMorning();
      final duration = tomorrow.difference(DateTime.now());
      await snoozeTaskReminder(
        task: await _getTask(taskId),
        snoozeDuration: duration,
      );
      break;
    // ... other actions
  }
}
```

### Database Migration
```sql
-- Ensure snooze_count is tracked properly
ALTER TABLE note_reminders 
ADD COLUMN IF NOT EXISTS snooze_count INTEGER DEFAULT 0;

-- Add index for efficient snooze queries
CREATE INDEX IF NOT EXISTS idx_reminders_snooze 
ON note_reminders(is_snoozed, snoozed_until);
```

### Testing Requirements
1. Snooze task 5 times → 6th attempt shows limit message
2. Snooze for "tomorrow" at 11 PM → reminder at 9 AM next day
3. Snooze count persists across app restarts
4. Different snooze durations work correctly
5. Snooze respects task due date (doesn't snooze past it)

---

## 7. Use User's Input for New Task Titles

### Objective
Fix the issue where new standalone tasks always get "New Task" as title regardless of user input.

### Current Issues
- `EnhancedTaskListScreen._createStandaloneTask` hardcodes content as "New Task"
- `TaskMetadataDialog` collects `taskContent` but it's ignored
- Users must edit task after creation to set actual title

### Implementation Requirements

#### 7.1 Update Task Creation in EnhancedTaskListScreen
```dart
// In lib/ui/enhanced_task_list_screen.dart

Future<void> _createStandaloneTask(TaskMetadata metadata) async {
  try {
    final taskService = ref.read(enhancedTaskServiceProvider);
    
    // USE USER'S INPUT instead of hardcoded "New Task"
    final taskContent = metadata.taskContent.trim();
    
    // Validate content
    if (taskContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task title cannot be empty'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Create task with user's content
    final taskId = await taskService.createTask(
      noteId: 'standalone',
      content: taskContent, // USE ACTUAL USER INPUT
      priority: metadata.priority,
      dueDate: metadata.dueDate,
      labels: metadata.labels.isNotEmpty ? {'labels': metadata.labels} : null,
      notes: metadata.notes,
      estimatedMinutes: metadata.estimatedMinutes,
      createReminder: metadata.hasReminder && metadata.dueDate != null,
    );
    
    // Handle custom reminder time if specified
    if (metadata.hasReminder && 
        metadata.reminderTime != null && 
        metadata.dueDate != null &&
        metadata.reminderTime != metadata.dueDate) {
      final task = await ref.read(appDbProvider).getTaskById(taskId);
      if (task != null) {
        final duration = metadata.dueDate!.difference(metadata.reminderTime!);
        await ref.read(taskReminderBridgeProvider).createTaskReminder(
          task: task,
          beforeDueDate: duration.abs(),
        );
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created task: $taskContent'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Refresh or navigate to task
            },
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating task: $e')),
      );
    }
  }
}

Future<void> _showCreateStandaloneTaskDialog(BuildContext context) async {
  final result = await showDialog<TaskMetadata>(
    context: context,
    builder: (context) => TaskMetadataDialog(
      taskContent: '', // Start with empty, not "New Task"
      isNewTask: true, // Flag to show appropriate placeholder
      onSave: (metadata) => Navigator.of(context).pop(metadata),
    ),
  );
  
  if (result != null) {
    await _createStandaloneTask(result);
  }
}
```

#### 7.2 Update TaskMetadataDialog for Better UX
```dart
// In lib/ui/dialogs/task_metadata_dialog.dart

class TaskMetadataDialog extends StatefulWidget {
  final String taskContent;
  final bool isNewTask; // Add flag for new tasks
  // ... other fields
  
  @override
  _TaskMetadataDialogState createState() => _TaskMetadataDialogState();
}

class _TaskMetadataDialogState extends State<TaskMetadataDialog> {
  late TextEditingController _contentController;
  
  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.taskContent);
    
    // Auto-focus on content field for new tasks
    if (widget.isNewTask && widget.taskContent.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_contentFocusNode);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNewTask ? 'New Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              decoration: InputDecoration(
                labelText: 'Task Title*',
                hintText: widget.isNewTask 
                  ? 'Enter task description...' 
                  : 'Task description',
                errorText: _contentError,
              ),
              autofocus: widget.isNewTask,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {
                  _contentError = value.trim().isEmpty 
                    ? 'Task title is required' 
                    : null;
                });
              },
            ),
            // ... other fields
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _contentController.text.trim().isEmpty ? null : _save,
          child: Text(widget.isNewTask ? 'Create' : 'Save'),
        ),
      ],
    );
  }
  
  void _save() {
    final content = _contentController.text.trim();
    
    if (content.isEmpty) {
      setState(() {
        _contentError = 'Task title is required';
      });
      return;
    }
    
    widget.onSave(TaskMetadata(
      taskContent: content,
      // ... other metadata
    ));
  }
}
```

### Testing Requirements
1. Create new task with title "Buy groceries" → task shows "Buy groceries"
2. Try to create task with empty title → validation error shown
3. Create task with long title → properly truncated in list view
4. Edit existing task title → changes are saved
5. Bulk create multiple tasks → each has correct title

---

## 8. Ensure Robust Sync on Rapid Task Toggling

### Objective
Prevent sync issues and data loss when users rapidly toggle task checkboxes or make quick edits.

### Current Issues
- 500ms debounce may miss rapid changes
- `_activeSyncOperations` flag might skip important updates
- No final sync on note close if changes pending

### Implementation Requirements

#### 8.1 Improve Debounce Logic
```dart
// In lib/services/bidirectional_task_sync_service.dart

class BidirectionalTaskSyncService {
  // Reduce debounce for critical operations
  static const _defaultDebounceDelay = Duration(milliseconds: 500);
  static const _criticalDebounceDelay = Duration(milliseconds: 100);
  
  // Track pending changes
  final Map<String, List<PendingChange>> _pendingChanges = {};
  
  Timer? _debounceTimer;
  
  void _scheduleSync(String noteId, {bool isCritical = false}) {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Use shorter delay for critical changes (like checkbox toggles)
    final delay = isCritical ? _criticalDebounceDelay : _defaultDebounceDelay;
    
    _debounceTimer = Timer(delay, () async {
      await _processPendingChanges(noteId);
    });
  }
  
  Future<void> _processPendingChanges(String noteId) async {
    final changes = _pendingChanges[noteId];
    if (changes == null || changes.isEmpty) return;
    
    // Process all pending changes
    _pendingChanges[noteId] = [];
    
    // If another sync is active, queue this one
    if (_activeSyncOperations.contains(noteId)) {
      _pendingChanges[noteId] = changes;
      _scheduleSync(noteId); // Reschedule
      return;
    }
    
    _activeSyncOperations.add(noteId);
    try {
      // Apply all changes
      for (final change in changes) {
        await _applyChange(change);
      }
    } finally {
      _activeSyncOperations.remove(noteId);
      
      // Check if more changes accumulated
      if (_pendingChanges[noteId]?.isNotEmpty ?? false) {
        _scheduleSync(noteId);
      }
    }
  }
  
  // Handle checkbox toggle specifically
  Future<void> handleTaskToggle({
    required String taskId,
    required String noteId,
    required bool isCompleted,
  }) async {
    // Add to pending changes
    _pendingChanges[noteId] ??= [];
    _pendingChanges[noteId]!.add(
      PendingChange(
        type: ChangeType.toggle,
        taskId: taskId,
        isCompleted: isCompleted,
        timestamp: DateTime.now(),
      ),
    );
    
    // Schedule with critical priority
    _scheduleSync(noteId, isCritical: true);
  }
}

class PendingChange {
  final ChangeType type;
  final String taskId;
  final bool? isCompleted;
  final String? content;
  final DateTime timestamp;
  
  PendingChange({
    required this.type,
    required this.taskId,
    this.isCompleted,
    this.content,
    required this.timestamp,
  });
}

enum ChangeType { toggle, edit, create, delete }
```

#### 8.2 Ensure Final Sync on Note Close
```dart
// In lib/services/note_task_coordinator.dart

class NoteTaskCoordinator {
  // Force sync when stopping watch
  Future<void> stopWatchingNote(String noteId) async {
    try {
      // Force immediate sync of any pending changes
      await _forceSync(noteId);
      
      // Then stop watching
      _activeWatchers.remove(noteId);
      _noteControllers[noteId]?.close();
      _noteControllers.remove(noteId);
      
      _logger.info('Stopped watching note and synced final changes', 
        data: {'noteId': noteId}
      );
    } catch (e, stack) {
      _logger.error('Error during final sync', 
        error: e, 
        stackTrace: stack
      );
    }
  }
  
  Future<void> _forceSync(String noteId) async {
    // Cancel any pending debounced syncs
    _syncService.cancelPendingSync(noteId);
    
    // Force immediate sync
    final note = await _db.getNote(noteId);
    if (note != null) {
      await _syncService.syncFromNoteToTasks(noteId, note.body);
    }
  }
}

// In lib/ui/modern_edit_note_screen.dart

@override
void dispose() {
  // Force final sync before disposing
  if (widget.noteId != null) {
    // Use synchronous callback to ensure sync completes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(noteTaskCoordinatorProvider).stopWatchingNote(
          widget.noteId!
        );
      } catch (e) {
        debugPrint('Error stopping note watch: $e');
      }
    });
  }
  
  _noteController.dispose();
  _contentFocusNode.dispose();
  // ... other disposals
  super.dispose();
}
```

#### 8.3 Add Optimistic UI Updates
```dart
// In lib/ui/widgets/blocks/todo_block_widget.dart

void _toggleCompleted() async {
  // Optimistic UI update
  setState(() {
    _isCompleted = !_isCompleted;
  });
  _updateTodo();
  
  // Track the optimistic state
  final optimisticState = _isCompleted;
  
  try {
    // Update in database
    if (widget.noteId != null && _task != null) {
      final syncService = ref.read(noteTaskSyncServiceProvider);
      await syncService.updateNoteContentForTask(
        noteId: widget.noteId!,
        taskId: _task!.id,
        isCompleted: _isCompleted,
      );
    }
  } catch (e) {
    // Revert on error
    if (mounted && _isCompleted == optimisticState) {
      setState(() {
        _isCompleted = !_isCompleted;
      });
      _updateTodo();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Testing Requirements
1. Toggle 5 checkboxes rapidly → all states correctly saved
2. Toggle same checkbox 10 times quickly → final state is correct
3. Edit task and immediately close note → changes are saved
4. Open note, toggle task, immediately navigate away → change persists
5. Network interruption during sync → changes queued and retried

### Performance Monitoring
```dart
// Add metrics to track sync performance
class SyncMetrics {
  static int pendingSyncs = 0;
  static int completedSyncs = 0;
  static int failedSyncs = 0;
  static Duration totalSyncTime = Duration.zero;
  static Duration maxSyncTime = Duration.zero;
  
  static void recordSync(Duration duration, bool success) {
    if (success) {
      completedSyncs++;
    } else {
      failedSyncs++;
    }
    totalSyncTime += duration;
    if (duration > maxSyncTime) {
      maxSyncTime = duration;
    }
  }
  
  static double get averageSyncTime => 
    completedSyncs > 0 
      ? totalSyncTime.inMilliseconds / completedSyncs 
      : 0;
}
```

---

## 9. Leverage Analytics & Goals Features (Future Enhancement)

### Objective
Activate the existing but unused TaskAnalyticsService and ProductivityGoalsService to provide insights and motivation.

### Current State
- TaskAnalyticsService exists with comprehensive metrics calculation
- ProductivityGoalsService can track goals but has no UI
- ProductivityAnalyticsScreen exists but may not be fully implemented

### Implementation Requirements

#### 9.1 Complete Analytics UI
```dart
// In lib/ui/productivity_analytics_screen.dart

class ProductivityAnalyticsScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ProductivityAnalyticsScreen> createState() => 
    _ProductivityAnalyticsScreenState();
}

class _ProductivityAnalyticsScreenState 
    extends ConsumerState<ProductivityAnalyticsScreen> {
  
  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(taskAnalyticsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productivity Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _showGoalsDialog,
            tooltip: 'Set Goals',
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (analytics) => _buildAnalyticsView(analytics),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
  
  Widget _buildAnalyticsView(TaskAnalytics analytics) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Completion Rate Card
        _MetricCard(
          title: 'Completion Rate',
          value: '${(analytics.completionRate * 100).toStringAsFixed(1)}%',
          trend: analytics.completionTrend,
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        
        // Tasks Per Day
        _MetricCard(
          title: 'Daily Average',
          value: '${analytics.averageTasksPerDay.toStringAsFixed(1)} tasks',
          subtitle: 'Completed per day',
          icon: Icons.calendar_today,
          color: Colors.blue,
        ),
        
        // Time Estimation Accuracy
        _MetricCard(
          title: 'Estimation Accuracy',
          value: '${(analytics.estimationAccuracy * 100).toStringAsFixed(0)}%',
          subtitle: analytics.tendToOverestimate 
            ? 'You tend to overestimate'
            : 'You tend to underestimate',
          icon: Icons.timer,
          color: Colors.orange,
        ),
        
        // Priority Distribution Chart
        _PriorityDistributionChart(
          distribution: analytics.priorityDistribution,
        ),
        
        // Streak Information
        _StreakCard(
          currentStreak: analytics.currentStreak,
          longestStreak: analytics.longestStreak,
        ),
        
        // Weekly Heatmap
        _WeeklyHeatmap(
          data: analytics.weeklyCompletions,
        ),
      ],
    );
  }
  
  Future<void> _showGoalsDialog() async {
    // Show dialog to create/manage goals
    final result = await showDialog<ProductivityGoal>(
      context: context,
      builder: (context) => _GoalsDialog(),
    );
    
    if (result != null) {
      await ref.read(productivityGoalsServiceProvider).createGoal(result);
    }
  }
}
```

#### 9.2 Implement Goals Tracking
```dart
// In lib/services/productivity_goals_service.dart

class ProductivityGoalsService {
  // Add notification support for goal achievements
  Future<void> checkAndNotifyAchievements() async {
    final goals = await getActiveGoals();
    
    for (final goal in goals) {
      final progress = await getGoalProgress(goal.id);
      
      if (progress >= 1.0 && !goal.isAchieved) {
        // Mark as achieved
        await markGoalAchieved(goal.id);
        
        // Send achievement notification
        await _sendAchievementNotification(goal);
        
        // Log analytics event
        analytics.event('goal.achieved', properties: {
          'goal_type': goal.type.toString(),
          'target_value': goal.targetValue,
          'days_to_achieve': goal.daysToAchieve,
        });
      }
    }
  }
  
  Future<void> _sendAchievementNotification(ProductivityGoal goal) async {
    await notificationService.show(
      goal.id.hashCode,
      '🎉 Goal Achieved!',
      'You completed your goal: ${goal.description}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'goals',
          'Goal Achievements',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

// Create provider for goals
final productivityGoalsProvider = StreamProvider<List<ProductivityGoal>>(
  (ref) async* {
    final service = ref.watch(productivityGoalsServiceProvider);
    
    // Check achievements periodically
    Timer.periodic(const Duration(hours: 1), (_) {
      service.checkAndNotifyAchievements();
    });
    
    // Stream active goals
    yield* service.watchActiveGoals();
  },
);
```

#### 9.3 Add Analytics Dashboard Widget
```dart
// Widget for home screen
class QuickStatsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayStats = ref.watch(todayStatsProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Completed',
                  value: todayStats.completed.toString(),
                  icon: Icons.check,
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Pending',
                  value: todayStats.pending.toString(),
                  icon: Icons.pending,
                  color: Colors.orange,
                ),
                _StatItem(
                  label: 'Overdue',
                  value: todayStats.overdue.toString(),
                  icon: Icons.warning,
                  color: Colors.red,
                ),
              ],
            ),
            if (todayStats.streak > 0) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, 
                    color: Colors.orange
                  ),
                  const SizedBox(width: 8),
                  Text('${todayStats.streak} day streak!'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Future AI Integration Points
```dart
// Prepare for AI insights
class AIInsightsService {
  Future<List<Insight>> generateInsights(TaskAnalytics analytics) async {
    final insights = <Insight>[];
    
    // Pattern detection
    if (analytics.mostProductiveHour != null) {
      insights.add(Insight(
        type: InsightType.pattern,
        title: 'Peak Productivity',
        description: 'You complete most tasks around '
          '${analytics.mostProductiveHour}:00. '
          'Consider scheduling important work during this time.',
      ));
    }
    
    // Recommendations
    if (analytics.estimationAccuracy < 0.7) {
      insights.add(Insight(
        type: InsightType.recommendation,
        title: 'Improve Estimations',
        description: 'Your time estimates are off by '
          '${((1 - analytics.estimationAccuracy) * 100).toStringAsFixed(0)}%. '
          'Try breaking tasks into smaller chunks for better accuracy.',
      ));
    }
    
    // Predictions
    final predictedCompletion = await predictWeeklyCompletion(analytics);
    insights.add(Insight(
      type: InsightType.prediction,
      title: 'Weekly Forecast',
      description: 'Based on your patterns, you\'re likely to complete '
        '$predictedCompletion tasks this week.',
    ));
    
    return insights;
  }
}
```

### Testing Requirements
1. Complete 5 tasks → analytics update correctly
2. Set goal for 10 tasks/week → progress tracks accurately
3. Achieve goal → notification sent, achievement recorded
4. View weekly heatmap → shows correct completion patterns
5. Time estimates vs actual → accuracy percentage is correct

---

## Performance & Scalability Considerations

### Database Optimizations
```sql
-- Add indexes for common queries
CREATE INDEX idx_tasks_note_status ON note_tasks(note_id, status, deleted);
CREATE INDEX idx_tasks_due_date ON note_tasks(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX idx_tasks_reminder ON note_tasks(reminder_id) WHERE reminder_id IS NOT NULL;
CREATE INDEX idx_reminders_trigger ON note_reminders(remind_at, is_active);

-- Partition tasks table for large datasets
CREATE TABLE note_tasks_archive (LIKE note_tasks);
-- Move completed tasks older than 6 months to archive
```

### Caching Strategy
```dart
class TaskCache {
  static final _cache = <String, CachedData>{};
  static const _cacheTimeout = Duration(minutes: 5);
  
  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher,
  ) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }
    
    final data = await fetcher();
    _cache[key] = CachedData(data, DateTime.now());
    return data;
  }
}
```

### Error Recovery
```dart
class TaskSyncErrorRecovery {
  static const maxRetries = 3;
  static const retryDelay = Duration(seconds: 1);
  
  static Future<T> withRetry<T>(
    Future<T> Function() operation,
    {String? context}
  ) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          logger.error('Operation failed after $maxRetries attempts',
            error: e,
            data: {'context': context}
          );
          rethrow;
        }
        
        await Future.delayed(retryDelay * attempts);
      }
    }
    
    throw Exception('Failed after $maxRetries retries');
  }
}
```

## Monitoring & Observability

### Key Metrics to Track
```dart
class TaskSystemMetrics {
  // Performance metrics
  static Timer trackOperation(String operation) {
    final stopwatch = Stopwatch()..start();
    return Timer(Duration.zero, () {
      analytics.timing(operation, stopwatch.elapsedMilliseconds);
    });
  }
  
  // Business metrics
  static void trackTaskCreated(NoteTask task) {
    analytics.event('task.created', properties: {
      'has_due_date': task.dueDate != null,
      'has_reminder': task.reminderId != null,
      'priority': task.priority.toString(),
      'source': task.noteId == 'standalone' ? 'standalone' : 'note',
    });
  }
  
  // Error tracking
  static void trackSyncError(String noteId, dynamic error) {
    crashlytics.recordError(error, null, reason: 'Task sync failed');
    analytics.event('task.sync_error', properties: {
      'note_id': noteId,
      'error_type': error.runtimeType.toString(),
    });
  }
}
```

## Security Considerations

### Input Validation
```dart
class TaskValidator {
  static const maxTitleLength = 500;
  static const maxNotesLength = 5000;
  
  static ValidationResult validateTaskContent(String content) {
    if (content.trim().isEmpty) {
      return ValidationResult.error('Task content cannot be empty');
    }
    
    if (content.length > maxTitleLength) {
      return ValidationResult.error(
        'Task content too long (max $maxTitleLength characters)'
      );
    }
    
    // Check for SQL injection attempts
    if (RegExp(r'[;\'"\\]|(--)|(\/\*)').hasMatch(content)) {
      return ValidationResult.error('Invalid characters in task content');
    }
    
    return ValidationResult.success();
  }
}
```

### Data Privacy
```dart
// Ensure sensitive task data is properly encrypted
class TaskEncryption {
  static Future<String> encryptTaskNotes(String notes) async {
    // Use platform secure storage for encryption keys
    final key = await secureStorage.read(key: 'task_encryption_key');
    return encrypt(notes, key);
  }
  
  static Future<String> decryptTaskNotes(String encrypted) async {
    final key = await secureStorage.read(key: 'task_encryption_key');
    return decrypt(encrypted, key);
  }
}
```

## Deployment Checklist

### Pre-deployment
- [ ] All unit tests passing
- [ ] Integration tests for task sync scenarios
- [ ] Performance testing with 1000+ tasks
- [ ] Security audit completed
- [ ] Database migrations tested on staging
- [ ] Rollback plan documented

### Feature Flags
```dart
class FeatureFlags {
  static bool get useEnhancedTaskSync => 
    RemoteConfig.getBool('enhanced_task_sync');
  
  static bool get enableSnoozeLimit =>
    RemoteConfig.getBool('task_snooze_limit');
  
  static bool get showAnalytics =>
    RemoteConfig.getBool('task_analytics');
}
```

### Gradual Rollout
1. Enable for internal testing (1% of users)
2. Monitor metrics for 24 hours
3. Expand to 10% if metrics are healthy
4. Full rollout after 1 week of stable metrics

### Success Metrics
- Task sync success rate > 99.5%
- Average sync time < 500ms
- No increase in crash rate
- User engagement with tasks increases by 15%
- Support tickets related to tasks decrease by 30%
