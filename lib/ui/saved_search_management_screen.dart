import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/saved_search.dart' as domain;
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // TODO: Generate localization files

class SavedSearchManagementScreen extends ConsumerStatefulWidget {
  const SavedSearchManagementScreen({super.key});

  @override
  ConsumerState<SavedSearchManagementScreen> createState() =>
      _SavedSearchManagementScreenState();
}

class _SavedSearchManagementScreenState
    extends ConsumerState<SavedSearchManagementScreen> {
  List<domain.SavedSearch> _savedSearches = [];
  bool _isLoading = true;
  bool _isReordering = false;

  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    _loadSavedSearches();
  }

  Future<void> _loadSavedSearches() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(savedSearchServiceProvider);
      final searches = await service.getAllSavedSearches();
      if (mounted) {
        setState(() {
          _savedSearches = searches;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load saved searches',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not load saved searches. Please try again.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_loadSavedSearches()),
            ),
          ),
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
      try {
        final service = ref.read(savedSearchServiceProvider);
        final savedSearch = await service.createSavedSearch(
          name: result['name'] as String,
          query: result['query'] as String,
          isPinned: false,
        );
        await _loadSavedSearches();
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved search created')));
        }
        _logger.info(
          'Saved search created',
          data: {'searchName': savedSearch.name},
        );
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to create saved search',
          error: error,
          stackTrace: stackTrace,
          data: {'name': result['name'], 'query': result['query']},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not create saved search. Please retry.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_createSavedSearch()),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _editSavedSearch(domain.SavedSearch search) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateSavedSearchDialog(initialSearch: search),
    );

    if (result != null) {
      try {
        final service = ref.read(savedSearchServiceProvider);
        final updatedSearch = search.copyWith(
          name: result['name'] as String,
          query: result['query'] as String,
        );
        await service.updateSavedSearch(updatedSearch);
        await _loadSavedSearches();
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved search updated')));
        }
        _logger.info('Saved search updated', data: {'searchId': search.id});
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to update saved search',
          error: error,
          stackTrace: stackTrace,
          data: {'searchId': search.id},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not update saved search. Please retry.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_editSavedSearch(search)),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSavedSearch(domain.SavedSearch search) async {
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
      try {
        final service = ref.read(savedSearchServiceProvider);
        await service.deleteSavedSearch(search.id);
        await _loadSavedSearches();
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved search deleted')));
        }
        _logger.info('Saved search deleted', data: {'searchId': search.id});
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to delete saved search',
          error: error,
          stackTrace: stackTrace,
          data: {'searchId': search.id},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not delete saved search. Please retry.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => unawaited(_deleteSavedSearch(search)),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _togglePin(domain.SavedSearch search) async {
    try {
      final service = ref.read(savedSearchServiceProvider);
      await service.togglePin(search.id);
      await _loadSavedSearches();
      HapticFeedback.lightImpact();
      _logger.info(
        'Saved search pin toggled',
        data: {'searchId': search.id, 'isPinned': search.isPinned},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle saved search pin',
        error: error,
        stackTrace: stackTrace,
        data: {'searchId': search.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not update saved search pin. Please retry.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_togglePin(search)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveReorder() async {
    try {
      final service = ref.read(savedSearchServiceProvider);
      await service.reorderSavedSearches(_savedSearches.map((s) => s.id).toList());
      setState(() => _isReordering = false);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order saved')));
      }
      _logger.info('Saved searches reordered');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to reorder saved searches',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not save order. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_saveReorder()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        heroTag: 'saved_search_fab', // PRODUCTION FIX: Unique hero tag
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
          leading: Icon(_getIconForSearch(search)),
          title: Text(search.name),
          subtitle: Text(_getSubtitleForSearch(search)),
          trailing: const Icon(Icons.drag_handle),
        );
      },
    );
  }

  Widget _buildSearchTile(domain.SavedSearch search) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_getIconForSearch(search)),
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
        // Return search to caller for execution
        // Usage tracking will happen when executeSavedSearch is called
        if (mounted) {
          Navigator.pop(context, search);
        }
      },
    );
  }

  IconData _getIconForSearch(domain.SavedSearch search) {
    // domain.SavedSearch doesn't have icon/searchType - return default
    return Icons.search;
  }

  String _getSubtitleForSearch(domain.SavedSearch search) {
    // domain.SavedSearch doesn't have searchType - just show query
    return search.query;
  }
}

class _CreateSavedSearchDialog extends StatefulWidget {
  const _CreateSavedSearchDialog({this.initialSearch});
  final domain.SavedSearch? initialSearch;

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
    // domain.SavedSearch doesn't have searchType, icon, color - use defaults
    _searchType = 'text';
    _selectedIcon = null;
    _selectedColor = null;
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
          onPressed:
              _nameController.text.isNotEmpty &&
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
