import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/audio_recording_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/voice_notes_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'voice_notes_service_test.mocks.dart';

@GenerateMocks([
  AppLogger,
  AnalyticsService,
  NotesCoreRepository,
])
void main() {
  late MockAppLogger mockLogger;
  late MockAnalyticsService mockAnalytics;
  late MockNotesCoreRepository mockNotesRepository;
  late ProviderContainer container;

  setUp(() {
    mockLogger = MockAppLogger();
    mockAnalytics = MockAnalyticsService();
    mockNotesRepository = MockNotesCoreRepository();

    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(mockLogger),
        analyticsProvider.overrideWithValue(mockAnalytics),
        notesCoreRepositoryProvider.overrideWithValue(mockNotesRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('VoiceNotesService', () {
    group('createVoiceNote', () {
      test('successfully creates note with correct attachmentMeta structure', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const recording = RecordingResult(
          url: 'https://example.supabase.co/storage/v1/object/public/attachments/test.m4a',
          filename: 'voice_note_123.m4a',
          durationSeconds: 45,
        );

        final expectedNote = Note(
          id: 'note-123',
          title: 'Test Voice Note',
          body: 'Voice note (0:45) recorded on Nov 22, 2025 at 14:30',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-123',
          attachmentMeta: null, // Will be set as Map in the call
          tags: const ['voice-note'],
        );

        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
        )).thenAnswer((_) async => expectedNote);

        // Act
        final result = await service.createVoiceNote(
          recording: recording,
          title: 'Test Voice Note',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'note-123');
        expect(result.title, 'Test Voice Note');
        expect(result.tags, contains('voice-note'));

        // Verify repository was called with correct parameters
        final captured = verify(mockNotesRepository.createOrUpdate(
          title: captureAnyNamed('title'),
          body: captureAnyNamed('body'),
          attachmentMeta: captureAnyNamed('attachmentMeta'),
          tags: captureAnyNamed('tags'),
          folderId: captureAnyNamed('folderId'),
        )).captured;

        expect(captured[0], 'Test Voice Note');
        expect(captured[1], contains('Voice note (0:45)'));

        // Verify attachmentMeta structure
        final attachmentMeta = captured[2] as Map<String, dynamic>;
        expect(attachmentMeta, containsPair('voiceRecordings', isA<List>()));

        final voiceRecordings = attachmentMeta['voiceRecordings'] as List;
        expect(voiceRecordings, hasLength(1));

        final recording0 = voiceRecordings[0] as Map<String, dynamic>;
        expect(recording0['url'], recording.url);
        expect(recording0['filename'], recording.filename);
        expect(recording0['durationSeconds'], recording.durationSeconds);
        expect(recording0['id'], isA<String>());
        expect(recording0['createdAt'], isA<String>());

        // Verify tags
        final tags = captured[3] as List<String>;
        expect(tags, contains('voice-note'));

        // Verify analytics
        verify(mockAnalytics.startTiming('voice_note_create')).called(1);
        verify(mockAnalytics.endTiming(
          'voice_note_create',
          properties: {
            'success': true,
            'duration_seconds': 45,
            'has_custom_title': true,
          },
        )).called(1);
        verify(mockAnalytics.featureUsed(
          'voice_note_created',
          properties: anyNamed('properties'),
        )).called(1);
      });

      test('returns null when repository returns null', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const recording = RecordingResult(
          url: 'https://example.supabase.co/test.m4a',
          filename: 'test.m4a',
          durationSeconds: 30,
        );

        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
        )).thenAnswer((_) async => null);

        // Act
        final result = await service.createVoiceNote(
          recording: recording,
          title: 'Test',
        );

        // Assert
        expect(result, isNull);
        verify(mockLogger.warning(
          'NotesRepository.createOrUpdate returned null for voice note',
          data: anyNamed('data'),
        )).called(1);
        verify(mockAnalytics.endTiming(
          'voice_note_create',
          properties: {
            'success': false,
            'reason': 'repository_returned_null',
          },
        )).called(1);
      });

      test('uses provided folderId when specified', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const recording = RecordingResult(
          url: 'https://example.supabase.co/test.m4a',
          filename: 'test.m4a',
          durationSeconds: 30,
        );

        final expectedNote = Note(
          id: 'note-123',
          title: 'Test',
          body: 'Body',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-123',
          folderId: 'folder-456',
          tags: const ['voice-note'],
        );

        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
        )).thenAnswer((_) async => expectedNote);

        // Act
        final result = await service.createVoiceNote(
          recording: recording,
          title: 'Test',
          folderId: 'folder-456',
        );

        // Assert
        expect(result, isNotNull);

        // Verify folderId was passed
        final captured = verify(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: captureAnyNamed('folderId'),
        )).captured;

        expect(captured.last, 'folder-456');
      });

      test('tracks error analytics on exception', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const recording = RecordingResult(
          url: 'https://example.supabase.co/test.m4a',
          filename: 'test.m4a',
          durationSeconds: 30,
        );

        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
        )).thenThrow(Exception('Database error'));

        // Act
        final result = await service.createVoiceNote(
          recording: recording,
          title: 'Test',
        );

        // Assert
        expect(result, isNull);
        verify(mockLogger.error('Failed to create voice note', error: anyNamed('error'))).called(1);
        verify(mockAnalytics.trackError(
          'Voice note creation failed',
          properties: anyNamed('properties'),
        )).called(1);
      });
    });

    group('addVoiceRecordingToNote', () {
      test('successfully adds recording to note without existing voiceRecordings', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const recording = RecordingResult(
          url: 'https://example.supabase.co/test2.m4a',
          filename: 'test2.m4a',
          durationSeconds: 60,
        );

        final existingNote = Note(
          id: 'note-123',
          title: 'Existing Note',
          body: 'Body',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-123',
          attachmentMeta: null, // No existing attachments
          tags: const [],
        );

        final updatedNote = existingNote.copyWith(
          tags: ['voice-note'],
        );

        when(mockNotesRepository.createOrUpdate(
          id: anyNamed('id'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
          isPinned: anyNamed('isPinned'),
        )).thenAnswer((_) async => updatedNote);

        // Act
        final result = await service.addVoiceRecordingToNote(
          note: existingNote,
          recording: recording,
        );

        // Assert
        expect(result, isNotNull);

        // Verify repository was called
        final captured = verify(mockNotesRepository.createOrUpdate(
          id: captureAnyNamed('id'),
          title: captureAnyNamed('title'),
          body: captureAnyNamed('body'),
          attachmentMeta: captureAnyNamed('attachmentMeta'),
          tags: captureAnyNamed('tags'),
          folderId: captureAnyNamed('folderId'),
          isPinned: captureAnyNamed('isPinned'),
        )).captured;

        expect(captured[0], 'note-123');

        // Verify attachmentMeta has new recording
        final attachmentMeta = captured[3] as Map<String, dynamic>;
        final voiceRecordings = attachmentMeta['voiceRecordings'] as List;
        expect(voiceRecordings, hasLength(1));

        final recording0 = voiceRecordings[0] as Map<String, dynamic>;
        expect(recording0['url'], recording.url);

        // Verify voice-note tag was added
        final tags = captured[4] as List<String>;
        expect(tags, contains('voice-note'));
      });

      test('appends to existing voiceRecordings array', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const newRecording = RecordingResult(
          url: 'https://example.supabase.co/test3.m4a',
          filename: 'test3.m4a',
          durationSeconds: 90,
        );

        final existingNote = Note(
          id: 'note-123',
          title: 'Existing Note',
          body: 'Body',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-123',
          attachmentMeta: '{"voiceRecordings":[{"id":"existing-1","url":"https://example.com/old.m4a","filename":"old.m4a","durationSeconds":30,"createdAt":"2025-11-22T10:00:00.000Z"}]}',
          tags: const ['voice-note'],
        );

        final updatedNote = existingNote.copyWith();

        when(mockNotesRepository.createOrUpdate(
          id: anyNamed('id'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
          isPinned: anyNamed('isPinned'),
        )).thenAnswer((_) async => updatedNote);

        // Act
        final result = await service.addVoiceRecordingToNote(
          note: existingNote,
          recording: newRecording,
        );

        // Assert
        expect(result, isNotNull);

        // Verify attachmentMeta has both recordings
        final captured = verify(mockNotesRepository.createOrUpdate(
          id: anyNamed('id'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: captureAnyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
          isPinned: anyNamed('isPinned'),
        )).captured;

        final attachmentMeta = captured[0] as Map<String, dynamic>;
        final voiceRecordings = attachmentMeta['voiceRecordings'] as List;
        expect(voiceRecordings, hasLength(2));
        expect(voiceRecordings[0]['url'], 'https://example.com/old.m4a');
        expect(voiceRecordings[1]['url'], newRecording.url);
      });

      test('returns null when repository returns null', () async {
        // Arrange
        final service = container.read(voiceNotesServiceProvider);
        const recording = RecordingResult(
          url: 'https://example.supabase.co/test.m4a',
          filename: 'test.m4a',
          durationSeconds: 30,
        );

        final existingNote = Note(
          id: 'note-123',
          title: 'Test',
          body: 'Body',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-123',
        );

        when(mockNotesRepository.createOrUpdate(
          id: anyNamed('id'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          attachmentMeta: anyNamed('attachmentMeta'),
          tags: anyNamed('tags'),
          folderId: anyNamed('folderId'),
          isPinned: anyNamed('isPinned'),
        )).thenAnswer((_) async => null);

        // Act
        final result = await service.addVoiceRecordingToNote(
          note: existingNote,
          recording: recording,
        );

        // Assert
        expect(result, isNull);
        verify(mockLogger.error('Repository returned null when updating note with voice recording')).called(1);
      });
    });
  });
}
