import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Note edit screen for creating or editing notes
/// This is a wrapper that integrates with the existing note editing infrastructure
class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialBody,
    this.folderId,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;
  final String? folderId;

  static Future<void> navigate(
    BuildContext context, {
    String? noteId,
    String? title,
    String? body,
    String? folderId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(
          noteId: noteId,
          initialTitle: title,
          initialBody: body,
          folderId: folderId,
        ),
      ),
    );
  }

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _isLoading = false;
  bool _hasChanges = false;
  LocalNote? _note;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    
    if (widget.noteId != null) {
      _loadNote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(notesRepositoryProvider);
      final note = await repository.getNoteById(widget.noteId!);
      
      if (note != null && mounted) {
        setState(() {
          _note = note;
          _titleController.text = note.title;
          _bodyController.text = note.body;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(notesRepositoryProvider);
      
      if (_note != null) {
        // Update existing note
        await repository.updateNote(
          _note!.id,
          title: title,
          body: body,
        );
      } else {
        // Create new note
        await repository.createNote(
          title: title,
          body: body,
          folderId: widget.folderId,
        );
      }
      
      setState(() => _hasChanges = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save your changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () async {
              await _saveNote();
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_note != null ? 'Edit Note' : 'New Note'),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isLoading ? null : _saveNote,
              ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                if (_note != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                  ),
                ),
              ],
              onSelected: (value) async {
                switch (value) {
                  case 'delete':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Note'),
                        content: const Text('Are you sure you want to delete this note?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true && _note != null) {
                      final repository = ref.read(notesRepositoryProvider);
                      await repository.deleteNote(_note!.id);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                    break;
                    
                  case 'share':
                    // Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                    break;
                }
              },
            ),
          ],
        ),
        body: _isLoading && _note == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                    ),
                    const Divider(),
                    Expanded(
                      child: TextField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          hintText: 'Start writing...',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: _hasChanges
            ? FloatingActionButton(
                onPressed: _isLoading ? null : _saveNote,
                child: const Icon(Icons.save),
              )
            : null,
      ),
    );
  }
}
