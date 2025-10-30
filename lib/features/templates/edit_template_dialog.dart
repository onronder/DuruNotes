import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/templates/create_template_dialog.dart';
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show templateCoreRepositoryProvider;
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider;
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/platform_adaptive_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Dialog for editing existing user templates
class EditTemplateDialog extends ConsumerStatefulWidget {
  const EditTemplateDialog({super.key, required this.template});

  final LocalTemplate template;

  @override
  ConsumerState<EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends ConsumerState<EditTemplateDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _logger = LoggerFactory.instance;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();

  // Form state
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'personal';
  IconData _selectedIcon = Icons.description;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Populate form with current template data
    _populateForm();

    // Track listeners for changes
    _titleController.addListener(_markChanged);
    _descriptionController.addListener(_markChanged);
    _bodyController.addListener(_markChanged);
    _tagsController.addListener(_markChanged);

    // Track dialog opened
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Edit template dialog opened',
          category: 'ui_interaction',
          data: {
            'template_id': widget.template.id,
            'template_title': widget.template.title,
          },
        ),
      );
    } catch (e) {
      _logger.error('Failed to track edit template dialog', error: e);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _populateForm() {
    _titleController.text = widget.template.title;
    _descriptionController.text = widget.template.description;
    _bodyController.text = widget.template.body;
    _selectedCategory = widget.template.category;

    // Parse tags
    final tags = _parseTags(widget.template.tags);
    _tagsController.text = tags.join(', ');

    // Set icon (try to parse from metadata or use category default)
    _selectedIcon =
        _parseIcon(widget.template) ?? _getCategoryIcon(_selectedCategory);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop()) {
          Navigator.of(context).pop(false);
        }
      },
      child: Dialog(
        clipBehavior: Clip.hardEdge,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: colorScheme.onPrimary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Template',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.template.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_hasChanges)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isLoading ? null : () => _handleClose(),
                      icon: Icon(Icons.close, color: colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.info_outline), text: 'Basic Info'),
                    Tab(icon: Icon(Icons.article), text: 'Content'),
                    Tab(icon: Icon(Icons.tune), text: 'Settings'),
                  ],
                ),
              ),

              // Form content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Basic Info tab
                      _buildBasicInfoTab(theme, colorScheme),

                      // Content tab
                      _buildContentTab(theme, colorScheme),

                      // Settings tab
                      _buildSettingsTab(theme, colorScheme),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Template info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Last modified: ${_formatDateTime(widget.template.updatedAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Template ID: ${widget.template.id}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cancel button
                    TextButton(
                      onPressed: _isLoading ? null : () => _handleClose(),
                      child: const Text('Cancel'),
                    ),

                    const SizedBox(width: 16),

                    // Save button
                    DuruButton(
                      onPressed: _isLoading || !_hasChanges
                          ? null
                          : _saveTemplate,
                      variant: DuruButtonVariant.primary,
                      isLoading: _isLoading,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isLoading) ...[
                            const Icon(Icons.save),
                            SizedBox(width: DuruSpacing.xs),
                          ],
                          Text(_isLoading ? 'Saving...' : 'Save Changes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Template Title *',
              hintText: 'Enter a descriptive title for your template',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Template title is required';
              }
              if (value.trim().length < 3) {
                return 'Template title must be at least 3 characters';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 20),

          // Template description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Brief description of what this template is for',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 20),

          // Category selection
          Text(
            'Category *',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: templateCategories.map((category) {
                final isSelected = _selectedCategory == category;
                return ListTile(
                  leading: Icon(
                    _getCategoryIcon(category),
                    color: isSelected ? colorScheme.primary : null,
                  ),
                  title: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      if (_selectedIcon ==
                          _getCategoryIcon(widget.template.category)) {
                        // Update icon if it was using the old category's default
                        _selectedIcon = _getCategoryIcon(category);
                      }
                    });
                    _markChanged();
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template content
          Text(
            'Template Content *',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bodyController,
            decoration: const InputDecoration(
              hintText:
                  'Enter your template content here...\n\nTip: Use {{variable}} for placeholders',
              border: OutlineInputBorder(),
            ),
            maxLines: 12,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Template content is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Content statistics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Content Statistics',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_bodyController.text.length} characters • '
                        '${_getWordCount(_bodyController.text)} words • '
                        '${_extractVariables(_bodyController.text).length} variables',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Variable helper
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Template Variables',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap to insert variable at cursor position:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            '{{date}}',
                            '{{time}}',
                            '{{datetime}}',
                            '{{title}}',
                            '{{name}}',
                            '{{project}}',
                          ]
                          .map(
                            (variable) => InkWell(
                              onTap: () => _insertVariable(variable),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.tertiary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  variable,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tags
          TextFormField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'Enter tags separated by commas',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_offer),
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon selection
          Text(
            'Template Icon',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: templateIcons.length,
              itemBuilder: (context, index) {
                final icon = templateIcons[index];
                final isSelected = _selectedIcon == icon;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                    _markChanged();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary)
                          : Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Preview section
          Text(
            'Template Preview',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(_selectedCategory),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_selectedIcon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleController.text.isEmpty
                                ? widget.template.title
                                : _titleController.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _selectedCategory.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_hasChanges) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'MODIFIED',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_descriptionController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _descriptionController.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Usage info
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.template.category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.update,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(widget.template.updatedAt),
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
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _handleClose() async {
    if (await _onWillPop()) {
      Navigator.of(context).pop(false);
    }
  }

  void _insertVariable(String variable) {
    final currentPosition = _bodyController.selection.base.offset;
    final currentText = _bodyController.text;

    final newText =
        currentText.substring(0, currentPosition) +
        variable +
        currentText.substring(currentPosition);

    _bodyController.value = _bodyController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: currentPosition + variable.length,
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      // Find the first tab with validation errors
      if (_titleController.text.trim().isEmpty ||
          _bodyController.text.trim().isEmpty) {
        _tabController.animateTo(_titleController.text.trim().isEmpty ? 0 : 1);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(templateCoreRepositoryProvider);
      final analytics = ref.read(analyticsProvider);

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Fetch existing template from repository
      final existing = await repository.getTemplateById(widget.template.id);
      if (existing == null) {
        throw Exception('Template not found: ${widget.template.id}');
      }

      // Create updated template with new values
      final updatedTemplate = existing.copyWith(
        name: _titleController.text.trim(),
        content: _bodyController.text.trim(),
        variables: {
          'tags': tags,
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
          'icon': _getIconName(_selectedIcon),
          'last_edited': DateTime.now().toIso8601String(),
          'icon_data': _selectedIcon.codePoint,
        },
        updatedAt: DateTime.now(),
      );

      await repository.updateTemplate(updatedTemplate);

      _logger.info(
        'Template updated successfully',
        data: {
          'template_id': widget.template.id,
          'category': _selectedCategory,
          'has_variables': _hasVariables(_bodyController.text),
          'content_length_change':
              _bodyController.text.length - widget.template.body.length,
        },
      );

      // Track analytics
      analytics.event(
        'template_updated',
        properties: {
          'template_category': _selectedCategory,
          'has_variables': _hasVariables(_bodyController.text),
          'content_length': _bodyController.text.length,
          'has_tags': tags.isNotEmpty,
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Template "${_titleController.text.trim()}" updated successfully',
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update template',
        error: e,
        stackTrace: stackTrace,
        data: {
          'template_id': widget.template.id,
          'template_title': _titleController.text.trim(),
        },
      );

      Sentry.captureException(e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update template: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> _parseTags(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return [];

    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (e) {
      _logger.error(
        'Failed to parse template tags',
        error: e,
        stackTrace: StackTrace.current,
      );
    }

    return [];
  }

  /// Const map of icon codepoints for tree-shaking compatibility
  static const Map<int, IconData> _iconCodepointMap = {
    0xe8f9: Icons.work, // work
    0xe7ef: Icons.person, // person
    0xe80c: Icons.school, // school
    0xe8b8: Icons.palette, // palette
    0xe8d1: Icons.meeting_room, // meeting_room
    0xe616: Icons.event_note, // event_note
    0xef42: Icons.article, // article
    0xe89c: Icons.note_add, // note_add
    0xe85d: Icons.assignment, // assignment
    0xf87e: Icons.task_alt, // task_alt
    0xe90f: Icons.lightbulb, // lightbulb
    0xe873: Icons.description, // description
  };

  IconData? _parseIcon(LocalTemplate template) {
    // Try to parse icon from metadata
    if (template.metadata != null) {
      try {
        final metadata = jsonDecode(template.metadata!);
        if (metadata is Map<String, dynamic> && metadata['icon_data'] != null) {
          final codePoint = metadata['icon_data'] as int;
          // Use const map lookup instead of dynamic IconData creation
          return _iconCodepointMap[codePoint];
        }
      } catch (e) {
        _logger.debug('Failed to parse icon from metadata: $e');
      }
    }

    // Fallback to icon name mapping
    return _getIconFromName(template.icon);
  }

  IconData? _getIconFromName(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'person':
        return Icons.person;
      case 'school':
        return Icons.school;
      case 'palette':
        return Icons.palette;
      case 'meeting_room':
        return Icons.meeting_room;
      case 'event_note':
        return Icons.event_note;
      case 'article':
        return Icons.article;
      case 'note_add':
        return Icons.note_add;
      case 'assignment':
        return Icons.assignment;
      case 'task_alt':
        return Icons.task_alt;
      case 'lightbulb':
        return Icons.lightbulb;
      default:
        return Icons.description;
    }
  }

  bool _hasVariables(String content) {
    return RegExp(r'\{\{[^}]+\}\}').hasMatch(content);
  }

  List<String> _extractVariables(String content) {
    final RegExp variablePattern = RegExp(r'\{\{([^}]+)\}\}');
    return variablePattern
        .allMatches(content)
        .map((match) => '{{${match.group(1)}}}')
        .toSet()
        .toList();
  }

  int _getWordCount(String text) {
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.green;
      case 'academic':
        return Colors.purple;
      case 'creative':
        return Colors.orange;
      case 'meeting':
        return Colors.red;
      case 'planning':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
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

  String _getIconName(IconData icon) {
    // Map IconData to string representation for storage
    switch (icon) {
      case Icons.work:
        return 'work';
      case Icons.person:
        return 'person';
      case Icons.school:
        return 'school';
      case Icons.palette:
        return 'palette';
      case Icons.meeting_room:
        return 'meeting_room';
      case Icons.event_note:
        return 'event_note';
      case Icons.article:
        return 'article';
      case Icons.note_add:
        return 'note_add';
      case Icons.assignment:
        return 'assignment';
      case Icons.task_alt:
        return 'task_alt';
      case Icons.lightbulb:
        return 'lightbulb';
      default:
        return 'description';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
