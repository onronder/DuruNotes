import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_filter_chips.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
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
  
  group('Inbox Preset Chip', () {
    late MockNotesRepository mockRepository;
    late MockAppDb mockDb;
    
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockRepository = MockNotesRepository();
      mockDb = MockAppDb();
      
      when(mockRepository.db).thenReturn(mockDb);
    });
    
    Widget createTestWidget({
      required Widget child,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(mockRepository),
          userIdProvider.overrideWithValue('test_user'),
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
    
    testWidgets('should show Inbox chip when Incoming Mail folder exists with notes', 
        (tester) async {
      // Setup: Create incoming mail folder with notes
      final incomingMailFolder = LocalFolder(
        id: 'inbox_folder',
        name: 'Incoming Mail',
        path: '/Incoming Mail',
        color: '#2196F3',
        icon: '📧',
        description: 'Automatically organized notes from incoming emails',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockRepository.listFolders())
          .thenAnswer((_) async => [incomingMailFolder]);
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 5);
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should show Inbox chip with count
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // Count badge
    });
    
    testWidgets('should hide Inbox chip when no Incoming Mail folder exists', 
        (tester) async {
      when(mockRepository.listFolders())
          .thenAnswer((_) async => []); // No folders
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should not show Inbox chip
      expect(find.text('Inbox'), findsNothing);
      expect(find.byIcon(Icons.inbox), findsNothing);
    });
    
    testWidgets('should hide Inbox chip when folder has no notes and not active', 
        (tester) async {
      final incomingMailFolder = LocalFolder(
        id: 'inbox_folder',
        name: 'Incoming Mail',
        path: '/Incoming Mail',
        color: '#2196F3',
        icon: '📧',
        description: 'Automatically organized notes from incoming emails',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockRepository.listFolders())
          .thenAnswer((_) async => [incomingMailFolder]);
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 0); // No notes
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should not show Inbox chip when empty
      expect(find.text('Inbox'), findsNothing);
      expect(find.byIcon(Icons.inbox), findsNothing);
    });
    
    testWidgets('should activate folder filter when tapped', (tester) async {
      final incomingMailFolder = LocalFolder(
        id: 'inbox_folder',
        name: 'Incoming Mail',
        path: '/Incoming Mail',
        color: '#2196F3',
        icon: '📧',
        description: 'Automatically organized notes from incoming emails',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockRepository.listFolders())
          .thenAnswer((_) async => [incomingMailFolder]);
      when(mockRepository.getFolder('inbox_folder'))
          .thenAnswer((_) async => incomingMailFolder);
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 3);
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      LocalFolder? selectedFolder;
      
      await tester.pumpWidget(
        createTestWidget(
          child: FolderFilterChips(
            onFolderSelected: (folder) {
              selectedFolder = folder;
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap the Inbox chip
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      
      // Verify folder was selected
      verify(mockRepository.getFolder('inbox_folder')).called(1);
    });
    
    testWidgets('should deactivate filter when tapped again', (tester) async {
      final incomingMailFolder = LocalFolder(
        id: 'inbox_folder',
        name: 'Incoming Mail',
        path: '/Incoming Mail',
        color: '#2196F3',
        icon: '📧',
        description: 'Automatically organized notes from incoming emails',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockRepository.listFolders())
          .thenAnswer((_) async => [incomingMailFolder]);
      when(mockRepository.getFolder('inbox_folder'))
          .thenAnswer((_) async => incomingMailFolder);
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 3);
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      LocalFolder? selectedFolder;
      int selectionCount = 0;
      
      await tester.pumpWidget(
        createTestWidget(
          child: FolderFilterChips(
            onFolderSelected: (folder) {
              selectedFolder = folder;
              selectionCount++;
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap to activate
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      
      // Tap again to deactivate
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      
      // Should have been called twice (activate and deactivate)
      expect(selectionCount, 2);
    });
    
    testWidgets('should update count when notes change', (tester) async {
      final incomingMailFolder = LocalFolder(
        id: 'inbox_folder',
        name: 'Incoming Mail',
        path: '/Incoming Mail',
        color: '#2196F3',
        icon: '📧',
        description: 'Automatically organized notes from incoming emails',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockRepository.listFolders())
          .thenAnswer((_) async => [incomingMailFolder]);
      
      // Start with 2 notes
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 2);
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should show count of 2
      expect(find.text('2'), findsOneWidget);
      
      // Update count to 5
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 5);
      
      // Rebuild widget to simulate count change
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should show updated count of 5
      expect(find.text('5'), findsOneWidget);
    });
    
    testWidgets('should handle case-insensitive folder name matching', (tester) async {
      final incomingMailFolder = LocalFolder(
        id: 'inbox_folder',
        name: 'INCOMING MAIL', // Different case
        path: '/INCOMING MAIL',
        color: '#2196F3',
        icon: '📧',
        description: 'Automatically organized notes from incoming emails',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      when(mockRepository.listFolders())
          .thenAnswer((_) async => [incomingMailFolder]);
      when(mockDb.countNotesInFolder('inbox_folder'))
          .thenAnswer((_) async => 3);
      when(mockDb.countUnfiledNotes())
          .thenAnswer((_) async => 0);
      
      await tester.pumpWidget(
        createTestWidget(
          child: const FolderFilterChips(),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should still find and show the Inbox chip
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
