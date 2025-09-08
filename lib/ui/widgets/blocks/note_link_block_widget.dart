import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteLinkBlockWidget extends ConsumerStatefulWidget {
  const NoteLinkBlockWidget({
    required this.block, required this.isFocused, required this.onChanged, required this.onFocusChanged, required this.onNoteSelected, super.key,
  });

  final NoteBlock block;
  final bool isFocused;
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;
  final Function(LocalNote) onNoteSelected;

  @override
  ConsumerState<NoteLinkBlockWidget> createState() => _NoteLinkBlockWidgetState();
}

class _NoteLinkBlockWidgetState extends ConsumerState<NoteLinkBlockWidget> {
  late String _linkedNoteId;
  bool _isSelecting = false;
  LocalNote? _linkedNote;

  @override
  void initState() {
    super.initState();
    _parseNoteLinkData();
    _loadLinkedNote();
  }

  @override
  void didUpdateWidget(NoteLinkBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.block.data != oldWidget.block.data) {
      _parseNoteLinkData();
      _loadLinkedNote();
    }
  }

  void _parseNoteLinkData() {
    // Format: "noteId"
    _linkedNoteId = widget.block.data;
  }

  Future<void> _loadLinkedNote() async {
    if (_linkedNoteId.isNotEmpty) {
      try {
        final notesRepository = ref.read(notesRepositoryProvider);
        final note = await notesRepository.getNote(_linkedNoteId);
        if (mounted) {
          setState(() {
            _linkedNote = note;
          });
        }
      } catch (e) {
        // Note not found or error
        if (mounted) {
          setState(() {
            _linkedNote = null;
          });
        }
      }
    }
  }

  void _updateNoteLink(String noteId) {
    final newBlock = widget.block.copyWith(data: noteId);
    widget.onChanged(newBlock);
    _linkedNoteId = noteId;
    _loadLinkedNote();
  }

  void _showNoteSelector() {
    setState(() {
      _isSelecting = true;
    });
  }

  void _hideNoteSelector() {
    setState(() {
      _isSelecting = false;
    });
  }

  void _selectNote(LocalNote note) {
    _updateNoteLink(note.id);
    _hideNoteSelector();
  }

  void _openLinkedNote() {
    if (_linkedNote != null) {
      widget.onNoteSelected(_linkedNote!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelecting) {
      return _buildNoteSelector();
    } else if (_linkedNote != null) {
      return _buildLinkedNoteView();
    } else {
      return _buildEmptyLinkView();
    }
  }

  Widget _buildLinkedNoteView() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _openLinkedNote,
        onLongPress: _showNoteSelector,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purple.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.purple.shade50,
          ),
          child: Row(
            children: [
              Icon(
                Icons.note,
                size: 20,
                color: Colors.purple.shade600,
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _linkedNote!.title.isNotEmpty 
                          ? _linkedNote!.title 
                          : 'Untitled Note',
                      style: TextStyle(
                        color: Colors.purple.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_linkedNote!.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _linkedNote!.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Updated ${_formatDate(_linkedNote!.updatedAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    onPressed: _openLinkedNote,
                    tooltip: 'Open note',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: _showNoteSelector,
                    tooltip: 'Change linked note',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLinkView() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _showNoteSelector,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.note_add,
                size: 20,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Text(
                  'Link to another note...',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.purple.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.note, size: 16, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Select a note to link',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.purple.shade700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _hideNoteSelector,
                ),
              ],
            ),
          ),
          
                      // Notes List - Simple placeholder for now
            SizedBox(
              height: 200,
              child: Consumer(
                builder: (context, ref, child) {
                  final notesAsync = ref.watch(currentNotesProvider);
                  
                  // Simple list handling without .when method
                  final notes = notesAsync;
                  if (notes.isEmpty) {
                    return const Center(
                      child: Text('No notes available'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return ListTile(
                        leading: const Icon(Icons.note, size: 16),
                        title: Text(
                          note.title.isNotEmpty ?? false ? note.title : 'Untitled',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: note.body.isNotEmpty ?? false
                            ? Text(
                                note.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => _selectNote(note),
                        dense: true,
                      );
                    },
                  );
                                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
