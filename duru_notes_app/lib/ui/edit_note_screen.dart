import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';



import 'package:duru_notes_app/core/parser/note_block_parser.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/models/note_block.dart';
import 'package:duru_notes_app/services/analytics/analytics_service.dart';
import 'package:duru_notes_app/services/analytics/analytics_sentry.dart';
import 'package:duru_notes_app/ui/home_screen.dart';



// Kamera ile OCR
import 'package:duru_notes_app/services/ocr_service.dart';
// Voice transcription
import 'package:duru_notes_app/services/voice_transcription_service.dart';
import 'package:duru_notes_app/services/audio_recording_service.dart';
import 'package:duru_notes_app/services/attachment_service.dart';
// Reminders
import 'package:duru_notes_app/services/reminder_service.dart';
import 'package:duru_notes_app/services/advanced_reminder_service.dart';
import 'package:duru_notes_app/ui/reminders_screen.dart';
import 'package:duru_notes_app/ui/widgets/block_editor.dart';

/// Block tabanlı not düzenleme ekranı.
class EditNoteScreen extends ConsumerStatefulWidget {
  const EditNoteScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialBody,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;

  @override
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen> {
  late final TextEditingController _title;
  late List<NoteBlock> _blocks;
  bool _preview = false;
  bool _hasUnsavedChanges = false;
  Timer? _autosaveTimer;
  
  // Voice transcription state
  VoiceTranscriptionService? _voiceService;
  AudioRecordingService? _audioService;
  bool _isRecording = false;
  String _liveTranscript = '';
  bool _saveAudioAttachment = false;
  
  // Reminder state
  List<NoteReminder> _reminders = [];
  ReminderService? _reminderService;
  AdvancedReminderService? _advancedReminderService;



  // Backlink sorgusunu her tuş vuruşunda değil, debounce ile tetikle
  Timer? _backlinkDebounce;
  Future<List<BacklinkPair>>? _backlinksFuture;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    final body = widget.initialBody ?? '';
    final parsed = parseMarkdownToBlocks(body);
    _blocks = parsed.isNotEmpty
        ? parsed
        : [const NoteBlock(type: NoteBlockType.paragraph, data: '')];

    // Track note screen view
    final isNewNote = widget.noteId == null;
    analytics.screen('EditNoteScreen', properties: {
      'is_new_note': isNewNote,
      'has_initial_content': body.isNotEmpty,
      'initial_block_count': _blocks.length,
    });
    
    if (isNewNote) {
      analytics.event(AnalyticsEvents.noteCreate, properties: {
        'trigger': 'screen_opened',
        'has_initial_content': body.isNotEmpty,
      });
    } else {
      analytics.event(AnalyticsEvents.noteView, properties: {
        'note_id': widget.noteId,
        'content_length': body.length > 0 ? 'has_content' : 'empty',
      });
    }
    
    logger.breadcrumb('EditNoteScreen opened', data: {
      'is_new_note': isNewNote,
      'note_id': widget.noteId,
    });

    // İlk backlink sorgusu (yalnızca var olan notlarda anlamlı ama zararsız)
    final db = ref.read(dbProvider);
    final initTitle =
        _title.text.trim().isEmpty ? '(untitled)' : _title.text.trim();
    _backlinksFuture = db.backlinksWithSources(initTitle);
    
    // Initialize voice services
    _voiceService = VoiceTranscriptionService();
    _audioService = AudioRecordingService();
    
    // Initialize reminder services
    _reminderService = ref.read(reminderServiceProvider);
    _advancedReminderService = ref.read(advancedReminderServiceProvider);
    
    // Load existing reminders for this note
    if (widget.noteId != null) {
      _loadExistingReminders();
    }
  }

  @override
  void dispose() {
    _backlinkDebounce?.cancel();
    _autosaveTimer?.cancel();
    _title.dispose();
    
    // Dispose voice services
    _voiceService?.dispose();
    _audioService?.dispose();
    
    super.dispose();
  }

