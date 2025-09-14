import 'package:flutter/foundation.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/settings/analytics_notifier.dart';
import 'package:duru_notes/core/settings/locale_notifier.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/settings/sync_mode_notifier.dart';
import 'package:duru_notes/core/settings/theme_mode_notifier.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/sync_service.dart';
import 'package:duru_notes/search/search_service.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/services/clipper_inbox_notes_adapter.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/services/inbox_management_service.dart';
import 'package:duru_notes/services/inbox_unread_service.dart';
import 'package:duru_notes/services/inbox_realtime_service.dart';
import 'package:duru_notes/services/folder_realtime_service.dart';
import 'package:duru_notes/services/notes_realtime_service.dart';
import 'package:duru_notes/services/notification_handler_service.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/services/note_task_sync_service.dart';
import 'package:duru_notes/repository/task_repository.dart';
import 'package:duru_notes/ui/filters/filters_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Export important types for easier importing
export 'data/local/app_db.dart' show AppDb, LocalNote;
export 'features/notes/pagination_notifier.dart' show NotesPage;

/// Auth state stream to trigger provider rebuilds on login/logout
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Database provider
final appDbProvider = Provider<AppDb>((ref) {
  return AppDb();
});

/// Key manager provider  
final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager(accountKeyService: ref.watch(accountKeyServiceProvider));
});

/// Crypto box provider
final cryptoBoxProvider = Provider<CryptoBox>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return CryptoBox(keyManager);
});

/// Notes repository provider
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('NotesRepository requested without an authenticated user');
  }
  
  final api = SupabaseNoteApi(client);
  
  return NotesRepository(
    db: db,
    crypto: crypto,
    api: api,
    client: client,
  );
});

/// Folder repository provider
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('FolderRepository requested without an authenticated user');
  }
  
  final repo = FolderRepository(db: db, userId: userId);
  
  // Dispose when provider is disposed
  ref.onDispose(() {
    repo.dispose();
  });
  
  return repo;
});

/// Folder updates stream provider
final folderUpdatesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  return repo.folderUpdates;
});

/// Folder update listener provider - listens to folder updates and invalidates dependent providers
final folderUpdateListenerProvider = Provider<void>((ref) {
  // Listen to folder updates and invalidate dependent providers
  ref.listen(folderUpdatesProvider, (_, __) {
    // Invalidate all folder-related providers to refresh UI
    ref.invalidate(folderHierarchyProvider);
    ref.invalidate(rootFoldersProvider);
    ref.invalidate(folderListProvider);
    ref.invalidate(visibleFolderNodesProvider);
    ref.invalidate(unfiledNotesCountProvider);
    ref.invalidate(filteredNotesProvider);
    
    // Also refresh notes if they're folder-filtered
    final currentFolder = ref.read(currentFolderProvider);
    if (currentFolder != null) {
      ref.read(notesPageProvider.notifier).refresh();
    }
    
    debugPrint('[FolderUpdates] Invalidated folder-dependent providers');
  });
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  // Rebuild SyncService when repo or auth changes
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notesRepositoryProvider);
  final service = SyncService(repo);
  
  // Listen to sync changes and refresh folders on completion
  service.changes.listen((_) async {
    try {
      // Refresh folders after successful sync
      // This also triggers rootFoldersProvider rebuild automatically
      await ref.read(folderHierarchyProvider.notifier).loadFolders();
      debugPrint('[Sync] Folders refreshed after sync completion');
      
      // Also refresh notes providers for immediate UI update
      ref.invalidate(filteredNotesProvider);
      ref.read(notesPageProvider.notifier).refresh();
      debugPrint('[Sync] Notes providers refreshed after sync completion');
    } catch (e) {
      debugPrint('[Sync] Error refreshing after sync: $e');
    }
  });
  
  return service;
});

/// Provider for paginated notes
final notesPageProvider = StateNotifierProvider.autoDispose<NotesPaginationNotifier, AsyncValue<NotesPage>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NotesPaginationNotifier(repo)..loadMore(); // Load first page immediately
});

/// Provider to watch just the loading state
final notesLoadingProvider = Provider<bool>((ref) {
  final notifier = ref.watch(notesPageProvider.notifier);
  return notifier.isLoadingMore;
});

/// Provider to watch just the current notes list
final currentNotesProvider = Provider<List<LocalNote>>((ref) {
  return ref.watch(notesPageProvider).when(
    data: (page) => page.items,
    loading: () => <LocalNote>[],
    error: (_, __) => <LocalNote>[],
  );
});

/// Current folder filter provider
final currentFolderProvider = StateNotifierProvider<CurrentFolderNotifier, LocalFolder?>((ref) {
  return CurrentFolderNotifier();
});

