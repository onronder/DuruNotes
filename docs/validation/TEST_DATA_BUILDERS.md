# TEST DATA BUILDERS

## Overview
Comprehensive test data builders for creating consistent, realistic test data across all test suites.

## Quick Start

```dart
import 'package:duru_notes/test/helpers/test_data_builder.dart';

// Create a complete user with data
final testUser = TestDataBuilder.createUserWithData(
  noteCount: 10,
  taskCount: 5,
  folderCount: 3,
);

// Create specific entities
final note = TestDataBuilder.note()
  .withUserId('user-123')
  .withTitle('Test Note')
  .withEncryption()
  .build();
```

## Core Builders

### User Builder

```dart
class UserBuilder {
  String? _id;
  String? _email;
  String? _password;
  String? _amkKey;
  Map<String, dynamic>? _metadata;

  UserBuilder withId(String id) {
    _id = id;
    return this;
  }

  UserBuilder withEmail(String email) {
    _email = email;
    return this;
  }

  UserBuilder withPassword(String password) {
    _password = password;
    return this;
  }

  UserBuilder withAmkKey(String key) {
    _amkKey = key;
    return this;
  }

  UserBuilder withMetadata(Map<String, dynamic> metadata) {
    _metadata = metadata;
    return this;
  }

  TestUser build() {
    return TestUser(
      id: _id ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: _email ?? 'test@example.com',
      password: _password ?? 'SecurePassword123!',
      amkKey: _amkKey ?? generateRandomKey(),
      metadata: _metadata ?? {},
    );
  }

  static String generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(values);
  }
}
```

### Note Builder

```dart
class NoteBuilder {
  String? _id;
  String? _userId;
  String? _titlePlain;
  String? _bodyPlain;
  String? _titleEncrypted;
  String? _bodyEncrypted;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  bool _deleted = false;
  bool _isPinned = false;
  NoteKind _noteType = NoteKind.note;
  int _version = 1;
  int _encryptionVersion = 1;
  String? _folderId;
  List<String> _tags = [];
  List<TaskBuilder> _tasks = [];
  Map<String, dynamic>? _metadata;

  NoteBuilder withId(String id) {
    _id = id;
    return this;
  }

  NoteBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  NoteBuilder withTitle(String title) {
    _titlePlain = title;
    return this;
  }

  NoteBuilder withBody(String body) {
    _bodyPlain = body;
    return this;
  }

  NoteBuilder withEncryption({String? key}) {
    if (_titlePlain != null) {
      _titleEncrypted = encryptText(_titlePlain!, key);
    }
    if (_bodyPlain != null) {
      _bodyEncrypted = encryptText(_bodyPlain!, key);
    }
    return this;
  }

  NoteBuilder withFolder(String folderId) {
    _folderId = folderId;
    return this;
  }

  NoteBuilder withTags(List<String> tags) {
    _tags = tags;
    return this;
  }

  NoteBuilder withTasks(int count) {
    for (int i = 0; i < count; i++) {
      _tasks.add(
        TaskBuilder()
          .withTitle('Task $i')
          .withPosition(i),
      );
    }
    return this;
  }

  NoteBuilder asPinned() {
    _isPinned = true;
    return this;
  }

  NoteBuilder asDeleted() {
    _deleted = true;
    return this;
  }

  NoteBuilder asTemplate() {
    _noteType = NoteKind.template;
    return this;
  }

  NoteBuilder withCreatedAt(DateTime date) {
    _createdAt = date;
    return this;
  }

  NoteBuilder withUpdatedAt(DateTime date) {
    _updatedAt = date;
    return this;
  }

  LocalNote build() {
    final now = DateTime.now();
    return LocalNote(
      id: _id ?? 'note-${now.millisecondsSinceEpoch}',
      titleEncrypted: _titleEncrypted ?? 'Encrypted Title',
      bodyEncrypted: _bodyEncrypted ?? 'Encrypted Body',
      createdAt: _createdAt ?? now,
      updatedAt: _updatedAt ?? now,
      deleted: _deleted,
      isPinned: _isPinned,
      noteType: _noteType,
      version: _version,
      userId: _userId,
      encryptionVersion: _encryptionVersion,
      metadata: jsonEncode(_metadata ?? {}),
    );
  }

  static String encryptText(String text, String? key) {
    // Mock encryption for tests
    final bytes = utf8.encode(text);
    final encoded = base64.encode(bytes);
    return 'ENC:$encoded';
  }
}
```

