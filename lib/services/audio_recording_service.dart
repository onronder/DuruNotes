import 'dart:io';
import 'dart:typed_data';

import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Result of a completed voice recording with upload information
class RecordingResult {
  const RecordingResult({
    required this.url,
    required this.filename,
    required this.durationSeconds,
  });

  final String url;
  final String filename;
  final int durationSeconds;
}

/// Audio recording service for recording voice notes
class AudioRecordingService {
  AudioRecordingService(this._ref);

  final Ref _ref;
  AppLogger get _logger => _ref.read(loggerProvider);
  AnalyticsService get _analytics => _ref.read(analyticsProvider);
  AttachmentService get _attachmentService => _ref.read(attachmentServiceProvider);
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  /// Start recording audio
  Future<bool> startRecording({String? sessionId}) async {
    if (_isRecording) {
      await stopRecording();
    }

    try {
      // Check microphone permission
      final micPermission = await Permission.microphone.status;
      if (micPermission.isDenied) {
        final granted = await Permission.microphone.request();
        if (!granted.isGranted) {
          throw Exception('Microphone permission denied');
        }
      }

      // Check if recording is supported
      if (!await _recorder.hasPermission()) {
        throw Exception('Recording permission not granted');
      }

      _analytics.startTiming('audio_recording_session');

      // Generate recording file path
      final directory = await resolveTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sessionPrefix = sessionId != null ? '${sessionId}_' : '';
      final filename = '${sessionPrefix}voice_note_$timestamp.m4a';
      _currentRecordingPath = path.join(directory.path, filename);

      // Start recording
      await _recorder.start(const RecordConfig(), path: _currentRecordingPath!);

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      _analytics.featureUsed(
        'audio_recording_start',
        properties: {
          'session_id': sessionId,
          'recording_type': 'voice_note',
        },
      );

      _logger.info(
        'Audio recording started',
        data: {'path': _currentRecordingPath, 'session_id': sessionId},
      );

      return true;
    } catch (e) {
      _logger.error('Failed to start audio recording', error: e);
      _analytics.trackError(
        'Audio recording start failed',
        properties: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final recordingPath = await _recorder.stop();
      _isRecording = false;

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      _analytics.endTiming(
        'audio_recording_session',
        properties: {
          'success': true,
          'duration_seconds': duration.inSeconds,
          'file_path': recordingPath,
        },
      );

      _analytics.featureUsed(
        'audio_recording_complete',
        properties: {
          'duration_seconds': duration.inSeconds,
          'recording_type': 'voice_note',
        },
      );

      _logger.info(
        'Audio recording completed',
        data: {'path': recordingPath, 'duration': duration.inSeconds},
      );

      return recordingPath ?? _currentRecordingPath;
    } catch (e) {
      _logger.error('Failed to stop audio recording', error: e);
      _analytics.endTiming(
        'audio_recording_session',
        properties: {'success': false, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
      _isRecording = false;

      // Delete the recording file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _analytics.endTiming(
        'audio_recording_session',
        properties: {'success': false, 'reason': 'cancelled'},
      );

      _logger.info('Audio recording cancelled');
    } catch (e) {
      _logger.error('Failed to cancel audio recording', error: e);
    }
  }

  /// Get recording as bytes
  Future<Uint8List?> getRecordingBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.warning('Recording file not found', data: {'path': filePath});
        return null;
      }

      final bytes = await file.readAsBytes();

      _logger.info(
        'Recording file read',
        data: {'path': filePath, 'size': bytes.length},
      );

      return bytes;
    } catch (e) {
      _logger.error(
        'Failed to read recording file',
        error: e,
        data: {'path': filePath},
      );
      return null;
    }
  }

  /// Delete recording file
  Future<bool> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _logger.info('Recording file deleted', data: {'path': filePath});
        return true;
      }
      return false;
    } catch (e) {
      _logger.error(
        'Failed to delete recording file',
        error: e,
        data: {'path': filePath},
      );
      return false;
    }
  }

  /// Get duration of recording file
  Future<Duration?> getRecordingDuration(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      // This is a simplified implementation
      // In a real app, you might want to use a library like just_audio to get exact duration
      final stat = await file.stat();
      final size = stat.size;

      // Rough estimation: 128kbps bitrate
      // Duration ≈ (file_size_bytes * 8) / bitrate_bps
      final estimatedDurationSeconds = (size * 8) / 128000;

      return Duration(seconds: estimatedDurationSeconds.round());
    } catch (e) {
      _logger.error('Failed to get recording duration', error: e);
      return null;
    }
  }

  /// Finalize recording and upload to Supabase Storage
  ///
  /// This method:
  /// 1. Stops recording if active
  /// 2. Reads recording file bytes
  /// 3. Uploads to Supabase Storage via AttachmentService
  /// 4. Deletes local temp file after successful upload
  /// 5. Returns RecordingResult with url, filename, and duration
  ///
  /// Returns null if recording fails or upload fails
  Future<RecordingResult?> finalizeAndUpload({String? sessionId}) async {
    try {
      _analytics.startTiming('voice_note_finalize_upload');

      // Stop recording if active
      String? recordingPath = _currentRecordingPath;
      if (_isRecording) {
        recordingPath = await stopRecording();
      }

      if (recordingPath == null) {
        _logger.warning('No recording path available for upload');
        _analytics.endTiming(
          'voice_note_finalize_upload',
          properties: {'success': false, 'reason': 'no_recording'},
        );
        return null;
      }

      // Get recording bytes
      final bytes = await getRecordingBytes(recordingPath);
      if (bytes == null) {
        _logger.error('Failed to read recording bytes');
        _analytics.endTiming(
          'voice_note_finalize_upload',
          properties: {'success': false, 'reason': 'read_failed'},
        );
        return null;
      }

      // Get duration
      final duration = await getRecordingDuration(recordingPath);
      final durationSeconds = duration?.inSeconds ?? 0;

      // Extract filename from path
      final filename = path.basename(recordingPath);

      // Upload to Supabase Storage
      _logger.info(
        'Uploading voice recording',
        data: {'filename': filename, 'size': bytes.length},
      );

      final attachmentData = await _attachmentService.uploadFromBytes(
        bytes: bytes,
        filename: filename,
      );

      if (attachmentData == null || attachmentData.url == null) {
        _logger.error('Failed to upload voice recording - no URL returned');
        _analytics.endTiming(
          'voice_note_finalize_upload',
          properties: {'success': false, 'reason': 'upload_failed_no_url'},
        );
        return null;
      }

      // Delete local temp file after successful upload
      await deleteRecording(recordingPath);

      final result = RecordingResult(
        url: attachmentData.url!,
        filename: attachmentData.fileName,
        durationSeconds: durationSeconds,
      );

      _analytics.endTiming(
        'voice_note_finalize_upload',
        properties: {
          'success': true,
          'duration_seconds': durationSeconds,
          'file_size': bytes.length,
          'recording_type': 'voice_note',
        },
      );

      _logger.info(
        'Voice recording uploaded successfully',
        data: {
          'url': result.url,
          'filename': result.filename,
          'duration': durationSeconds,
        },
      );

      return result;
    } catch (e, stackTrace) {
      print('[AUDIO_SERVICE_DEBUG] ========== UPLOAD FAILED ==========');
      print('[AUDIO_SERVICE_DEBUG] Error type: ${e.runtimeType}');
      print('[AUDIO_SERVICE_DEBUG] Error message: $e');
      print('[AUDIO_SERVICE_DEBUG] Stack trace:');
      print(stackTrace);
      print('[AUDIO_SERVICE_DEBUG] ==========================================');

      _logger.error('Failed to finalize and upload recording', error: e);
      _analytics.endTiming(
        'voice_note_finalize_upload',
        properties: {
          'success': false,
          'error': e.toString(),
          'recording_type': 'voice_note',
        },
      );
      _analytics.trackError(
        'Voice recording upload failed',
        properties: {'error': e.toString()},
      );
      return null;
    }
  }

  /// Clean up orphaned recording files older than specified age
  ///
  /// Scans the temp directory for voice_note_*.m4a files and deletes
  /// files older than the specified duration (default: 24 hours).
  ///
  /// This helps prevent temp directory bloat from failed uploads or
  /// cancelled recordings.
  ///
  /// Returns the number of files cleaned up.
  Future<int> cleanupOrphanedRecordings({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    int cleanedCount = 0;
    try {
      final directory = await resolveTemporaryDirectory();
      final files = directory.listSync();
      final now = DateTime.now();

      for (final file in files) {
        if (file is File) {
          final filename = path.basename(file.path);

          // Check if it's a voice note file
          if (filename.contains('voice_note') && filename.endsWith('.m4a')) {
            try {
              final stat = await file.stat();
              final age = now.difference(stat.modified);

              if (age > maxAge) {
                await file.delete();
                cleanedCount++;
                _logger.info(
                  'Deleted orphaned recording',
                  data: {'path': file.path, 'age_hours': age.inHours},
                );
              }
            } catch (e) {
              _logger.warning(
                'Failed to clean up orphaned recording',
                data: {'path': file.path, 'error': e.toString()},
              );
            }
          }
        }
      }

      if (cleanedCount > 0) {
        _logger.info(
          'Cleanup completed',
          data: {'cleaned_count': cleanedCount},
        );
        _analytics.featureUsed(
          'voice_note_cleanup',
          properties: {'cleaned_count': cleanedCount},
        );
      }

      return cleanedCount;
    } catch (e) {
      _logger.error('Failed to cleanup orphaned recordings', error: e);
      return cleanedCount;
    }
  }

  /// Get suggested filename for voice recording
  String getSuggestedFilename({String prefix = 'voice_note'}) {
    final timestamp = DateTime.now();
    final formattedDate =
        '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';

    return '${prefix}_${formattedDate}_$formattedTime.m4a';
  }

  /// Check if recording is supported on this device
  Future<bool> isSupported() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      return false;
    }
  }

  /// Check microphone permission
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Get current recording state
  bool get isRecording => _isRecording;

  /// Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Get recording duration so far
  Duration? get currentRecordingDuration {
    if (!_isRecording || _recordingStartTime == null) {
      return null;
    }
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Dispose resources
  void dispose() {
    if (_isRecording) {
      cancelRecording();
    }
    _recorder.dispose();
  }
}
