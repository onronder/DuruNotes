import 'package:flutter/material.dart';

class FolderChip extends StatelessWidget {
  const FolderChip({
    required this.label,
    super.key,
    this.color,
    this.icon = Icons.folder,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.showAddIcon = false,
  });
  final String label;
  final Color? color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showAddIcon;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 380;

    return Material(
      color: isSelected ? chipColor.withValues(alpha: 0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 12,
            vertical: isCompact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showAddIcon ? Icons.add : icon,
                size: isCompact ? 14 : 16,
                color: isSelected
                    ? chipColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: isCompact ? 3 : 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: isCompact ? 12.5 : 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? chipColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
