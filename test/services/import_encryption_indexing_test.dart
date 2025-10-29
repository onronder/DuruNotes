import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'import_encryption_indexing_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NotesCoreRepository>(),
  MockSpec<NoteIndexer>(),
  MockSpec<AppLogger>(),
  MockSpec<AnalyticsService>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockNotesCoreRepository mockNotesRepository;
  late MockNoteIndexer mockNoteIndexer;
  late MockAppLogger mockLogger;
  late MockAnalyticsService mockAnalytics;
  late ImportService importService;
  late domain.Note sampleNote;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('import_service_test_');
    mockNotesRepository = MockNotesCoreRepository();
    mockNoteIndexer = MockNoteIndexer();
    mockLogger = MockAppLogger();
    mockAnalytics = MockAnalyticsService();

    when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.debug(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.error(
      any,
      error: anyNamed('error'),
      stackTrace: anyNamed('stackTrace'),
      data: anyNamed('data'),
    )).thenReturn(null);

    when(mockAnalytics.event(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(mockAnalytics.startTiming(any)).thenReturn(null);
    when(mockAnalytics.endTiming(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(mockAnalytics.featureUsed(any, properties: anyNamed('properties')))
        .thenReturn(null);

    sampleNote = domain.Note(
      id: 'note-123',
      title: 'Imported Note',
      body: 'Body',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deleted: false,
      isPinned: false,
      noteType: NoteKind.note,
      version: 1,
      userId: 'user-123',
      tags: const ['imported'],
      links: const [],
    );

    importService = ImportService(
      notesRepository: mockNotesRepository,
      noteIndexer: mockNoteIndexer,
      logger: mockLogger,
      analytics: mockAnalytics,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('importMarkdown', () {
    test('persists note, indexes content, and tracks analytics', () async {
      final markdownFile = File(p.join(tempDir.path, 'daily.md'))
        ..writeAsStringSync('# Daily Log\nFocus on critical fixes.');

      when(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => sampleNote);
      when(mockNoteIndexer.indexNote(any)).thenAnswer((_) async {});

      final progress = <ImportProgress>[];

      final result = await importService.importMarkdown(
        markdownFile,
        onProgress: progress.add,
      );

      expect(result.isSuccess, isTrue);
      expect(result.successCount, equals(1));
      expect(result.errorCount, equals(0));
      expect(result.importedFiles, contains(markdownFile.path));
      expect(progress.map((e) => e.phase), contains(ImportPhase.completed));

      verify(mockNotesRepository.createOrUpdate(
        title: 'Daily Log',
        body: anyNamed('body'),
      )).called(1);
      verify(mockNoteIndexer.indexNote(sampleNote)).called(1);
      verify(mockAnalytics.event(
        'import.success',
        properties: anyNamed('properties'),
      )).called(1);
    });

    test('returns error result when repository throws', () async {
      final markdownFile = File(p.join(tempDir.path, 'broken.md'))
        ..writeAsStringSync('# Broken\nThis will fail.');

      when(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
      )).thenThrow(Exception('Database unavailable'));

      final result = await importService.importMarkdown(markdownFile);

      expect(result.isSuccess, isFalse);
      expect(result.errorCount, equals(1));
      expect(result.errors.single.message, contains('Exception'));

      verify(mockAnalytics.event(
        'import.error',
        properties: anyNamed('properties'),
      )).called(1);
      verifyNever(mockNoteIndexer.indexNote(any));
    });
  });

  group('importObsidian', () {
    test('imports multiple markdown files and reports progress', () async {
      final vaultDir = Directory(p.join(tempDir.path, 'vault'))..createSync();
      File(p.join(vaultDir.path, 'alpha.md')).writeAsStringSync('# Alpha\n#focus\nImportant decisions.');
      final betaFile = File(p.join(vaultDir.path, 'notes', 'beta.markdown'));
      betaFile.createSync(recursive: true);
      betaFile.writeAsStringSync('# Beta\nWrap up sprint.');
      // Hidden/system file should be ignored
      File(p.join(vaultDir.path, 'README.md')).writeAsStringSync('Skip me');

      var createCall = 0;
      final indexedNotes = <domain.Note>[];

      when(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
      )).thenAnswer((invocation) async {
        createCall++;
        final title = invocation.namedArguments[#title] as String;
        return domain.Note(
          id: 'imported-$createCall',
          title: title,
          body: 'body-$createCall',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-123',
          tags: const [],
          links: const [],
        );
      });

      when(mockNoteIndexer.indexNote(any)).thenAnswer((invocation) async {
        indexedNotes.add(invocation.positionalArguments.first as domain.Note);
      });

      final progressEvents = <ImportProgress>[];

      final result = await importService.importObsidian(
        vaultDir,
        onProgress: progressEvents.add,
      );

      expect(result.isSuccess, isTrue);
      expect(result.successCount, equals(2));
      expect(result.importedFiles.length, equals(2));
      expect(indexedNotes.map((n) => n.id), containsAll(['imported-1', 'imported-2']));
      expect(progressEvents.map((e) => e.phase), contains(ImportPhase.scanning));
      expect(progressEvents.last.phase, ImportPhase.completed);

      verify(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
      )).called(2);
      verify(mockNoteIndexer.indexNote(any)).called(2);
      verify(mockAnalytics.event(
        'import.success',
        properties: argThat(
          containsPair('type', 'obsidian'),
          named: 'properties',
        ),
      )).called(1);

      // Ensure hidden/system files were not processed
      expect(result.importedFiles.every((f) => !f.contains('README')), isTrue);
      expect(createCall, equals(2));
    });
  });
}
