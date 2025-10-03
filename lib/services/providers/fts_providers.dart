import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/services/fts_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides FTS (Full-Text Search) service instance
///
/// This service manages application-level FTS indexing for encrypted content.
/// It replaces SQL triggers that cannot decrypt data.
final ftsServiceProvider = Provider<FtsService>((ref) {
  final db = ref.watch(appDbProvider);
  return FtsService(db: db);
});
