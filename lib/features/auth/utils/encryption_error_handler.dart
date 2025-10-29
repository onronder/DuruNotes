import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';

/// Error types for encryption operations
enum EncryptionErrorType {
  invalidPassword,
  networkError,
  alreadySetup,
  notSetup,
  authRequired,
  migrationFailure,
  storageError,
  unknown,
}

/// Encryption error with type and user-friendly message
class EncryptionError {
  const EncryptionError({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.recoveryAction,
  });

  final EncryptionErrorType type;
  final String message;
  final String? technicalDetails;
  final String? recoveryAction;

  /// Parse exception into structured error
  factory EncryptionError.fromException(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('invalid password') ||
        errorStr.contains('decryption failed')) {
      return const EncryptionError(
        type: EncryptionErrorType.invalidPassword,
        message: 'Invalid password. Please try again.',
        recoveryAction: 'Double-check your password and try again. If you forgot your password, contact support.',
      );
    }

    if (errorStr.contains('already setup')) {
      return const EncryptionError(
        type: EncryptionErrorType.alreadySetup,
        message: 'Encryption is already set up for this account.',
        recoveryAction: 'If you need to change your password, go to Settings > Security > Change Encryption Password.',
      );
    }

    if (errorStr.contains('no encryption setup found') ||
        errorStr.contains('not found')) {
      return const EncryptionError(
        type: EncryptionErrorType.notSetup,
        message: 'No encryption found. Please set up encryption first.',
        recoveryAction: 'Go to Settings > Security > Set Up Encryption to enable encryption.',
      );
    }

    if (errorStr.contains('not authenticated') ||
        errorStr.contains('authentication')) {
      return const EncryptionError(
        type: EncryptionErrorType.authRequired,
        message: 'You must be signed in to access encryption.',
        recoveryAction: 'Please sign in to your account and try again.',
      );
    }

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout')) {
      return const EncryptionError(
        type: EncryptionErrorType.networkError,
        message: 'Network error. Please check your connection.',
        recoveryAction: 'Check your internet connection and try again.',
      );
    }

    if (errorStr.contains('migration') ||
        errorStr.contains('rewrap')) {
      return EncryptionError(
        type: EncryptionErrorType.migrationFailure,
        message: 'Failed to migrate encrypted data.',
        technicalDetails: error.toString(),
        recoveryAction: 'Contact support for help migrating your encrypted data.',
      );
    }

    if (errorStr.contains('storage') ||
        errorStr.contains('keychain') ||
        errorStr.contains('secure storage')) {
      return EncryptionError(
        type: EncryptionErrorType.storageError,
        message: 'Failed to store encryption keys securely.',
        technicalDetails: error.toString(),
        recoveryAction: 'Check your device storage permissions and try again.',
      );
    }

    // Generic error
    return EncryptionError(
      type: EncryptionErrorType.unknown,
      message: 'An unexpected error occurred.',
      technicalDetails: error.toString(),
      recoveryAction: 'Please try again. If the problem persists, contact support.',
    );
  }

  /// Get icon for error type
  IconData get icon {
    switch (type) {
      case EncryptionErrorType.invalidPassword:
        return CupertinoIcons.lock_slash;
      case EncryptionErrorType.networkError:
        return CupertinoIcons.wifi_slash;
      case EncryptionErrorType.alreadySetup:
        return CupertinoIcons.checkmark_shield;
      case EncryptionErrorType.notSetup:
        return CupertinoIcons.shield_slash;
      case EncryptionErrorType.authRequired:
        return CupertinoIcons.person_crop_circle_badge_xmark;
      case EncryptionErrorType.migrationFailure:
        return CupertinoIcons.arrow_2_circlepath_circle;
      case EncryptionErrorType.storageError:
        return CupertinoIcons.exclamationmark_triangle;
      case EncryptionErrorType.unknown:
        return CupertinoIcons.exclamationmark_circle;
    }
  }

  /// Get color for error type
  Color get color {
    switch (type) {
      case EncryptionErrorType.invalidPassword:
        return DuruColors.error;
      case EncryptionErrorType.networkError:
        return Colors.orange;
      case EncryptionErrorType.alreadySetup:
        return DuruColors.accent;
      case EncryptionErrorType.notSetup:
        return Colors.amber;
      case EncryptionErrorType.authRequired:
        return DuruColors.primary;
      case EncryptionErrorType.migrationFailure:
      case EncryptionErrorType.storageError:
      case EncryptionErrorType.unknown:
        return DuruColors.error;
    }
  }
}

/// Utility class for handling encryption errors
class EncryptionErrorHandler {
  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    EncryptionError error, {
    VoidCallback? onRetry,
    VoidCallback? onContactSupport,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _EncryptionErrorDialog(
        error: error,
        onRetry: onRetry,
        onContactSupport: onContactSupport,
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackbar(
    BuildContext context,
    EncryptionError error,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error.icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(error.message)),
          ],
        ),
        backgroundColor: error.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: error.recoveryAction != null
            ? SnackBarAction(
                label: 'Help',
                textColor: Colors.white,
                onPressed: () {
                  showErrorDialog(context, error);
                },
              )
            : null,
      ),
    );
  }

  /// Handle error with appropriate UI feedback
  static void handleError(
    BuildContext context,
    Object error, {
    bool showDialog = false,
    VoidCallback? onRetry,
  }) {
    final encryptionError = EncryptionError.fromException(error);

    if (showDialog) {
      showErrorDialog(context, encryptionError, onRetry: onRetry);
    } else {
      showErrorSnackbar(context, encryptionError);
    }
  }
}

/// Error dialog widget
class _EncryptionErrorDialog extends StatelessWidget {
  const _EncryptionErrorDialog({
    required this.error,
    this.onRetry,
    this.onContactSupport,
  });

  final EncryptionError error;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: EdgeInsets.all(DuruSpacing.lg),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: error.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              error.icon,
              size: 32,
              color: error.color,
            ),
          ),
          SizedBox(height: DuruSpacing.md),

          // Error Message
          Text(
            error.message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          // Recovery Action
          if (error.recoveryAction != null) ...[
            SizedBox(height: DuruSpacing.md),
            Container(
              padding: EdgeInsets.all(DuruSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.lightbulb,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: DuruSpacing.sm),
                  Expanded(
                    child: Text(
                      error.recoveryAction!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Technical Details (expandable)
          if (error.technicalDetails != null) ...[
            SizedBox(height: DuruSpacing.md),
            ExpansionTile(
              title: Text(
                'Technical Details',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(DuruSpacing.sm),
                  child: SelectableText(
                    error.technicalDetails!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: DuruSpacing.lg),

          // Action Buttons
          Row(
            children: [
              if (onRetry != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRetry!();
                    },
                    child: const Text('Retry'),
                  ),
                ),
              if (onRetry != null && onContactSupport != null)
                SizedBox(width: DuruSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onContactSupport != null) {
                      onContactSupport!();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuruColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(onContactSupport != null ? 'Contact Support' : 'OK'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
