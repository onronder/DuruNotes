
import 'dart:typed_data';

import 'package:duru_notes_app/core/crypto/crypto_box.dart';
import 'package:duru_notes_app/core/crypto/key_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CryptoBox', () {
    late KeyManager keyManager;
    late CryptoBox cryptoBox;
    
    setUp(() {
      keyManager = KeyManager.inMemory();
      cryptoBox = CryptoBox(keyManager);
    });

    group('String Encryption/Decryption', () {
      test('should encrypt and decrypt strings correctly', () async {
    const userId = 'user-1';
    const noteId = 'note-1';
    const text = 'Hello, encrypted world!';

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        expect(encrypted, isA<Uint8List>());
        expect(encrypted.isNotEmpty, isTrue);

        final decrypted = await cryptoBox.decryptStringForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(text));
      });

      test('should handle empty strings', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        const text = '';

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        final decrypted = await cryptoBox.decryptStringForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(text));
      });

      test('should handle unicode and special characters', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        const text = 'Unicode: 🔒 العربية 中文 ñoño @#\$%^&*()';

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        final decrypted = await cryptoBox.decryptStringForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(text));
      });

      test('should handle very long strings', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        final text = 'A' * 10000; // 10KB string

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        final decrypted = await cryptoBox.decryptStringForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(text));
      });
    });

    group('JSON Encryption/Decryption', () {
      test('should encrypt and decrypt JSON correctly', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        final json = {
          'title': 'Test Note',
          'body': 'This is a test note with various data types',
          'tags': ['work', 'urgent'],
          'count': 42,
          'completed': true,
          'metadata': {
            'created': '2024-01-01T00:00:00Z',
            'author': 'test@example.com'
          }
        };

        final encrypted = await cryptoBox.encryptJsonForNote(
          userId: userId,
          noteId: noteId,
          json: json,
        );
        
        expect(encrypted, isA<Uint8List>());
        expect(encrypted.isNotEmpty, isTrue);

        final decrypted = await cryptoBox.decryptJsonForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(json));
      });

      test('should handle nested JSON structures', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        final json = {
          'level1': {
            'level2': {
              'level3': {
                'data': 'deep nested value',
                'array': [1, 2, 3, {'nested': 'object'}]
              }
            }
          }
        };

        final encrypted = await cryptoBox.encryptJsonForNote(
          userId: userId,
          noteId: noteId,
          json: json,
        );
        
        final decrypted = await cryptoBox.decryptJsonForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(json));
      });

      test('should handle JSON with arrays as root', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        final json = {
          'items': ['item1', 'item2', 'item3'],
          'type': 'array_container'
        };

        final encrypted = await cryptoBox.encryptJsonForNote(
          userId: userId,
          noteId: noteId,
          json: json,
        );
        
        final decrypted = await cryptoBox.decryptJsonForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted,
        );
        
        expect(decrypted, equals(json));
      });

      test('should handle malformed JSON gracefully', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        const malformedJsonString = 'not valid json';

        // Manually create encrypted data with malformed JSON
        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: malformedJsonString,
        );
        
        // Should throw an exception when trying to parse malformed JSON
        expect(
          () => cryptoBox.decryptJsonForNote(
            userId: userId,
            noteId: noteId,
            data: encrypted,
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('Security Properties', () {
      test('should produce different ciphertext for same plaintext', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        const text = 'Same plaintext';

        final encrypted1 = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        final encrypted2 = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        // Should be different due to random nonce
        expect(encrypted1, isNot(equals(encrypted2)));
        
        // But both should decrypt to same plaintext
        final decrypted1 = await cryptoBox.decryptStringForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted1,
        );
        
        final decrypted2 = await cryptoBox.decryptStringForNote(
          userId: userId,
          noteId: noteId,
          data: encrypted2,
        );
        
        expect(decrypted1, equals(text));
        expect(decrypted2, equals(text));
      });

      test('should fail with wrong user ID', () async {
        const userId1 = 'user-1';
        const userId2 = 'user-2';
        const noteId = 'note-1';
        const text = 'Secret data';

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId1,
          noteId: noteId,
          text: text,
        );
        
        // Should fail to decrypt with different user ID
        expect(
          () => cryptoBox.decryptStringForNote(
            userId: userId2,
            noteId: noteId,
            data: encrypted,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should fail with wrong note ID', () async {
        const userId = 'user-1';
        const noteId1 = 'note-1';
        const noteId2 = 'note-2';
        const text = 'Secret data';

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId1,
          text: text,
        );
        
        // Should fail to decrypt with different note ID
        expect(
          () => cryptoBox.decryptStringForNote(
            userId: userId,
            noteId: noteId2,
            data: encrypted,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should fail with corrupted ciphertext', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        const text = 'Secret data';

        final encrypted = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId,
          text: text,
        );
        
        // Corrupt the ciphertext
        final corrupted = Uint8List.fromList(encrypted);
        corrupted[0] = corrupted[0] ^ 0xFF; // Flip bits
        
        // Should fail to decrypt corrupted data
        expect(
          () => cryptoBox.decryptStringForNote(
            userId: userId,
            noteId: noteId,
            data: corrupted,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should fail with truncated ciphertext', () async {
        const userId = 'user-1';
        const noteId = 'note-1';
        const text = 'Secret data';

        final encrypted = await cryptoBox.encryptStringForNote(
      userId: userId,
      noteId: noteId,
      text: text,
    );
        
        // Truncate the ciphertext
        final truncated = Uint8List.fromList(encrypted.take(10).toList());

        // Should fail to decrypt truncated data
        expect(
          () => cryptoBox.decryptStringForNote(
      userId: userId,
      noteId: noteId,
            data: truncated,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Key Derivation', () {
      test('should use different keys for different users', () async {
        const userId1 = 'user-1';
        const userId2 = 'user-2';
        const noteId = 'note-1';
        const text = 'Same text, different users';

        final encrypted1 = await cryptoBox.encryptStringForNote(
          userId: userId1,
          noteId: noteId,
          text: text,
        );
        
        final encrypted2 = await cryptoBox.encryptStringForNote(
          userId: userId2,
          noteId: noteId,
          text: text,
        );
        
        // Should produce different ciphertext for different users
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('should use different keys for different notes', () async {
        const userId = 'user-1';
        const noteId1 = 'note-1';
        const noteId2 = 'note-2';
        const text = 'Same text, different notes';

        final encrypted1 = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId1,
          text: text,
        );
        
        final encrypted2 = await cryptoBox.encryptStringForNote(
          userId: userId,
          noteId: noteId2,
          text: text,
        );
        
        // Should produce different ciphertext for different notes
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });
  });
}
