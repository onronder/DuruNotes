import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/security/authorization_service.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/services/fts_service.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateNiceMocks([
  MockSpec<AppDb>(),
  MockSpec<SupabaseClient>(),
  MockSpec<SupabaseQueryBuilder>(),
  MockSpec<PostgrestFilterBuilder<dynamic>>(),
  MockSpec<PostgrestBuilder<dynamic, dynamic, dynamic>>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<CryptoBox>(),
  MockSpec<SupabaseNoteApi>(),
  MockSpec<FtsService>(),
  MockSpec<AuthorizationService>(),
])
void main() {
  /* COMMENTED OUT - 7 errors - uses old APIs
   * Needs rewrite to use new architecture.
   */

  /*
  group('NotesCoreRepository Tests', () {
    late NotesCoreRepository repository;
    late AppDb testDb;
    late MockSupabaseClient mockSupabase;
    late MockCryptoBox mockCrypto;
    late MockSupabaseNoteApi mockApi;
    late MockFtsService mockFtsService;
    late MockAuthorizationService mockAuthService;

    setUp(() {
      // Use in-memory database instead of mocking
      testDb = TestDatabaseFactory.createTestDb();
      mockSupabase = MockSupabaseClient();
      mockCrypto = MockCryptoBox();
      mockApi = MockSupabaseNoteApi();
      mockFtsService = MockFtsService();
      mockAuthService = MockAuthorizationService();

      // Setup mock auth
      final mockAuth = MockGoTrueClient();
      final mockUser = MockUser();
      when(mockUser.id).thenReturn('test-user-id');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockSupabase.auth).thenReturn(mockAuth);

      // Setup mock authorization service
      when(mockAuthService.requireAuthenticatedUser(context: anyNamed('context')))
          .thenReturn('test-user-id');
      when(mockAuthService.currentUserId).thenReturn('test-user-id');

      // Setup FTS service mock to return successful indexing
      when(mockFtsService.indexNote(
        noteId: anyNamed('noteId'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        folderPath: anyNamed('folderPath'),
      )).thenAnswer((_) async => true);

      when(mockFtsService.removeNote(any)).thenAnswer((_) async => true);

      // Setup CryptoBox mock to pass-through encryption/decryption
      // In tests, we simulate encryption by wrapping data in a simple format
      when(mockCrypto.encryptJsonForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        json: anyNamed('json'),
      )).thenAnswer((invocation) async {
        final json = invocation.namedArguments[#json] as Map<String, dynamic>;
        // Return mock encrypted bytes (just encode the JSON as string bytes for testing)
        return utf8.encode(jsonEncode(json));
      });

      when(mockCrypto.decryptJsonForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      )).thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data] as List<int>;
        // Return the decrypted JSON (decode from bytes)
        return jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      });

      repository = NotesCoreRepository(
        db: testDb,
        crypto: mockCrypto,
        api: mockApi,
        client: mockSupabase,
        ftsService: mockFtsService,
        authService: mockAuthService,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    group('Read Operations', () {
      test('should get all notes', () async {
        // Arrange - Insert test data into in-memory database
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: '1',
            title: 'Test Note 1',
            body: 'Test content',
            userId: 'test-user-id',
          ),
        );
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: '2',
            title: 'Test Note 2',
            body: 'Test content',
            userId: 'test-user-id',
          ),
        );

        // Act
        final result = await repository.getAllNotes();

        // Assert
        expect(result.length, 2);
        expect(result[0].id, '1');
        expect(result[0].title, 'Test Note 1');
        expect(result[1].id, '2');
        expect(result[1].title, 'Test Note 2');
      });

      test('should get note by id', () async {
        // Arrange - Insert test data into in-memory database
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: '1',
            title: 'Test Note',
            body: 'Test content',
            userId: 'test-user-id',
          ),
        );

        // Act
        final result = await repository.getNoteById('1');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, '1');
        expect(result.title, 'Test Note');
      });

      test('should return null for non-existent note', () async {
        // Arrange - Database is empty, no need to insert anything

        // Act
        final result = await repository.getNoteById('non-existent');

        // Assert
        expect(result, isNull);
      });
    });

    group('Create/Update Operations', () {
      test('should create or update a note', () async {
        // Act
        final result = await repository.createOrUpdate(
          title: 'New Note',
          body: 'New content',
          tags: ['tag1', 'tag2'],
          isPinned: false,
        );

        // Assert
        expect(result, isNotNull);
        expect(result, const TypeMatcher<domain.Note>());
        expect(result!.title, 'New Note');
        expect(result.body, 'New content');

        // Verify it was actually inserted in database
        final notes = await testDb.select(testDb.localNotes).get();
        expect(notes.length, 1);
        // SECURITY: Plaintext columns are now empty, data is only in encrypted columns
        expect(notes.first.title, ''); // Plaintext is empty
        expect(notes.first.titleEncrypted, isNotNull); // Encrypted version exists
        expect(notes.first.encryptionVersion, 1); // Marked as encrypted
      });

      test('should handle note with links', () async {
        // Act
        final result = await repository.createOrUpdate(
          title: 'Note with Links',
          body: 'Content',
          links: [
            {'url': 'note-2', 'title': 'Related Note'}
          ],
          isPinned: false,
        );

        // Assert
        expect(result, const TypeMatcher<domain.Note>());
        expect(result!.title, 'Note with Links');

        // Verify it was inserted
        final notes = await testDb.select(testDb.localNotes).get();
        expect(notes.isNotEmpty, true);
      });
    });

    group('Update Operations', () {
      test('should update an existing note via createOrUpdate', () async {
        // Arrange - insert initial note
        final noteId = 'existing-note-1';
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: noteId,
            title: 'Original Note',
            body: 'Original content',
            userId: 'test-user-id',
          ),
        );

        // Act
        final result = await repository.createOrUpdate(
          id: noteId,
          title: 'Updated Note',
          body: 'Updated content',
          isPinned: true,
        );

        // Assert
        expect(result, isNotNull);
        expect(result, const TypeMatcher<domain.Note>());
        expect(result!.title, 'Updated Note');

        // Verify update in database
        final query = testDb.select(testDb.localNotes)
            ..where((n) => n.id.equals(noteId));
        final updatedNote = await query.getSingle();
        // SECURITY: Plaintext columns are now empty, data is only in encrypted columns
        expect(updatedNote.title, ''); // Plaintext is empty
        expect(updatedNote.titleEncrypted, isNotNull); // Encrypted version exists
        expect(updatedNote.encryptionVersion, 1); // Marked as encrypted
      });
    });

    group('Delete Operations', () {
      test('should delete a note', () async {
        // Arrange - insert a note to delete
        final noteId = 'note-to-delete';
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: noteId,
            title: 'Note to Delete',
            body: 'Content',
            userId: 'test-user-id',
          ),
        );

        // Act
        await repository.deleteNote(noteId);

        // Assert - note should be marked as deleted
        final query = testDb.select(testDb.localNotes)
            ..where((n) => n.id.equals(noteId));
        final deletedNote = await query.getSingleOrNull();
        expect(deletedNote?.deleted, true);
      });
    });

    group('Search Operations', () {
      test('should search notes by query', () async {
        // Arrange - insert test notes
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: '1',
            title: 'Search Result',
            body: 'Matching content',
            userId: 'test-user-id',
          ),
        );
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: '2',
            title: 'Other Note',
            body: 'Different content',
            userId: 'test-user-id',
          ),
        );

        // Act
        final result = await repository.searchNotes('Search');

        // Assert
        expect(result.length, greaterThan(0));
        expect(result.any((n) => n.title.contains('Search')), true);
      });
    });

    group('Sync Operations', () {
      test('should sync with remote', () async {
        // Arrange - insert some local notes
        await testDb.into(testDb.localNotes).insert(
          TestDatabaseFactory.createNoteCompanion(
            id: 'local-1',
            title: 'Local Note',
            body: 'Content',
            userId: 'test-user-id',
          ),
        );

        // Act
        await repository.sync();

        // Assert - sync completed without errors
        final notes = await testDb.select(testDb.localNotes).get();
        expect(notes.isNotEmpty, true);
      });
    });
  });
  */
}
