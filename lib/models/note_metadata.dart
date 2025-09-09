/// Metadata model for notes that came from external sources
class NoteMetadata {
  final String? source;
  final String? fromEmail;
  final String? to;
  final String? receivedAt;
  final String? messageId;
  final String? originalHtml;
  final Map<String, dynamic>? attachments;

  NoteMetadata({
    this.source,
    this.fromEmail,
    this.to,
    this.receivedAt,
    this.messageId,
    this.originalHtml,
    this.attachments,
  });

  Map<String, dynamic> toJson() {
    return {
      if (source != null) 'source': source,
      if (fromEmail != null) 'from_email': fromEmail,
      if (to != null) 'to': to,
      if (receivedAt != null) 'received_at': receivedAt,
      if (messageId != null) 'message_id': messageId,
      if (originalHtml != null) 'original_html': originalHtml,
      if (attachments != null) 'attachments': attachments,
    };
  }

  factory NoteMetadata.fromJson(Map<String, dynamic> json) {
    return NoteMetadata(
      source: json['source'] as String?,
      fromEmail: json['from_email'] as String?,
      to: json['to'] as String?,
      receivedAt: json['received_at'] as String?,
      messageId: json['message_id'] as String?,
      originalHtml: json['original_html'] as String?,
      attachments: json['attachments'] as Map<String, dynamic>?,
    );
  }
}
