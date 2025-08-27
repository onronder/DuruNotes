import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../providers.dart';
import '../core/parser/note_block_parser.dart';
import '../models/note_block.dart';
import '../services/export_service.dart';
import 'widgets/blocks/block_editor.dart';

/// Simple note editor
class EditNoteScreen extends ConsumerStatefulWidget {
  const EditNoteScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialBody,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;

  @override
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _isLoading = false;
  bool _isPreviewMode = false;
  bool _useBlockEditor = false;
  List<NoteBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    
    // Initialize blocks if we have content
    if (widget.initialBody?.isNotEmpty == true) {
      _blocks = parseMarkdownToBlocks(widget.initialBody!);
    } else {
      _blocks = [createParagraphBlock('')];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(notesRepositoryProvider);
      // Get body content based on current mode
      final String bodyContent;
      if (_useBlockEditor) {
        bodyContent = blocksToMarkdown(_blocks);
      } else {
        bodyContent = _bodyController.text;
      }
      
      await repo.createOrUpdate(
        title: _titleController.text,
        body: bodyContent,
        id: widget.noteId,
      );

      // Refresh the notes list
      ref.read(notesPageProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId != null ? 'Edit Note' : 'New Note'),
        actions: [
          // Block Editor toggle
          IconButton(
            icon: Icon(_useBlockEditor ? Icons.view_agenda : Icons.view_stream),
            onPressed: () {
              setState(() {
                _useBlockEditor = !_useBlockEditor;
                if (_useBlockEditor) {
                  // Convert text to blocks
                  _blocks = parseMarkdownToBlocks(_bodyController.text);
                } else {
                  // Convert blocks to text
                  _bodyController.text = blocksToMarkdown(_blocks);
                }
              });
            },
            tooltip: _useBlockEditor ? 'Switch to Text Editor' : 'Switch to Block Editor',
          ),
          
          // Preview toggle (only for text mode)
          if (!_useBlockEditor)
            IconButton(
              icon: Icon(_isPreviewMode ? Icons.edit : Icons.preview),
              onPressed: () {
                setState(() {
                  _isPreviewMode = !_isPreviewMode;
                });
              },
              tooltip: _isPreviewMode ? 'Edit' : 'Preview',
            ),
            
          // Export button
          if (widget.noteId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.share),
              tooltip: 'Export Note',
              onSelected: (format) => _exportNote(format),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'markdown',
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 16),
                      SizedBox(width: 8),
                      Text('Export as Markdown'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 16),
                      SizedBox(width: 8),
                      Text('Export as PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'html',
                  child: Row(
                    children: [
                      Icon(Icons.web, size: 16),
                      SizedBox(width: 8),
                      Text('Export as HTML'),
                    ],
                  ),
                ),
              ],
            ),
            
          // Save button
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Body field, block editor, or preview
            Expanded(
              child: _useBlockEditor ? _buildBlockEditor() : (_isPreviewMode ? _buildPreview() : _buildEditor()),
            ),
            const SizedBox(height: 16),
            
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNote,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEditor() {
    return TextField(
      controller: _bodyController,
      decoration: const InputDecoration(
        labelText: 'Content (Markdown supported)',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
        helperText: 'Tip: Use # for headings, **bold**, *italic*, - for lists, ``` for code',
        helperMaxLines: 2,
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
    );
  }
  
  Widget _buildPreview() {
    final content = _bodyController.text.isEmpty ? '*No content to preview*' : _bodyController.text;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Markdown(
        data: content,
        selectable: true,
        shrinkWrap: false,
        physics: const AlwaysScrollableScrollPhysics(),
      ),
    );
  }
  
  Widget _buildBlockEditor() {
    return BlockEditor(
      blocks: _blocks,
      onBlocksChanged: (blocks) {
        setState(() {
          _blocks = blocks;
        });
      },
      onBlockFocusChanged: (index) {
        // Handle block focus if needed
      },
    );
  }
  
  void _onNoteSelected(LocalNote note) {
    // Navigate to the selected note
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          noteId: note.id,
          initialTitle: note.title,
          initialBody: note.body,
        ),
      ),
    );
  }

  Future<void> _exportNote(String format) async {
    if (widget.noteId == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Exporting as ${format.toUpperCase()}...'),
            ],
          ),
        ),
      );

      final exportService = ref.read(exportServiceProvider);
      
      // Create current note object
      final currentNote = LocalNote(
        id: widget.noteId!,
        title: _titleController.text,
        body: _useBlockEditor ? blocksToMarkdown(_blocks) : _bodyController.text,
        updatedAt: DateTime.now(),
        deleted: false,
      );

      ExportResult result;

      switch (format) {
        case 'markdown':
          result = await exportService.exportToMarkdown(
            currentNote,
            onProgress: (progress) {
              // Could update progress dialog here
            },
          );
          break;
        case 'pdf':
          result = await exportService.exportToPdf(
            currentNote,
            onProgress: (progress) {
              // Could update progress dialog here
            },
          );
          break;
        case 'html':
          result = await exportService.exportToHtml(
            currentNote,
            onProgress: (progress) {
              // Could update progress dialog here
            },
          );
          break;
        default:
          throw UnsupportedError('Export format not supported: $format');
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result.success && result.file != null) {
        // Show success dialog with options
        _showExportSuccessDialog(result);
      } else {
        // Show error dialog
        _showExportErrorDialog(result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error dialog
      _showExportErrorDialog(e.toString());
    }
  }

  void _showExportSuccessDialog(ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your note has been exported as ${result.format.displayName}.'),
            const SizedBox(height: 8),
            Text('File size: ${_formatFileSize(result.fileSize)}'),
            Text('Processing time: ${result.processingTime.inMilliseconds}ms'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final exportService = ref.read(exportServiceProvider);
              await exportService.openExportedFile(result.file!);
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final exportService = ref.read(exportServiceProvider);
              await exportService.shareExportedFile(result.file!, result.format);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showExportErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Failed'),
        content: Text('Failed to export note: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
