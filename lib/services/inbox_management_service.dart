import 'dart:async';

import 'package:duru_notes/core/errors.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/result.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/sync_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing the inbound email inbox functionality
/// This service handles fetching, converting, and managing emails from the clipper_inbox
class InboxManagementService {
  InboxManagementService({
    required SupabaseClient supabase,
    required EmailAliasService aliasService,
    NotesRepository? notesRepository,
    IncomingMailFolderManager? folderManager,
    SyncService? syncService,
    AttachmentService? attachmentService,
  })  : _supabase = supabase,
        _aliasService = aliasService,
        _notesRepository = notesRepository,
        _folderManager = folderManager,
        _syncService = syncService,
        _attachmentService = attachmentService;
  final SupabaseClient _supabase;
  final EmailAliasService _aliasService;
  final NotesRepository? _notesRepository;
  final IncomingMailFolderManager? _folderManager;
  final SyncService? _syncService;
  final AttachmentService? _attachmentService;
  final AppLogger _logger = LoggerFactory.instance;

  // Debounce timer for sync
  Timer? _syncDebounceTimer;
  static const _syncDebounceDelay = Duration(milliseconds: 500);

  /// Get the full inbound email address for the user (delegates to EmailAliasService)
  Future<String?> getUserInboundEmail() async {
    return _aliasService.getFullEmailAddress();
  }

  /// List all inbox items (both email and web clips) - unified inbox
  Future<List<InboxItem>> listInboxItems({
    int limit = 50,
    int offset = 0,
  }) async {
    return getClipperInboxItems(limit: limit, offset: offset);
  }

