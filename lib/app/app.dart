import 'dart:async';

import 'package:flutter/services.dart';
import 'package:duru_notes/core/settings/preferences_initialization_provider.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/features/encryption/encryption_feature_flag.dart';
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show unifiedSyncServiceProvider, unifiedRealtimeServiceProvider;
import 'package:duru_notes/l10n/app_localizations.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/core/providers/security_providers.dart'
    show accountKeyServiceProvider;
import 'package:duru_notes/core/providers/search_providers.dart'
    show noteIndexerProvider;
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show folderHierarchyProvider, folderListProvider, noteFolderProvider;
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart'
    show
        notesPageProvider,
        hasMoreNotesProvider,
        currentFolderProvider,
        filterStateProvider,
        filteredNotesProvider,
        currentNotesProvider,
        notesLoadingProvider;
import 'package:duru_notes/features/notes/providers/notes_domain_providers.dart'
    show domainNotesProvider, domainNotesStreamProvider;
import 'package:duru_notes/features/tasks/providers/tasks_domain_providers.dart'
    show domainTasksProvider, domainTasksStreamProvider;
import 'package:duru_notes/features/folders/providers/folders_domain_providers.dart'
    show domainFoldersProvider, domainFoldersStreamProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show enhancedTaskServiceProvider, taskAnalyticsServiceProvider;
import 'package:duru_notes/features/settings/providers/settings_providers.dart'
    show themeModeProvider, localeProvider;
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show syncModeProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show
        templateCoreRepositoryProvider,
        domainTemplatesProvider,
        domainTemplatesStreamProvider;
import 'package:duru_notes/services/providers/services_providers.dart'
    show
        clipperInboxServiceProvider,
        pushNotificationServiceProvider,
        notificationHandlerServiceProvider,
        shareExtensionServiceProvider,
        quickCaptureServiceProvider,
        inboxManagementServiceProvider,
        inboxUnreadServiceProvider;
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/services/encryption_sync_service.dart';
import 'package:duru_notes/services/notification_handler_service.dart';
import 'package:duru_notes/services/quick_capture_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:duru_notes/services/providers/services_providers.dart'
    show encryptionSyncServiceProvider, purgeSchedulerServiceProvider;
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/theme/material3_theme.dart';
import 'package:duru_notes/ui/auth_screen.dart';
import 'package:duru_notes/ui/dialogs/encryption_setup_dialog.dart';
import 'package:duru_notes/ui/inbound_email_inbox_widget.dart';
import 'package:duru_notes/ui/app_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Main application widget with authentication flow
class App extends ConsumerWidget {
  const App({super.key, this.navigatorKey});
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings providers
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    const generatedSupportedLocales = AppLocalizations.supportedLocales;
    // If a saved locale isn't generated, fall back to system
    final effectiveLocale =
        (locale != null &&
            generatedSupportedLocales.any(
              (l) => l.languageCode == locale.languageCode,
            ))
        ? locale
        : null;

    // CRITICAL iOS FIX: Load user preferences after first frame
    // Phase 2 Fix: SharedPreferences is now preloaded in bootstrap, so loading
    // theme/locale preferences won't block with platform channel calls
    // This ensures UI renders immediately with defaults, then updates with saved preferences
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(themeModeProvider.notifier).loadThemeMode();
        ref.read(localeProvider.notifier).loadLocale();
      } catch (e) {
        debugPrint('[App] ⚠️ Error loading preferences: $e');
        // Non-critical - app continues with defaults
      }
    });

    return MaterialApp(
      title: 'Duru Notes',
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      locale: effectiveLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: generatedSupportedLocales,
      theme: DuruMaterial3Theme.lightTheme,
      darkTheme: DuruMaterial3Theme.darkTheme,
      home: AuthWrapper(navigatorKey: navigatorKey),
      debugShowCheckedModeBanner: false,
    );
  }
}

class UnlockPassphraseView extends ConsumerStatefulWidget {
  const UnlockPassphraseView({required this.onUnlocked, super.key});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<UnlockPassphraseView> createState() =>
      _UnlockPassphraseViewState();
}

class _UnlockPassphraseViewState extends ConsumerState<UnlockPassphraseView> {
  final _controller = TextEditingController();
  bool _isUnlocking = false;
  bool _isCrossDeviceEncryption = false;
  String _unlockMessage = 'Encryption Passphrase';

  @override
  void initState() {
    super.initState();
    _detectEncryptionType();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Detect whether user has cross-device encryption or device-specific encryption
  Future<void> _detectEncryptionType() async {
    if (!mounted) return;

    // Check if cross-device encryption is enabled via feature flag
    if (!EncryptionFeatureFlags.enableCrossDeviceEncryption) {
      setState(() {
        _isCrossDeviceEncryption = false;
        _unlockMessage = 'Encryption Passphrase';
      });
      return;
    }

    try {
      // Check if user has cross-device encryption set up on server
      final encryptionService = ref.read(encryptionSyncServiceProvider);
      final isSetupOnServer = await encryptionService.isEncryptionSetup();

      if (!isSetupOnServer && kDebugMode) {
        debugPrint(
          '[UnlockView] ⚠️ No remote AMK detected during unlock flow - falling back to device-specific mode',
        );
      }

      if (mounted) {
        setState(() {
          _isCrossDeviceEncryption = isSetupOnServer;
          _unlockMessage = isSetupOnServer
              ? 'Encryption Password'
              : 'Encryption Passphrase';
        });
      }

      if (kDebugMode) {
        debugPrint(
          '[UnlockView] Encryption type: ${_isCrossDeviceEncryption ? "cross-device" : "device-specific"}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UnlockView] Error detecting encryption type: $e');
      }
      // Fallback to device-specific on error
      if (mounted) {
        setState(() {
          _isCrossDeviceEncryption = false;
          _unlockMessage = 'Encryption Passphrase';
        });
      }
    }
  }

  Future<void> _handleUnlock() async {
    if (_isUnlocking || _controller.text.isEmpty) return;

    setState(() => _isUnlocking = true);

    try {
      if (_isCrossDeviceEncryption) {
        // Use cross-device encryption service
        await _unlockCrossDeviceEncryption();
      } else {
        // Use device-specific encryption service (fallback/legacy)
        await _unlockDeviceSpecificEncryption();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUnlocking = false);
      }
    }
  }

