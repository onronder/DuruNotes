import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider, analyticsProvider;
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show authStateChangesProvider, userIdProvider;
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show unifiedRealtimeServiceProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider, inboxRepositoryProvider, quickCaptureRepositoryProvider;
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show templateCoreRepositoryProvider;
// Phase 4: Migrated to organized provider imports
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider, accountKeyServiceProvider;
import 'package:duru_notes/core/providers/search_providers.dart'
    show noteIndexerProvider;
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/clipper_inbox_notes_adapter.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/encryption_sync_service.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/services/gdpr_compliance_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:duru_notes/services/inbox_management_service.dart';
import 'package:duru_notes/services/inbox_unread_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/services/notification_handler_service.dart';
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:duru_notes/services/quick_capture_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:duru_notes/services/undo_redo_service.dart';
import 'package:duru_notes/services/unified_export_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart' show LoggerFactory;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});

/// Push notification service provider
/// CRITICAL FIX: Do NOT auto-initialize to avoid permission popup before unlock screen
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref);

  // REMOVED AUTO-INITIALIZATION - permission request blocks unlock screen!
  // Services that need push notifications must call initialize() explicitly
  // after user unlocks encryption to avoid focus stealing

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
      logger: ref.read(loggerProvider),
      client: client,
      pushService: ref.watch(pushNotificationServiceProvider),
      analytics: ref.watch(analyticsProvider),
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
    notesRepository: ref.watch(notesCoreRepositoryProvider),
    noteIndexer: ref.watch(noteIndexerProvider),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Share extension service provider
final shareExtensionServiceProvider = Provider<ShareExtensionService>((ref) {
  return ShareExtensionService(
    notesRepository: ref.watch(notesCoreRepositoryProvider),
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

  final folderRepo = ref.watch(folderCoreRepositoryProvider);
  final manager = IncomingMailFolderManager(
    folderRepository: folderRepo,
    userId: userId,
  );
  unawaited(manager.processPendingAssignments());
  return manager;
});

/// Inbox management service provider
final inboxManagementServiceProvider = Provider<InboxManagementService>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;

  if (client.auth.currentUser == null) {
    throw StateError('InboxManagementService requested without authentication');
  }

  final inboxRepository = ref.watch(inboxRepositoryProvider);
  final aliasService = ref.watch(emailAliasServiceProvider);
  final repository = ref.watch(notesCoreRepositoryProvider);
  final folderManager = ref.watch(incomingMailFolderManagerProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);

  return InboxManagementService(
    inboxRepository: inboxRepository,
    supabase: client,
    aliasService: aliasService,
    notesRepository: repository,
    folderManager: folderManager,
    // syncService parameter doesn't exist in IncomingMailFolderManager constructor
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
  final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);
  if (unifiedRealtime != null) {
    // Subscribe to inbox stream from unified service
    unifiedRealtime.inboxStream.listen((event) {
      debugPrint(
        '[InboxUnread] Received inbox change event: ${event.eventType}',
      );
      service.computeBadgeCount();
    });

    // Also listen to general notifications
    unifiedRealtime.addListener(service.computeBadgeCount);
  }

  // Compute initial badge count
  service.computeBadgeCount();

  // Clean up on logout
  ref.onDispose(service.clear);

  return service;
});

/// Clipper inbox service provider (for auto-processing mode)
final clipperInboxServiceProvider = Provider<ClipperInboxService>((ref) {
  final logger = LoggerFactory.instance;

  try {
    logger.info('🔧 [Provider] Creating ClipperInboxService...');

    // Watch auth state
    ref.watch(authStateChangesProvider);
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      logger.error('❌ [Provider] ClipperInboxService: No authenticated user');
      throw StateError('ClipperInboxService requested without authentication');
    }

    logger.info(
      '✅ [Provider] ClipperInboxService: User authenticated (${user.id.substring(0, 8)})',
    );

    // Get dependencies with error handling
    final repo = ref.watch(notesCoreRepositoryProvider);
    final db = ref.watch(appDbProvider);
    final adapter = CaptureNotesAdapter(repository: repo, db: db);
    final folderManager = ref.watch(incomingMailFolderManagerProvider);

    final service = ClipperInboxService(
      supabase: client,
      notesPort: adapter,
      folderManager: folderManager,
    );

    logger.info('✅ [Provider] ClipperInboxService created successfully');
    return service;
  } catch (e, stack) {
    logger.error(
      '❌ [Provider] Failed to create ClipperInboxService',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
});

/// GDPR Compliance Service provider
final gdprComplianceServiceProvider = Provider<GDPRComplianceService>((ref) {
  return GDPRComplianceService(
    db: ref.watch(appDbProvider),
    exportService: ref.watch(unifiedExportServiceProvider),
    supabaseClient: Supabase.instance.client,
    cryptoBox: ref.watch(cryptoBoxProvider),
  );
});

/// Provider for UndoRedoService
final undoRedoServiceProvider = ChangeNotifierProvider<UndoRedoService>((ref) {
  final repository = ref.watch(notesCoreRepositoryProvider);
  final userId = ref.watch(userIdProvider) ?? 'default';

  return UndoRedoService(repository: repository, userId: userId);
});

/// Encryption Sync Service provider for cross-device encryption
///
/// Manages AMK (Account Master Key) synchronization across devices
/// using password-derived encryption (Argon2id + AES-256-GCM)
final encryptionSyncServiceProvider = Provider<EncryptionSyncService>((ref) {
  final client = Supabase.instance.client;
  const secureStorage = FlutterSecureStorage();
  final accountKeyService = ref.watch(accountKeyServiceProvider);

  return EncryptionSyncService(
    supabase: client,
    secureStorage: secureStorage,
    accountKeyService: accountKeyService,
  );
});

/// Quick Capture Service provider for widget integration
///
/// Handles quick note capture and syncs data to iOS/Android widgets
final quickCaptureServiceProvider = Provider<QuickCaptureService>((ref) {
  final notesRepository = ref.watch(notesCoreRepositoryProvider);
  final templateRepository = ref.watch(templateCoreRepositoryProvider);
  final quickCaptureRepository = ref.watch(quickCaptureRepositoryProvider);
  final analytics = ref.watch(analyticsProvider);
  final logger = ref.watch(loggerProvider);
  final client = Supabase.instance.client;
  final attachmentService = ref.watch(attachmentServiceProvider);

  return QuickCaptureService(
    notesRepository: notesRepository,
    templateRepository: templateRepository,
    quickCaptureRepository: quickCaptureRepository,
    analyticsService: analytics,
    logger: logger,
    supabaseClient: client,
    attachmentService: attachmentService,
  );
});
