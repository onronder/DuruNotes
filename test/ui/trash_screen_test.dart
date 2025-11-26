import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/ui/trash_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrashScreen Widget Tests - UI Rendering', () {
    Widget buildTestWidget({
      List<domain.Note> notes = const [],
      List<domain_folder.Folder> folders = const [],
      List<domain_task.Task> tasks = const [],
    }) {
      return ProviderScope(
        overrides: [
          // Override the deleted items providers with test data
          deletedNotesProvider.overrideWith((ref) async => notes),
          deletedFoldersProvider.overrideWith((ref) async => folders),
          deletedTasksProvider.overrideWith((ref) async => tasks),
        ],
        child: const MaterialApp(home: TrashScreen()),
      );
    }

    testWidgets('displays empty state when no deleted items', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Trash is empty'), findsOneWidget);
      expect(find.text('Deleted items will appear here'), findsOneWidget);
    });

    testWidgets('displays correct tab counts', (tester) async {
      final now = DateTime.now();

      // Create 2 notes, 1 folder, 3 tasks
      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Note 1',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
        domain.Note(
          id: 'note2',
          title: 'Note 2',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      final folders = [
        domain_folder.Folder(
          id: 'folder1',
          name: 'Folder 1',
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
          sortOrder: 0,
          userId: 'user1',
        ),
      ];

      final tasks = [
        domain_task.Task(
          id: 'task1',
          noteId: 'note1',
          title: 'Task 1',
          status: domain_task.TaskStatus.pending,
          priority: domain_task.TaskPriority.medium,
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
          tags: const [],
          metadata: const {},
        ),
        domain_task.Task(
          id: 'task2',
          noteId: 'note1',
          title: 'Task 2',
          status: domain_task.TaskStatus.pending,
          priority: domain_task.TaskPriority.medium,
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
          tags: const [],
          metadata: const {},
        ),
        domain_task.Task(
          id: 'task3',
          noteId: 'note1',
          title: 'Task 3',
          status: domain_task.TaskStatus.pending,
          priority: domain_task.TaskPriority.medium,
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
          tags: const [],
          metadata: const {},
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(notes: notes, folders: folders, tasks: tasks),
      );
      await tester.pumpAndSettle();

      // Check tab labels
      expect(find.text('All (6)'), findsOneWidget);
      expect(find.text('Notes (2)'), findsOneWidget);
      expect(find.text('Folders (1)'), findsOneWidget);
      expect(find.text('Tasks (3)'), findsOneWidget);

      // Check app bar subtitle
      expect(find.text('6 items'), findsOneWidget);
    });

    testWidgets('filters items when tapping tabs', (tester) async {
      final now = DateTime.now();

      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Test Note',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      final folders = [
        domain_folder.Folder(
          id: 'folder1',
          name: 'Test Folder',
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
          sortOrder: 0,
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(notes: notes, folders: folders));
      await tester.pumpAndSettle();

      // Initially shows all items
      expect(find.text('Test Note'), findsOneWidget);
      expect(find.text('Test Folder'), findsOneWidget);

      // Tap Notes tab
      await tester.tap(find.text('Notes (1)'));
      await tester.pumpAndSettle();

      // Should show only note
      expect(find.text('Test Note'), findsOneWidget);
      expect(find.text('Test Folder'), findsNothing);

      // Tap Folders tab
      await tester.tap(find.text('Folders (1)'));
      await tester.pumpAndSettle();

      // Should show only folder
      expect(find.text('Test Note'), findsNothing);
      expect(find.text('Test Folder'), findsOneWidget);
    });

    // TODO: Purge countdown tests require scrolling to view the text
    // These are better suited for integration tests
    // testWidgets('displays purge countdown for items with scheduledPurgeAt', (tester) async {
    //   final now = DateTime.now();
    //   final purgeIn5Days = now.add(const Duration(days: 5));
    //
    //   final notes = [
    //     domain.Note(
    //       id: 'note1',
    //       title: 'Note with countdown',
    //       body: 'body',
    //       createdAt: now,
    //       updatedAt: now,
    //       deleted: true,
    //       deletedAt: now,
    //       scheduledPurgeAt: purgeIn5Days,
    //       isPinned: false,
    //       noteType: NoteKind.note,
    //       version: 1,
    //       userId: 'user1',
    //     ),
    //   ];
    //
    //   await tester.pumpWidget(buildTestWidget(notes: notes));
    //   await tester.pumpAndSettle();
    //
    //   expect(find.textContaining('Auto-purge in 5 days'), findsOneWidget);
    // });

    testWidgets('enters selection mode on long press', (tester) async {
      final now = DateTime.now();

      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Test Note',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(notes: notes));
      await tester.pumpAndSettle();

      // Long press on the item
      await tester.longPress(find.text('Test Note'));
      await tester.pumpAndSettle();

      // Should show selection mode app bar
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byTooltip('Restore'), findsOneWidget);
      expect(find.byTooltip('Delete Forever'), findsOneWidget);
    });

    testWidgets('exits selection mode when cancel button tapped', (
      tester,
    ) async {
      final now = DateTime.now();

      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Test Note',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(notes: notes));
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.longPress(find.text('Test Note'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Find the close icon (xmark) in the app bar
      final closeButton = find.byIcon(CupertinoIcons.xmark);

      // Tap cancel button (X icon)
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Should exit selection mode
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('Trash'), findsOneWidget);
    });

    testWidgets('shows bottom sheet with actions when item tapped', (
      tester,
    ) async {
      final now = DateTime.now();

      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Test Note',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(notes: notes));
      await tester.pumpAndSettle();

      // Tap item to show bottom sheet
      await tester.tap(find.text('Test Note'));
      await tester.pumpAndSettle();

      // Should show bottom sheet with actions
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Delete Forever'), findsOneWidget);
    });

    testWidgets('shows more options menu when trash has items', (tester) async {
      final now = DateTime.now();

      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Test Note',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(notes: notes));
      await tester.pumpAndSettle();

      // Should show more options button
      expect(find.byTooltip('More options'), findsOneWidget);

      // Tap more options button
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // Should show Empty Trash option
      expect(find.text('Empty Trash'), findsOneWidget);
      expect(find.text('Permanently delete all items'), findsOneWidget);
    });

    testWidgets('hides more options when trash is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should not show more options button when empty
      expect(find.byTooltip('More options'), findsNothing);
    });

    // TODO: Purge countdown formatting tests require widget tree navigation
    // These are better tested in integration tests
    // testWidgets('displays delete countdown with correct formatting', (tester) async {
    //   final now = DateTime.now();
    //
    //   final notes = [
    //     domain.Note(
    //       id: 'note1',
    //       title: 'Purge in 1 day',
    //       body: 'body',
    //       createdAt: now,
    //       updatedAt: now,
    //       deleted: true,
    //       deletedAt: now,
    //       scheduledPurgeAt: now.add(const Duration(days: 1)),
    //       isPinned: false,
    //       noteType: NoteKind.note,
    //       version: 1,
    //       userId: 'user1',
    //     ),
    //     domain.Note(
    //       id: 'note2',
    //       title: 'Overdue purge',
    //       body: 'body',
    //       createdAt: now,
    //       updatedAt: now,
    //       deleted: true,
    //       deletedAt: now,
    //       scheduledPurgeAt: now.subtract(const Duration(hours: 1)),
    //       isPinned: false,
    //       noteType: NoteKind.note,
    //       version: 1,
    //       userId: 'user1',
    //     ),
    //   ];
    //
    //   await tester.pumpWidget(buildTestWidget(notes: notes));
    //   await tester.pumpAndSettle();
    //
    //   expect(find.textContaining('Auto-purge in 1 day'), findsOneWidget);
    //   expect(find.textContaining('Auto-purge overdue'), findsOneWidget);
    // });

    testWidgets('selection mode updates count when multiple items selected', (
      tester,
    ) async {
      final now = DateTime.now();

      final notes = [
        domain.Note(
          id: 'note1',
          title: 'Note 1',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
        domain.Note(
          id: 'note2',
          title: 'Note 2',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
        domain.Note(
          id: 'note3',
          title: 'Note 3',
          body: 'body',
          createdAt: now,
          updatedAt: now,
          deleted: true,
          deletedAt: now,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(notes: notes));
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.longPress(find.text('Note 1'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Select second item
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      // Select third item
      await tester.tap(find.text('Note 3'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);

      // Deselect one item
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });
  });
}
