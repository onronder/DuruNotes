import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show authStateChangesProvider;
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
// Phase 4: Migrated to organized provider imports
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Folder repository provider (now uses domain architecture)
///
/// **PRODUCTION NOTE**: Legacy FolderRepository has been removed.
/// This now provides the domain IFolderRepository implementation.
///
/// **PRODUCTION FIX**: Returns null when user not authenticated (prevents sign-out crash)
final folderRepositoryProvider = Provider<IFolderRepository?>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);

  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  // PRODUCTION FIX: Return null when not authenticated
  if (userId == null || userId.isEmpty) {
    return null;
  }

  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);

  return FolderCoreRepository(db: db, client: client, crypto: crypto);
});

/// Folder core repository provider (domain architecture)
final folderCoreRepositoryProvider = Provider<IFolderRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = ref.watch(supabaseClientProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  return FolderCoreRepository(db: db, client: client, crypto: crypto);
});

/// Folder updates stream provider
///
/// TODO(infrastructure): Implement folder updates stream in domain repository
/// For now, returns an empty stream to maintain API compatibility
final folderUpdatesProvider = StreamProvider.autoDispose<void>((ref) {
  // Stubbed - domain folder repository doesn't have updates stream yet
  return Stream<void>.periodic(const Duration(minutes: 1));
});
