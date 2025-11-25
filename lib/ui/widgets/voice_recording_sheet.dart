import 'dart:async';

import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/audio_recording_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/voice_notes_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bottom sheet for recording voice notes
///
/// States: idle → recording → stopped (+ title) → uploading → complete
class VoiceRecordingSheet extends ConsumerStatefulWidget {
  const VoiceRecordingSheet({super.key, this.folderId});

  final String? folderId;

  @override
  ConsumerState<VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends ConsumerState<VoiceRecordingSheet> {
  _RecordingState _state = _RecordingState.idle;
  String? _errorMessage;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;
  final TextEditingController _titleController = TextEditingController(text: 'Voice note');

  @override
  void initState() {
    super.initState();
    // Select the default title for quick editing
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    // Check and request permission
    final hasPermission = await audioService.hasPermission();
    if (!hasPermission) {
      final granted = await audioService.requestPermission();
      if (!granted) {
        setState(() {
          _errorMessage = 'Microphone permission is required to record voice notes';
        });
        _showPermissionDialog();
        return;
      }
    }

    // Start recording
    final success = await audioService.startRecording();
    if (success) {
      setState(() {
        _state = _RecordingState.recording;
        _recordingDuration = Duration.zero;
        _errorMessage = null;
      });

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _recordingDuration = audioService.currentRecordingDuration ?? Duration.zero;
          });
        }
      });
    } else {
      setState(() {
        _errorMessage = 'Failed to start recording. Please try again.';
      });
    }
  }

  Future<void> _stopRecording() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    _durationTimer?.cancel();

    final path = await audioService.stopRecording();
    if (path != null) {
      setState(() {
        _state = _RecordingState.stopped;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Failed to save recording';
        _state = _RecordingState.idle;
      });
    }
  }

  Future<void> _cancelRecording() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    _durationTimer?.cancel();

    await audioService.cancelRecording();
    Navigator.of(context).pop();
  }

  Future<void> _saveVoiceNote() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a title for your voice note';
      });
      return;
    }

    // DEBUG: Log voice note save start
    print('[VOICE_NOTE_DEBUG] ========== STARTING VOICE NOTE SAVE ==========');

    setState(() {
      _state = _RecordingState.uploading;
      _errorMessage = null;
    });

    final audioService = ref.read(audioRecordingServiceProvider);
    final voiceNotesService = ref.read(voiceNotesServiceProvider);

    try {
      // Upload recording
      print('[VOICE_NOTE_DEBUG] Calling audioService.finalizeAndUpload()...');
      final result = await audioService.finalizeAndUpload();
      print('[VOICE_NOTE_DEBUG] Upload result: ${result != null ? "SUCCESS" : "NULL (FAILED)"}');

      if (result == null) {
        print('[VOICE_NOTE_DEBUG] ERROR: finalizeAndUpload() returned null');
        setState(() {
          _errorMessage =
              'Failed to upload recording. Please check your connection.';
          _state = _RecordingState.stopped;
        });
        return;
      }

      print('[VOICE_NOTE_DEBUG] Upload successful! URL: ${result.url}');

      // Create voice note
      final note = await voiceNotesService.createVoiceNote(
        recording: result,
        title: title,
        folderId: widget.folderId,
      );

      if (note == null) {
        setState(() {
          _errorMessage = 'Failed to create voice note';
          _state = _RecordingState.stopped;
        });
        return;
      }

      // Success - close sheet
      if (mounted) {
        Navigator.of(context).pop(note);
      }
    } catch (e, stackTrace) {
      print('[VOICE_NOTE_DEBUG] ========== EXCEPTION CAUGHT ==========');
      print('[VOICE_NOTE_DEBUG] Error type: ${e.runtimeType}');
      print('[VOICE_NOTE_DEBUG] Error message: $e');
      print('[VOICE_NOTE_DEBUG] Stack trace:');
      print(stackTrace);
      print('[VOICE_NOTE_DEBUG] ==========================================');

      setState(() {
        _errorMessage =
            'Failed to upload recording. Please check your connection.';
        _state = _RecordingState.stopped;
      });
    }
  }

  Future<void> _reRecord() async {
    final audioService = ref.read(audioRecordingServiceProvider);
    await audioService.cancelRecording();

    setState(() {
      _state = _RecordingState.idle;
      _recordingDuration = Duration.zero;
      _errorMessage = null;
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Duru Notes needs access to your microphone to record voice notes. '
          'Please enable microphone access in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // Use max height so we can place scrollable content below the header
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Voice Note',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Content based on state (scrollable to avoid overflow on small screens)
              Expanded(
                child: SingleChildScrollView(
                  child: _buildContent(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_state) {
      case _RecordingState.idle:
        return _buildIdleState(theme);
      case _RecordingState.recording:
        return _buildRecordingState(theme);
      case _RecordingState.stopped:
        return _buildStoppedState(theme);
      case _RecordingState.uploading:
        return _buildUploadingState(theme);
    }
  }

  Widget _buildIdleState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.mic,
          size: 80,
          color: theme.colorScheme.primary.withOpacity(0.5),
        ),
        const SizedBox(height: 24),
        Text(
          'Tap to start recording',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _startRecording,
          icon: const Icon(Icons.fiber_manual_record, size: 24),
          label: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text('Record', style: TextStyle(fontSize: 18)),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRecordingState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Pulsing recording indicator
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.error.withOpacity(0.1),
              ),
            ),
            Icon(
              Icons.mic,
              size: 60,
              color: theme.colorScheme.error,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _formatDuration(_recordingDuration),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Recording...',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: _cancelRecording,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStoppedState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title input
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'Enter a title for this voice note',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),

        // Recording info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Recording complete: ${_formatDuration(_recordingDuration)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reRecord,
                icon: const Icon(Icons.refresh),
                label: const Text('Re-record'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saveVoiceNote,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUploadingState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Uploading voice note...',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

enum _RecordingState {
  idle,
  recording,
  stopped,
  uploading,
}
