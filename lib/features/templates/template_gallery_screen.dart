import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/templates/template_preview_dialog.dart';
import 'package:duru_notes/features/templates/create_template_dialog.dart';
import 'package:duru_notes/features/templates/edit_template_dialog.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Template view mode preference key
const String _kTemplateViewModeKey = 'template_view_mode';

/// Template sort preference key
const String _kTemplateSortKey = 'template_sort_mode';

/// Template category filter preference key
const String _kTemplateCategoryKey = 'template_category_filter';

/// Template sort modes
enum TemplateSortMode {
  mostUsed('Most Used'),
  recentlyUsed('Recently Used'),
  name('Name'),
  dateCreated('Date Created'),
  category('Category');

  const TemplateSortMode(this.label);
  final String label;
}

/// Template categories
enum TemplateCategory {
  all('All'),
  work('Work'),
  personal('Personal'),
  academic('Academic'),
  creative('Creative'),
  meeting('Meeting'),
  planning('Planning'),
  other('Other');

  const TemplateCategory(this.label);
  final String label;
}

/// Comprehensive template gallery screen with CRUD operations
class TemplateGalleryScreen extends ConsumerStatefulWidget {
  const TemplateGalleryScreen({super.key});

  @override
  ConsumerState<TemplateGalleryScreen> createState() =>
      _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends ConsumerState<TemplateGalleryScreen>
    with TickerProviderStateMixin {
  late AppLogger _logger;
  late AnalyticsService _analytics;
  late TabController _tabController;

  // View state
  bool _isGridView = true;
  TemplateSortMode _sortMode = TemplateSortMode.mostUsed;
  TemplateCategory _categoryFilter = TemplateCategory.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selection state
  final Set<String> _selectedTemplates = <String>{};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _logger = LoggerFactory.instance;

    // Load preferences
    _loadPreferences();

    // Initialize analytics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _analytics = ref.read(analyticsProvider);
        _analytics.event('template_gallery_opened');

        _logger.info('TemplateGalleryScreen initialized');

        // Track in Sentry
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Template gallery screen opened',
            category: 'navigation',
          ),
        );

        // Load templates when screen opens
        _loadTemplates();
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to initialize TemplateGalleryScreen',
          error: e,
          stackTrace: stackTrace,
        );
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isGridView = prefs.getBool(_kTemplateViewModeKey) ?? true;
        _sortMode = TemplateSortMode.values[
            prefs.getInt(_kTemplateSortKey) ?? 0];
        _categoryFilter = TemplateCategory.values[
            prefs.getInt(_kTemplateCategoryKey) ?? 0];
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load template preferences',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTemplateViewModeKey, _isGridView);
      await prefs.setInt(_kTemplateSortKey, _sortMode.index);
      await prefs.setInt(_kTemplateCategoryKey, _categoryFilter.index);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to save template preferences',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _loadTemplates() async {
    try {
      ref.invalidate(templateListProvider);
      await ref.read(templateListProvider.future);
      _logger.debug('Templates loaded successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load templates',
        error: e,
        stackTrace: stackTrace,
      );
      Sentry.captureException(e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load templates: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
    _savePreferences();
    _analytics.event('template_view_mode_changed',
        properties: {'view_mode': _isGridView ? 'grid' : 'list'});
  }

  void _changeSortMode(TemplateSortMode sortMode) {
    setState(() {
      _sortMode = sortMode;
    });
    _savePreferences();
    _analytics.event('template_sort_changed',
        properties: {'sort_mode': sortMode.label});
  }

  void _changeCategoryFilter(TemplateCategory category) {
    setState(() {
      _categoryFilter = category;
    });
    _savePreferences();
    _analytics.event('template_category_filtered',
        properties: {'category': category.label});
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<LocalTemplate> _filterAndSortTemplates(List<LocalTemplate> templates) {
    // Apply search filter
    var filtered = templates.where((template) {
      if (_searchQuery.isEmpty) return true;
      return template.title.toLowerCase().contains(_searchQuery) ||
             template.description.toLowerCase().contains(_searchQuery) ||
             template.category.toLowerCase().contains(_searchQuery);
    }).toList();

    // Apply category filter
    if (_categoryFilter != TemplateCategory.all) {
      filtered = filtered.where((template) =>
          template.category.toLowerCase() == _categoryFilter.label.toLowerCase()
      ).toList();
    }

    // Apply sorting
    switch (_sortMode) {
      case TemplateSortMode.mostUsed:
        // Note: usageCount not available in schema, using updatedAt as fallback
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case TemplateSortMode.recentlyUsed:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case TemplateSortMode.name:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case TemplateSortMode.dateCreated:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TemplateSortMode.category:
        filtered.sort((a, b) {
          final categoryComparison = a.category.compareTo(b.category);
          if (categoryComparison != 0) return categoryComparison;
          return a.title.compareTo(b.title);
        });
    }

    return filtered;
  }

  void _toggleSelection(String templateId) {
    setState(() {
      if (_selectedTemplates.contains(templateId)) {
        _selectedTemplates.remove(templateId);
        if (_selectedTemplates.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTemplates.add(templateId);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTemplates.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedTemplates.length} selected')
            : const Text('Template Gallery'),
        centerTitle: !_isSelectionMode,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: _isSelectionMode
            ? _buildSelectionActions()
            : _buildNormalActions(),
        bottom: _isSelectionMode ? null : PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _updateSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search templates...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _updateSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),

              // Filter and sort chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Category filter
                    FilterChip(
                      label: Text(_categoryFilter.label),
                      selected: _categoryFilter != TemplateCategory.all,
                      onSelected: (_) => _showCategoryFilter(),
                      avatar: const Icon(Icons.category, size: 18),
                    ),
                    const SizedBox(width: 8),

                    // Sort filter
                    FilterChip(
                      label: Text(_sortMode.label),
                      selected: true,
                      onSelected: (_) => _showSortOptions(),
                      avatar: const Icon(Icons.sort, size: 18),
                    ),
                    const SizedBox(width: 8),

                    // View mode toggle
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                      onPressed: _toggleViewMode,
                      tooltip: _isGridView ? 'List View' : 'Grid View',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final templatesAsync = ref.watch(templateListProvider);

          return templatesAsync.when(
            data: (templates) {
              final filteredTemplates = _filterAndSortTemplates(templates);

              if (filteredTemplates.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: _loadTemplates,
                child: _isGridView
                    ? _buildGridView(filteredTemplates)
                    : _buildListView(filteredTemplates),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
            error: (error, stackTrace) => _buildErrorState(error),
          );
        },
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: _showCreateTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: _selectedTemplates.length == 1 ? _shareSelectedTemplate : null,
        tooltip: 'Share Template',
      ),
      IconButton(
        icon: const Icon(Icons.copy),
        onPressed: _duplicateSelectedTemplates,
        tooltip: 'Duplicate',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'delete':
              _deleteSelectedTemplates();
            case 'export':
              _exportSelectedTemplates();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(Icons.download),
              title: Text('Export'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildNormalActions() {
    return [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _loadTemplates,
        tooltip: 'Refresh',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'import':
              _showImportDialog();
            case 'statistics':
              _showStatistics();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'import',
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Import Templates'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'statistics',
            child: ListTile(
              leading: Icon(Icons.analytics),
              title: Text('Usage Statistics'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildGridView(List<LocalTemplate> templates) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: templates.length,
        itemBuilder: (context, index) => _buildTemplateGridCard(templates[index]),
      ),
    );
  }

  Widget _buildListView(List<LocalTemplate> templates) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) => _buildTemplateListCard(templates[index]),
    );
  }

  Widget _buildTemplateGridCard(LocalTemplate template) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedTemplates.contains(template.id);

    return Card(
      elevation: isSelected ? 8 : 1,
      child: InkWell(
        onTap: () => _isSelectionMode
            ? _toggleSelection(template.id)
            : _showTemplatePreview(template),
        onLongPress: () => _toggleSelection(template.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and selection indicator
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(template.category),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(template.category),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    if (template.isSystem)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SYSTEM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  template.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Description
                Expanded(
                  child: Text(
                    template.description.isNotEmpty
                        ? template.description
                        : 'No description',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 8),

                // Footer with category and usage count
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          template.category.toUpperCase(),
                          style: theme.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Usage count not available in current schema
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.update,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatDateTime(template.updatedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateListCard(LocalTemplate template) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedTemplates.contains(template.id);

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _isSelectionMode
            ? _toggleSelection(template.id)
            : _showTemplatePreview(template),
        onLongPress: () => _toggleSelection(template.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection indicator or category icon
                if (isSelected)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(template.category),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(template.category),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with system badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (template.isSystem)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SYSTEM',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Description
                      Text(
                        template.description.isNotEmpty
                            ? template.description
                            : 'No description',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Footer
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              template.category.toUpperCase(),
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          const Spacer(),
                          // Show updated date instead of usage count
                          Icon(
                            Icons.update,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Updated ${_formatDateTime(template.updatedAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _formatDateTime(template.updatedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String title;
    String subtitle;

    if (_searchQuery.isNotEmpty) {
      title = 'No templates found';
      subtitle = 'Try adjusting your search or filters';
    } else if (_categoryFilter != TemplateCategory.all) {
      title = 'No ${_categoryFilter.label.toLowerCase()} templates';
      subtitle = 'Create a new template or try a different category';
    } else {
      title = 'No templates yet';
      subtitle = 'Create your first template to get started';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showCreateTemplateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load templates',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadTemplates,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    return DuruColors.getCategoryColor(context, category);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work;
      case 'personal':
        return Icons.person;
      case 'academic':
        return Icons.school;
      case 'creative':
        return Icons.palette;
      case 'meeting':
        return Icons.meeting_room;
      case 'planning':
        return Icons.event_note;
      default:
        return Icons.description;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showCategoryFilter() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter by Category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...TemplateCategory.values.map((category) => ListTile(
              leading: Icon(_getCategoryIcon(category.label)),
              title: Text(category.label),
              trailing: _categoryFilter == category
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                _changeCategoryFilter(category);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort Templates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...TemplateSortMode.values.map((sortMode) => ListTile(
              title: Text(sortMode.label),
              trailing: _sortMode == sortMode
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                _changeSortMode(sortMode);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _showTemplatePreview(LocalTemplate template) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => TemplatePreviewDialog(template: template),
    );

    if (result != null && mounted) {
      switch (result) {
        case 'use':
          await _useTemplate(template);
        case 'edit':
          await _editTemplate(template);
        case 'delete':
          await _deleteTemplate(template);
      }
    }
  }

  Future<void> _useTemplate(LocalTemplate template) async {
    try {
      // Track template usage
      _analytics.event('template_used', properties: {
        'template_id': template.id,
        'template_category': template.category,
        'is_system': template.isSystem,
      });

      // Update usage count
      final repository = ref.read(templateRepositoryProvider);
      repository.trackTemplateUsage(template.id);

      // Create note from template
      final noteData = repository.createNoteFromTemplate(template);
      // TODO: Implement note creation from template
      debugPrint('Template note data: $noteData');

      // Navigate to note editor with template data
      if (mounted) {
        Navigator.of(context).pop(); // Close template gallery
        // Here you would navigate to the note editor with the template data
        // This depends on your note editor implementation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note created from template "${template.title}"'),
            action: SnackBarAction(
              label: 'Edit',
              onPressed: () {
                // Navigate to note editor
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to use template',
        error: e,
        stackTrace: stackTrace,
        data: {'template_id': template.id},
      );
      Sentry.captureException(e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to use template: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editTemplate(LocalTemplate template) async {
    if (template.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('System templates cannot be edited'),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditTemplateDialog(template: template),
    );

    if (result ?? false) {
      await _loadTemplates();
    }
  }

  Future<void> _deleteTemplate(LocalTemplate template) async {
    if (template.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('System templates cannot be deleted'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        final repository = ref.read(templateRepositoryProvider);
        final success = await repository.deleteUserTemplate(template.id);

        if (success) {
          await _loadTemplates();
          _analytics.event('template_deleted', properties: {
            'template_id': template.id,
            'template_category': template.category,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted template "${template.title}"'),
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to delete template',
          error: e,
          stackTrace: stackTrace,
          data: {'template_id': template.id},
        );
        Sentry.captureException(e, stackTrace: stackTrace);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete template: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCreateTemplateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateTemplateDialog(),
    );

    if (result ?? false) {
      await _loadTemplates();
    }
  }

  void _shareSelectedTemplate() {
    // Implement template sharing
  }

  void _duplicateSelectedTemplates() {
    // Implement template duplication
  }

  void _deleteSelectedTemplates() {
    // Implement bulk template deletion
  }

  void _exportSelectedTemplates() {
    // Implement template export
  }

  void _showImportDialog() {
    // Implement template import
  }

  void _showStatistics() {
    // Implement usage statistics dialog
  }
}