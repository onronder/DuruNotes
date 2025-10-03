import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Folder repository provider (now uses domain architecture)
///
/// **PRODUCTION NOTE**: Legacy FolderRepository has been removed.
/// This now provides the domain IFolderRepository implementation.
final folderRepositoryProvider = Provider<IFolderRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;

  return FolderCoreRepository(db: db, client: client);
});

/// Folder core repository provider (domain architecture)
final folderCoreRepositoryProvider = Provider<IFolderRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return FolderCoreRepository(db: db, client: client);
});

/// Folder updates stream provider
///
/// TODO(infrastructure): Implement folder updates stream in domain repository
/// For now, returns an empty stream to maintain API compatibility
final folderUpdatesProvider = StreamProvider<void>((ref) {
  // Stubbed - domain folder repository doesn't have updates stream yet
  return Stream<void>.periodic(const Duration(minutes: 1), (_) => null);
});