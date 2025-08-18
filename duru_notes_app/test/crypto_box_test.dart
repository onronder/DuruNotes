import 'dart:typed_data';

import 'package:duru_notes_app/core/crypto/crypto_box.dart';
import 'package:duru_notes_app/core/crypto/key_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CryptoBox roundtrip', () async {
    final km = KeyManager.inMemory();
    final cb = CryptoBox(km);
    const userId = 'user-1';
    const noteId = 'note-1';
    const text = 'Hello, encrypted world!';

    final enc = await cb.encryptStringForNote(
      userId: userId,
      noteId: noteId,
      text: text,
    );
    expect(enc, isA<Uint8List>());
    expect(enc.isNotEmpty, true);

    final dec = await cb.decryptStringForNote(
      userId: userId,
      noteId: noteId,
      data: enc,
    );
    expect(dec, text);
  });
}
