import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Database provider
final appDbProvider = Provider<AppDb>((ref) {
  return AppDb();
});

/// Key manager provider
final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager(accountKeyService: ref.watch(accountKeyServiceProvider));
});

/// Crypto box provider
final cryptoBoxProvider = Provider<CryptoBox>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return CryptoBox(keyManager);
});

/// Note indexer provider
final noteIndexerProvider = Provider<NoteIndexer>((ref) {
  return NoteIndexer(ref);
});

/// Account key service (AMK) provider
final accountKeyServiceProvider = Provider<AccountKeyService>((ref) {
  return AccountKeyService(ref);
});

/// Database provider alias for compatibility
final Provider<AppDb> dbProvider = appDbProvider;