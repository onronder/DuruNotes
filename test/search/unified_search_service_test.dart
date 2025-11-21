import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider, analyticsProvider;
import 'package:duru_notes/domain/entities/folder.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/task.dart';
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/unified_search_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _testNotesRepositoryProvider = Provider<INotesRepository>(
  (_) => throw UnimplementedError(),
);
final _testTaskRepositoryProvider = Provider<ITaskRepository>(
  (_) => throw UnimplementedError(),
);
final _testFolderRepositoryProvider = Provider<IFolderRepository>(
  (_) => throw UnimplementedError(),
);
final _testTemplateRepositoryProvider = Provider<ITemplateRepository>(
  (_) => throw UnimplementedError(),
);
final _testMigrationConfigProvider = Provider<MigrationConfig>(
  (_) => MigrationConfig.developmentConfig(),
);
final _testNoteIndexerProvider = Provider<NoteIndexer>(
  (ref) => NoteIndexer(ref),
);
final _testUnifiedSearchServiceProvider = Provider<UnifiedSearchService>((ref) {
  return UnifiedSearchService(
    ref: ref,
    migrationConfig: ref.watch(_testMigrationConfigProvider),
    notesRepository: ref.watch(_testNotesRepositoryProvider),
    taskRepository: ref.watch(_testTaskRepositoryProvider),
    folderRepository: ref.watch(_testFolderRepositoryProvider),
    templateRepository: ref.watch(_testTemplateRepositoryProvider),
    noteIndexer: ref.watch(_testNoteIndexerProvider),
  );
});

