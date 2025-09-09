import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/repository/notes_repository.dart';

abstract class NotesCapturePort {
  Future<String> createEncryptedNote({
    required String title,
    required String body,
    required Map<String, dynamic> metadataJson,
    List<String> tags,
  });
}

class ClipperInboxService {
  ClipperInboxService({
    required SupabaseClient supabase, 
    required NotesCapturePort notesPort,
    required IncomingMailFolderManager folderManager,
    required NotesRepository repository,
  }) : _supabase = supabase,
       _notesPort = notesPort,
       _folderManager = folderManager,
       _repository = repository;

  final SupabaseClient _supabase;
  final NotesCapturePort _notesPort;
  final IncomingMailFolderManager _folderManager;
  final NotesRepository _repository;
  Timer? _timer;

  void start() {
    stop();
    unawaited(processOnce());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(processOnce()));
  }

  void stop() => _timer?.cancel();

  Future<void> processOnce() async {
    try {
      final rows = await _supabase
          .from('clipper_inbox')
          .select()
          .eq('source_type', 'email_in')
          .order('created_at', ascending: true) as List<Map<String, dynamic>>;

      for (final row in rows) {
        await _handleRow(row);
      }
    } catch (e, st) {
      debugPrint('clipper inbox processing error: $e');
      debugPrint('$st');
    }
  }

  Future<void> _handleRow(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final payload = Map<String, dynamic>.from(row['payload_json'] as Map);

    try {
      // Extract fields from payload
      final from = (payload['from'] as String?)?.trim() ?? 'Unknown';
      final subject = (payload['subject'] as String?)?.trim() ?? 'Email Note';
      final text = (payload['text'] as String?)?.trim() ?? '';
      final html = (payload['html'] as String?);
      final to = (payload['to'] as String?)?.trim();
      final receivedAt = (payload['received_at'] as String?)?.trim() 
          ?? DateTime.now().toIso8601String();

      // Build note body (plain text + footer)
      final body = StringBuffer();
      if (text.isNotEmpty) {
        body.write(text);
      }
      body.writeln('\n\n---');
      body.writeln('From: $from');
      body.writeln('Received: $receivedAt');

      // Build metadata map for encrypted properties
      final metadata = <String, dynamic>{
        'source': 'email_in',
        'from_email': from,
        'received_at': receivedAt,
        if (to != null) 'to': to,
        if (payload['message_id'] != null) 'message_id': payload['message_id'],
        if (html != null) 'original_html': html,
        if (payload['attachments'] != null) 'attachments': payload['attachments'],
      };

      // Check if the email has attachments
      final hasAttachments = (payload['attachments']?['count'] ?? 0) > 0;
      
      // Build tags list - always include 'Email', add 'Attachment' if needed
      final tags = <String>['Email'];
      if (hasAttachments) {
        tags.add('Attachment');
      }
      
      // Logging before processing
      debugPrint('[email_in] processing row=$id subject="$subject" from="$from"');
      debugPrint('[email_in] metadata keys: ${metadata.keys.join(', ')}');
      debugPrint('[email_in] attachments: $hasAttachments, tags: ${tags.join(', ')}');

      // Delegate to the same encryption + save path used by Editor V2
      final noteId = await _notesPort.createEncryptedNote(
        title: subject.isEmpty ? 'Email Note' : subject,
        body: body.toString().trimRight(),
        metadataJson: metadata,
        tags: tags,
      );

      // Add note to Incoming Mail folder
      try {
        await _folderManager.addNoteToIncomingMail(noteId);
      } catch (e) {
        debugPrint('[email_in] Failed to add note to folder: $e');
        // Continue even if folder assignment fails
      }

      // Logging after success
      debugPrint('[email_in] processed row=$id -> note=$noteId');

      // Only delete after successful save and folder assignment
      await _supabase.from('clipper_inbox').delete().eq('id', id);
    } catch (e, st) {
      debugPrint('[email_in] failed to process row $id: $e');
      debugPrint('$st');
      // keep row for retry
    }
  }
}
