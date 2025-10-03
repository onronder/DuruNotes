import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget that displays breadcrumb navigation for folders
class FolderBreadcrumbsWidget extends ConsumerWidget {
  const FolderBreadcrumbsWidget({super.key, this.folderId, this.onFolderTap});

  final String? folderId;
  final void Function(String? folderId)? onFolderTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (folderId == null) {
      // In inbox, show only inbox
      return _buildBreadcrumb(
        context,
        icon: Icons.inbox,
        label: 'Inbox',
        isLast: true,
        onTap: () => onFolderTap?.call(null),
      );
    }

    final folderRepo = ref.watch(folderRepositoryProvider);

    return FutureBuilder<List<LocalFolder>>(
      future: folderRepo.getFolderBreadcrumbs(folderId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final breadcrumbs = snapshot.data!;
        if (breadcrumbs.isEmpty) {
          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Home/Inbox
              _buildBreadcrumb(
                context,
                icon: Icons.home,
                label: 'Home',
                isLast: false,
                onTap: () => onFolderTap?.call(null),
              ),
              // Separator
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
              // Folder breadcrumbs
              ...breadcrumbs.asMap().entries.expand((entry) {
                final index = entry.key;
                final folder = entry.value;
                final isLast = index == breadcrumbs.length - 1;

                return [
                  _buildBreadcrumb(
                    context,
                    icon: isLast ? Icons.folder_open : Icons.folder,
                    label: folder.name,
                    isLast: isLast,
                    color: folder.color != null
                        ? Color(
                            int.parse(folder.color!.replaceFirst('#', '0xff')),
                          )
                        : null,
                    onTap: isLast ? null : () => onFolderTap?.call(folder.id),
                  ),
                  if (!isLast)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                ];
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumb(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isLast,
    Color? color,
    VoidCallback? onTap,
  }) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLast ? Theme.of(context).colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ??
                (isLast
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
              color: isLast
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: widget,
      );
    }

    return widget;
  }
}
