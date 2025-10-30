import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/core/error/provider_error_recovery.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/services/error_logging_service.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/domain/entities/note.dart' as domain_note;
import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
// Phase 5: Migrated to organized provider imports
import 'package:duru_notes/features/notes/providers/notes_domain_providers.dart'
    show domainNotesProvider;
import 'package:duru_notes/features/folders/providers/folders_domain_providers.dart'
    show domainFoldersProvider;
import 'package:duru_notes/features/tasks/providers/tasks_domain_providers.dart'
    show domainTasksProvider, domainTasksStreamProvider;

/// Secure wrapper for providers with error recovery and monitoring
/// This provides production-grade error handling for all critical providers

// ============================================================================
// NOTES PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure notes provider with automatic error recovery
/// Returns domain.Note objects - consumers should use domain types
final secureNotesProvider = FutureProvider.autoDispose<List<domain_note.Note>>((
  ref,
) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'notes_provider',
    operation: () async {
      // Watch the domain notes provider
      return await ref.watch(domainNotesProvider.future);
    },
    fallbackValue: <domain_note.Note>[], // Empty list as fallback
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
/// Returns domain.Note objects - filtering is handled by the domain providers
final secureFilteredNotesProvider =
    FutureProvider.autoDispose<List<domain_note.Note>>((ref) async {
      final recovery = SecurityInitialization.providerRecovery;

      // Configure specific recovery for filtered notes
      recovery.configureProvider(
        providerId: 'filtered_notes_provider',
        fallbackValue: <domain_note.Note>[],
        retryPolicy: RetryPolicy(
          maxAttempts: 2,
          retryDelay: const Duration(seconds: 1),
          backoffStrategy: BackoffStrategy.fixed,
        ),
      );

      return recovery.executeWithRecovery(
        providerId: 'filtered_notes_provider',
        operation: () async {
          // Use the domain notes provider - filtering happens elsewhere
          return await ref.watch(domainNotesProvider.future);
        },
        fallbackValue: <domain_note.Note>[],
      );
    });

// ============================================================================
// TASKS PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure tasks provider with error recovery
/// Returns domain.Task objects
///
/// NOTE: Riverpod 3.0+ - Using async* generator instead of deprecated .stream
final secureTasksProvider = StreamProvider.autoDispose<List<domain_task.Task>>((
  ref,
) async* {
  final recovery = SecurityInitialization.providerRecovery;

  // Use streamWithRecovery with a factory that doesn't rely on deprecated .stream
  yield* recovery.streamWithRecovery(
    providerId: 'tasks_provider',
    streamFactory: () async* {
      // Riverpod 3.0: Fetch initial data with .future
      final initialTasks = await ref.watch(domainTasksStreamProvider.future);
      yield initialTasks;

      // Listen for subsequent updates
      ref.listen(domainTasksStreamProvider, (previous, next) {
        // Provider will auto-rebuild when domainTasksStreamProvider changes
      });
    },
    fallbackValue: <domain_task.Task>[],
  );
});

/// Secure task stats provider
final secureTaskStatsProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'task_stats_provider',
    operation: () async {
      final tasks = await ref.watch(domainTasksProvider.future);
      final now = DateTime.now();

      return {
        'total': tasks.length,
        'completed': tasks
            .where((t) => t.status == domain_task.TaskStatus.completed)
            .length,
        'pending': tasks
            .where((t) => t.status != domain_task.TaskStatus.completed)
            .length,
        'overdue': tasks
            .where(
              (t) =>
                  t.status != domain_task.TaskStatus.completed &&
                  t.dueDate != null &&
                  t.dueDate!.isBefore(now),
            )
            .length,
      };
    },
    fallbackValue: {'total': 0, 'completed': 0, 'pending': 0, 'overdue': 0},
  );
});

// ============================================================================
// FOLDER PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure folders provider
/// Returns domain.Folder objects
final secureFoldersProvider =
    FutureProvider.autoDispose<List<domain_folder.Folder>>((ref) async {
      final recovery = SecurityInitialization.providerRecovery;

      return recovery.executeWithRecovery(
        providerId: 'folders_provider',
        operation: () async {
          return await ref.watch(domainFoldersProvider.future);
        },
        fallbackValue: <domain_folder.Folder>[],
      );
    });

