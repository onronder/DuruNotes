import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
// Phase 4: Migrated to organized provider imports
import 'package:duru_notes/core/providers/security_providers.dart'
    show cryptoBoxProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Task repository provider for sync (now uses domain architecture)
/// Returns null when user is not authenticated to prevent crashes on logout
final taskRepositoryProvider = Provider<ITaskRepository?>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);

  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  // Return null instead of throwing to prevent crashes on logout
  if (userId == null || userId.isEmpty) {
    return null;
  }

  final database = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);

  return TaskCoreRepository(db: database, client: client, crypto: crypto);
});

/// Task core repository provider (domain architecture)
/// Returns null when user is not authenticated to prevent crashes
final taskCoreRepositoryProvider = Provider<ITaskRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  // Return null if not authenticated
  if (userId == null || userId.isEmpty) {
    return null;
  }

  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  return TaskCoreRepository(db: db, client: client, crypto: crypto);
});
