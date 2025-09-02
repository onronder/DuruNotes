import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/settings/locale_notifier.dart';
import '../core/settings/sync_mode.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
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
    
    // Define cohesive Material 3 color schemes
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1976D2), // Professional blue
      brightness: Brightness.light,
    );
    
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1976D2),
      brightness: Brightness.dark,
    );

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        textTheme: Typography.material2021().black,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        
        // Modern Material 3 input field styling
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightScheme.surfaceVariant.withOpacity(0.3), // Subtle fill
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: lightScheme.outlineVariant,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: lightScheme.outlineVariant,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: lightScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: lightScheme.error,
              width: 2,
            ),
          ),
          labelStyle: TextStyle(color: lightScheme.onSurfaceVariant),
          prefixIconColor: lightScheme.onSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        
        // Modern button styling
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 2,
          ),
        ),
        
        // Modern card styling
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: lightScheme.shadow.withOpacity(0.1),
          surfaceTintColor: lightScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        
        // AppBar styling
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 4,
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          titleTextStyle: Typography.material2021().black.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: lightScheme.onSurface,
          ),
        ),
        
        // FloatingActionButton styling
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: lightScheme.primaryContainer,
          foregroundColor: lightScheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        
        // List tile styling
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        // Dialog styling
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        textTheme: Typography.material2021().white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        
        // Input field styling for dark mode
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        
        // Button styling for dark mode
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        // Card styling for dark mode
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        
        // AppBar styling for dark mode
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 4,
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          titleTextStyle: Typography.material2021().white.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: darkScheme.onSurface,
          ),
        ),
        
        // FloatingActionButton styling for dark mode
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: darkScheme.primaryContainer,
          foregroundColor: darkScheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        
        // List tile styling for dark mode
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        // Dialog styling for dark mode
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      
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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
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