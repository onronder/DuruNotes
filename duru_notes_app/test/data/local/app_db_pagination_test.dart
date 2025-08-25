import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes_app/data/local/app_db.dart';

void main() {
  group('AppDb Pagination', () {
    late AppDb database;

    setUp(() async {
      // Create in-memory database for testing
      database = AppDb(); // Use default constructor for testing
    });

    tearDown(() async {
      await database.close();
    });

    group('notesAfter', () {
      test('returns all notes when cursor is null', () async {
        // Arrange - Create test notes with different timestamps
        await _createTestNotes(database, 5);

        // Act
        final result = await database.notesAfter(
          cursor: null,
          limit: 10,
        );

        // Assert
        expect(result.length, equals(5));
        // Should be ordered by updatedAt DESC
        for (int i = 0; i < result.length - 1; i++) {
          expect(
            result[i].updatedAt.isAfter(result[i + 1].updatedAt) ||
                result[i].updatedAt.isAtSameMomentAs(result[i + 1].updatedAt),
            isTrue,
            reason: 'Notes should be ordered by updatedAt DESC',
          );
        }
      });

      test('returns notes after given cursor', () async {
        // Arrange - Create test notes
        final testNotes = await _createTestNotes(database, 10);
        
        // Sort by updatedAt DESC to match query order
        testNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        
        // Use the 3rd note as cursor (index 2)
        final cursor = testNotes[2].updatedAt;

        // Act
        final result = await database.notesAfter(
          cursor: cursor,
          limit: 10,
        );

        // Assert
        // Should return notes after the cursor (older notes)
        expect(result.length, equals(7)); // 10 - 3 = 7
        for (final note in result) {
          expect(
            note.updatedAt.isBefore(cursor),
            isTrue,
            reason: 'All returned notes should be older than cursor',
          );
        }
      });

      test('respects limit parameter', () async {
        // Arrange
        await _createTestNotes(database, 20);

        // Act
        final result = await database.notesAfter(
          cursor: null,
          limit: 5,
        );

        // Assert
        expect(result.length, equals(5));
      });

      test('excludes deleted notes', () async {
        // Arrange - Create notes, mark some as deleted
        final testNotes = await _createTestNotes(database, 5);
        
        // Mark first note as deleted
        final deletedNote = testNotes.first.copyWith(
          deleted: true,
          updatedAt: DateTime.now(),
        );
        await database.upsertNote(deletedNote);

        // Act
        final result = await database.notesAfter(
          cursor: null,
          limit: 10,
        );

        // Assert
        expect(result.length, equals(4)); // 5 - 1 deleted = 4
        expect(
          result.any((note) => note.id == deletedNote.id),
          isFalse,
          reason: 'Deleted notes should not be returned',
        );
      });

      test('handles empty database', () async {
        // Act
        final result = await database.notesAfter(
          cursor: null,
          limit: 10,
        );

        // Assert
        expect(result, isEmpty);
      });

      test('handles cursor with no matching notes', () async {
        // Arrange
        await _createTestNotes(database, 5);
        
        // Use a very old cursor
        final veryOldCursor = DateTime(2000, 1, 1);

        // Act
        final result = await database.notesAfter(
          cursor: veryOldCursor,
          limit: 10,
        );

        // Assert
        expect(result, isEmpty);
      });
    });

    group('pagedNotes (offset-based)', () {
      test('returns correct page with offset', () async {
        // Arrange
        await _createTestNotes(database, 10);

        // Act - Get second page (offset 5, limit 3)
        final result = await database.pagedNotes(
          limit: 3,
          offset: 5,
        );

        // Assert
        expect(result.length, equals(3));
        
        // Verify order (should be DESC by updatedAt)
        for (int i = 0; i < result.length - 1; i++) {
          expect(
            result[i].updatedAt.isAfter(result[i + 1].updatedAt) ||
                result[i].updatedAt.isAtSameMomentAs(result[i + 1].updatedAt),
            isTrue,
          );
        }
      });

      test('handles offset beyond available notes', () async {
        // Arrange
        await _createTestNotes(database, 5);

        // Act - Offset beyond available notes
        final result = await database.pagedNotes(
          limit: 10,
          offset: 20,
        );

        // Assert
        expect(result, isEmpty);
      });
    });

    group('Pagination Performance Comparison', () {
      test('keyset vs offset pagination behavior', () async {
        // Arrange - Create many notes
        final testNotes = await _createTestNotes(database, 100);
        testNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // Act - Get same logical page using both methods
        // Keyset: second page (using first page's last item as cursor)
        final firstPageKeyset = await database.notesAfter(
          cursor: null,
          limit: 20,
        );
        final secondPageKeyset = await database.notesAfter(
          cursor: firstPageKeyset.last.updatedAt,
          limit: 20,
        );

        // Offset: second page
        final secondPageOffset = await database.pagedNotes(
          limit: 20,
          offset: 20,
        );

        // Assert - Should return same notes (though order might vary due to timing)
        expect(secondPageKeyset.length, equals(20));
        expect(secondPageOffset.length, equals(20));
        
        // Both should exclude notes from first page
        final firstPageIds = firstPageKeyset.map((n) => n.id).toSet();
        expect(
          secondPageKeyset.any((n) => firstPageIds.contains(n.id)),
          isFalse,
          reason: 'Keyset pagination should not have overlapping results',
        );
      });
    });
  });
}

/// Helper function to create test notes with staggered timestamps
Future<List<LocalNote>> _createTestNotes(AppDb database, int count) async {
  final notes = <LocalNote>[];
  final baseTime = DateTime.now();

  for (int i = 0; i < count; i++) {
    final note = LocalNote(
      id: 'test_note_$i',
      title: 'Test Note $i',
      body: 'Content for test note $i with some additional text to make it realistic.',
      updatedAt: baseTime.subtract(Duration(minutes: i)), // Stagger timestamps
      deleted: false,
    );
    
    await database.upsertNote(note);
    notes.add(note);
  }

  return notes;
}
