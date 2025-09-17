import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility utilities for consistent semantic labeling
class AccessibilityUtils {
  AccessibilityUtils._();

  /// Minimum touch target size as per Material Design guidelines
  static const double minTouchTarget = 44;

  /// Wrap a widget with proper semantics for a button
  static Widget semanticButton({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      enabled: enabled,
      onTap: onTap,
      child: SizedBox(
        width: minTouchTarget,
        height: minTouchTarget,
        child: Center(child: child),
      ),
    );
  }

  /// Wrap a chip with proper semantics
  static Widget semanticChip({
    required Widget child,
    required String label,
    bool selected = false,
    bool deletable = false,
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      hint: deletable ? 'Double tap to remove' : null,
      onTap: onTap,
      onLongPress: onDelete,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minTouchTarget),
        child: child,
      ),
    );
  }

  /// Wrap a toggle with proper semantics
  static Widget semanticToggle({
    required Widget child,
    required String label,
    required bool value,
    VoidCallback? onToggle,
  }) {
    return Semantics(
      label: label,
      value: value ? 'On' : 'Off',
      toggled: value,
      onTap: onToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minTouchTarget),
        child: child,
      ),
    );
  }

  /// Announce a message to screen readers
  static void announce(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Create an accessible list item
  static Widget semanticListItem({
    required Widget child,
    required String label,
    String? value,
    String? hint,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      value: value,
      hint: hint,
      selected: selected,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          child: child,
        ),
      ),
    );
  }

  /// Ensure minimum touch target size
  static Widget ensureMinTouchTarget(Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minTouchTarget,
        minHeight: minTouchTarget,
      ),
      child: child,
    );
  }
}
