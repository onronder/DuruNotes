import 'dart:convert';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef FolderResolver = Future<String?> Function(String folderName);
typedef FolderNoteIdsResolver = Future<Set<String>> Function(String folderId);

class NoteSearchDelegate extends SearchDelegate<LocalNote?> {
  
  NoteSearchDelegate({
    required this.notes, 
    this.initialQuery,
    this.resolveFolderIdByName,
    this.getFolderNoteIdSet,
    this.autoSearch = false,
  }) {
    if (initialQuery != null) {
      query = initialQuery!;
    }
  }
  final List<LocalNote> notes;
  final String? initialQuery;
  final FolderResolver? resolveFolderIdByName;
  final FolderNoteIdsResolver? getFolderNoteIdSet;
  final bool autoSearch;

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

  Future<List<LocalNote>> _performSearchAsync(String query) async {
    if (query.isEmpty) return [];
    
    // Parse search tokens
    final filters = _parseSearchQuery(query);
    final keywords = filters['keywords'] as String;
    final hasAttachment = filters['hasAttachment'] as bool;
    final typeFilter = filters['type'] as String?;
    final filenameFilter = filters['filename'] as String?;
    final fromEmail = filters['fromEmail'] as bool;
    final fromWeb = filters['fromWeb'] as bool;
    final folderName = filters['folderName'] as String?;
    
    // Handle folder filtering if needed
    Set<String>? folderNoteIds;
    if (folderName != null && resolveFolderIdByName != null && getFolderNoteIdSet != null) {
      final folderId = await resolveFolderIdByName!(folderName);
      if (folderId != null) {
        folderNoteIds = await getFolderNoteIdSet!(folderId);
      }
    }
    
    return notes.where((note) {
      // Check folder filter first
      if (folderNoteIds != null && !folderNoteIds.contains(note.id)) {
        return false;
      }
      
      // Check from:email filter
      if (fromEmail) {
        // First choice: check encrypted metadata source
        if (note.encryptedMetadata != null) {
          try {
            final meta = jsonDecode(note.encryptedMetadata!);
            // Check for both 'email_inbox' (new format) and 'email_in' (old format)
            if (meta['source'] != 'email_inbox' && meta['source'] != 'email_in') {
              // Fallback: check for #Email tag in body
              if (!note.body.contains('#Email')) return false;
            }
          } catch (e) {
            // Fallback: check for #Email tag in body
            if (!note.body.contains('#Email')) return false;
          }
        } else {
          // Fallback: check for #Email tag in body
          if (!note.body.contains('#Email')) return false;
        }
      }
      
      // Check from:web filter
      if (fromWeb) {
        // First choice: check encrypted metadata source
        if (note.encryptedMetadata != null) {
          try {
            final meta = jsonDecode(note.encryptedMetadata!);
            if (meta['source'] != 'web') {
              // Fallback: check for #Web tag in body
              if (!note.body.contains('#Web')) return false;
            }
          } catch (e) {
            // Fallback: check for #Web tag in body
            if (!note.body.contains('#Web')) return false;
          }
        } else {
          // Fallback: check for #Web tag in body
          if (!note.body.contains('#Web')) return false;
        }
      }
      
      // Check attachment filters
      if (hasAttachment || typeFilter != null || filenameFilter != null) {
        final attachments = _getAttachments(note);
        
        // Must have attachments if has:attachment is specified
        if (hasAttachment && attachments.isEmpty) return false;
        
        // Check type filter
        if (typeFilter != null && !_matchesType(attachments, typeFilter)) {
          return false;
        }
        
        // Check filename filter
        if (filenameFilter != null && !_matchesFilename(attachments, filenameFilter)) {
          return false;
        }
      }
      
      // Check keywords in title and body (if any keywords remain after filtering)
      if (keywords.isNotEmpty) {
        final lowerKeywords = keywords.toLowerCase();
        return note.title.toLowerCase().contains(lowerKeywords) ||
               note.body.toLowerCase().contains(lowerKeywords);
      }
      
      // If no keywords but filters matched, include the note
      return true;
    }).toList();
  }
  
