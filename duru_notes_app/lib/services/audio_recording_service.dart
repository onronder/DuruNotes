import 'dart:typed_data';

import '../core/monitoring/app_logger.dart';
import 'analytics/analytics_sentry.dart';

/// Service for recording raw audio that can be saved as attachments.
/// 
/// This service works alongside VoiceTranscriptionService to optionally
/// capture the raw audio while transcription is happening. The recorded
/// audio can then be uploaded as an attachment.
/// 
/// NOTE: Currently disabled due to dependency compatibility issues.
/// Voice transcription will work without audio recording.
class AudioRecordingService {
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  String? _sessionId;
  
  static const Duration maxRecordingDuration = Duration(minutes: 10);
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB
  
  /// Start recording audio to a temporary file
  Future<bool> startRecording({String? sessionId}) async {
    // Audio recording temporarily disabled due to dependency compatibility issues
    logger.info('Audio recording temporarily disabled - voice transcription will work without it');
    analytics.event('audio_recording.disabled');
    return false;
  }
  
  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    // Audio recording disabled
    return null;
  }

  /// Cancel the current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    // Audio recording disabled
    _cleanup();
  }
  
  /// Read the recorded file as bytes
  Future<Uint8List?> getRecordingBytes(String filePath) async {
    // Audio recording disabled
    return null;
  }
  
  /// Delete a recording file
  Future<bool> deleteRecording(String filePath) async {
    // Audio recording disabled
    return false;
  }
  
  /// Get the suggested filename for the recording
  String getSuggestedFilename({String? prefix}) {
    final timestamp = DateTime.now();
    final dateStr = timestamp.toIso8601String().substring(0, 19).replaceAll(':', '-');
    return '${prefix ?? 'voice_note'}_$dateStr.m4a';
  }
  
  /// Check if currently recording
  bool get isRecording => _isRecording;
  
  /// Get current recording path (if any)
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// Clean up session state
  void _cleanup() {
    _isRecording = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _sessionId = null;
  }
  
  /// Dispose of the service
  Future<void> dispose() async {
    if (_isRecording) {
      await cancelRecording();
    }
  }
}