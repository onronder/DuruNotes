import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:duru_notes/providers.dart' show notesCoreRepositoryProvider;
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/services/unified_task_service.dart' as unified;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for watching tasks for a specific note
final noteTasksProvider =
    StreamProvider.family<List<NoteTask>, String>((ref, noteId) {
  final taskService = ref.watch(taskServiceProvider);
  return taskService.watchTasksForNote(noteId);
});

/// Provider for getting a specific task by ID
final taskByIdProvider =
    FutureProvider.family<NoteTask?, String>((ref, taskId) async {
  final db = ref.watch(appDbProvider);
  return db.getTaskById(taskId);
});

/// Task reminder bridge provider with feature flag support
final taskReminderBridgeProvider = Provider<TaskReminderBridge>((ref) {
  // Use the unified reminder coordinator
  // We'll need to import this from reminders module
  final reminderCoordinator = null; // ref.watch(unifiedReminderCoordinatorProvider);

  // We'll need to import this from reminders module
  final advancedReminderService = null; // ref.watch(advancedReminderServiceProvider);
  final taskService = ref.watch(taskServiceProvider);
  final database = ref.watch(appDbProvider);
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  final bridge = TaskReminderBridge(
    ref,
    reminderCoordinator: reminderCoordinator,
    advancedReminderService: advancedReminderService as AdvancedReminderService,
    taskService: taskService,
    taskRepository: ref.read(taskCoreRepositoryProvider),
    notificationPlugin: notificationPlugin,
  );

  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Enhanced task service provider with reminder integration
final enhancedTaskServiceProvider = Provider<EnhancedTaskService>((ref) {
  final database = ref.watch(appDbProvider);
  final reminderBridge = ref.watch(taskReminderBridgeProvider);

  final service = EnhancedTaskService(
    database: database,
    reminderBridge: reminderBridge,
  );

  // Note: Bidirectional sync is now handled by UnifiedTaskService

  return service;
});

/// Task analytics service provider
final taskAnalyticsServiceProvider = Provider<TaskAnalyticsService>((ref) {
  final database = ref.watch(appDbProvider);
  return TaskAnalyticsService(ref, database: database);
});

/// Productivity goals service provider
final productivityGoalsServiceProvider =
    Provider<ProductivityGoalsService>((ref) {
  final database = ref.watch(appDbProvider);
  final analyticsService = ref.watch(taskAnalyticsServiceProvider);

  final service = ProductivityGoalsService(
    taskRepository: ref.read(taskCoreRepositoryProvider),
    analyticsService: analyticsService,
  );

  // Dispose the service when provider is disposed to prevent memory leaks
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for active productivity goals
final activeGoalsProvider =
    StreamProvider<List<ProductivityGoal>>((ref) async* {
  final goalsService = ref.watch(productivityGoalsServiceProvider);

  // Initial load
  yield await goalsService.getActiveGoals();

  // Update every minute to refresh progress
  yield* Stream.periodic(const Duration(minutes: 1), (_) async {
    await goalsService.updateAllGoalProgress();
    return goalsService.getActiveGoals();
  }).asyncMap((future) => future);
});

/// Provider for the unified task service that consolidates all task functionality
final unifiedTaskServiceProvider = Provider<unified.UnifiedTaskService>((ref) {
  final db = ref.watch(appDbProvider);
  final logger = LoggerFactory.instance;
  final analytics = AnalyticsFactory.instance;

  // Create enhanced task service internally to avoid circular dependency
  // Use a lazy approach to prevent initialization loops
  final reminderBridge = ref.watch(taskReminderBridgeProvider);

  late final EnhancedTaskService enhancedService;
  late final unified.UnifiedTaskService service;

  // Initialize enhanced service after unified service is created
  enhancedService = EnhancedTaskService(
    database: db,
    reminderBridge: reminderBridge,
  );

  service = unified.UnifiedTaskService(
    taskRepository: ref.read(taskCoreRepositoryProvider),
    notesRepository: ref.read(notesCoreRepositoryProvider),
    logger: logger,
    analytics: analytics,
    enhancedTaskService: enhancedService,
  );

  // CRITICAL: Dispose the service when provider is disposed to prevent memory leaks
  ref.onDispose(() {
    try {
      service.dispose();
    } catch (e) {
      logger.error('Error disposing UnifiedTaskService', error: e);
    }
  });

  return service;
});

/// Provider for task updates stream
final unifiedTaskUpdatesProvider = StreamProvider<unified.TaskUpdate>((ref) {
  final service = ref.watch(unifiedTaskServiceProvider);
  return service.taskUpdates;
});

/// Provider for tasks by note using unified service
final unifiedTasksForNoteProvider =
    FutureProvider.family<List<NoteTask>, String>((ref, noteId) {
  final service = ref.watch(unifiedTaskServiceProvider);
  return service.getTasksForNote(noteId);
});

/// Provider for task statistics using unified service
final unifiedTaskStatisticsProvider = FutureProvider<unified.TaskStatistics>((ref) {
  final service = ref.watch(unifiedTaskServiceProvider);

  // Refresh when task updates occur
  ref.watch(unifiedTaskUpdatesProvider);

  return service.getTaskStatistics();
});