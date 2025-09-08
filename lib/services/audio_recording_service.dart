import 'dart:io';
import 'dart:typed_data';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Audio recording service for recording voice notes
class AudioRecordingService {
  AudioRecordingService({
    AppLogger? logger,
    AnalyticsService? analytics,
  })  : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance;

  final AppLogger _logger;
  final AnalyticsService _analytics;
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
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sessionPrefix = sessionId != null ? '${sessionId}_' : '';
      final filename = '${sessionPrefix}voice_note_$timestamp.m4a';
      _currentRecordingPath = path.join(directory.path, filename);
      
      // Start recording
      await _recorder.start(
        const RecordConfig(
          
        ),
        path: _currentRecordingPath!,
      );
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      _analytics.featureUsed('audio_recording_start', properties: {
        'session_id': sessionId,
      });
      
      _logger.info('Audio recording started', data: {
        'path': _currentRecordingPath,
        'session_id': sessionId,
      });
      
      return true;
    } catch (e) {
      _logger.error('Failed to start audio recording', error: e);
      _analytics.trackError('Audio recording start failed', properties: {
        'error': e.toString(),
      });
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
      
      _analytics.endTiming('audio_recording_session', properties: {
        'success': true,
        'duration_seconds': duration.inSeconds,
        'file_path': recordingPath,
      });
      
      _analytics.featureUsed('audio_recording_complete', properties: {
        'duration_seconds': duration.inSeconds,
      });
      
      _logger.info('Audio recording completed', data: {
        'path': recordingPath,
        'duration': duration.inSeconds,
      });
      
      return recordingPath ?? _currentRecordingPath;
    } catch (e) {
      _logger.error('Failed to stop audio recording', error: e);
      _analytics.endTiming('audio_recording_session', properties: {
        'success': false,
        'error': e.toString(),
      });
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
      
      _analytics.endTiming('audio_recording_session', properties: {
        'success': false,
        'reason': 'cancelled',
      });
      
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
      
      _logger.info('Recording file read', data: {
        'path': filePath,
        'size': bytes.length,
      });
      
      return bytes;
    } catch (e) {
      _logger.error('Failed to read recording file', error: e, data: {
        'path': filePath,
      });
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
      _logger.error('Failed to delete recording file', error: e, data: {
        'path': filePath,
      });
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

  /// Get suggested filename for voice recording
  String getSuggestedFilename({String prefix = 'voice_note'}) {
    final timestamp = DateTime.now();
    final formattedDate = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
    final formattedTime = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
    
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
