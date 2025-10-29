import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/note_link_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade link dialog screen with tab support for note links and web links
///
/// Features:
/// - Tab navigation between "Note Links" and "Web Links"
/// - Real-time search for notes using NoteLinkParser
/// - Web link creation with URL and text fields
/// - Material 3 design with proper theming
/// - Production-grade error handling
class LinkDialogScreen extends StatefulWidget {
  const LinkDialogScreen({
    super.key,
    required this.initialText,
    required this.linkParser,
    required this.notesRepository,
    required this.onInsertLink,
  });

  final String initialText;
  final NoteLinkParser linkParser;
  final INotesRepository notesRepository;
  final void Function(String linkMarkdown) onInsertLink;

  @override
  State<LinkDialogScreen> createState() => _LinkDialogScreenState();
}

class _LinkDialogScreenState extends State<LinkDialogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _linkTextController = TextEditingController();
  final AppLogger _logger = LoggerFactory.instance;

  List<domain.Note> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _linkTextController.text = widget.initialText;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _urlController.dispose();
    _linkTextController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _error = null;
      });
      return;
    }

    _searchNotes(query);
  }

  Future<void> _searchNotes(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await widget.linkParser.searchNotesByTitle(
        query,
        widget.notesRepository,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to search notes for link dialog',
        error: error,
        stackTrace: stackTrace,
        data: {'query': query, 'limit': 20},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() {
          _error = 'Failed to search notes';
          _isSearching = false;
        });
      }
    }
  }

  void _insertNoteLink(domain.Note note) {
    // Insert note link in @[title] format
    final linkMarkdown = '@[${note.title}]';
    widget.onInsertLink(linkMarkdown);
    Navigator.of(context).pop();
  }

  void _insertWebLink() {
    final url = _urlController.text.trim();
    final text = _linkTextController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _error = 'URL is required';
      });
      return;
    }

    // Insert markdown link [text](url)
    final linkText = text.isEmpty ? url : text;
    final linkMarkdown = '[$linkText]($url)';
    widget.onInsertLink(linkMarkdown);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insert Link'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Note Links', icon: Icon(Icons.note_outlined, size: 20)),
            Tab(text: 'Web Links', icon: Icon(Icons.link, size: 20)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildNoteLinkTab(theme, colorScheme),
            _buildWebLinkTab(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteLinkTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            autofocus: true,
          ),
        ),

        // Search results
        Expanded(
          child: _buildNoteSearchResults(theme, colorScheme),
        ),
      ],
    );
  }

  Widget _buildNoteSearchResults(ThemeData theme, ColorScheme colorScheme) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching notes...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Type to search for notes',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No notes found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final note = _searchResults[index];
        return _buildNoteItem(note, theme, colorScheme);
      },
    );
  }

  Widget _buildNoteItem(
    domain.Note note,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final snippet = note.body.length > 100
        ? '${note.body.substring(0, 100)}...'
        : note.body;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => _insertNoteLink(note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebLinkTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Link text field
          TextField(
            controller: _linkTextController,
            decoration: InputDecoration(
              labelText: 'Link Text',
              hintText: 'Enter link text',
              prefixIcon: Icon(Icons.text_fields, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 16),

          // URL field
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
              prefixIcon: Icon(Icons.link, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            keyboardType: TextInputType.url,
            autofocus: widget.initialText.isNotEmpty,
          ),
          const SizedBox(height: 24),

          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Insert button
          FilledButton.icon(
            onPressed: _insertWebLink,
            icon: const Icon(Icons.add_link),
            label: const Text('Insert Link'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
