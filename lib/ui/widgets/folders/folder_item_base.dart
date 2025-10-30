import 'package:duru_notes/models/local_folder.dart';
import 'package:flutter/material.dart';

/// Base widget for folder display components
abstract class BaseFolderItem extends StatelessWidget {
  final LocalFolder folder;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int indentLevel;
  final int noteCount;
  final bool showNoteCount;
  final bool showActions;

  const BaseFolderItem({
    super.key,
    required this.folder,
    this.isSelected = false,
    this.isExpanded = false,
    this.onTap,
    this.onExpand,
    this.onEdit,
    this.onDelete,
    this.indentLevel = 0,
    this.noteCount = 0,
    this.showNoteCount = true,
    this.showActions = true,
  });

  /// Build folder icon based on state
  Widget buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    IconData iconData;
    if (folder.isSpecial) {
      iconData = _getSpecialFolderIcon();
    } else {
      iconData = isExpanded ? Icons.folder_open : Icons.folder;
    }

    return Icon(iconData, color: iconColor, size: 20);
  }

  /// Build folder title with appropriate styling
  Widget buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface,
    );

    return Text(
      folder.name,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build note count badge
  Widget buildNoteCount(BuildContext context) {
    if (!showNoteCount || noteCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        noteCount.toString(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build expand/collapse indicator for folders with children
  Widget buildExpandIndicator(BuildContext context) {
    if (!folder.hasChildren) {
      return const SizedBox(width: 24);
    }

    return GestureDetector(
      onTap: onExpand,
      child: Icon(
        isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Build action menu for folder operations
  Widget buildActionMenu(BuildContext context) {
    if (!showActions || (onEdit == null && onDelete == null)) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuItem<String>>[];

        if (onEdit != null && !folder.isSpecial) {
          items.add(
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
        }

        if (onDelete != null && !folder.isSpecial) {
          items.add(
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
        }

        return items;
      },
    );
  }

  /// Get icon for special system folders
  IconData _getSpecialFolderIcon() {
    switch (folder.specialType) {
      case 'inbox':
        return Icons.inbox;
      case 'archive':
        return Icons.archive;
      case 'trash':
        return Icons.delete_outline;
      case 'favorites':
        return Icons.star_outline;
      case 'recent':
        return Icons.access_time;
      case 'shared':
        return Icons.people_outline;
      default:
        return Icons.folder_special;
    }
  }
}

/// Standard list tile implementation of folder item
class FolderListItem extends BaseFolderItem {
  const FolderListItem({
    super.key,
    required super.folder,
    super.isSelected,
    super.isExpanded,
    super.onTap,
    super.onExpand,
    super.onEdit,
    super.onDelete,
    super.indentLevel,
    super.noteCount,
    super.showNoteCount,
    super.showActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.only(left: indentLevel * 16.0),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        border: isSelected
            ? Border(left: BorderSide(color: colorScheme.primary, width: 3))
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildExpandIndicator(context),
            const SizedBox(width: 4),
            buildIcon(context),
          ],
        ),
        title: buildTitle(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [buildNoteCount(context), buildActionMenu(context)],
        ),
        onTap: onTap,
        selected: isSelected,
      ),
    );
  }
}

/// Compact folder item for sidebar navigation
class CompactFolderItem extends BaseFolderItem {
  const CompactFolderItem({
    super.key,
    required super.folder,
    super.isSelected,
    super.isExpanded,
    super.onTap,
    super.onExpand,
    super.indentLevel,
    super.noteCount,
  }) : super(showActions: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: 8 + (indentLevel * 12.0),
          right: 8,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Row(
          children: [
            if (folder.hasChildren)
              buildExpandIndicator(context)
            else
              const SizedBox(width: 24),
            const SizedBox(width: 4),
            buildIcon(context),
            const SizedBox(width: 8),
            Expanded(child: buildTitle(context)),
            if (noteCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                noteCount.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