  /// Unlock using cross-device encryption (EncryptionSyncService)
  Future<void> _unlockCrossDeviceEncryption() async {
    try {
      final encryptionService = ref.read(encryptionSyncServiceProvider);
      await encryptionService.retrieveEncryption(_controller.text);

      if (mounted) {
        widget.onUnlocked();
      }
    } on EncryptionException catch (e) {
      if (kDebugMode) {
        debugPrint('[UnlockView] ❌ Cross-device unlock failed: ${e.message}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Unlock using device-specific encryption (AccountKeyService - legacy)
  Future<void> _unlockDeviceSpecificEncryption() async {
    final ok = await ref
        .read(accountKeyServiceProvider)
        .unlockAmkWithPassphrase(_controller.text);

    if (ok) {
      if (mounted) {
        widget.onUnlocked();
      }
    } else {
      if (kDebugMode) {
        debugPrint('[UnlockView] ❌ Device-specific unlock failed');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect passphrase'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unlock Encryption',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  enabled: !_isUnlocking,
                  decoration: InputDecoration(
                    labelText: _unlockMessage,
                    prefixIcon: const Icon(Icons.vpn_key),
                    helperText: _isCrossDeviceEncryption
                        ? 'Enter the encryption password you created'
                        : null,
                  ),
                  onSubmitted: (_) => _handleUnlock(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isUnlocking ? null : _handleUnlock,
                  child: _isUnlocking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isUnlocking
                      ? null
                      : () async {
                          // Clear both device-specific and cross-device encryption keys
                          await ref
                              .read(accountKeyServiceProvider)
                              .clearLocalAmk();

                          // Also clear cross-device encryption if enabled
                          if (EncryptionFeatureFlags
                              .enableCrossDeviceEncryption) {
                            try {
                              await ref
                                  .read(encryptionSyncServiceProvider)
                                  .clearLocalKeys();
                            } catch (e) {
                              if (kDebugMode) {
                                debugPrint(
                                  '[UnlockView] Error clearing cross-device keys: $e',
                                );
                              }
                            }
                          }

                          // CRITICAL SECURITY FIX: Clear local database before sign-out
                          // This prevents cross-user data leakage when a different user signs in
                          try {
                            final db = ref.read(appDbProvider);
                            await db.clearAll();
                            debugPrint(
                              '[UnlockView] ✅ Local database cleared on sign-out',
                            );
                          } catch (dbError) {
                            debugPrint(
                              '[UnlockView] ❌ Failed to clear database: $dbError',
                            );
                            // Continue with sign-out even if clear fails
                          }

                          // Reset security initialization
                          SecurityInitialization.reset();
                          debugPrint(
                            '[UnlockView] ✅ Security initialization reset',
                          );

                          await Supabase.instance.client.auth.signOut();
                        },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Represents the encryption gate state before entering the app shell
enum EncryptionGateState {
  ready, // AMK available locally - safe to enter app
  needsUnlock, // AMK exists remotely but needs passphrase to unlock locally
  needsSetup, // New user - must create AMK before continuing
}

/// Coordinates first-time AMK provisioning for new users without showing the legacy unlock screen
class NewUserEncryptionSetupGate extends ConsumerStatefulWidget {
  const NewUserEncryptionSetupGate({
    required this.onSetupComplete,
    required this.onSetupCancelled,
    super.key,
  });

  final VoidCallback onSetupComplete;
  final Future<void> Function() onSetupCancelled;

  @override
  ConsumerState<NewUserEncryptionSetupGate> createState() =>
      _NewUserEncryptionSetupGateState();
}

class _NewUserEncryptionSetupGateState
    extends ConsumerState<NewUserEncryptionSetupGate> {
  bool _launchedDialog = false;
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    // Launch setup dialog after first frame so build can complete
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchSetupDialog());
  }

  Future<void> _launchSetupDialog() async {
    if (_launchedDialog || !mounted) return;
    _launchedDialog = true;

    final logger = ref.read(loggerProvider);
    logger.info(
      '[EncryptionSetupGate] Launching initial encryption setup dialog',
    );

    final result = await showEncryptionSetupDialog(
      context,
      mode: EncryptionSetupMode.setup,
      allowCancel: false,
    );

    if (!mounted) return;

    if (result == true) {
      logger.info(
        '[EncryptionSetupGate] Encryption setup completed successfully',
      );
      setState(() {
        _finalizing = true;
      });
      widget.onSetupComplete();
    } else {
      logger.warning(
        '[EncryptionSetupGate] Encryption setup dismissed or failed; initiating cancellation flow',
      );
      // User cancelled or dialog closed - return to auth screen
      await widget.onSetupCancelled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _finalizing
                  ? 'Securing your account...'
                  : 'Preparing encryption setup...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper that handles authentication state
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper>
    with WidgetsBindingObserver {
  bool _hasTriggeredInitialSync = false;
  ClipperInboxService? _clipperService;
  NotificationHandlerService? _notificationHandler;
  StreamSubscription<NotificationPayload>? _notificationTapSubscription;
  Future<void>? _pendingSecurityInitialization;

  // CRITICAL FIX: Key to force FutureBuilder re-run after unlock
  int _amkCheckKey = 0;
  bool _signOutCleanupScheduled = false;
  bool _signOutCleanupRunning = false;

  // BLACK SCREEN FIX: Track if user was previously authenticated
  // This prevents cleanup from running on cold start (when there was never a session)
  bool _hadPreviousSession = false;

  // User-scoped cache for remote AMK existence (positive results only)
  // Auto-cleared when user ID changes to prevent cross-user cache leakage
  String? _cachedUserId;
  bool? _cachedRemoteAmkExists;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupDeepLinkHandler();
  }

  /// Setup deep link handler for widget deep links
  void _setupDeepLinkHandler() {
    const channel = MethodChannel('com.fittechs.durunotes/deep_links');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'handleDeepLink') {
        final url = call.arguments as String?;
        if (url != null) {
          await _handleDeepLink(url);
        }
      }
    });
  }

  /// Handle deep link from widget
  Future<void> _handleDeepLink(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'durunotes') {
      debugPrint('❌ [App] Invalid scheme: ${uri.scheme}');
      return;
    }

    // Wait a frame to ensure UI is ready
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    switch (uri.host) {
      case 'note':
        // Open specific note: durunotes://note/[id]
        final noteId = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : null;
        if (noteId != null) {
          _openNote(noteId);
        }
        break;
      case 'new-note':
        // Create new note: durunotes://new-note
        _createNewNote();
        break;
      case 'quick-capture':
        // Open quick capture: durunotes://quick-capture
        _openQuickCapture();
        break;
      default:
        debugPrint('❌ [App] Unknown deep link host: ${uri.host}');
    }
  }

  /// Navigate to specific note
  void _openNote(String noteId) {
    if (!mounted) return;

    // Navigate to note editor with specific note ID
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ModernEditNoteScreen(noteId: noteId),
      ),
    );
  }

  /// Create new note
  void _createNewNote() {
    if (!mounted) return;

    // Navigate to new note screen
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ModernEditNoteScreen(),
      ),
    );
  }

  /// Open quick capture
  void _openQuickCapture() {
    if (!mounted) return;

    // Navigate to new note screen (same as create new note for now)
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ModernEditNoteScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _clipperService?.stop();
    _notificationTapSubscription?.cancel();
    _notificationHandler?.dispose();
    _clearRemoteAmkCache(); // Clear cache on widget disposal
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Trigger sync when app resumes from background (if in automatic mode)
    if (state == AppLifecycleState.resumed) {
      _performAppResumeSync();
    }
  }

  /// Perform sync when app resumes and refresh UI if needed
  Future<void> _performAppResumeSync() async {
    // Guard: skip if not authenticated yet
    if (Supabase.instance.client.auth.currentUser == null) return;

    // Check if widget is still mounted
    if (!mounted) return;

    try {
      await _ensureSecurityServicesInitialized();
    } catch (error, stackTrace) {
      try {
        final logger = ref.read(loggerProvider);
        logger.error(
          '❌ [App] Skipping resume sync - security services unavailable',
          error: error,
          stackTrace: stackTrace,
        );
      } catch (_) {
        debugPrint(
          '❌ [App] Skipping resume sync - security services unavailable: $error\n$stackTrace',
        );
      }
      return;
    }
    if (!mounted) return;
    if (!SecurityInitialization.isInitialized) {
      debugPrint(
        '⏳ [App] Security services still initializing on resume, skipping sync.',
      );
      return;
    }

    try {
      final syncModeNotifier = ref.read(syncModeProvider.notifier);
      await syncModeNotifier.performInitialSyncIfAuto();
    } on StateError catch (error) {
      if (error.message.contains('[notesCoreRepositoryProvider]')) {
        debugPrint(
          '⏳ [App] Sync service requested before security init; will retry on next resume.',
        );
        return;
      }
      rethrow;
    }

    // Check mounted after async operation
    if (!mounted) return;

    SyncMode syncMode;
    try {
      syncMode = ref.read(syncModeProvider);
    } on StateError catch (error) {
      if (error.message.contains('[notesCoreRepositoryProvider]')) {
        debugPrint(
          '⏳ [App] Sync mode unavailable before security init; skipping refresh.',
        );
        return;
      }
      rethrow;
    }

    if (syncMode == SyncMode.automatic) {
      await ref.read(notesPageProvider.notifier).refresh();

      // Load additional pages if there are more notes
      while (ref.read(hasMoreNotesProvider)) {
        await ref.read(notesPageProvider.notifier).loadMore();
      }

      // Refresh folders as well
      await ref.read(folderHierarchyProvider.notifier).loadFolders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authClient = Supabase.instance.client.auth;
    debugPrint('[AuthWrapper] build starting');
    return StreamBuilder<AuthState>(
      stream: authClient.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        authClient.currentSession,
      ),
      builder: (context, snapshot) {
        debugPrint(
          '[AuthWrapper] Stream state=${snapshot.connectionState} '
          'hasData=${snapshot.hasData} session=${snapshot.data?.session != null}',
        );
        // Show loading while checking auth state
        final isInitialPending =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (isInitialPending) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'Loading Duru Notes...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if user is authenticated
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // BLACK SCREEN FIX: Track that user was authenticated
          // This allows us to detect actual logout vs cold start
          _hadPreviousSession = true;
          _signOutCleanupScheduled = false;

          // GDPR: Check if user has been anonymized
          return FutureBuilder<bool>(
            future: _checkAnonymizationStatus(),
            builder: (context, anonymizedSnap) {
              if (anonymizedSnap.connectionState != ConnectionState.done) {
                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Verifying account status...'),
                      ],
                    ),
                  ),
                );
              }

              final isAnonymized = anonymizedSnap.data ?? false;
              if (isAnonymized) {
                // CRITICAL: User has been anonymized - IMMEDIATELY force logout
                // Do NOT wait for user interaction, do NOT show encryption screens
                debugPrint('[GDPR] ❌ Account is anonymized - forcing immediate logout');

                // Force logout immediately
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await Supabase.instance.client.auth.signOut();
                    debugPrint('[GDPR] ✅ Forced logout successful');
                  } catch (e) {
                    debugPrint('[GDPR] ⚠️ Forced logout error: $e');
                    // Even if logout fails, show the dialog
                  }
                  if (context.mounted) {
                    _showAccountDeletedDialog(context);
                  }
                });

