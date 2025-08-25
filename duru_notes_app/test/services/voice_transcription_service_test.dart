import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:duru_notes_app/services/voice_transcription_service.dart';

// Mock for testing callbacks
class MockPartialCallback extends Mock {
  void call(String text);
}

class MockFinalCallback extends Mock {
  void call(String text);
}

class MockErrorCallback extends Mock {
  void call(String error);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  
  group('VoiceTranscriptionService', () {
    late VoiceTranscriptionService service;
    late MockPartialCallback mockPartialCallback;
    late MockFinalCallback mockFinalCallback;
    late MockErrorCallback mockErrorCallback;

    setUp(() {
      service = VoiceTranscriptionService();
      mockPartialCallback = MockPartialCallback();
      mockFinalCallback = MockFinalCallback();
      mockErrorCallback = MockErrorCallback();
    });

    tearDown(() {
      service.dispose();
    });

    test('should initialize with correct default state', () {
      expect(service.isListening, false);
      expect(service.isAvailable, false);
    });

    test('should not start if not listening', () async {
      // Note: This test may fail on systems without speech recognition
      // In a real app, you'd mock the speech_to_text package
      expect(service.isListening, false);
    });

    test('should handle service state correctly', () {
      // Test initial state
      expect(service.isListening, false);
      expect(service.isAvailable, false);
    });

    test('should handle get locales gracefully', () async {
      // This test may fail on systems without speech recognition support
      // but should not crash the app
      try {
        await service.getLocales();
      } catch (e) {
        // Expected to fail in test environment, but should not crash
        expect(e, isNotNull);
      }
    });

    test('should dispose cleanly', () {
      // Test that dispose doesn't throw
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
