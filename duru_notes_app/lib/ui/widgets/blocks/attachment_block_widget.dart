import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/note_block.dart';
import '../../../services/attachment_service.dart';
import '../attachment_image.dart';

/// Widget for rendering and editing attachment blocks.
/// 
/// This widget handles:
/// - File attachment display with appropriate icons
/// - Image preview capabilities with caching
/// - File metadata display (name, size, type)
/// - Attachment editing and replacement
/// - Block deletion functionality
class AttachmentBlockWidget extends StatelessWidget {
  const AttachmentBlockWidget({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onDelete,
  });

  /// The attachment block being edited
  final NoteBlock block;
  
  /// Callback when the block content changes
  final ValueChanged<NoteBlock> onChanged;
  
  /// Callback when the block should be deleted
  final VoidCallback onDelete;

  AttachmentBlockData get _attachmentData => block.data as AttachmentBlockData;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attachment header with file info and actions
          _buildAttachmentHeader(context),
          
          // Preview content
          if (_isImageFile(_attachmentData.filename))
            _buildImagePreview(context)
          else
            _buildFilePreview(context),
          
          // Action buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildAttachmentHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            _getFileIcon(_attachmentData.filename),
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _attachmentData.filename.isNotEmpty 
                      ? _attachmentData.filename 
                      : 'Untitled attachment',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_attachmentData.url.isNotEmpty)
                  Text(
                    _getFileTypeAndSize(_attachmentData.filename),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete attachment',
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    if (_attachmentData.url.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AttachmentImage(
          url: _attachmentData.url,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getFileIcon(_attachmentData.filename),
                size: 32,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 4),
              Text(
                _getFileExtension(_attachmentData.filename).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Edit/Replace button
          TextButton.icon(
            onPressed: () => _editAttachment(context),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 8),
          
          // View/Download button
          if (_attachmentData.url.isNotEmpty)
            TextButton.icon(
              onPressed: () => _viewAttachment(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View'),
            ),
          
          const Spacer(),
          
          // Replace button
          OutlinedButton.icon(
            onPressed: () => _replaceAttachment(context),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  void _editAttachment(BuildContext context) async {
    final filenameController = TextEditingController(text: _attachmentData.filename);
    final urlController = TextEditingController(text: _attachmentData.url);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Attachment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: filenameController,
              decoration: const InputDecoration(
                labelText: 'File name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final updated = _attachmentData.copyWith(
        filename: filenameController.text,
        url: urlController.text,
      );
      final updatedBlock = block.copyWith(data: updated);
      onChanged(updatedBlock);
    }
    
    filenameController.dispose();
    urlController.dispose();
  }

  void _viewAttachment(BuildContext context) {
    if (_attachmentData.url.isEmpty) return;
    
    if (_isImageFile(_attachmentData.filename)) {
      // Show image in full screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AttachmentViewer(url: _attachmentData.url),
        ),
      );
    } else {
      // Open URL externally (would need url_launcher package)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${_attachmentData.filename}...'),
          action: SnackBarAction(
            label: 'Copy URL',
            onPressed: () {
              // Copy URL to clipboard
            },
          ),
        ),
      );
    }
  }

  void _replaceAttachment(BuildContext context) async {
    final client = Supabase.instance.client;
    final service = AttachmentService(client);
    
    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      },
    );

    try {
      final newAttachment = await service.pickAndUpload();
      
      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (newAttachment != null && context.mounted) {
        final updatedBlock = block.copyWith(data: newAttachment);
        onChanged(updatedBlock);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment replaced successfully')),
        );
      }
      
    } catch (e) {
      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace attachment: $e')),
        );
      }
    }
  }

  bool _isImageFile(String filename) {
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    final extension = _getFileExtension(filename);
    return imageExtensions.contains(extension);
  }

  String _getFileExtension(String filename) {
    return filename.split('.').last.toLowerCase();
  }

  String _getFileTypeAndSize(String filename) {
    final extension = _getFileExtension(filename);
    return extension.toUpperCase();
  }

  IconData _getFileIcon(String filename) {
    final extension = _getFileExtension(filename);
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart;
      case 'pptx':
      case 'ppt':
        return Icons.slideshow;
      default:
        return Icons.attach_file;
    }
  }
}

/// Widget for compact attachment display in previews.
class AttachmentBlockPreview extends StatelessWidget {
  const AttachmentBlockPreview({
    super.key,
    required this.attachmentData,
    this.showPreview = true,
  });

  /// The attachment data to display
  final AttachmentBlockData attachmentData;
  
  /// Whether to show image previews
  final bool showPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _getFileIcon(attachmentData.filename),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attachmentData.filename.isNotEmpty 
                    ? attachmentData.filename 
                    : 'Attachment',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.attach_file;
    }
  }
}