/// Helper function to batch fetch tags for multiple notes
Future<Map<String, Set<String>>> _batchFetchTags(
  NotesRepository repo,
  List<String> noteIds,
) async {
  final Map<String, Set<String>> result = {};
  
  // Batch fetch all tags in a single query
  final db = repo.db;
  final tagsQuery = db.select(db.noteTags)
    ..where((t) => t.noteId.isIn(noteIds));
  
  final allTags = await tagsQuery.get();
  
  // Group tags by note ID
  for (final tag in allTags) {
    result.putIfAbsent(tag.noteId, () => {}).add(tag.tag);
  }
  
  // Ensure all noteIds have an entry (even if empty)
  for (final noteId in noteIds) {
    result.putIfAbsent(noteId, () => {});
  }
  
  return result;
}

/// Provider for folder-filtered notes
final filteredNotesProvider = FutureProvider<List<LocalNote>>((ref) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);
  final repo = ref.watch(notesRepositoryProvider);
  
  // Get base notes based on folder selection
  List<LocalNote> notes;
  if (currentFolder != null) {
    notes = await repo.getNotesInFolder(currentFolder.id);
  } else {
    // IMPORTANT: Use watch instead of read to trigger rebuilds when notes update
    notes = ref.watch(currentNotesProvider);
  }
  
  // Apply advanced filters if active
  if (filterState != null && filterState.hasActiveFilters) {
    // Filter by pinned status
    if (filterState.pinnedOnly) {
      notes = notes.where((note) => note.isPinned).toList();
    }
    
    // Batch fetch tags for all notes if needed
    if (filterState.includeTags.isNotEmpty || filterState.excludeTags.isNotEmpty) {
      // Batch fetch all tags at once
      final noteIds = notes.map((n) => n.id).toList();
      final noteTagsMap = await _batchFetchTags(repo, noteIds);
      
      // Filter by included tags
      if (filterState.includeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has ALL required tags
          return filterState.includeTags.every((tag) => tagSet.contains(tag));
        }).toList();
      }
      
      // Filter by excluded tags
      if (filterState.excludeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has NONE of the excluded tags
          return !filterState.excludeTags.any((tag) => tagSet.contains(tag));
        }).toList();
      }
    }
  }
  
  return notes;
});

/// Provider to check if there are more notes to load
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref.watch(notesPageProvider).when(
    data: (page) => page.hasMore,
    loading: () => true,
    error: (_, __) => false,
  );
});

/// Logger provider
final loggerProvider = Provider<AppLogger>((ref) {
  return LoggerFactory.instance;
});

/// Analytics provider  
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsFactory.instance;
});

/// Database provider alias for compatibility
final Provider<AppDb> dbProvider = appDbProvider;

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
    // attachmentService: ref.watch(attachmentServiceProvider),  // Reserved for attachment export
  );
});

/// Task service provider
final taskServiceProvider = Provider<TaskService>((ref) {
  final database = ref.watch(appDbProvider);
  return TaskService(database: database);
});

/// Task repository provider for sync
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final database = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  
  if (userId == null || userId.isEmpty) {
    throw StateError('TaskRepository requested without an authenticated user');
  }
  
  return TaskRepository(
    database: database,
    supabase: client,
  );
});

/// Note-task sync service provider
final noteTaskSyncServiceProvider = Provider<NoteTaskSyncService>((ref) {
  final database = ref.watch(appDbProvider);
  final taskService = ref.watch(taskServiceProvider);
  
  final service = NoteTaskSyncService(
    database: database,
    taskService: taskService,
  );
  
  ref.onDispose(() => service.dispose());
  
  return service;
});

/// Account key service (AMK) provider
final accountKeyServiceProvider = Provider<AccountKeyService>((ref) {
  return AccountKeyService(
    logger: ref.watch(loggerProvider),
  );
});

