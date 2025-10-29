import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth-related providers for authentication state management
///
/// This file contains providers that manage authentication state,
/// user identity, and Supabase client access across the application.

/// Auth state stream to trigger provider rebuilds on login/logout
///
/// This provider watches the Supabase auth state and emits events
/// whenever the authentication state changes (login, logout, token refresh).
/// Use this to rebuild widgets that depend on authentication status.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Provider for Supabase client
///
/// Provides access to the Supabase client for authentication,
/// database queries, and realtime subscriptions.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for current user ID
///
/// Returns the current authenticated user's ID, or null if not authenticated.
/// This is a convenience provider that extracts the user ID from Supabase auth.
final userIdProvider = Provider<String?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});
