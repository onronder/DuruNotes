import 'package:supabase_flutter/supabase_flutter.dart';

class InboundEmailService {
  final SupabaseClient _supabase;
  
  InboundEmailService(this._supabase);
  
  /// Get the inbound email domain from environment or configuration
  String get inboundDomain => const String.fromEnvironment(
    'INBOUND_EMAIL_DOMAIN',
    defaultValue: 'notes.yourdomain.com', // Replace with your actual domain
  );
  
  /// Get or generate the user's email alias
  Future<String?> getUserEmailAlias() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // First, try to get existing alias
      final response = await _supabase
          .from('inbound_aliases')
          .select('alias')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null && response['alias'] != null) {
        return response['alias'] as String;
      }
      
      // If no alias exists, generate one
      final result = await _supabase.rpc(
        'generate_user_alias',
        params: {'p_user_id': userId},
      );
      
      return result as String?;
    } catch (e) {
      print('Error getting user email alias: $e');
      return null;
    }
  }
  
  /// Get the full inbound email address for the user
  Future<String?> getUserInboundEmail() async {
    final alias = await getUserEmailAlias();
    if (alias == null) return null;
    
    return '$alias@$inboundDomain';
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
    } catch (e) {
      print('Error fetching inbound emails: $e');
      return [];
    }
  }
  
  /// Delete an inbound email
  Future<bool> deleteInboundEmail(String emailId) async {
    try {
      await _supabase
          .from('clipper_inbox')
          .delete()
          .eq('id', emailId);
      
      return true;
    } catch (e) {
      print('Error deleting inbound email: $e');
      return false;
    }
  }
  
  /// Convert an inbound email to a note
  Future<String?> convertEmailToNote(InboundEmail email) async {
    try {
      // Extract content from the email
      final title = email.subject ?? 'Email from ${email.from}';
      final content = email.text ?? email.html ?? '';
      
      // Create a note with the email content
      final noteData = {
        'title': title,
        'content': content,
        'metadata': {
          'source': 'email',
          'from': email.from,
          'received_at': email.createdAt.toIso8601String(),
          'original_id': email.id,
        },
      };
      
      // You would integrate this with your existing notes service
      // For now, returning a placeholder
      print('Converting email to note: $noteData');
      
      // After successful conversion, delete from inbox
      await deleteInboundEmail(email.id);
      
      return 'note_id_placeholder';
    } catch (e) {
      print('Error converting email to note: $e');
      return null;
    }
  }
  
  /// Get attachment URLs for an email
  List<EmailAttachment> getAttachments(InboundEmail email) {
    final attachments = email.payloadJson['attachments'];
    if (attachments == null || attachments['files'] == null) {
      return [];
    }
    
    return (attachments['files'] as List)
        .map((file) => EmailAttachment.fromJson(file as Map<String, dynamic>))
        .toList();
  }
  
  /// Generate a signed URL for a private attachment
  Future<String?> getAttachmentUrl(String filePath) async {
    try {
      // Generate a signed URL that expires in 1 hour
      final response = await _supabase.storage
          .from('inbound-attachments')
          .createSignedUrl(filePath, 3600);
      
      return response;
    } catch (e) {
      print('Error getting attachment URL: $e');
      return null;
    }
  }
}

/// Model for inbound email
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

/// Model for email attachment
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
      filename: json['filename'] as String,
      type: json['type'] as String,
      size: json['size'] as int,
      url: json['url'] as String?,
    );
  }
  
  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
