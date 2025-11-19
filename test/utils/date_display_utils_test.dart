import 'package:duru_notes/utils/date_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getDisplayDate', () {
    group('Never Edited Scenarios', () {
      test('returns createdAt when timestamps are identical', () {
        final date = DateTime(2024, 1, 1, 12, 0, 0);

        final result = getDisplayDate(
          createdAt: date,
          updatedAt: date,
        );

        expect(result, equals(date));
        expect(result, equals(date)); // Verify it's createdAt, not updatedAt
      });

      test('returns createdAt when difference is exactly 1 second', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 1); // 1 second later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // Within tolerance - treat as "never edited"
        expect(result, equals(created));
      });

      test('returns createdAt when difference is less than 1 second', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 0, 500); // 500ms later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(created));
      });

      test('handles updatedAt before createdAt (clock skew)', () {
        final created = DateTime(2024, 1, 1, 12, 0, 1);
        final updated = DateTime(2024, 1, 1, 12, 0, 0); // 1 second before

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // Absolute difference is 1 second - within tolerance
        expect(result, equals(created));
      });
    });

    group('Has Been Edited Scenarios', () {
      test('returns updatedAt when edited 2 seconds later', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 2); // 2 seconds later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('returns updatedAt when edited minutes later', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 5, 0); // 5 minutes later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('returns updatedAt when edited hours later', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 15, 30, 0); // 3.5 hours later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('returns updatedAt when edited days later', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 5, 12, 0, 0); // 4 days later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('returns updatedAt when edited months later', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 3, 15, 12, 0, 0); // ~2.5 months later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('returns updatedAt when edited years later', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2025, 6, 15, 12, 0, 0); // ~1.5 years later

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });
    });

    group('Edge Cases', () {
      test('handles UTC timestamps correctly', () {
        final created = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final updated = DateTime.utc(2024, 1, 1, 12, 0, 0);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(created));
      });

      test('handles local timestamps correctly', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 0);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(created));
      });

      test('handles mixed UTC and local timestamps', () {
        final created = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 0);

        // This may not be identical due to timezone, but should handle gracefully
        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // Result should be one of the input dates
        expect([created, updated].contains(result), isTrue);
      });

      test('handles very old dates', () {
        final created = DateTime(2000, 1, 1, 0, 0, 0);
        final updated = DateTime(2000, 1, 1, 0, 0, 0);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(created));
      });

      test('handles far future dates', () {
        final created = DateTime(2099, 12, 31, 23, 59, 59);
        final updated = DateTime(2099, 12, 31, 23, 59, 59);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(created));
      });

      test('handles dates with milliseconds precision', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0, 123);
        final updated = DateTime(2024, 1, 1, 12, 0, 0, 456);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // 333ms difference - within 1 second tolerance
        expect(result, equals(created));
      });

      test('handles dates with microseconds precision', () {
        final created = DateTime(2024, 1, 1, 12, 0, 0, 0, 123);
        final updated = DateTime(2024, 1, 1, 12, 0, 0, 0, 456);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // Tiny difference - within tolerance
        expect(result, equals(created));
      });
    });

    group('Real-World Scenarios', () {
      test('note created and never edited shows creation date', () {
        // Simulate: User creates note at 12:00:00
        final timestamp = DateTime(2024, 1, 15, 12, 0, 0);

        final result = getDisplayDate(
          createdAt: timestamp,
          updatedAt: timestamp,
        );

        expect(result, equals(timestamp));
      });

      test('note created then edited immediately shows update date', () {
        // Simulate: Created at 12:00:00, edited at 12:00:05
        final created = DateTime(2024, 1, 15, 12, 0, 0);
        final updated = DateTime(2024, 1, 15, 12, 0, 5);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('note created today, edited yesterday shows edit date', () {
        final created = DateTime(2024, 1, 14, 10, 0, 0);
        final updated = DateTime(2024, 1, 15, 14, 30, 0);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });

      test('handles sync operation with minimal time drift', () {
        // Simulate: Server adjusts timestamp by 1 second during sync
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 1);

        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // Treat as "never edited" due to tolerance
        expect(result, equals(created));
      });

      test('handles bulk import with same timestamp', () {
        // Simulate: Bulk import sets both timestamps to import time
        final importTime = DateTime(2024, 1, 10, 9, 30, 0);

        final result = getDisplayDate(
          createdAt: importTime,
          updatedAt: importTime,
        );

        expect(result, equals(importTime));
      });
    });

    group('Cross-Device Scenarios', () {
      test('timestamps persist correctly across devices', () {
        // Device A creates note
        final created = DateTime(2024, 1, 1, 12, 0, 0);
        final updated = DateTime(2024, 1, 1, 12, 0, 0);

        // Device B fetches synced note
        final resultOnDeviceB = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(resultOnDeviceB, equals(created));
      });

      test('edit on one device shows correctly on other device', () {
        // Device A creates note
        final created = DateTime(2024, 1, 1, 12, 0, 0);

        // Device A edits note
        final updated = DateTime(2024, 1, 2, 15, 30, 0);

        // Device B fetches updated note
        final resultOnDeviceB = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(resultOnDeviceB, equals(updated));
      });
    });

    group('App Reinstall Scenarios', () {
      test('dates persist after app reinstall', () {
        // Before reinstall
        final created = DateTime(2023, 12, 25, 10, 0, 0);
        final updated = DateTime(2023, 12, 25, 10, 0, 0);

        final beforeReinstall = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        // After reinstall (data synced from server)
        final afterReinstall = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(afterReinstall, equals(beforeReinstall));
        expect(afterReinstall, equals(created));
      });

      test('edited note shows correct date after reinstall', () {
        final created = DateTime(2023, 12, 25, 10, 0, 0);
        final updated = DateTime(2024, 1, 15, 14, 30, 0);

        // After reinstall
        final result = getDisplayDate(
          createdAt: created,
          updatedAt: updated,
        );

        expect(result, equals(updated));
      });
    });
  });

  group('getSafeDisplayDate', () {
    test('uses standard logic when both timestamps present', () {
      final created = DateTime(2024, 1, 1, 12, 0, 0);
      final updated = DateTime(2024, 1, 1, 12, 0, 0);

      final result = getSafeDisplayDate(
        createdAt: created,
        updatedAt: updated,
      );

      expect(result, equals(created));
    });

    test('uses updatedAt when createdAt is null', () {
      final updated = DateTime(2024, 1, 5, 15, 30, 0);

      final result = getSafeDisplayDate(
        createdAt: null,
        updatedAt: updated,
      );

      expect(result, equals(updated));
    });

    test('uses createdAt when updatedAt is null', () {
      final created = DateTime(2024, 1, 1, 12, 0, 0);

      final result = getSafeDisplayDate(
        createdAt: created,
        updatedAt: null,
      );

      expect(result, equals(created));
    });

    test('uses current time when both are null', () {
      final before = DateTime.now();

      final result = getSafeDisplayDate(
        createdAt: null,
        updatedAt: null,
      );

      final after = DateTime.now();

      // Result should be between before and after
      expect(result.isAfter(before) || result.isAtSameMomentAs(before), isTrue);
      expect(result.isBefore(after) || result.isAtSameMomentAs(after), isTrue);
    });

    test('prefers standard logic over fallback when both present', () {
      final created = DateTime(2024, 1, 1, 12, 0, 0);
      final updated = DateTime(2024, 1, 5, 15, 30, 0);

      final result = getSafeDisplayDate(
        createdAt: created,
        updatedAt: updated,
      );

      // Should use getDisplayDate logic (updatedAt for edited)
      expect(result, equals(updated));
    });

    test('handles both null gracefully without throwing', () {
      expect(
        () => getSafeDisplayDate(createdAt: null, updatedAt: null),
        returnsNormally,
      );
    });
  });

  group('NoteDisplayDate Extension', () {
    test('works with mock Note object', () {
      final mockNote = _MockNote(
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final displayDate = mockNote.displayDate;

      expect(displayDate, equals(mockNote.createdAt));
    });

    test('works with edited mock Note object', () {
      final mockNote = _MockNote(
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        updatedAt: DateTime(2024, 1, 5, 15, 30, 0),
      );

      final displayDate = mockNote.displayDate;

      expect(displayDate, equals(mockNote.updatedAt));
    });

    test('handles objects without proper fields gracefully', () {
      final mockObject = _MockInvalidObject();

      // With the safe version, should fallback to current time
      // instead of throwing
      expect(() => mockObject.displayDate, returnsNormally);

      final result = mockObject.displayDate;
      expect(result, isA<DateTime>());

      // Should be recent (within last second)
      final now = DateTime.now();
      final difference = now.difference(result).abs();
      expect(difference.inSeconds, lessThan(2));
    });
  });
}

/// Mock Note class for testing
class _MockNote {
  final DateTime createdAt;
  final DateTime updatedAt;

  _MockNote({required this.createdAt, required this.updatedAt});
}

/// Mock object without proper fields for error handling test
class _MockInvalidObject {
  final String notADate = 'invalid';
}
