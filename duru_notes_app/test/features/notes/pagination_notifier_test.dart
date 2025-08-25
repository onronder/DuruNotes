import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes_app/features/notes/pagination_notifier.dart';
import 'package:duru_notes_app/repository/notes_repository.dart';
import 'package:duru_notes_app/data/local/app_db.dart';

// Generate mocks
@GenerateMocks([NotesRepository])
import 'pagination_notifier_test.mocks.dart';

void main() {
  group('NotesPaginationNotifier', () {
    late MockNotesRepository mockRepository;
    late ProviderContainer container;
    late NotesPaginationNotifier notifier;

    setUp(() {
      mockRepository = MockNotesRepository();
      container = ProviderContainer();
      notifier = NotesPaginationNotifier(mockRepository);
    });

    tearDown(() {
      container.dispose();
    });

    group('loadMore', () {
      test('loads first page successfully', () async {
        // Arrange
        final testNotes = _createTestNotes(20);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => testNotes);

        // Act
        await notifier.loadMore();

        // Assert
        final state = notifier.state.value!;
        expect(state.items.length, equals(20));
        expect(state.hasMore, isTrue); // Full page means more might exist
        expect(state.nextCursor, equals(testNotes.last.updatedAt));
        expect(state.isLoading, isFalse);
      });

      test('loads subsequent page successfully', () async {
        // Arrange - First page
        final firstPage = _createTestNotes(20);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => firstPage);
        await notifier.loadMore();

        // Arrange - Second page
        final secondPage = _createTestNotes(15, startId: 21);
        when(mockRepository.listAfter(firstPage.last.updatedAt, limit: 20))
            .thenAnswer((_) async => secondPage);

        // Act
        await notifier.loadMore();

        // Assert
        final state = notifier.state.value!;
        expect(state.items.length, equals(35)); // 20 + 15
        expect(state.hasMore, isFalse); // Partial page means no more
        expect(state.nextCursor, equals(secondPage.last.updatedAt));
      });

      test('handles empty result correctly', () async {
        // Arrange
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => []);

        // Act
        await notifier.loadMore();

        // Assert
        final state = notifier.state.value!;
        expect(state.items.length, equals(0));
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, isNull);
      });

      test('handles error correctly', () async {
        // Arrange
        when(mockRepository.listAfter(null, limit: 20))
            .thenThrow(Exception('Database error'));

        // Act
        await notifier.loadMore();

        // Assert
        expect(notifier.state.hasError, isTrue);
        expect(notifier.state.error.toString(), contains('Database error'));
      });

      test('prevents concurrent loading', () async {
        // Arrange
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return _createTestNotes(20);
        });

        // Act - Start two loads simultaneously
        final future1 = notifier.loadMore();
        final future2 = notifier.loadMore(); // This should be ignored

        await Future.wait([future1, future2]);

        // Assert - Only one call should have been made
        verify(mockRepository.listAfter(null, limit: 20)).called(1);
      });

      test('stops loading when hasMore is false', () async {
        // Arrange - Load a partial page first
        final partialPage = _createTestNotes(10);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => partialPage);
        await notifier.loadMore();

        // Act - Try to load more
        await notifier.loadMore();

        // Assert - Should not make another call
        verify(mockRepository.listAfter(null, limit: 20)).called(1);
        verifyNoMoreInteractions(mockRepository);
      });
    });

    group('refresh', () {
      test('resets pagination and loads first page', () async {
        // Arrange - Load initial data
        final initialNotes = _createTestNotes(20);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => initialNotes);
        await notifier.loadMore();

        // Arrange - New data for refresh
        final refreshedNotes = _createTestNotes(15);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => refreshedNotes);

        // Act
        await notifier.refresh();

        // Assert
        final state = notifier.state.value!;
        expect(state.items.length, equals(15));
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, equals(refreshedNotes.last.updatedAt));
      });
    });

    group('checkLoadMore', () {
      test('triggers loadMore when near bottom', () async {
        // Arrange
        final testNotes = _createTestNotes(20);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => testNotes);
        await notifier.loadMore();

        // Arrange second page
        final secondPage = _createTestNotes(20, startId: 21);
        when(mockRepository.listAfter(testNotes.last.updatedAt, limit: 20))
            .thenAnswer((_) async => secondPage);

        // Act - Simulate scroll near bottom
        notifier.checkLoadMore(1000, 1200); // Within 400px threshold

        // Give async operation time to complete
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert
        verify(mockRepository.listAfter(testNotes.last.updatedAt, limit: 20)).called(1);
      });

      test('does not trigger loadMore when not near bottom', () async {
        // Arrange
        final testNotes = _createTestNotes(20);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => testNotes);
        await notifier.loadMore();

        // Act - Simulate scroll not near bottom
        notifier.checkLoadMore(100, 1200); // More than 400px from bottom

        // Assert
        verifyNoMoreInteractions(mockRepository);
      });
    });

    group('currentPage getter', () {
      test('returns current page state', () async {
        // Arrange
        final testNotes = _createTestNotes(10);
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async => testNotes);

        // Act
        await notifier.loadMore();

        // Assert
        final currentPage = notifier.currentPage;
        expect(currentPage, isNotNull);
        expect(currentPage!.items.length, equals(10));
        expect(currentPage.hasMore, isFalse);
      });
    });

    group('isLoadingMore getter', () {
      test('returns loading state correctly', () async {
        // Initial state
        expect(notifier.isLoadingMore, isFalse);

        // Arrange slow loading
        when(mockRepository.listAfter(null, limit: 20))
            .thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _createTestNotes(20);
        });

        // Act
        final future = notifier.loadMore();
        
        // Assert during loading
        expect(notifier.isLoadingMore, isTrue);
        
        // Wait for completion
        await future;
        
        // Assert after loading
        expect(notifier.isLoadingMore, isFalse);
      });
    });
  });

  group('NotesPage', () {
    test('equality works correctly', () {
      final notes1 = _createTestNotes(5);
      final notes2 = _createTestNotes(5);
      final cursor = DateTime.now();

      final page1 = NotesPage(
        items: notes1,
        hasMore: true,
        nextCursor: cursor,
      );

      final page2 = NotesPage(
        items: notes2,
        hasMore: true,
        nextCursor: cursor,
      );

      // Same structure should be equal
      expect(page1, equals(page2));
    });

    test('copyWith works correctly', () {
      final notes = _createTestNotes(5);
      final cursor = DateTime.now();

      final original = NotesPage(
        items: notes,
        hasMore: true,
        nextCursor: cursor,
      );

      final copied = original.copyWith(hasMore: false);

      expect(copied.items, equals(original.items));
      expect(copied.hasMore, isFalse);
      expect(copied.nextCursor, equals(original.nextCursor));
    });
  });
}

/// Helper function to create test notes
List<LocalNote> _createTestNotes(int count, {int startId = 1}) {
  return List.generate(count, (index) {
    final id = startId + index;
    return LocalNote(
      id: 'note_$id',
      title: 'Test Note $id',
      body: 'This is the content of test note $id',
      updatedAt: DateTime.now().subtract(Duration(minutes: id)),
      deleted: false,
    );
  });
}
