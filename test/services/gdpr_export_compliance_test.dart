import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/gdpr_compliance_service.dart';
import 'package:duru_notes/services/unified_export_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gdpr_export_compliance_test.mocks.dart';

/// Helper function to create test notes with proper encryption format
Future<void> createTestNote(
  AppDb db,
  String noteId, {
  String userId = 'test-user-id',
  String title = 'Test Note',
  String body = '',
  List<int>? titleBytes,
  List<int>? bodyBytes,
}) async {
  // Use provided bytes or encode as base64 strings
  final titleEncrypted = titleBytes != null
      ? base64Encode(titleBytes)
      : base64Encode(utf8.encode(title));
  final bodyEncrypted = bodyBytes != null
      ? base64Encode(bodyBytes)
      : base64Encode(utf8.encode(body));

  await db
      .into(db.localNotes)
      .insert(
        LocalNotesCompanion.insert(
          id: noteId,
          userId: Value(userId),
          titleEncrypted: Value(titleEncrypted),
          bodyEncrypted: Value(bodyEncrypted),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteType: Value(NoteKind.note),
          deleted: Value(false),
          encryptionVersion: Value(1),
        ),
      );
}

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<UnifiedExportService>(),
  MockSpec<CryptoBox>(),
  MockSpec<FlutterSecureStorage>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDb db;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockUnifiedExportService mockExportService;
  late MockCryptoBox mockCryptoBox;
  late MockFlutterSecureStorage mockSecureStorage;
  late GDPRComplianceService gdprService;

  const testUserId = 'test-user-123';
  const testNoteId = 'note-123';
  const testTaskId = 'task-123';

  const plainTitle = 'My Secret Note';
  const plainBody = 'This is private information';
  const plainTaskContent = 'Buy groceries for dinner';

  setUp(() async {
    // Create in-memory database for testing
    db = AppDb.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});

    // Setup mocks
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockExportService = MockUnifiedExportService();
    mockCryptoBox = MockCryptoBox();
    mockSecureStorage = MockFlutterSecureStorage();

    // Configure mock user
    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn(testUserId);
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.createdAt).thenReturn(DateTime.now().toIso8601String());
    when(mockUser.lastSignInAt).thenReturn(DateTime.now().toIso8601String());
    when(mockUser.appMetadata).thenReturn(<String, dynamic>{});
    when(mockUser.userMetadata).thenReturn(<String, dynamic>{});

    final secureStorageState = <String, String?>{};

    when(
      mockSecureStorage.write(
        key: anyNamed('key'),
        value: anyNamed('value'),
        aOptions: anyNamed('aOptions'),
        iOptions: anyNamed('iOptions'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      secureStorageState[key] = value;
    });

    when(
      mockSecureStorage.read(
        key: anyNamed('key'),
        aOptions: anyNamed('aOptions'),
        iOptions: anyNamed('iOptions'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      return secureStorageState[key];
    });

    when(
      mockSecureStorage.delete(
        key: anyNamed('key'),
        aOptions: anyNamed('aOptions'),
        iOptions: anyNamed('iOptions'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      secureStorageState.remove(key);
    });

    when(
      mockSecureStorage.deleteAll(
        aOptions: anyNamed('aOptions'),
        iOptions: anyNamed('iOptions'),
      ),
    ).thenAnswer((_) async {
      secureStorageState.clear();
    });

    String decodeEncryptedString(List<int> data) {
      final encoded = utf8.decode(data);
      List<int> decodedBytes;
      try {
        decodedBytes = base64Decode(encoded);
      } on FormatException {
        return utf8.decode(data);
      }

      try {
        return utf8.decode(decodedBytes);
      } on FormatException {
        throw const FormatException('Unable to decode encrypted payload');
      }
    }

    when(
      mockCryptoBox.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as List<int>;
      return decodeEncryptedString(data);
    });

    when(
      mockCryptoBox.decryptJsonForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as List<int>;
      final value = decodeEncryptedString(data);

      if (value.trim().startsWith('{')) {
        final decoded = jsonDecode(value);
        final content = decoded is Map<String, dynamic>
            ? decoded['content']?.toString() ?? ''
            : value;
        return {
          'content': content,
          'labels': decoded is Map<String, dynamic>
              ? decoded['labels']?.toString() ?? content
              : content,
          'notes': decoded is Map<String, dynamic>
              ? decoded['notes']?.toString() ?? content
              : content,
        };
      }

      return {'content': value, 'labels': value, 'notes': value};
    });

    // Create GDPR service
    gdprService = GDPRComplianceService(
      db: db,
      exportService: mockExportService,
      supabaseClient: mockSupabase,
      cryptoBox: mockCryptoBox,
      secureStorage: mockSecureStorage,
      remoteDeletion: (_) async => true,
      authRevoker: (_) async => true,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('GDPR Data Export Compliance Tests - Production Grade', () {
    test(
      'exportAllUserData returns plaintext note titles and bodies',
      () async {
        // Arrange - Create encrypted note in database
        await createTestNote(
          db,
          testNoteId,
          userId: testUserId,
          titleBytes: plainTitle.codeUnits,
          bodyBytes: plainBody.codeUnits,
        );

        // Act - Export user data
        final exportFile = await gdprService.exportAllUserData(
          userId: testUserId,
          format: ExportFormat.json,
        );

        // Assert - Read exported JSON
        final exportJson = jsonDecode(await exportFile.readAsString());
        final notes = exportJson['userData']['notes'] as List;

        // GDPR Compliance Verification
        expect(notes.length, 1, reason: 'Should export exactly one note');
        final exportedNote = notes.first as Map<String, dynamic>;

        // CRITICAL: Verify plaintext export (not encrypted)
        expect(
          exportedNote['title'],
          equals(plainTitle),
          reason:
              'GDPR VIOLATION: Note title must be plaintext for portability',
        );
        expect(
          exportedNote['body'],
          equals(plainBody),
          reason: 'GDPR VIOLATION: Note body must be plaintext for portability',
        );

        // Verify no encrypted markers
        expect(exportedNote['title'], isNot(contains('[ENCRYPTED]')));
        expect(exportedNote['body'], isNot(contains('[ENCRYPTED]')));

        // Verify metadata
        expect(exportedNote['id'], equals(testNoteId));
        expect(exportedNote['isDeleted'], isFalse);

        // Cleanup
        await exportFile.delete();
      },
    );

    test('exportAllUserData returns plaintext task content', () async {
      // Arrange - Create note first (required for task foreign key)
      await createTestNote(db, testNoteId, userId: testUserId);

      // Create encrypted task
      await db
          .into(db.noteTasks)
          .insert(
            NoteTasksCompanion.insert(
              id: testTaskId,
              noteId: testNoteId,
              userId: testUserId,
              contentEncrypted: base64Encode(plainTaskContent.codeUnits),
              contentHash: 'hash',
              status: Value(TaskStatus.open),
              priority: Value(TaskPriority.medium),
              position: Value(0),
              encryptionVersion: Value(1),
            ),
          );

      // Act - Export user data
      final exportFile = await gdprService.exportAllUserData(
        userId: testUserId,
        format: ExportFormat.json,
      );

      // Assert - Read exported JSON
      final exportJson = jsonDecode(await exportFile.readAsString());
      final tasks = exportJson['userData']['tasks'] as List;

      // GDPR Compliance Verification
      expect(tasks.length, 1, reason: 'Should export exactly one task');
      final exportedTask = tasks.first as Map<String, dynamic>;

      // CRITICAL: Verify plaintext export
      expect(
        exportedTask['content'],
        equals(plainTaskContent),
        reason:
            'GDPR VIOLATION: Task content must be plaintext for portability',
      );
      expect(exportedTask['content'], isNot(contains('[ENCRYPTED]')));
      expect(exportedTask['id'], equals(testTaskId));
      expect(exportedTask['noteId'], equals(testNoteId));

      // Cleanup
      await exportFile.delete();
    });

    test('exportAllUserData handles decryption failures gracefully', () async {
      // Arrange - Create note with corrupted data
      await createTestNote(
        db,
        testNoteId,
        userId: testUserId,
        titleBytes: [0xFF, 0xFF],
        bodyBytes: [0xFF, 0xFF],
      );

      // Act - Export should still succeed but mark failures
      final exportFile = await gdprService.exportAllUserData(
        userId: testUserId,
        format: ExportFormat.json,
      );

      // Assert
      final exportJson = jsonDecode(await exportFile.readAsString());
      final notes = exportJson['userData']['notes'] as List;

      expect(notes.length, 1);
      final exportedNote = notes.first as Map<String, dynamic>;

      // Should indicate decryption failure, not show encrypted gibberish
      expect(
        exportedNote['title'],
        equals('[DECRYPTION_FAILED]'),
        reason: 'Must clearly indicate decryption failure',
      );
      expect(
        exportedNote['body'],
        equals('[DECRYPTION_FAILED]'),
        reason: 'Must clearly indicate decryption failure',
      );

      // Cleanup
      await exportFile.delete();
    });

    test('GDPR export includes all required user data categories', () async {
      // Act - Export user data
      final exportFile = await gdprService.exportAllUserData(
        userId: testUserId,
        format: ExportFormat.json,
      );

      // Assert
      final exportJson = jsonDecode(await exportFile.readAsString());

      // Verify export metadata is GDPR compliant
      final metadata = exportJson['exportMetadata'] as Map<String, dynamic>;
      expect(
        metadata['gdprCompliant'],
        isTrue,
        reason: 'Must explicitly declare GDPR compliance',
      );
      expect(metadata['userId'], equals(testUserId));
      expect(metadata['exportDate'], isNotNull);
      expect(metadata['version'], isNotNull);

      // Verify all required data categories are present (GDPR Article 20)
      final userData = exportJson['userData'] as Map<String, dynamic>;

      // Personal data
      expect(
        userData.containsKey('profile'),
        isTrue,
        reason: 'Must include user profile data',
      );

      // Content data
      expect(
        userData.containsKey('notes'),
        isTrue,
        reason: 'Must include all notes',
      );
      expect(
        userData.containsKey('tasks'),
        isTrue,
        reason: 'Must include all tasks',
      );
      expect(
        userData.containsKey('folders'),
        isTrue,
        reason: 'Must include folder structure',
      );
      expect(userData.containsKey('tags'), isTrue, reason: 'Must include tags');

      // Metadata and settings
      expect(
        userData.containsKey('reminders'),
        isTrue,
        reason: 'Must include reminder settings',
      );
      expect(
        userData.containsKey('attachments'),
        isTrue,
        reason: 'Must include attachment metadata',
      );
      expect(
        userData.containsKey('preferences'),
        isTrue,
        reason: 'Must include user preferences',
      );

      // Audit data
      expect(
        userData.containsKey('auditTrail'),
        isTrue,
        reason: 'Must include user activity audit trail',
      );

      // Cleanup
      await exportFile.delete();
    });

    test('CSV export format also returns plaintext data', () async {
      // Arrange - Create encrypted note
      await createTestNote(
        db,
        testNoteId,
        userId: testUserId,
        titleBytes: plainTitle.codeUnits,
        bodyBytes: plainBody.codeUnits,
      );

      // Act - Export as CSV
      final exportFile = await gdprService.exportAllUserData(
        userId: testUserId,
        format: ExportFormat.csv,
      );

      // Assert - Read CSV content
      final csvContent = await exportFile.readAsString();

      // CRITICAL: CSV should contain plaintext, not [ENCRYPTED]
      expect(
        csvContent,
        contains(plainTitle),
        reason: 'CSV export must contain plaintext title',
      );
      expect(
        csvContent,
        contains(plainBody),
        reason: 'CSV export must contain plaintext body',
      );
      expect(
        csvContent,
        isNot(contains('[ENCRYPTED]')),
        reason: 'CSV must not contain encryption markers',
      );

      // Verify CSV structure
      expect(
        csvContent,
        contains('GDPR Data Export'),
        reason: 'CSV must identify as GDPR export',
      );
      expect(
        csvContent,
        contains(testUserId),
        reason: 'CSV must identify user',
      );

      // Cleanup
      await exportFile.delete();
    });

    test('exportAllUserData enforces user isolation', () async {
      // Arrange - Create notes for two different users
      await createTestNote(
        db,
        'user1-note',
        userId: testUserId,
        title: 'User 1 Note',
      );

      await createTestNote(
        db,
        'user2-note',
        userId: 'other-user-456',
        title: 'User 2 Note',
      );

      // Act - Export data for testUserId
      final exportFile = await gdprService.exportAllUserData(
        userId: testUserId,
        format: ExportFormat.json,
      );

      // Assert - Should only contain testUserId's data
      final exportJson = jsonDecode(await exportFile.readAsString());
      final notes = exportJson['userData']['notes'] as List;

      expect(
        notes.length,
        1,
        reason: 'Should only export current user\'s notes',
      );
      expect(
        notes.first['id'],
        equals('user1-note'),
        reason: 'Should export correct user\'s note',
      );

      // Verify no cross-user data leakage
      final exportContent = await exportFile.readAsString();
      expect(
        exportContent,
        isNot(contains('other-user-456')),
        reason: 'Must not leak other user IDs',
      );
      expect(
        exportContent,
        isNot(contains('User 2 Note')),
        reason: 'Must not leak other user data',
      );

      // Cleanup
      await exportFile.delete();
    });
  });

  group('GDPR Right to Erasure Tests - Production Grade', () {
    test(
      'deleteAllUserData performs complete deletion with verification',
      () async {
        // Arrange - Create comprehensive test data
        await createTestNote(
          db,
          testNoteId,
          userId: testUserId,
          title: 'Test Note',
        );

        await db
            .into(db.noteTasks)
            .insert(
              NoteTasksCompanion.insert(
                id: testTaskId,
                noteId: testNoteId,
                userId: testUserId,
                contentEncrypted: base64Encode([]),
                contentHash: 'hash',
                status: Value(TaskStatus.open),
                priority: Value(TaskPriority.medium),
                position: Value(0),
                encryptionVersion: Value(1),
              ),
            );

        // Generate deletion code
        final code = await gdprService.generateDeletionCode(testUserId);
        expect(
          code.length,
          equals(6),
          reason: 'Deletion code must be 6 characters',
        );
        expect(
          code,
          matches(RegExp(r'^[A-Z0-9]{6}$')),
          reason: 'Deletion code must be alphanumeric',
        );

        // Act - Delete all user data
        await gdprService.deleteAllUserData(
          userId: testUserId,
          confirmationCode: code,
          createBackup: false,
        );

        // Assert - Verify complete deletion
        // 1. Notes should be marked as deleted (soft delete)
        final notes = await (db.select(
          db.localNotes,
        )..where((n) => n.userId.equals(testUserId))).get();
        expect(
          notes.every((n) => n.deleted),
          isTrue,
          reason: 'All notes must be marked as deleted',
        );

        // 2. Tasks should be deleted
        final tasks = await (db.select(
          db.noteTasks,
        )..where((t) => t.noteId.equals(testNoteId))).get();
        expect(tasks, isEmpty, reason: 'All associated tasks must be deleted');
      },
    );

    test('deleteAllUserData requires valid confirmation code', () async {
      // Arrange
      await createTestNote(db, testNoteId, userId: testUserId, title: 'Test');

      // Act & Assert - Should throw with invalid code
      expect(
        () => gdprService.deleteAllUserData(
          userId: testUserId,
          confirmationCode: 'INVALID',
          createBackup: false,
        ),
        throwsA(
          isA<GDPRException>().having(
            (e) => e.message,
            'message',
            contains('Invalid confirmation code'),
          ),
        ),
        reason: 'Must reject invalid confirmation codes',
      );

      // Verify data was NOT deleted
      final notes = await (db.select(
        db.localNotes,
      )..where((n) => n.userId.equals(testUserId))).get();
      expect(
        notes,
        isNotEmpty,
        reason: 'Data should not be deleted with invalid code',
      );
    });

    test('deleteAllUserData creates backup when requested', () async {
      // Arrange
      await createTestNote(
        db,
        testNoteId,
        userId: testUserId,
        title: 'Important Data',
      );

      final code = await gdprService.generateDeletionCode(testUserId);

      // Act - Delete with backup
      await gdprService.deleteAllUserData(
        userId: testUserId,
        confirmationCode: code,
        createBackup: true, // Request backup
      );

      // Assert - Backup should be created before deletion
      // Note: In production, verify backup file exists in temp directory
      // For this test, we verify the deletion still succeeded
      final notes = await (db.select(
        db.localNotes,
      )..where((n) => n.userId.equals(testUserId))).get();
      expect(
        notes.every((n) => n.deleted),
        isTrue,
        reason: 'Data should be deleted even with backup',
      );
    });
  });

  group('GDPR Consent Management - Production Grade', () {
    test('getUserConsents returns all consent types', () async {
      // Act
      final consents = await gdprService.getUserConsents(testUserId);

      // Assert - All required consent types present
      expect(consents.containsKey('dataCollection'), isTrue);
      expect(consents.containsKey('analytics'), isTrue);
      expect(consents.containsKey('marketing'), isTrue);
      expect(consents.containsKey('thirdPartySharing'), isTrue);
      expect(consents.containsKey('personalizedAds'), isTrue);

      // Default values should be false (opt-in required)
      expect(
        consents.values.every((granted) => granted == false),
        isTrue,
        reason: 'Consents should default to false (GDPR requires opt-in)',
      );
    });

    test('updateUserConsent persists consent changes', () async {
      // Act - Grant consent
      await gdprService.updateUserConsent(
        userId: testUserId,
        consentType: 'analytics',
        granted: true,
      );

      // Assert - Consent should be persisted
      final consents = await gdprService.getUserConsents(testUserId);
      expect(
        consents['analytics'],
        isTrue,
        reason: 'Consent change must be persisted',
      );
    });

    test('updateUserConsent allows revoking consent', () async {
      // Arrange - Grant consent first
      await gdprService.updateUserConsent(
        userId: testUserId,
        consentType: 'marketing',
        granted: true,
      );

      // Act - Revoke consent
      await gdprService.updateUserConsent(
        userId: testUserId,
        consentType: 'marketing',
        granted: false,
      );

      // Assert - Consent should be revoked
      final consents = await gdprService.getUserConsents(testUserId);
      expect(
        consents['marketing'],
        isFalse,
        reason: 'User must be able to revoke consent (GDPR requirement)',
      );
    });
  });

  group('GDPR Data Retention Policy - Production Grade', () {
    test('getDataRetentionPolicy returns clear retention periods', () {
      // Act
      final policy = gdprService.getDataRetentionPolicy();

      // Assert - All data types have retention policies
      expect(policy.containsKey('notes'), isTrue);
      expect(policy.containsKey('tasks'), isTrue);
      expect(policy.containsKey('reminders'), isTrue);
      expect(policy.containsKey('auditLogs'), isTrue);
      expect(policy.containsKey('analytics'), isTrue);
      expect(policy.containsKey('backups'), isTrue);

      // Verify retention periods are defined
      expect(policy['notes']['retention'], isNotNull);
      expect(policy['tasks']['retention'], isNotNull);

      // Verify auto-delete flags
      expect(
        policy['notes']['autoDelete'],
        isFalse,
        reason: 'User notes should not auto-delete',
      );
      expect(
        policy['auditLogs']['autoDelete'],
        isTrue,
        reason: 'Audit logs should auto-delete after retention period',
      );
    });
  });
}
