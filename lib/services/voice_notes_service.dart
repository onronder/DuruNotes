import 'dart:convert';
import 'dart:io' show Platform;

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/audio_recording_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Service for creating and managing voice notes
class VoiceNotesService {
  VoiceNotesService(this._ref);

  final Ref _ref;
  AppLogger get _logger => _ref.read(loggerProvider);
  AnalyticsService get _analytics => _ref.read(analyticsProvider);
  INotesRepository get _notesRepository => _ref.read(notesCoreRepositoryProvider);

  /// Create a new voice note from a recording result
  ///
  /// Takes a RecordingResult DTO (url, filename, durationSeconds) and creates
  /// a new note with voice recording metadata in attachmentMeta.voiceRecordings.
  ///
  /// Uses INotesRepository.createOrUpdate() (not a custom repo method) and
  /// emits voice_note_created analytics event with duration and platform.
  ///
  /// Returns the created Note or null if creation fails
  Future<Note?> createVoiceNote({
    required RecordingResult recording,
    required String title,
    String? folderId,
  }) async {
    try {
      _analytics.startTiming('voice_note_create');

      // Build voiceRecordings metadata consistent with NOTE_ATTACHMENT_SCHEMA.md
      final voiceRecording = {
        'id': const Uuid().v4(),
        'url': recording.url,
        'filename': recording.filename,
        'durationSeconds': recording.durationSeconds,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Pass attachmentMeta as Map<String, dynamic> (not JSON string)
      final attachmentMeta = {
        'voiceRecordings': [voiceRecording],
      };

      // Create note using generic createOrUpdate (not a custom method)
      // Note: noteType is not a parameter - repository defaults to NoteKind.note
      final now = DateTime.now();
      final durationText = _formatDuration(recording.durationSeconds);

      final note = await _notesRepository.createOrUpdate(
        title: title,
        body: 'Voice note ($durationText) recorded on ${_formatDate(now)}',
        attachmentMeta: attachmentMeta,
        tags: ['voice-note'],
        folderId: folderId,  // If null, defaults to Inbox
      );

      if (note == null) {
        _analytics.endTiming(
          'voice_note_create',
          properties: {
            'success': false,
            'reason': 'repository_returned_null',
          },
        );

        _logger.warning(
          'NotesRepository.createOrUpdate returned null for voice note',
          data: {
            'title': title,
            'duration_seconds': recording.durationSeconds,
            'folder_id': folderId,
          },
        );
        return null;
      }

      // Defensive null check - repository can return null if no authenticated user
      if (note == null) {
        _logger.error('Repository returned null when creating voice note');
        _analytics.endTiming(
          'voice_note_create',
          properties: {
            'success': false,
            'reason': 'repository_returned_null',
          },
        );
        return null;
      }

      _analytics.endTiming(
        'voice_note_create',
        properties: {
          'success': true,
          'duration_seconds': recording.durationSeconds,
          'has_custom_title': title.isNotEmpty,
        },
      );

      // Emit voice_note_created analytics event with duration and platform
      _analytics.featureUsed(
        'voice_note_created',
        properties: {
          'duration_seconds': recording.durationSeconds,
          'platform': _getPlatform(),
        },
      );

      _logger.info(
        'Voice note created successfully',
        data: {
          'note_id': note.id,
          'title': title,
          'duration_seconds': recording.durationSeconds,
          'url': recording.url,
        },
      );

      return note;
    } catch (e) {
      _logger.error('Failed to create voice note', error: e);

      _analytics.endTiming(
        'voice_note_create',
        properties: {
          'success': false,
          'error': e.toString(),
        },
      );

      _analytics.trackError(
        'Voice note creation failed',
        properties: {'error': e.toString()},
      );

      return null;
    }
  }

  /// Add voice recording to existing note
  ///
  /// Appends a new voice recording to an existing note's attachmentMeta.
  /// If the note doesn't have attachmentMeta, it creates it.
  ///
  /// Returns the updated Note or null if update fails
  Future<Note?> addVoiceRecordingToNote({
    required Note note,
    required RecordingResult recording,
  }) async {
    try {
      _analytics.startTiming('voice_recording_add_to_note');

      // Parse existing attachmentMeta or create new
      Map<String, dynamic> attachmentData = {};
      if (note.attachmentMeta != null && note.attachmentMeta!.isNotEmpty) {
        try {
          attachmentData = jsonDecode(note.attachmentMeta!) as Map<String, dynamic>;
        } catch (e) {
          _logger.warning('Failed to parse existing attachmentMeta', data: {'error': e.toString()});
        }
      }

      // Get existing voice recordings or create empty list
      final List<dynamic> voiceRecordings =
          (attachmentData['voiceRecordings'] as List<dynamic>?) ?? [];

      // Add new recording consistent with schema
      final newRecording = {
        'id': const Uuid().v4(),
        'url': recording.url,
        'filename': recording.filename,
        'durationSeconds': recording.durationSeconds,
        'createdAt': DateTime.now().toIso8601String(),
      };

      voiceRecordings.add(newRecording);
      attachmentData['voiceRecordings'] = voiceRecordings;

      // Update note using generic createOrUpdate
      // Pass attachmentData as Map<String, dynamic> (not JSON string)
      final updatedNote = await _notesRepository.createOrUpdate(
        id: note.id,
        title: note.title,
        body: note.body,
        attachmentMeta: attachmentData,
        tags: note.tags.contains('voice-note')
            ? note.tags
            : [...note.tags, 'voice-note'],
        folderId: note.folderId,
        isPinned: note.isPinned,
      );

      // Defensive null check - repository can return null if no authenticated user
      if (updatedNote == null) {
        _logger.error('Repository returned null when updating note with voice recording');
        _analytics.endTiming(
          'voice_recording_add_to_note',
          properties: {
            'success': false,
            'reason': 'repository_returned_null',
          },
        );
        return null;
      }

      _analytics.endTiming(
        'voice_recording_add_to_note',
        properties: {
          'success': true,
          'total_recordings': voiceRecordings.length,
        },
      );

      _logger.info(
        'Voice recording added to note',
        data: {
          'note_id': updatedNote.id,
          'total_recordings': voiceRecordings.length,
        },
      );

      return updatedNote;
    } catch (e) {
      _logger.error('Failed to add voice recording to note', error: e);

      _analytics.endTiming(
        'voice_recording_add_to_note',
        properties: {
          'success': false,
          'error': e.toString(),
        },
      );

      return null;
    }
  }

  /// Format duration in seconds to human-readable format (e.g., "2:30")
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Format date to readable format (e.g., "Nov 22, 2025 at 14:30")
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$month $day, $year at $hour:$minute';
  }

  /// Get current platform for analytics
  String _getPlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