  // Keep synchronous version for backward compatibility (without folder filtering)
  List<LocalNote> _performSearch(String query) {
    if (query.isEmpty) return [];
    
    // Parse search tokens
    final filters = _parseSearchQuery(query);
    final keywords = filters['keywords'] as String;
    final hasAttachment = filters['hasAttachment'] as bool;
    final typeFilter = filters['type'] as String?;
    final filenameFilter = filters['filename'] as String?;
    final fromEmail = filters['fromEmail'] as bool;
    final fromWeb = filters['fromWeb'] as bool;
    
    return notes.where((note) {
      // Check from:email filter
      if (fromEmail) {
        // First choice: check encrypted metadata source
        if (note.encryptedMetadata != null) {
          try {
            final meta = jsonDecode(note.encryptedMetadata!);
            // Check for both 'email_inbox' (new format) and 'email_in' (old format)
            if (meta['source'] != 'email_inbox' && meta['source'] != 'email_in') {
              // Fallback: check for #Email tag in body
              if (!note.body.contains('#Email')) return false;
            }
          } catch (e) {
            // Fallback: check for #Email tag in body
            if (!note.body.contains('#Email')) return false;
          }
        } else {
          // Fallback: check for #Email tag in body
          if (!note.body.contains('#Email')) return false;
        }
      }
      
      // Check from:web filter
      if (fromWeb) {
        // First choice: check encrypted metadata source
        if (note.encryptedMetadata != null) {
          try {
            final meta = jsonDecode(note.encryptedMetadata!);
            if (meta['source'] != 'web') {
              // Fallback: check for #Web tag in body
              if (!note.body.contains('#Web')) return false;
            }
          } catch (e) {
            // Fallback: check for #Web tag in body
            if (!note.body.contains('#Web')) return false;
          }
        } else {
          // Fallback: check for #Web tag in body
          if (!note.body.contains('#Web')) return false;
        }
      }
      
      // Check attachment filters
      if (hasAttachment || typeFilter != null || filenameFilter != null) {
        final attachments = _getAttachments(note);
        
        // Must have attachments if has:attachment is specified
        if (hasAttachment && attachments.isEmpty) return false;
        
        // Check type filter
        if (typeFilter != null && !_matchesType(attachments, typeFilter)) {
          return false;
        }
        
        // Check filename filter
        if (filenameFilter != null && !_matchesFilename(attachments, filenameFilter)) {
          return false;
        }
      }
      
      // Check keywords in title and body (if any keywords remain after filtering)
      if (keywords.isNotEmpty) {
        final lowerKeywords = keywords.toLowerCase();
        return note.title.toLowerCase().contains(lowerKeywords) ||
               note.body.toLowerCase().contains(lowerKeywords);
      }
      
      // If no keywords but filters matched, include the note
      return true;
    }).toList();
  }
  
  Map<String, dynamic> _parseSearchQuery(String query) {
    String keywords = query;
    bool hasAttachment = false;
    String? typeFilter;
    String? filenameFilter;
    bool fromEmail = false;
    bool fromWeb = false;
    String? folderName;
    
    // Extract has:attachment (case-insensitive)
    final hasAttachmentRegex = RegExp(r'has:attachment', caseSensitive: false);
    if (hasAttachmentRegex.hasMatch(query)) {
      hasAttachment = true;
      keywords = keywords.replaceAll(hasAttachmentRegex, '').trim();
    }
    
    // Extract from:email (case-insensitive)
    final fromEmailRegex = RegExp(r'from:email', caseSensitive: false);
    if (fromEmailRegex.hasMatch(query)) {
      fromEmail = true;
      keywords = keywords.replaceAll(fromEmailRegex, '').trim();
    }
    
    // Extract from:web (case-insensitive)
    final fromWebRegex = RegExp(r'from:web', caseSensitive: false);
    if (fromWebRegex.hasMatch(query)) {
      fromWeb = true;
      keywords = keywords.replaceAll(fromWebRegex, '').trim();
    }
    
    // Extract folder:"name" or folder:name (case-insensitive)
    final folderQuotedMatch = RegExp(r'folder:"([^"]+)"', caseSensitive: false).firstMatch(query);
    final folderUnquotedMatch = RegExp(r'folder:([^\s]+)', caseSensitive: false).firstMatch(query);
    
    if (folderQuotedMatch != null) {
      folderName = folderQuotedMatch.group(1);
      keywords = keywords.replaceAll(folderQuotedMatch.group(0)!, '').trim();
    } else if (folderUnquotedMatch != null) {
      folderName = folderUnquotedMatch.group(1);
      keywords = keywords.replaceAll(folderUnquotedMatch.group(0)!, '').trim();
    }
    
    // Map "Inbox" to "Incoming Mail" for convenience
    if (folderName?.toLowerCase() == 'inbox') {
      folderName = 'Incoming Mail';
    }
    
    // Extract type:xxx
    final typeMatch = RegExp(r'type:([^\s]+)', caseSensitive: false).firstMatch(query);
    if (typeMatch != null) {
      typeFilter = typeMatch.group(1)?.toLowerCase();
      keywords = keywords.replaceAll(typeMatch.group(0)!, '').trim();
    }
    
    // Extract filename:xxx
    final filenameMatch = RegExp(r'filename:([^\s]+)', caseSensitive: false).firstMatch(query);
    if (filenameMatch != null) {
      filenameFilter = filenameMatch.group(1)?.toLowerCase();
      keywords = keywords.replaceAll(filenameMatch.group(0)!, '').trim();
    }
    
    return {
      'keywords': keywords,
      'hasAttachment': hasAttachment,
      'type': typeFilter,
      'filename': filenameFilter,
      'fromEmail': fromEmail,
      'fromWeb': fromWeb,
      'folderName': folderName,
    };
  }
  
