import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_management_screen.dart';
import 'package:duru_notes/features/folders/folder_deletion_with_undo.dart';
import 'package:duru_notes/services/folder_undo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
void main() {
  group('Folder Management Screen Tests', () {
    late ProviderContainer container;
    late MockFolderUndoService mockUndoService;

    setUp(() {
      mockUndoService = MockFolderUndoService();
      container = createTestProviderContainer(
        overrides: [
          folderUndoServiceProvider.overrideWithValue(mockUndoService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('FolderManagementScreen displays correctly', (tester) async {
      // Build the widget
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const FolderManagementScreen(),
          ),
        ),
      );

      // Wait for widget to build
      await tester.pumpAndSettle();

      // Verify key elements are present
      expect(find.text('Folder Management'), findsOneWidget);
      expect(find.text('All Folders'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsWidgets);
    });

    testWidgets('Create folder button shows dialog', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const FolderManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the create folder button
      final createButton = find.byIcon(Icons.create_new_folder).first;
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify create folder dialog appears
      expect(find.text('Create Folder'), findsOneWidget);
      expect(find.text('Folder name'), findsOneWidget);
    });

    testWidgets('UndoHistoryFAB appears when there are operations', (tester) async {
      // Mock undo history with operations
      when(mockUndoService.historyStream).thenAnswer(
        (_) => Stream.value([
          FolderUndoOperation(
            id: 'test-op-1',
            type: FolderUndoType.delete,
            timestamp: DateTime.now(),
            originalFolder: LocalFolder(
              id: 'folder-1',
              name: 'Test Folder',
              parentId: null,
              path: '/Test Folder',
              sortOrder: 0,
              description: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
            ),
          ),
        ]),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const FolderManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify undo FAB is present
      expect(find.byType(UndoHistoryFAB), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('Tabs work correctly', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const FolderManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial tab
      expect(find.text('All Folders'), findsOneWidget);

      // Tap Details tab
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Verify details tab content
      expect(find.text('Select a Folder'), findsOneWidget);
    });

    testWidgets('App bar actions work', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const FolderManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the more menu
      final moreButton = find.byIcon(Icons.more_vert);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // Verify menu items
      expect(find.text('Create New Folder'), findsOneWidget);
      expect(find.text('Expand All'), findsOneWidget);
      expect(find.text('Collapse All'), findsOneWidget);
      expect(find.text('Health Check'), findsOneWidget);
    });
  });

  group('Folder Undo Service Tests', () {
    late FolderUndoService undoService;
    late MockFolderRepository mockRepository;

    setUp(() {
      mockRepository = MockFolderRepository();
      undoService = FolderUndoService(mockRepository);
    });

    test('addDeleteOperation creates undo operation', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final operationId = await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: ['note-1', 'note-2'],
        affectedChildFolders: [],
      );

      expect(operationId, isNotNull);
      expect(undoService.currentHistory.length, equals(1));

      final operation = undoService.currentHistory.first;
      expect(operation.type, equals(FolderUndoType.delete));
      expect(operation.originalFolder.id, equals('test-folder'));
      expect(operation.affectedNotes, equals(['note-1', 'note-2']));
    });

    test('getLatestOperation returns most recent operation', () async {
      final folder1 = LocalFolder(
        id: 'folder-1',
        name: 'Folder 1',
        parentId: null,
        path: '/Folder 1',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final folder2 = LocalFolder(
        id: 'folder-2',
        name: 'Folder 2',
        parentId: null,
        path: '/Folder 2',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      await undoService.addDeleteOperation(
        folder: folder1,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await undoService.addDeleteOperation(
        folder: folder2,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      final latest = undoService.getLatestOperation();
      expect(latest?.originalFolder.id, equals('folder-2'));
    });

    test('clearHistory removes all operations', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      expect(undoService.currentHistory.length, equals(1));

      undoService.clearHistory();

      expect(undoService.currentHistory.length, equals(0));
    });

    test('operations expire after 5 minutes', () {
      final expiredOperation = FolderUndoOperation(
        id: 'expired-op',
        type: FolderUndoType.delete,
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
        originalFolder: LocalFolder(
          id: 'test-folder',
          name: 'Test Folder',
          parentId: null,
          path: '/Test Folder',
          sortOrder: 0,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
      );

      expect(expiredOperation.isExpired, isTrue);
    });

    test('fresh operations are not expired', () {
      final freshOperation = FolderUndoOperation(
        id: 'fresh-op',
        type: FolderUndoType.delete,
        timestamp: DateTime.now(),
        originalFolder: LocalFolder(
          id: 'test-folder',
          name: 'Test Folder',
          parentId: null,
          path: '/Test Folder',
          sortOrder: 0,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
      );

      expect(freshOperation.isExpired, isFalse);
    });
  });

  group('Folder Deletion with Undo Mixin Tests', () {
    testWidgets('FolderDeletionWithUndo mixin works', (tester) async {
      late ProviderContainer container;
      late MockFolderUndoService mockUndoService;

      mockUndoService = MockFolderUndoService();
      container = createTestProviderContainer(
        overrides: [
          folderUndoServiceProvider.overrideWithValue(mockUndoService),
        ],
      );

      // Create a test widget that uses the mixin
      final testWidget = _TestFolderDeletionWidget();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: testWidget,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(_TestFolderDeletionWidget), findsOneWidget);

      container.dispose();
    });
  });
}

// Test widget that uses the FolderDeletionWithUndo mixin
class _TestFolderDeletionWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TestFolderDeletionWidget> createState() =>
      _TestFolderDeletionWidgetState();
}

class _TestFolderDeletionWidgetState
    extends ConsumerState<_TestFolderDeletionWidget>
    with FolderDeletionWithUndo {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Widget')),
      body: const Center(
        child: Text('Test Folder Deletion with Undo'),
      ),
    );
  }
}