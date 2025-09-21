import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // TODO: Generate localization files

class SavedSearchManagementScreen extends ConsumerStatefulWidget {
  const SavedSearchManagementScreen({super.key});

  @override
  ConsumerState<SavedSearchManagementScreen> createState() =>
      _SavedSearchManagementScreenState();
}

class _SavedSearchManagementScreenState
    extends ConsumerState<SavedSearchManagementScreen> {
  List<SavedSearch> _savedSearches = [];
  bool _isLoading = true;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSearches();
  }

  Future<void> _loadSavedSearches() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      final searches = await repo.getSavedSearches();
      if (mounted) {
        setState(() {
          _savedSearches = searches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load saved searches: $e')),
        );
      }
    }
  }

  Future<void> _createSavedSearch() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateSavedSearchDialog(),
    );

    if (result != null) {
      final repo = ref.read(notesRepositoryProvider);
      final savedSearch = SavedSearch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name'] as String,
        query: result['query'] as String,
        searchType: result['type'] as String,
        sortOrder: 0,
        color: result['color'] as String?,
        icon: result['icon'] as String?,
        isPinned: false,
        createdAt: DateTime.now(),
        usageCount: 0,
      );
      await repo.createOrUpdateSavedSearch(savedSearch);
      await _loadSavedSearches();
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved search created')));
      }
    }
  }

  Future<void> _editSavedSearch(SavedSearch search) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateSavedSearchDialog(initialSearch: search),
    );

    if (result != null) {
      final repo = ref.read(notesRepositoryProvider);
      final updatedSearch = search.copyWith(
        name: result['name'] as String,
        query: result['query'] as String,
        searchType: result['type'] as String,
        icon: Value(result['icon'] as String?),
        color: Value(result['color'] as String?),
      );
      await repo.createOrUpdateSavedSearch(updatedSearch);
      await _loadSavedSearches();
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved search updated')));
      }
    }
  }

  Future<void> _deleteSavedSearch(SavedSearch search) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Search'),
        content: Text('Are you sure you want to delete "${search.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final repo = ref.read(notesRepositoryProvider);
      await repo.deleteSavedSearch(search.id);
      await _loadSavedSearches();
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved search deleted')));
      }
    }
  }

  Future<void> _togglePin(SavedSearch search) async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.toggleSavedSearchPin(search.id);
    await _loadSavedSearches();
    HapticFeedback.lightImpact();
  }

  Future<void> _saveReorder() async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.reorderSavedSearches(_savedSearches.map((s) => s.id).toList());
    setState(() => _isReordering = false);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final l10n = AppLocalizations.of(context); // TODO: Enable when localization is generated

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Searches'),
        actions: [
          if (_isReordering)
            TextButton(onPressed: _saveReorder, child: const Text('Done'))
          else
            IconButton(
              icon: const Icon(Icons.reorder),
              onPressed: _savedSearches.isNotEmpty
                  ? () => setState(() => _isReordering = true)
                  : null,
              tooltip: 'Reorder',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedSearches.isEmpty
              ? _buildEmptyState(context)
              : _isReordering
                  ? _buildReorderableList()
                  : _buildNormalList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSavedSearch,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.saved_search,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved searches',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create custom searches to quickly find your notes',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createSavedSearch,
            icon: const Icon(Icons.add),
            label: const Text('Create Saved Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _savedSearches.length,
      itemBuilder: (context, index) {
        final search = _savedSearches[index];
        return _buildSearchTile(search);
      },
    );
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _savedSearches.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _savedSearches.removeAt(oldIndex);
          _savedSearches.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final search = _savedSearches[index];
        return ListTile(
          key: ValueKey(search.id),
          leading: Icon(
            _getIconForSearch(search),
            color: search.color != null
                ? Color(int.parse(search.color!.replaceFirst('#', '0xff')))
                : null,
          ),
          title: Text(search.name),
          subtitle: Text(_getSubtitleForSearch(search)),
          trailing: const Icon(Icons.drag_handle),
        );
      },
    );
  }

  Widget _buildSearchTile(SavedSearch search) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        _getIconForSearch(search),
        color: search.color != null
            ? Color(int.parse(search.color!.replaceFirst('#', '0xff')))
            : null,
      ),
      title: Text(search.name),
      subtitle: Text(_getSubtitleForSearch(search)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (search.usageCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${search.usageCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              search.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: search.isPinned ? theme.colorScheme.primary : null,
            ),
            onPressed: () => _togglePin(search),
            tooltip: search.isPinned ? 'Unpin' : 'Pin',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editSavedSearch(search);
                  break;
                case 'delete':
                  _deleteSavedSearch(search);
                  break;
              }
            },
          ),
        ],
      ),
      onTap: () async {
        // Track usage
        final repo = ref.read(notesRepositoryProvider);
        await repo.trackSavedSearchUsage(search.id);

        // Execute search
        if (mounted) {
          Navigator.pop(context, search);
        }
      },
    );
  }

  IconData _getIconForSearch(SavedSearch search) {
    if (search.icon != null) {
      // Map icon names to IconData
      switch (search.icon) {
        case 'star':
          return Icons.star;
        case 'folder':
          return Icons.folder;
        case 'tag':
          return Icons.tag;
        case 'calendar':
          return Icons.calendar_today;
        default:
          return Icons.search;
      }
    }

    // Default icons based on type
    switch (search.searchType) {
      case 'tag':
        return Icons.tag;
      case 'folder':
        return Icons.folder;
      case 'date_range':
        return Icons.date_range;
      case 'compound':
        return Icons.filter_alt;
      default:
        return Icons.search;
    }
  }

  String _getSubtitleForSearch(SavedSearch search) {
    switch (search.searchType) {
      case 'tag':
        return 'Tag: ${search.query}';
      case 'folder':
        return 'Folder search';
      case 'date_range':
        return 'Date range search';
      case 'compound':
        return 'Advanced search';
      default:
        return 'Text: ${search.query}';
    }
  }
}

