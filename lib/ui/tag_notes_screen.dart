import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:duru_notes/ui/widgets/error_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagNotesScreen extends ConsumerStatefulWidget {
  const TagNotesScreen({
    required this.tag, 
    this.savedSearchKey,
    super.key,
  });
  
  final String tag;
  /// Optional saved search key for authoritative filtering
  final String? savedSearchKey;

  @override
  ConsumerState<TagNotesScreen> createState() => _TagNotesScreenState();
}

class _TagNotesScreenState extends ConsumerState<TagNotesScreen> {
  bool _isLoading = true;
  List<LocalNote> _notes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(notesRepositoryProvider);
      
      // Use authoritative search if savedSearchKey is provided
      final notes = widget.savedSearchKey != null
          ? await ref.read(appDbProvider).notesForSavedSearch(savedSearchKey: widget.savedSearchKey!)
          : await repo.queryNotesByTags(
              anyTags: [widget.tag],
              noneTags: const [],
              sort: const SortSpec(), // Default sort with pinned first
            );
      
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Cache for preview generation to avoid repeated regex processing
  static final Map<String, String> _previewCache = <String, String>{};
  
  String _generatePreview(String body) {
    if (body.trim().isEmpty) return '(No content)';
    
    // Check cache first
    final bodyHash = body.hashCode.toString();
    if (_previewCache.containsKey(bodyHash)) {
      return _previewCache[bodyHash]!;
    }
    
    // Limit input length to prevent long processing
    final limitedBody = body.length > 300 ? body.substring(0, 300) : body;
    
    // Strip markdown formatting for cleaner preview (optimized)
    final preview = limitedBody
        .replaceAll(RegExp(r'#{1,6}\s'), '') // Remove headers
        .replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'$1') // Remove bold (non-greedy)
        .replaceAll(RegExp(r'\*([^*]*)\*'), r'$1') // Remove italic (non-greedy)
        .replaceAll(RegExp('`([^`]*)`'), r'$1') // Remove code (non-greedy)
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1') // Remove links (non-greedy)
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();

    final result = preview.isEmpty ? '(No content)' : 
        (preview.length > 100 ? '${preview.substring(0, 100)}...' : preview);
    
    // Cache result (limit cache size)
    if (_previewCache.length > 50) {
      _previewCache.clear();
    }
    _previewCache[bodyHash] = result;
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.tag}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ModernEditNoteScreen(),
            ),
          );
          // Refresh notes after returning from editor
          _loadNotes();
        },
        tooltip: 'Create note with #${widget.tag}',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingDisplay();
    }

    if (_error != null) {
      return ErrorDisplay(
        error: _error!,
        message: 'Failed to load notes',
        onRetry: _loadNotes,
      );
    }

    if (_notes.isEmpty) {
      // Provide friendly empty state messages based on the tag
      String title;
      String subtitle;
      IconData icon;
      
      switch (widget.tag.toLowerCase()) {
        case 'attachment':
          title = 'No notes with #Attachment yet';
          subtitle = 'Notes with file attachments will appear here';
          icon = Icons.attach_file;
          break;
        case 'web':
          title = 'No notes created via Web Clipper yet';
          subtitle = 'Use the Web Clipper extension to save content from the web';
          icon = Icons.language;
          break;
        case 'email':
          title = 'No notes created via Email-in yet';
          subtitle = 'Send emails to your Duru Notes inbox to create notes';
          icon = Icons.email;
          break;
        default:
          title = 'No notes with #${widget.tag}';
          subtitle = 'Create a note and add #${widget.tag} to see it here';
          icon = Icons.tag;
      }
      
      return EmptyDisplay(
        title: title,
        subtitle: subtitle,
        icon: icon,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final note = _notes[i];
          final preview = _generatePreview(note.body);
          
          return Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                note.title.isEmpty ? '(Untitled)' : note.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview != '(No content)') ...[
                    const SizedBox(height: 8),
                    Text(
                      preview,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(note.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModernEditNoteScreen(
                      noteId: note.id,
                    ),
                  ),
                );
                // Refresh notes after returning from editor
                _loadNotes();
              },
            ),
          );
        },
      ),
    );
  }
}
