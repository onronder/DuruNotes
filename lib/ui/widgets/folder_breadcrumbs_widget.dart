import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final AppLogger _logger = LoggerFactory.instance;

/// Displays folder path as clickable breadcrumbs for navigation
class FolderBreadcrumbsWidget extends StatelessWidget {
  const FolderBreadcrumbsWidget({
    required this.breadcrumbs,
    required this.onFolderTap,
    super.key,
    this.showHome = true,
  });
  final List<domain.Folder> breadcrumbs;
  final void Function(domain.Folder?) onFolderTap;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Home/Inbox button
          if (showHome) ...[
            _BreadcrumbChip(
              icon: Icons.home,
              label: 'Home',
              onTap: () => onFolderTap(null),
              isLast: breadcrumbs.isEmpty,
              colorScheme: colorScheme,
            ),
            if (breadcrumbs.isNotEmpty)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
          ],
          // Folder breadcrumbs
          ...breadcrumbs.asMap().entries.expand((entry) {
            final index = entry.key;
            final folder = entry.value;
            final isLast = index == breadcrumbs.length - 1;

            return [
              _BreadcrumbChip(
                icon: _getFolderIcon(folder),
                label: folder.name,
                onTap: () => onFolderTap(folder),
                isLast: isLast,
                color: _getFolderColor(folder),
                colorScheme: colorScheme,
              ),
              if (!isLast)
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
            ];
          }),
        ],
      ),
    );
  }

  IconData _getFolderIcon(domain.Folder folder) {
    if (folder.icon != null) {
      switch (folder.icon) {
        case 'work':
          return Icons.work;
        case 'personal':
          return Icons.person;
        case 'archive':
          return Icons.archive;
        case 'star':
          return Icons.star;
        default:
          return Icons.folder;
      }
    }
    return Icons.folder;
  }

  Color? _getFolderColor(domain.Folder folder) {
    if (folder.color != null) {
      try {
        return Color(int.parse(folder.color!.replaceFirst('#', '0xff')));
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'Invalid folder color ${folder.color} for ${folder.name}: $error\n$stackTrace',
          );
        }
        _logger.warning(
          'Invalid folder color string for breadcrumbs',
          data: {
            'folderId': folder.id,
            'folderName': folder.name,
            'rawColor': folder.color,
          },
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      }
    }
    return null;
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isLast,
    required this.colorScheme,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;
  final Color? color;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = isLast;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    color ??
                    (isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact breadcrumbs for limited space (e.g., app bar)
class CompactFolderBreadcrumbs extends StatelessWidget {
  const CompactFolderBreadcrumbs({
    required this.breadcrumbs,
    required this.onFolderTap,
    super.key,
    this.maxItems = 3,
  });
  final List<domain.Folder> breadcrumbs;
  final void Function(domain.Folder?) onFolderTap;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Truncate breadcrumbs if too many
    var displayBreadcrumbs = breadcrumbs;
    var hasMore = false;

    if (breadcrumbs.length > maxItems) {
      displayBreadcrumbs = [
        breadcrumbs.first,
        ...breadcrumbs.skip(breadcrumbs.length - maxItems + 1),
      ];
      hasMore = true;
    }

    return Row(
      children: [
        // Home button
        IconButton(
          icon: const Icon(Icons.home, size: 20),
          onPressed: () => onFolderTap(null),
          tooltip: 'Home',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (breadcrumbs.isNotEmpty) ...[
          Icon(
            Icons.chevron_right,
            size: 16,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          if (hasMore) ...[
            Text(
              '...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: displayBreadcrumbs.asMap().entries.expand((entry) {
                  final index = entry.key;
                  final folder = entry.value;
                  final isLast = (hasMore && index == 0)
                      ? false
                      : index == displayBreadcrumbs.length - 1;

                  return [
                    GestureDetector(
                      onTap: isLast
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onFolderTap(folder);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          folder.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isLast
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isLast
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                  ];
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
