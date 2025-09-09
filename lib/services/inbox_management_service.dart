import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';

/// Service for managing the inbound email inbox functionality
/// This service handles fetching, converting, and managing emails from the clipper_inbox
class InboxManagementService {
  final SupabaseClient _supabase;
  final EmailAliasService _aliasService;
  final NotesRepository? _notesRepository;
  final IncomingMailFolderManager? _folderManager;
  
  InboxManagementService({
    required SupabaseClient supabase,
    required EmailAliasService aliasService,
    NotesRepository? notesRepository,
    IncomingMailFolderManager? folderManager,
  }) : _supabase = supabase,
       _aliasService = aliasService,
       _notesRepository = notesRepository,
       _folderManager = folderManager;
  
  /// Get the full inbound email address for the user (delegates to EmailAliasService)
  Future<String?> getUserInboundEmail() async {
    return _aliasService.getFullEmailAddress();
  }
  
  /// Fetch inbound emails from clipper_inbox
  Future<List<InboundEmail>> getInboundEmails({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('clipper_inbox')
          .select()
          .eq('source_type', 'email_in')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return (response as List)
          .map((json) => InboundEmail.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error fetching inbound emails: $e');
      debugPrint('$stackTrace');
      return [];
    }
  }
  
  /// Delete an inbound email from the inbox
  Future<bool> deleteInboundEmail(String emailId) async {
    try {
      await _supabase
          .from('clipper_inbox')
          .delete()
          .eq('id', emailId);
      
      debugPrint('[InboxManagementService] Deleted email: $emailId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error deleting inbound email $emailId: $e');
      debugPrint('$stackTrace');
      return false;
    }
  }
  
  /// Convert an inbound email to a note using the NotesRepository
  Future<String?> convertEmailToNote(InboundEmail email) async {
    if (_notesRepository == null) {
      debugPrint('[InboxManagementService] NotesRepository not available for conversion');
      return null;
    }
    
    try {
      // Extract content from the email
      final title = email.subject ?? 'Email from ${email.from}';
      String body = email.text ?? '';
      
      // If no text content, try to extract from HTML
      if (body.isEmpty && email.html != null) {
        // Basic HTML to text conversion (strip tags)
        body = email.html!
            .replaceAll(RegExp(r'<br\s*/?>'), '\n')
            .replaceAll(RegExp(r'<p\s*>'), '\n')
            .replaceAll(RegExp(r'</p>'), '\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll(RegExp(r'\n\n+'), '\n\n')
            .trim();
      }
      
      // Add email metadata as tags
      final tags = <String>['#Email'];
      if (email.hasAttachments) {
        tags.add('#Attachment');
      }
      final bodyWithTags = '$body\n\n${tags.join(' ')}';
      
      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'email_inbox',
        'from': email.from,
        'to': email.to,
        'received_at': email.createdAt.toIso8601String(),
        'original_id': email.id,
        'message_id': email.messageId,
      };
      
      // Add attachments metadata if present
      if (email.payloadJson['attachments'] != null) {
        metadata['attachments'] = email.payloadJson['attachments'];
      }
      
      // Create the note
      final noteId = await _notesRepository.createOrUpdate(
        title: title,
        body: bodyWithTags,
        metadataJson: metadata,
      );
      
      // Add to Incoming Mail folder if folder manager is available
      if (_folderManager != null && noteId.isNotEmpty) {
        try {
          await _folderManager.addNoteToIncomingMail(noteId);
          debugPrint('[InboxManagementService] Added note to Incoming Mail folder');
        } catch (e) {
          debugPrint('[InboxManagementService] Failed to add note to folder: $e');
          // Continue even if folder assignment fails
        }
      }
      
      // Delete from inbox after successful conversion
      await deleteInboundEmail(email.id);
      
      debugPrint('[InboxManagementService] Converted email ${email.id} to note $noteId');
      return noteId;
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error converting email to note: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }
  
  /// Get attachment information for an email
  List<EmailAttachment> getAttachments(InboundEmail email) {
    final attachments = email.payloadJson['attachments'];
    if (attachments == null || attachments['files'] == null) {
      return [];
    }
    
    try {
      return (attachments['files'] as List)
          .map((file) => EmailAttachment.fromJson(file as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[InboxManagementService] Error parsing attachments: $e');
      return [];
    }
  }
  
  /// Generate a signed URL for a private attachment
  Future<String?> getAttachmentUrl(String filePath) async {
    try {
      // Generate a signed URL that expires in 1 hour
      final response = await _supabase.storage
          .from('inbound-attachments')
          .createSignedUrl(filePath, 3600);
      
      debugPrint('[InboxManagementService] Generated signed URL for: $filePath');
      return response;
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error getting attachment URL for $filePath: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }
}

/// Model for inbound email from clipper_inbox
class InboundEmail {
  final String id;
  final String userId;
  final Map<String, dynamic> payloadJson;
  final DateTime createdAt;
  
  InboundEmail({
    required this.id,
    required this.userId,
    required this.payloadJson,
    required this.createdAt,
  });
  
  factory InboundEmail.fromJson(Map<String, dynamic> json) {
    return InboundEmail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      payloadJson: json['payload_json'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  // Convenience getters for common fields
  String? get to => payloadJson['to'] as String?;
  String? get from => payloadJson['from'] as String?;
  String? get subject => payloadJson['subject'] as String?;
  String? get text => payloadJson['text'] as String?;
  String? get html => payloadJson['html'] as String?;
  String? get messageId => payloadJson['message_id'] as String?;
  
  bool get hasAttachments {
    final attachments = payloadJson['attachments'];
    return attachments != null && 
           attachments['count'] != null && 
           (attachments['count'] as int) > 0;
  }
  
  int get attachmentCount {
    final attachments = payloadJson['attachments'];
    return (attachments?['count'] as int?) ?? 0;
  }
}

/// Model for email attachment metadata
class EmailAttachment {
  final String filename;
  final String type;
  final int size;
  final String? url;
  
  EmailAttachment({
    required this.filename,
    required this.type,
    required this.size,
    this.url,
  });
  
  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      filename: json['filename'] as String? ?? 'unnamed',
      type: json['type'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      url: json['url'] as String?,
    );
  }
  
  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  String get typeCategory {
    if (type.startsWith('image/')) return 'image';
    if (type.startsWith('video/')) return 'video';
    if (type.startsWith('audio/')) return 'audio';
    if (type.contains('pdf')) return 'pdf';
    if (type.contains('word') || type.contains('document')) return 'document';
    if (type.contains('sheet') || type.contains('excel')) return 'spreadsheet';
    if (type.contains('presentation') || type.contains('powerpoint')) return 'presentation';
    if (type.startsWith('text/')) return 'text';
    return 'file';
  }
}