### Task Builder

```dart
class TaskBuilder {
  String? _id;
  String? _noteId;
  String? _userId;
  String? _contentPlain;
  String? _contentEncrypted;
  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  DateTime? _completedAt;
  String? _completedBy;
  int _position = 0;
  int? _estimatedMinutes;
  int? _actualMinutes;
  String? _parentTaskId;
  List<String> _labels = [];
  String? _notes;

  TaskBuilder withId(String id) {
    _id = id;
    return this;
  }

  TaskBuilder withNoteId(String noteId) {
    _noteId = noteId;
    return this;
  }

  TaskBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  TaskBuilder withTitle(String title) {
    _contentPlain = title;
    return this;
  }

  TaskBuilder withEncryption({String? key}) {
    if (_contentPlain != null) {
      _contentEncrypted = NoteBuilder.encryptText(_contentPlain!, key);
    }
    return this;
  }

  TaskBuilder withStatus(TaskStatus status) {
    _status = status;
    return this;
  }

  TaskBuilder withPriority(TaskPriority priority) {
    _priority = priority;
    return this;
  }

  TaskBuilder withDueDate(DateTime date) {
    _dueDate = date;
    return this;
  }

  TaskBuilder asCompleted({DateTime? at, String? by}) {
    _status = TaskStatus.done;
    _completedAt = at ?? DateTime.now();
    _completedBy = by ?? 'test-user';
    return this;
  }

  TaskBuilder withPosition(int position) {
    _position = position;
    return this;
  }

  TaskBuilder withEstimate(int minutes) {
    _estimatedMinutes = minutes;
    return this;
  }

  TaskBuilder withLabels(List<String> labels) {
    _labels = labels;
    return this;
  }

  TaskBuilder asSubtaskOf(String parentId) {
    _parentTaskId = parentId;
    return this;
  }

  NoteTask build() {
    final now = DateTime.now();
    return NoteTask(
      id: _id ?? 'task-${now.millisecondsSinceEpoch}',
      noteId: _noteId ?? 'note-default',
      contentEncrypted: _contentEncrypted ?? 'Encrypted Task',
      status: _status,
      priority: _priority,
      dueDate: _dueDate,
      completedAt: _completedAt,
      completedBy: _completedBy,
      position: _position,
      estimatedMinutes: _estimatedMinutes,
      actualMinutes: _actualMinutes,
      parentTaskId: _parentTaskId,
      labelsEncrypted: _labels.isNotEmpty
        ? NoteBuilder.encryptText(jsonEncode(_labels), null)
        : null,
      notesEncrypted: _notes != null
        ? NoteBuilder.encryptText(_notes!, null)
        : null,
      userId: _userId,
      createdAt: now,
      updatedAt: now,
      deleted: false,
      encryptionVersion: 1,
    );
  }
}
```

### Folder Builder

```dart
class FolderBuilder {
  String? _id;
  String? _userId;
  String? _name;
  String? _parentId;
  String? _path;
  int _sortOrder = 0;
  String? _color;
  String? _icon;
  String? _description;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  bool _deleted = false;
  List<String> _noteIds = [];

  FolderBuilder withId(String id) {
    _id = id;
    return this;
  }

  FolderBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  FolderBuilder withName(String name) {
    _name = name;
    return this;
  }

  FolderBuilder withParent(String parentId) {
    _parentId = parentId;
    return this;
  }

  FolderBuilder withPath(String path) {
    _path = path;
    return this;
  }

  FolderBuilder withColor(String color) {
    _color = color;
    return this;
  }

  FolderBuilder withIcon(String icon) {
    _icon = icon;
    return this;
  }

  FolderBuilder withDescription(String description) {
    _description = description;
    return this;
  }

  FolderBuilder withNotes(List<String> noteIds) {
    _noteIds = noteIds;
    return this;
  }

  FolderBuilder withSortOrder(int order) {
    _sortOrder = order;
    return this;
  }

  LocalFolder build() {
    final now = DateTime.now();
    final name = _name ?? 'Test Folder';
    return LocalFolder(
      id: _id ?? 'folder-${now.millisecondsSinceEpoch}',
      userId: _userId ?? 'test-user',
      name: name,
      parentId: _parentId,
      path: _path ?? '/$name',
      sortOrder: _sortOrder,
      color: _color,
      icon: _icon,
      description: _description,
      createdAt: _createdAt ?? now,
      updatedAt: _updatedAt ?? now,
      deleted: _deleted,
    );
  }
}
```

