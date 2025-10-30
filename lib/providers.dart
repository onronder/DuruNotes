// Phase 9: Removed unused imports - all service implementations now in organized files
import 'package:duru_notes/core/providers/auth_providers.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider;
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Export important types for easier importing
export 'data/local/app_db.dart' show AppDb, LocalNote;
export 'features/notes/pagination_notifier.dart' show NotesPage;
export 'core/providers/database_providers.dart' show appDbProvider, getAppDb;
export 'features/settings/providers/settings_providers.dart'
    show
        userPreferencesServiceProvider,
        themeModeProvider,
        localeProvider,
        analyticsSettingsProvider;

// ===== PHASE 2 & 4: Re-export organized providers for backward compatibility =====
// Export auth providers from organized file
export 'package:duru_notes/core/providers/auth_providers.dart'
    show authStateChangesProvider, supabaseClientProvider, userIdProvider;

// Export search providers from organized file
export 'package:duru_notes/core/providers/search_providers.dart'
    show noteIndexerProvider;

// Export notes state providers from organized file
export 'package:duru_notes/features/notes/providers/notes_state_providers.dart'
    show
        currentFolderProvider,
        filterStateProvider,
        filteredNotesProvider,
        sortPreferencesServiceProvider,
        currentSortSpecProvider,
        CurrentSortSpecNotifier,
        currentNotesProvider,
        notesPageProvider,
        hasMoreNotesProvider,
        notesLoadingProvider;

// Phase 4: Export security providers from organized file
export 'package:duru_notes/core/providers/security_providers.dart'
    show accountKeyServiceProvider, keyManagerProvider, cryptoBoxProvider;

// Phase 5: Export domain entity providers from organized files
export 'package:duru_notes/features/notes/providers/notes_domain_providers.dart'
    show
        domainNotesProvider,
        domainNotesStreamProvider,
        domainFilteredNotesProvider,
        domainPinnedNotesProvider,
        domainUnpinnedNotesProvider;

export 'package:duru_notes/features/folders/providers/folders_domain_providers.dart'
    show domainFoldersProvider, domainFoldersStreamProvider;

export 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show domainTemplatesProvider, domainTemplatesStreamProvider;

export 'package:duru_notes/features/tasks/providers/tasks_domain_providers.dart'
    show
        domainTasksProvider,
        domainTasksForNoteProvider,
        domainTasksStreamProvider,
        domainOpenTasksProvider,
        domainCompletedTasksProvider,
        domainTaskStatsProvider;

// Phase 6: Export folder providers from organized files
export 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show
        folderProvider,
        folderHierarchyProvider,
        noteFolderProvider,
        folderListProvider,
        visibleFolderNodesProvider;

export 'package:duru_notes/features/folders/providers/folders_integration_providers.dart'
    show
        noteFolderIntegrationServiceProvider,
        rootFoldersProvider,
        allFoldersCountProvider,
        unfiledNotesCountProvider;

// Phase 7: Export template and task repository providers from organized files
export 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show
        templateCoreRepositoryProvider,
        templateListProvider,
        templateListStreamProvider,
        systemTemplateListProvider,
        userTemplateListProvider;

export 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider, taskRepositoryProvider;

// Phase 8: Export task service providers from organized file
export 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show
        noteTasksProvider,
        taskByIdProvider,
        taskReminderBridgeProvider,
        enhancedTaskServiceProvider,
        taskAnalyticsServiceProvider,
        productivityGoalsServiceProvider,
        activeGoalsProvider;

// Phase 9: Export service providers from organized files
export 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider, analyticsProvider;
export 'package:duru_notes/core/providers/database_providers.dart'
    show dbProvider;
export 'package:duru_notes/services/providers/services_providers.dart'
    show
        exportServiceProvider,
        pushNotificationServiceProvider,
        notificationHandlerServiceProvider,
        attachmentServiceProvider,
        importServiceProvider,
        shareExtensionServiceProvider,
        emailAliasServiceProvider,
        incomingMailFolderManagerProvider,
        inboxManagementServiceProvider,
        inboxUnreadServiceProvider,
        clipperInboxServiceProvider,
        gdprComplianceServiceProvider,
        undoRedoServiceProvider,
        encryptionSyncServiceProvider;
export 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show unifiedRealtimeServiceProvider, syncModeProvider;
export 'package:duru_notes/features/notes/providers/notes_repository_providers.dart'
    show supabaseNoteApiProvider;
export 'package:duru_notes/features/search/providers/search_providers.dart'
    show searchServiceProvider, savedSearchesStreamProvider;

// Export sync verification and pre-deployment providers for testing
export 'package:duru_notes/providers/sync_verification_providers.dart'
    show
        syncIntegrityValidatorProvider,
        conflictResolutionEngineProvider,
        dataConsistencyCheckerProvider,
        syncRecoveryManagerProvider,
        syncVerificationProvider,
        syncHealthProvider;

// ===== AUTH PROVIDERS =====
// Moved to core/providers/auth_providers.dart
// authStateChangesProvider, supabaseClientProvider, userIdProvider

// ===== SECURITY PROVIDERS =====
// Phase 4: Moved to core/providers/security_providers.dart
// accountKeyServiceProvider, keyManagerProvider, cryptoBoxProvider