/// Secure folder tree provider
/// DEPRECATED: Folder tree structure should be built from flat list
@Deprecated('Build tree from domainFoldersProvider instead')
final secureFolderTreeProvider = FutureProvider.autoDispose<domain_folder.Folder?>((
  ref,
) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'folder_tree_provider',
    operation: () async {
      // Folders are now flat - consumers should build tree from parent relationships
      return null;
    },
    fallbackValue: null,
  );
});

// ============================================================================
// TAG PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure tags provider
/// DEPRECATED: Tags are embedded in notes, use domain notes and extract tags
@Deprecated('Extract tags from notes instead')
final secureTagsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.streamWithRecovery(
    providerId: 'tags_provider',
    streamFactory: () {
      // Tags are now part of notes - consumers should extract from notes
      return Stream.value(<String>[]);
    },
    fallbackValue: <String>[],
  );
});

/// Secure popular tags provider
/// DEPRECATED: Extract from notes instead
@Deprecated('Extract popular tags from notes instead')
final securePopularTagsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'popular_tags_provider',
    operation: () async {
      // Tags are embedded in notes
      return <String>[];
    },
    fallbackValue: <String>[],
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
    streamFactory: () => Stream.value(
      SyncStatus.idle,
    ), // TODO: Implement actual sync status stream
    fallbackValue: SyncStatus.idle,
  );
});

/// Secure sync operation provider
final secureSyncOperationProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final recovery = SecurityInitialization.providerRecovery;

  return recovery.executeWithRecovery(
    providerId: 'sync_operation_provider',
    operation: () async {
      // TODO: Implement sync service
      await Future<void>.delayed(const Duration(seconds: 1));
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
/// Returns domain.Note objects
final secureSearchProvider = FutureProvider.autoDispose
    .family<List<domain_note.Note>, String>((ref, query) async {
      final recovery = SecurityInitialization.providerRecovery;

      return recovery.executeWithRecovery(
        providerId: 'search_provider_$query',
        operation: () async {
          // Validate search query
          final validatedQuery = SecurityInitialization.validation
              .validateAndSanitizeText(
                query,
                fieldName: 'search',
                maxLength: 100,
                allowHtml: false,
              );

          if (validatedQuery == null || validatedQuery.isEmpty) {
            return <domain_note.Note>[];
          }

          // Perform search using domain notes provider
          final allNotes = await ref.watch(domainNotesProvider.future);
          final lowerQuery = validatedQuery.toLowerCase();

          return allNotes.where((note) {
            return note.title.toLowerCase().contains(lowerQuery) ||
                note.body.toLowerCase().contains(lowerQuery);
          }).toList();
        },
        fallbackValue: <domain_note.Note>[],
      );
    });

// ============================================================================
// USER PREFERENCES WITH ERROR RECOVERY
// ============================================================================

/// Secure user preferences provider
final secureUserPreferencesProvider =
    StateNotifierProvider.autoDispose<UserPreferencesNotifier, UserPreferences>(
      (ref) {
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
      },
    );

// ============================================================================
// ANALYTICS PROVIDERS WITH ERROR RECOVERY
// ============================================================================

/// Secure analytics data provider
final secureAnalyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
                : tasks
                          .where(
                            (t) => t.status == domain_task.TaskStatus.completed,
                          )
                          .length /
                      tasks.length,
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
final providerHealthProvider = Provider.autoDispose<ProviderHealthMonitor>((
  ref,
) {
  return ProviderHealthMonitor(ref);
});

/// Provider health monitoring service
class ProviderHealthMonitor {
  final Ref ref;
  final ProviderErrorRecovery _recovery =
      SecurityInitialization.providerRecovery;
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
        SecurityInitialization.errorLogging
            .logWarning('Providers in error state', {
              'count': providersInError.length,
              'providers': providersInError.keys.toList(),
            });

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
