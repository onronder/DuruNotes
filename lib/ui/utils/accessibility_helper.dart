import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Comprehensive accessibility helper for WCAG 2.1 AA compliance
///
/// This utility class provides semantic wrappers and focus indicators
/// to make the app accessible to screen reader users and keyboard navigation.
///
/// Usage:
/// ```dart
/// A11yHelper.button(
///   label: 'Delete note',
///   hint: 'Permanently removes this note',
///   child: IconButton(...),
/// )
/// ```
class A11yHelper {
  A11yHelper._();

  // ============================================================================
  // SEMANTIC WRAPPERS
  // ============================================================================

  /// Wraps a button with proper semantics
  static Widget button({
    required String label,
    required Widget child,
    String? hint,
    bool enabled = true,
    VoidCallback? onTap,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: enabled,
      onTap: onTap,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  /// Wraps a checkbox with proper semantics
  static Widget checkbox({
    required String label,
    required bool value,
    required Widget child,
    String? hint,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      checked: value,
      enabled: enabled,
      onTap: onTap,
      child: child,
    );
  }

  /// Wraps a toggle switch with proper semantics
  static Widget toggle({
    required String label,
    required bool value,
    required Widget child,
    String? hint,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      toggled: value,
      enabled: enabled,
      onTap: onTap,
      child: child,
    );
  }

  /// Wraps a tappable item (like list item, card) with proper semantics
  static Widget tappable({
    required String label,
    required Widget child,
    String? hint,
    String? value,
    bool enabled = true,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool selected = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: true,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      child: child,
    );
  }

  /// Wraps a list item with proper semantics
  static Widget listItem({
    required String label,
    required Widget child,
    required int index,
    required int totalCount,
    String? hint,
    String? value,
    bool enabled = true,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Semantics(
      label: '$label. Item ${index + 1} of $totalCount',
      hint: hint,
      value: value,
      button: onTap != null,
      enabled: enabled,
      onTap: onTap,
      selected: selected,
      child: child,
    );
  }

  /// Wraps a header/heading with proper semantics
  static Widget header({
    required String label,
    required Widget child,
    bool header = true,
  }) {
    return Semantics(label: label, header: header, child: child);
  }

  /// Wraps an image with proper alt text
  static Widget image({
    required String label,
    required Widget child,
    String? hint,
  }) {
    return Semantics(label: label, hint: hint, image: true, child: child);
  }

  /// Wraps a link with proper semantics
  static Widget link({
    required String label,
    required Widget child,
    String? hint,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      link: true,
      onTap: onTap,
      child: child,
    );
  }

  /// Wraps a text input field with proper semantics
  static Widget textField({
    required String label,
    required Widget child,
    String? hint,
    String? value,
    bool enabled = true,
    bool obscured = false,
    bool multiline = false,
    bool readOnly = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      textField: true,
      enabled: enabled,
      obscured: obscured,
      multiline: multiline,
      readOnly: readOnly,
      child: child,
    );
  }

  /// Empty state with guidance
  static Widget emptyState({
    required String label,
    required Widget child,
    String? hint,
  }) {
    return Semantics(label: label, hint: hint, liveRegion: true, child: child);
  }

  /// Live region for dynamic content announcements
  static Widget liveRegion({
    required String label,
    required Widget child,
    bool assertive = false,
  }) {
    return Semantics(label: label, liveRegion: true, child: child);
  }

  /// Slider with proper semantics
  static Widget slider({
    required String label,
    required double value,
    required Widget child,
    String? hint,
    bool enabled = true,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value.toString(),
      slider: true,
      enabled: enabled,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: child,
    );
  }

  /// Progress indicator with semantic value
  static Widget progressIndicator({
    required String label,
    required Widget child,
    double? value,
  }) {
    final percentage = value != null ? '${(value * 100).round()}%' : 'Loading';
    return Semantics(
      label: '$label: $percentage',
      value: percentage,
      child: child,
    );
  }

  /// Excludes a widget from semantics tree (for decorative elements)
  static Widget decorative(Widget child) {
    return ExcludeSemantics(child: child);
  }

  /// Merges semantics of children (for complex widgets)
  static Widget merged({required Widget child, bool excluding = true}) {
    return MergeSemantics(child: child);
  }

  // ============================================================================
  // FOCUS INDICATORS
  // ============================================================================

  /// Wraps a widget with keyboard focus indicator
  static Widget focusable({
    required Widget child,
    FocusNode? focusNode,
    bool autofocus = false,
    ValueChanged<bool>? onFocusChange,
    Color? focusColor,
    double focusBorderWidth = 3.0,
    BorderRadius? borderRadius,
  }) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final theme = Theme.of(context);
          final effectiveFocusColor = focusColor ?? theme.colorScheme.primary;

          return Container(
            decoration: hasFocus
                ? BoxDecoration(
                    border: Border.all(
                      color: effectiveFocusColor,
                      width: focusBorderWidth,
                    ),
                    borderRadius: borderRadius ?? BorderRadius.circular(8),
                  )
                : null,
            child: child,
          );
        },
      ),
    );
  }

  /// Creates a focus indicator widget with custom styling
  static Widget customFocusIndicator({
    required Widget child,
    required bool hasFocus,
    Color? focusColor,
    double focusBorderWidth = 3.0,
    BorderRadius? borderRadius,
  }) {
    return Container(
      decoration: hasFocus
          ? BoxDecoration(
              border: Border.all(
                color: focusColor ?? Colors.blue,
                width: focusBorderWidth,
              ),
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            )
          : null,
      child: child,
    );
  }

  // ============================================================================
  // SEMANTIC ANNOUNCEMENTS
  // ============================================================================

  /// Announces a message to screen readers
  static void announce(
    BuildContext context,
    String message, {
    TextDirection textDirection = TextDirection.ltr,
    Assertiveness assertiveness = Assertiveness.polite,
  }) {
    SemanticsService.announce(
      message,
      textDirection,
      assertiveness: assertiveness,
    );
  }

  /// Announces a polite message (doesn't interrupt)
  static void announcePolite(BuildContext context, String message) {
    announce(context, message, assertiveness: Assertiveness.polite);
  }

  /// Announces an assertive message (interrupts current announcement)
  static void announceAssertive(BuildContext context, String message) {
    announce(context, message, assertiveness: Assertiveness.assertive);
  }

  // ============================================================================
  // COMMON PATTERNS
  // ============================================================================

  /// Card with semantic label (note card, task card, etc.)
  static Widget card({
    required String title,
    required Widget child,
    String? subtitle,
    String? metadata,
    bool isPinned = false,
    bool isCompleted = false,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final buffer = StringBuffer(title);

    if (subtitle != null && subtitle.isNotEmpty) {
      buffer.write('. $subtitle');
    }

    if (isPinned) {
      buffer.write('. Pinned');
    }

    if (isCompleted) {
      buffer.write('. Completed');
    }

    if (isSelected) {
      buffer.write('. Selected');
    }

    if (metadata != null && metadata.isNotEmpty) {
      buffer.write('. $metadata');
    }

    return Semantics(
      label: buffer.toString(),
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      child: child,
    );
  }

  /// Note card with semantic metadata
  static Widget noteCard({
    required String title,
    required Widget child,
    String? content,
    String? date,
    bool isPinned = false,
    bool hasAttachments = false,
    bool hasTasks = false,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final buffer = StringBuffer();
    buffer.write(title.isEmpty ? 'Untitled note' : title);

    if (content != null && content.isNotEmpty) {
      buffer.write(
        '. ${content.substring(0, content.length > 100 ? 100 : content.length)}',
      );
    }

    if (isPinned) {
      buffer.write('. Pinned');
    }

    if (hasAttachments) {
      buffer.write('. Has attachments');
    }

    if (hasTasks) {
      buffer.write('. Contains tasks');
    }

    if (date != null) {
      buffer.write('. Updated $date');
    }

    if (isSelected) {
      buffer.write('. Selected');
    }

    return Semantics(
      label: buffer.toString(),
      hint: 'Double tap to open, long press for options',
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      child: child,
    );
  }

  /// Task card with semantic metadata
  static Widget taskCard({
    required String title,
    required Widget child,
    String? description,
    bool isCompleted = false,
    String? dueDate,
    String? priority,
    List<String>? tags,
    bool isSelected = false,
    VoidCallback? onTap,
    ValueChanged<bool?>? onToggle,
  }) {
    final buffer = StringBuffer();

    if (isCompleted) {
      buffer.write('Completed task: ');
    } else {
      buffer.write('Task: ');
    }

    buffer.write(title);

    if (description != null && description.isNotEmpty) {
      buffer.write(
        '. ${description.substring(0, description.length > 100 ? 100 : description.length)}',
      );
    }

    if (priority != null) {
      buffer.write('. Priority: $priority');
    }

    if (dueDate != null) {
      buffer.write('. Due $dueDate');
    }

    if (tags != null && tags.isNotEmpty) {
      buffer.write('. Tags: ${tags.join(", ")}');
    }

    if (isSelected) {
      buffer.write('. Selected');
    }

    return Semantics(
      label: buffer.toString(),
      hint: isCompleted
          ? 'Double tap to reopen, long press for options'
          : 'Double tap to complete, long press for options',
      checked: isCompleted,
      onTap: onTap,
      selected: isSelected,
      child: child,
    );
  }

  /// Icon button with semantic label
  static Widget iconButton({
    required String label,
    required Widget child,
    String? hint,
    bool enabled = true,
    VoidCallback? onPressed,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: enabled && onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: child,
    );
  }

  /// Menu item with semantic label
  static Widget menuItem({
    required String label,
    required Widget child,
    String? hint,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final buffer = StringBuffer(label);
    if (icon != null) {
      // Add icon description if needed
    }

    return Semantics(
      label: buffer.toString(),
      hint: hint,
      button: true,
      onTap: onTap,
      child: child,
    );
  }

  /// Dialog with semantic label
  static Widget dialog({
    required String title,
    required Widget child,
    String? description,
  }) {
    final label = description != null ? '$title. $description' : title;
    return Semantics(
      label: label,
      scopesRoute: true,
      namesRoute: true,
      child: child,
    );
  }

  /// Bottom sheet with semantic label
  static Widget bottomSheet({required String title, required Widget child}) {
    return Semantics(label: title, scopesRoute: true, child: child);
  }

  // ============================================================================
  // VALIDATION & ERROR MESSAGES
  // ============================================================================

  /// Creates a semantically accessible form field
  static Widget formField({
    required String label,
    required Widget child,
    String? hint,
    String? errorText,
    bool required = false,
  }) {
    final buffer = StringBuffer(label);

    if (required) {
      buffer.write(', required');
    }

    return Semantics(
      label: buffer.toString(),
      hint: hint,
      value: errorText,
      textField: true,
      child: child,
    );
  }

  /// Error message announcement
  static Widget errorMessage({required String message, required Widget child}) {
    return Semantics(label: 'Error: $message', liveRegion: true, child: child);
  }

  /// Success message announcement
  static Widget successMessage({
    required String message,
    required Widget child,
  }) {
    return Semantics(
      label: 'Success: $message',
      liveRegion: true,
      child: child,
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Truncates text to a maximum length for semantic labels
  static String truncateForSemantics(String text, {int maxLength = 200}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Formats date for semantic announcement
  static String formatDateForSemantics(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return 'on ${date.month}/${date.day}/${date.year}';
    }
  }

  /// Creates a descriptive label for a list
  static String listLabel(int count, String itemType) {
    if (count == 0) {
      return 'No $itemType';
    } else if (count == 1) {
      return '1 $itemType';
    } else {
      return '$count ${itemType}s';
    }
  }

  /// Creates a label for a priority level
  static String priorityLabel(dynamic priority) {
    return 'Priority: ${priority.toString().split('.').last}';
  }

  /// Creates a label for a status
  static String statusLabel(dynamic status) {
    return 'Status: ${status.toString().split('.').last}';
  }
}

/// Focus indicator widget with Material Design styling
class DuruFocusIndicator extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final Color? focusColor;
  final double focusBorderWidth;
  final BorderRadius? borderRadius;

  const DuruFocusIndicator({
    super.key,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.focusColor,
    this.focusBorderWidth = 3.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return A11yHelper.focusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      focusColor: focusColor,
      focusBorderWidth: focusBorderWidth,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// Extensions for easier accessibility
extension A11yWidget on Widget {
  /// Wraps widget with semantic button
  Widget a11yButton(String label, {String? hint, bool enabled = true}) {
    return A11yHelper.button(
      label: label,
      hint: hint,
      enabled: enabled,
      child: this,
    );
  }

  /// Wraps widget with semantic header
  Widget a11yHeader(String label) {
    return A11yHelper.header(label: label, child: this);
  }

  /// Excludes widget from semantics (decorative)
  Widget a11yDecorative() {
    return A11yHelper.decorative(this);
  }

  /// Wraps widget with focus indicator
  Widget a11yFocusable({
    FocusNode? focusNode,
    bool autofocus = false,
    Color? focusColor,
  }) {
    return A11yHelper.focusable(
      focusNode: focusNode,
      autofocus: autofocus,
      focusColor: focusColor,
      child: this,
    );
  }
}
