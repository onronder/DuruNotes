import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/audio_recording_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/voice_notes_service.dart';
import 'package:duru_notes/ui/widgets/voice_recording_player.dart';
import 'package:duru_notes/ui/widgets/voice_recording_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'voice_note_flow_test.mocks.dart';

@GenerateMocks([
  AppLogger,
  AnalyticsService,
  AudioRecordingService,
  VoiceNotesService,
])
void main() {
  group('Voice Note Flow Integration Test', () {
    late MockAppLogger mockLogger;
    late MockAnalyticsService mockAnalytics;
    late MockAudioRecordingService mockAudioRecordingService;
    late MockVoiceNotesService mockVoiceNotesService;

    setUp(() {
      mockLogger = MockAppLogger();
      mockAnalytics = MockAnalyticsService();
      mockAudioRecordingService = MockAudioRecordingService();
      mockVoiceNotesService = MockVoiceNotesService();
    });

    testWidgets('Voice recording flow: Record → Save → Note created with player', (
      tester,
    ) async {
      // Arrange - Setup successful recording flow
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.startRecording(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.stopRecording(),
      ).thenAnswer((_) async => '/tmp/voice_note_test.m4a');
      when(mockAudioRecordingService.finalizeAndUpload()).thenAnswer(
        (_) async => const RecordingResult(
          url:
              'https://example.supabase.co/storage/v1/object/public/attachments/test.m4a',
          filename: 'voice_note_test.m4a',
          durationSeconds: 45,
        ),
      );

      final createdNote = Note(
        id: 'note-123',
        title: 'My Recording',
        body: 'Voice note (0:45) recorded on Nov 22, 2025 at 14:30',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user-123',
        attachmentMeta:
            '{"voiceRecordings":[{"id":"rec-1","url":"https://example.supabase.co/storage/v1/object/public/attachments/test.m4a","filename":"test.m4a","durationSeconds":45,"createdAt":"2025-11-22T14:30:00.000Z"}]}',
        tags: const ['voice-note'],
      );

      when(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: anyNamed('title'),
          folderId: anyNamed('folderId'),
        ),
      ).thenAnswer((_) async => createdNote);

      // Build the voice recording sheet in isolation
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggerProvider.overrideWithValue(mockLogger),
            analyticsProvider.overrideWithValue(mockAnalytics),
            audioRecordingServiceProvider.overrideWithValue(
              mockAudioRecordingService,
            ),
            voiceNotesServiceProvider.overrideWithValue(mockVoiceNotesService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const FractionallySizedBox(
                            heightFactor: 0.7,
                            child: VoiceRecordingSheet(),
                          ),
                        );
                      },
                      child: const Text('Open Voice Recording'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Open voice recording sheet
      await tester.tap(find.text('Open Voice Recording'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceRecordingSheet), findsOneWidget);

      // Step 2: Start recording
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      expect(find.text('Recording...'), findsOneWidget);
      verify(mockAudioRecordingService.hasPermission()).called(1);
      verify(mockAudioRecordingService.startRecording()).called(1);

      // Step 3: Stop recording
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      verify(mockAudioRecordingService.stopRecording()).called(1);

      // Step 4: Enter title and save
      await tester.enterText(find.byType(TextField), 'My Recording');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Step 5: Verify voice note creation
      verify(mockAudioRecordingService.finalizeAndUpload()).called(1);
      verify(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: 'My Recording',
          folderId: null,
        ),
      ).called(1);
    });

    // SKIPPED: just_audio platform channel not available in widget tests
    // This test would verify VoiceRecordingPlayer rendering, but the audio player
    // requires platform channel support which isn't available in unit tests.
    // The widget structure and logic are tested in voice_recording_player_test.dart
    testWidgets('VoiceRecordingPlayer renders for note with voice recording', (
      tester,
    ) async {
      // This test verifies that the VoiceRecordingPlayer widget can render
      // when provided with voice recording data. Full integration with
      // ModernEditNoteScreen would require mocking repository layer.

      // Arrange - Create a standalone player
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggerProvider.overrideWithValue(mockLogger),
            analyticsProvider.overrideWithValue(mockAnalytics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VoiceRecordingPlayer(
                audioUrl: 'https://example.com/test.m4a',
                durationSeconds: 45,
                title: 'Test Voice Note',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify VoiceRecordingPlayer is present and renders
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      ); // Loading state
    }, skip: true);

    testWidgets('Permission denied flow shows dialog', (tester) async {
      // Arrange - Permission denied
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => false);
      when(
        mockAudioRecordingService.requestPermission(),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggerProvider.overrideWithValue(mockLogger),
            analyticsProvider.overrideWithValue(mockAnalytics),
            audioRecordingServiceProvider.overrideWithValue(
              mockAudioRecordingService,
            ),
            voiceNotesServiceProvider.overrideWithValue(mockVoiceNotesService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const FractionallySizedBox(
                        heightFactor: 0.7,
                        child: VoiceRecordingSheet(),
                      ),
                    );
                  },
                  child: const Text('Open Voice Recording'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open sheet and try to record
      await tester.tap(find.text('Open Voice Recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      // Verify permission dialog appears
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      verify(mockAudioRecordingService.hasPermission()).called(1);
      verify(mockAudioRecordingService.requestPermission()).called(1);
      verifyNever(mockAudioRecordingService.startRecording());
    });

    testWidgets('Upload failure shows error message', (tester) async {
      // Arrange - Upload fails
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.startRecording(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.stopRecording(),
      ).thenAnswer((_) async => '/tmp/test.m4a');
      when(
        mockAudioRecordingService.finalizeAndUpload(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggerProvider.overrideWithValue(mockLogger),
            analyticsProvider.overrideWithValue(mockAnalytics),
            audioRecordingServiceProvider.overrideWithValue(
              mockAudioRecordingService,
            ),
            voiceNotesServiceProvider.overrideWithValue(mockVoiceNotesService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const FractionallySizedBox(
                        heightFactor: 0.7,
                        child: VoiceRecordingSheet(),
                      ),
                    );
                  },
                  child: const Text('Open Voice Recording'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Record and try to save
      await tester.tap(find.text('Open Voice Recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify error message
      expect(
        find.text('Failed to upload recording. Please check your connection.'),
        findsOneWidget,
      );
      verifyNever(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: anyNamed('title'),
          folderId: anyNamed('folderId'),
        ),
      );
    });
  });
}
