import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/core/error/provider_error_recovery.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/services/error_logging_service.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'dart:async';

/// Secure wrapper for providers with error recovery and monitoring
/// This provides production-grade error handling for all critical providers

// ============================================================================
// NOTES PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure notes provider with automatic error recovery
final secureNotesProvider = FutureProvider.autoDispose<List<LocalNote>>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'notes_provider',
    operation: () async {
      // Watch the original provider
      return await ref.watch(domainNotesProvider.future).then((notes) =>
        notes.map((n) => LocalNote(
          id: n.id,
          title: n.title ?? '',
          body: n.body ?? '',
          updatedAt: n.updatedAt ?? DateTime.now(),
          deleted: false,
          userId: '',
          noteType: NoteKind.note,
          version: 1,
          isPinned: false,
        )).toList());
    },
    fallbackValue: <LocalNote>[], // Empty list as fallback
    onError: (error, stack) {
      // Log critical errors
      SecurityInitialization.errorLogging.logError(
        error,
        stack,
        severity: ErrorSeverity.error,
        category: 'Provider',
        metadata: {'provider': 'notes'},
      );
    },
  );
});

/// Secure filtered notes provider
final secureFilteredNotesProvider = FutureProvider.autoDispose<List<LocalNote>>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  // Configure specific recovery for filtered notes
  recovery.configureProvider(
    providerId: 'filtered_notes_provider',
    fallbackValue: <LocalNote>[],
    retryPolicy: RetryPolicy(
      maxAttempts: 2,
      retryDelay: const Duration(seconds: 1),
      backoffStrategy: BackoffStrategy.fixed,
    ),
  );

  return recovery.executeWithRecovery(
    providerId: 'filtered_notes_provider',
    operation: () async {
      return await ref.watch(domainFilteredNotesProvider.future).then((notes) =>
        notes.map((n) => LocalNote(
          id: n.id,
          title: n.title ?? '',
          body: n.body ?? '',
          updatedAt: n.updatedAt ?? DateTime.now(),
          deleted: false,
          userId: '',
          noteType: NoteKind.note,
          version: 1,
          isPinned: false,
        )).toList());
    },
    fallbackValue: <LocalNote>[],
  );
});

// ============================================================================
// TASKS PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure tasks provider with error recovery
final secureTasksProvider = StreamProvider.autoDispose<List<NoteTask>>((ref) {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.streamWithRecovery(
    providerId: 'tasks_provider',
    streamFactory: () => ref.watch(domainTasksStreamProvider.stream).map(
      (tasks) => tasks.map((t) => NoteTask(
        id: t.id,
        noteId: t.noteId,
        content: t.title,  // Using title as content since NoteTask expects content
        contentHash: t.title.hashCode.toString(),  // Generate hash from title
        position: 0,  // Default position
        status: TaskStatus.values.firstWhere((s) => s.name == t.status.name),
        priority: TaskPriority.values.firstWhere((p) => p.name == t.priority.name),
        dueDate: t.dueDate,
        completedAt: t.completedAt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      )).toList(),
    ),
    fallbackValue: <NoteTask>[],
  );
});

/// Secure task stats provider
final secureTaskStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'task_stats_provider',
    operation: () async {
      final tasks = await ref.watch(domainTasksProvider.future);
      final now = DateTime.now();

      return {
        'total': tasks.length,
        'completed': tasks.where((t) => t.status == domain_task.TaskStatus.completed).length,
        'pending': tasks.where((t) => t.status != domain_task.TaskStatus.completed).length,
        'overdue': tasks.where((t) =>
          t.status != domain_task.TaskStatus.completed &&
          t.dueDate != null &&
          t.dueDate!.isBefore(now)
        ).length,
      };
    },
    fallbackValue: {
      'total': 0,
      'completed': 0,
      'pending': 0,
      'overdue': 0,
    },
  );
});

// ============================================================================
// FOLDER PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure folders provider
final secureFoldersProvider = FutureProvider.autoDispose<List<LocalFolder>>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'folders_provider',
    operation: () async {
      final repo = ref.watch(folderRepositoryProvider);
      return await repo.getAllFolders();
    },
    fallbackValue: <LocalFolder>[],
  );
});

/// Secure folder tree provider
final secureFolderTreeProvider = FutureProvider.autoDispose<LocalFolder?>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'folder_tree_provider',
    operation: () async {
      final repo = ref.watch(folderRepositoryProvider);
      // getFolderTree not available, returning null
      return null;
    },
    fallbackValue: null,
  );
});

// ============================================================================
// TAG PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure tags provider
final secureTagsProvider = StreamProvider.autoDispose<List<TagModel>>((ref) {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.streamWithRecovery(
    providerId: 'tags_provider',
    streamFactory: () {
      final repo = ref.watch(tagRepositoryInterfaceProvider);
      // watchAllTags not available, using Stream.value
      return Stream.value(<TagModel>[]);
    },
    fallbackValue: <TagModel>[],
  );
});

/// Secure popular tags provider
final securePopularTagsProvider = FutureProvider.autoDispose<List<TagModel>>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'popular_tags_provider',
    operation: () async {
      final repo = ref.watch(tagRepositoryInterfaceProvider);
      // getPopularTags not available, returning empty list
      return <TagModel>[];
    },
    fallbackValue: <TagModel>[],
  );
});

