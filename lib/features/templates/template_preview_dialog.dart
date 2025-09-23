import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Dialog for previewing template content and metadata
class TemplatePreviewDialog extends StatefulWidget {
  const TemplatePreviewDialog({
    super.key,
    required this.template,
  });

  final LocalTemplate template;

  @override
  State<TemplatePreviewDialog> createState() => _TemplatePreviewDialogState();
}

class _TemplatePreviewDialogState extends State<TemplatePreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _logger = LoggerFactory.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Track preview opened
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Template preview opened',
          category: 'ui_interaction',
          data: {'template_id': widget.template.id},
        ),
      );
    } catch (e) {
      _logger.error('Failed to track template preview', error: e);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getCategoryColor(widget.template.category),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getCategoryColor(widget.template.category),
                    _getCategoryColor(widget.template.category).withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and close button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.template.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Category and system badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(widget.template.category),
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.template.category.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.template.isSystem) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SYSTEM',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (widget.template.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.template.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.preview),
                    text: 'Preview',
                  ),
                  Tab(
                    icon: Icon(Icons.info_outline),
                    text: 'Details',
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Preview tab
                  _buildPreviewTab(theme, colorScheme),

                  // Details tab
                  _buildDetailsTab(theme, colorScheme),
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Secondary actions
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _copyTemplateContent(),
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy Content',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _shareTemplate(),
                          icon: const Icon(Icons.share),
                          tooltip: 'Share Template',
                        ),
                        if (!widget.template.isSystem) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop('edit'),
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit Template',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop('delete'),
                            icon: Icon(
                              Icons.delete,
                              color: colorScheme.error,
                            ),
                            tooltip: 'Delete Template',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Primary action
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop('use'),
                    icon: const Icon(Icons.note_add),
                    label: const Text('Use Template'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _getCategoryColor(widget.template.category),
                      foregroundColor: Colors.white,
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

  Widget _buildPreviewTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template content with placeholder highlighting
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.article,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Template Content',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.template.body.length} characters',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content body
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightedContent(widget.template.body, theme, colorScheme),

                      if (widget.template.body.isEmpty) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No content to preview',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Variables section
          if (_hasVariables(widget.template.body)) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.tertiary.withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.code,
                          size: 20,
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Template Variables',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Variables in this template will be replaced when creating a note:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._extractVariables(widget.template.body).map(
                      (variable) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                variable,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: colorScheme.tertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getVariableDescription(variable),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsTab(ThemeData theme, ColorScheme colorScheme) {
    final createdDate = _formatDateTime(widget.template.createdAt);
    final updatedDate = _formatDateTime(widget.template.updatedAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic information
          _buildDetailSection(
            'Basic Information',
            [
              _buildDetailRow('Template ID', widget.template.id, theme, colorScheme),
              _buildDetailRow('Title', widget.template.title, theme, colorScheme),
              _buildDetailRow('Category', widget.template.category, theme, colorScheme),
              _buildDetailRow('Type', widget.template.isSystem ? 'System Template' : 'User Template', theme, colorScheme),
            ],
            theme,
            colorScheme,
            Icons.info_outline,
          ),

          const SizedBox(height: 16),

          // Description
          if (widget.template.description.isNotEmpty)
            _buildDetailSection(
              'Description',
              [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.template.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              theme,
              colorScheme,
              Icons.description,
            ),

          const SizedBox(height: 16),

          // Usage statistics
          _buildDetailSection(
            'Usage Statistics',
            [
              // Usage count not available in current schema
              _buildDetailRow(
                'Template Type',
                widget.template.isSystem ? 'System Template' : 'User Template',
                theme,
                colorScheme,
              ),
              _buildDetailRow('Created', createdDate, theme, colorScheme),
              _buildDetailRow('Last Modified', updatedDate, theme, colorScheme),
            ],
            theme,
            colorScheme,
            Icons.analytics,
          ),

          const SizedBox(height: 16),

          // Content statistics
          _buildDetailSection(
            'Content Statistics',
            [
              _buildDetailRow('Characters', widget.template.body.length.toString(), theme, colorScheme),
              _buildDetailRow('Words', _getWordCount(widget.template.body).toString(), theme, colorScheme),
              _buildDetailRow('Lines', widget.template.body.split('\n').length.toString(), theme, colorScheme),
              _buildDetailRow('Variables', _extractVariables(widget.template.body).length.toString(), theme, colorScheme),
            ],
            theme,
            colorScheme,
            Icons.text_fields,
          ),

          const SizedBox(height: 16),

          // Tags (if any)
          if (widget.template.tags != null && widget.template.tags!.isNotEmpty)
            _buildDetailSection(
              'Tags',
              [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _parseTags(widget.template.tags!).map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ],
              theme,
              colorScheme,
              Icons.local_offer,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    List<Widget> children,
    ThemeData theme,
    ColorScheme colorScheme,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedContent(String content, ThemeData theme, ColorScheme colorScheme) {
    if (content.isEmpty) return const SizedBox.shrink();

    // Split content by variable patterns and highlight them
    final RegExp variablePattern = RegExp(r'\{\{[^}]+\}\}');
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in variablePattern.allMatches(content)) {
      // Add text before the variable
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: theme.textTheme.bodyMedium,
        ));
      }

      // Add the highlighted variable
      spans.add(TextSpan(
        text: match.group(0)!,
        style: theme.textTheme.bodyMedium?.copyWith(
          backgroundColor: colorScheme.tertiary.withOpacity(0.2),
          color: colorScheme.tertiary,
          fontWeight: FontWeight.w600,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: theme.textTheme.bodyMedium,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
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

  String _getVariableDescription(String variable) {
    final cleanVar = variable.replaceAll(RegExp(r'[{}]'), '').toLowerCase();

    switch (cleanVar) {
      case 'date':
        return 'Current date';
      case 'time':
        return 'Current time';
      case 'datetime':
        return 'Current date and time';
      case 'name':
        return 'Your name';
      case 'title':
        return 'Note title';
      case 'project':
        return 'Project name';
      case 'author':
        return 'Document author';
      default:
        return 'Custom variable';
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
      _logger.error('Failed to parse template tags', error: e);
    }

    return [];
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _copyTemplateContent() {
    try {
      Clipboard.setData(ClipboardData(text: widget.template.body));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template content copied to clipboard'),
        ),
      );

      _logger.info('Template content copied to clipboard', data: {
        'template_id': widget.template.id,
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to copy template content',
        error: e,
        stackTrace: stackTrace,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy content: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _shareTemplate() {
    try {
      // Here you would implement template sharing
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template sharing coming soon'),
        ),
      );

      _logger.info('Template share initiated', data: {
        'template_id': widget.template.id,
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to share template',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}