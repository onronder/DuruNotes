import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../providers.dart';
import '../core/parser/note_block_parser.dart';
import '../models/note_block.dart';
import '../services/export_service.dart';
import 'widgets/blocks/block_editor.dart';

/// Enhanced note editor with improved UX
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

class _EditNoteScreenState extends ConsumerState<EditNoteScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  bool _isPreviewMode = false;
  bool _useBlockEditor = false;
  bool _hasChanges = false;
  bool _isAutoSaving = false;
  List<NoteBlock> _blocks = [];
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();
  DateTime? _lastAutoSave;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    
    // Initialize blocks if we have content
    if (widget.initialBody?.isNotEmpty == true) {
      _blocks = parseMarkdownToBlocks(widget.initialBody!);
    } else {
      _blocks = [createParagraphBlock('')];
    }
    
    // Add listeners for auto-save
    _titleController.addListener(_onContentChanged);
    _bodyController.addListener(_onContentChanged);
    
    // Auto-focus title for new notes
    if (widget.noteId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onContentChanged);
    _bodyController.removeListener(_onContentChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    // Auto-save after 2 seconds of inactivity
    Future.delayed(const Duration(seconds: 2), () {
      if (_hasChanges && mounted && !_isLoading) {
        final now = DateTime.now();
        if (_lastAutoSave == null || 
            now.difference(_lastAutoSave!).inSeconds > 2) {
          _autoSave();
        }
      }
    });
  }

  Future<void> _autoSave() async {
    if (!_hasChanges || _isLoading) return;
    
    setState(() {
      _isAutoSaving = true;
    });
    
    try {
      final repo = ref.read(notesRepositoryProvider);
      final String bodyContent = _useBlockEditor 
          ? blocksToMarkdown(_blocks)
          : _bodyController.text;
      
      await repo.createOrUpdate(
        title: _titleController.text,
        body: bodyContent,
        id: widget.noteId,
      );
      
      _lastAutoSave = DateTime.now();
      _hasChanges = false;
      
      if (mounted) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Silent fail for auto-save
    } finally {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
      }
    }
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
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldPop = await _showUnsavedChangesDialog();
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Row(
              key: ValueKey(_isAutoSaving),
              children: [
                Text(widget.noteId != null ? 'Edit Note' : 'New Note'),
                if (_isAutoSaving) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.green),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Saving...',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ] else if (_hasChanges) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Enhanced title field with better styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Note Title',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    _bodyFocusNode.requestFocus();
                  },
                ),
              ),
              
              // Formatting toolbar (when not in block editor mode)
              if (!_useBlockEditor && !_isPreviewMode)
                _buildFormattingToolbar(),
              
              // Body field, block editor, or preview
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _useBlockEditor 
                      ? _buildBlockEditor() 
                      : (_isPreviewMode ? _buildPreview() : _buildEnhancedEditor()),
                ),
              ),
              
              // Bottom action bar
              _buildBottomActionBar(),
            ],
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }
  
  Widget _buildEnhancedEditor() {
    return Container(
      key: const ValueKey('text_editor'),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _bodyController,
        focusNode: _bodyFocusNode,
        decoration: InputDecoration(
          hintText: 'Start writing...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.6,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _buildFormatButton(Icons.format_bold, 'Bold', () => _insertMarkdown('**', '**')),
            _buildFormatButton(Icons.format_italic, 'Italic', () => _insertMarkdown('*', '*')),
            _buildFormatButton(Icons.title, 'Heading', () => _insertMarkdown('## ', '')),
            _buildFormatButton(Icons.format_list_bulleted, 'List', () => _insertMarkdown('\n- ', '')),
            _buildFormatButton(Icons.checklist, 'Checklist', () => _insertMarkdown('\n- [ ] ', '')),
            _buildFormatButton(Icons.code, 'Code', () => _insertMarkdown('`', '`')),
            _buildFormatButton(Icons.link, 'Link', () => _insertMarkdown('[', '](url)')),
            _buildFormatButton(Icons.format_quote, 'Quote', () => _insertMarkdown('\n> ', '')),
            const VerticalDivider(width: 16),
            _buildFormatButton(Icons.undo, 'Undo', _undo),
            _buildFormatButton(Icons.redo, 'Redo', _redo),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      padding: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(minWidth: 40),
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix${text.substring(selection.start, selection.end)}$suffix',
    );
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length,
      ),
    );
  }

  void _undo() {
    // Placeholder for undo functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Undo feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _redo() {
    // Placeholder for redo functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redo feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  Widget _buildPreview() {
    final content = _bodyController.text.isEmpty ? '*No content to preview*' : _bodyController.text;
    return Container(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: content,
        selectable: true,
        shrinkWrap: false,
        physics: const AlwaysScrollableScrollPhysics(),
        styleSheet: MarkdownStyleSheet(
          h1: Theme.of(context).textTheme.headlineLarge,
          h2: Theme.of(context).textTheme.headlineMedium,
          h3: Theme.of(context).textTheme.headlineSmall,
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          code: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            fontFamily: 'monospace',
          ),
          blockquote: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
  
  Widget _buildBlockEditor() {
    return Container(
      key: const ValueKey('block_editor'),
      child: BlockEditor(
        blocks: _blocks,
        onBlocksChanged: (blocks) {
          setState(() {
            _blocks = blocks;
            _hasChanges = true;
          });
          _scheduleAutoSave();
        },
        onBlockFocusChanged: (index) {
          // Handle block focus if needed
        },
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Word count
            Expanded(
              child: Text(
                _getWordCount(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Save status
            if (_hasChanges && !_isAutoSaving)
              TextButton.icon(
                onPressed: _isLoading ? null : _saveNote,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              )
            else if (!_hasChanges)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Saved',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_isPreviewMode || _useBlockEditor) return null;
    
    return FloatingActionButton.small(
      onPressed: () {
        HapticFeedback.lightImpact();
        _showQuickActions();
      },
      tooltip: 'Quick Actions',
      child: const Icon(Icons.add),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Add Image'),
              onTap: () {
                Navigator.pop(context);
                _insertMarkdown('![Image](', ')');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Add Table'),
              onTap: () {
                Navigator.pop(context);
                _insertMarkdown(
                  '\n| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1   | Cell 2   |\n',
                  '',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.horizontal_rule),
              title: const Text('Add Divider'),
              onTap: () {
                Navigator.pop(context);
                _insertMarkdown('\n---\n', '');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_off),
              title: const Text('Add Code Block'),
              onTap: () {
                Navigator.pop(context);
                _insertMarkdown('\n```\n', '\n```\n');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getWordCount() {
    final text = _useBlockEditor 
        ? blocksToMarkdown(_blocks)
        : _bodyController.text;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = text.length;
    return '$words words • $chars characters';
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _saveNote();
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
