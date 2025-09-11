import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/tag_notes_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tags: $e')),
        );
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
        _filteredTags = _tags
            .where((tc) => tc.tag.toLowerCase().contains(query))
            .toList();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed tag in $count notes'),
          ),
        );
        _loadTags(); // Reload tags
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename tag: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTags.isEmpty
              ? _buildEmptyState(context)
              : _buildTagsList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.tag,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No tags found for "$_searchQuery"'
                : 'No tags yet',
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredTags.length,
      itemBuilder: (context, index) {
        final tagCount = _filteredTags[index];
        final isEditing = _editingTag == tagCount.tag;

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTagColor(tagCount.tag, colorScheme).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.tag,
                color: _getTagColor(tagCount.tag, colorScheme),
                size: 20,
              ),
            ),
          ),
          title: isEditing
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
                  style: theme.textTheme.titleMedium,
                ),
          subtitle: Text(
            '${tagCount.count} ${tagCount.count == 1 ? 'note' : 'notes'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: isEditing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      onPressed: () => _saveEdit(tagCount.tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _cancelEdit,
                    ),
                  ],
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
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
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    const PopupMenuItem(
                      value: 'merge',
                      child: Text('Merge with...'),
                    ),
                  ],
                ),
          onTap: isEditing
              ? null
              : () {
                  // Navigate to filtered notes
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TagNotesScreen(
                        tag: tagCount.tag,
                      ),
                    ),
                  );
                },
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
    final targetTags = _tags
        .where((tc) => tc.tag != sourceTag)
        .map((tc) => tc.tag)
        .toList();

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
                value: selectedTarget,
                decoration: const InputDecoration(
                  labelText: 'Target tag',
                  border: OutlineInputBorder(),
                ),
                items: targetTags.map((tag) {
                  return DropdownMenuItem(
                    value: tag,
                    child: Text(tag),
                  );
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