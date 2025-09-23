import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/platform_adaptive_widgets.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:intl/intl.dart';

/// Modern note card with improved visual hierarchy and interactions
class ModernNoteCard extends StatelessWidget {
  final LocalNote note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showTasks;

  const ModernNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showTasks = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? DuruColors.primary.withOpacity(0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? DuruColors.primary
                    : theme.colorScheme.outline.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with pin indicator and menu
                if (note.isPinned) ...[
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DuruColors.accent,
                          DuruColors.primary,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),
                ],

                Padding(
                  padding: EdgeInsets.all(DuruSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and icon row
                      Row(
                        children: [
                          if (_getIcon() != null) ...[
                            Container(
                              padding: EdgeInsets.all(DuruSpacing.sm),
                              decoration: BoxDecoration(
                                color: _getIconColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getIcon(),
                                size: 20,
                                color: _getIconColor(),
                              ),
                            ),
                            SizedBox(width: DuruSpacing.sm),
                          ],
                          Expanded(
                            child: Text(
                              note.title.isEmpty ? 'Untitled Note' : note.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Modern menu button
                          if (!isSelected)
                            IconButton(
                              onPressed: () => _showNoteMenu(context),
                              icon: Icon(
                                CupertinoIcons.ellipsis,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),

                      // Content preview with better truncation
                      if (note.content.isNotEmpty) ...[
                        SizedBox(height: DuruSpacing.sm),
                        Text(
                          _cleanContent(note.content),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Task indicators
                      if (showTasks && _hasChecklistItems()) ...[
                        SizedBox(height: DuruSpacing.md),
                        _buildTaskIndicator(context),
                      ],

                      // Footer with metadata
                      SizedBox(height: DuruSpacing.md),
                      Row(
                        children: [
                          // Folder indicator
                          if (note.folderId != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: DuruSpacing.sm,
                                vertical: DuruSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: DuruColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.folder_fill,
                                    size: 12,
                                    color: DuruColors.primary,
                                  ),
                                  SizedBox(width: DuruSpacing.xs),
                                  Text(
                                    'Folder',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: DuruColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: DuruSpacing.sm),
                          ],

                          // Attachment indicator
                          if (note.hasAttachments) ...[
                            Icon(
                              CupertinoIcons.paperclip,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            SizedBox(width: DuruSpacing.sm),
                          ],

                          const Spacer(),

                          // Time indicator with smart formatting
                          Text(
                            _formatTime(note.modifiedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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

  IconData? _getIcon() {
    if (_hasChecklistItems()) return CupertinoIcons.checkmark_square;
    if (note.hasAttachments) return CupertinoIcons.photo;
    if (note.content.toLowerCase().contains('project')) return CupertinoIcons.briefcase;
    return null;
  }

  Color _getIconColor() {
    if (_hasChecklistItems()) return DuruColors.accent;
    if (note.hasAttachments) return Colors.orange;
    if (note.content.toLowerCase().contains('project')) return DuruColors.primary;
    return Colors.grey;
  }

  bool _hasChecklistItems() {
    return note.content.contains('[ ]') || note.content.contains('[x]');
  }

  String _cleanContent(String content) {
    // Remove checklist syntax for preview
    return content
        .replaceAll(RegExp(r'\[[ x]\]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
  }

  Widget _buildTaskIndicator(BuildContext context) {
    final completed = RegExp(r'\[x\]').allMatches(note.content).length;
    final total = completed + RegExp(r'\[ \]').allMatches(note.content).length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: EdgeInsets.all(DuruSpacing.sm),
      decoration: BoxDecoration(
        color: DuruColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? DuruColors.accent : DuruColors.primary,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? DuruColors.accent : DuruColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(width: DuruSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed of $total tasks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: DuruSpacing.xs),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? DuruColors.accent : DuruColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat.MMMd().format(time);
  }

  void _showNoteMenu(BuildContext context) {
    // TODO: Implement modern context menu
  }
}