  /// Fetch all clipper inbox items (both email and web clips)
  Future<List<InboxItem>> getClipperInboxItems({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('No authenticated user for inbox fetch');
        return [];
      }

      final response = await _supabase
          .from('clipper_inbox')
          .select()
          .eq('user_id', userId) // Strict user scoping
          .or('source_type.eq.email_in,source_type.eq.web')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => InboxItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error fetching inbox items',
        error: e,
        stackTrace: stackTrace,
      );
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
        .map(
          (item) => InboundEmail(
            id: item.id,
            userId: item.userId,
            payloadJson: item.payloadJson,
            createdAt: item.createdAt,
          ),
        )
        .toList();
  }

  /// Delete an inbox item (email or web clip)
  Future<Result<void, AppError>> deleteInboxItem(String itemId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('No authenticated user for deletion');
        return Result.failure(
          const AuthError(
            message: 'No authenticated user',
            type: AuthErrorType.sessionExpired,
          ),
        );
      }

      await _supabase
          .from('clipper_inbox')
          .delete()
          .eq('user_id', userId) // Strict user scoping
          .eq('id', itemId);

      _logger.info('Deleted inbox item', data: {'itemId': itemId});
      return Result.success(null);
    } catch (e, stackTrace) {
      _logger.error(
        'Error deleting inbox item',
        error: e,
        stackTrace: stackTrace,
        data: {'itemId': itemId},
      );
      return Result.failure(ErrorFactory.fromException(e, stackTrace));
    }
  }

  /// Delete an inbox item (email or web clip) - backward compatible
  @Deprecated('Use deleteInboxItem which returns Result')
  Future<bool> deleteInboxItemLegacy(String itemId) async {
    final result = await deleteInboxItem(itemId);
    return result.isSuccess;
  }

  /// Delete an inbound email from the inbox (deprecated - use deleteInboxItem)
  @Deprecated('Use deleteInboxItem instead')
  Future<bool> deleteInboundEmail(String emailId) async {
    final result = await deleteInboxItem(emailId);
    return result.isSuccess;
  }

  /// Convert an inbox item (email or web clip) to a note - Result-based API
  /// Performance optimized: <3s from tap to synced
  Future<Result<String, AppError>> convertItemToNote(InboxItem item) async {
    if (_notesRepository == null) {
      _logger.error('NotesRepository not available for conversion');
      return Result.failure(
        const UnexpectedError(
          message: 'NotesRepository not initialized',
          code: 'REPO_NOT_INITIALIZED',
        ),
      );
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Branch based on source type
      String? noteId;
      if (item.sourceType == 'email_in') {
        noteId = await _convertEmailToNote(item);
      } else if (item.sourceType == 'web') {
        noteId = await _convertWebClipToNote(item);
      } else {
        _logger.warning(
          'Unknown source type',
          data: {'sourceType': item.sourceType, 'itemId': item.id},
        );
        return Result.failure(
          ValidationError(
            message: 'Unknown source type: ${item.sourceType}',
            code: 'INVALID_SOURCE_TYPE',
          ),
        );
      }

      if (noteId == null) {
        return Result.failure(
          UnexpectedError(
            message: 'Failed to create note from ${item.sourceType}',
            code: 'CONVERSION_FAILED',
          ),
        );
      }

      // Trigger sync immediately (debounced)
      _triggerDebouncedSync();

      _logger.info(
        'Conversion completed',
        data: {
          'itemId': item.id,
          'noteId': noteId,
          'sourceType': item.sourceType,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );

      return Result.success(noteId);
    } catch (e, stackTrace) {
      _logger.error(
        'Error converting item to note',
        error: e,
        stackTrace: stackTrace,
        data: {'itemId': item.id},
      );
      return Result.failure(ErrorFactory.fromException(e, stackTrace));
    }
  }

  /// Convert an inbox item (email or web clip) to a note - Legacy API
  /// Performance optimized: <3s from tap to synced
  @Deprecated('Use convertItemToNote which returns Result<String, AppError>')
  Future<String?> convertInboxItemToNote(InboxItem item) async {
    if (_notesRepository == null) {
      _logger.error('NotesRepository not available for conversion');
      return null;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Branch based on source type
      String? noteId;
      if (item.sourceType == 'email_in') {
        noteId = await _convertEmailToNote(item);
      } else if (item.sourceType == 'web') {
        noteId = await _convertWebClipToNote(item);
      } else {
        _logger.warning(
          'Unknown source type',
          data: {'sourceType': item.sourceType, 'itemId': item.id},
        );
        return null;
      }

      if (noteId != null) {
        // Trigger sync immediately (debounced)
        _triggerDebouncedSync();

        _logger.debug(
          ' Conversion completed in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      return noteId;
    } catch (e, stackTrace) {
      _logger.debug(' Error converting item to note: $e');
      _logger.debug('$stackTrace');
      return null;
    }
  }

  /// Trigger sync with debouncing to coalesce multiple conversions
  void _triggerDebouncedSync() {
    if (_syncService == null) return;

    // Cancel existing timer if any
    _syncDebounceTimer?.cancel();

    // Start new timer
    _syncDebounceTimer = Timer(_syncDebounceDelay, () {
      _logger.debug(' Triggering sync after conversion');
      _syncService.syncNow();
    });
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
      _logger.error('NotesRepository not available for conversion');
      return null;
    }

    try {
      final phaseStopwatch = Stopwatch()..start();

      // Phase A: Build content and create note locally (target: <500ms)
      final title = item.subject ?? 'Email from ${item.from ?? "Unknown"}';
      var emailText = item.text ?? '';

      // If no text content, try to extract from HTML
      if (emailText.isEmpty && item.html != null) {
        // Basic HTML to text conversion (strip tags)
        emailText = item.html!
            .replaceAll(RegExp(r'<br\s*/?>'), '\n')
            .replaceAll(RegExp(r'<p\s*>'), '\n')
            .replaceAll(RegExp('</p>'), '\n')
            .replaceAll(RegExp('<[^>]+>'), '')
            .replaceAll(RegExp(r'\n\n+'), '\n\n')
            .trim();
      }

      // Build body with email content and metadata footer
      final body = StringBuffer();
      if (emailText.isNotEmpty) {
        body.write(emailText);
      }
      body.writeln('\n\n---');
      body.writeln('From: ${item.from ?? "Unknown"}');
      body.writeln('Received: ${item.createdAt.toIso8601String()}');

      // Add tags (without # prefix for database)
      final tags = <String>['Email'];
      if (item.hasAttachments) {
        tags.add('Attachment');
      }
      // Add hashtags to body for display
      final bodyWithTags = '$body\n\n${tags.map((t) => '#$t').join(' ')}';

      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'email_in',
        'from': item.from,
        'to': item.to,
        'received_at': item.createdAt.toIso8601String(),
        'original_id': item.id,
        'message_id': item.messageId,
        'tags': tags,
      };

      // Store attachment info for later processing
      final attachmentInfo =
          item.payloadJson['attachments'] as Map<String, dynamic>?;
      if (attachmentInfo != null) {
        metadata['attachments'] = attachmentInfo;
        metadata['attachments_pending'] = true; // Mark as pending upload
      }

      // Add HTML to metadata if present
      if (item.html != null) {
        metadata['html'] = item.html;
      }

      // Create the note locally (should be fast)
      final note = await _notesRepository.createOrUpdate(
        title: title,
        body: bodyWithTags,
        metadataJson: metadata,
        tags: tags.toSet(),
      );

      if (note == null) {
        _logger.debug(' Failed to create note from email');
        return null;
      }

      final noteId = note.id;
      _logger.debug(
        ' Phase A completed in ${phaseStopwatch.elapsedMilliseconds}ms',
      );

      // Phase B: Background operations (non-blocking)
      // Process attachments in background if present
      if (item.hasAttachments && attachmentInfo != null) {
        _processAttachmentsInBackground(
          noteId,
          attachmentInfo,
          title,
          bodyWithTags,
          metadata,
        );
      }

      // Add to folder and delete from inbox (non-blocking)
      _completeConversionInBackground(item.id, noteId);

      _logger.debug(' Converted email ${item.id} to note $noteId');
      return noteId;
    } catch (e, stackTrace) {
      _logger.debug(' Error converting email to note: $e');
      _logger.debug('$stackTrace');
      return null;
    }
  }

  Future<String?> _convertWebClipToNote(InboxItem item) async {
    if (_notesRepository == null) {
      _logger.error('NotesRepository not available for conversion');
      return null;
    }

    try {
      final phaseStopwatch = Stopwatch()..start();

      // Phase A: Build content and create note locally (target: <500ms)
      final title = item.webTitle ?? 'Web Clip';
      final text = item.webText ?? '';
      final url = item.webUrl ?? '';
      final clippedAt = item.webClippedAt ?? item.createdAt.toIso8601String();

      // Build body with source reference
      final body = StringBuffer();
      if (text.isNotEmpty) {
        body.write(text);
      }
      body.writeln('\n\n---');
      body.writeln('Source: $url');
      body.writeln('Clipped: $clippedAt');

      // Add tags (without # prefix for database)
      final tags = <String>['Web'];
      // Add hashtags to body for display
      final bodyWithTags = '$body\n\n${tags.map((t) => '#$t').join(' ')}';

      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'web',
        'url': url,
        'clipped_at': clippedAt,
        'original_id': item.id,
        'tags': tags,
      };

      // Add HTML content to metadata if present
      if (item.webHtml != null) {
        metadata['html'] = item.webHtml;
      }

      // Create the note locally (should be fast)
      final note = await _notesRepository.createOrUpdate(
        title: title,
        body: bodyWithTags,
        metadataJson: metadata,
        tags: tags.toSet(),
      );

      if (note == null) {
        _logger.debug(' Failed to create note from web clip');
        return null;
      }

      final noteId = note.id;
      _logger.debug(
        ' Phase A completed in ${phaseStopwatch.elapsedMilliseconds}ms',
      );

      // Complete remaining tasks in background
      _completeConversionInBackground(item.id, noteId);

      _logger.debug(' Converted web clip ${item.id} to note $noteId');
      return noteId;
    } catch (e, stackTrace) {
      _logger.debug(' Error converting web clip to note: $e');
      _logger.debug('$stackTrace');
      return null;
    }
  }

  /// Process attachments in background without blocking note creation
  Future<void> _processAttachmentsInBackground(
    String noteId,
    Map<String, dynamic> attachmentInfo,
    String title,
    String bodyWithTags,
    Map<String, dynamic> metadata,
  ) async {
    try {
      _logger.debug(' Processing attachments in background for note $noteId');

      // Extract attachment details
      final attachments = getAttachments(
        InboxItem(
          id: '',
          userId: '',
          sourceType: 'email_in',
          payloadJson: {'attachments': attachmentInfo},
          createdAt: DateTime.now(),
        ),
      );

      if (attachments.isEmpty) return;

      final attachmentLinks = StringBuffer();
      attachmentLinks.writeln('\n\n## Attachments');

      for (final attachment in attachments) {
        // For now, just add metadata about attachments
        // In a full implementation, you would:
        // 1. Download attachment from storage
        // 2. Re-upload to user's attachment storage
        // 3. Get the new URL
        attachmentLinks.writeln(
          '- [${attachment.filename}](${attachment.url ?? "pending"}) (${attachment.sizeFormatted})',
        );
      }

      // Update note body with attachment links
      final updatedBody = bodyWithTags + attachmentLinks.toString();
      metadata['attachments_pending'] = false;

      // Update the note with attachment info
      await _notesRepository?.createOrUpdate(
        id: noteId,
        title: title,
        body: updatedBody,
        metadataJson: metadata,
      );

      // Trigger another sync to push the updated note
      _triggerDebouncedSync();

      _logger.debug(' Attachments processed for note $noteId');
    } catch (e) {
      _logger.debug(' Error processing attachments: $e');
      // Don't fail the conversion if attachment processing fails
    }
  }

  /// Complete conversion tasks in background
  Future<void> _completeConversionInBackground(
    String itemId,
    String noteId,
  ) async {
    try {
      // Add to Incoming Mail folder if folder manager is available
      if (_folderManager != null && noteId.isNotEmpty) {
        try {
          await _folderManager.addNoteToIncomingMail(noteId);
          _logger.debug(' Added note to Incoming Mail folder');
        } catch (e) {
          _logger.debug(' Failed to add note to folder: $e');
        }
      }

      // Delete from inbox after successful conversion
      await deleteInboxItem(itemId);
      _logger.debug(' Deleted inbox item $itemId');
    } catch (e) {
      _logger.debug(' Error in background tasks: $e');
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
      _logger.debug(' Error parsing attachments: $e');
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

      _logger.debug(' Generated signed URL for: $filePath');
      return response;
    } catch (e, stackTrace) {
      _logger.debug(' Error getting attachment URL for $filePath: $e');
      _logger.debug('$stackTrace');
      return null;
    }
  }
}

