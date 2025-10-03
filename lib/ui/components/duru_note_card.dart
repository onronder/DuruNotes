import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/core/migration/ui_migration_utility.dart';
import 'package:intl/intl.dart';

/// Unified note card variants
enum NoteCardVariant {
  compact,  // Minimal height, just title and date
  standard, // Title, content preview, and metadata
  detailed, // Full content, tasks, attachments, etc.
}

/// Unified note card component that replaces all other note card implementations
/// Supports both LocalNote and domain.Note for migration compatibility
class DuruNoteCard extends StatelessWidget {
  final dynamic note; // Can be LocalNote or domain.Note
  final NoteCardVariant variant;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showTasks;
  final bool showAttachments;

  const DuruNoteCard({
    super.key,
    required this.note,
    this.variant = NoteCardVariant.standard,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showTasks = true,
    this.showAttachments = false,
  }) : assert(note is LocalNote || note is domain.Note,
            'Note must be either LocalNote or domain.Note');

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      NoteCardVariant.compact => _buildCompact(context),
      NoteCardVariant.standard => _buildStandard(context),
      NoteCardVariant.detailed => _buildDetailed(context),
    };
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final title = UiMigrationUtility.getNoteTitle(note);
    final updatedAt = UiMigrationUtility.getNoteUpdatedAt(note);
    final isPinned = UiMigrationUtility.getNoteIsPinned(note);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(DuruSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected
                  ? DuruColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? DuruColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isPinned)
                  Padding(
                    padding: EdgeInsets.only(right: DuruSpacing.xs),
                    child: Icon(
                      CupertinoIcons.pin_fill,
                      size: 14,
                      color: DuruColors.accent,
                    ),
                  ),
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Untitled Note' : title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(updatedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract properties using migration utility
    final title = UiMigrationUtility.getNoteTitle(note);
    final content = UiMigrationUtility.getNoteContent(note);
    final isPinned = UiMigrationUtility.getNoteIsPinned(note);
    final updatedAt = UiMigrationUtility.getNoteUpdatedAt(note);

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
                  ? DuruColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? DuruColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pin indicator bar
                if (isPinned)
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

                Padding(
                  padding: EdgeInsets.all(DuruSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.isEmpty ? 'Untitled Note' : title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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

                      // Content preview
                      if (content.isNotEmpty) ...[
                        SizedBox(height: DuruSpacing.sm),
                        Text(
                          content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Metadata row
                      SizedBox(height: DuruSpacing.sm),
                      Row(
                        children: [
                          Text(
                            _formatDate(updatedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          if (showTasks && _hasTaskIndicator()) ...[
                            Icon(
                              CupertinoIcons.checkmark_circle,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            SizedBox(width: DuruSpacing.xs),
                          ],
                          if (_hasAttachments()) ...[
                            Icon(
                              CupertinoIcons.paperclip,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            SizedBox(width: DuruSpacing.xs),
                          ],
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

  Widget _buildDetailed(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract all properties
    final title = UiMigrationUtility.getNoteTitle(note);
    final content = UiMigrationUtility.getNoteContent(note);
    final isPinned = UiMigrationUtility.getNoteIsPinned(note);
    final updatedAt = UiMigrationUtility.getNoteUpdatedAt(note);

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
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? DuruColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? DuruColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pin indicator
                if (isPinned)
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DuruColors.accent,
                          DuruColors.primary,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.all(DuruSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title.isEmpty ? 'Untitled Note' : title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),

                      // Full content
                      if (content.isNotEmpty) ...[
                        SizedBox(height: DuruSpacing.md),
                        Text(
                          content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.6,
                          ),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Task preview if available
                      if (showTasks && _hasTaskIndicator()) ...[
                        SizedBox(height: DuruSpacing.md),
                        Container(
                          padding: EdgeInsets.all(DuruSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_circle,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              SizedBox(width: DuruSpacing.sm),
                              Text(
                                'Contains tasks',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Attachment preview if available
                      if (showAttachments && _hasAttachments()) ...[
                        SizedBox(height: DuruSpacing.md),
                        Container(
                          padding: EdgeInsets.all(DuruSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.paperclip,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              SizedBox(width: DuruSpacing.sm),
                              Text(
                                'Has attachments',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Metadata footer
                      SizedBox(height: DuruSpacing.md),
                      Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      SizedBox(height: DuruSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          SizedBox(width: DuruSpacing.xs),
                          Text(
                            'Updated ${_formatDateRelative(updatedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          if (!isSelected)
                            TextButton(
                              onPressed: () => _showNoteMenu(context),
                              child: Text(
                                'More',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat.jm().format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(date);
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  String _formatDateRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  bool _hasTaskIndicator() {
    // Check if note has tasks
    // This would need to be implemented based on your task system
    return false;
  }

  bool _hasAttachments() {
    // Check if note has attachments
    if (note is LocalNote) {
      final attachmentMeta = note.attachmentMeta;
      return attachmentMeta != null && (attachmentMeta as String).isNotEmpty;
    } else if (note is domain.Note) {
      final attachmentMeta = note.attachmentMeta;
      return attachmentMeta != null && (attachmentMeta as Map<String, dynamic>).isNotEmpty;
    }
    return false;
  }

  void _showNoteMenu(BuildContext context) {
    // Implement note menu actions
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(DuruSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.pencil),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onTap?.call();
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.share),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.folder),
              title: const Text('Move to folder'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.pin),
              title: const Text('Pin'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.delete),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}