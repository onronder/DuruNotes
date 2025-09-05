import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/settings/locale_notifier.dart';
import '../core/settings/sync_mode.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../theme/material3_theme.dart';
import '../ui/auth_screen.dart';
import '../ui/notes_list_screen.dart';

/// Main application widget with authentication flow
class App extends ConsumerWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const App({
    super.key,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings providers
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Duru Notes',
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleNotifier.supportedLocales,
      theme: DuruMaterial3Theme.lightTheme,
      darkTheme: DuruMaterial3Theme.darkTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
  void _performAppResumeSync() async {
    final syncModeNotifier = ref.read(syncModeProvider.notifier);
    await syncModeNotifier.performInitialSyncIfAuto();
    
    // Refresh notes if auto-sync ran
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
          // User is authenticated - show main app
          _maybePerformInitialSync();
          return const NotesListScreen();
        } else {
          // User is not authenticated - show login screen
          _hasTriggeredInitialSync = false; // Reset flag when logged out
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
        final syncModeNotifier = ref.read(syncModeProvider.notifier);
        await syncModeNotifier.performInitialSyncIfAuto();
        
        // Refresh notes if auto-sync ran
        if (ref.read(syncModeProvider) == SyncMode.automatic) {
          await ref.read(notesPageProvider.notifier).refresh();
        }
      });
    }
  }
}