import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/crypto/crypto_box.dart';
import 'core/crypto/key_manager.dart';
import 'core/monitoring/app_logger.dart';
import 'core/parser/note_indexer.dart';
import 'core/settings/analytics_notifier.dart';
import 'core/settings/locale_notifier.dart';
import 'core/settings/sync_mode.dart';
import 'core/settings/sync_mode_notifier.dart';
import 'core/settings/theme_mode_notifier.dart';
import 'data/local/app_db.dart';
import 'repository/notes_repository.dart';
import 'repository/sync_service.dart';
import 'features/notes/pagination_notifier.dart';
import 'services/analytics/analytics_service.dart';
import 'services/attachment_service.dart';
import 'services/export_service.dart';
import 'services/import_service.dart';
import 'services/share_extension_service.dart';

// Export important types for easier importing
export 'data/local/app_db.dart' show LocalNote, AppDb;
export 'features/notes/pagination_notifier.dart' show NotesPage;

/// Database provider
final appDbProvider = Provider<AppDb>((ref) {
  return AppDb();
});

/// Key manager provider  
final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});

/// Crypto box provider
final cryptoBoxProvider = Provider<CryptoBox>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return CryptoBox(keyManager);
});

/// Notes repository provider
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id ?? 'anonymous';
  
  return NotesRepository(
    db: db,
    crypto: crypto,
    client: client,
    userId: userId,
  );
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
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
final dbProvider = appDbProvider;

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
    attachmentService: ref.watch(attachmentServiceProvider),
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
