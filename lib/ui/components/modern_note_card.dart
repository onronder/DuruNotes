import 'package:flutter/material.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/components/dual_type_note_card.dart';

/// Modern note card with improved visual hierarchy and interactions
/// This is now a wrapper around DualTypeNoteCard for backward compatibility
class ModernNoteCard extends StatelessWidget {
  final LocalNote note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showTasks;

  const ModernNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showTasks = true,
  });

  @override
  Widget build(BuildContext context) {
    // Delegate to DualTypeNoteCard which handles both LocalNote and domain.Note
    return DualTypeNoteCard(
      note: note,
      onTap: onTap,
      onLongPress: onLongPress,
      isSelected: isSelected,
      showTasks: showTasks,
    );
  }
}