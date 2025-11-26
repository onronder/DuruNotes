import 'package:duru_notes/ui/widgets/voice_recording_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceRecordingPlayer', () {
    testWidgets('widget renders without crashing', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test.m4a',
              durationSeconds: 45,
              title: 'Test Recording',
            ),
          ),
        ),
      );

      // Assert - widget should render
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);

      // Shows loading state initially (before audio loads)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('handles different duration values', (tester) async {
      // Test short duration
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test.m4a',
              durationSeconds: 5,
              title: 'Short',
            ),
          ),
        ),
      );
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);

      // Test long duration (> 1 hour)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test2.m4a',
              durationSeconds: 3665, // 1:01:05
              title: 'Long',
            ),
          ),
        ),
      );
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);
    });

    testWidgets('handles empty URL gracefully', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: '',
              durationSeconds: 45,
              title: 'Empty URL Test',
            ),
          ),
        ),
      );

      // Assert - should render without crashing
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);
    });

    testWidgets('widget disposes properly', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test.m4a',
              durationSeconds: 45,
              title: 'Dispose Test',
            ),
          ),
        ),
      );

      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);

      // Act - navigate away to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('New Screen'))),
      );

      // Assert - should dispose without errors
      expect(find.byType(VoiceRecordingPlayer), findsNothing);
      expect(find.text('New Screen'), findsOneWidget);
    });
  });

  group('VoiceRecordingPlayer - Edge Cases', () {
    testWidgets('handles null title gracefully', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test.m4a',
              durationSeconds: 45,
            ),
          ),
        ),
      );

      // Assert - should render without crashing even without title
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);
    });

    testWidgets('handles edge case durations', (tester) async {
      // Zero duration
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test.m4a',
              durationSeconds: 0,
              title: 'Zero Duration',
            ),
          ),
        ),
      );
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);

      // Negative duration (invalid but should handle gracefully)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPlayer(
              audioUrl: 'https://example.com/test2.m4a',
              durationSeconds: -10,
              title: 'Negative Duration',
            ),
          ),
        ),
      );
      expect(find.byType(VoiceRecordingPlayer), findsOneWidget);
    });
  });

  group('VoiceRecordingPlayer - Integration Notes', () {
    // Note: Full playback testing requires mocking just_audio's AudioPlayer
    // which is complex due to platform channel dependencies. These tests verify:
    // 1. Widget structure and layout
    // 2. Initial state rendering
    // 3. Error handling
    // 4. Disposal behavior
    //
    // For full playback functionality (play/pause/seek), use integration tests
    // or manual testing on real devices/simulators.
  });
}
