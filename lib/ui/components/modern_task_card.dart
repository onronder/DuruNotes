import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';
import 'package:duru_notes/ui/components/dual_type_task_card.dart';

/// Modern task card widget with improved visual design
/// This is now a wrapper around DualTypeTaskCard for backward compatibility
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenNote,
  });

  final NoteTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    // Delegate to DualTypeTaskCard which handles both NoteTask and domain.Task
    return DualTypeTaskCard(
      task: task,
      onToggle: onToggle,
      onEdit: onEdit,
      onDelete: onDelete,
      onOpenNote: onOpenNote,
    );
  }
}