class _CreateSavedSearchDialog extends StatefulWidget {
  const _CreateSavedSearchDialog({this.initialSearch});
  final SavedSearch? initialSearch;

  @override
  State<_CreateSavedSearchDialog> createState() =>
      _CreateSavedSearchDialogState();
}

class _CreateSavedSearchDialogState extends State<_CreateSavedSearchDialog> {
  late TextEditingController _nameController;
  late TextEditingController _queryController;
  String _searchType = 'text';
  String? _selectedIcon;
  String? _selectedColor;

  final List<String> _searchTypes = ['text', 'tag', 'folder', 'compound'];
  final List<String> _availableIcons = [
    'search',
    'star',
    'folder',
    'tag',
    'calendar',
  ];
  final List<String> _availableColors = [
    '#FF5252',
    '#E91E63',
    '#9C27B0',
    '#673AB7',
    '#3F51B5',
    '#2196F3',
    '#00BCD4',
    '#009688',
    '#4CAF50',
    '#8BC34A',
    '#FFC107',
    '#FF9800',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialSearch?.name ?? '',
    );
    _queryController = TextEditingController(
      text: widget.initialSearch?.query ?? '',
    );
    _searchType = widget.initialSearch?.searchType ?? 'text';
    _selectedIcon = widget.initialSearch?.icon;
    _selectedColor = widget.initialSearch?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.initialSearch == null
            ? 'Create Saved Search'
            : 'Edit Saved Search',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Work Notes',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _searchType,
              decoration: const InputDecoration(labelText: 'Search Type'),
              items: _searchTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _searchType = value!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Query',
                hintText: _getQueryHint(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableIcons.map((iconName) {
                final isSelected = _selectedIcon == iconName;
                return FilterChip(
                  selected: isSelected,
                  label: Icon(_getIconData(iconName), size: 20),
                  onSelected: (selected) {
                    setState(() => _selectedIcon = selected ? iconName : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Color', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableColors.map((color) {
                final isSelected = _selectedColor == color;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedColor = isSelected ? null : color);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.isNotEmpty &&
                  _queryController.text.isNotEmpty
              ? () {
                  Navigator.pop(context, {
                    'name': _nameController.text,
                    'query': _queryController.text,
                    'type': _searchType,
                    'icon': _selectedIcon,
                    'color': _selectedColor,
                  });
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'tag':
        return 'Tag Search';
      case 'folder':
        return 'Folder Search';
      case 'compound':
        return 'Advanced Search';
      default:
        return 'Text Search';
    }
  }

  String _getQueryHint() {
    switch (_searchType) {
      case 'tag':
        return 'Enter tag name (without #)';
      case 'folder':
        return 'Enter folder name or ID';
      case 'compound':
        return 'Enter advanced query';
      default:
        return 'Enter search text';
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'folder':
        return Icons.folder;
      case 'tag':
        return Icons.tag;
      case 'calendar':
        return Icons.calendar_today;
      default:
        return Icons.search;
    }
  }
}
