import 'package:flutter/material.dart';

/// Reusable dialog action row component
///
/// This widget standardizes the action buttons used across all dialogs in the app,
/// providing consistent styling and behavior for cancel/confirm actions.
class DialogActionRow extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String? cancelText;
  final String? confirmText;
  final bool isConfirmDestructive;
  final bool isConfirmDisabled;
  final Widget? customCancelButton;
  final Widget? customConfirmButton;
  final MainAxisAlignment alignment;
  final double spacing;

  const DialogActionRow({
    super.key,
    this.onCancel,
    this.onConfirm,
    this.cancelText,
    this.confirmText,
    this.isConfirmDestructive = false,
    this.isConfirmDisabled = false,
    this.customCancelButton,
    this.customConfirmButton,
    this.alignment = MainAxisAlignment.end,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build cancel button
    Widget? cancelButton;
    if (customCancelButton != null) {
      cancelButton = customCancelButton;
    } else if (onCancel != null) {
      cancelButton = TextButton(
        onPressed: onCancel,
        child: Text(cancelText ?? 'Cancel'),
      );
    }

    // Build confirm button
    Widget? confirmButton;
    if (customConfirmButton != null) {
      confirmButton = customConfirmButton;
    } else if (onConfirm != null) {
      final buttonStyle = isConfirmDestructive
          ? FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            )
          : null;

      confirmButton = FilledButton(
        onPressed: isConfirmDisabled ? null : onConfirm,
        style: buttonStyle,
        child: Text(confirmText ?? 'Confirm'),
      );
    }

    // Build row with buttons
    final buttons = <Widget>[];
    if (cancelButton != null) buttons.add(cancelButton);
    if (cancelButton != null && confirmButton != null) {
      buttons.add(SizedBox(width: spacing));
    }
    if (confirmButton != null) buttons.add(confirmButton);

    return Row(mainAxisAlignment: alignment, children: buttons);
  }
}

/// Convenience constructors for common patterns
extension DialogActionRowExtensions on DialogActionRow {
  /// Create a standard OK/Cancel dialog action row
  static DialogActionRow okCancel({
    required VoidCallback onOk,
    required VoidCallback onCancel,
    String? okText,
    String? cancelText,
    bool isOkDisabled = false,
  }) {
    return DialogActionRow(
      onCancel: onCancel,
      onConfirm: onOk,
      cancelText: cancelText ?? 'Cancel',
      confirmText: okText ?? 'OK',
      isConfirmDisabled: isOkDisabled,
    );
  }

  /// Create a destructive action dialog row (e.g., for delete confirmations)
  static DialogActionRow destructive({
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    required String confirmText,
    String? cancelText,
    bool isConfirmDisabled = false,
  }) {
    return DialogActionRow(
      onCancel: onCancel,
      onConfirm: onConfirm,
      cancelText: cancelText ?? 'Cancel',
      confirmText: confirmText,
      isConfirmDestructive: true,
      isConfirmDisabled: isConfirmDisabled,
    );
  }

  /// Create a save/cancel dialog action row
  static DialogActionRow saveCancel({
    required VoidCallback onSave,
    required VoidCallback onCancel,
    bool isSaveDisabled = false,
    bool isNewItem = false,
  }) {
    return DialogActionRow(
      onCancel: onCancel,
      onConfirm: onSave,
      cancelText: 'Cancel',
      confirmText: isNewItem ? 'Create' : 'Save',
      isConfirmDisabled: isSaveDisabled,
    );
  }

  /// Create a single action dialog row (e.g., just "Close")
  static DialogActionRow single({
    required VoidCallback onAction,
    required String actionText,
    bool isDestructive = false,
  }) {
    return DialogActionRow(
      onConfirm: onAction,
      confirmText: actionText,
      isConfirmDestructive: isDestructive,
    );
  }
}