/// Model for inbox items (email or web clips) from clipper_inbox
class InboxItem {
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
  final String id;
  final String userId;
  final String sourceType;
  final Map<String, dynamic> payloadJson;
  final DateTime createdAt;

  // Common getters
  bool get isEmail => sourceType == 'email_in';
  bool get isWebClip => sourceType == 'web';

  // Email-specific getters
  String? get to => isEmail ? payloadJson['to'] as String? : null;
  String? get from => isEmail ? payloadJson['from'] as String? : null;
  String? get subject => isEmail ? payloadJson['subject'] as String? : null;
  String? get text => isEmail ? payloadJson['text'] as String? : null;
  String? get html => isEmail ? payloadJson['html'] as String? : null;
  String? get messageId =>
      isEmail ? payloadJson['message_id'] as String? : null;

  // Web clip-specific getters
  String? get webTitle => isWebClip ? payloadJson['title'] as String? : null;
  String? get webText => isWebClip ? payloadJson['text'] as String? : null;
  String? get webUrl => isWebClip ? payloadJson['url'] as String? : null;
  String? get webHtml => isWebClip ? payloadJson['html'] as String? : null;
  String? get webClippedAt =>
      isWebClip ? payloadJson['clipped_at'] as String? : null;

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
    // Get preview text, trimmed and with normalized whitespace
    String? rawText;
    if (isEmail) {
      rawText = text;
    } else if (isWebClip) {
      rawText = webText;
    }

    if (rawText == null || rawText.isEmpty) return null;

    // Clean up the text for preview
    return rawText
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
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
    required super.id,
    required super.userId,
    required super.payloadJson,
    required super.createdAt,
  }) : super(sourceType: 'email_in');

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
  final String filename;
  final String type;
  final int size;
  final String? url;

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
    if (type.contains('presentation') || type.contains('powerpoint')) {
      return 'presentation';
    }
    if (type.startsWith('text/')) return 'text';
    return 'file';
  }
}
