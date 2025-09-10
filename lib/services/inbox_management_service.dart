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
  
  /// Fetch all clipper inbox items (both email and web clips)
  Future<List<InboxItem>> getClipperInboxItems({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('clipper_inbox')
          .select()
          .or('source_type.eq.email_in,source_type.eq.web')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return (response as List)
          .map((json) => InboxItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error fetching inbox items: $e');
      debugPrint('$stackTrace');
      return [];
    }
  }
  
  /// Fetch inbound emails from clipper_inbox (deprecated - use getClipperInboxItems)
  @Deprecated('Use getClipperInboxItems instead')
  Future<List<InboundEmail>> getInboundEmails({
    int limit = 50,
    int offset = 0,
  }) async {
    final items = await getClipperInboxItems(limit: limit, offset: offset);
    // Filter only email items and convert to InboundEmail for backward compatibility
    return items
        .where((item) => item.sourceType == 'email_in')
        .map((item) => InboundEmail(
              id: item.id,
              userId: item.userId,
              payloadJson: item.payloadJson,
              createdAt: item.createdAt,
            ))
        .toList();
  }
  
  /// Delete an inbox item (email or web clip)
  Future<bool> deleteInboxItem(String itemId) async {
    try {
      await _supabase
          .from('clipper_inbox')
          .delete()
          .eq('id', itemId);
      
      debugPrint('[InboxManagementService] Deleted inbox item: $itemId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error deleting inbox item $itemId: $e');
      debugPrint('$stackTrace');
      return false;
    }
  }
  
  /// Delete an inbound email from the inbox (deprecated - use deleteInboxItem)
  @Deprecated('Use deleteInboxItem instead')
  Future<bool> deleteInboundEmail(String emailId) async {
    return deleteInboxItem(emailId);
  }
  
  /// Convert an inbox item (email or web clip) to a note
  Future<String?> convertInboxItemToNote(InboxItem item) async {
    if (_notesRepository == null) {
      debugPrint('[InboxManagementService] NotesRepository not available for conversion');
      return null;
    }
    
    try {
      // Branch based on source type
      if (item.sourceType == 'email_in') {
        return await _convertEmailToNote(item);
      } else if (item.sourceType == 'web') {
        return await _convertWebClipToNote(item);
      } else {
        debugPrint('[InboxManagementService] Unknown source type: ${item.sourceType}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error converting item to note: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }
  
  /// Convert an inbound email to a note (deprecated - use convertInboxItemToNote)
  @Deprecated('Use convertInboxItemToNote instead')
  Future<String?> convertEmailToNote(InboundEmail email) async {
    final item = InboxItem(
      id: email.id,
      userId: email.userId,
      sourceType: 'email_in',
      payloadJson: email.payloadJson,
      createdAt: email.createdAt,
    );
    return convertInboxItemToNote(item);
  }
  
  Future<String?> _convertEmailToNote(InboxItem item) async {
    if (_notesRepository == null) {
      debugPrint('[InboxManagementService] NotesRepository not available for conversion');
      return null;
    }
    
    try {
      // Extract content from the email
      final title = item.subject ?? 'Email from ${item.from}';
      String body = item.text ?? '';
      
      // If no text content, try to extract from HTML
      if (body.isEmpty && item.html != null) {
        // Basic HTML to text conversion (strip tags)
        body = item.html!
            .replaceAll(RegExp(r'<br\s*/?>'), '\n')
            .replaceAll(RegExp(r'<p\s*>'), '\n')
            .replaceAll(RegExp(r'</p>'), '\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll(RegExp(r'\n\n+'), '\n\n')
            .trim();
      }
      
      // Add email metadata as tags
      final tags = <String>['#Email'];
      if (item.hasAttachments) {
        tags.add('#Attachment');
      }
      final bodyWithTags = '$body\n\n${tags.join(' ')}';
      
      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'email_inbox',
        'from': item.from,
        'to': item.to,
        'received_at': item.createdAt.toIso8601String(),
        'original_id': item.id,
        'message_id': item.messageId,
      };
      
      // Add attachments metadata if present
      if (item.payloadJson['attachments'] != null) {
        metadata['attachments'] = item.payloadJson['attachments'];
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
      await deleteInboxItem(item.id);
      
      debugPrint('[InboxManagementService] Converted email ${item.id} to note $noteId');
      return noteId;
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error converting email to note: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }
  
  Future<String?> _convertWebClipToNote(InboxItem item) async {
    try {
      // Extract content from the web clip
      final title = item.webTitle ?? 'Web Clip';
      final text = item.webText ?? '';
      final url = item.webUrl ?? '';
      
      // Build body with source reference
      final body = StringBuffer();
      if (text.isNotEmpty) {
        body.write(text);
      }
      body.writeln('\n\n---');
      body.writeln('Source: $url');
      if (item.webClippedAt != null) {
        body.writeln('Clipped: ${item.webClippedAt}');
      }
      
      // Add tags
      final tags = <String>['#Web'];
      final bodyWithTags = '${body.toString()}\n\n${tags.join(' ')}';
      
      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'web',
        'url': url,
        'clipped_at': item.webClippedAt ?? item.createdAt.toIso8601String(),
        'original_id': item.id,
      };
      
      // Add HTML content to metadata if present
      if (item.webHtml != null) {
        metadata['html'] = item.webHtml;
      }
      
      // Create the note
      final noteId = await _notesRepository!.createOrUpdate(
        title: title,
        body: bodyWithTags,
        metadataJson: metadata,
      );
      
      // Add to Incoming Mail folder (serves as unified inbox)
      if (_folderManager != null && noteId.isNotEmpty) {
        try {
          await _folderManager.addNoteToIncomingMail(noteId);
          debugPrint('[InboxManagementService] Added web clip to Incoming Mail folder');
        } catch (e) {
          debugPrint('[InboxManagementService] Failed to add web clip to folder: $e');
          // Continue even if folder assignment fails
        }
      }
      
      // Delete from inbox after successful conversion
      await deleteInboxItem(item.id);
      
      debugPrint('[InboxManagementService] Converted web clip ${item.id} to note $noteId');
      return noteId;
    } catch (e, stackTrace) {
      debugPrint('[InboxManagementService] Error converting web clip to note: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }
  
  /// Get attachment information for an inbox item (currently only emails have attachments)
  List<EmailAttachment> getAttachments(InboxItem item) {
    final attachments = item.payloadJson['attachments'];
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

/// Model for inbox items (email or web clips) from clipper_inbox
class InboxItem {
  final String id;
  final String userId;
  final String sourceType;
  final Map<String, dynamic> payloadJson;
  final DateTime createdAt;
  
  InboxItem({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.payloadJson,
    required this.createdAt,
  });
  
  factory InboxItem.fromJson(Map<String, dynamic> json) {
    return InboxItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sourceType: json['source_type'] as String,
      payloadJson: json['payload_json'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  // Common getters
  bool get isEmail => sourceType == 'email_in';
  bool get isWebClip => sourceType == 'web';
  
  // Email-specific getters
  String? get to => isEmail ? payloadJson['to'] as String? : null;
  String? get from => isEmail ? payloadJson['from'] as String? : null;
  String? get subject => isEmail ? payloadJson['subject'] as String? : null;
  String? get text => isEmail ? payloadJson['text'] as String? : null;
  String? get html => isEmail ? payloadJson['html'] as String? : null;
  String? get messageId => isEmail ? payloadJson['message_id'] as String? : null;
  
  // Web clip-specific getters
  String? get webTitle => isWebClip ? payloadJson['title'] as String? : null;
  String? get webText => isWebClip ? payloadJson['text'] as String? : null;
  String? get webUrl => isWebClip ? payloadJson['url'] as String? : null;
  String? get webHtml => isWebClip ? payloadJson['html'] as String? : null;
  String? get webClippedAt => isWebClip ? payloadJson['clipped_at'] as String? : null;
  
  // Display helpers
  String get displayTitle {
    if (isEmail) return subject ?? 'Email from ${from ?? "Unknown"}';
    if (isWebClip) return webTitle ?? 'Web Clip';
    return 'Unknown Item';
  }
  
  String get displaySubtitle {
    if (isEmail) return from ?? 'Unknown sender';
    if (isWebClip) {
      if (webUrl != null && webUrl!.isNotEmpty) {
        try {
          final uri = Uri.parse(webUrl!);
          return uri.host;
        } catch (_) {
          return webUrl!;
        }
      }
      return 'Web clip';
    }
    return '';
  }
  
  String? get displayText {
    if (isEmail) return text;
    if (isWebClip) return webText;
    return null;
  }
  
  bool get hasAttachments {
    if (!isEmail) return false;
    final attachments = payloadJson['attachments'];
    return attachments != null && 
           attachments['count'] != null && 
           (attachments['count'] as int) > 0;
  }
  
  int get attachmentCount {
    if (!isEmail) return 0;
    final attachments = payloadJson['attachments'];
    return (attachments?['count'] as int?) ?? 0;
  }
}

/// Model for inbound email from clipper_inbox (kept for backward compatibility)
@Deprecated('Use InboxItem instead')
class InboundEmail extends InboxItem {
  InboundEmail({
    required String id,
    required String userId,
    required Map<String, dynamic> payloadJson,
    required DateTime createdAt,
  }) : super(
          id: id,
          userId: userId,
          sourceType: 'email_in',
          payloadJson: payloadJson,
          createdAt: createdAt,
        );
  
  factory InboundEmail.fromJson(Map<String, dynamic> json) {
    return InboundEmail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      payloadJson: json['payload_json'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
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
