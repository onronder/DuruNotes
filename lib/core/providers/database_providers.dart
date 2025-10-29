import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global singleton AppDb instance
/// This prevents multiple database instances which cause memory leaks and corruption
final _appDbInstance = AppDb();

/// Get the singleton AppDb instance
/// Use this for code that runs before the Riverpod container is available (e.g., bootstrap)
AppDb getAppDb() => _appDbInstance;

/// Database provider - returns the singleton instance
/// CRITICAL: Do NOT create new AppDb() instances anywhere else in the codebase
/// NOTE: Other providers (keyManager, cryptoBox, noteIndexer, accountKeyService) are in providers.dart
final appDbProvider = Provider<AppDb>((ref) {
  return _appDbInstance;
});

/// Database provider alias for compatibility
final Provider<AppDb> dbProvider = appDbProvider;