// Database provider removed from here - use providers from database_providers.dart

// ===== SEARCH PROVIDERS =====
// Moved to core/providers/search_providers.dart
// noteIndexerProvider

/// Clean architecture repository providers
/// Notes core repository provider
/// IMPORTANT: This provider is defined in lib/infrastructure/providers/repository_providers.dart
/// to include FTSIndexingService and NoteLinkParser. Import from there instead.

/// Tag repository provider
final tagRepositoryInterfaceProvider = Provider<ITagRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = ref.watch(supabaseClientProvider);
  return TagRepository(db: db, client: client, crypto: crypto);
});

/// Search repository provider
final searchRepositoryProvider = Provider<ISearchRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = ref.watch(supabaseClientProvider);
  final folderRepo = ref.watch(folderCoreRepositoryProvider);
  return SearchRepository(
    db: db,
    client: client,
    crypto: crypto,
    folderRepository: folderRepo,
  );
});

// ===== MIGRATION CONFIGURATION =====
// NOTE: migrationConfigProvider is defined in lib/core/providers/infrastructure_providers.dart
// DO NOT re-define here to avoid conflicts

// ===== INFRASTRUCTURE REPOSITORY PROVIDERS =====

// ===== PHASE 7: TEMPLATE & TASK REPOSITORY PROVIDERS MOVED TO ORGANIZED FILES =====
// Template providers moved to: lib/features/templates/providers/templates_providers.dart
//   - templateListProvider, templateListStreamProvider, systemTemplateListProvider, userTemplateListProvider
//   - These now use templateCoreRepositoryProvider + TemplateMapper for proper architecture
//   - Barrel versions were bypassing repository layer with direct DB access
//
// Task repository moved to: lib/features/tasks/providers/tasks_repository_providers.dart
//   - taskCoreRepositoryProvider (nullable version for safe auth handling)
//   - taskRepositoryProvider (alias)
//
// Import from organized files or use barrel re-exports below

// ===== MIGRATION UTILITY PROVIDERS =====

/// Provider migration utilities for safe transitions
class ProviderMigration {
  /// Create a dual provider that switches based on feature flag
  static Provider<T> createDualProvider<T>({
    required Provider<T> legacyProvider,
    required Provider<T> domainProvider,
    required String feature,
  }) {
    return Provider<T>((ref) {
      final config = ref.watch(migrationConfigProvider);
      if (config.isFeatureEnabled(feature)) {
        return ref.watch(domainProvider);
      }
      return ref.watch(legacyProvider);
    });
  }

  /// Create a dual future provider with conversion
  static FutureProvider<List<T>> createDualFutureProvider<TLocal, T>({
    required FutureProvider<List<TLocal>> legacyProvider,
    required FutureProvider<List<T>> domainProvider,
    required T Function(TLocal) converter,
    required String feature,
  }) {
    return FutureProvider<List<T>>((ref) async {
      final config = ref.watch(migrationConfigProvider);
      if (config.isFeatureEnabled(feature)) {
        return ref.watch(domainProvider.future);
      }

      final legacyData = await ref.watch(legacyProvider.future);
      return legacyData.map(converter).toList();
    });
  }
}

// NOTE: migrationStatusProvider is defined in lib/core/providers/infrastructure_providers.dart
// DO NOT re-define here to avoid conflicts

// ===== NOTES STATE PROVIDERS =====
// Moved to features/notes/providers/notes_state_providers.dart
// notesPageProvider, notesLoadingProvider, currentNotesProvider,
// currentFolderProvider, filteredNotesProvider, hasMoreNotesProvider,
// sortPreferencesServiceProvider, filterStateProvider,
// currentSortSpecProvider, CurrentSortSpecNotifier

// ===== PHASE 9: SERVICE PROVIDERS MOVED TO ORGANIZED FILES =====
// All service providers moved to organized files for better modularity:
//   - loggerProvider, analyticsProvider → core/providers/infrastructure_providers.dart
//   - dbProvider → core/providers/database_providers.dart
//   - exportServiceProvider, pushNotificationServiceProvider, notificationHandlerServiceProvider,
//     attachmentServiceProvider, importServiceProvider, shareExtensionServiceProvider,
//     emailAliasServiceProvider, incomingMailFolderManagerProvider, inboxManagementServiceProvider,
//     inboxUnreadServiceProvider, clipperInboxServiceProvider, gdprComplianceServiceProvider,
//     undoRedoServiceProvider, encryptionSyncServiceProvider → services/providers/services_providers.dart
//   - unifiedRealtimeServiceProvider → features/sync/providers/sync_providers.dart
//   - supabaseNoteApiProvider → features/notes/providers/notes_repository_providers.dart
//   - searchServiceProvider, savedSearchesStreamProvider → features/search/providers/search_providers.dart
//   - syncModeProvider → features/settings/providers/settings_providers.dart
//
// Fixed critical issues in organized files:
//   - Added unawaited() call for incomingMailFolderManagerProvider background assignments
//   - Enhanced clipperInboxServiceProvider with production-grade logging and error handling
//   - Verified supabaseNoteApiProvider uses correct nullable type (SupabaseNoteApi?)
//
// Import from organized files or use barrel re-exports above
