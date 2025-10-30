import 'dart:convert';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Helper for decrypting NoteTask encrypted fields
///
/// ARCHITECTURE: This helper provides a clean interface for decrypting task data.
/// It delegates all encryption/decryption logic to CryptoBox, which handles
/// multiple formats (JSON, legacy) internally.
class TaskDecryptionHelper {
  final CryptoBox crypto;

  TaskDecryptionHelper(this.crypto);

  /// Decrypt content (title) from NoteTask
  ///
  /// The encrypted data is stored as a JSON string: {"n":"...", "c":"...", "m":"..."}
  /// We convert it to UTF-8 bytes and pass to CryptoBox for decryption.
  Future<String> decryptContent(NoteTask task, String noteId) async {
    if (task.contentEncrypted.isEmpty) return '';

    final userId = task.userId;

    try {
      // Convert JSON string to UTF-8 bytes for CryptoBox
      final contentBytes = utf8.encode(task.contentEncrypted);

      final contentMap = await crypto.decryptJsonForNote(
        userId: userId,
        noteId: noteId,
        data: contentBytes,
      );
      return contentMap['content']?.toString() ?? '';
    } catch (e) {
      print('⚠️ Failed to decrypt content for task ${task.id}: $e');
      rethrow;
    }
  }

  /// Decrypt labels (tags) from NoteTask
  ///
  /// The encrypted data is stored as a JSON string: {"n":"...", "c":"...", "m":"..."}
  /// We convert it to UTF-8 bytes and pass to CryptoBox for decryption.
  Future<String?> decryptLabels(NoteTask task, String noteId) async {
    if (task.labelsEncrypted == null || task.labelsEncrypted!.isEmpty)
      return null;

    final userId = task.userId;

    try {
      // Convert JSON string to UTF-8 bytes for CryptoBox
      final labelsBytes = utf8.encode(task.labelsEncrypted!);

      final labelsMap = await crypto.decryptJsonForNote(
        userId: userId,
        noteId: noteId,
        data: labelsBytes,
      );
      return labelsMap['labels']?.toString();
    } catch (e) {
      print('⚠️ Failed to decrypt labels for task ${task.id}: $e');
      rethrow;
    }
  }

  /// Decrypt notes (description) from NoteTask
  ///
  /// The encrypted data is stored as a JSON string: {"n":"...", "c":"...", "m":"..."}
  /// We convert it to UTF-8 bytes and pass to CryptoBox for decryption.
  Future<String?> decryptNotes(NoteTask task, String noteId) async {
    if (task.notesEncrypted == null || task.notesEncrypted!.isEmpty)
      return null;

    final userId = task.userId;

    try {
      // Convert JSON string to UTF-8 bytes for CryptoBox
      final notesBytes = utf8.encode(task.notesEncrypted!);

      final notesMap = await crypto.decryptJsonForNote(
        userId: userId,
        noteId: noteId,
        data: notesBytes,
      );
      return notesMap['notes']?.toString();
    } catch (e) {
      print('⚠️ Failed to decrypt notes for task ${task.id}: $e');
      rethrow;
    }
  }

  /// Encrypt content for storage
  ///
  /// DEPRECATED: This method is not used by the repository.
  /// The repository encrypts directly via CryptoBox.encryptStringForNote()
  Future<String> encryptContent(
    String userId,
    String noteId,
    String content,
  ) async {
    final contentBytes = await crypto.encryptJsonForNote(
      userId: userId,
      noteId: noteId,
      json: {'content': content},
    );
    return utf8.decode(contentBytes);
  }

  /// Encrypt labels for storage
  ///
  /// DEPRECATED: This method is not used by the repository.
  /// The repository encrypts directly via CryptoBox.encryptStringForNote()
  Future<String?> encryptLabels(
    String userId,
    String noteId,
    String? labels,
  ) async {
    if (labels == null) return null;

    final labelsBytes = await crypto.encryptJsonForNote(
      userId: userId,
      noteId: noteId,
      json: {'labels': labels},
    );
    return utf8.decode(labelsBytes);
  }

  /// Encrypt notes for storage
  ///
  /// DEPRECATED: This method is not used by the repository.
  /// The repository encrypts directly via CryptoBox.encryptStringForNote()
  Future<String?> encryptNotes(
    String userId,
    String noteId,
    String? notes,
  ) async {
    if (notes == null) return null;

    final notesBytes = await crypto.encryptJsonForNote(
      userId: userId,
      noteId: noteId,
      json: {'notes': notes},
    );
    return utf8.decode(notesBytes);
  }
}
