import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoteSearchDelegate extends SearchDelegate<LocalNote?> {
  
  NoteSearchDelegate({required this.notes});
  final List<LocalNote> notes;

  @override
  String? get searchFieldLabel => 'Search notes...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear',
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  List<LocalNote> _performSearch(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    return notes.where((note) {
      return note.title.toLowerCase().contains(lowerQuery) ||
             note.body.toLowerCase().contains(lowerQuery);
    }).toList();
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
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _performSearch(query);
    
    if (query.isEmpty) {
      // Show recent notes when no query
      final recentNotes = notes.take(5).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Recent Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: recentNotes.length,
              itemBuilder: (context, index) {
                final note = recentNotes[index];
                return _buildNoteListTile(context, note, isRecent: true);
              },
            ),
          ),
        ],
      );
    }
    
    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No notes found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final note = suggestions[index];
        return _buildNoteListTile(context, note);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _performSearch(query);
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${results.length} results for "$query"',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final note = results[index];
              return _buildResultCard(context, note, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoteListTile(BuildContext context, LocalNote note, {bool isRecent = false}) {
    final preview = _generatePreview(note.body);
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isRecent 
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getNoteIcon(note),
          size: 20,
          color: isRecent
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        note.title.isEmpty ? '(Untitled)' : note.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.isNotEmpty && preview != '(No content)') ...[
            const SizedBox(height: 4),
            Text(
              preview,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatDate(note.updatedAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        close(context, note);
      },
    );
  }

  Widget _buildResultCard(BuildContext context, LocalNote note, int index) {
    final preview = _generatePreview(note.body);
    // Highlight search terms in the preview
    final highlightedPreview = _highlightSearchTerms(context, preview, query);
    
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          close(context, note);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getNoteIcon(note),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? '(Untitled)' : note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty && preview != '(No content)') ...[
                const SizedBox(height: 12),
                RichText(
                  text: highlightedPreview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(note.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _highlightSearchTerms(BuildContext context, String text, String searchQuery) {
    if (searchQuery.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    
    var start = 0;
    var index = lowerText.indexOf(lowerQuery, start);
    
    while (index != -1 && start < text.length) {
      // Add non-highlighted text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ));
      
      start = index + searchQuery.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ));
    }
    
    return TextSpan(children: spans);
  }

  IconData _getNoteIcon(LocalNote note) {
    final body = note.body.toLowerCase();
    if (body.contains('- [ ]') || body.contains('- [x]')) {
      return Icons.checklist;
    } else if (body.contains('```')) {
      return Icons.code;
    } else if (body.contains('http://') || body.contains('https://')) {
      return Icons.link;
    } else if (body.contains('![')) {
      return Icons.image;
    }
    return Icons.note;
  }
}
