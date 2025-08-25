import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';

void main() {
  group('Voice Recording Widget Tests', () {
    testWidgets('EditNoteScreen should show microphone button', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const EditNoteScreen(),
          ),
        ),
      );

      // Find the microphone button in the app bar
      final micButton = find.byIcon(Icons.mic_none);
      expect(micButton, findsOneWidget);
    });

    testWidgets('EditNoteScreen should show popup menu button', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const EditNoteScreen(),
          ),
        ),
      );

      // Find the popup menu button
      final popupMenuButton = find.byType(PopupMenuButton<String>);
      expect(popupMenuButton, findsOneWidget);
    });

    testWidgets('Should show audio attachment option in popup menu', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const EditNoteScreen(),
          ),
        ),
      );

      // Tap the popup menu button
      final popupMenuButton = find.byType(PopupMenuButton<String>);
      await tester.tap(popupMenuButton);
      await tester.pumpAndSettle();

      // Look for the audio attachment option
      expect(find.text('Save audio attachment'), findsOneWidget);
    });

    testWidgets('Should not show live transcript when not recording', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const EditNoteScreen(),
          ),
        ),
      );

      // Live transcript should not be visible initially
      expect(find.text('Live transcript:'), findsNothing);
    });

    testWidgets('Should show correct title without recording indicator', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const EditNoteScreen(),
          ),
        ),
      );

      // Check that title doesn't contain recording indicator
      final titleFinder = find.textContaining('New note');
      expect(titleFinder, findsOneWidget);
      
      // Should not contain microphone emoji when not recording
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.data, isNot(contains('🎤')));
    });
  });
}
