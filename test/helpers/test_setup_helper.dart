/* COMMENTED OUT - 11 errors - uses old APIs
 * This class uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_setup_helper.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AppLogger>(),
  MockSpec<AppDb>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<SharedPreferences>(),
])
class TestSetupHelper {
  /// Initialize test environment with all necessary bindings and mocks
  static Future<void> initializeTestEnvironment() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Set up shared preferences mock
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase with test configuration
    await _initializeSupabase();
  }

  /// Initialize Supabase for testing
  static Future<void> _initializeSupabase() async {
    try {
      // Check if already initialized by trying to access instance
      Supabase.instance.client;
      return;
    } catch (_) {
      // Not initialized, proceed with initialization
    }

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  }

  /// Create a test provider container with common overrides
  static ProviderContainer createTestContainer({
    List<Override>? additionalOverrides,
  }) {
    final mockLogger = createMockLogger();
    final mockDb = createMockDatabase();

    final overrides = [
      loggerProvider.overrideWithValue(mockLogger),
      appDbProvider.overrideWithValue(mockDb),
      ...?additionalOverrides,
    ];

    return ProviderContainer(overrides: overrides);
  }

  /// Create a mock logger with default behavior
  static MockAppLogger createMockLogger() {
    final mock = MockAppLogger();

    // Set up default behavior for new AppLogger interface
    when(mock.info(any, data: anyNamed('data'))).thenReturn(null);
    when(mock.debug(any, data: anyNamed('data'))).thenReturn(null);
    when(mock.warning(any, data: anyNamed('data'))).thenReturn(null);
    when(mock.error(any, error: anyNamed('error'), stackTrace: anyNamed('stackTrace'), data: anyNamed('data'))).thenReturn(null);

    return mock;
  }

  /// Create a mock database with default behavior
  static MockAppDb createMockDatabase() {
    final mock = MockAppDb();

    // Set up default behavior for common methods
    // Note: Since AppDb methods are integrated, we mock them directly
    // when(mock.getAllNotes()).thenAnswer((_) async => []);
    // when(mock.getAllTasks()).thenAnswer((_) async => []);
    // when(mock.getAllFolders()).thenAnswer((_) async => []);
    when(mock.close()).thenAnswer((_) async => {});

    return mock;
  }

  /// Create a mock Supabase client
  static MockSupabaseClient createMockSupabaseClient() {
    final mock = MockSupabaseClient();
    final mockAuth = MockGoTrueClient();
    final mockUser = MockUser();

    when(mockUser.id).thenReturn('test-user-id');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mock.auth).thenReturn(mockAuth);

    return mock;
  }

  /// Create a test widget with provider scope
  static Widget createTestWidget({
    required Widget child,
    List<Override>? overrides,
  }) {
    return ProviderScope(
      overrides: overrides ?? [],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  /// Run a test with proper setup and teardown
  static Future<void> runTestWithSetup(
    String description,
    Future<void> Function(WidgetTester tester, ProviderContainer container) testBody, {
    List<Override>? overrides,
  }) async {
    testWidgets(description, (tester) async {
      await initializeTestEnvironment();

      final container = createTestContainer(additionalOverrides: overrides);

      try {
        await testBody(tester, container);
      } finally {
        container.dispose();
      }
    });
  }

  /// Pump and settle with timeout protection
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        timeout,
      );
    } on FlutterError catch (e) {
      // If pump and settle times out, just pump once more
      await tester.pump();
      debugPrint('PumpAndSettle timeout: $e');
    }
  }

  /// Create test data generators
}

/// Test data generator class
class TestDataGenerator {
    static LocalNote createLocalNote({
      String? id,
      String? title,
      String? body,
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final now = DateTime.now();
      return LocalNote(
        id: id ?? 'test-note-${now.millisecondsSinceEpoch}',
        title: title ?? 'Test Note',
        body: body ?? 'Test content',
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'test-user-id',
        encryptionVersion: 0,
      );
    }

    static NoteTask createNoteTask({
      String? id,
      String? noteId,
      String? content,
      TaskStatus? status,
      TaskPriority? priority,
      DateTime? dueDate,
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final now = DateTime.now();
      return NoteTask(
        id: id ?? 'test-task-${now.millisecondsSinceEpoch}',
        noteId: noteId ?? 'test-note-1',
        content: content ?? 'Test Task',
        status: status ?? TaskStatus.open,
        priority: priority ?? TaskPriority.medium,
        position: 0,
        contentHash: 'test-hash',
        dueDate: dueDate,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
        deleted: false,
        encryptionVersion: 0,
      );
    }

    static LocalFolder createLocalFolder({
      String? id,
      String? name,
      String? parentId,
      String? color,
      String? icon,
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final now = DateTime.now();
      return LocalFolder(
        id: id ?? 'test-folder-${now.millisecondsSinceEpoch}',
        name: name ?? 'Test Folder',
        parentId: parentId,
        color: color ?? '#FF0000',
        icon: icon ?? '📁',
        description: '',
        sortOrder: 0,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
        deleted: false,
        path: parentId != null ? '/$parentId/' : '/',
      );
    }
}

// TestLocalStorage removed - no longer needed with current Supabase API

/// Common test assertions
class TestAssertions {
  /// Assert that a widget exists in the tree
  static void widgetExists(WidgetTester tester, Type widgetType) {
    expect(find.byType(widgetType), findsOneWidget,
        reason: '$widgetType should exist in the widget tree');
  }

  /// Assert that text exists in the tree
  static void textExists(WidgetTester tester, String text) {
    expect(find.text(text), findsOneWidget,
        reason: 'Text "$text" should exist in the widget tree');
  }

  /// Assert that a widget does not exist in the tree
  static void widgetDoesNotExist(WidgetTester tester, Type widgetType) {
    expect(find.byType(widgetType), findsNothing,
        reason: '$widgetType should not exist in the widget tree');
  }

  /// Assert that an async operation completes successfully
  static Future<void> asyncCompletes(Future<void> operation) async {
    await expectLater(operation, completes,
        reason: 'Async operation should complete without throwing');
  }

  /// Assert that an async operation throws an error
  static Future<void> asyncThrows<T extends Object>(Future<void> operation) async {
    await expectLater(operation, throwsA(isA<T>()),
        reason: 'Async operation should throw ${T.toString()}');
  }
}

/// Test matchers for custom types - using direct property access instead of reflection
class CustomMatchers {
  /// Matcher for checking if a LocalNote has expected properties
  static Matcher isLocalNoteWith({
    String? id,
    String? title,
    String? body,
    bool? isPinned,
    bool? deleted,
  }) {
    return predicate<LocalNote>((note) {
      if (id != null && note.id != id) return false;
      if (title != null && note.title != title) return false;
      if (body != null && note.body != body) return false;
      if (isPinned != null && note.isPinned != isPinned) return false;
      if (deleted != null && note.deleted != deleted) return false;
      return true;
    }, 'matches LocalNote with expected properties');
  }

  /// Matcher for checking if a NoteTask has expected properties
  static Matcher isNoteTaskWith({
    String? id,
    String? noteId,
    String? content,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
  }) {
    return predicate<NoteTask>((task) {
      if (id != null && task.id != id) return false;
      if (noteId != null && task.noteId != noteId) return false;
      if (content != null && task.content != content) return false;
      if (status != null && task.status != status) return false;
      if (priority != null && task.priority != priority) return false;
      if (dueDate != null && task.dueDate != dueDate) return false;
      return true;
    }, 'matches NoteTask with expected properties');
  }
}*/