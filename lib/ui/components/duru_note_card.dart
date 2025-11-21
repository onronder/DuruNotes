import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart'
    show filteredNotesProvider, currentNotesProvider, notesPageProvider;
import 'package:duru_notes/features/folders/enhanced_move_to_folder_dialog.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/ui/utils/accessibility_helper.dart';
import 'package:duru_notes/ui/helpers/domain_note_helpers.dart';

/// Unified note card variants
enum NoteCardVariant {
  compact, // Minimal height, just title and date
  standard, // Title, content preview, and metadata
  detailed, // Full content, tasks, attachments, etc.
}

/// Unified note card component that replaces all other note card implementations
/// Works with domain.Note entities only (post-encryption migration)
class DuruNoteCard extends StatelessWidget {
  final domain.Note note;
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
  });

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
    final title = note.title;
    final isPinned = note.isPinned;

    return A11yHelper.noteCard(
      title: title,
      date: _formatDate(),
      isPinned: isPinned,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
                    A11yHelper.decorative(
                      Padding(
                        padding: EdgeInsets.only(right: DuruSpacing.xs),
                        child: Icon(
                          CupertinoIcons.pin_fill,
                          size: 14,
                          color: DuruColors.accent,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        title.isEmpty ? 'Untitled Note' : title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      _formatDate(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract properties from domain entity
    final title = note.title;
    final content = note.body;
    final isPinned = note.isPinned;

    return A11yHelper.noteCard(
      title: title,
      content: content,
      date: _formatDate(),
      isPinned: isPinned,
      hasAttachments: _hasAttachments(),
      hasTasks: _hasTaskIndicator(),
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
                          colors: [DuruColors.accent, DuruColors.primary],
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
                              child: ExcludeSemantics(
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
                            ),
                            if (!isSelected)
                              A11yHelper.iconButton(
                                label:
                                    'More options for ${title.isEmpty ? "untitled note" : title}',
                                hint:
                                    'Open menu with edit, share, move, pin, and delete actions',
                                onPressed: () => _showNoteMenu(context),
                                child: IconButton(
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
                              ),
                          ],
                        ),

                        // Content preview
                        if (content.isNotEmpty) ...[
                          SizedBox(height: DuruSpacing.sm),
                          ExcludeSemantics(
                            child: Text(
                              content,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],

                        // Metadata row
                        SizedBox(height: DuruSpacing.sm),
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              Text(
                                _formatDate(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const Spacer(),
                              if (showTasks && _hasTaskIndicator()) ...[
                                Icon(
                                  CupertinoIcons.checkmark_circle,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                SizedBox(width: DuruSpacing.xs),
                              ],
                              if (_hasAttachments()) ...[
                                Icon(
                                  CupertinoIcons.paperclip,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                SizedBox(width: DuruSpacing.xs),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildDetailed(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract all properties from domain entity
    final title = note.title;
    final content = note.body;
    final isPinned = note.isPinned;

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
                        colors: [DuruColors.accent, DuruColors.primary],
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
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
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
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.3),
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
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          SizedBox(width: DuruSpacing.xs),
                          Text(
                            _getTimestampText(note),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
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

  /// Format date: Show createdAt unless note was actually edited
  /// If updatedAt is different from createdAt, show updatedAt (note was edited)
  /// Otherwise show createdAt (note was never edited)
  String _formatDate() {
    final createdAt = note.createdAt;
    final updatedAt = note.updatedAt;

    // Check if note was actually edited (timestamps differ by more than 1 second)
    final timeDiff = updatedAt.difference(createdAt).abs();
    final wasEdited = timeDiff.inSeconds > 1;

    // Show updatedAt only if note was actually edited, otherwise show createdAt
    final displayDate = wasEdited ? updatedAt : createdAt;

    final now = DateTime.now();
    final diff = now.difference(displayDate);

    if (diff.inDays == 0) {
      return DateFormat.jm().format(displayDate);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(displayDate);
    } else {
      return DateFormat.MMMd().format(displayDate);
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

  /// Get timestamp text following the rule:
  /// - If updatedAt equals createdAt, show "Created {time}"
  /// - Otherwise, show "Last updated {time}"
  String _getTimestampText(domain.Note note) {
    final createdAt = note.createdAt;
    final updatedAt = note.updatedAt;

    // Compare timestamps (allow 1 second tolerance for rounding)
    final isJustCreated = updatedAt.difference(createdAt).abs().inSeconds <= 1;

    if (isJustCreated) {
      return 'Created ${_formatDateRelative(createdAt)}';
    } else {
      return 'Last updated ${_formatDateRelative(updatedAt)}';
    }
  }

  bool _hasTaskIndicator() {
    // Check if note has tasks
    // This would need to be implemented based on your task system
    return false;
  }

  bool _hasAttachments() => DomainNoteHelpers.hasAttachments(note);

  Future<void> _togglePin(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final logger = LoggerFactory.instance;
    final notesRepo = container.read(notesCoreRepositoryProvider);
    final shouldPin = !note.isPinned;

    try {
      await notesRepo.setNotePin(note.id, shouldPin);

      container.invalidate(filteredNotesProvider);
      container.invalidate(currentNotesProvider);
      await container.read(notesPageProvider.notifier).refresh();

      if (context.mounted) {
        final message = shouldPin ? 'Note pinned' : 'Note unpinned';
        final icon = shouldPin ? CupertinoIcons.pin_fill : CupertinoIcons.pin;

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(message),
                ],
              ),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
      }
    } catch (error, stackTrace) {
      logger.error(
        'Failed to toggle note pin state',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': note.id, 'targetState': shouldPin},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Failed to update pin status'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
      }
    }
  }

  Future<void> _openMoveToFolderDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnhancedMoveToFolderDialog(
        noteIds: [note.id],
        currentFolderId: note.folderId,
        onMoveCompleted: (result) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = Navigator.of(context);
            if (!navigator.mounted) {
              return;
            }

            final messengerState = ScaffoldMessenger.maybeOf(context);
            if (messengerState == null) {
              return;
            }

            final theme = Theme.of(context);

            messengerState
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(result.getStatusMessage()),
                  backgroundColor: result.hasErrors
                      ? theme.colorScheme.error
                      : theme.colorScheme.tertiary,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
          });
        },
      ),
    );
  }

  void _showNoteMenu(BuildContext context) {
    final rootContext = context;
    final isPinned = note.isPinned;
    final pinLabel = isPinned ? 'Unpin' : 'Pin';
    final pinHint = isPinned ? 'Unpin this note' : 'Pin this note to the top';
    final pinIcon = isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin;

    showModalBottomSheet<void>(
      context: rootContext,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(DuruSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            A11yHelper.menuItem(
              label: 'Edit',
              hint: 'Edit this note',
              icon: CupertinoIcons.pencil,
              onTap: () {
                Navigator.pop(sheetContext);
                onTap?.call();
              },
              child: ListTile(
                leading: const Icon(CupertinoIcons.pencil),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onTap?.call();
                },
              ),
            ),
            A11yHelper.menuItem(
              label: 'Share',
              hint: 'Share this note with others',
              icon: CupertinoIcons.share,
              onTap: () => Navigator.pop(sheetContext),
              child: ListTile(
                leading: const Icon(CupertinoIcons.share),
                title: const Text('Share'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ),
            A11yHelper.menuItem(
              label: 'Move to folder',
              hint: 'Organize this note into a folder',
              icon: CupertinoIcons.folder,
              onTap: () async {
                Navigator.pop(sheetContext);
                await _openMoveToFolderDialog(rootContext);
              },
              child: ListTile(
                leading: const Icon(CupertinoIcons.folder),
                title: const Text('Move to folder'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _openMoveToFolderDialog(rootContext);
                },
              ),
            ),
            A11yHelper.menuItem(
              label: pinLabel,
              hint: pinHint,
              icon: pinIcon,
              onTap: () => Navigator.pop(sheetContext),
              child: ListTile(
                leading: Icon(pinIcon),
                title: Text(pinLabel),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _togglePin(rootContext);
                },
              ),
            ),
            A11yHelper.menuItem(
              label: 'Delete',
              hint: 'Delete this note permanently',
              icon: CupertinoIcons.delete,
              onTap: () => Navigator.pop(sheetContext),
              child: ListTile(
                leading: const Icon(CupertinoIcons.delete),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
