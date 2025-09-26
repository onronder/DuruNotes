import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Folder repository provider
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError(
      'FolderRepository requested without an authenticated user',
    );
  }

  final repo = FolderRepository(db: db, userId: userId);

  // Dispose when provider is disposed
  ref.onDispose(repo.dispose);

  return repo;
});

/// Folder core repository provider (domain architecture)
final folderCoreRepositoryProvider = Provider<IFolderRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return FolderCoreRepository(db: db, client: client);
});

/// Folder updates stream provider
final folderUpdatesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  return repo.folderUpdates;
});