import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth state stream to trigger provider rebuilds on login/logout
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for user ID
final userIdProvider = Provider<String?>((ref) {
  // Get user ID from auth service or Supabase
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});
