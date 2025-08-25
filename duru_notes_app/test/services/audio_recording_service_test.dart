import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/services/audio_recording_service.dart';

void main() {
  group('AudioRecordingService', () {
    late AudioRecordingService service;

    setUp(() {
      service = AudioRecordingService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should initialize with correct default state', () {
      expect(service.isRecording, false);
      expect(service.currentRecordingPath, null);
    });

    test('should generate suggested filename correctly', () {
      final filename = service.getSuggestedFilename();
      expect(filename, contains('voice_note_'));
      expect(filename, endsWith('.m4a'));
    });

    test('should generate custom prefix filename correctly', () {
      const prefix = 'custom_recording';
      final filename = service.getSuggestedFilename(prefix: prefix);
      expect(filename, startsWith(prefix));
      expect(filename, endsWith('.m4a'));
    });

    test('should have correct max duration and file size constants', () {
      expect(AudioRecordingService.maxRecordingDuration, 
        equals(const Duration(minutes: 10)));
      expect(AudioRecordingService.maxFileSizeBytes, equals(50 * 1024 * 1024));
    });

    test('should stop recording gracefully when not recording', () async {
      // Should not throw when stopping while not recording
      final result = await service.stopRecording();
      expect(result, null);
    });

    test('should cancel recording gracefully when not recording', () async {
      // Should not throw when cancelling while not recording
      expect(() async => await service.cancelRecording(), returnsNormally);
    });

    test('should dispose cleanly', () async {
      // Test that dispose doesn't throw
      expect(() async => await service.dispose(), returnsNormally);
    });
  });
}
