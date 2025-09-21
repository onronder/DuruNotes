import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote API for folder synchronization
abstract class FolderRemoteApi {
  Future<List<Map<String, dynamic>>> fetchFolders();
  Future<Map<String, dynamic>?> fetchFolder(String folderId);
  Future<void> upsertFolder(LocalFolder folder);
  Future<void> deleteFolder(String folderId);
  Future<void> markFolderDeleted(String folderId);
  Future<void> batchUpsertFolders(List<LocalFolder> folders);
}

/// Supabase implementation of FolderRemoteApi
class SupabaseFolderRemoteApi implements FolderRemoteApi {
  SupabaseFolderRemoteApi({
    required this.client,
    required this.logger,
  });

  final SupabaseClient client;
  final AppLogger logger;

  static const String _tableName = 'folders';

  @override
  Future<List<Map<String, dynamic>>> fetchFolders() async {
    try {
      final response = await client
          .from(_tableName)
          .select()
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e, stack) {
      logger.error('Failed to fetch folders', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchFolder(String folderId) async {
    try {
      final response = await client
          .from(_tableName)
          .select()
          .eq('id', folderId)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e, stack) {
      logger.error('Failed to fetch folder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> upsertFolder(LocalFolder folder) async {
    try {
      await client.from(_tableName).upsert({
        'id': folder.id,
        'name': folder.name,
        'parent_id': folder.parentId,
        'path': folder.path,
        'color': folder.color,
        'icon': folder.icon,
        'description': folder.description,
        'sort_order': folder.sortOrder,
        'created_at': folder.createdAt.toIso8601String(),
        'updated_at': folder.updatedAt.toIso8601String(),
        'deleted': folder.deleted,
      });
    } catch (e, stack) {
      logger.error('Failed to upsert folder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    try {
      // Hard delete
      await client.from(_tableName).delete().eq('id', folderId);
    } catch (e, stack) {
      logger.error('Failed to delete folder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> markFolderDeleted(String folderId) async {
    try {
      // Soft delete by marking as deleted
      await client.from(_tableName).update({
        'deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', folderId);
    } catch (e, stack) {
      logger.error('Failed to mark folder as deleted',
          error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> batchUpsertFolders(List<LocalFolder> folders) async {
    try {
      final data = folders
          .map((folder) => {
                'id': folder.id,
                'name': folder.name,
                'parent_id': folder.parentId,
                'path': folder.path,
                'color': folder.color,
                'icon': folder.icon,
                'description': folder.description,
                'sort_order': folder.sortOrder,
                'created_at': folder.createdAt.toIso8601String(),
                'updated_at': folder.updatedAt.toIso8601String(),
                'deleted': folder.deleted,
              })
          .toList();

      await client.from(_tableName).upsert(data);
    } catch (e, stack) {
      logger.error('Failed to batch upsert folders',
          error: e, stackTrace: stack);
      rethrow;
    }
  }
}
