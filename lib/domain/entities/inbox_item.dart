/// Domain entity representing an inbox item (email or web clip)
class InboxItem {
  final String id;
  final String userId;
  final String sourceType; // 'email_in' or 'web'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final bool isProcessed;
  final String? noteId; // If converted to note

  const InboxItem({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.payload,
    required this.createdAt,
    this.isProcessed = false,
    this.noteId,
  });

  // Type checking helpers
  bool get isEmail => sourceType == 'email_in';
  bool get isWebClip => sourceType == 'web';

  // Email-specific getters
  String? get emailTo => isEmail ? payload['to'] as String? : null;
  String? get emailFrom => isEmail ? payload['from'] as String? : null;
  String? get emailSubject => isEmail ? payload['subject'] as String? : null;
  String? get emailText => isEmail ? payload['text'] as String? : null;
  String? get emailHtml => isEmail ? payload['html'] as String? : null;
  String? get emailMessageId =>
      isEmail ? payload['message_id'] as String? : null;

  // Web clip-specific getters
  String? get webTitle => isWebClip ? payload['title'] as String? : null;
  String? get webText => isWebClip ? payload['text'] as String? : null;
  String? get webUrl => isWebClip ? payload['url'] as String? : null;
  String? get webHtml => isWebClip ? payload['html'] as String? : null;
  DateTime? get webClippedAt => isWebClip && payload['clipped_at'] != null
      ? DateTime.tryParse(payload['clipped_at'] as String)
      : null;

  // Attachment info
  bool get hasAttachments {
    if (!isEmail) return false;
    final attachments = payload['attachments'];
    return attachments != null &&
        attachments['count'] != null &&
        (attachments['count'] as int) > 0;
  }

  int get attachmentCount {
    if (!isEmail) return 0;
    final attachments = payload['attachments'];
    return (attachments?['count'] as int?) ?? 0;
  }

  // Display helpers for UI
  String get displayTitle {
    if (isEmail) {
      return emailSubject ?? 'Email from ${emailFrom ?? "Unknown"}';
    }
    if (isWebClip) {
      return webTitle ?? 'Web Clip';
    }
    return 'Unknown Item';
  }

  String get displaySubtitle {
    if (isEmail) {
      return emailFrom ?? 'Unknown sender';
    }
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
    // Get preview text, trimmed and with normalized whitespace
    String? rawText;
    if (isEmail) {
      rawText = emailText;
    } else if (isWebClip) {
      rawText = webText;
    }

    if (rawText == null || rawText.isEmpty) return null;

    // Clean up the text for preview
    return rawText
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  // Convenience aliases for backward compatibility
  String? get from => emailFrom;
  String? get to => emailTo;
  String? get html => isEmail ? emailHtml : (isWebClip ? webHtml : null);

  InboxItem copyWith({
    String? id,
    String? userId,
    String? sourceType,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    bool? isProcessed,
    String? noteId,
  }) {
    return InboxItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sourceType: sourceType ?? this.sourceType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      isProcessed: isProcessed ?? this.isProcessed,
      noteId: noteId ?? this.noteId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
