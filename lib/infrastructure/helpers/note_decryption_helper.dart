import 'dart:convert';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper for decrypting LocalNote encrypted fields
///
/// ARCHITECTURE: This helper provides a clean interface for decrypting note data.
/// It delegates all encryption/decryption logic to CryptoBox, which handles
/// multiple formats (JSON, legacy) internally.
class NoteDecryptionHelper {
  final CryptoBox crypto;

  NoteDecryptionHelper(this.crypto);

  /// Decrypt title from LocalNote
  ///
  /// The encrypted data is stored as a JSON string: {"n":"...", "c":"...", "m":"..."}
  /// We convert it to UTF-8 bytes and pass to CryptoBox for decryption.
  Future<String> decryptTitle(LocalNote note) async {
    if (note.titleEncrypted.isEmpty) return '';

    final userId = note.userId ?? Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) {
      print('⚠️ Cannot decrypt title without user ID for note ${note.id}');
      return '';
    }

    try {
      // Convert JSON string to UTF-8 bytes for CryptoBox
      final titleBytes = utf8.encode(note.titleEncrypted);

      return await crypto.decryptStringForNote(
        userId: userId,
        noteId: note.id,
        data: titleBytes,
      );
    } catch (e) {
      print('⚠️ Failed to decrypt title for note ${note.id}: $e');
      rethrow;
    }
  }

  /// Decrypt body from LocalNote
  ///
  /// The encrypted data is stored as a JSON string: {"n":"...", "c":"...", "m":"..."}
  /// We convert it to UTF-8 bytes and pass to CryptoBox for decryption.
  Future<String> decryptBody(LocalNote note) async {
    if (note.bodyEncrypted.isEmpty) return '';

    final userId = note.userId ?? Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) {
      print('⚠️ Cannot decrypt body without user ID for note ${note.id}');
      return '';
    }

    try {
      // Convert JSON string to UTF-8 bytes for CryptoBox
      final bodyBytes = utf8.encode(note.bodyEncrypted);

      return await crypto.decryptStringForNote(
        userId: userId,
        noteId: note.id,
        data: bodyBytes,
      );
    } catch (e) {
      print('⚠️ Failed to decrypt body for note ${note.id}: $e');
      rethrow;
    }
  }

  /// Encrypt title for storage
  ///
  /// DEPRECATED: This method is not used by the repository.
  /// The repository encrypts directly via CryptoBox.encryptStringForNote()
  Future<String> encryptTitle(String userId, String noteId, String title) async {
    final titleBytes = await crypto.encryptJsonForNote(
      userId: userId,
      noteId: noteId,
      json: {'title': title},
    );
    return utf8.decode(titleBytes);
  }

  /// Encrypt body for storage
  ///
  /// DEPRECATED: This method is not used by the repository.
  /// The repository encrypts directly via CryptoBox.encryptStringForNote()
  Future<String> encryptBody(String userId, String noteId, String body) async {
    final bodyBytes = await crypto.encryptJsonForNote(
      userId: userId,
      noteId: noteId,
      json: {'body': body},
    );
    return utf8.decode(bodyBytes);
  }
}
