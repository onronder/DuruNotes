import 'dart:async';
import 'dart:convert'; // For base64 decoding
import 'dart:typed_data'; // For Uint8List

import 'package:duru_notes/core/errors.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/result.dart';
import 'package:duru_notes/domain/entities/inbox_item.dart' as domain;
import 'package:duru_notes/domain/repositories/i_inbox_repository.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:http/http.dart' as http; // For downloading from pre-signed URLs
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing the inbound email inbox functionality
/// This service handles converting inbox items (email, web clips) into notes
/// and delegates data access to InboxRepository following DDD principles.
class InboxManagementService {
  InboxManagementService({
    required IInboxRepository inboxRepository,
    required SupabaseClient supabase,
    required EmailAliasService aliasService,
    NotesCoreRepository? notesRepository,
    IncomingMailFolderManager? folderManager,
    AttachmentService? attachmentService, // Kept for backward compatibility
  }) : _inboxRepository = inboxRepository,
       _supabase = supabase,
       _aliasService = aliasService,
       _notesRepository = notesRepository,
       _folderManager = folderManager;

  final IInboxRepository _inboxRepository;
  final SupabaseClient _supabase;
  final EmailAliasService _aliasService;
  final NotesCoreRepository? _notesRepository;
  final IncomingMailFolderManager? _folderManager;
  final AppLogger _logger = LoggerFactory.instance;

  // Debounce timer for sync
  Timer? _syncDebounceTimer;
  static const _syncDebounceDelay = Duration(milliseconds: 500);

  /// Get the full inbound email address for the user (delegates to EmailAliasService)
  Future<String?> getUserInboundEmail() async {
    return _aliasService.getFullEmailAddress();
  }

