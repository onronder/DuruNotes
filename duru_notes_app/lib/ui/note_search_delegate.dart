import 'package:flutter/material.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/services/analytics/analytics_service.dart';
import 'package:duru_notes_app/services/analytics/analytics_sentry.dart';

class NoteSearchDelegate extends SearchDelegate<LocalNote?> {
  NoteSearchDelegate({required this.db});

  final AppDb db;
  int _token = 0; // yarış durumlarını atlamak için

  @override
  String? get searchFieldLabel => 'Search notes or #tags...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
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
      IconButton(
        icon: const Icon(Icons.tag),
        tooltip: 'Browse tags',
        onPressed: () {
          // This could navigate to tags screen or show tag picker
          close(context, null);
        },
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

  Future<List<LocalNote>> _doSearch(String q, int myToken) async {
    // Track search attempt
    analytics.startTiming('search_query');
    analytics.event(AnalyticsEvents.searchPerformed, properties: {
      AnalyticsProperties.searchQuery: q.length.toString() + ' characters',
      AnalyticsProperties.searchQueryLength: q.length,
      'is_tag_search': q.startsWith('#'),
      'is_empty_query': q.trim().isEmpty,
    });
    
    logger.info('Search performed', data: {
      'query_length': q.length,
      'is_tag_search': q.startsWith('#'),
    });
    
    final res = await db.searchNotes(q);
    
    // Track search results
    analytics.endTiming('search_query', properties: {
      AnalyticsProperties.searchResultCount: res.length,
      AnalyticsProperties.searchQueryLength: q.length,
    });
    
    analytics.event(AnalyticsEvents.searchResults, properties: {
      AnalyticsProperties.searchResultCount: res.length,
      AnalyticsProperties.searchQueryLength: q.length,
      'has_results': res.isNotEmpty,
    });
    
    logger.breadcrumb('Search completed', data: {
      'result_count': res.length,
      'query_length': q.length,
    });
    
    // Eski isteklerin sonuçlarını yut
    if (myToken != _token) return const <LocalNote>[];
    return res;
  }

  Future<List<String>> _getTagSuggestions(String q) async {
    if (!q.startsWith('#') || q.length < 2) return [];
    final tagPrefix = q.substring(1);
    return await db.searchTags(tagPrefix);
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
    String preview = limitedBody
        .replaceAll(RegExp(r'#{1,6}\s'), '') // Remove headers
        .replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'$1') // Remove bold (non-greedy)
        .replaceAll(RegExp(r'\*([^*]*)\*'), r'$1') // Remove italic (non-greedy)
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1') // Remove code (non-greedy)
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
    ++_token;
    
    // If query starts with #, show tag suggestions
    if (query.startsWith('#')) {
      return FutureBuilder<List<String>>(
        future: _getTagSuggestions(query),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                height: 24, 
                width: 24, 
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          
          final tags = snap.data ?? <String>[];
          if (tags.isEmpty && query.length > 1) {
            return const Center(
              child: Text('No matching tags'),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tags.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (_, i) {
              final tag = tags[i];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.tag,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text('#$tag'),
                subtitle: const Text('Tap to search this tag'),
                onTap: () {
                  query = '#$tag';
                  showResults(context);
                },
              );
            },
          );
        },
      );
    }
    
    // Regular note suggestions
    return FutureBuilder<List<LocalNote>>(
      future: db.suggestNotesByTitlePrefix(query, limit: 8),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              height: 24, 
              width: 24, 
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        final items = snap.data ?? <LocalNote>[];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No suggestions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching for #tags or note content',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (_, i) {
            final note = items[i];
            final preview = _generatePreview(note.body);
            
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  if (preview != '(No content)') ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(note.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              onTap: () {
                // Track search result click
                analytics.event(AnalyticsEvents.searchResultClicked, properties: {
                  'note_id': note.id,
                  'search_query_length': query.length,
                  'result_position': items.indexOf(note) + 1,
                  'total_results': items.length,
                  'note_has_title': note.title.trim().isNotEmpty,
                });
                
                logger.breadcrumb('Search result clicked', data: {
                  'note_id': note.id,
                  'result_position': items.indexOf(note) + 1,
                  'total_results': items.length,
                });
                
                close(context, note);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final myToken = ++_token;
    return FutureBuilder<List<LocalNote>>(
      future: _doSearch(query, myToken),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final items = snap.data ?? <LocalNote>[];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or search for #tags',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final note = items[i];
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
                onTap: () {
                  // Track search result click
                  analytics.event(AnalyticsEvents.searchResultClicked, properties: {
                    'note_id': note.id,
                    'search_query_length': query.length,
                    'result_position': items.indexOf(note) + 1,
                    'total_results': items.length,
                    'note_has_title': note.title.trim().isNotEmpty,
                    'context': 'results',
                  });
                  
                  logger.breadcrumb('Search result clicked', data: {
                    'note_id': note.id,
                    'result_position': items.indexOf(note) + 1,
                    'total_results': items.length,
                  });
                  
                  close(context, note);
                },
              ),
            );
          },
        );
      },
    );
  }
}
