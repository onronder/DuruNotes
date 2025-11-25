import 'package:duru_notes/core/feature_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for voice dictation text insertion logic
///
/// Note: Full widget tests for ModernEditNoteScreen require extensive
/// provider mocking. These tests focus on the core text insertion logic.
void main() {
  setUp(() {
    // Enable the feature flag for testing
    FeatureFlags.instance.setOverride('voice_dictation_enabled', true);
  });

  tearDown(() {
    FeatureFlags.instance.clearOverrides();
  });

  group('Voice Dictation Feature Flag', () {
    test('voiceDictationEnabled returns true when flag is enabled', () {
      FeatureFlags.instance.setOverride('voice_dictation_enabled', true);
      expect(FeatureFlags.instance.voiceDictationEnabled, isTrue);
    });

    test('voiceDictationEnabled returns false when flag is disabled', () {
      FeatureFlags.instance.setOverride('voice_dictation_enabled', false);
      expect(FeatureFlags.instance.voiceDictationEnabled, isFalse);
    });
  });

  group('Voice Dictation Text Insertion Logic', () {
    /// Helper function that replicates the text insertion logic from
    /// ModernEditNoteScreen._onDictationFinal
    TextEditingValue insertDictatedText({
      required String existingText,
      required TextSelection selection,
      required String transcript,
    }) {
      if (transcript.isEmpty) {
        return TextEditingValue(text: existingText, selection: selection);
      }

      final text = existingText;

      // Determine insertion point (cursor or end of text)
      final start = selection.isValid && selection.start >= 0
          ? selection.start
          : text.length;
      final end = selection.isValid && selection.end >= 0
          ? selection.end
          : text.length;

      // Add space before if needed (auto-spacing)
      final needsLeadingSpace = start > 0 &&
          text.isNotEmpty &&
          !RegExp(r'\s').hasMatch(text[start - 1]);
      final insertText = needsLeadingSpace ? ' $transcript' : transcript;

      final newText = text.replaceRange(start, end, insertText);
      final newCursorPosition = start + insertText.length;

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
        composing: TextRange.empty,
      );
    }

    test('inserts text at cursor position', () {
      final result = insertDictatedText(
        existingText: 'Hello world',
        selection: const TextSelection.collapsed(offset: 6), // After "Hello "
        transcript: 'beautiful ',
      );

      // Cursor is after space in "Hello ", so no auto-space added
      // Insert "beautiful " (with trailing space) to separate from "world"
      expect(result.text, equals('Hello beautiful world'));
      expect(result.selection.baseOffset, equals(16)); // After "beautiful "
    });

    test('appends text at end when cursor is at end', () {
      final result = insertDictatedText(
        existingText: 'Hello',
        selection: const TextSelection.collapsed(offset: 5),
        transcript: 'world',
      );

      expect(result.text, equals('Hello world')); // Auto-space added
      expect(result.selection.baseOffset, equals(11));
    });

    test('adds space before text when inserting after non-whitespace', () {
      final result = insertDictatedText(
        existingText: 'Hello',
        selection: const TextSelection.collapsed(offset: 5),
        transcript: 'there',
      );

      // Should add space before "there"
      expect(result.text, equals('Hello there'));
      expect(result.selection.baseOffset, equals(11));
    });

    test('does not add space when inserting after whitespace', () {
      final result = insertDictatedText(
        existingText: 'Hello ',
        selection: const TextSelection.collapsed(offset: 6),
        transcript: 'world',
      );

      // Should NOT add extra space
      expect(result.text, equals('Hello world'));
      expect(result.selection.baseOffset, equals(11));
    });

    test('does not add space when inserting at start', () {
      final result = insertDictatedText(
        existingText: 'world',
        selection: const TextSelection.collapsed(offset: 0),
        transcript: 'Hello',
      );

      // Should NOT add space at start
      expect(result.text, equals('Helloworld'));
      expect(result.selection.baseOffset, equals(5));
    });

    test('replaces selected text', () {
      final result = insertDictatedText(
        existingText: 'Hello bad world',
        selection: const TextSelection(baseOffset: 6, extentOffset: 9), // "bad"
        transcript: 'beautiful',
      );

      expect(result.text, equals('Hello beautiful world'));
      expect(result.selection.baseOffset, equals(15));
    });

    test('handles empty transcript gracefully', () {
      final result = insertDictatedText(
        existingText: 'Hello world',
        selection: const TextSelection.collapsed(offset: 6),
        transcript: '',
      );

      // Should not modify anything
      expect(result.text, equals('Hello world'));
    });

    test('handles empty existing text', () {
      final result = insertDictatedText(
        existingText: '',
        selection: const TextSelection.collapsed(offset: 0),
        transcript: 'Hello world',
      );

      expect(result.text, equals('Hello world'));
      expect(result.selection.baseOffset, equals(11));
    });

    test('handles invalid selection by appending to end', () {
      final result = insertDictatedText(
        existingText: 'Hello',
        selection: const TextSelection.collapsed(offset: -1),
        transcript: 'world',
      );

      // Should append to end with space
      expect(result.text, equals('Hello world'));
    });
  });
}
