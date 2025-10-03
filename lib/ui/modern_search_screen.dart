import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/search/search_parser.dart';
import '../theme/cross_platform_tokens.dart';
import 'package:intl/intl.dart';

/// Modern search screen with semantic search and AI-powered suggestions
class ModernSearchScreen extends ConsumerStatefulWidget {
  const ModernSearchScreen({super.key});

  @override
  ConsumerState<ModernSearchScreen> createState() => _ModernSearchScreenState();
}

class _ModernSearchScreenState extends ConsumerState<ModernSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<LocalNote> _searchResults = [];
  List<LocalNote> _recentNotes = [];
  List<String> _searchSuggestions = [];
  bool _isSearching = false;
  String _searchMode = 'all'; // all, semantic, exact

  // AI-powered search state
  bool _useSemanticSearch = false;
  double _semanticThreshold = 0.7;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _loadRecentNotes();
    _animationController.forward();

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentNotes() async {
    // Get recent notes from database - recently updated notes as proxy for recently viewed
    final allNotes = await ref.read(notesRepositoryProvider).db.localNotes();
    final recentNotes = allNotes.where((n) => !n.deleted).take(5).toList();

    if (mounted) {
      setState(() {
        _recentNotes = recentNotes;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<LocalNote> results;

      if (_useSemanticSearch) {
        // Simulate semantic search (replace with actual implementation)
        results = await _performSemanticSearch(query);
      } else {
        // Use traditional search
        final allNotes = await ref.read(notesRepositoryProvider).db.localNotes();
        final searchQuery = SearchParser.parse(query);

        results = allNotes.where((note) {
          if (note.deleted) return false;
          final searchableText = '${note.title} ${note.body}'.toLowerCase();
          return searchableText.contains(query.toLowerCase());
        }).toList();
      }

      // Sort by relevance/date
      results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<List<LocalNote>> _performSemanticSearch(String query) async {
    // Placeholder for semantic search implementation
    // In production, this would use vector embeddings and similarity search
    final allNotes = await ref.read(notesRepositoryProvider).db.localNotes();

    // Simulate semantic matching
    return allNotes.where((note) {
      if (note.deleted) return false;
      final content = '${note.title} ${note.body}'.toLowerCase();
      // Simple keyword matching for now
      final keywords = query.toLowerCase().split(' ');
      return keywords.any((keyword) => content.contains(keyword));
    }).toList();
  }

  void _generateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
      });
      return;
    }

    // Generate contextual suggestions
    final suggestions = <String>[];

    // Add search operators
    if (!query.contains(':')) {
      suggestions.add('$query in:title');
      suggestions.add('$query tag:');
      suggestions.add('$query folder:');
    }

    // Add recent searches (would be loaded from storage)
    suggestions.add('$query today');
    suggestions.add('$query this week');

    setState(() {
      _searchSuggestions = suggestions.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DuruColors.primary, DuruColors.accent],
            ),
          ),
        ),
        actions: [
          // Semantic search toggle
          IconButton(
            icon: Icon(
              CupertinoIcons.sparkles,
              color: _useSemanticSearch
                  ? const Color(0xFF9333EA)
                  : Colors.white.withValues(alpha: 0.7),
            ),
            onPressed: () {
              setState(() {
                _useSemanticSearch = !_useSemanticSearch;
              });
              HapticFeedback.lightImpact();

              // Re-run search if query exists
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
            tooltip: 'Semantic Search',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input with glass morphism
          Container(
            margin: const EdgeInsets.all(DuruSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DuruSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        color: DuruColors.primary,
                      ),
                      const SizedBox(width: DuruSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: _useSemanticSearch
                                ? 'Ask anything about your notes...'
                                : 'Search notes, tags, or folders...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          onChanged: (value) {
                            _generateSuggestions(value);
                            // Debounced search
                            Future<void>.delayed(const Duration(milliseconds: 300), () {
                              if (value == _searchController.text) {
                                _performSearch(value);
                              }
                            });
                          },
                          onSubmitted: _performSearch,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            CupertinoIcons.clear_circled_solid,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _searchSuggestions = [];
                            });
                          },
                        ),
                    ],
                  ),
                ),

                // Search mode selector
                if (_useSemanticSearch)
                  Container(
                    padding: const EdgeInsets.all(DuruSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9333EA).withValues(alpha: 0.1),
                          const Color(0xFF3B82F6).withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFF9333EA).withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.sparkles,
                          size: 16,
                          color: const Color(0xFF9333EA),
                        ),
                        const SizedBox(width: DuruSpacing.sm),
                        Text(
                          'Semantic Search Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF9333EA),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Threshold: ${(_semanticThreshold * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF9333EA).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Suggestions
                if (_searchSuggestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: DuruSpacing.sm),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: DuruSpacing.md),
                      child: Row(
                        children: _searchSuggestions.map((suggestion) {
                          return Padding(
                            padding: const EdgeInsets.only(right: DuruSpacing.sm),
                            child: ActionChip(
                              label: Text(suggestion),
                              onPressed: () {
                                _searchController.text = suggestion;
                                _performSearch(suggestion);
                              },
                              backgroundColor: DuruColors.primary.withValues(alpha: 0.1),
                              side: BorderSide(
                                color: DuruColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Results area
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _searchController.text.isEmpty
                    ? _buildEmptyState()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DuruSpacing.md),
        child: Column(
          children: [
            // Recent notes section
            if (_recentNotes.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Recent Notes',
                icon: CupertinoIcons.clock,
              ),
              const SizedBox(height: DuruSpacing.sm),
              ..._recentNotes.map((note) => _buildNoteCard(note)),
              const SizedBox(height: DuruSpacing.lg),
            ],

            // Search tips
            _buildSectionHeader(
              title: 'Search Tips',
              icon: CupertinoIcons.lightbulb,
            ),
            const SizedBox(height: DuruSpacing.sm),
            _buildTipCard(
              'Use operators',
              'Try "in:title", "tag:important", or "folder:work"',
              CupertinoIcons.command,
            ),
            _buildTipCard(
              'Semantic search',
              'Enable AI search to find notes by meaning',
              CupertinoIcons.sparkles,
            ),
            _buildTipCard(
              'Date filters',
              'Search with "today", "this week", or specific dates',
              CupertinoIcons.calendar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: DuruSpacing.md),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: DuruSpacing.sm),
            Text(
              _useSemanticSearch
                  ? 'Try rephrasing your query'
                  : 'Try different keywords or filters',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(DuruSpacing.md),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return _buildNoteCard(_searchResults[index]);
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DuruColors.primary, DuruColors.accent],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: DuruSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(LocalNote note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat.yMMMd();

    return Container(
      margin: const EdgeInsets.only(bottom: DuruSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop(note);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(DuruSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    Icon(
                      CupertinoIcons.pin_fill,
                      size: 14,
                      color: DuruColors.accent,
                    ),
                  if (note.isPinned) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled Note' : note.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateFormat.format(note.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: (isDark ? Colors.white : Colors.black87)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: DuruSpacing.xs),
                Text(
                  note.body,
                  style: TextStyle(
                    fontSize: 14,
                    color: (isDark ? Colors.white : Colors.black87)
                        .withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(String title, String description, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: DuruSpacing.sm),
      padding: const EdgeInsets.all(DuruSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DuruColors.primary.withValues(alpha: 0.05),
            DuruColors.accent.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DuruColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DuruColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: DuruColors.primary,
            ),
          ),
          const SizedBox(width: DuruSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: (isDark ? Colors.white : Colors.black87)
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}