### Template Builder

```dart
class TemplateBuilder extends NoteBuilder {
  String? _category;
  Map<String, dynamic>? _variables;
  bool _isSystemTemplate = false;

  TemplateBuilder withCategory(String category) {
    _category = category;
    return this;
  }

  TemplateBuilder withVariables(Map<String, dynamic> variables) {
    _variables = variables;
    return this;
  }

  TemplateBuilder asSystemTemplate() {
    _isSystemTemplate = true;
    return this;
  }

  @override
  LocalNote build() {
    final template = super.asTemplate().build();

    // Add template-specific metadata
    final metadata = {
      'category': _category ?? 'General',
      'variables': _variables ?? {},
      'isSystemTemplate': _isSystemTemplate,
    };

    return template.copyWith(
      metadata: jsonEncode(metadata),
    );
  }
}
```

### Reminder Builder

```dart
class ReminderBuilder {
  String? _id;
  String? _noteId;
  String? _userId;
  DateTime? _scheduledAt;
  ReminderType _reminderType = ReminderType.time;
  RecurrenceRule? _recurrenceRule;
  bool _isCompleted = false;
  DateTime? _completedAt;
  String? _title;
  String? _message;

  ReminderBuilder withId(String id) {
    _id = id;
    return this;
  }

  ReminderBuilder withNoteId(String noteId) {
    _noteId = noteId;
    return this;
  }

  ReminderBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  ReminderBuilder scheduledAt(DateTime time) {
    _scheduledAt = time;
    return this;
  }

  ReminderBuilder withType(ReminderType type) {
    _reminderType = type;
    return this;
  }

  ReminderBuilder withRecurrence(RecurrenceRule rule) {
    _recurrenceRule = rule;
    return this;
  }

  ReminderBuilder asCompleted() {
    _isCompleted = true;
    _completedAt = DateTime.now();
    return this;
  }

  ReminderBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  ReminderBuilder withMessage(String message) {
    _message = message;
    return this;
  }

  NoteReminder build() {
    final now = DateTime.now();
    return NoteReminder(
      id: _id ?? 'reminder-${now.millisecondsSinceEpoch}',
      noteId: _noteId ?? 'note-default',
      userId: _userId,
      scheduledAt: _scheduledAt ?? now.add(const Duration(hours: 1)),
      reminderType: _reminderType,
      recurrenceRule: _recurrenceRule,
      isCompleted: _isCompleted,
      completedAt: _completedAt,
      title: _title,
      message: _message,
      createdAt: now,
      updatedAt: now,
    );
  }
}
```

## Complex Scenario Builders

### Complete User Data Set

