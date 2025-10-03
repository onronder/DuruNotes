import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/features/auth/providers/auth_providers.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Task service provider
final taskServiceProvider = Provider<TaskService>((ref) {
  final database = ref.watch(appDbProvider);
  return TaskService(database: database);
});

/// Task repository provider for sync
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final database = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  if (userId == null || userId.isEmpty) {
    throw StateError('TaskRepository requested without an authenticated user');
  }

  return TaskRepository(database: database, supabase: client);
});

/// Task core repository provider (domain architecture)
final taskCoreRepositoryProvider = Provider<ITaskRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return TaskCoreRepository(db: db, client: client);
});