  /// List all inbox items (both email and web clips) - unified inbox
  Future<List<domain.InboxItem>> listInboxItems({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Use repository to fetch unprocessed items
      // Note: Repository doesn't support pagination yet, so we get all and slice
      final allItems = await _inboxRepository.getUnprocessed();

      // Apply offset and limit
      if (offset >= allItems.length) return [];

      final endIndex = (offset + limit).clamp(0, allItems.length);
      return allItems.sublist(offset, endIndex);
    } catch (e, stackTrace) {
      _logger.error(
        'Error listing inbox items',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Fetch all clipper inbox items (both email and web clips)
  Future<List<domain.InboxItem>> getClipperInboxItems({
    int limit = 50,
    int offset = 0,
  }) async {
    return listInboxItems(limit: limit, offset: offset);
  }

  /// Delete an inbox item (email or web clip)
  Future<Result<void, AppError>> deleteInboxItem(String itemId) async {
    try {
      await _inboxRepository.delete(itemId);
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
  Future<Result<String, AppError>> convertItemToNote(
    domain.InboxItem item,
  ) async {
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
  Future<String?> convertInboxItemToNote(domain.InboxItem item) async {
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
    // Sync is now handled by UnifiedSyncService automatically
    // Cancel existing timer if any
    _syncDebounceTimer?.cancel();

    // Start new timer
    _syncDebounceTimer = Timer(_syncDebounceDelay, () {
      _logger.debug(
        ' Sync triggered after conversion (handled by UnifiedSyncService)',
      );
      // No-op - sync happens automatically via queue
    });
  }

  Future<String?> _convertEmailToNote(domain.InboxItem item) async {
    if (_notesRepository == null) {
      _logger.error('NotesRepository not available for conversion');
      return null;
    }

    try {
      final phaseStopwatch = Stopwatch()..start();

      // Phase A: Build content and create note locally (target: <500ms)
      final title =
          item.emailSubject ?? 'Email from ${item.emailFrom ?? "Unknown"}';
      var emailText = item.emailText ?? '';

      // If no text content, try to extract from HTML
      if (emailText.isEmpty && item.emailHtml != null) {
        // Basic HTML to text conversion (strip tags)
        emailText = item.emailHtml!
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
      body.writeln('From: ${item.emailFrom ?? "Unknown"}');
      body.writeln('Received: ${item.createdAt.toIso8601String()}');

      Map<String, dynamic>? attachmentInfo =
          item.payload['attachments'] as Map<String, dynamic>?;
      Map<String, dynamic>? attachmentMeta;
      var hasAttachments = item.hasAttachments;

      if (!_hasAttachmentFiles(attachmentInfo)) {
        final resolved = await _waitForInboundAttachments(item.id);
        if (_hasAttachmentFiles(resolved)) {
          attachmentInfo = resolved;
          hasAttachments = true;
        }
      } else {
        hasAttachments = true;
      }

      // Add tags (without # prefix for database)
      final tags = <String>['Email'];
      if (hasAttachments) {
        tags.add('Attachment');
      }
      // Add hashtags to body for display
      final bodyWithTags = '$body\n\n${tags.map((t) => '#$t').join(' ')}';

      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'email_in',
        'from': item.emailFrom,
        'to': item.emailTo,
        'received_at': item.createdAt.toIso8601String(),
        'original_id': item.id,
        'message_id': item.emailMessageId,
        'tags': tags,
      };

      // Store attachment info in format that modern_edit_note_screen expects
      if (_hasAttachmentFiles(attachmentInfo)) {
        // Convert to format: {files: [{path, filename, type, size, url, url_expires_at}]}
        // This matches what EmailAttachmentRef constructor expects in modern_edit_note_screen
        // CRITICAL FIX: Preserve URL and expiration from backend
        final files = ((attachmentInfo?['files'] as List?) ?? const []).map((
          f,
        ) {
          return {
            'path': f['storage_path'] ?? '',
            'filename': f['filename'] ?? 'unnamed',
            'type': f['content_type'] ?? 'application/octet-stream',
            'size': f['size'] ?? 0,
            'url': f['url'], // Pre-signed URL from backend (CRITICAL FIX)
            'url_expires_at':
                f['url_expires_at'], // URL expiration timestamp (CRITICAL FIX)
          };
        }).toList();

        attachmentMeta = {
          'files': files,
          'count': attachmentInfo?['count'] ?? files.length,
        };
        metadata['attachments'] = attachmentMeta;
        metadata['attachments_pending'] = true; // Mark as pending upload
      }

      // Add HTML to metadata if present
      if (item.emailHtml != null) {
        metadata['html'] = item.emailHtml;
      }

      // Create the note locally (should be fast)
      final note = await _notesRepository.createOrUpdate(
        title: title,
        body: bodyWithTags,
        attachmentMeta: attachmentMeta,
        metadataJson: metadata,
        tags: tags,
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
      _logger.info(
        '📎 [Attachments] Checking resolved metadata',
        data: {
          'hasAttachmentsFlag': hasAttachments,
          'metadataHasFiles': _hasAttachmentFiles(attachmentInfo),
          'inboxId': item.id,
        },
      );
      if (hasAttachments && attachmentInfo != null) {
        _logger.info('📎 [Attachments] Starting background processing');
        _processAttachmentsInBackground(
          noteId,
          attachmentInfo,
          title,
          bodyWithTags,
          metadata,
        );
      } else {
        _logger.warn(
          '⚠️ [Debug] Attachment processing SKIPPED: hasAttachments=${item.hasAttachments}, attachmentInfo=${attachmentInfo != null ? 'exists' : 'null'}',
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

  Future<String?> _convertWebClipToNote(domain.InboxItem item) async {
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
      final clippedAt =
          item.webClippedAt?.toIso8601String() ??
          item.createdAt.toIso8601String();

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
        tags: tags,
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
    Map<String, dynamic> metadata, {
    int attempt = 1,
  }) async {
    const maxAttempts = 5;
    if (attempt > maxAttempts) {
      _logger.error(
        '❌ [Attachments] Giving up after max retries: note not synced',
        data: {'noteId': noteId, 'attempts': maxAttempts},
      );
      return;
    }

    final noteSynced = await _waitForNoteToSync(noteId);
    if (!noteSynced) {
      final retryDelay = Duration(seconds: attempt * 2);
      _logger.warn(
        '⚠️ [Attachments] Note not yet synced; retrying',
        data: {
          'noteId': noteId,
          'attempt': attempt,
          'maxAttempts': maxAttempts,
          'retryInSeconds': retryDelay.inSeconds,
        },
      );

      final metadataClone =
          jsonDecode(jsonEncode(metadata)) as Map<String, dynamic>;
      final attachmentClone =
          jsonDecode(jsonEncode(attachmentInfo)) as Map<String, dynamic>;

      Future<void>.delayed(retryDelay, () {
        _processAttachmentsInBackground(
          noteId,
          attachmentClone,
          title,
          bodyWithTags,
          metadataClone,
          attempt: attempt + 1,
        );
      });
      return;
    }

    try {
      _logger.info(
        '📎 [Attachments] Processing in background',
        data: {'noteId': noteId, 'attempt': attempt},
      );
      Map<String, dynamic>? attachmentsMeta;
      final existingAttachmentsMeta = metadata['attachments'];
      if (existingAttachmentsMeta is Map<String, dynamic>) {
        attachmentsMeta = Map<String, dynamic>.from(existingAttachmentsMeta);
      } else if (existingAttachmentsMeta is Map) {
        attachmentsMeta = existingAttachmentsMeta.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
      }

      // Extract attachment details
      final attachments = getAttachments(
        domain.InboxItem(
          id: '',
          userId: '',
          sourceType: 'email_in',
          payload: {'attachments': attachmentInfo},
          createdAt: DateTime.now(),
        ),
      );

      if (attachments.isEmpty) return;

      final attachmentLinks = StringBuffer();
      attachmentLinks.writeln('\n\n## Attachments');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.error('❌ [Attachments] No authenticated user');
        return;
      }

      int successCount = 0;
      int failCount = 0;
      final updatedFiles = <Map<String, dynamic>>[];

      for (final attachment in attachments) {
        try {
          final filename = attachment.filename;
          final size = attachment.size;
          final mimeType = attachment.contentType;

          _logger.info(
            '📎 [Attachments] Processing: $filename ($size bytes, $mimeType)',
          );

          // VALIDATION: File size limit (50MB)
          const maxFileSize = 50 * 1024 * 1024; // 50MB
          if (size > maxFileSize) {
            _logger.warn(
              '⚠️ [Attachments] File too large: $filename (${_formatBytes(size)}) - max 50MB',
            );
            attachmentLinks.writeln(
              '- ⚠️ [$filename](file-too-large) (${_formatBytes(size)} - max 50MB)',
            );
            failCount++;
            continue;
          }

          // GET FILE DATA: Download from storage_path (new) or decode base64 (legacy)
          Uint8List? fileBytes;
          try {
            fileBytes = await attachment.getFileData(_supabase);
            if (fileBytes == null) {
              _logger.warn(
                '⚠️ [Attachments] No file data available for: $filename',
              );
              attachmentLinks.writeln('- ⚠️ [$filename](no-content)');
              failCount++;
              continue;
            }
            _logger.debug(
              '✓ [Attachments] Retrieved file data: ${fileBytes.length} bytes',
            );
          } catch (e) {
            _logger.error('❌ [Attachments] Failed to get file data: $e');
            attachmentLinks.writeln('- ❌ [$filename](data-error)');
            failCount++;
            continue;
          }

          // UPLOAD: To final Supabase Storage location
          final storagePath = '$userId/$noteId/$filename';
          _logger.debug('📤 [Attachments] Uploading to: $storagePath');

          try {
            await _supabase.storage
                .from('inbound-attachments')
                .uploadBinary(
                  storagePath,
                  fileBytes,
                  fileOptions: FileOptions(
                    contentType: mimeType,
                    upsert: false, // Don't overwrite existing files
                  ),
                );
            _logger.info('✅ [Attachments] Uploaded: $filename');

            // CLEANUP: Remove temporary file if it came from storage_path
            if (attachment.storagePath != null) {
              try {
                await _supabase.storage.from('inbound-attachments-temp').remove(
                  [attachment.storagePath!],
                );
                _logger.debug('🗑️ [Attachments] Cleaned up temp file');
              } catch (cleanupError) {
                _logger.warn(
                  '⚠️ [Attachments] Failed to cleanup temp file: $cleanupError',
                );
                // Non-critical error, continue processing
              }
            }
          } catch (e) {
            _logger.error('❌ [Attachments] Upload failed: $e');
            attachmentLinks.writeln('- ❌ [$filename](upload-error)');
            failCount++;
            continue;
          }

          // GET PUBLIC URL
          final publicUrl = _supabase.storage
              .from('inbound-attachments')
              .getPublicUrl(storagePath);

          _logger.debug('🔗 [Attachments] Public URL: $publicUrl');

          // SAVE TO DATABASE
          try {
            // Generate unique ID for attachment (required by schema)
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final sanitizedFilename = filename.replaceAll(
              RegExp(r'[^a-zA-Z0-9.]'),
              '_',
            );
            final attachmentId = '${timestamp}_$sanitizedFilename';

            final insertData = {
              'id': attachmentId,
              'user_id': userId,
              'note_id': noteId,
              'file_name': filename,
              'storage_path': storagePath,
              'mime_type': mimeType,
              'size': size,
              'url': publicUrl,
              'uploaded_at': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'deleted': false,
            };

            _logger.info(
              '💾 [Attachments] Attempting DB insert with data: $insertData',
            );

            await _supabase.from('attachments').insert(insertData);

            _logger.info('✅ [Attachments] DB insert SUCCESS: $filename');
          } catch (e, stackTrace) {
            _logger.error(
              '❌ [Attachments] DB insert FAILED',
              error: e,
              stackTrace: stackTrace,
              data: {
                'filename': filename,
                'noteId': noteId,
                'userId': userId,
                'storagePath': storagePath,
                'size': size,
                'mimeType': mimeType,
                'errorType': e.runtimeType.toString(),
              },
            );
            // Print full error to console for debugging
            print('🔴 ATTACHMENT INSERT ERROR:');
            print('   Error: $e');
            print('   Type: ${e.runtimeType}');
            print('   StackTrace: $stackTrace');
            // Try to clean up uploaded file
            try {
              await _supabase.storage.from('inbound-attachments').remove([
                storagePath,
              ]);
              _logger.debug('🗑️ [Attachments] Cleaned up failed upload');
            } catch (cleanupError) {
              _logger.warn('⚠️ [Attachments] Cleanup failed: $cleanupError');
            }
            attachmentLinks.writeln('- ❌ [$filename](db-error)');
            failCount++;
            continue;
          }

          // SUCCESS: Add link to note and store updated file info
          attachmentLinks.writeln(
            '- 📎 [$filename]($publicUrl) (${_formatBytes(size)})',
          );

          // Store updated file info with new storage path
          updatedFiles.add({
            'path': storagePath,
            'filename': filename,
            'type': mimeType,
            'size': size,
          });

          successCount++;

          _logger.info(
            '✅ [Attachments] Complete: $filename (${_formatBytes(size)})',
          );
        } catch (e, stackTrace) {
          _logger.error(
            '❌ [Attachments] Unexpected error processing ${attachment.filename}',
            error: e,
            stackTrace: stackTrace,
          );
          attachmentLinks.writeln(
            '- ❌ [${attachment.filename}](error: ${e.toString().substring(0, 50)})',
          );
          failCount++;
        }
      }

      _logger.info(
        '📊 [Attachments] Summary: $successCount succeeded, $failCount failed',
      );
      _logger.debug(
        '[InboxConversion] Attachment summary for note $noteId',
        data: {
          'successCount': successCount,
          'failCount': failCount,
          'updatedFiles': updatedFiles,
        },
      );

      // Update note body with attachment links
      final updatedBody = bodyWithTags + attachmentLinks.toString();
      metadata['attachments_pending'] = false;
      metadata['attachments_processed'] = successCount;
      metadata['attachments_failed'] = failCount;

      // Update attachments metadata with new storage paths
      if (updatedFiles.isNotEmpty) {
        attachmentsMeta = {'files': updatedFiles, 'count': updatedFiles.length};
        metadata['attachments'] = attachmentsMeta;
      } else if (attachmentsMeta != null) {
        metadata['attachments'] = attachmentsMeta;
      }

      // Update the note with attachment info
      final attachmentTags =
          (metadata['tags'] as List<dynamic>?)?.cast<String>() ?? const [];

      await _notesRepository?.createOrUpdate(
        id: noteId,
        title: title,
        body: updatedBody,
        attachmentMeta: attachmentsMeta,
        metadataJson: metadata,
        tags: attachmentTags,
      );
      _logger.debug(
        '[InboxConversion] Updated note $noteId metadata',
        data: {'metadata': metadata},
      );

      // Trigger another sync to push the updated note
      _triggerDebouncedSync();

      _logger.debug(' Attachments processed for note $noteId');
    } catch (e) {
      _logger.debug(' Error processing attachments: $e');
      // Don't fail the conversion if attachment processing fails
    }
  }

  Future<bool> _waitForNoteToSync(
    String noteId, {
    Duration timeout = const Duration(seconds: 8),
    Duration pollInterval = const Duration(milliseconds: 400),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _supabase
            .from('notes')
            .select('id')
            .eq('id', noteId)
            .maybeSingle();

        if (response != null) {
          return true;
        }
      } catch (error) {
        _logger.warn(
          '⚠️ [Attachments] Failed to verify remote note status',
          data: {'noteId': noteId, 'error': error.toString()},
        );
      }

      await Future<void>.delayed(pollInterval);
    }

    _logger.warn(
      '⚠️ [Attachments] Timed out waiting for note sync',
      data: {'noteId': noteId, 'timeoutSeconds': timeout.inSeconds},
    );
    return false;
  }

  bool _hasAttachmentFiles(Map<String, dynamic>? attachmentInfo) {
    final files = attachmentInfo?['files'];
    if (files is List && files.isNotEmpty) {
      return true;
    }
    final count = attachmentInfo?['count'];
    if (count is num && count > 0) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _waitForInboundAttachments(
    String inboxId, {
    Duration timeout = const Duration(seconds: 6),
    Duration pollInterval = const Duration(milliseconds: 400),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _supabase
            .from('clipper_inbox')
            .select('payload_json')
            .eq('id', inboxId)
            .maybeSingle();

        final payload = response?['payload_json'];
        if (payload is Map<String, dynamic>) {
          final attachments = payload['attachments'] as Map<String, dynamic>?;
          if (_hasAttachmentFiles(attachments)) {
            _logger.info(
              '📎 [Attachments] Resolved metadata from clipper_inbox',
              data: {'inboxId': inboxId},
            );
            return attachments;
          }
        }
      } catch (error) {
        _logger.warning(
          '⚠️ [Attachments] Failed to fetch latest inbox payload',
          data: {'inboxId': inboxId, 'error': error.toString()},
        );
      }
      await Future<void>.delayed(pollInterval);
    }

    _logger.warn(
      '⚠️ [Attachments] Timed out waiting for inbound attachment metadata',
      data: {'inboxId': inboxId, 'timeoutSeconds': timeout.inSeconds},
    );
    return null;
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

      // Mark as processed so it no longer appears in inbox list
      try {
        await _inboxRepository.markAsProcessed(itemId, noteId: noteId);
        _logger.debug(' Marked inbox item $itemId as processed');
      } catch (e) {
        _logger.debug(' Failed to mark inbox item as processed: $e');
      }
    } catch (e) {
      _logger.debug(' Error in background tasks: $e');
    }
  }

  /// Get attachment information for an inbox item (currently only emails have attachments)
  List<EmailAttachment> getAttachments(domain.InboxItem item) {
    final attachments = item.payload['attachments'];
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
  /// PRODUCTION FIX: Uses correct bucket for temp attachments
  Future<String?> getAttachmentUrl(String filePath) async {
    try {
      // Generate a signed URL that expires in 1 hour
      // CRITICAL FIX: Use 'inbound-attachments-temp' for temporary email attachments
      final response = await _supabase.storage
          .from('inbound-attachments-temp')
          .createSignedUrl(filePath, 3600);

      _logger.debug(' Generated signed URL for: $filePath');
      return response;
    } catch (e, stackTrace) {
      _logger.error(
        ' Failed to generate signed URL',
        error: e,
        stackTrace: stackTrace,
        data: {'filePath': filePath},
      );
      return null;
    }
  }

  /// Format bytes into human-readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Model for email attachment metadata
class EmailAttachment {
  EmailAttachment({
    required this.filename,
    required this.type,
    required this.size,
    this.url,
    this.urlExpiresAt, // CRITICAL FIX: URL expiration timestamp
    this.content, // Base64-encoded file content (legacy)
    this.storagePath, // Storage path in Supabase Storage (new)
  });

  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      filename: json['filename'] as String? ?? 'unnamed',
      type:
          json['type'] as String? ??
          json['content_type'] as String? ??
          'application/octet-stream',
      size: json['size'] as int? ?? 0,
      url: json['url'] as String?,
      urlExpiresAt: json['url_expires_at'] != null
          ? DateTime.tryParse(json['url_expires_at'] as String)
          : null,
      content: json['content'] as String?, // Base64 content (legacy)
      storagePath: json['storage_path'] as String?, // Storage path (new)
    );
  }
  final String filename;
  final String type; // Also accepts 'content_type' from JSON
  final int size;
  final String? url;
  final DateTime? urlExpiresAt; // When the signed URL expires
  final String? content; // Base64-encoded file content (legacy)
  final String? storagePath; // Storage path in Supabase Storage (new)

  /// Get content type (alias for type)
  String get contentType => type;

  /// Get file data from either storage_path (new) or base64 content (legacy)
  Future<Uint8List?> getFileData(SupabaseClient supabase) async {
    // CRITICAL FIX: First try using pre-signed URL (most reliable)
    if (url != null && url!.isNotEmpty) {
      // Check if URL is still valid
      if (urlExpiresAt != null && urlExpiresAt!.isAfter(DateTime.now())) {
        try {
          final response = await http.get(Uri.parse(url!));
          if (response.statusCode == 200) {
            LoggerFactory.instance.debug(
              '✓ Downloaded using pre-signed URL',
              data: {'filename': filename, 'size': response.bodyBytes.length},
            );
            return response.bodyBytes;
          }
        } catch (e) {
          LoggerFactory.instance.error(
            'Failed to download from pre-signed URL',
            error: e,
            data: {'url': url!.substring(0, 100)},
          );
          // Fall through to try other methods
        }
      }
    }

    // Try storage_path (download from temp storage)
    if (storagePath != null && storagePath!.isNotEmpty) {
      try {
        final bytes = await supabase.storage
            .from('inbound-attachments-temp')
            .download(storagePath!);
        return bytes;
      } catch (e) {
        LoggerFactory.instance.error(
          'Failed to download from storage_path',
          error: e,
          data: {'storagePath': storagePath},
        );
        // Fall through to try base64 if storage download fails
      }
    }

    // Fallback to base64 content (legacy way)
    if (content != null && content!.isNotEmpty) {
      try {
        return base64Decode(content!);
      } catch (e) {
        LoggerFactory.instance.error(
          'Failed to decode base64 content',
          error: e,
        );
        return null;
      }
    }

    // No file data available
    return null;
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
    if (type.contains('presentation') || type.contains('powerpoint')) {
      return 'presentation';
    }
    if (type.startsWith('text/')) return 'text';
    return 'file';
  }
}