                // Show blocking screen immediately
                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block, size: 64, color: Colors.red),
                        SizedBox(height: 24),
                        Text(
                          'Account Deleted',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('This account has been permanently deleted.'),
                        SizedBox(height: 16),
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Signing out...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              // Check if AMK is present locally
              return FutureBuilder<EncryptionGateState>(
            key: ValueKey(_amkCheckKey),
            future: _checkForAmkWithRetry(),
            builder: (context, amkSnap) {
              if (amkSnap.connectionState != ConnectionState.done) {
                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Initializing encryption...'),
                      ],
                    ),
                  ),
                );
              }

              if (amkSnap.hasError) {
                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        const Text('Encryption check failed.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _amkCheckKey++;
                              });
                            }
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final gateState = amkSnap.data ?? EncryptionGateState.needsSetup;

              if (gateState == EncryptionGateState.needsSetup) {
                return NewUserEncryptionSetupGate(
                  onSetupComplete: () {
                    if (mounted) {
                      _clearRemoteAmkCache(); // Clear cache after provisioning
                      setState(() {
                        _amkCheckKey++;
                      });
                    }
                  },
                  onSetupCancelled: () async {
                    _clearRemoteAmkCache(); // Clear cache on logout
                    await Supabase.instance.client.auth.signOut();
                  },
                );
              }

              if (gateState == EncryptionGateState.needsUnlock) {
                return UnlockPassphraseView(
                  onUnlocked: () {
                    if (mounted) {
                      _clearRemoteAmkCache(); // Clear cache after successful unlock
                      setState(() {
                        _amkCheckKey++;
                      });
                    }
                  },
                );
              }

              // Wait for security services initialization before showing app
              // This ensures SecureApiWrapper instances get the global RateLimitingMiddleware
              // instead of creating their own local instances (which breaks rate limiting)
              return FutureBuilder<void>(
                future: _ensureSecurityServicesInitialized(),
                builder: (context, securitySnapshot) {
                  if (securitySnapshot.connectionState !=
                      ConnectionState.done) {
                    return Scaffold(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      body: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Initializing security services...'),
                          ],
                        ),
                      ),
                    );
                  }

                  if (securitySnapshot.hasError) {
                    return Scaffold(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Security initialization failed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please restart the app or sign out and sign in again',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () async {
                                await Supabase.instance.client.auth.signOut();
                              },
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // SecurityInitialization is complete - show main app
                  _maybePerformInitialSync();

                  // PHASE 3 FIX: Optimize post-frame callbacks to reduce queue saturation
                  // Only keep critical operations in post-frame callback
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    debugPrint(
                      '🔔 Attempting push token registration after authentication...',
                    );
                    _registerPushTokenInBackground();

                    // Initialize notification handler service (critical for push)
                    _initializeNotificationHandler();
                  });

                  // Defer non-critical operations to reduce startup contention
                  Future<void>.delayed(const Duration(milliseconds: 200), () {
                    if (!mounted) return;
                    debugPrint('🔄 Initializing non-critical services (share extension, widget cache)');

                    // Initialize share extension service (requires repositories)
                    _initializeShareExtension();

                    // Sync widget cache after authentication (iOS/Android widgets)
                    _syncWidgetCacheInBackground();
                  });

                  // CRITICAL FIX: Removed connectivity initialization
                  // The connectivity provider was causing iOS crashes due to synchronous
                  // platform channel calls during startup. Let it initialize lazily when needed.
                  return const AppShell();
                },
              );
            },
          );
            },
          );
        } else {
          // User is not authenticated - show login screen
          //
          // CRITICAL SECURITY: Clear local database to prevent data leakage between users
          // This is a critical safeguard in case sign-out didn't clear the database properly
          //
          // BLACK SCREEN FIX: Only run cleanup if user was previously authenticated
          // This prevents cleanup from running on cold start (which causes provider invalidation
          // and triggers a massive rebuild that destroys the AuthScreen, leaving black screen)
          //
          // Scenarios:
          // - Cold start (no previous session): Skip cleanup, show AuthScreen immediately
          // - Logout (had previous session): Run cleanup to clear data before showing AuthScreen
          if (!_signOutCleanupScheduled && _hadPreviousSession) {
            _signOutCleanupScheduled = true;
            debugPrint('[AuthWrapper] Detected logout - scheduling database cleanup');
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              _scheduleSignedOutCleanup(ref);
            });
          } else if (!_hadPreviousSession) {
            debugPrint('[AuthWrapper] Cold start detected - skipping cleanup to prevent black screen');
          }

          _hasTriggeredInitialSync = false; // Reset flag when logged out
          SecurityInitialization.dispose();
          _pendingSecurityInitialization = null;
          _clipperService?.stop(); // Stop the clipper service when logged out
          _clipperService = null;

          // Clean up notification handler when logged out
          _notificationTapSubscription?.cancel();
          _notificationTapSubscription = null;
          _notificationHandler?.dispose();
          _notificationHandler = null;

          return const AuthScreen();
        }
      },
    );
  }

  void _scheduleSignedOutCleanup(WidgetRef ref) {
    if (_signOutCleanupRunning) {
      debugPrint(
        '[AuthWrapper] Logout cleanup already running - skipping duplicate',
      );
      return;
    }
    _signOutCleanupRunning = true;
    Future.microtask(() async {
      try {
        final db = ref.read(appDbProvider);
        await db.clearAll();
        debugPrint(
          '[AuthWrapper] ✅ Database cleared on logout - preventing data leakage',
        );
        _invalidateAllProviders(ref);
        debugPrint(
          '[AuthWrapper] ✅ All providers invalidated - cached state cleared',
        );
      } catch (e) {
        debugPrint('[AuthWrapper] ⚠️ Error clearing database on logout: $e');
      } finally {
        _signOutCleanupRunning = false;
      }
    });
  }

  /// Trigger initial sync if in automatic mode (only once per session)
  void _maybePerformInitialSync() {
    if (!_hasTriggeredInitialSync) {
      _hasTriggeredInitialSync = true;

      // Use a post-frame callback to ensure providers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Check if widget is still mounted before using ref
        if (!mounted) return;

        // CRITICAL SECURITY: Validate no data leakage from previous user
        // Check if local database has notes with a different user ID
        try {
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId != null) {
            final db = ref.read(appDbProvider);
            final localNotes =
                await (db.select(db.localNotes)
                      ..where((t) => t.userId.isNotNull())
                      ..limit(1))
                    .get();

            if (localNotes.isNotEmpty) {
              final firstNoteUserId = localNotes.first.userId;
              if (firstNoteUserId != null && firstNoteUserId != currentUserId) {
                debugPrint(
                  '[AuthWrapper] 🚨 CRITICAL: Data from different user detected!',
                );
                debugPrint('[AuthWrapper] Current user: $currentUserId');
                debugPrint('[AuthWrapper] Local data user: $firstNoteUserId');
                debugPrint(
                  '[AuthWrapper] 🧹 Clearing database to prevent data leakage...',
                );

                await db.clearAll();

                debugPrint(
                  '[AuthWrapper] ✅ Database cleared - data leakage prevented',
                );
              }
            }
          }
        } catch (e, stack) {
          debugPrint(
            '[AuthWrapper] ⚠️ Error checking for data leakage: $e\n$stack',
          );
          // Continue - this is a safety check, not critical path
        }

        if (!mounted) return;

        try {
          await _ensureSecurityServicesInitialized();
        } catch (error, stackTrace) {
          try {
            final logger = ref.read(loggerProvider);
            logger.error(
              '❌ [App] Aborting initial sync - security services unavailable',
              error: error,
              stackTrace: stackTrace,
            );
          } catch (_) {
            debugPrint(
              '❌ [App] Aborting initial sync - security services unavailable: $error\n$stackTrace',
            );
          }
          return;
        }
        if (!mounted) return;

        if (!SecurityInitialization.isInitialized) {
          debugPrint(
            '⏳ [App] Security services still initializing; postponing initial sync.',
          );
          _hasTriggeredInitialSync = false;
          return;
        }

        // Initialize user preferences (sync local to database) - fire-and-forget
        // This ensures push notifications use correct language from day 1
        try {
          ref.read(preferencesInitializationProvider);
        } catch (e) {
          // Non-critical - preferences will sync when user changes settings
          debugPrint('⚠️ [App] Preferences initialization deferred: $e');
        }

        // Start the clipper inbox service after authentication
        try {
          final logger = ref.read(loggerProvider);
          logger.info('🔄 [App] Attempting to start ClipperInboxService...');

          _clipperService = ref.read(clipperInboxServiceProvider);
          if (_clipperService == null) {
            logger.error('❌ [App] ClipperInboxService provider returned null');
          } else {
            _clipperService!.start();
            logger.info('✅ [App] ClipperInboxService started successfully');
          }
        } catch (e, stackTrace) {
          // Use proper logger instead of debugPrint
          try {
            final logger = ref.read(loggerProvider);
            logger.error(
              '❌ [App] Failed to start clipper inbox service',
              error: e,
              stackTrace: stackTrace,
            );
          } catch (_) {
            // Fallback if logger fails
            debugPrint(
              '❌ Failed to start clipper inbox service: $e\n$stackTrace',
            );
          }
          // Service is optional, so continue app initialization
        }

        // Check mounted again after async operation
        if (!mounted) return;

        try {
          final syncModeNotifier = ref.read(syncModeProvider.notifier);
          await syncModeNotifier.performInitialSyncIfAuto();
        } on StateError catch (error) {
          if (error.message.contains('[notesCoreRepositoryProvider]')) {
            debugPrint(
              '⏳ [App] Sync service requested before security init; retrying next frame.',
            );
            _hasTriggeredInitialSync = false;
            return;
          }
          rethrow;
        }

        // Check mounted before continuing
        if (!mounted) return;

        // Refresh notes if auto-sync ran
        SyncMode syncMode;
        try {
          syncMode = ref.read(syncModeProvider);
        } on StateError catch (error) {
          if (error.message.contains('[notesCoreRepositoryProvider]')) {
            debugPrint(
              '⏳ [App] Sync mode unavailable before security init; skipping refresh.',
            );
            _hasTriggeredInitialSync = false;
            return;
          }
          rethrow;
        }

        if (syncMode == SyncMode.automatic) {
          await ref.read(notesPageProvider.notifier).refresh();

          // Also load folders after sync
          await ref.read(folderHierarchyProvider.notifier).loadFolders();
        }

        // Check mounted before final operations
        if (!mounted) return;

        // Production-grade boot sync: if this device has no local notes yet, force a full pull once
        try {
          final db = ref.read(appDbProvider);
          final existing = await db.allNotes();
          if (existing.isEmpty) {
            // Check mounted before long-running operations
            if (!mounted) return;

            final syncService = ref.read(unifiedSyncServiceProvider);
            try {
              await syncService.syncAll();
            } catch (error) {
              // Handle sync errors silently - errors are already logged by UnifiedSyncService
              // Could show a user notification here if needed
            }

            // Final mounted check
            if (!mounted) return;
            await ref.read(notesPageProvider.notifier).refresh();

            // Load folders after initial sync
            await ref.read(folderHierarchyProvider.notifier).loadFolders();
          }
        } catch (_) {
          // Ignore boot sync errors; user can trigger manual sync later
        }
      });
    }
  }

  /// Check for AMK with retries to handle timing issues after signup.
  /// Returns [EncryptionGateState] to indicate whether the user is ready,
  /// needs to unlock an existing AMK, or must run initial setup.
  Future<EncryptionGateState> _checkForAmkWithRetry() async {
    final totalStopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('[AuthWrapper] ⏱️  Starting AMK check with retry logic');
    }

    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 200); // Reduced from 500ms for faster UX

    for (var i = 0; i < maxRetries; i++) {
      if (kDebugMode) {
        debugPrint('[AuthWrapper] ⏱️  Retry attempt ${i + 1}/$maxRetries');
      }

      if (await _hasLocalAmk()) {
        totalStopwatch.stop();
        if (kDebugMode) {
          debugPrint('[AuthWrapper] ✅ Local AMK available (total time: ${totalStopwatch.elapsedMilliseconds}ms)');
        }
        return EncryptionGateState.ready;
      }

      if (await _remoteAmkExists()) {
        totalStopwatch.stop();
        if (kDebugMode) {
          debugPrint(
            '[AuthWrapper] ⚠️ Remote AMK detected - user must unlock to restore it (total time: ${totalStopwatch.elapsedMilliseconds}ms)',
          );
        }
        return EncryptionGateState.needsUnlock;
      }

      if (i < maxRetries - 1) {
        if (kDebugMode) {
          debugPrint('[AuthWrapper] ⏱️  Waiting ${retryDelay.inMilliseconds}ms before retry...');
        }
        await Future<void>.delayed(retryDelay);
      }
    }

    if (EncryptionFeatureFlags.enableCrossDeviceEncryption) {
      if (await _remoteAmkExists()) {
        totalStopwatch.stop();
        if (kDebugMode) {
          debugPrint(
            '[AuthWrapper] ⚠️ Remote AMK detected after retries - requiring unlock (total time: ${totalStopwatch.elapsedMilliseconds}ms)',
          );
        }
        return EncryptionGateState.needsUnlock;
      }

      totalStopwatch.stop();
      if (kDebugMode) {
        debugPrint(
          '[AuthWrapper] ❌ No AMK found locally or remotely - provisioning required (total time: ${totalStopwatch.elapsedMilliseconds}ms)',
        );
      }
      return EncryptionGateState.needsSetup;
    }

    // Legacy device-specific encryption fallback
    totalStopwatch.stop();
    if (kDebugMode) {
      debugPrint('[AuthWrapper] ⏱️  Returning needsUnlock (legacy fallback, total time: ${totalStopwatch.elapsedMilliseconds}ms)');
    }
    return EncryptionGateState.needsUnlock;
  }

  /// GDPR: Check if user account has been anonymized
  /// Returns true if user is anonymized and should be logged out
  Future<bool> _checkAnonymizationStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        return false; // Not logged in
      }

      debugPrint('[GDPR] Checking anonymization status for user $userId');

      // Call the database function to get anonymization status
      final response = await Supabase.instance.client
          .rpc<Map<String, dynamic>>('get_anonymization_status_summary', params: {'check_user_id': userId});

      if (response == null) {
        debugPrint('[GDPR] No anonymization status found');
        return false;
      }

      final isAnonymized = response['is_anonymized'] as bool? ?? false;
      final anonymizationCompletedAt = response['anonymization_completed_at'] as String?;
      final authDeletionCompletedAt = response['auth_deletion_completed_at'] as String?;

      if (isAnonymized) {
        debugPrint(
          '[GDPR] ⚠️  User is anonymized! '
          'Completed at: $anonymizationCompletedAt, '
          'Auth deleted at: $authDeletionCompletedAt',
        );
      }

      return isAnonymized;
    } catch (error) {
      debugPrint('[GDPR] Error checking anonymization status: $error');
      // On error, assume not anonymized to avoid blocking legitimate users
      // RLS policies will still block access if truly anonymized
      return false;
    }
  }

  /// Show "Account Deleted" dialog and force logout
  void _showAccountDeletedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Account Permanently Deleted'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This account has been permanently deleted and cannot be accessed.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('What happened:'),
            SizedBox(height: 8),
            Text('• All encryption keys were destroyed'),
            Text('• All data was anonymized'),
            Text('• Your account was removed from the system'),
            SizedBox(height: 16),
            Text(
              'This action is irreversible and complies with GDPR Article 17 (Right to Erasure).',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // User is already signed out at this point
              debugPrint('[GDPR] User acknowledged account deletion');
            },
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  Future<bool> _hasLocalAmk() async {
    final stopwatch = Stopwatch()..start();

    // Cross-device AMK stored via EncryptionSyncService
    if (EncryptionFeatureFlags.enableCrossDeviceEncryption) {
      try {
        final encryptionService = ref.read(encryptionSyncServiceProvider);
        final localAmk = await encryptionService.getLocalAmk();
        if (localAmk != null) {
          stopwatch.stop();
          if (kDebugMode) {
            debugPrint('[AuthWrapper] ⏱️  _hasLocalAmk() → true (cross-device, ${stopwatch.elapsedMilliseconds}ms)');
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthWrapper] Error checking local cross-device AMK: $e');
        }
      }
    }

    // Legacy device-specific AMK
    try {
      final localLegacyAmk = await ref
          .read(accountKeyServiceProvider)
          .getLocalAmk();
      stopwatch.stop();
      final result = localLegacyAmk != null;
      if (kDebugMode) {
        debugPrint('[AuthWrapper] ⏱️  _hasLocalAmk() → $result (legacy, ${stopwatch.elapsedMilliseconds}ms)');
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[AuthWrapper] Error checking local legacy AMK: $e (${stopwatch.elapsedMilliseconds}ms)');
      }
    }
    stopwatch.stop();
    if (kDebugMode) {
      debugPrint('[AuthWrapper] ⏱️  _hasLocalAmk() → false (${stopwatch.elapsedMilliseconds}ms)');
    }
    return false;
  }

  Future<bool> _remoteAmkExists() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Auto-clear cache if user changed (handles signOut, new login, token refresh)
    if (_cachedUserId != currentUserId) {
      if (kDebugMode && _cachedRemoteAmkExists != null) {
        debugPrint('[AuthWrapper] 🔄 User changed ($_cachedUserId → $currentUserId), clearing cache');
      }
      _cachedRemoteAmkExists = null;
      _cachedUserId = currentUserId;
    }

    // Check user-scoped cache (positive results only)
    if (_cachedRemoteAmkExists == true) {
      if (kDebugMode) {
        debugPrint('[AuthWrapper] ⏱️  _remoteAmkExists() → true (cached for user $currentUserId, 0ms)');
      }
      return true;
    }

    final totalStopwatch = Stopwatch()..start();

    if (!EncryptionFeatureFlags.enableCrossDeviceEncryption) {
      return false;
    }

    if (currentUserId == null) return false;

    if (kDebugMode) {
      debugPrint('[AuthWrapper] ⏱️  Querying user_encryption_keys and user_keys tables in parallel...');
    }

    // Query both tables in parallel to reduce latency
    final results = await Future.wait([
      // Query 1: user_encryption_keys (cross-device)
      Supabase.instance.client
          .from('user_encryption_keys')
          .select('user_id')
          .eq('user_id', currentUserId)
          .maybeSingle()
          .catchError((Object e) {
        if (kDebugMode) {
          debugPrint(
            '[AuthWrapper] Error checking remote AMK existence (user_encryption_keys): $e',
          );
        }
        return null;
      }),
      // Query 2: user_keys (legacy)
      Supabase.instance.client
          .from('user_keys')
          .select('user_id')
          .eq('user_id', currentUserId)
          .maybeSingle()
          .catchError((Object e) {
        if (kDebugMode) {
          debugPrint(
            '[AuthWrapper] Error checking remote AMK existence (user_keys fallback): $e',
          );
        }
        return null;
      }),
    ]);

    totalStopwatch.stop();

    final hasEncryptionKey = results[0] != null;
    final hasLegacyKey = results[1] != null;
    final exists = hasEncryptionKey || hasLegacyKey;

    // Cache positive results only (prevents stale "needs setup" on cross-device restore)
    // User ID already set at start of method, so cache is user-scoped
    if (exists) {
      _cachedRemoteAmkExists = true;
      if (kDebugMode) {
        debugPrint('[AuthWrapper] 💾 Cached positive AMK existence result for user $currentUserId');
      }
    }

    if (kDebugMode) {
      final source = hasEncryptionKey ? 'user_encryption_keys' : (hasLegacyKey ? 'user_keys' : 'none');
      debugPrint('[AuthWrapper] ⏱️  _remoteAmkExists() → $exists (source: $source, total ${totalStopwatch.elapsedMilliseconds}ms)');
    }

    return exists;
  }

  /// Clear the remote AMK cache.
  /// Called on logout, successful provisioning, successful unlock, or widget disposal.
  void _clearRemoteAmkCache() {
    if (kDebugMode && _cachedRemoteAmkExists != null) {
      debugPrint('[AuthWrapper] 🗑️  Clearing remote AMK cache for user $_cachedUserId');
    }
    _cachedRemoteAmkExists = null;
    _cachedUserId = null;
  }

  Future<void> _ensureSecurityServicesInitialized() {
    if (SecurityInitialization.isInitialized) {
      return Future.value();
    }

    return _pendingSecurityInitialization ??= _initializeSecurityServices();
  }

  Future<void> _initializeSecurityServices() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      throw StateError(
        'Cannot initialize security services without authenticated user',
      );
    }

    final currentSession = client.auth.currentSession;

    try {
      await SecurityInitialization.initialize(
        userId: currentUser.id,
        sessionId: currentSession?.accessToken,
        debugMode: kDebugMode,
      );
      await _mirrorCrossDeviceAmk();
      // Ensure repository providers retry after security services become available
      ref.invalidate(notesCoreRepositoryProvider);
      ref.invalidate(folderCoreRepositoryProvider);
      ref.invalidate(templateCoreRepositoryProvider);
      ref.invalidate(taskCoreRepositoryProvider);
      unawaited(_runAutomaticTrashPurge());
    } catch (error, stackTrace) {
      try {
        final logger = ref.read(loggerProvider);
        logger.error(
          '❌ [Security] Failed to initialize security services',
          error: error,
          stackTrace: stackTrace,
        );
      } catch (_) {
        debugPrint(
          '❌ [Security] Failed to initialize security services: $error\n$stackTrace',
        );
      }
      rethrow;
    } finally {
      _pendingSecurityInitialization = null;
    }
  }

  Future<void> _mirrorCrossDeviceAmk() async {
    try {
      final encryptionSync = ref.read(encryptionSyncServiceProvider);
      final Uint8List? amk = await encryptionSync.getLocalAmk();
      if (amk != null && amk.isNotEmpty) {
        await ref.read(accountKeyServiceProvider).setLocalAmk(amk);
        debugPrint(
          '[AuthWrapper] 🔐 Mirrored cross-device AMK into AccountKeyService',
        );
      }
    } catch (error, stack) {
      debugPrint(
        '[AuthWrapper] ⚠️ Failed to mirror cross-device AMK: $error\n$stack',
      );
    }
  }

  Future<void> _runAutomaticTrashPurge() async {
    try {
      await ref.read(purgeSchedulerServiceProvider).checkAndPurgeOnStartup();
    } catch (error, stack) {
      try {
        final logger = ref.read(loggerProvider);
        logger.warning(
          'Automatic trash purge failed',
          data: {'error': error.toString(), 'stack': stack.toString()},
        );
      } catch (_) {
        debugPrint('Automatic trash purge failed: $error\n$stack');
      }
    }
  }

  Future<void> _registerPushTokenInBackground() async {
    if (!mounted) return;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint('🔔 Skipping push token registration - user signed out');
      return;
    }
    // Register push token in background to not block UI
    debugPrint('🔔 Starting push token registration...');
    try {
      final pushService = ref.read(pushNotificationServiceProvider);

      // CRITICAL FIX: Initialize service explicitly here (after unlock)
      // Provider no longer auto-initializes to avoid permission popup before unlock
      await pushService.initialize();

      debugPrint('🔔 Push service obtained, calling registerWithBackend...');
      final result = await pushService.registerWithBackend();
      if (result.success) {
        debugPrint('✅ Push token registered successfully!');
        if (result.token != null) {
          debugPrint('📱 Token: ${result.token!.substring(0, 30)}...');
        }
      } else {
        debugPrint('❌ Push token registration failed: ${result.error}');
      }
    } catch (e, stack) {
      // Log error but don't show to user - push registration failure shouldn't block app usage
      debugPrint('❌ Failed to register push token: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> _initializeNotificationHandler() async {
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      debugPrint('🔔 Skipping notification handler init - user signed out');
      return;
    }
    try {
      debugPrint('🔔 Initializing notification handler service...');

      // Get the notification handler service
      _notificationHandler = ref.read(notificationHandlerServiceProvider);

      // Initialize the service (sets up Firebase message handlers)
      await _notificationHandler!.initialize();

      // Subscribe to notification tap events for navigation
      _notificationTapSubscription = _notificationHandler!.onNotificationTap
          .listen(_handleNotificationTap);

      debugPrint('✅ Notification handler service initialized successfully');
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize notification handler: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> _initializeShareExtension() async {
    if (!mounted) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      debugPrint('📱 Skipping share extension init - user signed out');
      return;
    }

    if (!SecurityInitialization.isInitialized) {
      debugPrint(
        '📱 Awaiting security services before share extension init...',
      );
      try {
        await _ensureSecurityServicesInitialized();
      } catch (e, stack) {
        debugPrint(
          '❌ Share extension init blocked - security initialization failed: $e',
        );
        debugPrint('Stack trace: $stack');
        return;
      }

      if (!mounted || client.auth.currentUser == null) {
        debugPrint(
          '📱 Share extension init cancelled - widget disposed or user signed out',
        );
        return;
      }

      if (!SecurityInitialization.isInitialized) {
        debugPrint(
          '❌ Share extension init aborted - security services still unavailable',
        );
        return;
      }
    }

    try {
      debugPrint('📱 Initializing share extension service...');

      ShareExtensionService shareExtensionService;
      try {
        shareExtensionService = ref.read(shareExtensionServiceProvider);
      } on StateError catch (error) {
        if (error.message.contains('[notesCoreRepositoryProvider]')) {
          debugPrint(
            '📱 Share extension init skipped - repositories unavailable before security init.',
          );
          return;
        }
        rethrow;
      }
      await shareExtensionService.initialize();

      debugPrint('✅ Share extension service initialized successfully');
    } catch (e, stack) {
      // Log error but don't block app - share extension is optional
      debugPrint('❌ Failed to initialize share extension service: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> _syncWidgetCacheInBackground() async {
    if (!mounted) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      debugPrint('📱 Skipping widget cache sync - user signed out');
      return;
    }

    if (!SecurityInitialization.isInitialized) {
      debugPrint('📱 Awaiting security services before widget cache sync...');
      try {
        await _ensureSecurityServicesInitialized();
      } catch (e, stack) {
        debugPrint(
          '❌ Widget cache sync blocked - security initialization failed: $e',
        );
        debugPrint('Stack trace: $stack');
        return;
      }

      if (!mounted || client.auth.currentUser == null) {
        debugPrint(
          '📱 Widget cache sync cancelled - widget disposed or user signed out',
        );
        return;
      }

      if (!SecurityInitialization.isInitialized) {
        debugPrint(
          '❌ Widget cache sync aborted - security services still unavailable',
        );
        return;
      }
    }

    try {
      debugPrint('📱 Syncing widget cache after authentication...');

      QuickCaptureService quickCaptureService;
      try {
        quickCaptureService = ref.read(quickCaptureServiceProvider);
      } on StateError catch (error) {
        if (error.message.contains('[notesCoreRepositoryProvider]') ||
            error.message.contains('[quickCaptureRepositoryProvider]')) {
          debugPrint(
            '📱 Widget cache sync skipped - repositories unavailable before security init.',
          );
          return;
        }
        rethrow;
      }

      // Update widget cache to sync current user data to iOS/Android widget
      await quickCaptureService.updateWidgetCache();

      debugPrint('✅ Widget cache synced successfully');
    } catch (e, stack) {
      // Log error but don't block app - widget sync is optional
      debugPrint('❌ Failed to sync widget cache: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  void _handleNotificationTap(NotificationPayload payload) {
    debugPrint('📱 Handling notification tap: ${payload.eventType}');

    // Get the navigator from the global key if available
    final navigatorKey = widget.navigatorKey;
    if (navigatorKey?.currentState == null) {
      debugPrint('⚠️ Navigator not available, cannot navigate');
      return;
    }

    final navigator = navigatorKey!.currentState!;

    // Navigate based on event type
    switch (payload.eventType) {
      case 'email_received':
        debugPrint('📧 Navigating to email inbox');
        navigator.push(
          MaterialPageRoute<void>(
            builder: (context) => const InboundEmailInboxWidget(),
          ),
        );
        break;

      case 'web_clip_saved':
        // Navigate to the web clip note if we have a note ID
        final noteId = payload.data['note_id'] as String?;
        if (noteId != null) {
          _navigateToNote(navigator, noteId);
        } else {
          // Just go to notes list
          debugPrint('📝 Web clip saved, returning to notes list');
        }
        break;

      case 'note_shared':
        // Navigate to the shared note
        final noteId = payload.data['note_id'] as String?;
        if (noteId != null) {
          debugPrint('🔗 Navigating to shared note: $noteId');
          _navigateToNote(navigator, noteId);
        }
        break;

      case 'reminder_due':
        // Navigate to the note with the reminder
        final noteId = payload.data['note_id'] as String?;
        if (noteId != null) {
          debugPrint('⏰ Navigating to note with reminder: $noteId');
          _navigateToNote(navigator, noteId);
        }
        break;

      default:
        debugPrint('⚠️ Unknown notification event type: ${payload.eventType}');
    }
  }

  Future<void> _navigateToNote(NavigatorState navigator, String noteId) async {
    try {
      // Load the note from the repository
      final repo = ref.read(notesCoreRepositoryProvider);
      final note = await repo.getNoteById(noteId);

      if (note != null) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (context) => ModernEditNoteScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialBody: note.body,
            ),
          ),
        );
      } else {
        debugPrint('⚠️ Note not found: $noteId');
      }
    } catch (e) {
      debugPrint('❌ Error navigating to note: $e');
    }
  }

  /// CRITICAL SECURITY: Invalidate all providers to prevent data leakage between users
  ///
  /// When User A logs out and User B logs in, Riverpod providers can retain
  /// User A's cached data. This method invalidates all providers that could
  /// contain user-specific data.
  ///
  /// Called during logout to ensure clean state for next user.
  void _invalidateAllProviders(WidgetRef ref) {
    try {
      // Repository providers - hold database query results
      ref.invalidate(notesCoreRepositoryProvider);
      ref.invalidate(taskCoreRepositoryProvider);
      ref.invalidate(folderCoreRepositoryProvider);
      ref.invalidate(templateCoreRepositoryProvider);

      // Domain providers - stream providers that cache entities
      ref.invalidate(domainNotesProvider);
      ref.invalidate(domainNotesStreamProvider);
      ref.invalidate(domainTasksProvider);
      ref.invalidate(domainTasksStreamProvider);
      ref.invalidate(domainFoldersProvider);
      ref.invalidate(domainFoldersStreamProvider);
      ref.invalidate(domainTemplatesProvider);
      ref.invalidate(domainTemplatesStreamProvider);

      // State providers - UI state and filters
      ref.invalidate(currentFolderProvider);
      ref.invalidate(filterStateProvider);
      ref.invalidate(filteredNotesProvider);
      ref.invalidate(notesPageProvider);
      ref.invalidate(currentNotesProvider);

      // Folder state providers
      ref.invalidate(folderHierarchyProvider);
      ref.invalidate(folderListProvider);
      ref.invalidate(noteFolderProvider);

      // Service providers - may cache data
      ref.invalidate(unifiedRealtimeServiceProvider);
      ref.invalidate(enhancedTaskServiceProvider);
      ref.invalidate(taskAnalyticsServiceProvider);
      ref.invalidate(inboxManagementServiceProvider);
      ref.invalidate(inboxUnreadServiceProvider);

      // Search providers
      ref.invalidate(noteIndexerProvider);

      // Pagination providers
      ref.invalidate(hasMoreNotesProvider);
      ref.invalidate(notesLoadingProvider);

      debugPrint(
        '[AuthWrapper] 🧹 Invalidated all providers - fresh state for new user',
      );
    } catch (e) {
      debugPrint('[AuthWrapper] ⚠️ Error invalidating providers: $e');
      // Continue - this is a safety measure, not critical path
    }
  }
}