  void _scheduleBacklinksRecalc() {
    _backlinkDebounce?.cancel();
    _backlinkDebounce = Timer(const Duration(milliseconds: 600), () {
      final db = ref.read(dbProvider);
      final t = _title.text.trim().isEmpty ? '(untitled)' : _title.text.trim();
      if (mounted) {
        setState(() {
          _backlinksFuture = db.backlinksWithSources(t);
        });
      }
    });
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    }
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), () {
      if (_hasUnsavedChanges) {
        _saveOrUpdate(context, showSuccess: false);
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _saveOrUpdate(context);
      return true;
    }
    
    return result == false;
  }

  Future<void> _saveOrUpdate(BuildContext context, {bool showSuccess = true}) async {
    final repo = ref.read(repoProvider);
    final sync = ref.read(syncProvider);
    final messenger = ScaffoldMessenger.of(context);
    final bodyMarkdown = blocksToMarkdown(_blocks);
    
    // Track save attempt
    final isNewNote = widget.noteId == null;
    analytics.startTiming('note_save');
    
    try {
      await repo.createOrUpdate(
        title: _title.text.trim(),
        body: bodyMarkdown,
        id: widget.noteId,
      );
      
      // Track successful save
      final metadata = AnalyticsHelper.getNoteMetadata(bodyMarkdown);
      analytics.endTiming('note_save', properties: {
        'success': true,
        'is_new_note': isNewNote,
        'has_title': _title.text.trim().isNotEmpty,
        'block_count': _blocks.length,
        ...metadata,
      });
      
      analytics.event(isNewNote ? AnalyticsEvents.noteCreate : AnalyticsEvents.noteEdit, properties: {
        'note_id': widget.noteId ?? 'new',
        'save_trigger': showSuccess ? 'manual' : 'autosave',
        'has_title': _title.text.trim().isNotEmpty,
        'block_count': _blocks.length,
        ...metadata,
      });
      
      logger.info('Note saved successfully', data: {
        'is_new_note': isNewNote,
        'note_id': widget.noteId,
        'character_count': bodyMarkdown.length,
        'block_count': _blocks.length,
      });
      
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
      if (!context.mounted) return;
      if (showSuccess) {
        Navigator.of(context).pop(true);
      }

      // Sync'i arka planda tetikle (başarısız olursa logla)
      if (sync != null) {
        unawaited(
          sync.syncNow().catchError((Object e, _) {
            debugPrint('Sync error after save: $e');
          }),
        );
      }
    } on Object catch (e) {
      // Track save failure
      analytics.endTiming('note_save', properties: {
        'success': false,
        'error_type': e.runtimeType.toString(),
        'is_new_note': isNewNote,
      });
      
      analytics.trackError('Note save failed', context: 'EditNoteScreen', properties: {
        'is_new_note': isNewNote,
        'note_id': widget.noteId,
        'error_type': e.runtimeType.toString(),
      });
      
      logger.error('Note save failed', error: e, data: {
        'is_new_note': isNewNote,
        'note_id': widget.noteId,
      });
      
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _deleteNote(BuildContext context) async {
    final repo = ref.read(repoProvider);
    final sync = ref.read(syncProvider);
    final messenger = ScaffoldMessenger.of(context);
    final noteId = widget.noteId;
    if (noteId == null) return;
    try {
      await repo.delete(noteId);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
      if (sync != null) {
        unawaited(
          sync.syncNow().catchError((Object e, _) {
            debugPrint('Sync error after delete: $e');
          }),
        );
      }
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  /// Kamera ile belge tara ve metni yeni bir paragraf blok olarak ekle.
  Future<void> _scanDocument(BuildContext context) async {
    final ocr = OCRService();
    try {
      final text = await ocr.pickAndScanImage();
      if (text == null || text.trim().isEmpty) return;
      if (mounted) {
        setState(() {
          _blocks.add(
            NoteBlock(type: NoteBlockType.paragraph, data: text.trim()),
          );
        });
      }
    } catch (e) {
      debugPrint('OCR scan failed: $e');
    } finally {
      ocr.dispose();
    }
  }

  // ----------------------
  // Reminder methods
  // ----------------------
  
  /// Load existing reminders for this note
  Future<void> _loadExistingReminders() async {
    if (widget.noteId == null || _advancedReminderService == null) return;
    
    try {
      final reminders = await _advancedReminderService!.getRemindersForNote(widget.noteId!);
      if (mounted) {
        setState(() {
          _reminders = reminders;
        });
      }
    } catch (e, stack) {
      logger.error('Failed to load reminders', error: e, stackTrace: stack);
    }
  }
  
  /// Open the reminders management screen
  void _openRemindersScreen() {
    // Save the note first if it's new
    if (widget.noteId == null) {
      _saveOrUpdate(context, showSuccess: false).then((_) {
        if (widget.noteId != null && mounted) {
          _navigateToRemindersScreen();
        }
      });
    } else {
      _navigateToRemindersScreen();
    }
  }
  
  void _navigateToRemindersScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RemindersScreen(
          noteId: widget.noteId!,
          noteTitle: _title.text.trim(),
          noteBody: blocksToMarkdown(_blocks),
        ),
      ),
    ).then((_) {
      // Reload reminders when coming back
      _loadExistingReminders();
    });
  }

  /// Show date-time picker for setting reminder (legacy method)
  Future<void> _setReminder() async {
    if (_reminderService == null) return;
    
    // For new notes, save first to get an ID
    if (widget.noteId == null) {
      await _saveOrUpdate(context, showSuccess: false);
      if (widget.noteId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please save the note first')),
          );
        }
        return;
      }
    }
    
    try {
      // Check and request permissions
      if (!await _reminderService!.hasPermissions()) {
        final granted = await _reminderService!.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Notification permission is required for reminders'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    // TODO: Open app settings
                  },
                ),
              ),
            );
          }
          return;
        }
      }
      
      // Show date picker
      final now = DateTime.now();
      final initialDate = _currentReminder?.remindAt.toLocal() ?? now.add(const Duration(hours: 1));
      
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: initialDate.isAfter(now) ? initialDate : now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      
      if (selectedDate == null || !mounted) return;
      
      // Show time picker
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      
      if (selectedTime == null || !mounted) return;
      
      // Combine date and time
      final reminderDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      
      // Check if time is in the future
      if (reminderDateTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a time in the future')),
        );
        return;
      }
      
      // Save reminder to database
      final db = ref.read(appDbProvider);
      await db.upsertReminder(
        noteId: widget.noteId!,
        remindAtUtc: reminderDateTime.toUtc(),
        timeZone: now.timeZoneName,
      );
      
      // Schedule notification
      final title = _title.text.trim().isNotEmpty ? _title.text.trim() : 'Note Reminder';
      final success = await _reminderService!.schedule(
        noteId: widget.noteId!,
        remindAtUtc: reminderDateTime.toUtc(),
        title: 'Note Reminder',
        body: title,
      );
      
      if (success) {
        // Reload reminder state
        await _loadExistingReminder();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder set for ${_formatReminderTime(reminderDateTime)}'),
            ),
          );
        }
        
        analytics.event(AnalyticsEvents.reminderSet, properties: {
          'hours_from_now': reminderDateTime.difference(now).inHours,
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set reminder')),
          );
        }
      }
      
    } catch (e, stack) {
      logger.error('Failed to set reminder', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to set reminder')),
        );
      }
    }
  }
  
  /// Remove the current reminder
  Future<void> _removeReminder() async {
    if (widget.noteId == null || _reminderService == null || _currentReminder == null) return;
    
    try {
      // Cancel notification
      await _reminderService!.cancel(widget.noteId!);
      
      // Remove from database
      final db = ref.read(appDbProvider);
      await db.deleteReminder(widget.noteId!);
      
      // Update state
      if (mounted) {
        setState(() {
          _currentReminder = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder removed')),
        );
      }
      
      analytics.event(AnalyticsEvents.reminderRemoved);
      
    } catch (e, stack) {
      logger.error('Failed to remove reminder', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove reminder')),
        );
      }
    }
  }
  
  /// Format reminder time for display
  String _formatReminderTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    if (reminderDate == today) {
      return 'Today $timeStr';
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow $timeStr';
    } else {
      return '${dateTime.day}/${dateTime.month} $timeStr';
    }
  }
  
  /// Show options for existing reminder (Change or Remove)
  void _showReminderOptions() {
    if (_currentReminder == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Reminder set for ${_formatReminderTime(_currentReminder!.remindAt.toLocal())}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              leading: const Icon(Icons.notifications_active),
            ),
            const Divider(),
            ListTile(
              title: const Text('Change time'),
              leading: const Icon(Icons.edit),
              onTap: () {
                Navigator.of(context).pop();
                _setReminder();
              },
            ),
            ListTile(
              title: const Text('Remove reminder'),
              leading: const Icon(Icons.notifications_off),
              onTap: () {
                Navigator.of(context).pop();
                _removeReminder();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Toggle voice recording on/off
  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopVoiceRecording();
    } else {
      await _startVoiceRecording();
    }
  }

  /// Start voice recording and transcription
  Future<void> _startVoiceRecording() async {
    if (_voiceService == null) return;
    
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // Generate session ID for linking voice and audio
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Start audio recording if enabled
      bool audioStarted = false;
      if (_saveAudioAttachment && _audioService != null) {
        audioStarted = await _audioService!.startRecording(sessionId: sessionId);
        if (!audioStarted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to start audio recording')),
          );
        }
      }
      
      // Start voice transcription
      final voiceStarted = await _voiceService!.start(
        onPartial: _handlePartialTranscript,
        onFinal: _handleFinalTranscript,
        onError: _handleTranscriptError,
      );
      
      if (voiceStarted) {
        if (mounted) {
          setState(() {
            _isRecording = true;
            _liveTranscript = '';
          });
        }
        
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mic, color: Colors.red),
                const SizedBox(width: 8),
                Text(_saveAudioAttachment && audioStarted
                    ? 'Recording voice with audio...'
                    : 'Recording voice...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        
        analytics.featureUsed('voice_transcription', properties: {
          'has_audio_recording': _saveAudioAttachment && audioStarted,
          'session_id': sessionId,
        });
      } else {
        // Stop audio recording if voice failed
        if (audioStarted && _audioService != null) {
          await _audioService!.cancelRecording();
        }
        
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to start voice recording')),
        );
      }
    } catch (e) {
      logger.error('Failed to start voice recording', error: e);
      messenger.showSnackBar(
        SnackBar(content: Text('Error starting voice recording: $e')),
      );
    }
  }

  /// Stop voice recording and transcription
  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;
    
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // Stop voice transcription
      await _voiceService?.stop();
      
      // Stop audio recording and handle attachment
      if (_saveAudioAttachment && _audioService != null) {
        final audioPath = await _audioService!.stopRecording();
        if (audioPath != null) {
          await _processAudioAttachment(audioPath);
        }
      }
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _liveTranscript = '';
        });
      }
      
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Voice recording stopped'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      logger.error('Failed to stop voice recording', error: e);
      messenger.showSnackBar(
        SnackBar(content: Text('Error stopping voice recording: $e')),
      );
    }
  }

  /// Cancel voice recording
  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording) return;
    
    try {
      await _voiceService?.cancel();
      await _audioService?.cancelRecording();
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _liveTranscript = '';
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recording cancelled'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      logger.error('Failed to cancel voice recording', error: e);
    }
  }

  /// Handle partial transcription results
  void _handlePartialTranscript(String text) {
    if (mounted) {
      setState(() {
        _liveTranscript = text;
      });
    }
  }

  /// Handle final transcription results
  void _handleFinalTranscript(String text) {
    if (text.trim().isEmpty) return;
    
    if (mounted) {
      setState(() {
        // Add final transcription as a new paragraph block
        _blocks.add(
          NoteBlock(type: NoteBlockType.paragraph, data: text.trim()),
        );
        _liveTranscript = '';
      });
      _markAsChanged();
    }
    
    logger.info('Voice transcription completed', data: {
      'textLength': text.length,
      'wordCount': text.split(' ').where((w) => w.isNotEmpty).length,
    });
  }

  /// Handle transcription errors
  void _handleTranscriptError(String error) {
    logger.error('Voice transcription error: $error');
    
    if (mounted) {
      setState(() {
        _isRecording = false;
        _liveTranscript = '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice recording error: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _startVoiceRecording,
          ),
        ),
      );
    }
  }

  /// Process audio recording as attachment
  Future<void> _processAudioAttachment(String audioPath) async {
    try {
      final attachmentService = ref.read(attachmentServiceProvider);
      final audioBytes = await _audioService!.getRecordingBytes(audioPath);
      
      if (audioBytes == null) {
        logger.error('Failed to read audio recording bytes');
        return;
      }
      
      final filename = _audioService!.getSuggestedFilename(prefix: 'voice_note');
      
      // Upload audio to Supabase Storage
      final attachmentBlockData = await attachmentService.uploadFromBytes(
        bytes: audioBytes, 
        filename: filename,
      );
      
      if (attachmentBlockData != null) {
        // Add attachment block
        if (mounted) {
          setState(() {
            _blocks.add(
              NoteBlock(
                type: NoteBlockType.attachment,
                data: attachmentBlockData,
              ),
            );
          });
          _markAsChanged();
        }
        
        logger.info('Audio attachment uploaded successfully', data: {
          'filename': filename,
          'sizeBytes': audioBytes.length,
        });
        
        analytics.featureUsed('voice_audio_attachment', properties: {
          'file_size_bytes': audioBytes.length,
          'filename': filename,
        });
      } else {
        logger.error('Failed to upload audio attachment');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload audio attachment')),
          );
        }
      }
      
      // Clean up temporary file
      await _audioService!.deleteRecording(audioPath);
    } catch (e) {
      logger.error('Failed to process audio attachment', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save audio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.noteId == null ? 'New note' : 'Edit note'}${_hasUnsavedChanges ? ' •' : ''}${_isRecording ? ' 🎤' : ''}',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Scan Document',
              onPressed: mounted ? () => _scanDocument(context) : null,
            ),
            IconButton(
              icon: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: _isRecording ? Colors.red : null,
              ),
              tooltip: _isRecording ? 'Stop Recording' : 'Start Voice Recording',
              onPressed: mounted ? _toggleVoiceRecording : null,
            ),
            if (_isRecording)
              IconButton(
                icon: const Icon(Icons.stop),
                tooltip: 'Cancel Recording',
                onPressed: mounted ? _cancelVoiceRecording : null,
              ),
            // Bell icon for reminders
            IconButton(
              icon: Stack(
                children: [
                  Icon(
                    _reminders.isNotEmpty ? Icons.notifications_active : Icons.notifications_none,
                    color: _reminders.isNotEmpty ? Colors.orange : null,
                  ),
                  if (_reminders.length > 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_reminders.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: _reminders.isEmpty 
                  ? 'Set reminder' 
                  : '${_reminders.length} reminder${_reminders.length == 1 ? '' : 's'} set',
              onPressed: mounted ? _openRemindersScreen : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: (widget.noteId == null || !mounted) ? null : () => _deleteNote(context),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle_audio') {
                  setState(() {
                    _saveAudioAttachment = !_saveAudioAttachment;
                  });
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_audio',
                  child: Row(
                    children: [
                      Icon(_saveAudioAttachment ? Icons.check_box : Icons.check_box_outline_blank),
                      const SizedBox(width: 8),
                      const Text('Save audio attachment'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (_) {
                    if (mounted) {
                      setState(() {});            // UI'daki başlık vs. güncellensin
                    }
                    _scheduleBacklinksRecalc(); // backlink sorgusunu debounce et
                    _markAsChanged();           // Mark as changed for autosave
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Preview'),
                    Switch(
                      value: _preview,
                      onChanged: (v) {
                        setState(() => _preview = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Live transcript display
                if (_isRecording && _liveTranscript.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.mic,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Live transcript:',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _liveTranscript,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(minHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _preview
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: MarkdownBody(
                            data: blocksToMarkdown(_blocks),
                            onTapLink: (text, href, title) async {
                              if (href == null || href.isEmpty) return;
                              final uri = Uri.tryParse(href);
                              if (uri == null) return;
                              final ok = await launchUrl(uri);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Could not open $href')),
                                );
                              }
                            },
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: BlockEditor(
                            blocks: _blocks,
                            onChanged: (blocks) {
                              setState(() => _blocks = blocks);
                              _markAsChanged();
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: mounted ? () => _saveOrUpdate(context) : null,
                    child: const Text('Save'),
                  ),
                ),
                if (widget.noteId != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Backlinks',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<BacklinkPair>>(
                    future: _backlinksFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      if (!snap.hasData) return const SizedBox.shrink();
                      final items = snap.data!;
                      if (items.isEmpty) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No backlinks'),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (context, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final l = item.link;
                          final src = item.source;
                          final title = (src == null || src.title.trim().isEmpty)
                              ? l.sourceId
                              : src.title.trim();
                          return ListTile(
                            dense: true,
                            title: Text(title, textDirection: TextDirection.ltr),
                            subtitle: Text('links to: ${l.targetTitle}',
                                textDirection: TextDirection.ltr),
                            onTap: () async {
                              final db = ref.read(dbProvider);
                              final existing =
                                  src ?? await db.findNote(l.sourceId);
                              if (!context.mounted) return;
                              if (existing != null) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => EditNoteScreen(
                                      noteId: existing.id,
                                      initialTitle: existing.title,
                                      initialBody: existing.body,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 100), // Extra padding for scrolling
              ],
            ),
          ),
        ),
      ),
    );
  }
}
