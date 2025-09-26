import 'package:flutter/material.dart';
import 'package:duru_notes/models/local_folder.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/providers/unified_providers.dart';
import 'package:duru_notes/core/models/unified_folder.dart' as models;

/// Unified folder item component that works with both LocalFolder and domain.Folder
/// Uses type-agnostic helpers to access properties regardless of model type
abstract class DualTypeFolderItem extends StatelessWidget {
  final dynamic folder; // Can be LocalFolder or domain.Folder
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

  const DualTypeFolderItem({
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

  /// Get folder ID using unified helper
  String get folderId => getUnifiedFolderId(folder as models.UnifiedFolder);

  /// Get folder name using unified helper
  String get folderName => getUnifiedFolderName(folder as models.UnifiedFolder);

  /// Check if folder is special (only for LocalFolder)
  bool get isSpecial {
    if (folder is LocalFolder) {
      return (folder as LocalFolder).isSpecial;
    }
    return false; // domain.Folder doesn't have special folders concept
  }

  /// Get special folder type (only for LocalFolder)
  String? get specialType {
    if (folder is LocalFolder) {
      return (folder as LocalFolder).specialType;
    }
    return null;
  }

  /// Check if folder has children (only for LocalFolder)
  bool get hasChildren {
    if (folder is LocalFolder) {
      return (folder as LocalFolder).hasChildren;
    }
    return false; // domain.Folder doesn't track children directly
  }

  /// Get folder color
  String? get color {
    if (folder is LocalFolder) {
      return (folder as LocalFolder).color;
    } else if (folder is domain.Folder) {
      return (folder as domain.Folder).color;
    }
    return null;
  }

  /// Get folder icon
  String? get icon {
    if (folder is LocalFolder) {
      return (folder as LocalFolder).icon;
    } else if (folder is domain.Folder) {
      return (folder as domain.Folder).icon;
    }
    return null;
  }

  /// Build folder icon based on state and type
  Widget buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    IconData iconData;

    // Use custom icon if available
    if (icon != null) {
      iconData = _parseIconData(icon!);
    } else if (isSpecial) {
      iconData = _getSpecialFolderIcon();
    } else {
      iconData = isExpanded ? Icons.folder_open : Icons.folder;
    }

    return Icon(
      iconData,
      color: color != null ? _parseColor(color!) : iconColor,
      size: 20,
    );
  }

  /// Build folder title with appropriate styling
  Widget buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color:
          isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
    );

    return Text(
      folderName,
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
          color:
              isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build expand/collapse indicator for folders with children
  Widget buildExpandIndicator(BuildContext context) {
    if (!hasChildren) {
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
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.5),
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

        if (onEdit != null && !isSpecial) {
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

        if (onDelete != null && !isSpecial) {
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
    switch (specialType) {
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

  /// Parse icon data from string representation
  IconData _parseIconData(String iconString) {
    // Simple icon mapping - in production this would be more sophisticated
    switch (iconString.toLowerCase()) {
      case 'folder':
        return Icons.folder;
      case 'folder_open':
        return Icons.folder_open;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'bookmark':
        return Icons.bookmark;
      case 'label':
        return Icons.label;
      case 'category':
        return Icons.category;
      default:
        return Icons.folder;
    }
  }

  /// Parse color from string representation
  Color _parseColor(String colorString) {
    // Simple color parsing - in production this would handle hex colors, etc.
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'teal':
        return Colors.teal;
      case 'indigo':
        return Colors.indigo;
      case 'pink':
        return Colors.pink;
      default:
        // Try to parse as hex color
        if (colorString.startsWith('#') && colorString.length == 7) {
          try {
            return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
          } catch (e) {
            return Colors.blue; // fallback
          }
        }
        return Colors.blue; // fallback
    }
  }
}

/// Standard list tile implementation of dual-type folder item
class DualTypeFolderListItem extends DualTypeFolderItem {
  const DualTypeFolderListItem({
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
            ? Border(
                left: BorderSide(
                  color: colorScheme.primary,
                  width: 3,
                ),
              )
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
          children: [
            buildNoteCount(context),
            buildActionMenu(context),
          ],
        ),
        onTap: onTap,
        selected: isSelected,
      ),
    );
  }
}

/// Compact dual-type folder item for sidebar navigation
class DualTypeCompactFolderItem extends DualTypeFolderItem {
  const DualTypeCompactFolderItem({
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
            if (hasChildren)
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