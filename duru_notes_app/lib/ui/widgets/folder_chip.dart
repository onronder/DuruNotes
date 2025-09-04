import 'package:flutter/material.dart';

class FolderChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showAddIcon;

  const FolderChip({
    super.key,
    required this.label,
    this.color,
    this.icon = Icons.folder,
    this.isSelected = false,
    this.onTap,
    this.showAddIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Material(
      color: isSelected 
          ? chipColor.withOpacity(0.2)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? chipColor : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showAddIcon ? Icons.add : icon,
                size: 16,
                color: isSelected ? chipColor : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? chipColor : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