```dart
class TestScenarios {
  /// Create a user with a complete data set
  static Future<TestUserData> createCompleteUserData({
    required AppDb database,
    required String userId,
    int noteCount = 10,
    int taskCount = 5,
    int folderCount = 3,
    int reminderCount = 2,
    int templateCount = 2,
  }) async {
    final data = TestUserData(userId: userId);

    // Create folder hierarchy
    for (int i = 0; i < folderCount; i++) {
      final folder = FolderBuilder()
        .withUserId(userId)
        .withName('Folder $i')
        .withPath('/Folder $i')
        .build();

      await database.into(database.localFolders).insert(folder);
      data.folders.add(folder);
    }

    // Create notes with tasks
    for (int i = 0; i < noteCount; i++) {
      final note = NoteBuilder()
        .withUserId(userId)
        .withTitle('Note $i')
        .withBody('This is the body of note $i')
        .withEncryption()
        .withFolder(data.folders.first.id)
        .withTags(['tag$i', 'important'])
        .build();

      await database.into(database.localNotes).insert(note);
      data.notes.add(note);

      // Add tasks to some notes
      if (i < taskCount) {
        final task = TaskBuilder()
          .withNoteId(note.id)
          .withUserId(userId)
          .withTitle('Task for Note $i')
          .withEncryption()
          .build();

        await database.into(database.noteTasks).insert(task);
        data.tasks.add(task);
      }

      // Add reminders to some notes
      if (i < reminderCount) {
        final reminder = ReminderBuilder()
          .withNoteId(note.id)
          .withUserId(userId)
          .scheduledAt(DateTime.now().add(Duration(days: i + 1)))
          .build();

        await database.into(database.noteReminders).insert(reminder);
        data.reminders.add(reminder);
      }
    }

    // Create templates
    for (int i = 0; i < templateCount; i++) {
      final template = TemplateBuilder()
        .withUserId(userId)
        .withTitle('Template $i')
        .withBody('Template body with {{variable}}')
        .withCategory('Category $i')
        .withVariables({'variable': 'default_value'})
        .build();

      await database.into(database.localNotes).insert(template);
      data.templates.add(template);
    }

    return data;
  }

  /// Create edge case data for testing
  static Future<void> createEdgeCaseData({
    required AppDb database,
    required String userId,
  }) async {
    // Very long title
    final longTitleNote = NoteBuilder()
      .withUserId(userId)
      .withTitle('A' * 1000)  // 1000 character title
      .withEncryption()
      .build();
    await database.into(database.localNotes).insert(longTitleNote);

    // Special characters in content
    final specialCharsNote = NoteBuilder()
      .withUserId(userId)
      .withTitle('Special: <>&"\'\\/')
      .withBody('Emoji: 🎉🚀 Unicode: 你好世界')
      .withEncryption()
      .build();
    await database.into(database.localNotes).insert(specialCharsNote);

    // Deeply nested folders
    String? parentId;
    for (int i = 0; i < 10; i++) {
      final folder = FolderBuilder()
        .withUserId(userId)
        .withName('Nested $i')
        .withParent(parentId)
        .withPath('/Nested' * (i + 1))
        .build();
      await database.into(database.localFolders).insert(folder);
      parentId = folder.id;
    }

    // Task with all fields populated
    final complexTask = TaskBuilder()
      .withUserId(userId)
      .withTitle('Complex Task')
      .withEncryption()
      .withStatus(TaskStatus.inProgress)
      .withPriority(TaskPriority.high)
      .withDueDate(DateTime.now().add(const Duration(days: 7)))
      .withEstimate(120)
      .withLabels(['urgent', 'review', 'client'])
      .build();
    await database.into(database.noteTasks).insert(complexTask);

    // Recurring reminder
    final recurringReminder = ReminderBuilder()
      .withUserId(userId)
      .scheduledAt(DateTime.now())
      .withType(ReminderType.recurring)
      .withRecurrence(RecurrenceRule.daily)
      .build();
    await database.into(database.noteReminders).insert(recurringReminder);
  }

  /// Create data for performance testing
  static Future<void> createLargeDataset({
    required AppDb database,
    required String userId,
    int count = 10000,
  }) async {
    final batch = database.batch((batch) {
      for (int i = 0; i < count; i++) {
        final note = NoteBuilder()
          .withId('note-perf-$i')
          .withUserId(userId)
          .withTitle('Performance Test Note $i')
          .withBody('Body content for performance testing')
          .withEncryption()
          .build();

        batch.insert(database.localNotes, note);

        // Add task for every 10th note
        if (i % 10 == 0) {
          final task = TaskBuilder()
            .withNoteId('note-perf-$i')
            .withUserId(userId)
            .withTitle('Task $i')
            .build();

          batch.insert(database.noteTasks, task);
        }

        // Add folder for every 100th note
        if (i % 100 == 0) {
          final folder = FolderBuilder()
            .withUserId(userId)
            .withName('Folder $i')
            .build();

          batch.insert(database.localFolders, folder);
        }
      }
    });

    await batch.commit();
  }
}
```

### Test User Data Container

```dart
class TestUserData {
  final String userId;
  final List<LocalNote> notes = [];
  final List<NoteTask> tasks = [];
  final List<LocalFolder> folders = [];
  final List<NoteReminder> reminders = [];
  final List<LocalNote> templates = [];
  final List<SavedSearch> searches = [];
  final List<NoteTag> tags = [];

  TestUserData({required this.userId});

  /// Clear all data from database
  Future<void> clearAll(AppDb database) async {
    await database.clearAll();
  }

  /// Verify all data belongs to this user
  bool verifyUserIsolation() {
    for (final note in notes) {
      if (note.userId != userId) return false;
    }
    for (final task in tasks) {
      if (task.userId != userId) return false;
    }
    for (final folder in folders) {
      if (folder.userId != userId) return false;
    }
    for (final reminder in reminders) {
      if (reminder.userId != userId) return false;
    }
    return true;
  }

  /// Get statistics about the test data
  Map<String, int> getStatistics() {
    return {
      'notes': notes.length,
      'tasks': tasks.length,
      'folders': folders.length,
      'reminders': reminders.length,
      'templates': templates.length,
      'searches': searches.length,
      'tags': tags.length,
    };
  }
}
```

