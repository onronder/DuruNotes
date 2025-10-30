/// Comprehensive test helper that provides a complete testing environment
///
/// This helper combines:
/// - Platform channel mocks
/// - Provider container setup
/// - Database initialization
/// - Supabase mock configuration
library;

// import 'test_data_builders.dart'; // TODO: Create this file or remove builder references
/// - Test data builders
///
/// Example usage:
/// ```dart
/// void main() {
/* COMMENTED OUT - 16 errors - old test helper utilities
   * This test uses old models/APIs that no longer exist after domain migration.
   * Needs complete rewrite to use new domain models and architecture.
   *
   * TODO: Rewrite test for new architecture
   */

/*
///   late TestEnvironment env;
///
///   setUpAll(() async {
///     env = await TestEnvironment.setUp();
///   });
///
///   tearDown(() async {
///     await env.tearDown();
///   });
///
///   test('my test', () async {
///     final note = env.builders.note()
///       .withTitle('Test Note')
///       .build();
///
///     when(env.mocks.notesRepo.create(any))
///       .thenAnswer((_) async => note);
///
///     final result = await env.container.read(notesProvider);
///     expect(result, isNotNull);
///   });
/// }
/// ```
class TestEnvironment {
  final TestProviderContainer container;
  final AppDb database;
  // final TestDataBuilders builders; // TODO: Implement builders
  final TestMocks mocks;
  final supabase.SupabaseClient? supabaseClient;

  TestEnvironment._({
    required this.container,
    required this.database,
    // required this.builders,
    required this.mocks,
    this.supabaseClient,
  });

  /// Set up a complete test environment
  static Future<TestEnvironment> setUp({
    bool initSupabase = false,
    List<Override>? additionalOverrides,
    Map<String, dynamic>? sharedPrefsValues,
  }) async {
    // Initialize platform mocks
    PlatformMocks.setup();

    // Set up SharedPreferences with custom values
    final defaultValues = <String, dynamic>{
      'user_id': 'test-user-123',
      'theme_mode': 'light',
      'locale': 'en',
      'encryption_enabled': false,
      ...?sharedPrefsValues,
    };
    SharedPreferences.setMockInitialValues(defaultValues);

    // Initialize Supabase if needed
    supabase.SupabaseClient? supabaseClient;
    if (initSupabase) {
      try {
        await supabase.Supabase.initialize(
          url: 'https://test.supabase.co',
          anonKey: 'test-anon-key',
          debug: false,
        );
        supabaseClient = supabase.Supabase.instance.client;
      } catch (e) {
        // Supabase may already be initialized
        if (e.toString().contains('already initialized')) {
          supabaseClient = supabase.Supabase.instance.client;
        }
      }
    }

    // Create in-memory database
    final database = AppDb();

    // Create provider container with mocks
    final container = TestProviderContainer.create(
      additionalOverrides: additionalOverrides,
    );

    // Create test data builders
    // final builders = TestDataBuilders(); // TODO: Implement builders

    // Create mocks wrapper for easy access
    final mocks = TestMocks(
      db: container.mockDb,
      logger: container.mockLogger,
      analytics: container.mockAnalytics,
      notesRepo: container.mockNotesRepo,
      folderRepo: container.mockFolderRepo,
      taskRepo: container.mockTaskRepo,
      templateRepo: container.mockTemplateRepo,
      taskBridge: container.mockTaskBridge,
    );

    return TestEnvironment._(
      container: container,
      database: database,
      // builders: builders,
      mocks: mocks,
      supabaseClient: supabaseClient,
    );
  }

  /// Tear down the test environment
  Future<void> tearDown() async {
    container.resetMocks();
    container.dispose();
    await database.close();
  }

  /// Run a test within a provider scope
  Future<T> runScoped<T>(Future<T> Function(ProviderContainer container) callback) async {
    return await callback(container.container);
  }

  /// Create a widget with provider scope for widget testing
  Widget wrapWithProviders(Widget child) {
    return UncontrolledProviderScope(
      container: container.container,
      child: child,
    );
  }
}

/// Convenient access to all mocks in one place
class TestMocks {
  final MockAppDb db;
  final MockAppLogger logger;
  final MockAnalyticsService analytics;
  final MockINotesRepository notesRepo;
  final MockIFolderRepository folderRepo;
  final MockITaskRepository taskRepo;
  final MockITemplateRepository templateRepo;
  final MockTaskReminderBridge taskBridge;

  TestMocks({
    required this.db,
    required this.logger,
    required this.analytics,
    required this.notesRepo,
    required this.folderRepo,
    required this.taskRepo,
    required this.templateRepo,
    required this.taskBridge,
  });

  /// Reset all mocks
  void resetAll() {
    reset(db);
    reset(logger);
    reset(analytics);
    reset(notesRepo);
    reset(folderRepo);
    reset(taskRepo);
    reset(templateRepo);
    reset(taskBridge);
  }

  /// Setup common stub behaviors
  void setupDefaults() {
    // Logger defaults (no-op)
    when(logger.info(any, data: anyNamed('data')))
        .thenReturn(null);
    when(logger.error(any, error: anyNamed('error'), stackTrace: anyNamed('stackTrace'), data: anyNamed('data')))
        .thenReturn(null);
    when(logger.warning(any, data: anyNamed('data')))
        .thenReturn(null);
    when(logger.breadcrumb(any, data: anyNamed('data')))
        .thenReturn(null);

    // Analytics defaults (no-op)
    when(analytics.event(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(analytics.trackError(any, context: anyNamed('context'), properties: anyNamed('properties')))
        .thenReturn(null);

    // Database defaults
    when(db.managers).thenReturn(DriftDatabaseManagers(db));
  }
}

/// Test data builders wrapper
// TODO: Implement test data builders
// class TestDataBuilders {
//   NoteBuilder note() => NoteBuilder();
//   TaskBuilder task() => TaskBuilder();
//   FolderBuilder folder() => FolderBuilder();
//   UserBuilder user() => UserBuilder();
//   AttachmentBuilder attachment() => AttachmentBuilder();
//   TagBuilder tag() => TagBuilder();
//   ReminderBuilder reminder() => ReminderBuilder();
//   TemplateBuilder template() => TemplateBuilder();
// }

// Extension methods for common test patterns
extension TestWidgetTesterExtensions on WidgetTester {
  /// Pump a widget wrapped with test providers
  Future<void> pumpTestWidget(
    Widget widget,
    TestEnvironment env, {
    Duration? duration,
  }) async {
    await pumpWidget(
      env.wrapWithProviders(widget),
      duration,
    );
  }

  /// Pump and settle a widget wrapped with test providers
  Future<void> pumpAndSettleTestWidget(
    Widget widget,
    TestEnvironment env, {
    Duration duration = const Duration(milliseconds: 100),
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    await pumpWidget(env.wrapWithProviders(widget));
    await pumpAndSettle(duration, phase, timeout);
  }
}

// Common test matchers
final isUuid = matches(RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
));

final isIsoDateTime = matches(RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$'
));

final isEncryptedString = matches(RegExp(
  r'^[A-Za-z0-9+/]+=*$'
));

// Test utilities
class TestUtils {
  /// Wait for async operations to complete
  static Future<void> waitForAsync({
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await Future.delayed(duration);
  }

  /// Create a future that completes after a delay
  static Future<T> delayedFuture<T>(
    T value, {
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await Future.delayed(duration);
    return value;
  }

  /// Create a future that throws after a delay
  static Future<T> delayedError<T>(
    Object error, {
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await Future.delayed(duration);
    throw error;
  }

  /// Run a function with a timeout
  static Future<T?> runWithTimeout<T>(
    Future<T> Function() fn, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }
}

// Test error classes
class TestException implements Exception {
  final String message;
  TestException(this.message);

  @override
  String toString() => 'TestException: $message';
}

class TestError extends Error {
  final String message;
  TestError(this.message);

  @override
  String toString() => 'TestError: $message';
}
*/
