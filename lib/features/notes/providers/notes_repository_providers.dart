import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/notes_repository_refactored.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Use refactored architecture flag - set to true to enable clean architecture
/// MIGRATION IN PROGRESS: Enabled for gradual migration
const bool useRefactoredArchitecture = true;

/// Notes repository provider - uses refactored version if flag is true
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final indexer = ref.watch(noteIndexerProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('NotesRepository requested without an authenticated user');
  }

  final api = SupabaseNoteApi(client);

  if (useRefactoredArchitecture) {
    return NotesRepositoryRefactored(
      db: db,
      crypto: crypto,
      api: api,
      client: client,
      indexer: indexer
    ) as NotesRepository;
  } else {
    return NotesRepository(
      db: db,
      crypto: crypto,
      api: api,
      client: client,
      indexer: indexer
    );
  }
});

/// Clean architecture repository providers
/// Notes core repository provider
final notesCoreRepositoryProvider = Provider<INotesRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final indexer = ref.watch(noteIndexerProvider);
  final client = Supabase.instance.client;
  final api = SupabaseNoteApi(client);

  return NotesCoreRepository(
    db: db,
    crypto: crypto,
    api: api,
    client: client,
    indexer: indexer,
  );
});

/// Supabase Note API provider for sync verification system
final supabaseNoteApiProvider = Provider<SupabaseNoteApi>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('SupabaseNoteApi requested without an authenticated user');
  }

  return SupabaseNoteApi(client);
});