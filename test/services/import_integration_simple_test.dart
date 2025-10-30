import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/providers/search_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'import_integration_simple_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AnalyticsService>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<CryptoBox>(),
  MockSpec<SupabaseNoteApi>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDb db;
  late ProviderContainer container;
  late NoteIndexer noteIndexer;
  late MockAnalyticsService mockAnalytics;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockCryptoBox mockCrypto;
  late MockSupabaseNoteApi mockSupabaseNoteApi;
  late NotesCoreRepository notesRepository;
  late ImportService importService;

  const testUserId = 'user-123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    tempDir = Directory.systemTemp.createTempSync('import_integration_test_');
    db = AppDb.forTesting(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [loggerProvider.overrideWithValue(const ConsoleLogger())],
    );

    noteIndexer = container.read(noteIndexerProvider);
    mockAnalytics = MockAnalyticsService();
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockCrypto = MockCryptoBox();
    mockSupabaseNoteApi = MockSupabaseNoteApi();

    when(mockSupabaseClient.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn(testUserId);

    when(
      mockAnalytics.event(any, properties: anyNamed('properties')),
    ).thenReturn(null);
    when(mockAnalytics.startTiming(any)).thenReturn(null);
    when(
      mockAnalytics.endTiming(any, properties: anyNamed('properties')),
    ).thenReturn(null);
    when(
      mockAnalytics.featureUsed(any, properties: anyNamed('properties')),
    ).thenReturn(null);

    Uint8List encode(String value) =>
        Uint8List.fromList(utf8.encode('enc:$value'));

    when(
      mockCrypto.encryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        text: anyNamed('text'),
      ),
    ).thenAnswer((invocation) async {
      final text = invocation.namedArguments[#text] as String;
      return encode(text);
    });

    when(
      mockCrypto.decryptStringForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        data: anyNamed('data'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Uint8List;
      final decoded = utf8.decode(data);
      return decoded.startsWith('enc:') ? decoded.substring(4) : decoded;
    });

    when(
      mockCrypto.encryptJsonForNote(
        userId: anyNamed('userId'),
        noteId: anyNamed('noteId'),
        json: anyNamed('json'),
      ),
    ).thenAnswer((_) async => encode('json'));

    final secureApi = SecureApiWrapper.testing(
      api: mockSupabaseNoteApi,
      userIdResolver: () => testUserId,
    );

    notesRepository = NotesCoreRepository(
      db: db,
      crypto: mockCrypto,
      client: mockSupabaseClient,
      indexer: noteIndexer,
      secureApi: secureApi,
    );

    importService = ImportService(
      notesRepository: notesRepository,
      noteIndexer: noteIndexer,
      logger: container.read(loggerProvider),
      analytics: mockAnalytics,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    container.dispose();
  });

  group('ImportService integration', () {
    test('imports markdown using real repository + indexer', () async {
      final markdownFile = File(p.join(tempDir.path, 'focus.md'))
        ..writeAsStringSync('# Focus\nWe must harden encryption.');

      final result = await importService.importMarkdown(markdownFile);

      expect(result.isSuccess, isTrue);
      expect(result.successCount, 1);
      verify(
        mockAnalytics.event(
          'import.success',
          properties: anyNamed('properties'),
        ),
      ).called(1);

      final localNotes = await db.select(db.localNotes).get();
      expect(localNotes, hasLength(1));
      final stored = localNotes.first;
      expect(stored.userId, equals(testUserId));
      final decodedTitle = await notesRepository.crypto.decryptStringForNote(
        userId: testUserId,
        noteId: stored.id,
        data: base64.decode(stored.titleEncrypted),
      );
      expect(decodedTitle, equals('Focus'));

      final indexStats = noteIndexer.getIndexStats();
      expect(indexStats['indexed_notes'], equals(1));
      expect(noteIndexer.searchNotes('harden'), contains(stored.id));
    });

    test('imports Obsidian vault end-to-end', () async {
      final obsidianDir = Directory(p.join(tempDir.path, 'vault'))
        ..createSync();
      File(
        p.join(obsidianDir.path, 'alpha.md'),
      ).writeAsStringSync('# Alpha\n#ops\nAudit encryption.');
      File(p.join(obsidianDir.path, 'nested', 'beta.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync('# Beta\n#ops #focus\nDeploy fixes.');
      File(p.join(obsidianDir.path, '.DS_Store')).writeAsStringSync('skip');

      final progress = <ImportProgress>[];

      final result = await importService.importObsidian(
        obsidianDir,
        onProgress: progress.add,
      );

      expect(result.successCount, 2);
      expect(result.errorCount, 0);
      expect(result.importedFiles.length, 2);
      expect(progress.isNotEmpty, isTrue);
      expect(progress.first.phase, ImportPhase.scanning);
      expect(progress.last.phase, ImportPhase.completed);

      final localNotes = await db.select(db.localNotes).get();
      final importedIds = localNotes.map((n) => n.id).toList();
      expect(importedIds.length, equals(2));
      expect(noteIndexer.searchNotes('audit'), contains(importedIds.first));
      expect(noteIndexer.searchNotes('deploy'), contains(importedIds.last));
      verify(
        mockAnalytics.event(
          'import.success',
          properties: argThat(
            containsPair('type', 'obsidian'),
            named: 'properties',
          ),
        ),
      ).called(1);
    });
  });
}
