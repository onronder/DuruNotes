import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart' show LocalNote;
import 'package:duru_notes/domain/entities/template.dart' as domain_template;
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show templateCoreRepositoryProvider;
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart' show analyticsProvider;
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/platform_adaptive_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

/// Available template categories
const List<String> templateCategories = [
  'work',
  'personal',
  'academic',
  'creative',
  'meeting',
  'planning',
  'other',
];

/// Available template icons
const List<IconData> templateIcons = [
  Icons.description,
  Icons.work,
  Icons.person,
  Icons.school,
  Icons.palette,
  Icons.meeting_room,
  Icons.event_note,
  Icons.article,
  Icons.note_add,
  Icons.assignment,
  Icons.task_alt,
  Icons.lightbulb,
];

/// Dialog for creating new templates
class CreateTemplateDialog extends ConsumerStatefulWidget {
  const CreateTemplateDialog({
    super.key,
    this.sourceNote,
    this.sourceTitle,
    this.sourceBody,
    this.sourceTags,
  });

  /// Optional source note to create template from (for metadata)
  final LocalNote? sourceNote;

  /// Optional pre-populated title (decrypted from source note)
  final String? sourceTitle;

  /// Optional pre-populated body (decrypted from source note)
  final String? sourceBody;

  /// Optional pre-populated tags
  final List<String>? sourceTags;

  @override
  ConsumerState<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends ConsumerState<CreateTemplateDialog>
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Pre-populate from source note if provided
    if (widget.sourceTitle != null) {
      _titleController.text = widget.sourceTitle!;
    }
    if (widget.sourceBody != null) {
      _bodyController.text = widget.sourceBody!;
    }
    if (widget.sourceTags != null && widget.sourceTags!.isNotEmpty) {
      _tagsController.text = widget.sourceTags!.join(', ');
    }

    // Extract category from source note metadata if available
    if (widget.sourceNote != null) {
      try {
        final metadata = widget.sourceNote!.encryptedMetadata;
        if (metadata != null && metadata.isNotEmpty) {
          // Could parse category from metadata here
          // For now, keep default 'personal'
        }
      } catch (e) {
        // Ignore metadata parsing errors
      }
    }

    // Track dialog opened
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Create template dialog opened',
          category: 'ui_interaction',
          data: {
            'has_source_note': widget.sourceNote != null,
            'source_note_id': widget.sourceNote?.id,
          },
        ),
      );
    } catch (e) {
      _logger.error('Failed to track create template dialog', error: e);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      clipBehavior: Clip.hardEdge,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(DuruSpacing.lg),
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
                  Icon(
                    Icons.add_circle,
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.sourceNote != null
                          ? 'Create Template from Note'
                          : 'Create New Template',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
                  Tab(
                    icon: Icon(Icons.info_outline),
                    text: 'Basic Info',
                  ),
                  Tab(
                    icon: Icon(Icons.article),
                    text: 'Content',
                  ),
                  Tab(
                    icon: Icon(Icons.tune),
                    text: 'Settings',
                  ),
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
              padding: EdgeInsets.all(DuruSpacing.lg),
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
                  // Preview button (more compact)
                  Expanded(
                    child: DuruButton(
                      onPressed: _isLoading ? null : _previewTemplate,
                      variant: DuruButtonVariant.outlined,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.preview, size: 14),
                          SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              'Preview',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Cancel button
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),

                  const SizedBox(width: 8),

                  // Create button (more compact)
                  Expanded(
                    child: DuruButton(
                      onPressed: _isLoading ? null : _createTemplate,
                      variant: DuruButtonVariant.primary,
                      isLoading: _isLoading,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isLoading) ...[
                            const Icon(Icons.check, size: 14),
                            const SizedBox(width: 2),
                          ],
                          Flexible(
                            child: Text(
                              _isLoading ? 'Creating...' : 'Create',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(DuruSpacing.lg),
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
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                      _selectedIcon = _getCategoryIcon(category);
                    });
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
      padding: EdgeInsets.all(DuruSpacing.lg),
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
              hintText: 'Enter your template content here...\n\nTip: Use {{variable}} for placeholders',
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

          // Variable helper
          Container(
            padding: EdgeInsets.all(DuruSpacing.md),
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
                  'Use these variables in your template. They will be replaced when creating a note:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '{{date}}',
                    '{{time}}',
                    '{{datetime}}',
                    '{{title}}',
                    '{{name}}',
                    '{{project}}',
                  ].map(
                    (variable) => InkWell(
                      onTap: () => _insertVariable(variable),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.tertiary.withValues(alpha: 0.3),
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
                  ).toList(),
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
      padding: EdgeInsets.all(DuruSpacing.lg),
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
            padding: EdgeInsets.all(DuruSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
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
                          : Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
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
            padding: EdgeInsets.all(DuruSpacing.md),
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
                      child: Icon(
                        _selectedIcon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleController.text.isEmpty
                                ? 'Template Title'
                                : _titleController.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedCategory.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _insertVariable(String variable) {
    final currentPosition = _bodyController.selection.base.offset;
    final currentText = _bodyController.text;

    final newText = currentText.substring(0, currentPosition) +
        variable +
        currentText.substring(currentPosition);

    _bodyController.value = _bodyController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: currentPosition + variable.length,
      ),
    );
  }

  void _previewTemplate() {
    // Switch to settings tab to show preview
    _tabController.animateTo(2);
  }

  Future<void> _createTemplate() async {
    if (!_formKey.currentState!.validate()) {
      // Find the first tab with validation errors
      if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
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

      // Create template using domain entity
      final templateToCreate = domain_template.Template(
        id: const Uuid().v4(),
        name: _titleController.text.trim(),
        content: _bodyController.text.trim(),
        variables: {
          'tags': tags,
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
          'icon': _getIconName(_selectedIcon),
          'created_from_note': widget.sourceNote != null,
          'source_note_id': widget.sourceNote?.id,
          'icon_data': _selectedIcon.codePoint,
        },
        isSystem: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final template = await repository.createTemplate(templateToCreate);

      _logger.info(
        'Template created successfully',
        data: {
          'template_id': template.id,
          'category': _selectedCategory,
          'has_variables': _hasVariables(_bodyController.text),
          'created_from_note': widget.sourceNote != null,
        },
      );

      // Track analytics
      analytics.event('template_created', properties: {
        'template_category': _selectedCategory,
        'has_variables': _hasVariables(_bodyController.text),
        'created_from_note': widget.sourceNote != null,
        'content_length': _bodyController.text.length,
        'has_tags': tags.isNotEmpty,
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${_titleController.text.trim()}" created successfully'),
            action: SnackBarAction(
              label: 'Use Now',
              onPressed: () {
                // Here you could immediately use the template
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create template',
        error: e,
        stackTrace: stackTrace,
        data: {
          'template_title': _titleController.text.trim(),
          'category': _selectedCategory,
        },
      );

      Sentry.captureException(e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create template: $e'),
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

  bool _hasVariables(String content) {
    return RegExp(r'\{\{[^}]+\}\}').hasMatch(content);
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
}