/// Push notification service provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(
    logger: ref.watch(loggerProvider),
  );
  
  // Initialize the service
  service.initialize().catchError((error) {
    ref.watch(loggerProvider).error('Failed to initialize push notification service: $error');
  });
  
  // Clean up on disposal
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Notification handler service provider
final notificationHandlerServiceProvider = Provider<NotificationHandlerService>((ref) {
  // Only create if authenticated
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  if (client.auth.currentUser == null) {
    throw StateError('NotificationHandlerService requested without authentication');
  }
  
  final service = NotificationHandlerService(
    client: client,
    logger: ref.watch(loggerProvider),
    pushService: ref.watch(pushNotificationServiceProvider),
  );
  
  // Clean up on disposal
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Attachment service provider
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Import service provider
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    notesRepository: ref.watch(notesRepositoryProvider),
    noteIndexer: NoteIndexer(logger: ref.watch(loggerProvider)),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Share extension service provider
final shareExtensionServiceProvider = Provider<ShareExtensionService>((ref) {
  return ShareExtensionService(
    notesRepository: ref.watch(notesRepositoryProvider),
    attachmentService: ref.watch(attachmentServiceProvider),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Email alias service provider
final emailAliasServiceProvider = Provider<EmailAliasService>((ref) {
  final client = Supabase.instance.client;
  return EmailAliasService(client);
});

/// Incoming mail folder manager provider
final incomingMailFolderManagerProvider = Provider<IncomingMailFolderManager>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('IncomingMailFolderManager requested without authentication');
  }
  
  final repo = ref.watch(notesRepositoryProvider);
  return IncomingMailFolderManager(
    repository: repo,
    userId: userId,
  );
});

/// Inbox management service provider
final inboxManagementServiceProvider = Provider<InboxManagementService>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  if (client.auth.currentUser == null) {
    throw StateError('InboxManagementService requested without authentication');
  }
  
  final aliasService = ref.watch(emailAliasServiceProvider);
  final repository = ref.watch(notesRepositoryProvider);
  final folderManager = ref.watch(incomingMailFolderManagerProvider);
  final syncService = ref.watch(syncServiceProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);
  
  return InboxManagementService(
    supabase: client,
    aliasService: aliasService,
    notesRepository: repository,
    folderManager: folderManager,
    syncService: syncService,
    attachmentService: attachmentService,
  );
});

/// Inbox realtime subscription service provider
final inboxRealtimeServiceProvider = ChangeNotifierProvider<InboxRealtimeService>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  if (client.auth.currentUser == null) {
    throw StateError('InboxRealtimeService requested without authentication');
  }
  
  final service = InboxRealtimeService(supabase: client);
  
  // Start realtime subscription
  service.start();
  
  // Clean up on logout/dispose
  ref.onDispose(() {
    service.stop();
  });
  
  return service;
});

/// Folder realtime subscription service provider
final folderRealtimeServiceProvider = Provider<FolderRealtimeService?>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  // Return null if not authenticated - graceful degradation
  if (client.auth.currentUser == null) {
    return null;
  }
  
  final service = FolderRealtimeService(
    supabase: client,
    ref: ref,
  );
  
  // Start realtime subscription
  service.start();
  
  // Clean up on logout/dispose
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Notes realtime subscription service provider
final notesRealtimeServiceProvider = ChangeNotifierProvider<NotesRealtimeService?>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  // Return null if not authenticated - graceful degradation
  if (client.auth.currentUser == null) {
    return null;
  }
  
  final service = NotesRealtimeService(
    supabase: client,
    ref: ref,
  );
  
  // Start realtime subscription
  service.start();
  
  // Clean up on logout/dispose
  ref.onDispose(() {
    service.stop();
  });
  
  return service;
});

/// Inbox unread tracking service provider
final inboxUnreadServiceProvider = ChangeNotifierProvider<InboxUnreadService?>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  // Return null if not authenticated - graceful degradation
  if (client.auth.currentUser == null) {
    return null;
  }
  
  final service = InboxUnreadService(supabase: client);
  
  // Listen to realtime changes for instant badge updates
  try {
    final realtimeService = ref.watch(inboxRealtimeServiceProvider);
    // When realtime events occur, update badge count
    realtimeService.addListener(() {
      service.computeBadgeCount();
    });
  } catch (e) {
    debugPrint('Could not connect realtime to unread service: $e');
  }
  
  // Compute initial badge count
  service.computeBadgeCount();
  
  // Clean up on logout
  ref.onDispose(() {
    service.clear();
  });
  
  return service;
});

/// Clipper inbox service provider (legacy - for auto-processing mode only)
final clipperInboxServiceProvider = Provider<ClipperInboxService>((ref) {
  // Only create if authenticated
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    throw StateError('ClipperInboxService requested without authentication');
  }
  
  final repo = ref.watch(notesRepositoryProvider);
  final db = ref.watch(appDbProvider);
  final adapter = CaptureNotesAdapter(repository: repo, db: db);
  final folderManager = ref.watch(incomingMailFolderManagerProvider);
  
  return ClipperInboxService(
    supabase: client,
    notesPort: adapter,
    folderManager: folderManager,
    unreadService: null,  // No longer needed - realtime handled separately
  );
});

// Settings providers

