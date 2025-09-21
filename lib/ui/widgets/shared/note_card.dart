import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Shared note card widget with accessibility support
class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.note,
    required this.onTap,
    super.key,
    this.onLongPress,
    this.onDelete,
    this.onPin,
    this.isGrid = false,
    this.isSelected = false,
  });

  final LocalNote note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final bool isGrid;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // Format date
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    final timeFormat = DateFormat.jm(l10n.localeName);
    final updatedDate = dateFormat.format(note.updatedAt);
    final updatedTime = timeFormat.format(note.updatedAt);

    // Prepare content preview
    final preview = _getPreviewText(note.body);

    // Card styling
    final cardColor = isSelected
        ? colorScheme.primaryContainer
        : note.isPinned
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surface;

    final borderColor = isSelected
        ? colorScheme.primary
        : note.isPinned
            ? colorScheme.primary.withValues(alpha: 0.3)
            : colorScheme.outline.withValues(alpha: 0.2);

    return Semantics(
      label:
          '${note.title}. $preview. ${l10n.dateModified}: $updatedDate $updatedTime',
      button: true,
      selected: isSelected,
      onTapHint: l10n.edit,
      onLongPressHint: onLongPress != null ? 'Select for actions' : null,
      child: Card(
        elevation: isSelected ? 4 : 1,
        margin: isGrid
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
        ),
        color: cardColor,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isGrid ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: isGrid ? MainAxisSize.min : MainAxisSize.max,
              children: [
                // Header with title and actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pin indicator
                    if (note.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.push_pin,
                          size: 16,
                          color: colorScheme.primary,
                          semanticLabel: l10n.pinnedNotes,
                        ),
                      ),

                    // Title
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? l10n.noTitle : note.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: note.title.isEmpty
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : null,
                        ),
                        maxLines: isGrid ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Actions menu
                    if (!isGrid && (onDelete != null || onPin != null))
                      _buildActionsMenu(context, colorScheme, l10n),
                  ],
                ),

                // Body preview
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                    maxLines: isGrid ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Tags - removed for now as tags need to be loaded separately
                // TODO: Load tags from database using getTagsForNote
                /*
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: note.tags.take(isGrid ? 2 : 3).map((tag) {
                      return Semantics(
                        label: '${l10n.tags}: $tag',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#$tag',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                */

                // Footer with date
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$updatedDate • $updatedTime',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),

                    // Attachment indicator
                    if (AppDb.noteHasAttachments(note))
                      Icon(
                        Icons.attach_file,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        semanticLabel: l10n.attachments,
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

  Widget _buildActionsMenu(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      tooltip: 'More actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            onPin?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onPin != null)
          PopupMenuItem(
            value: 'pin',
            child: Row(
              children: [
                Icon(
                  note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(note.isPinned ? l10n.unpinNote : l10n.pinNote),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  l10n.deleteNote,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getPreviewText(String body) {
    // Remove markdown formatting for preview
    var preview = body
        .replaceAll(RegExp(r'#{1,6}\s'), '') // Headers
        .replaceAll(RegExp(r'\*{1,2}([^\*]+)\*{1,2}'), r'$1') // Bold/italic
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // Links
        .replaceAll(RegExp('`([^`]+)`'), r'$1') // Code
        .replaceAll(RegExp(r'^\s*[-*+]\s', multiLine: true), '') // Lists
        .replaceAll(RegExp(r'\n+'), ' ') // Multiple newlines
        .trim();

    // Limit length
    const maxLength = 150;
    if (preview.length > maxLength) {
      preview = '${preview.substring(0, maxLength)}...';
    }

    return preview;
  }
}
