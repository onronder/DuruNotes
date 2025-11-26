import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/audio_recording_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/voice_notes_service.dart';
import 'package:duru_notes/ui/widgets/voice_recording_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'voice_recording_sheet_test.mocks.dart';

@GenerateMocks([
  AppLogger,
  AnalyticsService,
  AudioRecordingService,
  VoiceNotesService,
])
void main() {
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

  Widget createWidgetUnderTest({String? folderId}) {
    return ProviderScope(
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
                  builder: (context) => FractionallySizedBox(
                    heightFactor: 0.7,
                    child: VoiceRecordingSheet(folderId: folderId),
                  ),
                );
              },
              child: const Text('Show Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('VoiceRecordingSheet', () {
    testWidgets('shows initial idle state', (tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Assert - verify initial state UI elements
      expect(find.text('Voice Note'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('Tap to start recording'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('shows recording state when recording starts', (tester) async {
      // Arrange
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.startRecording(),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Act - tap the record button
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      // Assert - verify recording state
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Recording...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Verify service methods were called
      verify(mockAudioRecordingService.hasPermission()).called(1);
      verify(mockAudioRecordingService.startRecording()).called(1);
    });

    testWidgets('shows permission denied dialog when permission is denied', (
      tester,
    ) async {
      // Arrange
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => false);
      when(
        mockAudioRecordingService.requestPermission(),
      ).thenAnswer((_) async => false); // Permission request denied

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Act - tap the record button
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      // Assert - verify permission dialog is shown
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      // Verify permission flow was executed
      verify(mockAudioRecordingService.hasPermission()).called(1);
      verify(mockAudioRecordingService.requestPermission()).called(1);
      verifyNever(mockAudioRecordingService.startRecording());
    });

    testWidgets('shows title input after recording stops', (tester) async {
      // Arrange
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.startRecording(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.stopRecording(),
      ).thenAnswer((_) async => '/tmp/voice_note_test.m4a');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Start recording
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      // Act - stop recording
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Assert - verify title input is shown
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Title'), findsOneWidget); // TextField label
      expect(find.text('Save'), findsOneWidget); // Save button
      expect(find.text('Re-record'), findsOneWidget); // Re-record button

      // Verify stop was called
      verify(mockAudioRecordingService.stopRecording()).called(1);
    });

    testWidgets('creates voice note when save is tapped with valid title', (
      tester,
    ) async {
      // Arrange
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
          url: 'https://example.com/test.m4a',
          filename: 'test.m4a',
          durationSeconds: 45,
        ),
      );

      final testNote = Note(
        id: 'note-123',
        title: 'My Recording',
        body: 'Voice note',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user-123',
      );

      when(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: anyNamed('title'),
          folderId: anyNamed('folderId'),
        ),
      ).thenAnswer((_) async => testNote);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Start and stop recording
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Act - enter custom title and save
      await tester.enterText(find.byType(TextField), 'My Recording');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - verify voice note creation
      verify(mockAudioRecordingService.finalizeAndUpload()).called(1);
      verify(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: 'My Recording',
          folderId: null,
        ),
      ).called(1);
    });

    testWidgets('shows error when upload fails', (tester) async {
      // Arrange
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.startRecording(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.stopRecording(),
      ).thenAnswer((_) async => '/tmp/voice_note_test.m4a');
      when(
        mockAudioRecordingService.finalizeAndUpload(),
      ).thenAnswer((_) async => null); // Upload failed

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Start and stop recording
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Act - try to save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - verify error message
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

    testWidgets('cancels recording and closes sheet', (tester) async {
      // Arrange
      when(
        mockAudioRecordingService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.startRecording(),
      ).thenAnswer((_) async => true);
      when(
        mockAudioRecordingService.stopRecording(),
      ).thenAnswer((_) async => '/tmp/voice_note_test.m4a');
      when(
        mockAudioRecordingService.cancelRecording(),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Start recording
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      // Act - tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - verify sheet is closed
      expect(find.text('Voice Note'), findsNothing);
      verify(mockAudioRecordingService.cancelRecording()).called(1);
    });

    testWidgets('passes folderId to voice note creation', (tester) async {
      // Arrange
      const testFolderId = 'folder-456';

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
          url: 'https://example.com/test.m4a',
          filename: 'test.m4a',
          durationSeconds: 45,
        ),
      );

      final testNote = Note(
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
        folderId: testFolderId,
      );

      when(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: anyNamed('title'),
          folderId: anyNamed('folderId'),
        ),
      ).thenAnswer((_) async => testNote);

      await tester.pumpWidget(createWidgetUnderTest(folderId: testFolderId));
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Start and stop recording
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Act - save with default title
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - verify folderId was passed
      verify(
        mockVoiceNotesService.createVoiceNote(
          recording: anyNamed('recording'),
          title: anyNamed('title'),
          folderId: testFolderId,
        ),
      ).called(1);
    });
  });
}
