import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/modern_app_bar.dart';
import 'package:duru_notes/ui/tag_notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // TODO: Generate localization files

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  List<TagCount> _tags = [];
  List<TagCount> _filteredTags = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String? _editingTag;
  final Map<String, TextEditingController> _editControllers = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(_filterTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _editControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      final tags = await repo.listTagsWithCounts();
      if (mounted) {
        setState(() {
          _tags = tags;
          _filteredTags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tags: $e')));
      }
    }
  }

  void _filterTags() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTags = _tags;
      } else {
        _filteredTags =
            _tags.where((tc) => tc.tag.toLowerCase().contains(query)).toList();
      }
    });
  }

  Future<void> _renameTag(String oldTag, String newTag) async {
    if (newTag.trim().isEmpty || oldTag == newTag) {
      return;
    }

    try {
      final repo = ref.read(notesRepositoryProvider);
      final count = await repo.renameTagEverywhere(
        from: oldTag,
        to: newTag.trim(),
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed tag in $count notes')));
        _loadTags(); // Reload tags
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to rename tag: $e')));
      }
    }
  }

  void _startEdit(String tag) {
    setState(() {
      _editingTag = tag;
      _editControllers[tag] = TextEditingController(text: tag);
    });
  }

  void _cancelEdit() {
    setState(() {
      if (_editingTag != null) {
        _editControllers[_editingTag]?.dispose();
        _editControllers.remove(_editingTag);
      }
      _editingTag = null;
    });
  }

  void _saveEdit(String oldTag) {
    final newTag = _editControllers[oldTag]?.text ?? oldTag;
    _renameTag(oldTag, newTag);
    _cancelEdit();
  }

  Widget _buildStatsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final totalTags = _tags.length;
    final totalNotes = _tags.fold<int>(0, (sum, tag) => sum + tag.count);
    final popularTag = _tags.isEmpty
        ? null
        : _tags.reduce((a, b) => a.count > b.count ? a : b);
    final recentTag = _tags.isEmpty ? null : _tags.last;

    return Container(
      margin: EdgeInsets.all(DuruSpacing.md),
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DuruColors.primary.withOpacity(0.1),
            DuruColors.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: CupertinoIcons.tag_fill,
            value: totalTags.toString(),
            label: 'Tags',
            color: DuruColors.primary,
          ),
          _buildStatItem(
            context,
            icon: CupertinoIcons.doc_text_fill,
            value: totalNotes.toString(),
            label: 'Notes',
            color: DuruColors.accent,
          ),
          _buildStatItem(
            context,
            icon: CupertinoIcons.flame_fill,
            value: popularTag?.count.toString() ?? '0',
            label: 'Most Used',
            color: DuruColors.warning,
          ),
          _buildStatItem(
            context,
            icon: CupertinoIcons.clock_fill,
            value: recentTag?.tag ?? 'None',
            label: 'Latest',
            color: DuruColors.surfaceVariant,
            isText: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool isText = false,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(DuruSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: DuruSpacing.xs),
        Text(
          isText && value.length > 8 ? '${value.substring(0, 6)}...' : value,
          style: TextStyle(
            fontSize: isText ? 14 : 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final l10n = AppLocalizations.of(context); // TODO: Enable when localization is generated

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8FAFB),
      appBar: ModernAppBar(
        title: 'Tags',
        subtitle: 'Organize your notes with tags',
        showGradient: true,
        actions: [
          ModernAppBarAction(
            icon: CupertinoIcons.refresh,
            onPressed: _loadTags,
            tooltip: 'Refresh tags',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _buildStatsHeader(context),
          // Search bar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: DuruSpacing.md,
              vertical: DuruSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tags...',
                prefixIcon: Icon(CupertinoIcons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(CupertinoIcons.xmark_circle_fill),
                        onPressed: _searchController.clear,
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          // Tags list
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTags.isEmpty
              ? _buildEmptyState(context)
              : _buildTagsList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(DuruSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DuruColors.primary.withOpacity(0.1),
                  DuruColors.accent.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearching ? CupertinoIcons.search : CupertinoIcons.tag_fill,
              size: 64,
              color: DuruColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No tags found for "$_searchQuery"' : 'No tags yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 8),
            Text(
              'Tags will appear here when you add them to notes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagsList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      padding: EdgeInsets.all(DuruSpacing.md),
      itemCount: _filteredTags.length,
      itemBuilder: (context, index) {
        final tagCount = _filteredTags[index];
        final isEditing = _editingTag == tagCount.tag;

        return Container(
          margin: EdgeInsets.only(bottom: DuruSpacing.sm),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEditing
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => TagNotesScreen(
                            tag: tagCount.tag,
                          ),
                        ),
                      ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getTagColor(tagCount.tag, colorScheme).withOpacity(0.05),
                      theme.colorScheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getTagColor(tagCount.tag, colorScheme).withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(DuruSpacing.md),
                child: Row(
                  children: [
                    // Tag icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getTagColor(tagCount.tag, colorScheme).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.tag_fill,
                          color: _getTagColor(tagCount.tag, colorScheme),
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: DuruSpacing.md),
                    // Tag content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isEditing
                              ? TextField(
                                  controller: _editControllers[tagCount.tag],
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onSubmitted: (_) => _saveEdit(tagCount.tag),
                                  onTapOutside: (_) => _cancelEdit(),
                                )
                              : Text(
                                  tagCount.tag,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                          SizedBox(height: DuruSpacing.xs),
                          Text(
                            '${tagCount.count} ${tagCount.count == 1 ? 'note' : 'notes'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Actions
                    isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(CupertinoIcons.checkmark_circle_fill,
                                    color: DuruColors.accent),
                                onPressed: () => _saveEdit(tagCount.tag),
                              ),
                              IconButton(
                                icon: Icon(CupertinoIcons.xmark_circle_fill,
                                    color: DuruColors.error),
                                onPressed: _cancelEdit,
                              ),
                            ],
                          )
                        : PopupMenuButton<String>(
                            icon: Icon(
                              CupertinoIcons.ellipsis_vertical,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'rename':
                                  _startEdit(tagCount.tag);
                        break;
                      case 'merge':
                        _showMergeDialog(tagCount.tag);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                      value: 'merge',
                      child: Text('Merge with...'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Color _getTagColor(String tag, ColorScheme colorScheme) {
    // Generate a consistent color for each tag based on its hash
    final hash = tag.hashCode;
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];
    return colors[hash.abs() % colors.length];
  }

  Future<void> _showMergeDialog(String sourceTag) async {
    final targetTags =
        _tags.where((tc) => tc.tag != sourceTag).map((tc) => tc.tag).toList();

    if (targetTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other tags available to merge with')),
      );
      return;
    }

    String? selectedTarget;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Merge "$sourceTag" with...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'All notes with this tag will be updated to use the target tag.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTarget,
                decoration: const InputDecoration(
                  labelText: 'Target tag',
                  border: OutlineInputBorder(),
                ),
                items: targetTags.map((tag) {
                  return DropdownMenuItem(value: tag, child: Text(tag));
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedTarget = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedTarget != null
                  ? () => Navigator.pop(context, selectedTarget)
                  : null,
              child: const Text('Merge'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _renameTag(sourceTag, result);
    }
  }
}
