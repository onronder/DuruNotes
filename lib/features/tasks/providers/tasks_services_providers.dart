import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
// Phase 4: Migrated to organized provider imports
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
// Phase 8: Import provider dependencies for task services
import 'package:duru_notes/providers/unified_reminder_provider.dart'
    show unifiedReminderCoordinatorProvider;
import 'package:duru_notes/services/advanced_reminder_service.dart'
    show advancedReminderServiceProvider;
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for watching tasks for a specific note
/// DEPRECATED: Use domainTasksForNoteProvider for domain tasks
final noteTasksProvider = StreamProvider.autoDispose
    .family<List<NoteTask>, String>((ref, noteId) {
      // Direct database access - TaskService.watchTasksForNote just delegates to DB
      final db = ref.watch(appDbProvider);
      final client = ref.watch(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return const Stream<List<NoteTask>>.empty();
      }
      return db.watchTasksForNote(noteId, userId);
    });

/// Provider for getting a specific task by ID
final taskByIdProvider = FutureProvider.autoDispose.family<NoteTask?, String>((
  ref,
  taskId,
) async {
  final db = ref.watch(appDbProvider);
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    return null;
  }
  return db.getTaskById(taskId, userId: userId);
});

/// Task reminder bridge provider
/// PRODUCTION: Now uses AppDb directly - no longer depends on deprecated TaskService
final taskReminderBridgeProvider = Provider<TaskReminderBridge>((ref) {
  // Use the unified reminder coordinator
  final reminderCoordinator = ref.watch(unifiedReminderCoordinatorProvider);

  final advancedReminderService = ref.watch(advancedReminderServiceProvider);
  final database = ref.watch(appDbProvider);
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  final cryptoBox = ref.watch(cryptoBoxProvider);
  final taskRepository = ref.watch(taskCoreRepositoryProvider);

  final bridge = TaskReminderBridge(
    ref,
    reminderCoordinator: reminderCoordinator,
    advancedReminderService: advancedReminderService,
    database: database,
    notificationPlugin: notificationPlugin,
    cryptoBox: cryptoBox,
    taskRepository: taskRepository,
  );

  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Domain task controller provider (domain-first task operations)
final domainTaskControllerProvider = Provider<DomainTaskController>((ref) {
  final taskRepository = ref.watch(taskCoreRepositoryProvider);
  final notesRepository = ref.watch(notesCoreRepositoryProvider);
  final enhancedService = ref.watch(enhancedTaskServiceProvider);
  final logger = LoggerFactory.instance;

  if (taskRepository == null) {
    throw StateError('DomainTaskController requires authenticated user');
  }

  return DomainTaskController(
    taskRepository: taskRepository,
    notesRepository: notesRepository,
    enhancedTaskService: enhancedService,
    logger: logger,
  );
});

/// Enhanced task service provider with reminder integration
final enhancedTaskServiceProvider = Provider<EnhancedTaskService>((ref) {
  final database = ref.watch(appDbProvider);
  final taskRepository = ref.watch(taskCoreRepositoryProvider);

  // Handle nullable repository - required for enhanced task service
  if (taskRepository == null) {
    throw StateError('EnhancedTaskService requires authenticated user');
  }

  final reminderBridge = ref.watch(taskReminderBridgeProvider);

  final service = EnhancedTaskService(
    database: database,
    taskRepository: taskRepository,
    reminderBridge: reminderBridge,
  );

  return service;
});

/// Task analytics service provider
final taskAnalyticsServiceProvider = Provider<TaskAnalyticsService>((ref) {
  final taskRepository = ref.watch(taskCoreRepositoryProvider);
  return TaskAnalyticsService(ref, taskRepository: taskRepository);
});

/// Productivity goals service provider
final productivityGoalsServiceProvider = Provider<ProductivityGoalsService>((
  ref,
) {
  final database = ref.watch(appDbProvider);
  final analyticsService = ref.watch(taskAnalyticsServiceProvider);

  final service = ProductivityGoalsService(
    database: database,
    analyticsService: analyticsService,
  );

  // Dispose the service when provider is disposed to prevent memory leaks
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for active productivity goals
final activeGoalsProvider = StreamProvider.autoDispose<List<ProductivityGoal>>((
  ref,
) async* {
  final goalsService = ref.watch(productivityGoalsServiceProvider);

  // Initial load
  yield await goalsService.getActiveGoals();

  // Update every minute to refresh progress
  yield* Stream.periodic(const Duration(minutes: 1), (_) async {
    await goalsService.updateAllGoalProgress();
    return goalsService.getActiveGoals();
  }).asyncMap((future) => future);
});
