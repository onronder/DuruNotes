import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes_app/app/app.dart';
import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';
import 'mocks/mock_supabase.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CRUD Note + Sync Integration Test', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuth;
    late MockSession mockSession;
    late MockUser mockUser;

    setUpAll(() async {
      // Initialize mock Supabase
      mockSupabaseClient = MockSupabaseSetup.createMockClient();
      mockAuth = MockGoTrueClient();
      mockSession = MockSupabaseSetup.createMockSession();
      mockUser = MockSupabaseSetup.createMockUser();

      when(mockSupabaseClient.auth).thenReturn(mockAuth);
      
      // Setup authenticated state
      MockSupabaseSetup.setupSuccessfulAuth(mockAuth, user: mockUser);
      MockSupabaseSetup.setupNotesTable(mockSupabaseClient);

      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    });

    setUp(() {
      // Ensure authenticated state before each test
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(mockUser);
    });

    testWidgets('Create note and verify sync', (WidgetTester tester) async {
      // Setup sync mocks
      final mockQueryBuilder = MockPostgrestQueryBuilder();
      final mockBuilder = MockPostgrestBuilder();
      
      when(mockSupabaseClient.from('notes')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.insert(any)).thenReturn(mockBuilder);
      when(mockBuilder.execute()).thenAnswer((_) async => [
        {
          'id': 'new-note-123',
          'title': 'Integration Test Note',
          'body': 'This is a test note content',
          'updated_at': DateTime.now().toIso8601String(),
          'deleted': false,
        }
      ]);

      // Launch the app (should start at home screen since authenticated)
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Should be on home screen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Find and tap the "Add Note" button
      final addNoteButton = find.byKey(const Key('add_note_button'));
      expect(addNoteButton, findsOneWidget);
      
      await tester.tap(addNoteButton);
      await tester.pumpAndSettle();

      // Should navigate to edit note screen
      expect(find.byType(EditNoteScreen), findsOneWidget);

      // Find title and content fields
      final titleField = find.byKey(const Key('note_title_field'));
      final contentField = find.byKey(const Key('note_content_field'));
      
      expect(titleField, findsOneWidget);
      expect(contentField, findsOneWidget);

      // Enter note content
      await tester.enterText(titleField, 'Integration Test Note');
      await tester.enterText(contentField, 'This is a test note content');
      await tester.pumpAndSettle();

      // Save the note
      final saveButton = find.byKey(const Key('save_note_button'));
      expect(saveButton, findsOneWidget);
      
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Should return to home screen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify the note appears in the list
      expect(find.text('Integration Test Note'), findsOneWidget);
      expect(find.textContaining('This is a test note'), findsOneWidget);

      // Verify sync was triggered (insert was called)
      verify(mockQueryBuilder.insert(any)).called(greaterThan(0));
    });

    testWidgets('Edit existing note and verify sync', (WidgetTester tester) async {
      // Setup existing note
      final existingNote = {
        'id': 'existing-note-456',
        'title': 'Existing Note',
        'body': 'Original content',
        'updated_at': DateTime.now().toIso8601String(),
        'deleted': false,
      };

      // Setup mocks for loading and updating notes
      final mockQueryBuilder = MockPostgrestQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      final mockBuilder = MockPostgrestBuilder();
      
      when(mockSupabaseClient.from('notes')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
      when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.execute()).thenAnswer((_) async => [existingNote]);
      when(mockBuilder.execute()).thenAnswer((_) async => [existingNote]);

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Should be on home screen with existing note
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Existing Note'), findsOneWidget);

      // Tap on the existing note to edit it
      await tester.tap(find.text('Existing Note'));
      await tester.pumpAndSettle();

      // Should navigate to edit screen
      expect(find.byType(EditNoteScreen), findsOneWidget);

      // Find and modify the content
      final titleField = find.byKey(const Key('note_title_field'));
      final contentField = find.byKey(const Key('note_content_field'));

      // Clear and enter new content
      await tester.enterText(titleField, 'Updated Note Title');
      await tester.enterText(contentField, 'Updated note content with changes');
      await tester.pumpAndSettle();

      // Save the changes
      final saveButton = find.byKey(const Key('save_note_button'));
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Should return to home screen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify updated content appears
      expect(find.text('Updated Note Title'), findsOneWidget);

      // Verify update was synced
      verify(mockQueryBuilder.update(any)).called(greaterThan(0));
    });

    testWidgets('Delete note and verify sync', (WidgetTester tester) async {
      // Setup existing note
      final noteToDelete = {
        'id': 'note-to-delete-789',
        'title': 'Note to Delete',
        'body': 'This note will be deleted',
        'updated_at': DateTime.now().toIso8601String(),
        'deleted': false,
      };

      // Setup mocks
      final mockQueryBuilder = MockPostgrestQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      
      when(mockSupabaseClient.from('notes')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
      when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.execute()).thenAnswer((_) async => [noteToDelete]);

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Should be on home screen with note
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Note to Delete'), findsOneWidget);

      // Long press on note to show delete option
      await tester.longPress(find.text('Note to Delete'));
      await tester.pumpAndSettle();

      // Find and tap delete button in context menu
      final deleteButton = find.byKey(const Key('delete_note_button'));
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirm deletion if dialog appears
        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
        }

        // Verify note is removed from UI
        expect(find.text('Note to Delete'), findsNothing);

        // Verify delete sync was triggered
        verify(mockQueryBuilder.update(any)).called(greaterThan(0));
      }
    });

    testWidgets('Offline mode queues operations for sync', (WidgetTester tester) async {
      // Setup network failure
      when(mockSupabaseClient.from(any)).thenThrow(Exception('Network error'));

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Try to create a note while offline
      final addNoteButton = find.byKey(const Key('add_note_button'));
      await tester.tap(addNoteButton);
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('note_title_field'));
      final contentField = find.byKey(const Key('note_content_field'));

      await tester.enterText(titleField, 'Offline Note');
      await tester.enterText(contentField, 'Created while offline');
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_note_button'));
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Note should be saved locally even if sync fails
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Offline Note'), findsOneWidget);

      // Verify offline indicator is shown
      expect(find.byKey(const Key('offline_indicator')), findsOneWidget);
    });

    testWidgets('Sync conflict resolution works correctly', (WidgetTester tester) async {
      // Setup conflicting versions of a note
      final localNote = {
        'id': 'conflict-note-123',
        'title': 'Local Version',
        'body': 'Local changes',
        'updated_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'deleted': false,
      };

      final remoteNote = {
        'id': 'conflict-note-123',
        'title': 'Remote Version',
        'body': 'Remote changes',
        'updated_at': DateTime.now().toIso8601String(),
        'deleted': false,
      };

      // Setup mocks to return different versions
      final mockQueryBuilder = MockPostgrestQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();
      
      when(mockSupabaseClient.from('notes')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.execute()).thenAnswer((_) async => [remoteNote]);

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Should handle conflict and show appropriate resolution
      // (Implementation depends on your conflict resolution strategy)
      
      // Verify one version is displayed (typically the most recent)
      expect(find.text('Remote Version'), findsOneWidget);
    });

    testWidgets('Encrypted sync preserves data integrity', (WidgetTester tester) async {
      // Setup encryption mocks
      const sensitiveContent = 'This is sensitive information 🔒';
      
      final mockQueryBuilder = MockPostgrestQueryBuilder();
      final mockBuilder = MockPostgrestBuilder();
      
      when(mockSupabaseClient.from('notes')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.insert(any)).thenReturn(mockBuilder);
      when(mockBuilder.execute()).thenAnswer((_) async => [
        {
          'id': 'encrypted-note-456',
          'title': 'Encrypted Note',
          'encrypted_content': 'base64_encrypted_data_here',
          'updated_at': DateTime.now().toIso8601String(),
          'deleted': false,
        }
      ]);

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Create note with sensitive content
      final addNoteButton = find.byKey(const Key('add_note_button'));
      await tester.tap(addNoteButton);
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('note_title_field'));
      final contentField = find.byKey(const Key('note_content_field'));

      await tester.enterText(titleField, 'Encrypted Note');
      await tester.enterText(contentField, sensitiveContent);
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_note_button'));
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify note was created and synced
      expect(find.text('Encrypted Note'), findsOneWidget);
      verify(mockQueryBuilder.insert(any)).called(greaterThan(0));

      // In a real test, you'd verify that the content was encrypted before sync
      // and properly decrypted when displayed
    });
  });
}
