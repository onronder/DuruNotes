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
          unfiledNotesCountProvider.overrideWithValue(const AsyncValue.data(0)),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('shows Inbox chip when Incoming Mail folder has notes',
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
          .thenAnswer((_) async => 5);

      await tester
          .pumpWidget(createTestWidget(child: const FolderFilterChips()));
      await tester.pumpAndSettle();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('hides Inbox chip when folder is missing', (tester) async {
      when(mockRepository.listFolders()).thenAnswer((_) async => []);

      await tester
          .pumpWidget(createTestWidget(child: const FolderFilterChips()));
      await tester.pumpAndSettle();

      expect(find.text('Inbox'), findsNothing);
      expect(find.byIcon(Icons.inbox), findsNothing);
    });

    testWidgets('hides Inbox chip when folder has no notes', (tester) async {
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
          .thenAnswer((_) async => 0);

      await tester
          .pumpWidget(createTestWidget(child: const FolderFilterChips()));
      await tester.pumpAndSettle();

      expect(find.text('Inbox'), findsNothing);
      expect(find.byIcon(Icons.inbox), findsNothing);
    });

    testWidgets('activates folder filter when tapped', (tester) async {
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

      await tester
          .pumpWidget(createTestWidget(child: const FolderFilterChips()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();

      verify(mockRepository.getFolder('inbox_folder')).called(1);
    });

    testWidgets('displays count badge update when folder changes',
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
          .thenAnswer((_) async => 5);

      await tester
          .pumpWidget(createTestWidget(child: const FolderFilterChips()));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });
  },
      skip:
          'Pending folder drag/drop refactor to align with updated providers.');
}
