import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/search/search_parser.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter state for the bottom sheet
class FilterState {
  const FilterState({
    this.includeTags = const {},
    this.excludeTags = const {},
    this.pinnedOnly = false,
    this.sortSpec = const NoteSortSpec(),
  });
  final Set<String> includeTags;
  final Set<String> excludeTags;
  final bool pinnedOnly;
  final NoteSortSpec sortSpec;

  FilterState copyWith({
    Set<String>? includeTags,
    Set<String>? excludeTags,
    bool? pinnedOnly,
    NoteSortSpec? sortSpec,
  }) {
    return FilterState(
      includeTags: includeTags ?? this.includeTags,
      excludeTags: excludeTags ?? this.excludeTags,
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
      sortSpec: sortSpec ?? this.sortSpec,
    );
  }

  bool get hasActiveFilters {
    return includeTags.isNotEmpty ||
        excludeTags.isNotEmpty ||
        pinnedOnly ||
        sortSpec != const NoteSortSpec();
  }

  SearchQuery toSearchQuery({String? keywords}) {
    return SearchQuery(
      keywords: keywords ?? '',
      includeTags: includeTags.toList(),
      excludeTags: excludeTags.toList(),
      isPinned: pinnedOnly,
    );
  }
}

/// Bottom sheet for advanced filters
class FiltersBottomSheet extends ConsumerStatefulWidget {
  const FiltersBottomSheet({
    required this.onApply,
    super.key,
    this.initialState,
  });
  final FilterState? initialState;
  final Function(FilterState) onApply;

  static Future<void> show(
    BuildContext context, {
    required Function(FilterState) onApply,
    FilterState? initialState,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          FiltersBottomSheet(initialState: initialState, onApply: onApply),
    );
  }

  @override
  ConsumerState<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends ConsumerState<FiltersBottomSheet>
    with SingleTickerProviderStateMixin {
  late FilterState _filterState;
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<TagCount> _allTags = [];
  List<TagCount> _filteredTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filterState = widget.initialState ?? const FilterState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTags();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final db = ref.read(appDbProvider);
      final tags = await db.getTagsWithCounts();
      if (mounted) {
        setState(() {
          _allTags = tags;
          _filteredTags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterTags(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTags = _allTags;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredTags = _allTags
            .where((t) => t.tag.toLowerCase().contains(lowerQuery))
            .toList();
      }
    });
  }

  void _toggleIncludeTag(String tag) {
    setState(() {
      final newSet = Set<String>.from(_filterState.includeTags);
      if (newSet.contains(tag)) {
        newSet.remove(tag);
      } else {
        newSet.add(tag);
        // Remove from exclude if present
        final excludeSet = Set<String>.from(_filterState.excludeTags);
        excludeSet.remove(tag);
        _filterState = _filterState.copyWith(excludeTags: excludeSet);
      }
      _filterState = _filterState.copyWith(includeTags: newSet);
    });
  }

  void _toggleExcludeTag(String tag) {
    setState(() {
      final newSet = Set<String>.from(_filterState.excludeTags);
      if (newSet.contains(tag)) {
        newSet.remove(tag);
      } else {
        newSet.add(tag);
        // Remove from include if present
        final includeSet = Set<String>.from(_filterState.includeTags);
        includeSet.remove(tag);
        _filterState = _filterState.copyWith(includeTags: includeSet);
      }
      _filterState = _filterState.copyWith(excludeTags: newSet);
    });
  }

  void _clearAll() {
    setState(() {
      _filterState = const FilterState();
    });
    HapticFeedback.lightImpact();
  }

  void _apply() {
    widget.onApply(_filterState);
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasChanges =
        _filterState != (widget.initialState ?? const FilterState());

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Advanced Filters',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_filterState.hasActiveFilters)
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear all'),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinned only switch
                  SwitchListTile(
                    title: const Text('Pinned notes only'),
                    subtitle: const Text('Show only pinned notes'),
                    secondary: Icon(
                      _filterState.pinnedOnly
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: _filterState.pinnedOnly
                          ? colorScheme.primary
                          : null,
                    ),
                    value: _filterState.pinnedOnly,
                    onChanged: (value) {
                      setState(() {
                        _filterState = _filterState.copyWith(pinnedOnly: value);
                      });
                      HapticFeedback.selectionClick();
                    },
                  ),

                  const Divider(indent: 16, endIndent: 16),

                  // Sort options
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      'Sort by',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  ...SortPreferencesService.getAllSortOptions().map((spec) {
                    return RadioListTile<NoteSortSpec>(
                      value: spec,
                      groupValue: _filterState.sortSpec,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              sortSpec: value,
                            );
                          });
                          HapticFeedback.selectionClick();
                        }
                      },
                      title: Text(spec.label),
                      dense: true,
                    );
                  }),

                  const Divider(indent: 16, endIndent: 16),

                  // Tags section with tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      'Filter by tags',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Search box for tags
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterTags,
                      decoration: InputDecoration(
                        hintText: 'Search tags...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterTags('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // Tab bar for include/exclude
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            const Text('Include'),
                            if (_filterState.includeTags.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_filterState.includeTags.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            const Text('Exclude'),
                            if (_filterState.excludeTags.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_filterState.excludeTags.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),

                  // Tab content
                  SizedBox(
                    height: 200,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Include tags
                        _buildTagList(
                          tags: _filteredTags,
                          selectedTags: _filterState.includeTags,
                          onToggle: _toggleIncludeTag,
                          emptyMessage: 'No tags found',
                          color: colorScheme.primary,
                        ),
                        // Exclude tags
                        _buildTagList(
                          tags: _filteredTags,
                          selectedTags: _filterState.excludeTags,
                          onToggle: _toggleExcludeTag,
                          emptyMessage: 'No tags found',
                          color: colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: hasChanges ? _apply : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagList({
    required List<TagCount> tags,
    required Set<String> selectedTags,
    required Function(String) onToggle,
    required String emptyMessage,
    required Color color,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tags.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        final isSelected = selectedTags.contains(tag.tag);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => onToggle(tag.tag),
          title: Text(tag.tag),
          subtitle: Text('${tag.count} notes'),
          secondary: Icon(
            Icons.tag,
            size: 20,
            color: isSelected ? color : null,
          ),
          dense: true,
          activeColor: color,
        );
      },
    );
  }
}