/// Sync mode provider
final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  
  // Callback to refresh UI after successful sync
  // Use a safe callback that checks if the provider is still alive
  void onSyncComplete() {
    // Only refresh if the provider is still alive
    try {
      // Check if we can still access providers
      ref.read(notesPageProvider.notifier).refresh();
      
      // Load additional pages if there are more notes
      while (ref.read(hasMoreNotesProvider)) {
        ref.read(notesPageProvider.notifier).loadMore();
      }
      
      // Refresh folders as well
      ref.read(folderHierarchyProvider.notifier).loadFolders();
    } catch (e) {
      // Provider is disposed or ref is not available
      // Silently ignore - this is expected when the provider is disposed
      debugPrint('[SyncMode] Cannot refresh after sync - provider disposed');
    }
  }
  
  return SyncModeNotifier(repo, onSyncComplete);
});

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Locale provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// Analytics settings provider
final analyticsSettingsProvider = StateNotifierProvider<AnalyticsNotifier, bool>((ref) {
  final analytics = ref.watch(analyticsProvider);
  return AnalyticsNotifier(analytics);
});

// Folder providers

/// Folder state provider for CRUD operations
final folderProvider = StateNotifierProvider<FolderNotifier, FolderOperationState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return FolderNotifier(repo);
});

/// Folder hierarchy provider for tree structure management
final folderHierarchyProvider = StateNotifierProvider<FolderHierarchyNotifier, FolderHierarchyState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return FolderHierarchyNotifier(repo);
});

/// Note-folder relationship provider
final noteFolderProvider = StateNotifierProvider<NoteFolderNotifier, NoteFolderState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NoteFolderNotifier(repo);
});

/// Folder list provider (derived from hierarchy state)
final folderListProvider = Provider<List<LocalFolder>>((ref) {
  return ref.watch(folderHierarchyProvider).folders;
});

/// Visible folder tree nodes provider (derived from hierarchy state)
final visibleFolderNodesProvider = Provider<List<FolderTreeNode>>((ref) {
  ref.watch(folderHierarchyProvider); // Watch the state, not just notifier
  return ref.read(folderHierarchyProvider.notifier).getVisibleNodes();
});

/// Root folders provider for quick access
/// This provider is invalidated whenever folders change to ensure consistency
final rootFoldersProvider = FutureProvider<List<LocalFolder>>((ref) {
  // Watch the folder hierarchy state to ensure both providers stay in sync
  // This causes rootFoldersProvider to rebuild when hierarchy changes
  ref.watch(folderHierarchyProvider);
  
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getRootFolders();
});

/// All folders count provider for accurate statistics
final allFoldersCountProvider = FutureProvider<int>((ref) async {
  // Watch the folder hierarchy to rebuild when folders change
  ref.watch(folderHierarchyProvider);
  
  final repo = ref.watch(notesRepositoryProvider);
  final allFolders = await repo.listFolders();
  return allFolders.length;
});

/// Unfiled notes count provider
final unfiledNotesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  final unfiledNotes = await repo.getUnfiledNotes();
  return unfiledNotes.length;
});

/// Search service provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final db = ref.watch(appDbProvider);
  final repo = ref.watch(notesRepositoryProvider);
  return SearchService(db: db, repo: repo);
});

/// Sort preferences service
final sortPreferencesServiceProvider = Provider<SortPreferencesService>((ref) {
  return SortPreferencesService();
});

/// Stream of saved searches from the database
final savedSearchesStreamProvider = StreamProvider<List<SavedSearch>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchSavedSearches();
});

/// Current filter state for advanced filters
final filterStateProvider = StateProvider<FilterState?>((ref) => null);

/// Current sort spec for the selected folder
final currentSortSpecProvider = StateNotifierProvider<CurrentSortSpecNotifier, NoteSortSpec>((ref) {
  final currentFolder = ref.watch(currentFolderProvider);
  final service = ref.watch(sortPreferencesServiceProvider);
  
  // Create a new notifier when folder changes
  final notifier = CurrentSortSpecNotifier(service, currentFolder?.id);
  
  // Clean up when folder changes
  ref.onDispose(() {
    // Nothing to dispose, but could add cleanup if needed
  });
  
  return notifier;
});

/// Notifier for managing the current sort spec
class CurrentSortSpecNotifier extends StateNotifier<NoteSortSpec> {
  CurrentSortSpecNotifier(this._service, this._folderId) : super(const NoteSortSpec()) {
    _loadSortSpec();
  }

  final SortPreferencesService _service;
  final String? _folderId;

  Future<void> _loadSortSpec() async {
    final spec = await _service.getSortForFolder(_folderId);
    if (mounted) {
      state = spec;
    }
  }

  Future<void> updateSortSpec(NoteSortSpec spec) async {
    state = spec;
    await _service.setSortForFolder(_folderId, spec);
  }
}
