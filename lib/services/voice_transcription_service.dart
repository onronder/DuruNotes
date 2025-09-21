import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service for converting speech to text using the microphone.
class VoiceTranscriptionService {
  VoiceTranscriptionService({AppLogger? logger, AnalyticsService? analytics})
      : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance;

  final AppLogger _logger;
  final AnalyticsService _analytics;
  final SpeechToText _speechToText = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';

  // Optional callback hooks
  Function(String)? _onPartial;
  Function(String)? _onFinal;
  Function(String)? _onError;

  /// Initialize the speech-to-text engine (request mic permission if needed).
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _analytics.startTiming('voice_transcription_init');
      // Check microphone permission
      final micPermission = await Permission.microphone.status;
      if (!micPermission.isGranted) {
        final granted = await Permission.microphone.request();
        if (!granted.isGranted) {
          throw Exception('Microphone permission denied');
        }
      }
      // Initialize SpeechToText plugin
      final available = await _speechToText.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
      if (!available) {
        throw Exception('Speech recognition not available');
      }
      _isInitialized = true;
      _analytics.endTiming(
        'voice_transcription_init',
        properties: {'success': true},
      );
      _logger.info('Voice transcription service initialized');
      return true;
    } catch (e) {
      _logger.error('Failed to initialize voice transcription', error: e);
      _analytics.endTiming(
        'voice_transcription_init',
        properties: {'success': false, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Start listening for speech input.
  Future<bool> start({
    Function(String)? onPartial,
    Function(String)? onFinal,
    Function(String)? onError,
  }) async {
    if (!_isInitialized && !await initialize()) {
      return false;
    }
    if (_isListening) {
      await stop();
    }
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onError = onError;
    try {
      _analytics.startTiming('voice_transcription_session');
      await _speechToText.listen(
        onResult: _handleResult,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      );
      _isListening = true;
      _lastWords = '';
      _analytics.featureUsed('voice_transcription_start');
      _logger.info('Voice transcription started');
      return true;
    } catch (e) {
      _logger.error('Failed to start voice transcription', error: e);
      _onError?.call('Failed to start recording: $e');
      return false;
    }
  }

  /// Stop listening and finalize the transcription.
  Future<void> stop() async {
    if (!_isListening) return;
    try {
      await _speechToText.stop();
      _isListening = false;
      // Deliver final result if available
      if (_lastWords.isNotEmpty) {
        _onFinal?.call(_lastWords);
      }
      _analytics.endTiming(
        'voice_transcription_session',
        properties: {
          'success': true,
          'words_transcribed': _lastWords.split(' ').length,
        },
      );
      _logger.info(
        'Voice transcription stopped',
        data: {'final_text': _lastWords},
      );
    } catch (e) {
      _logger.error('Error stopping voice transcription', error: e);
    }
  }

  /// Cancel listening without using the current partial result.
  Future<void> cancel() async {
    if (!_isListening) return;
    try {
      await _speechToText.cancel();
      _isListening = false;
      _lastWords = '';
      _analytics.endTiming(
        'voice_transcription_session',
        properties: {'success': false, 'reason': 'cancelled'},
      );
      _logger.info('Voice transcription cancelled');
    } catch (e) {
      _logger.error('Error cancelling voice transcription', error: e);
    }
  }

  /// Handle incoming speech recognition results.
  void _handleResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords;
    final isFinal = result.finalResult;
    _lastWords = recognizedWords;
    if (isFinal) {
      _onFinal?.call(recognizedWords);
      _analytics.featureUsed(
        'voice_transcription_final',
        properties: {
          'word_count': recognizedWords.split(' ').length,
          'character_count': recognizedWords.length,
        },
      );
    } else {
      _onPartial?.call(recognizedWords);
    }
  }

  /// Handle speech recognition errors.
  void _handleError(SpeechRecognitionError error) {
    final errorMsg = error.errorMsg;
    final errorType = error
        .errorMsg; // Use errorMsg as errorType since errorType doesn't exist
    _logger.error(
      'Voice transcription error',
      data: {'error_msg': errorMsg, 'error_type': errorType},
    );
    _analytics.trackError(
      'Voice transcription error',
      properties: {'error_type': errorType, 'error_message': errorMsg},
    );
    _onError?.call(errorMsg);
  }

  /// Handle speech recognition status changes.
  void _handleStatus(String status) {
    _logger.debug('Voice transcription status: $status');
    if (status == 'done') {
      _isListening = false;
      if (_lastWords.isNotEmpty) {
        _onFinal?.call(_lastWords);
      }
    }
  }

  /// Check if microphone permissions have been granted.
  Future<bool> hasPermissions() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission from the user.
  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Dispose any active resources (stop listening if active).
  void dispose() {
    if (_isListening) {
      cancel();
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
}
