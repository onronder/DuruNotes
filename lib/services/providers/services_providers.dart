import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/clipper_inbox_notes_adapter.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:duru_notes/services/inbox_management_service.dart';
import 'package:duru_notes/services/inbox_unread_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/services/notification_handler_service.dart';
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:duru_notes/services/undo_redo_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart' hide loggerProvider, authStateChangesProvider, noteIndexerProvider, analyticsProvider, appDbProvider, userIdProvider;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});

/// Push notification service provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref);

  // Initialize the service
  service.initialize().catchError((Object error) {
    ref
        .watch(loggerProvider)
        .error('Failed to initialize push notification service: $error');
  });

  // Clean up on disposal
  ref.onDispose(service.dispose);

  return service;
});

/// Notification handler service provider
final notificationHandlerServiceProvider = Provider<NotificationHandlerService>(
  (ref) {
    // Only create if authenticated
    ref.watch(authStateChangesProvider);
    final client = Supabase.instance.client;

    if (client.auth.currentUser == null) {
      throw StateError(
        'NotificationHandlerService requested without authentication',
      );
    }

    final service = NotificationHandlerService(
      ref,
      client: client,
      pushService: ref.watch(pushNotificationServiceProvider),
    );

    // Clean up on disposal
    ref.onDispose(service.dispose);

    return service;
  },
);

/// Attachment service provider
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref);
});

/// Import service provider
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    // We'll need to import notesRepositoryProvider from notes module
    notesRepository: ref.watch(notesRepositoryProvider),
    noteIndexer: ref.watch(noteIndexerProvider),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Share extension service provider
final shareExtensionServiceProvider = Provider<ShareExtensionService>((ref) {
  return ShareExtensionService(
    // We'll need to import notesRepositoryProvider from notes module
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
final incomingMailFolderManagerProvider = Provider<IncomingMailFolderManager>((
  ref,
) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError(
      'IncomingMailFolderManager requested without authentication',
    );
  }

  final repo = ref.watch(notesRepositoryProvider);
  final manager = IncomingMailFolderManager(repository: repo, userId: userId);
  // unawaited(manager.processPendingAssignments());
  return manager;
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

/// Inbox unread tracking service provider
final inboxUnreadServiceProvider = ChangeNotifierProvider<InboxUnreadService?>((
  ref,
) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;

  // Return null if not authenticated - graceful degradation
  if (client.auth.currentUser == null) {
    return null;
  }

  final service = InboxUnreadService(supabase: client);

  // Listen to unified realtime changes for instant badge updates
  // We'll need to import from sync module
  final unifiedRealtime = null; // ref.watch(unifiedRealtimeServiceProvider);
  if (unifiedRealtime != null) {
    // Subscribe to inbox stream from unified service
    // unifiedRealtime.inboxStream.listen((event) {
    //   debugPrint(
    //     '[InboxUnread] Received inbox change event: ${event.eventType}',
    //   );
    //   service.computeBadgeCount();
    // });

    // Also listen to general notifications
    // unifiedRealtime.addListener(service.computeBadgeCount);
  }

  // Compute initial badge count
  service.computeBadgeCount();

  // Clean up on logout
  ref.onDispose(service.clear);

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
  );
});

/// Provider for UndoRedoService
final undoRedoServiceProvider = ChangeNotifierProvider<UndoRedoService>((ref) {
  // We'll need to import notesRepositoryProvider from notes module
  final repository = null; // ref.watch(notesRepositoryProvider);
  final userId = ref.watch(userIdProvider) ?? 'default';

  return UndoRedoService(
    repository: repository,
    userId: userId,
  );
});