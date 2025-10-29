import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/template.dart' as domain;
import 'package:duru_notes/features/templates/template_preview_dialog.dart';
import 'package:duru_notes/features/templates/create_template_dialog.dart';
import 'package:duru_notes/features/templates/edit_template_dialog.dart';
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show templateListProvider, templateCoreRepositoryProvider;
import 'package:duru_notes/models/template_model.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart' show analyticsProvider;
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/template_sharing_service.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/modern_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  const TemplateGalleryScreen({
    super.key,
    this.selectMode = false,
  });

  final bool selectMode; // If true, tapping a template returns it

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

  Widget _buildStatsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final templatesAsync = ref.watch(templateListProvider);

    return templatesAsync.when(
      data: (templates) {
        final workTemplates = templates.where((t) => t.category == 'work').length;
        final personalTemplates = templates.where((t) => t.category == 'personal').length;
        // Use createdAt for recent templates since lastUsedAt doesn't exist
        final recentTemplates = templates.where((t) {
          final diff = DateTime.now().difference(t.createdAt);
          return diff.inDays <= 7;
        }).length;

        return Container(
          margin: EdgeInsets.all(DuruSpacing.md),
          padding: EdgeInsets.all(DuruSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DuruColors.primary.withValues(alpha: 0.1),
                DuruColors.accent.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: CupertinoIcons.doc_text_viewfinder,
                value: templates.length.toString(),
                label: 'Templates',
                color: DuruColors.primary,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.briefcase_fill,
                value: workTemplates.toString(),
                label: 'Work',
                color: DuruColors.accent,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.person_fill,
                value: personalTemplates.toString(),
                label: 'Personal',
                color: DuruColors.warning,
              ),
              _buildStatItem(
                context,
                icon: CupertinoIcons.time,
                value: recentTemplates.toString(),
                label: 'Recent',
                color: DuruColors.surfaceVariant,
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 120,
        margin: EdgeInsets.all(DuruSpacing.md),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(DuruSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: DuruSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8FAFB),
      appBar: ModernAppBar(
        title: _isSelectionMode
            ? '${_selectedTemplates.length} selected'
            : 'Template Gallery',
        subtitle: _isSelectionMode ? null : 'Ready-to-use note templates',
        showGradient: !_isSelectionMode,
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(CupertinoIcons.xmark, color: Colors.white),
                onPressed: _clearSelection,
              )
            : null,
        actions: _isSelectionMode
            ? _buildSelectionActions()
            : _buildNormalActions(),
        backgroundColor: _isSelectionMode ? DuruColors.primary : null,
      ),
      body: Column(
        children: [
          // Stats header
          if (!_isSelectionMode) _buildStatsHeader(context),
          // Search and filter bar
          if (!_isSelectionMode)
            Container(
              padding: EdgeInsets.all(DuruSpacing.md),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: _updateSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: Icon(CupertinoIcons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(CupertinoIcons.xmark_circle_fill),
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
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  SizedBox(height: DuruSpacing.sm),
                  // Filter and sort chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Category filter
                        FilterChip(
                          label: Text(_categoryFilter.label),
                          selected: _categoryFilter != TemplateCategory.all,
                          onSelected: (_) => _showCategoryFilter(),
                          avatar: Icon(CupertinoIcons.tag_fill, size: 16),
                          backgroundColor: DuruColors.primary.withValues(alpha: 0.1),
                          selectedColor: DuruColors.primary.withValues(alpha: 0.2),
                        ),
                        SizedBox(width: DuruSpacing.xs),
                        // Sort filter
                        FilterChip(
                          label: Text(_sortMode.label),
                          selected: true,
                          onSelected: (_) => _showSortOptions(),
                          avatar: Icon(CupertinoIcons.sort_down, size: 16),
                          backgroundColor: DuruColors.accent.withValues(alpha: 0.1),
                          selectedColor: DuruColors.accent.withValues(alpha: 0.2),
                        ),
                        SizedBox(width: DuruSpacing.xs),
                        // View mode toggle
                        IconButton(
                          icon: Icon(
                            _isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
                            color: DuruColors.primary,
                          ),
                          onPressed: _toggleViewMode,
                          tooltip: _isGridView ? 'List View' : 'Grid View',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Templates content
          Expanded(
            child: Consumer(
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
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: _showCreateTemplateDialog,
        backgroundColor: DuruColors.primary,
        icon: Icon(CupertinoIcons.plus_circle_fill, color: Colors.white),
        label: const Text('New Template', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: Icon(CupertinoIcons.share, color: Colors.white),
        onPressed: _selectedTemplates.length == 1 ? _shareSelectedTemplate : null,
        tooltip: 'Share Template',
      ),
      IconButton(
        icon: Icon(CupertinoIcons.doc_on_doc, color: Colors.white),
        onPressed: _duplicateSelectedTemplates,
        tooltip: 'Duplicate',
      ),
      PopupMenuButton<String>(
        icon: Icon(CupertinoIcons.ellipsis_vertical, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (value) {
          switch (value) {
            case 'delete':
              _deleteSelectedTemplates();
            case 'export':
              _exportSelectedTemplates();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(CupertinoIcons.arrow_down_doc, color: DuruColors.primary),
              title: const Text('Export'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(CupertinoIcons.trash, color: DuruColors.error),
              title: Text('Delete', style: TextStyle(color: DuruColors.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildNormalActions() {
    return [
      ModernAppBarAction(
        icon: CupertinoIcons.refresh,
        onPressed: _loadTemplates,
        tooltip: 'Refresh',
      ),
      PopupMenuButton<String>(
        icon: Icon(CupertinoIcons.ellipsis_vertical, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (value) {
          switch (value) {
            case 'import':
              _showImportDialog();
            case 'statistics':
              _showStatistics();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'import',
            child: ListTile(
              leading: Icon(CupertinoIcons.arrow_up_doc, color: DuruColors.primary),
              title: const Text('Import Templates'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'statistics',
            child: ListTile(
              leading: Icon(CupertinoIcons.chart_bar_fill, color: DuruColors.accent),
              title: const Text('Usage Statistics'),
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
            : widget.selectMode
                ? _selectTemplate(template)
                : _showTemplatePreview(template),
        onLongPress: () => _showTemplateOptions(template),
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
            : widget.selectMode
                ? _selectTemplate(template)
                : _showTemplatePreview(template),
        onLongPress: () => _showTemplateOptions(template),
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

      // Apply template to create note
      final repository = ref.read(templateCoreRepositoryProvider);
      final noteId = await repository.applyTemplate(
        templateId: template.id,
        variableValues:
            <String, dynamic>{}, // Empty variables for now - will be replaced with note creation
      );

      debugPrint('Created note from template: $noteId');

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
        final repository = ref.read(templateCoreRepositoryProvider);
        await repository.deleteTemplate(template.id);

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

  void _selectTemplate(LocalTemplate template) {
    // Convert LocalTemplate to Template model and return it
    // Parse tags from JSON string
    List<String> tagsList = [];
    try {
      tagsList = (jsonDecode(template.tags) as List<dynamic>).cast<String>();
        } catch (_) {
      tagsList = [];
    }

    Map<String, dynamic> metadataMap = {};
    try {
      if (template.metadata != null && template.metadata!.isNotEmpty) {
        final decoded = jsonDecode(template.metadata!);
        metadataMap = decoded is Map<String, dynamic> ? decoded : {};
      }
    } catch (_) {
      metadataMap = {};
    }

    final templateModel = Template(
      id: template.id,
      title: template.title,
      body: template.body,
      tags: tagsList,
      isSystem: false,
      category: template.category,
      description: template.description,
      icon: template.icon,
      sortOrder: template.sortOrder,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
      metadata: metadataMap,
    );

    Navigator.of(context).pop(templateModel);
  }

  void _showTemplateOptions(LocalTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Template'),
                onTap: () {
                  Navigator.pop(context);
                  _editTemplate(template);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Export Template'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportTemplate(template);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Duplicate Template'),
                onTap: () async {
                  Navigator.pop(context);
                  await _duplicateTemplate(template);
                },
              ),
              if (!template.isSystem)
                ListTile(
                  leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  title: Text('Delete Template',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteTemplate(template);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportTemplate(LocalTemplate template) async {
    try {
      final sharingService = TemplateSharingService();

      // Parse tags from JSON string
      List<String> tagsList = [];
      try {
        tagsList = (jsonDecode(template.tags) as List<dynamic>).cast<String>();
            } catch (_) {
        tagsList = [];
      }

      // Parse metadata safely
      Map<String, dynamic> metadataMap = {};
      try {
        if (template.metadata != null && template.metadata!.isNotEmpty) {
          final decoded = jsonDecode(template.metadata!);
          metadataMap = decoded is Map<String, dynamic> ? decoded : {};
        }
      } catch (_) {
        metadataMap = {};
      }

      // Create Template model for export
      final templateModel = Template(
        id: template.id,
        title: template.title,
        body: template.body,
        tags: tagsList,
        isSystem: template.isSystem,
        category: template.category,
        description: template.description,
        icon: template.icon,
        sortOrder: template.sortOrder,
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
        metadata: metadataMap,
      );

      final success = await sharingService.exportTemplate(templateModel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Template exported successfully' : 'Export failed'),
            backgroundColor: success ? Colors.green : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export template: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _duplicateTemplate(LocalTemplate template) async {
    try {
      final repository = ref.read(templateCoreRepositoryProvider);

      await repository.duplicateTemplate(
        templateId: template.id,
        newName: '${template.title} (Copy)',
      );

      await _loadTemplates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template duplicated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate template: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _shareSelectedTemplate() {
    // Implement bulk template sharing
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.arrow_up_doc, color: DuruColors.primary),
            SizedBox(width: 12),
            Text('Import Templates'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose what you want to import:'),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(CupertinoIcons.doc, color: DuruColors.primary),
              title: Text('Single Template'),
              subtitle: Text('Import one template file (.tmpl)'),
              onTap: () {
                Navigator.of(context).pop();
                _importSingleTemplate();
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.folder, color: DuruColors.accent),
              title: Text('Template Pack'),
              subtitle: Text('Import multiple templates (.tpack)'),
              onTap: () {
                Navigator.of(context).pop();
                _importTemplatePack();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSingleTemplate() async {
    try {
      final sharingService = TemplateSharingService();
      final repository = ref.read(templateCoreRepositoryProvider);

      final template = await sharingService.importTemplate();
      if (template != null) {
        // Convert model to domain entity and save
        final domainTemplate = domain.Template(
          id: template.id,
          name: template.title,
          content: template.body,
          variables: template.metadata ?? {},
          isSystem: false, // Imported templates are user templates
          createdAt: template.createdAt,
          updatedAt: template.updatedAt,
        );

        await repository.createTemplate(domainTemplate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Template "${template.title}" imported successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the templates list
          ref.invalidate(templateCoreRepositoryProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import template: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importTemplatePack() async {
    try {
      final sharingService = TemplateSharingService();
      final repository = ref.read(templateCoreRepositoryProvider);

      final templates = await sharingService.importTemplatePack();
      if (templates.isNotEmpty) {
        int successCount = 0;

        for (final template in templates) {
          try {
            // Convert model to domain entity and save
            final domainTemplate = domain.Template(
              id: template.id,
              name: template.title,
              content: template.body,
              variables: template.metadata ?? {},
              isSystem: false, // Imported templates are user templates
              createdAt: template.createdAt,
              updatedAt: template.updatedAt,
            );

            await repository.createTemplate(domainTemplate);
            successCount++;
          } catch (e) {
            // Continue with next template if one fails
            continue;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $successCount of ${templates.length} templates'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the templates list
          ref.invalidate(templateCoreRepositoryProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import template pack: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatistics() {
    // Implement usage statistics dialog
  }
}