## Usage Examples

### Basic Usage

```dart
test('create and query notes', () async {
  final userId = 'test-user-123';

  // Create a note with builder
  final note = NoteBuilder()
    .withUserId(userId)
    .withTitle('My Note')
    .withBody('Note content')
    .withEncryption()
    .asPinned()
    .build();

  await database.into(database.localNotes).insert(note);

  // Query and verify
  final notes = await database.select(database.localNotes).get();
  expect(notes.length, 1);
  expect(notes.first.userId, userId);
});
```

### Complex Scenario

```dart
test('complete user workflow', () async {
  // Create user with full data set
  final userData = await TestScenarios.createCompleteUserData(
    database: database,
    userId: 'user-123',
    noteCount: 20,
    taskCount: 10,
    folderCount: 5,
  );

  // Verify data integrity
  expect(userData.notes.length, 20);
  expect(userData.tasks.length, 10);
  expect(userData.folders.length, 5);
  expect(userData.verifyUserIsolation(), true);

  // Simulate logout
  await userData.clearAll(database);

  // Verify complete cleanup
  final notesAfterClear = await database.select(database.localNotes).get();
  expect(notesAfterClear, isEmpty);
});
```

### Performance Testing

```dart
test('performance with large dataset', () async {
  final stopwatch = Stopwatch()..start();

  // Create large dataset
  await TestScenarios.createLargeDataset(
    database: database,
    userId: 'perf-user',
    count: 10000,
  );

  stopwatch.stop();
  print('Created 10,000 notes in ${stopwatch.elapsedMilliseconds}ms');

  // Test query performance
  stopwatch.reset();
  stopwatch.start();

  final notes = await database.select(database.localNotes).get();

  stopwatch.stop();
  print('Queried ${notes.length} notes in ${stopwatch.elapsedMilliseconds}ms');

  expect(stopwatch.elapsedMilliseconds, lessThan(1000));
});
```

### Edge Cases

```dart
test('handle edge cases', () async {
  await TestScenarios.createEdgeCaseData(
    database: database,
    userId: 'edge-user',
  );

  // Verify special characters are handled
  final notes = await database.select(database.localNotes).get();
  final specialNote = notes.firstWhere(
    (n) => n.titleEncrypted.contains('Special')
  );

  expect(specialNote, isNotNull);

  // Verify deeply nested folders
  final folders = await database.select(database.localFolders).get();
  final deepestFolder = folders.firstWhere(
    (f) => f.name == 'Nested 9'
  );

  expect(deepestFolder.path.split('/').length, greaterThan(5));
});
```

## Best Practices

1. **Always use builders for test data**
   - Ensures consistency
   - Makes tests more readable
   - Reduces boilerplate

2. **Set userId explicitly**
   - Critical for user isolation tests
   - Prevents accidental data leakage

3. **Use scenarios for complex tests**
   - Reusable test setups
   - Consistent test environments
   - Faster test writing

4. **Clean up after tests**
   - Always call `clearAll()` in tearDown
   - Verify cleanup in security tests
   - Reset mocks between tests

5. **Performance considerations**
   - Use batch operations for large datasets
   - Use in-memory database for unit tests
   - Profile slow tests regularly

## Maintenance

### Adding New Builders
1. Create builder class extending `BaseBuilder`
2. Add fluent methods for all properties
3. Implement `build()` method
4. Add to `TestDataBuilder` factory
5. Document usage examples

### Updating Existing Builders
1. Add new properties as optional
2. Maintain backward compatibility
3. Update documentation
4. Add migration notes if breaking

### Testing the Builders
```dart
test('builders create valid entities', () {
  final note = NoteBuilder().build();
  expect(note.id, isNotEmpty);
  expect(note.titleEncrypted, isNotEmpty);
  expect(note.createdAt, isNotNull);
});
```