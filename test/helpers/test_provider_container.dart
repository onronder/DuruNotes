/* COMMENTED OUT - 4 errors
 * This file uses old models/APIs. Needs rewrite.
 */

/*
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for common test dependencies
@GenerateNiceMocks([
  MockSpec<AppDb>(),
  MockSpec<AppLogger>(),
  MockSpec<AnalyticsService>(),
  MockSpec<INotesRepository>(),
  MockSpec<IFolderRepository>(),
  MockSpec<ITaskRepository>(),
  MockSpec<ITemplateRepository>(),
  MockSpec<TaskReminderBridge>(),
])
import 'test_provider_container.mocks.dart';

/// Production-grade test provider container with centralized mock management
///
/// Features:
/// - Consistent mock injection across all tests
/// - Proper provider overrides
/// - Dummy value registration for Mockito
/// - Lifecycle management
/// - Type-safe mock access
///
/// Usage:
/// ```dart
/// late TestProviderContainer testContainer;
///
/// setUp(() {
///   testContainer = TestProviderContainer.create();
/// });
///
/// tearDown(() {
///   testContainer.dispose();
/// });
///
/// test('my test', () {
///   final mockDb = testContainer.mockDb;
///   when(mockDb.allNotes()).thenAnswer((_) async => []);
///
///   final result = testContainer.container.read(myProvider);
///   // assertions...
/// });
/// ```
class TestProviderContainer {
  final ProviderContainer container;

  // Core dependencies
  final MockAppDb mockDb;
  final MockAppLogger mockLogger;
  final MockAnalyticsService mockAnalytics;

  // Repository mocks
  final MockINotesRepository mockNotesRepo;
  final MockIFolderRepository mockFolderRepo;
  final MockITaskRepository mockTaskRepo;
  final MockITemplateRepository mockTemplateRepo;

  // Service mocks
  final MockTaskReminderBridge mockTaskBridge;

  TestProviderContainer._({
    required this.container,
    required this.mockDb,
    required this.mockLogger,
    required this.mockAnalytics,
    required this.mockNotesRepo,
    required this.mockFolderRepo,
    required this.mockTaskRepo,
    required this.mockTemplateRepo,
    required this.mockTaskBridge,
  });

  /// Create a new test container with all mocks initialized
  ///
  /// Automatically:
  /// - Creates all necessary mocks
  /// - Registers dummy providers for Mockito
  /// - Overrides providers with mocks
  /// - Sets up proper lifecycle management
  factory TestProviderContainer.create({
    List<Override>? additionalOverrides,
  }) {
    // Create all mocks
    final mockDb = MockAppDb();
    final mockLogger = MockAppLogger();
    final mockAnalytics = MockAnalyticsService();
    final mockNotesRepo = MockINotesRepository();
    final mockFolderRepo = MockIFolderRepository();
    final mockTaskRepo = MockITaskRepository();
    final mockTemplateRepo = MockITemplateRepository();
    final mockTaskBridge = MockTaskReminderBridge();

    // Register dummy values for Mockito
    // This fixes "MissingDummyValueError" issues
    provideDummy<AppLogger>(mockLogger);
    provideDummy<AnalyticsService>(mockAnalytics);
    provideDummy<AppDb>(mockDb);
    provideDummy<INotesRepository>(mockNotesRepo);
    provideDummy<IFolderRepository>(mockFolderRepo);
    provideDummy<ITaskRepository>(mockTaskRepo);
    provideDummy<ITemplateRepository>(mockTemplateRepo);
    provideDummy<TaskReminderBridge>(mockTaskBridge);

    // Create provider overrides
    final overrides = <Override>[
      appDbProvider.overrideWithValue(mockDb),
      loggerProvider.overrideWithValue(mockLogger),
      analyticsProvider.overrideWithValue(mockAnalytics),
      notesRepositoryProvider.overrideWithValue(mockNotesRepo),
      folderRepositoryProvider.overrideWithValue(mockFolderRepo),
      taskRepositoryProvider.overrideWithValue(mockTaskRepo),
      templateRepositoryProvider.overrideWithValue(mockTemplateRepo),
      // Add additional overrides if provided
      ...?additionalOverrides,
    ];

    final container = ProviderContainer(overrides: overrides);

    return TestProviderContainer._(
      container: container,
      mockDb: mockDb,
      mockLogger: mockLogger,
      mockAnalytics: mockAnalytics,
      mockNotesRepo: mockNotesRepo,
      mockFolderRepo: mockFolderRepo,
      mockTaskRepo: mockTaskRepo,
      mockTemplateRepo: mockTemplateRepo,
      mockTaskBridge: mockTaskBridge,
    );
  }

  /// Reset all mocks to their initial state
  ///
  /// Call this in tearDown() or between tests to prevent
  /// "Verification appears to be in progress" errors
  void resetMocks() {
    reset(mockDb);
    reset(mockLogger);
    reset(mockAnalytics);
    reset(mockNotesRepo);
    reset(mockFolderRepo);
    reset(mockTaskRepo);
    reset(mockTemplateRepo);
    reset(mockTaskBridge);
  }

  /// Dispose the container and clean up resources
  ///
  /// Always call this in tearDown() to prevent memory leaks
  void dispose() {
    resetMocks();
    container.dispose();
  }

  /// Read a provider value
  ///
  /// Convenience method to avoid writing testContainer.container.read()
  T read<T>(ProviderListenable<T> provider) {
    return container.read(provider);
  }
}

/// Fake implementations for simple types that don't need full mocking

class FakeAppLogger extends Fake implements AppLogger {
  @override
  void info(String message, {Map<String, dynamic>? data}) {
    // No-op in tests
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    // No-op in tests
  }

  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {
    // No-op in tests
  }

  @override
  void warning(String message, {Map<String, dynamic>? data}) {
    // No-op in tests
  }
}

class FakeAnalyticsService extends Fake implements AnalyticsService {
  @override
  void event(String eventName, {Map<String, dynamic>? properties}) {
    // No-op in tests
  }

  @override
  void trackError(String error, {String? context, Map<String, dynamic>? properties}) {
    // No-op in tests
  }
}
*/
