import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/quick_capture_queue_item.dart';
import 'package:duru_notes/domain/entities/quick_capture_widget_cache.dart';
import 'package:duru_notes/domain/repositories/i_quick_capture_repository.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:uuid/uuid.dart';

class QuickCaptureRepository implements IQuickCaptureRepository {
  QuickCaptureRepository({required AppDb db, required CryptoBox crypto})
    : _db = db,
      _crypto = crypto,
      _logger = LoggerFactory.instance;

  final AppDb _db;
  final CryptoBox _crypto;
  final AppLogger _logger;
  final Uuid _uuid = const Uuid();

  static const _widgetCacheSaltPrefix = 'widget-cache';

  @override
  Future<QuickCaptureQueueItem> enqueueCapture({
    required String userId,
    required Map<String, dynamic> payload,
    String? platform,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now().toUtc();
    final encryptedPayloadBytes = await _crypto.encryptJsonForNote(
      userId: userId,
      noteId: id,
      json: payload,
    );
    final payloadEncoded = base64.encode(encryptedPayloadBytes);

    final companion = QuickCaptureQueueEntriesCompanion.insert(
      id: id,
      userId: userId,
      payloadEncrypted: payloadEncoded,
      platform: drift.Value(platform),
      retryCount: const drift.Value(0),
      processed: const drift.Value(false),
      createdAt: drift.Value(createdAt),
      updatedAt: drift.Value(createdAt),
      encryptionVersion: const drift.Value(1),
    );

    await _db.into(_db.quickCaptureQueueEntries).insert(companion);

    return QuickCaptureQueueItem(
      id: id,
      userId: userId,
      payload: payload,
      createdAt: createdAt,
      updatedAt: createdAt,
      platform: platform,
      retryCount: 0,
      processed: false,
    );
  }

  @override
  Future<List<QuickCaptureQueueItem>> getPendingCaptures({
    required String userId,
    int limit = 20,
  }) async {
    final query = (_db.select(_db.quickCaptureQueueEntries)
      ..where(
        (entry) => entry.userId.equals(userId) & entry.processed.equals(false),
      )
      ..orderBy([(entry) => drift.OrderingTerm.asc(entry.createdAt)])
      ..limit(limit));

    final rows = await query.get();
    final result = <QuickCaptureQueueItem>[];

    for (final row in rows) {
      try {
        final payload = await _decryptPayload(row);
        result.add(
          QuickCaptureQueueItem(
            id: row.id,
            userId: row.userId,
            payload: payload,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            processedAt: row.processedAt,
            platform: row.platform,
            retryCount: row.retryCount,
            processed: row.processed,
          ),
        );
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to decrypt quick capture queue entry',
          error: error,
          stackTrace: stackTrace,
          data: {'entryId': row.id},
        );
      }
    }

    return result;
  }

  @override
  Future<void> markCaptureProcessed({
    required String id,
    bool processed = true,
    DateTime? processedAt,
  }) async {
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.quickCaptureQueueEntries,
    )..where((entry) => entry.id.equals(id))).write(
      QuickCaptureQueueEntriesCompanion(
        processed: drift.Value(processed),
        processedAt: drift.Value(processed ? processedAt ?? now : null),
        updatedAt: drift.Value(now),
      ),
    );
  }

  @override
  Future<void> incrementRetryCount(String id) async {
    final now = DateTime.now().toUtc();
    await _db.customStatement(
      '''
      UPDATE quick_capture_queue_entries
      SET retry_count = retry_count + 1,
          updated_at = ?
      WHERE id = ?
      ''',
      [now.toIso8601String(), id],
    );
  }

  @override
  Future<void> deleteCapture(String id) async {
    await (_db.delete(
      _db.quickCaptureQueueEntries,
    )..where((entry) => entry.id.equals(id))).go();
  }

  @override
  Future<void> clearProcessedCaptures({
    required String userId,
    DateTime? olderThan,
  }) async {
    if (olderThan != null) {
      await _db.customStatement(
        '''
        DELETE FROM quick_capture_queue_entries
        WHERE user_id = ?
          AND processed = 1
          AND processed_at IS NOT NULL
          AND processed_at < ?
        ''',
        [userId, olderThan.toIso8601String()],
      );
    } else {
      await _db.customStatement(
        '''
        DELETE FROM quick_capture_queue_entries
        WHERE user_id = ?
          AND processed = 1
        ''',
        [userId],
      );
    }
  }

  @override
  Future<QuickCaptureWidgetCache?> getWidgetCache(String userId) async {
    final row = await (_db.select(
      _db.quickCaptureWidgetCacheEntries,
    )..where((entry) => entry.userId.equals(userId))).getSingleOrNull();

    if (row == null) return null;

    try {
      final payload = await _decryptWidgetPayload(row);
      return QuickCaptureWidgetCache(
        userId: userId,
        payload: payload,
        updatedAt: row.updatedAt,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to decrypt quick capture widget cache',
        error: error,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return null;
    }
  }

  @override
  Future<void> upsertWidgetCache(QuickCaptureWidgetCache cache) async {
    final salt = '$_widgetCacheSaltPrefix:${cache.userId}';
    final encryptedPayload = await _crypto.encryptJsonForNote(
      userId: cache.userId,
      noteId: salt,
      json: cache.payload,
    );

    final encoded = base64.encode(encryptedPayload);
    final companion = QuickCaptureWidgetCacheEntriesCompanion.insert(
      userId: cache.userId,
      dataEncrypted: encoded,
      updatedAt: drift.Value(cache.updatedAt.toUtc()),
      encryptionVersion: const drift.Value(1),
    );

    await _db
        .into(_db.quickCaptureWidgetCacheEntries)
        .insertOnConflictUpdate(companion);
  }

  Future<Map<String, dynamic>> _decryptPayload(
    QuickCaptureQueueEntry entry,
  ) async {
    final bytes = base64.decode(entry.payloadEncrypted);
    final decrypted = await _crypto.decryptJsonForNote(
      userId: entry.userId,
      noteId: entry.id,
      data: bytes,
    );
    return decrypted;
  }

  Future<Map<String, dynamic>> _decryptWidgetPayload(
    QuickCaptureWidgetCacheEntry entry,
  ) async {
    final bytes = base64.decode(entry.dataEncrypted);
    final payload = await _crypto.decryptJsonForNote(
      userId: entry.userId,
      noteId: '$_widgetCacheSaltPrefix:${entry.userId}',
      data: bytes,
    );
    return payload;
  }
}
