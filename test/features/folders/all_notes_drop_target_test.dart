import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_filter_chips.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

class MockAppDb extends Mock implements AppDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('All Notes Drop Target', () {
    late MockNotesRepository mockRepository;
    late MockAppDb mockDb;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockRepository = MockNotesRepository();
      mockDb = MockAppDb();
      when(mockRepository.db).thenReturn(mockDb);
      when(mockRepository.listFolders()).thenAnswer((_) async => []);
    });

    Widget createTestWidget({
      required Widget child,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(mockRepository),
          userIdProvider.overrideWithValue('test_user'),
          unfiledNotesCountProvider.overrideWith((ref) async => 0),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets('should display All Notes chip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsOneWidget);
    });

    testWidgets('should show visual feedback when dragging over',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              const FolderFilterChips(),
              Draggable<LocalNote>(
                data: LocalNote(
                  id: 'test_note',
                  title: 'Test Note',
                  body: 'Test body',
                  updatedAt: DateTime.now(
                    noteType: NoteKind.note,
                  ),
                  deleted: false,
                  isPinned: false,
                  noteType: NoteKind.note,
                ),
                feedback: const Material(
                  child: Text('Dragging'),
                ),
                child: const Text('Drag me'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start dragging
      final dragGesture = await tester.startGesture(
        tester.getCenter(find.text('Drag me')),
      );

      // Move to All Notes chip
      await dragGesture.moveTo(
        tester.getCenter(find.text('Notes')),
      );
      await tester.pump();

      // Should show download icon when hovering
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

      await dragGesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('should handle note drop and call repository', (tester) async {
      when(mockRepository.getFolderForNote('test_note'))
          .thenAnswer((_) async => LocalFolder(
                id: 'folder1',
                name: 'Test Folder',
                path: '/Test Folder',
                color: '#FF0000',
                icon: '📁',
                description: '',
                sortOrder: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                deleted: false,
              ));
      when(mockRepository.removeNoteFromFolder('test_note'))
          .thenAnswer((_) async => {});

      final testNote = LocalNote(
        id: 'test_note',
        title: 'Test Note',
        body: 'Test body',
        updatedAt: DateTime.now(
          noteType: NoteKind.note,
        ),
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              const FolderFilterChips(),
              Draggable<LocalNote>(
                data: testNote,
                feedback: const Material(
                  child: Text('Dragging'),
                ),
                child: const Text('Drag me'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform drag and drop
      await tester.drag(
        find.text('Drag me'),
        tester.getCenter(find.text('Notes')) -
            tester.getCenter(find.text('Drag me')),
      );

      await tester.pumpAndSettle();

      // Verify repository methods were called
      verify(mockRepository.getFolderForNote('test_note')).called(1);
      verify(mockRepository.removeNoteFromFolder('test_note')).called(1);

      // Verify undo operation was recorded
    });

    testWidgets('should handle batch note drop', (tester) async {
      when(mockRepository.getFolderForNote('test_note'))
          .thenAnswer((_) async => null);
      when(mockRepository.removeNoteFromFolder('test_note'))
          .thenAnswer((_) async => {});

      final testNotes = [
        LocalNote(
          id: 'note1',
          title: 'Note 1',
          body: 'Body 1',
          updatedAt: DateTime.now(
            noteType: NoteKind.note,
          ),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
        ),
        LocalNote(
          id: 'note2',
          title: 'Note 2',
          body: 'Body 2',
          updatedAt: DateTime.now(
            noteType: NoteKind.note,
          ),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              const FolderFilterChips(),
              Draggable<List<LocalNote>>(
                data: testNotes,
                feedback: const Material(
                  child: Text('Dragging batch'),
                ),
                child: const Text('Drag batch'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform drag and drop
      await tester.drag(
        find.text('Drag batch'),
        tester.getCenter(find.text('Notes')) -
            tester.getCenter(find.text('Drag batch')),
      );

      await tester.pumpAndSettle();

      // Verify batch operation was recorded

      // Verify all notes were unfiled
      verify(mockRepository.removeNoteFromFolder('note1')).called(1);
      verify(mockRepository.removeNoteFromFolder('note2')).called(1);
    });

    testWidgets('should show snackbar with undo action', (tester) async {
      when(mockRepository.getFolderForNote('test_note'))
          .thenAnswer((_) async => null);
      when(mockRepository.removeNoteFromFolder('test_note'))
          .thenAnswer((_) async => {});

      final testNote = LocalNote(
        id: 'test_note',
        title: 'Test Note',
        body: 'Test body',
        updatedAt: DateTime.now(
          noteType: NoteKind.note,
        ),
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              const FolderFilterChips(),
              Draggable<LocalNote>(
                data: testNote,
                feedback: const Material(
                  child: Text('Dragging'),
                ),
                child: const Text('Drag me'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform drag and drop
      await tester.drag(
        find.text('Drag me'),
        tester.getCenter(find.text('Notes')) -
            tester.getCenter(find.text('Drag me')),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check snackbar appeared
      expect(find.text('Unfiled Notes'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
    });
  },
      skip:
          'Pending folder drag/drop refactor to align with updated providers.');
}