  List<Map<String, dynamic>> _getAttachments(LocalNote note) {
    // First check metadata for attachments
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        final files = (meta['attachments']?['files'] as List?) ?? 
                     (meta['attachments'] as List?) ?? [];
        if (files.isNotEmpty) {
          return files.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        // Continue to fallback
      }
    }
    
    // Fallback: check if note has #Attachment tag
    if (note.body.contains('#Attachment')) {
      // Return a dummy attachment to indicate presence
      return [{'type': 'unknown', 'filename': 'attachment'}];
    }
    
    return [];
  }
  
  bool _matchesType(List<Map<String, dynamic>> attachments, String typeFilter) {
    if (attachments.isEmpty) return false;
    
    for (final attachment in attachments) {
      final mimeType = (attachment['type'] as String?) ?? '';
      final filename = (attachment['filename'] as String?) ?? '';
      
      // Check common type mappings
      switch (typeFilter) {
        case 'pdf':
          if (mimeType.contains('pdf') || filename.toLowerCase().endsWith('.pdf')) {
            return true;
          }
          break;
        case 'image':
          if (mimeType.startsWith('image/') || 
              RegExp(r'\.(png|jpg|jpeg|gif|bmp|webp|svg)$', caseSensitive: false)
                  .hasMatch(filename)) {
            return true;
          }
          break;
        case 'video':
          if (mimeType.startsWith('video/') || 
              RegExp(r'\.(mp4|avi|mov|wmv|flv|mkv|webm)$', caseSensitive: false)
                  .hasMatch(filename)) {
            return true;
          }
          break;
        case 'audio':
          if (mimeType.startsWith('audio/') || 
              RegExp(r'\.(mp3|wav|flac|aac|ogg|wma|m4a)$', caseSensitive: false)
                  .hasMatch(filename)) {
            return true;
          }
          break;
        case 'excel':
          if (mimeType.contains('excel') || mimeType.contains('spreadsheet') ||
              RegExp(r'\.(xls|xlsx|csv)$', caseSensitive: false).hasMatch(filename)) {
            return true;
          }
          break;
        case 'word':
          if (mimeType.contains('word') || mimeType.contains('document') ||
              RegExp(r'\.(doc|docx)$', caseSensitive: false).hasMatch(filename)) {
            return true;
          }
          break;
        case 'zip':
          if (mimeType.contains('zip') || mimeType.contains('compressed') ||
              RegExp(r'\.(zip|rar|7z|tar|gz)$', caseSensitive: false).hasMatch(filename)) {
            return true;
          }
          break;
        default:
          // Generic type matching
          if (mimeType.toLowerCase().contains(typeFilter) || 
              filename.toLowerCase().contains(typeFilter)) {
            return true;
          }
      }
    }
    
    return false;
  }
  
  bool _matchesFilename(List<Map<String, dynamic>> attachments, String filenameFilter) {
    if (attachments.isEmpty) return false;
    
    for (final attachment in attachments) {
      final filename = (attachment['filename'] as String?) ?? '';
      if (filename.toLowerCase().contains(filenameFilter)) {
        return true;
      }
    }
    
    return false;
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
    // If autoSearch is enabled and we have an initial query, show results immediately
    // This should trigger for has:attachment, from:email, from:web
    if (autoSearch && query.isNotEmpty) {
      // Always show results when autoSearch is enabled
      return buildResults(context);
    }
    
    // If we have a query but it's not auto-search, still show results
    if (query.isNotEmpty) {
      return buildResults(context);
    }
    
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

  @override
  Widget buildResults(BuildContext context) {
    // Check if we need async search (has folder filter)
    final filters = _parseSearchQuery(query);
    final needsAsync = filters['folderName'] != null && 
                       resolveFolderIdByName != null && 
                       getFolderNoteIdSet != null;
    
    if (needsAsync) {
      // Use async search with FutureBuilder
      return FutureBuilder<List<LocalNote>>(
        future: _performSearchAsync(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final results = snapshot.data ?? [];
          return _buildResultsList(context, results);
        },
      );
    } else {
      // Use synchronous search for backward compatibility
      final results = _performSearch(query);
      return _buildResultsList(context, results);
    }
  }
  
  Widget _buildResultsList(BuildContext context, List<LocalNote> results) {
    // Parse the query to show what filter is active
    String filterDescription = '';
    if (query.contains('has:attachment')) {
      filterDescription = 'Notes with Attachments';
    } else if (query.contains('from:email')) {
      filterDescription = 'Email Notes';
    } else if (query.contains('from:web')) {
      filterDescription = 'Web Clips';
    } else if (query.isNotEmpty) {
      filterDescription = 'Search Results';
    }
    
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
              filterDescription.isNotEmpty 
                  ? 'No $filterDescription found'
                  : 'Try different keywords',
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
        if (filterDescription.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            child: Row(
              children: [
                Icon(
                  query.contains('has:attachment') ? Icons.attach_file :
                  query.contains('from:email') ? Icons.email :
                  query.contains('from:web') ? Icons.language :
                  Icons.search,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  filterDescription,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${results.length} ${results.length == 1 ? 'note' : 'notes'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
