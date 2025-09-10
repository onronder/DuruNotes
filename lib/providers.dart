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
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/sync_service.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/services/clipper_inbox_notes_adapter.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/services/inbox_management_service.dart';
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
  
  return NotesRepository(
    db: db,
    crypto: crypto,
    client: client,
    userId: userId,
  );
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  // Rebuild SyncService when repo or auth changes
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notesRepositoryProvider);
  return SyncService(repo);
});

/// Provider for paginated notes
final notesPageProvider = StateNotifierProvider<NotesPaginationNotifier, AsyncValue<NotesPage>>((ref) {
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

/// Provider for folder-filtered notes
final filteredNotesProvider = FutureProvider<List<LocalNote>>((ref) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final repo = ref.watch(notesRepositoryProvider);
  
  if (currentFolder != null) {
    // Show notes in the selected folder
    return repo.getNotesInFolder(currentFolder.id);
  } else {
    // Show all notes
    return ref.watch(currentNotesProvider);
  }
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

/// Account key service (AMK) provider
final accountKeyServiceProvider = Provider<AccountKeyService>((ref) {
  return AccountKeyService(
    logger: ref.watch(loggerProvider),
  );
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
  
  return InboxManagementService(
    supabase: client,
    aliasService: aliasService,
    notesRepository: repository,
    folderManager: folderManager,
  );
});

/// Clipper inbox service provider
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
  );
});

// Settings providers

/// Sync mode provider
final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  
  // Callback to refresh UI after successful sync
  void onSyncComplete() {
    ref.read(notesPageProvider.notifier).refresh();
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
final rootFoldersProvider = FutureProvider<List<LocalFolder>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getRootFolders();
});

/// Unfiled notes count provider
final unfiledNotesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  final unfiledNotes = await repo.getUnfiledNotes();
  return unfiledNotes.length;
});
