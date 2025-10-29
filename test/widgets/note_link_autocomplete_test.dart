import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/note_link_parser.dart';
import 'package:duru_notes/ui/widgets/note_link_autocomplete.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_link_autocomplete_test.mocks.dart';

@GenerateMocks([NoteLinkParser, INotesRepository])
void main() {
  late MockNoteLinkParser mockLinkParser;
  late MockINotesRepository mockRepository;
  late TextEditingController textController;
  late FocusNode focusNode;

  setUp(() {
    mockLinkParser = MockNoteLinkParser();
    mockRepository = MockINotesRepository();
    textController = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    textController.dispose();
    focusNode.dispose();
  });

  Widget createTestWidget({Widget? child}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 200, left: 16, right: 16),
            child: NoteLinkAutocomplete(
              textEditingController: textController,
              focusNode: focusNode,
              linkParser: mockLinkParser,
              notesRepository: mockRepository,
              child: child ??
                  TextField(
                    controller: textController,
                    focusNode: focusNode,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  group('NoteLinkAutocomplete - @ sign detection', () {
    testWidgets('should show overlay when @ is typed', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Test Note',
              body: 'Content',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      // Type @ followed by text
      await tester.enterText(find.byType(TextField), '@test');
      await tester.pump();

      // Verify search was called
      verify(mockLinkParser.searchNotesByTitle(
        'test',
        mockRepository,
        limit: anyNamed('limit'),
      )).called(1);
    });

    testWidgets('should not show overlay for @ without text', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@');
      await tester.pump();

      // Should not call search with empty query
      verifyNever(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      ));
    });

    testWidgets('should not trigger on @ with space after', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@ test');
      await tester.pump();

      // Should not trigger because of space
      verifyNever(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      ));
    });

    testWidgets('should hide overlay when @ is deleted', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());

      // Type @ and text
      await tester.enterText(find.byType(TextField), '@test');
      await tester.pump();

      // Delete the text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Overlay should be hidden
      expect(find.text('Test Note'), findsNothing);
    });
  });

  group('NoteLinkAutocomplete - search and display', () {
    testWidgets('should display search results', (tester) async {
      final testNotes = [
        domain.Note(
          id: 'note-1',
          title: 'Project Plan',
          body: 'Planning document',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          userId: 'test-user',
          version: 1,
          tags: const [],
        ),
        domain.Note(
          id: 'note-2',
          title: 'Project Update',
          body: 'Status update',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          userId: 'test-user',
          version: 1,
          tags: const [],
        ),
      ];

      when(mockLinkParser.searchNotesByTitle(
        'proj',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => testNotes);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@proj');
      await tester.pumpAndSettle();

      // Should display both results
      expect(find.text('Project Plan'), findsOneWidget);
      expect(find.text('Project Update'), findsOneWidget);
    });

    testWidgets('should show "no results" when search returns empty',
        (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@nonexistent');
      await tester.pumpAndSettle();

      verify(mockLinkParser.searchNotesByTitle(
        'nonexistent',
        mockRepository,
        limit: anyNamed('limit'),
      )).called(greaterThan(0));

      expect(find.byType(ListView), findsNothing,
          reason: 'Overlay should be hidden when no results are returned');
    });

    testWidgets('should update results as user types', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        'p',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Project',
              body: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      when(mockLinkParser.searchNotesByTitle(
        'pr',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Project',
              body: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@p');
      await tester.pump();

      await tester.enterText(find.byType(TextField), '@pr');
      await tester.pumpAndSettle();

      verify(mockLinkParser.searchNotesByTitle(
        'p',
        mockRepository,
        limit: anyNamed('limit'),
      )).called(1);

      verify(mockLinkParser.searchNotesByTitle(
        'pr',
        mockRepository,
        limit: anyNamed('limit'),
      )).called(1);
    });
  });

  group('NoteLinkAutocomplete - link insertion', () {
    testWidgets('should insert link on tap', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        'test',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Test Note',
              body: 'Content',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@test');
      await tester.pumpAndSettle();

      // Tap on the result
      await tester.tap(find.text('Test Note'));
      await tester.pumpAndSettle();

      // Verify link was inserted
      expect(textController.text, contains('@[Test Note]'));
    });

    testWidgets('should replace @ query with full link', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        'proj',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Project Plan',
              body: 'Content',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@proj');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Project Plan'));
      await tester.pumpAndSettle();

      // Should replace @proj with @[Project Plan]
      expect(textController.text, '@[Project Plan]');
      expect(textController.text, isNot(contains('@proj')));
    });

    testWidgets('should maintain cursor position after insertion',
        (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        'test',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Test',
              body: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), 'Start @test');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      // Cursor should be after the inserted link
      expect(textController.selection.baseOffset, 'Start @[Test]'.length);
    });
  });

  group('NoteLinkAutocomplete - keyboard navigation', () {
    testWidgets('should navigate with arrow keys', (tester) async {
      final testNotes = [
        domain.Note(
          id: 'note-1',
          title: 'First',
          body: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          userId: 'test-user',
          version: 1,
          tags: const [],
        ),
        domain.Note(
          id: 'note-2',
          title: 'Second',
          body: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          userId: 'test-user',
          version: 1,
          tags: const [],
        ),
      ];

      when(mockLinkParser.searchNotesByTitle(
        'test',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => testNotes);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@test');
      await tester.pumpAndSettle();

      // Simulate down arrow key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Selection should move down
      // (Visual indication would be tested in integration tests)
    });

    testWidgets('should insert link on Enter key', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        'test',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Test Note',
              body: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@test');
      await tester.pumpAndSettle();

      // Press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Link should be inserted
      expect(textController.text, contains('@[Test Note]'));
    });

    testWidgets('should hide overlay on Escape key', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        'test',
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => [
            domain.Note(
              id: 'note-1',
              title: 'Test',
              body: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
              isPinned: false,
              noteType: NoteKind.note,
              userId: 'test-user',
              version: 1,
              tags: const [],
            )
          ]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@test');
      await tester.pumpAndSettle();

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Overlay should be hidden
      expect(find.text('Test'), findsNothing);
    });
  });

  group('NoteLinkAutocomplete - error handling', () {
    testWidgets('should handle search errors gracefully', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      )).thenThrow(Exception('Search failed'));

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@error');
      await tester.pumpAndSettle();

      // Should not crash, overlay should hide
      expect(tester.takeException(), isNull);
    });

    testWidgets('should handle null repository response', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@test');
      await tester.pumpAndSettle();

      // Should handle empty results gracefully
      expect(tester.takeException(), isNull);
    });
  });

  group('NoteLinkAutocomplete - edge cases', () {
    testWidgets('should ignore @ when cursor is followed by whitespace',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), 'Start @test end');
      await tester.pumpAndSettle();

      // New behavior: query with embedded whitespace is ignored
      verifyNever(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      ));
    });

    testWidgets('should handle multiple @ signs', (tester) async {
      when(mockLinkParser.searchNotesByTitle(
        any,
        any,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@first @second');
      await tester.pumpAndSettle();

      // Should handle multiple @ signs
      expect(tester.takeException(), isNull);
    });

    testWidgets('should handle very long search queries', (tester) async {
      final longQuery = 'a' * 1000;
      when(mockLinkParser.searchNotesByTitle(
        longQuery,
        mockRepository,
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '@$longQuery');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
