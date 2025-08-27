import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return MaterialApp(
      title: 'Duru Notes',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Wrapper that handles authentication state
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          return const NotesListScreen();
        } else {
          // User is not authenticated - show login screen
          return const AuthScreen();
        }
      },
    );
  }
}