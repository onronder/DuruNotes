import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Database transaction manager to ensure atomic operations during sync
/// Prevents partial data states and corruption during sync operations
class TransactionManager {
  TransactionManager(this._db);

  final AppDb _db;
  final Map<String, Completer<void>?> _activeTransactions = {};

  /// Execute operations within a database transaction
  Future<T> executeInTransaction<T>(
    String operationName,
    Future<T> Function(DatabaseConnectionUser db) operation,
  ) async {
    // Check if there's already an active transaction for this operation
    if (_activeTransactions[operationName] != null) {
      debugPrint('⏳ Waiting for existing transaction: $operationName');
      await _activeTransactions[operationName]!.future;
    }

    // Start new transaction
    final completer = Completer<void>();
    _activeTransactions[operationName] = completer;

    try {
      debugPrint('🔒 Starting transaction: $operationName');

      final result = await _db.transaction(() async {
        return await operation(_db);
      });

      debugPrint('✅ Transaction completed: $operationName');
      return result;

    } catch (error) {
      debugPrint('❌ Transaction failed: $operationName - $error');
      rethrow;
    } finally {
      // Always clean up the transaction state
      _activeTransactions[operationName] = null;
      completer.complete();
    }
  }

  /// Execute multiple operations in a single batch transaction
  Future<List<T>> executeBatch<T>(
    String batchName,
    List<Future<T> Function(DatabaseConnectionUser db)> operations,
  ) async {
    return await executeInTransaction<List<T>>(
      'batch_$batchName',
      (db) async {
        final results = <T>[];

        for (int i = 0; i < operations.length; i++) {
          try {
            final result = await operations[i](db);
            results.add(result);
            debugPrint('✓ Batch operation ${i + 1}/${operations.length} completed: $batchName');
          } catch (error) {
            debugPrint('❌ Batch operation ${i + 1}/${operations.length} failed: $batchName - $error');
            rethrow; // This will roll back the entire transaction
          }
        }

        return results;
      },
    );
  }

  /// Execute note-related operations atomically
  Future<void> executeNoteOperations(
    String noteId,
    List<Future<void> Function(DatabaseConnectionUser db)> operations,
  ) async {
    await executeInTransaction<void>(
      'note_ops_$noteId',
      (db) async {
        for (final operation in operations) {
          await operation(db);
        }
      },
    );
  }

  /// Execute sync operations atomically to prevent partial sync states
  Future<T> executeSyncOperation<T>(
    String syncType,
    String entityId,
    Future<T> Function(DatabaseConnectionUser db) operation,
  ) async {
    return await executeInTransaction<T>(
      'sync_${syncType}_$entityId',
      operation,
    );
  }

  /// Wait for all active transactions to complete
  Future<void> waitForAllTransactions() async {
    final activeCompleters = _activeTransactions.values
        .where((completer) => completer != null)
        .cast<Completer<void>>()
        .toList();

    if (activeCompleters.isNotEmpty) {
      debugPrint('⏳ Waiting for ${activeCompleters.length} active transactions to complete');
      await Future.wait(activeCompleters.map((c) => c.future));
    }
  }

  /// Get current transaction status for monitoring
  Map<String, bool> getTransactionStatus() {
    return Map.fromEntries(
      _activeTransactions.entries.map(
        (entry) => MapEntry(entry.key, entry.value != null),
      ),
    );
  }

  /// Force cleanup all transactions (emergency use only)
  void emergencyCleanup() {
    debugPrint('🛑 Emergency: Cleaning up all transaction state');
    for (final entry in _activeTransactions.entries) {
      if (entry.value != null) {
        debugPrint('🛑 Force completing transaction: ${entry.key}');
        entry.value!.complete();
      }
    }
    _activeTransactions.clear();
  }

  /// Specialized sync transaction helpers

  /// Execute note sync with proper constraint checking
  Future<void> syncNoteWithConstraints(
    String noteId,
    Map<String, dynamic> noteData,
    Uint8List? encryptedMetadata,
  ) async {
    await executeSyncOperation<void>(
      'note',
      noteId,
      (db) async {
        // Validate encrypted metadata before insertion
        if (encryptedMetadata != null) {
          await _validateEncryptedMetadata(encryptedMetadata);
        }

        // Perform the actual sync operation within the transaction
        await db.customStatement('''
          INSERT OR REPLACE INTO local_notes (
            id, title, body, updated_at, deleted, encrypted_metadata,
            is_pinned, note_type, version, user_id, attachment_meta, metadata
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          noteData['id'],
          noteData['title'] ?? '',
          noteData['body'] ?? '',
          (noteData['updated_at'] as DateTime?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          noteData['deleted'] == true ? 1 : 0,
          encryptedMetadata,
          noteData['is_pinned'] == true ? 1 : 0,
          noteData['note_type'] ?? 0,
          noteData['version'] ?? 1,
          noteData['user_id'],
          noteData['attachment_meta'],
          noteData['metadata'],
        ]);
      },
    );
  }

  /// Validate encrypted metadata before database insertion
  Future<void> _validateEncryptedMetadata(Uint8List data) async {
    // Check for corruption patterns
    if (data.length == 2 && data[0] == 91 && data[1] == 93) {
      throw FormatException('Corrupted encrypted metadata: Empty JSON array detected');
    }

    if (data.length < 32) {
      throw FormatException('Invalid encrypted metadata size: ${data.length} bytes (minimum 32 required)');
    }

    // Try to parse as UTF-8 JSON to verify structure
    try {
      final jsonString = String.fromCharCodes(data);
      final parsed = jsonDecode(jsonString);

      if (parsed is Map<String, dynamic>) {
        // Check for required SecretBox keys
        if (!parsed.containsKey('n') || !parsed.containsKey('c') || !parsed.containsKey('m')) {
          throw FormatException('Invalid SecretBox structure: Missing required keys (n, c, m)');
        }
      } else {
        throw FormatException('Invalid encrypted metadata: Expected JSON object, got ${parsed.runtimeType}');
      }
    } catch (e) {
      throw FormatException('Invalid encrypted metadata format: $e');
    }
  }
}