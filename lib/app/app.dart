import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/theme/material3_theme.dart';
import 'package:duru_notes/ui/auth_screen.dart';
import 'package:duru_notes/ui/notes_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Main application widget with authentication flow
class App extends ConsumerWidget {

  const App({
    super.key,
    this.navigatorKey,
  });
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings providers
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    const generatedSupportedLocales = AppLocalizations.supportedLocales;
    // If a saved locale isn't generated, fall back to system
    final effectiveLocale = (locale != null &&
            generatedSupportedLocales.any((l) => l.languageCode == locale.languageCode))
        ? locale
        : null;

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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class UnlockPassphraseView extends ConsumerStatefulWidget {
  const UnlockPassphraseView({required this.onUnlocked, super.key});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<UnlockPassphraseView> createState() => _UnlockPassphraseViewState();
}

class _UnlockPassphraseViewState extends ConsumerState<UnlockPassphraseView> {
  final _controller = TextEditingController();
  bool _isUnlocking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    if (_isUnlocking || _controller.text.isEmpty) return;

    setState(() => _isUnlocking = true);
    
    try {
      final ok = await ref.read(accountKeyServiceProvider).unlockAmkWithPassphrase(_controller.text);
      if (ok) {
        widget.onUnlocked();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect passphrase'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
                Text('Unlock Encryption', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  enabled: !_isUnlocking,
                  decoration: const InputDecoration(
                    labelText: 'Encryption Passphrase',
                    prefixIcon: Icon(Icons.vpn_key),
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
                  onPressed: _isUnlocking ? null : () async {
                    // Clear the AMK before signing out
                    await ref.read(accountKeyServiceProvider).clearLocalAmk();
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

/// Wrapper that handles authentication state
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> with WidgetsBindingObserver {
  bool _hasTriggeredInitialSync = false;
  ClipperInboxService? _clipperService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _clipperService?.stop();
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

    final syncModeNotifier = ref.read(syncModeProvider.notifier);
    await syncModeNotifier.performInitialSyncIfAuto();
    
    if (ref.read(syncModeProvider) == SyncMode.automatic) {
      await ref.read(notesPageProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if user is authenticated
        final session = snapshot.hasData ? snapshot.data!.session : null;
        
        if (session != null) {
          // Check if AMK is present locally
          // For new signups, retry a few times as provisioning might still be in progress
          return FutureBuilder(
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
                        Text('Initializing encryption...')
                      ],
                    ),
                  ),
                );
              }
              
              // If no AMK found after retries, show unlock screen
              if (amkSnap.data != true) {
                // Show unlock screen for existing users on new devices
                // or if AMK provisioning failed during signup
                return UnlockPassphraseView(
                  onUnlocked: () {
                    if (mounted) setState(() {});
                  },
                );
              }
              
              // User is authenticated and AMK is available - show main app
              _maybePerformInitialSync();
              return const NotesListScreen();
            },
          );
        } else {
          // User is not authenticated - show login screen
          _hasTriggeredInitialSync = false; // Reset flag when logged out
          _clipperService?.stop(); // Stop the clipper service when logged out
          _clipperService = null;
          return const AuthScreen();
        }
      },
    );
  }

  /// Trigger initial sync if in automatic mode (only once per session)
  void _maybePerformInitialSync() {
    if (!_hasTriggeredInitialSync) {
      _hasTriggeredInitialSync = true;
      
      // Use a post-frame callback to ensure providers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Start the clipper inbox service after authentication
        try {
          _clipperService = ref.read(clipperInboxServiceProvider);
          _clipperService?.start();
        } catch (e) {
          // Log but don't fail - clipper service is optional
          debugPrint('Failed to start clipper inbox service: $e');
        }
        
        final syncModeNotifier = ref.read(syncModeProvider.notifier);
        await syncModeNotifier.performInitialSyncIfAuto();
        
        // Refresh notes if auto-sync ran
        if (ref.read(syncModeProvider) == SyncMode.automatic) {
          await ref.read(notesPageProvider.notifier).refresh();
        }

        // Production-grade boot sync: if this device has no local notes yet, force a full pull once
        try {
          final db = ref.read(appDbProvider);
          final existing = await db.allNotes();
          if (existing.isEmpty) {
            final syncService = ref.read(syncServiceProvider);
            await syncService.syncWithRetry();
            await ref.read(notesPageProvider.notifier).refresh();
          }
        } catch (_) {
          // Ignore boot sync errors; user can trigger manual sync later
        }
      });
    }
  }
  
  /// Check for AMK with retries to handle timing issues after signup
  Future<bool> _checkForAmkWithRetry() async {
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);
    
    for (var i = 0; i < maxRetries; i++) {
      final amk = await ref.read(accountKeyServiceProvider).getLocalAmk();
      if (amk != null) {
        return true;
      }
      
      // Don't delay on the last attempt
      if (i < maxRetries - 1) {
        await Future<void>.delayed(retryDelay);
      }
    }
    
    return false;
  }
}
