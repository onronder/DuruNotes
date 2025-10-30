import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Note API provider for sync verification system
/// Returns null when user is not authenticated to prevent crashes
final supabaseNoteApiProvider = Provider<SupabaseNoteApi?>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  // Return null instead of throwing to prevent crashes on logout
  if (userId == null || userId.isEmpty) {
    return null;
  }

  return SupabaseNoteApi(client);
});
