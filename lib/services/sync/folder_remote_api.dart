import 'dart:async';
import 'dart:typed_data';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
    required CryptoBox crypto,
  })  : _crypto = crypto,
        _noteApi = SupabaseNoteApi(client);

  final SupabaseClient client;
  final AppLogger logger;
  final CryptoBox _crypto;
  final SupabaseNoteApi _noteApi;

  static const String _tableName = 'folders';

  void _captureRemoteException({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('service', 'FolderRemoteApi');
          scope.setTag('operation', operation);        },
      ),
    );
  }

  String _requireUserId() {
    final id = client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Supabase authentication required for folder sync');
    }
    return id;
  }

  Future<Uint8List> _encryptName({
    required String userId,
    required String folderId,
    required String name,
  }) {
    return _crypto.encryptJsonForNote(
      userId: userId,
      noteId: folderId,
      json: {'name': name},
    );
  }

  Future<Uint8List> _encryptProps({
    required String userId,
    required LocalFolder folder,
    required bool deletedOverride,
  }) {
    final props = <String, dynamic>{
      'parentId': folder.parentId,
      'color': folder.color,
      'icon': folder.icon,
      'description': folder.description,
      'sortOrder': folder.sortOrder,
      'path': folder.path,
      'deleted': deletedOverride,
      'createdAt': folder.createdAt.toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((_, value) => value == null);

    return _crypto.encryptJsonForNote(
      userId: userId,
      noteId: folder.id,
      json: props,
    );
  }

  Future<Map<String, dynamic>> _decryptFolderRow(
    Map<String, dynamic> row,
  ) async {
    final userId = _requireUserId();
    final id = row['id'] as String;
    final nameEnc = row['name_enc'];
    final propsEnc = row['props_enc'];

    String name = '';
    Map<String, dynamic> props = {};

    if (nameEnc != null) {
      final decoded = await _crypto.decryptJsonForNote(
        userId: userId,
        noteId: id,
        data: SupabaseNoteApi.asBytes(nameEnc),
      );
      name = (decoded['name'] as String?) ?? '';
    }

    if (propsEnc != null) {
      props = await _crypto.decryptJsonForNote(
        userId: userId,
        noteId: id,
        data: SupabaseNoteApi.asBytes(propsEnc),
      );
    }

    final createdAtRaw = row['created_at'];
    final updatedAtRaw = row['updated_at'] ?? props['updatedAt'];

    return <String, dynamic>{
      'id': id,
      'user_id': row['user_id'],
      'name': name,
      'parent_id': props['parentId'],
      'color': props['color'],
      'icon': props['icon'],
      'description': props['description'],
      'sort_order': props['sortOrder'] ?? 0,
      'path': props['path'],
      'deleted': row['deleted'] ?? props['deleted'] ?? false,
      'created_at': createdAtRaw is String
          ? createdAtRaw
          : (createdAtRaw as DateTime?)?.toIso8601String(),
      'updated_at': updatedAtRaw is String
          ? updatedAtRaw
          : (updatedAtRaw as DateTime?)?.toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFolders() async {
    try {
      final rows = await _noteApi.fetchEncryptedFolders();
      final results = <Map<String, dynamic>>[];
      for (final row in rows) {
        results.add(await _decryptFolderRow(row));
      }
      results.sort((a, b) {
        final bTime = DateTime.tryParse((b['updated_at'] as String?) ?? '');
        final aTime = DateTime.tryParse((a['updated_at'] as String?) ?? '');
        return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
      return results;
    } catch (error, stack) {
      logger.error('Failed to fetch folders', error: error, stackTrace: stack);
      _captureRemoteException(
        operation: 'fetchFolders',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchFolder(String folderId) async {
    try {
      final userId = _requireUserId();
      final Map<String, dynamic>? response = await client
          .from(_tableName)
          .select(
            'id, user_id, created_at, updated_at, name_enc, props_enc, deleted',
          )
          .eq('user_id', userId)
          .eq('id', folderId)
          .maybeSingle();

      if (response == null) return null;
      return _decryptFolderRow(response);
    } catch (error, stack) {
      logger.error('Failed to fetch folder', error: error, stackTrace: stack);
      _captureRemoteException(
        operation: 'fetchFolder',
        error: error,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      rethrow;
    }
  }

  @override
  Future<void> upsertFolder(LocalFolder folder) async {
    try {
      final userId = _requireUserId();
      final nameEnc = await _encryptName(
        userId: userId,
        folderId: folder.id,
        name: folder.name,
      );
      final propsEnc = await _encryptProps(
        userId: userId,
        folder: folder,
        deletedOverride: folder.deleted,
      );

      await _noteApi.upsertEncryptedFolder(
        id: folder.id,
        nameEnc: nameEnc,
        propsEnc: propsEnc,
        deleted: folder.deleted,
      );
    } catch (error, stack) {
      logger.error('Failed to upsert folder', error: error, stackTrace: stack);
      _captureRemoteException(
        operation: 'upsertFolder',
        error: error,
        stackTrace: stack,
        data: {'folderId': folder.id},
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    try {
      final userId = _requireUserId();
      // Hard delete
      await client
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .eq('id', folderId);
    } catch (error, stack) {
      logger.error('Failed to delete folder', error: error, stackTrace: stack);
      _captureRemoteException(
        operation: 'deleteFolder',
        error: error,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      rethrow;
    }
  }

  @override
  Future<void> markFolderDeleted(String folderId) async {
    try {
      final userId = _requireUserId();
      // Soft delete by marking as deleted
      await client.from(_tableName).update({
        'deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId).eq('id', folderId);
    } catch (error, stack) {
      logger.error('Failed to mark folder as deleted',
          error: error, stackTrace: stack);
      _captureRemoteException(
        operation: 'markFolderDeleted',
        error: error,
        stackTrace: stack,
        data: {'folderId': folderId},
      );
      rethrow;
    }
  }

  @override
  Future<void> batchUpsertFolders(List<LocalFolder> folders) async {
    try {
      for (final folder in folders) {
        await upsertFolder(folder);
      }
    } catch (error, stack) {
      logger.error('Failed to batch upsert folders',
          error: error, stackTrace: stack);
      _captureRemoteException(
        operation: 'batchUpsertFolders',
        error: error,
        stackTrace: stack,
        data: {'count': folders.length},
      );
      rethrow;
    }
  }
}
