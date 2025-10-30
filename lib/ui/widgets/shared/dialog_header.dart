import 'package:flutter/material.dart';

/// Reusable dialog header component
///
/// This widget standardizes the header section used across all dialogs in the app,
/// providing consistent styling for titles, icons, and close buttons.
class DialogHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onClose;
  final Widget? trailing;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry? padding;
  final bool showDivider;

  const DialogHeader({
    super.key,
    required this.title,
    this.icon,
    this.onClose,
    this.trailing,
    this.iconColor,
    this.titleStyle,
    this.padding,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveTitleStyle =
        titleStyle ??
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600);

    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final effectivePadding =
        padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 16);

    Widget header = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: effectiveIconColor, size: 28),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: effectiveTitleStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        if (onClose != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 24,
          ),
        ],
      ],
    );

    if (padding != null || padding == EdgeInsets.zero) {
      header = Padding(padding: effectivePadding, child: header);
    }

    if (showDivider) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [header, const Divider(height: 1)],
      );
    }

    return header;
  }
}

/// Convenience constructors for common patterns
extension DialogHeaderExtensions on DialogHeader {
  /// Create a simple header with just a title
  static DialogHeader simple(String title) {
    return DialogHeader(title: title);
  }

  /// Create a header with an icon
  static DialogHeader withIcon({
    required String title,
    required IconData icon,
    Color? iconColor,
  }) {
    return DialogHeader(title: title, icon: icon, iconColor: iconColor);
  }

  /// Create a closeable header
  static DialogHeader closeable({
    required String title,
    required VoidCallback onClose,
    IconData? icon,
  }) {
    return DialogHeader(title: title, icon: icon, onClose: onClose);
  }

  /// Create a header for forms (with close button and divider)
  static DialogHeader form({
    required String title,
    required VoidCallback onClose,
    IconData? icon,
  }) {
    return DialogHeader(
      title: title,
      icon: icon,
      onClose: onClose,
      showDivider: true,
    );
  }

  /// Create a header for destructive actions
  static DialogHeader destructive({
    required String title,
    VoidCallback? onClose,
  }) {
    return DialogHeader(
      title: title,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
      onClose: onClose,
    );
  }

  /// Create a header for info dialogs
  static DialogHeader info({required String title, VoidCallback? onClose}) {
    return DialogHeader(
      title: title,
      icon: Icons.info_outline,
      onClose: onClose,
    );
  }
}
