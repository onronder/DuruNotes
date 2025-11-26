import 'package:uuid/uuid.dart';

/// Test utilities for UUID handling in reminder system migration
///
/// This helper provides:
/// - Deterministic UUID generation for consistent testing
/// - UUID validation
/// - Test data generation
class UuidTestHelper {
  static const _uuid = Uuid();
  static final _cache = <String, String>{};

  /// Get consistent UUID for testing (same input = same UUID)
  ///
  /// This is useful for tests that need predictable IDs.
  /// Example:
  /// ```dart
  /// final id1 = UuidTestHelper.deterministicUuid('reminder-1');
  /// final id2 = UuidTestHelper.deterministicUuid('reminder-1');
  /// expect(id1, equals(id2)); // true - same seed produces same UUID
  /// ```
  static String deterministicUuid(String seed) {
    return _cache.putIfAbsent(seed, () => _uuid.v5(Uuid.NAMESPACE_OID, seed));
  }

  /// Generate new random UUID (v4)
  ///
  /// Use this when you need a truly random UUID in tests.
  static String randomUuid() => _uuid.v4();

  /// Validate UUID format (RFC 4122)
  ///
  /// Returns true if the value is a valid UUID string in the format:
  /// xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  ///
  /// Example:
  /// ```dart
  /// expect(UuidTestHelper.isValidUuid('550e8400-e29b-41d4-a716-446655440000'), isTrue);
  /// expect(UuidTestHelper.isValidUuid('not-a-uuid'), isFalse);
  /// expect(UuidTestHelper.isValidUuid('123'), isFalse);
  /// ```
  static bool isValidUuid(String? value) {
    if (value == null || value.isEmpty) return false;
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return pattern.hasMatch(value);
  }

  /// Clear the deterministic UUID cache
  ///
  /// Use this in setUp/tearDown to ensure test isolation.
  static void clearCache() => _cache.clear();

  /// Generate a list of deterministic UUIDs
  ///
  /// Useful for creating test data sets.
  /// Example:
  /// ```dart
  /// final ids = UuidTestHelper.generateList('reminder', count: 5);
  /// // ['uuid-for-reminder-0', 'uuid-for-reminder-1', ...]
  /// ```
  static List<String> generateList(String prefix, {required int count}) {
    return List.generate(count, (index) => deterministicUuid('$prefix-$index'));
  }

  /// Common test UUIDs for convenience
  static String get testReminder1 => deterministicUuid('test-reminder-1');
  static String get testReminder2 => deterministicUuid('test-reminder-2');
  static String get testReminder3 => deterministicUuid('test-reminder-3');
  static String get testTask1 => deterministicUuid('test-task-1');
  static String get testTask2 => deterministicUuid('test-task-2');
  static String get testNote1 => deterministicUuid('test-note-1');
  static String get testUser1 => deterministicUuid('test-user-1');
}
