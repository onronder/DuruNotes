import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Normalize task content for stable hashing and duplicate prevention
String normalizeTaskContent(String content) {
  // Collapse all whitespace to single spaces and trim
  final collapsed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Lowercase for case-insensitive stability
  return collapsed.toLowerCase();
}

/// Generate a stable SHA-256 hash for a task using noteId + normalized content
/// This is deterministic across processes/versions (unlike Dart's hashCode)
String stableTaskHash(String noteId, String content) {
  final normalized = normalizeTaskContent(content);
  final input = '$noteId|$normalized';
  return crypto.sha256.convert(utf8.encode(input)).toString();
}
