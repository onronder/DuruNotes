import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes_app/models/note_block.dart';
import 'package:duru_notes_app/services/attachment_service.dart';
import 'package:duru_notes_app/services/ocr_service.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';

/// Service to handle shared content from other apps via Android share sheet.
/// Supports text content and images (with optional OCR processing).
class ShareService {
  ShareService({required this.ref});

  final Ref ref;
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  StreamSubscription<List<SharedMediaFile>>? _intentTextStreamSubscription;

  /// Initialize the share service and start listening for shared content
  void initialize(BuildContext context) {
    // Listen for shared media files (images, etc.)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          _handleSharedMedia(context, files);
        }
      },
      onError: (Object err) {
        debugPrint('Share service media error: $err');
      },
    );

    // Listen for shared text
    _intentTextStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        // Check if any file contains text content
        for (final file in files) {
          if (file.type == SharedMediaType.text) {
            _handleSharedText(context, file.path);
          }
        }
      },
      onError: (Object err) {
        debugPrint('Share service text error: $err');
      },
    );

    // Handle initial shared content when app is launched via share
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedMedia(context, files);
      }
    });

    // Text sharing is handled through getInitialMedia for this package version
  }

  /// Handle shared media files (primarily images)
  Future<void> _handleSharedMedia(BuildContext context, List<SharedMediaFile> files) async {
    if (!context.mounted) return;

    try {
      final blocks = <NoteBlock>[];
      
      for (final file in files) {
        final path = file.path;
        if (path.isEmpty) continue;

        final fileExtension = path.split('.').last.toLowerCase();
        
        // Handle images with optional OCR
        if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          await _handleImageFile(context, path, blocks);
        } else {
          // Handle other file types as attachments
          await _handleFileAsAttachment(context, path, blocks);
        }
      }

      if (blocks.isNotEmpty) {
        await _createNoteWithBlocks(context, blocks, 'Shared content');
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process shared files: $e')),
        );
      }
    }
  }

  /// Handle shared text content
  Future<void> _handleSharedText(BuildContext context, String text) async {
    if (!context.mounted) return;

    try {
      final blocks = [
        NoteBlock(type: NoteBlockType.paragraph, data: text.trim()),
      ];

      await _createNoteWithBlocks(context, blocks, 'Shared text');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process shared text: $e')),
        );
      }
    }
  }

  /// Handle image files with optional OCR processing
  Future<void> _handleImageFile(BuildContext context, String path, List<NoteBlock> blocks) async {
    // Show dialog asking user what to do with the image
    final action = await _showImageActionDialog(context);
    if (action == null) return;

          switch (action) {
        case ImageAction.attachment:
          await _handleFileAsAttachment(context, path, blocks);
        case ImageAction.ocr:
          await _handleImageOCR(context, path, blocks);
        case ImageAction.both:
          await _handleFileAsAttachment(context, path, blocks);
          await _handleImageOCR(context, path, blocks);
      }
  }

  /// Show dialog asking user how to handle shared image
  Future<ImageAction?> _showImageActionDialog(BuildContext context) async {
    return showDialog<ImageAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shared Image'),
        content: const Text('How would you like to handle this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageAction.attachment),
            child: const Text('As Attachment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageAction.ocr),
            child: const Text('Extract Text (OCR)'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageAction.both),
            child: const Text('Both'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Handle image OCR processing
  Future<void> _handleImageOCR(BuildContext context, String path, List<NoteBlock> blocks) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final ocrService = OCRService();
      try {
        // Create a temporary XFile-like interface for OCR
        final recognizedText = await _extractTextFromImageFile(file);
        
        if (recognizedText != null && recognizedText.trim().isNotEmpty) {
          blocks.add(
            NoteBlock(type: NoteBlockType.paragraph, data: recognizedText.trim()),
          );
        }
      } finally {
        ocrService.dispose();
      }
    } catch (e) {
      debugPrint('OCR processing failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text extraction failed')),
        );
      }
    }
  }

  /// Extract text from image file using ML Kit
  Future<String?> _extractTextFromImageFile(File file) async {
    try {
      final ocrService = OCRService();
      try {
        return await ocrService.processImageFile(file);
      } finally {
        ocrService.dispose();
      }
    } catch (e) {
      debugPrint('OCR extraction failed: $e');
      return null;
    }
  }

  /// Handle file as attachment by uploading to Supabase Storage
  Future<void> _handleFileAsAttachment(BuildContext context, String path, List<NoteBlock> blocks) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final filename = path.split('/').last;

      // Upload file using enhanced AttachmentService
      final client = Supabase.instance.client;
      final attachmentData = await _uploadFileToStorage(
        client, 
        filename, 
        bytes,
      );
      
      if (attachmentData != null) {
        blocks.add(
          NoteBlock(type: NoteBlockType.attachment, data: attachmentData),
        );
      }
    } catch (e) {
      debugPrint('Attachment upload failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload attachment: $e')),
        );
      }
    }
  }

  /// Upload file to Supabase Storage using AttachmentService
  Future<AttachmentBlockData?> _uploadFileToStorage(
    SupabaseClient client,
    String filename,
    Uint8List bytes,
  ) async {
    try {
      final attachmentService = AttachmentService(client);
      return await attachmentService.uploadFromBytes(
        filename: filename,
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('Storage upload failed: $e');
      return null;
    }
  }

  /// Create a new note with the processed blocks
  Future<void> _createNoteWithBlocks(
    BuildContext context,
    List<NoteBlock> blocks,
    String defaultTitle,
  ) async {
    if (!context.mounted || blocks.isEmpty) return;

    try {
      // Navigate to edit screen with pre-populated content
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditNoteScreen(
            initialTitle: defaultTitle,
            initialBody: _blocksToInitialBody(blocks),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create note: $e')),
        );
      }
    }
  }

  /// Convert blocks to initial body text for EditNoteScreen
  String _blocksToInitialBody(List<NoteBlock> blocks) {
    final buffer = StringBuffer();
    
    for (final block in blocks) {
              switch (block.type) {
        case NoteBlockType.paragraph:
          buffer.writeln(block.data as String);
        case NoteBlockType.attachment:
          final attachment = block.data as AttachmentBlockData;
          buffer.writeln('![${attachment.filename}](${attachment.url})');
        case NoteBlockType.heading1:
        case NoteBlockType.heading2:
        case NoteBlockType.heading3:
        case NoteBlockType.todo:
        case NoteBlockType.quote:
        case NoteBlockType.code:
        case NoteBlockType.table:
          buffer.writeln(block.data.toString());
      }
      buffer.writeln(); // Add spacing between blocks
    }
    
    return buffer.toString().trim();
  }

  /// Clean up resources
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _intentTextStreamSubscription?.cancel();
  }
}

/// Actions that can be performed on shared images
enum ImageAction {
  attachment,
  ocr,
  both,
}

/// Provider for ShareService
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(ref: ref);
});