void main() {
  late ProviderContainer container;
  late UnifiedSearchService service;
  late InMemoryNotesRepository notesRepository;
  late InMemoryTaskRepository taskRepository;
  late InMemoryFolderRepository folderRepository;
  late InMemoryTemplateRepository templateRepository;

  setUp(() async {
    final now = DateTime.utc(2025, 10, 26);
    const userId = 'user-123';

    final userNotes = [
      Note(
        id: 'note-mercury',
        title: 'Project Mercury launch briefing',
        body: 'Review launch checklist for Mercury mission and propulsion',
        createdAt: now,
        updatedAt: now,
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: userId,
        tags: const ['space', 'launch'],
      ),
      Note(
        id: 'note-todo',
        title: 'Launch readiness tasks',
        body: 'Verify telemetry systems and booster sequence',
        createdAt: now,
        updatedAt: now,
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: userId,
        tags: const ['checklist'],
      ),
    ];

    final otherUserNotes = [
      Note(
        id: 'note-other',
        title: 'Project Mercury private log',
        body: 'Sensitive information for another user',
        createdAt: now,
        updatedAt: now,
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user-456',
        tags: const ['private'],
      ),
    ];

    notesRepository = InMemoryNotesRepository(
      userId: userId,
      notes: [...userNotes, ...otherUserNotes],
    );

    taskRepository = InMemoryTaskRepository(
      allowedNoteIds: userNotes.map((n) => n.id).toSet(),
      tasks: [
        Task(
          id: 'task-review',
          noteId: 'note-mercury',
          title: 'Review Mercury checklist',
          description: 'Cross-check propulsion parameters before T-5',
          status: TaskStatus.pending,
          priority: TaskPriority.high,
          dueDate: now.add(const Duration(hours: 2)),
          completedAt: null,
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
          tags: const ['space'],
          metadata: const {},
        ),
        Task(
          id: 'task-other',
          noteId: 'note-other',
          title: 'Other user task',
          description: 'Should never appear for current user searches',
          status: TaskStatus.pending,
          priority: TaskPriority.medium,
          dueDate: now,
          completedAt: null,
          createdAt: now,
          updatedAt: now,
          tags: const [],
          metadata: const {},
        ),
      ],
    );

    folderRepository = InMemoryFolderRepository(
      userId: userId,
      folders: [
        Folder(
          id: 'folder-mercury',
          name: 'Project Mercury',
          description: 'All assets related to Mercury mission',
          parentId: null,
          color: '#FFAA00',
          icon: '🚀',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
          userId: userId,
        ),
        Folder(
          id: 'folder-other',
          name: 'Private Folder',
          description: 'Should not surface',
          parentId: null,
          color: '#000000',
          icon: '🔒',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
          userId: 'user-456',
        ),
      ],
    );

    templateRepository = InMemoryTemplateRepository(
      templates: [
        Template(
          id: 'tmpl-mercury',
          name: 'Mercury Daily Update',
          content: 'Status update template for Mercury mission.',
          variables: const {},
          isSystem: false,
          createdAt: now,
          updatedAt: now,
        ),
        Template(
          id: 'tmpl-system',
          name: 'System Template',
          content: 'Default template for all users.',
          variables: const {},
          isSystem: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(const _NoOpLogger()),
        analyticsProvider.overrideWithValue(_StubAnalyticsService()),
        _testNotesRepositoryProvider.overrideWithValue(notesRepository),
        _testTaskRepositoryProvider.overrideWithValue(taskRepository),
        _testFolderRepositoryProvider.overrideWithValue(folderRepository),
        _testTemplateRepositoryProvider.overrideWithValue(templateRepository),
      ],
    );

    final noteIndexer = container.read(_testNoteIndexerProvider);
    await noteIndexer.clearIndex();
    for (final note in notesRepository.userVisibleNotes) {
      await noteIndexer.indexNote(note);
    }

    service = container.read(_testUnifiedSearchServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'search returns only current user notes and supports tag filters',
    () async {
      final options = SearchOptions(
        types: const [SearchResultType.note],
        tags: const ['space'],
      );

      final results = await service.search('Mercury', options: options);
      final noteIds = results
          .where((r) => r.type == SearchResultType.note)
          .map((r) => (r.data as Note).id);

      expect(noteIds, contains('note-mercury'));
      expect(noteIds, isNot(contains('note-other')));
    },
  );

  test(
    'search aggregates folder and template results without leaking other tenants',
    () async {
      final options = SearchOptions(
        types: const [SearchResultType.folder, SearchResultType.template],
      );

      final results = await service.search('Mercury', options: options);

      final folderResults = results
          .where((r) => r.type == SearchResultType.folder)
          .toList();
      final templateResults = results
          .where((r) => r.type == SearchResultType.template)
          .toList();

      expect(folderResults, hasLength(1));
      expect((folderResults.first.data as Folder).id, equals('folder-mercury'));

      expect(templateResults, hasLength(1));
      expect(
        (templateResults.first.data as Template).id,
        equals('tmpl-mercury'),
      );
    },
  );

  test('task search scopes to notes owned by the current user', () async {
    final options = SearchOptions(types: const [SearchResultType.task]);

    final results = await service.search('checklist', options: options);
    final taskIds = results
        .where((r) => r.type == SearchResultType.task)
        .map((r) => (r.data as Task).id);

    expect(taskIds, contains('task-review'));
    expect(taskIds, isNot(contains('task-other')));
  });
}

class InMemoryNotesRepository implements INotesRepository {
  InMemoryNotesRepository({required this.userId, required List<Note> notes})
    : _notes = List.unmodifiable(notes);

  final String userId;
  final List<Note> _notes;

  List<Note> get userVisibleNotes =>
      _notes.where((note) => note.userId == userId && !note.deleted).toList();

  @override
  Future<Note?> getNoteById(String id) async {
    for (final note in userVisibleNotes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<List<Note>> localNotesForSync() async => userVisibleNotes;

  @override
  Future<List<Note>> localNotes() async => userVisibleNotes;

  @override
  Future<void> deleteNote(String id) => throw UnimplementedError();

  @override
  Future<void> restoreNote(String id) => throw UnimplementedError();

  @override
  Future<DateTime?> getLastSyncTime() => throw UnimplementedError();

  @override
  Future<List<Note>> getPinnedNotes() => throw UnimplementedError();

  @override
  Future<List<Note>> getRecentlyViewedNotes({int limit = 5}) =>
      throw UnimplementedError();

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<int> getNotesCountInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<List<Note>> list({int? limit}) => throw UnimplementedError();

  @override
  Future<List<Note>> listAfter(DateTime? cursor, {int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<void> pullSince(DateTime? since) => throw UnimplementedError();

  @override
  Future<void> pushAllPending() => throw UnimplementedError();

  @override
  Future<void> setNotePin(String noteId, bool isPinned) =>
      throw UnimplementedError();

  @override
  Future<void> sync() => throw UnimplementedError();

  @override
  Future<void> toggleNotePin(String noteId) => throw UnimplementedError();

  @override
  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    String? folderId,
    bool updateFolder = false,
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadata,
    List<Map<String, String?>>? links,
    bool? isPinned,
    DateTime? updatedAt,
  }) => throw UnimplementedError();

  @override
  Future<Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => throw UnimplementedError();

  @override
  Stream<List<Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) => const Stream.empty();

  @override
  Future<void> permanentlyDeleteNote(String id) async {}

  @override
  Future<List<Note>> getDeletedNotes() async => [];

  @override
  Future<int> anonymizeAllNotesForUser(String userId) async => 0;
}

class InMemoryTaskRepository implements ITaskRepository {
  InMemoryTaskRepository({
    required this.allowedNoteIds,
    required List<Task> tasks,
  }) : _tasks = List.unmodifiable(tasks);

  final Set<String> allowedNoteIds;
  final List<Task> _tasks;

  @override
  Future<List<Task>> searchTasks(String query) async {
    final normalizedQuery = query.toLowerCase();
    return _tasks.where((task) {
      if (!allowedNoteIds.contains(task.noteId)) return false;
      final titleMatch = task.title.toLowerCase().contains(normalizedQuery);
      final descriptionMatch =
          task.description?.toLowerCase().contains(normalizedQuery) ?? false;
      return titleMatch || descriptionMatch;
    }).toList();
  }

  @override
  Future<List<Task>> getAllTasks() => throw UnimplementedError();

  @override
  Future<Task> createTask(Task task) => throw UnimplementedError();

  @override
  Future<void> deleteTask(String id) => throw UnimplementedError();

  @override
  Future<List<Task>> getCompletedTasks({int? limit, DateTime? since}) =>
      throw UnimplementedError();

  @override
  Future<Task?> getTaskById(String id) => throw UnimplementedError();

  @override
  Future<List<Task>> getTasksByDateRange({
    required DateTime start,
    required DateTime end,
  }) => throw UnimplementedError();

  @override
  Future<List<Task>> getTasksByPriority(TaskPriority priority) =>
      throw UnimplementedError();

  @override
  Future<List<Task>> getTasksForNote(String noteId) =>
      throw UnimplementedError();

  @override
  Future<List<Task>> getPendingTasks() => throw UnimplementedError();

  @override
  Future<List<Task>> getOverdueTasks() => throw UnimplementedError();

  @override
  Future<Task> updateTask(Task task) => throw UnimplementedError();

  @override
  Future<void> completeTask(String id) => throw UnimplementedError();

  @override
  Future<void> deleteTasksForNote(String noteId) => throw UnimplementedError();

  @override
  Future<void> toggleTaskStatus(String id) => throw UnimplementedError();

  @override
  Future<void> updateTaskDueDate(String id, DateTime? dueDate) =>
      throw UnimplementedError();

  @override
  Future<void> updateTaskPriority(String id, TaskPriority priority) =>
      throw UnimplementedError();

  @override
  Future<Map<String, int>> getTaskStatistics() => throw UnimplementedError();

  @override
  Future<Task> createSubtask({
    required String parentTaskId,
    required String title,
    String? description,
  }) => throw UnimplementedError();

  @override
  Future<List<Task>> getSubtasks(String parentTaskId) =>
      throw UnimplementedError();

  @override
  Future<void> addTagToTask(String taskId, String tag) =>
      throw UnimplementedError();

  @override
  Future<void> removeTagFromTask(String taskId, String tag) =>
      throw UnimplementedError();

  @override
  Future<void> syncTasksWithNoteContent(String noteId, String noteContent) =>
      throw UnimplementedError();

  @override
  Stream<List<Task>> watchAllTasks() => const Stream.empty();

  @override
  Stream<List<Task>> watchTasks() => const Stream.empty();

  @override
  Stream<List<Task>> watchTasksForNote(String noteId) => const Stream.empty();

  @override
  Future<List<Task>> getDeletedTasks() async => const [];

  @override
  Future<void> restoreTask(String id) async {}

  @override
  Future<void> permanentlyDeleteTask(String id) async {}

  @override
  Future<void> updateTaskReminderLink({
    required String taskId,
    required String? reminderId,
  }) async {}

  @override
  Future<void> updateTaskPositions(Map<String, int> positions) async {}

  @override
  Future<int> anonymizeAllTasksForUser(String userId) async => 0;
}

class InMemoryFolderRepository implements IFolderRepository {
  InMemoryFolderRepository({
    required this.userId,
    required List<Folder> folders,
  }) : _folders = List.unmodifiable(folders);

  final String userId;
  final List<Folder> _folders;

  @override
  Future<List<Folder>> listFolders() async =>
      _folders.where((folder) => folder.userId == userId).toList();

  @override
  String? getCurrentUserId() => userId;

  @override
  Future<Folder?> getFolder(String id) => throw UnimplementedError();

  @override
  Future<List<Folder>> getRootFolders() => throw UnimplementedError();

  @override
  Future<Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) => throw UnimplementedError();

  @override
  Future<List<Folder>> getDeletedFolders() async => const [];

  @override
  Future<void> restoreFolder(String folderId, {bool restoreContents = false}) async {}

  @override
  Future<void> permanentlyDeleteFolder(String folderId) async {}

  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) => throw UnimplementedError();

  @override
  Future<void> renameFolder(String folderId, String newName) =>
      throw UnimplementedError();

  @override
  Future<void> moveFolder(String folderId, String? newParentId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteFolder(String folderId) => throw UnimplementedError();

  @override
  Future<List<Note>> getNotesInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<List<Note>> getUnfiledNotes() => throw UnimplementedError();

  @override
  Future<void> addNoteToFolder(String noteId, String folderId) =>
      throw UnimplementedError();

  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) =>
      throw UnimplementedError();

  @override
  Future<void> removeNoteFromFolder(String noteId) =>
      throw UnimplementedError();

  @override
  Future<Map<String, int>> getFolderNoteCounts() => throw UnimplementedError();

  @override
  Future<Folder?> getFolderForNote(String noteId) => throw UnimplementedError();

  @override
  Future<List<Folder>> getChildFolders(String parentId) =>
      throw UnimplementedError();

  @override
  Future<List<Folder>> getChildFoldersRecursive(String parentId) =>
      throw UnimplementedError();

  @override
  Future<Folder?> findFolderByName(String name) => throw UnimplementedError();

  @override
  Future<int> getFolderDepth(String folderId) => throw UnimplementedError();

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<int> getNotesCountInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<void> ensureFolderIntegrity() => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() =>
      throw UnimplementedError();

  @override
  Future<void> validateAndRepairFolderStructure() => throw UnimplementedError();

  @override
  Future<void> cleanupOrphanedRelationships() => throw UnimplementedError();

  @override
  Future<void> resolveFolderConflicts() => throw UnimplementedError();

  @override
  Future<int> anonymizeAllFoldersForUser(String userId) async => 0;
}

class InMemoryTemplateRepository implements ITemplateRepository {
  InMemoryTemplateRepository({required List<Template> templates})
    : _templates = List.unmodifiable(templates);

  final List<Template> _templates;

  @override
  Future<List<Template>> getAllTemplates() async =>
      _templates.where((template) => !template.isSystem).toList();

  @override
  Future<Template> createTemplate(Template template) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTemplate(String id) => throw UnimplementedError();

  @override
  Future<Template?> getTemplateById(String id) => throw UnimplementedError();

  @override
  Future<List<Template>> getSystemTemplates() => throw UnimplementedError();

  @override
  Future<List<Template>> getUserTemplates() => throw UnimplementedError();

  @override
  Stream<List<Template>> watchTemplates() => const Stream.empty();

  @override
  Future<String> applyTemplate({
    required String templateId,
    required Map<String, dynamic> variableValues,
  }) => throw UnimplementedError();

  @override
  Future<Template> duplicateTemplate({
    required String templateId,
    required String newName,
  }) => throw UnimplementedError();

  @override
  Future<Template> updateTemplate(Template template) =>
      throw UnimplementedError();
}

class _NoOpLogger implements AppLogger {
  const _NoOpLogger();

  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}

  @override
  void debug(String message, {Map<String, dynamic>? data}) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}

  @override
  Future<void> flush() async {}

  @override
  void info(String message, {Map<String, dynamic>? data}) {}

  @override
  void warn(String message, {Map<String, dynamic>? data}) {}

  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
}

class _StubAnalyticsService extends AnalyticsService {
  final List<Map<String, dynamic>> recordedEvents = [];

  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    recordedEvents.add({
      'name': name,
      'properties': properties ?? const <String, dynamic>{},
    });
  }
}