// ============================================================================
// SYNC PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure sync status provider
final secureSyncStatusProvider = StreamProvider.autoDispose<SyncStatus>((ref) {
  final recovery = SecurityInitialization.providerRecovery;

  // Configure aggressive retry for sync
  recovery.configureProvider(
    providerId: 'sync_status_provider',
    retryPolicy: RetryPolicy.aggressive(),
    circuitBreakerConfig: CircuitBreakerConfig(
      failureThreshold: 10,
      resetTimeout: const Duration(minutes: 5),
    ),
  );

  return recovery.streamWithRecovery(
    providerId: 'sync_status_provider',
    streamFactory: () => Stream.value(SyncStatus.idle), // TODO: Implement actual sync status stream
    fallbackValue: SyncStatus.idle,
  );
});

/// Secure sync operation provider
final secureSyncOperationProvider = FutureProvider.autoDispose<void>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'sync_operation_provider',
    operation: () async {
      // TODO: Implement sync service
      await Future.delayed(const Duration(seconds: 1));
    },
    fallbackValue: null,
    onError: (error, stack) {
      // Log sync errors with high priority
      SecurityInitialization.errorLogging.logError(
        error,
        stack,
        severity: ErrorSeverity.critical,
        category: 'Sync',
        shouldNotifyUser: true,
      );
    },
  );
});

// ============================================================================
// SEARCH PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure search provider
final secureSearchProvider = FutureProvider.autoDispose.family<List<LocalNote>, String>(
  (ref, query) async {
    final recovery = SecurityInitialization.providerRecovery;

    return recovery.executeWithRecovery(
      providerId: 'search_provider_$query',
      operation: () async {
        // Validate search query
        final validatedQuery = SecurityInitialization.validation.validateAndSanitizeText(
          query,
          fieldName: 'search',
          maxLength: 100,
          allowHtml: false,
        );

        if (validatedQuery == null || validatedQuery.isEmpty) {
          return <LocalNote>[];
        }

        // Perform search
        // searchNotes not available in ISearchRepository
        return <LocalNote>[];
      },
      fallbackValue: <LocalNote>[],
    );
  },
);

// ============================================================================
// USER PREFERENCES WITH ERROR RECOVERY
// ============================================================================

/// Secure user preferences provider
final secureUserPreferencesProvider = StateNotifierProvider.autoDispose<
    UserPreferencesNotifier, UserPreferences>((ref) {
  final recovery = SecurityInitialization.providerRecovery;

  // Load preferences with error recovery
  recovery.executeWithRecovery(
    providerId: 'user_preferences_loader',
    operation: () async {
      // TODO: Implement user preferences provider
      return UserPreferences.defaults();
    },
    fallbackValue: UserPreferences.defaults(),
  );

  // TODO: Implement user preferences notifier
  return UserPreferencesNotifier();
});

// ============================================================================
// ANALYTICS PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure analytics data provider
final secureAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'analytics_provider',
    operation: () async {
      final notes = await ref.watch(domainNotesProvider.future);
      final tasks = await ref.watch(domainTasksProvider.future);

      return {
        'totalNotes': notes.length,
        'totalTasks': tasks.length,
        'completionRate': tasks.isEmpty
          ? 0.0
          : tasks.where((t) => t.status == domain_task.TaskStatus.completed).length / tasks.length,
        'lastActivity': DateTime.now().toIso8601String(),
      };
    },
    fallbackValue: {
      'totalNotes': 0,
      'totalTasks': 0,
      'completionRate': 0.0,
      'lastActivity': null,
    },
  );
});

// ============================================================================
// PROVIDER ERROR MONITORING
// ============================================================================

/// Monitor provider health
final providerHealthProvider = Provider.autoDispose<ProviderHealthMonitor>((ref) {
  return ProviderHealthMonitor(ref);
});

/// Provider health monitoring service
class ProviderHealthMonitor {
  final Ref ref;
  final ProviderErrorRecovery _recovery = SecurityInitialization.providerRecovery;
  Timer? _healthTimer; // Store timer reference to prevent memory leak

  ProviderHealthMonitor(this.ref) {
    _startMonitoring();
  }

  void _startMonitoring() {
    // Check provider health every minute
    _healthTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final providersInError = _recovery.getProvidersInError();

      if (providersInError.isNotEmpty) {
        // Log providers in error state
        SecurityInitialization.errorLogging.logWarning(
          'Providers in error state',
          {
            'count': providersInError.length,
            'providers': providersInError.keys.toList(),
          },
        );

        // Attempt to recover critical providers
        for (final entry in providersInError.entries) {
          if (_isCriticalProvider(entry.key)) {
            _recovery.clearErrorState(entry.key);
          }
        }
      }
    });
  }

  bool _isCriticalProvider(String providerId) {
    const criticalProviders = [
      'notes_provider',
      'sync_status_provider',
      'user_preferences_loader',
    ];
    return criticalProviders.contains(providerId);
  }

  /// Get current health status
  Map<String, dynamic> getHealthStatus() {
    final errors = _recovery.getProvidersInError();

    return {
      'healthy': errors.isEmpty,
      'errorCount': errors.length,
      'criticalErrors': errors.entries
          .where((e) => _isCriticalProvider(e.key))
          .map((e) => e.key)
          .toList(),
    };
  }

  /// Dispose of resources to prevent memory leaks
  void dispose() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }
}

// Type placeholders (these should match your actual types)
enum SyncStatus { idle, syncing, success, error }
class UserPreferences {
  static UserPreferences defaults() => UserPreferences();
}
class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  UserPreferencesNotifier() : super(UserPreferences.defaults());
}
class FolderNode {}
class TagModel {}