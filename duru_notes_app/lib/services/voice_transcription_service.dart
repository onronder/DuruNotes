import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/monitoring/app_logger.dart';
import 'analytics/analytics_sentry.dart';

typedef PartialCallback = void Function(String text);
typedef FinalCallback = void Function(String text);
typedef ErrorCallback = void Function(String error);

/// Service for managing voice transcription using on-device speech-to-text.
/// 
/// This service provides a facade around the speech_to_text package with
/// privacy-safe analytics, lifecycle management, and error handling.
class VoiceTranscriptionService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  bool _isListening = false;
  DateTime? _sessionStartTime;
  String? _sessionId;
  DateTime? _lastPartialEvent;
  
  // Callbacks for the current session
  PartialCallback? _onPartial;
  FinalCallback? _onFinal;
  ErrorCallback? _onError;
  
  /// Initialize the speech-to-text service
  Future<bool> init() async {
    try {
      logger.breadcrumb('VoiceTranscriptionService init started');
      
      _available = await _stt.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );
      
      logger.info('VoiceTranscriptionService initialized', data: {
        'available': _available,
        'hasPermission': await _hasPermission(),
      });
      
      return _available;
    } catch (e) {
      logger.error('Failed to initialize VoiceTranscriptionService', error: e);
      return false;
    }
  }
  
  /// Check if microphone permission is granted
  Future<bool> _hasPermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      logger.error('Failed to check microphone permission', error: e);
      return false;
    }
  }
  
  /// Request microphone permission
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      
      logger.info('Microphone permission requested', data: {
        'status': status.toString(),
        'isGranted': status.isGranted,
      });
      
      analytics.event('voice.permission_requested', properties: {
        'status': status.toString(),
        'granted': status.isGranted,
      });
      
      return status.isGranted;
    } catch (e) {
      logger.error('Failed to request microphone permission', error: e);
      analytics.trackError('Failed to request microphone permission', 
        context: 'VoiceTranscriptionService');
      return false;
    }
  }
  
  /// Start listening for speech with callbacks
  Future<bool> start({
    required PartialCallback onPartial,
    required FinalCallback onFinal,
    ErrorCallback? onError,
    String? localeId,
  }) async {
    if (_isListening) {
      logger.warn('VoiceTranscriptionService already listening');
      return false;
    }
    
    // Check if service is available
    if (!_available) {
      _available = await init();
    }
    
    if (!_available) {
      final error = 'Speech recognition not available';
      logger.error(error);
      onError?.call(error);
      analytics.trackError(error, context: 'VoiceTranscriptionService');
      return false;
    }
    
    // Check permissions
    if (!await _hasPermission()) {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        final error = 'Microphone permission denied';
        logger.error(error);
        onError?.call(error);
        analytics.event('voice.permission_denied');
        return false;
      }
    }
    
    try {
      // Set up session
      _sessionStartTime = DateTime.now();
      _sessionId = _sessionStartTime!.millisecondsSinceEpoch.toString();
      _onPartial = onPartial;
      _onFinal = onFinal;
      _onError = onError;
      
      // Start listening
      final started = await _stt.listen(
        onResult: _handleResult,
        listenMode: stt.ListenMode.dictation,
        localeId: localeId,
        partialResults: true,
        onSoundLevelChange: _handleSoundLevel,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 10), // Max 10 minutes
      );
      
      if (started == true) {
        _isListening = true;
        
        logger.info('Voice transcription started', data: {
          'sessionId': _sessionId,
          'localeId': localeId,
        });
        
        analytics.event('voice.start', properties: {
          'session_id': _sessionId,
          'locale': localeId ?? 'default',
          'has_permission': true,
        });
        
        return true;
      } else {
        final error = 'Failed to start speech recognition';
        logger.error(error);
        onError?.call(error);
        analytics.trackError(error, context: 'VoiceTranscriptionService');
        return false;
      }
    } catch (e) {
      logger.error('Failed to start voice transcription', error: e);
      onError?.call('Failed to start recording: $e');
      analytics.trackError('Failed to start voice transcription', 
        context: 'VoiceTranscriptionService');
      return false;
    }
  }
  
  /// Stop listening and finalize the session
  Future<void> stop() async {
    if (!_isListening) return;
    
    try {
      await _stt.stop();
      _finalizeSession(false);
      
      logger.info('Voice transcription stopped', data: {
        'sessionId': _sessionId,
      });
    } catch (e) {
      logger.error('Failed to stop voice transcription', error: e);
      analytics.trackError('Failed to stop voice transcription', 
        context: 'VoiceTranscriptionService');
      _finalizeSession(true);
    }
  }
  
  /// Cancel the current session
  Future<void> cancel() async {
    if (!_isListening) return;
    
    try {
      await _stt.cancel();
      _finalizeSession(true);
      
      logger.info('Voice transcription cancelled', data: {
        'sessionId': _sessionId,
      });
      
      analytics.event('voice.cancel', properties: {
        'session_id': _sessionId,
        'duration_ms': _getSessionDuration(),
      });
    } catch (e) {
      logger.error('Failed to cancel voice transcription', error: e);
      analytics.trackError('Failed to cancel voice transcription', 
        context: 'VoiceTranscriptionService');
      _finalizeSession(true);
    }
  }
  
  /// Check if currently listening
  bool get isListening => _isListening;
  
  /// Check if service is available
  bool get isAvailable => _available;
  
  /// Get available locales
  Future<List<stt.LocaleName>> getLocales() async {
    try {
      if (!_available) {
        await init();
      }
      return _stt.locales();
    } catch (e) {
      logger.error('Failed to get locales', error: e);
      return [];
    }
  }
  
  /// Handle speech recognition results
  void _handleResult(dynamic result) {
    final text = (result.recognizedWords as String).trim();
    
    if (text.isEmpty) return;
    
    logger.breadcrumb('Voice transcription result', data: {
      'isFinal': result.finalResult,
      'hasConfidence': result.hasConfidenceRating,
      'confidence': result.confidence,
      'textLength': text.length,
    });
    
    if (result.finalResult == true) {
      _onFinal?.call(text);
      
      analytics.event('voice.final', properties: {
        'session_id': _sessionId,
        'character_count': text.length,
        'word_count': text.split(' ').where((String w) => w.isNotEmpty).length,
        'has_confidence': result.hasConfidenceRating,
        'confidence': result.hasConfidenceRating == true ? result.confidence : null,
        'duration_ms': _getSessionDuration(),
      });
    } else {
      _onPartial?.call(text);
      
      // Throttled partial analytics (max once per 2 seconds)  
      final now = DateTime.now();
      if (_lastPartialEvent == null || 
          now.difference(_lastPartialEvent!).inSeconds >= 2) {
        analytics.event('voice.partial', properties: {
          'session_id': _sessionId,
          'character_count': text.length,
          'has_confidence': result.hasConfidenceRating,
        });
        _lastPartialEvent = now;
      }
    }
  }
  
  /// Handle status changes
  void _handleStatus(String status) {
    logger.breadcrumb('Voice transcription status', data: {
      'status': status,
      'sessionId': _sessionId,
    });
    
    if (status == 'done' || status == 'notListening') {
      _finalizeSession(false);
    }
  }
  
  /// Handle errors
  void _handleError(dynamic error) {
    final errorMessage = error.errorMsg as String;
    
    logger.error('Voice transcription error', error: errorMessage, data: {
      'permanent': error.permanent,
      'sessionId': _sessionId,
    });
    
    _onError?.call(errorMessage);
    
    analytics.event('voice.error', properties: {
      'session_id': _sessionId,
      'error_message': errorMessage,
      'permanent': error.permanent,
      'duration_ms': _getSessionDuration(),
    });
    
    _finalizeSession(true);
  }
  
  /// Handle sound level changes (optional, for UI feedback)
  void _handleSoundLevel(double level) {
    // Could be used for UI feedback like sound wave animation
    // Currently just logged for debugging
    if (kDebugMode) {
      logger.breadcrumb('Sound level', data: {'level': level});
    }
  }
  
  /// Finalize the current session
  void _finalizeSession(bool wasError) {
    _isListening = false;
    
    if (!wasError && _sessionStartTime != null) {
      analytics.event('voice.session_complete', properties: {
        'session_id': _sessionId,
        'duration_ms': _getSessionDuration(),
        'success': !wasError,
      });
    }
    
    // Clear session data
    _sessionStartTime = null;
    _sessionId = null;
    _onPartial = null;
    _onFinal = null;
    _onError = null;
  }
  
  /// Get session duration in milliseconds
  int? _getSessionDuration() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!).inMilliseconds;
  }
  
  /// Dispose of the service
  void dispose() {
    if (_isListening) {
      cancel();
    }
    // Note: speech_to_text doesn't require explicit disposal
  }
}
