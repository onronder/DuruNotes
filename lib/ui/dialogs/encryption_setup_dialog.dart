import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/services/encryption_sync_service.dart'; // EncryptionException
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zxcvbn/zxcvbn.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Dialog for setting up encryption password for cross-device sync
///
/// This dialog is shown:
/// - On first sign-up (optional)
/// - When user wants to enable cross-device encryption
/// - When signing in on a new device (to retrieve encryption)
class EncryptionSetupDialog extends ConsumerStatefulWidget {
  const EncryptionSetupDialog({
    super.key,
    this.mode = EncryptionSetupMode.setup,
    this.onSuccess,
    this.allowCancel = true,
  });

  final EncryptionSetupMode mode;
  final VoidCallback? onSuccess;
  final bool allowCancel;

  @override
  ConsumerState<EncryptionSetupDialog> createState() =>
      _EncryptionSetupDialogState();
}

enum EncryptionSetupMode {
  setup, // First-time setup (create new encryption)
  retrieve, // Sign in on new device (retrieve existing encryption)
}

class _EncryptionSetupDialogState extends ConsumerState<EncryptionSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  AppLogger get _logger => ref.read(loggerProvider);

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _canSubmit = false;

  // Password strength (0-4: weak to very strong)
  int _passwordStrength = 0;
  String _passwordStrengthText = '';
  final _zxcvbn = Zxcvbn();

  @override
  void initState() {
    super.initState();

    // Listen to password changes for real-time strength calculation
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_updateFormValidity);

    // Auto-focus password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
      _updateFormValidity();
    });
  }

  /// Calculate password strength using zxcvbn
  void _updatePasswordStrength() {
    if (widget.mode != EncryptionSetupMode.setup) return;

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = '';
      });
      return;
    }

    try {
      // Limit evaluation input size to avoid pathological OOM scenarios
      final sample = password.length > 256
          ? password.substring(0, 256)
          : password;
      final result = _zxcvbn.evaluate(sample);
      final rawScore = result.score ?? 0;
      final score = rawScore < 0
          ? 0
          : rawScore > 4
          ? 4
          : rawScore.round();

      const strengthLabels = [
        'Very Weak',
        'Weak',
        'Fair',
        'Strong',
        'Very Strong',
      ];

      if (!mounted) return;
      setState(() {
        _passwordStrength = score;
        _passwordStrengthText = strengthLabels[score];
      });
    } on OutOfMemoryError catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          '[EncryptionSetupDialog] OOM during password strength evaluation: $e\n$stack',
        );
      }
      if (!mounted) return;
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = 'Weak';
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          '[EncryptionSetupDialog] Error calculating password strength: $e\n$stack',
        );
      }
      if (!mounted) return;
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = '';
      });
    }
  }

  void _onPasswordChanged() {
    _updatePasswordStrength();
    _updateFormValidity();
  }

  void _updateFormValidity() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    var canSubmit = password.isNotEmpty;

    if (widget.mode == EncryptionSetupMode.setup) {
      final hasUppercase = password.contains(RegExp(r'[A-Z]'));
      final hasLowercase = password.contains(RegExp(r'[a-z]'));
      final hasSpecialChars = password.contains(
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
      );
      canSubmit =
          canSubmit &&
          password.length >= 6 &&
          hasUppercase &&
          hasLowercase &&
          hasSpecialChars &&
          confirm.isNotEmpty &&
          confirm == password &&
          _passwordStrength >= 2;
    }

    if (widget.mode == EncryptionSetupMode.retrieve) {
      canSubmit = password.isNotEmpty;
    }

    if (!mounted) return;

    if (canSubmit != _canSubmit) {
      setState(() => _canSubmit = canSubmit);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_updateFormValidity);

    // SECURITY: Clear password from memory before disposing
    _clearPasswordFromMemory(_passwordController);
    _clearPasswordFromMemory(_confirmPasswordController);

    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  /// Securely clear password from memory
  ///
  /// SECURITY: Overwrite the password text with zeros before releasing memory
  /// This prevents passwords from lingering in memory after disposal
  void _clearPasswordFromMemory(TextEditingController controller) {
    if (controller.text.isNotEmpty) {
      // Overwrite with zeros multiple times to ensure data is cleared
      final length = controller.text.length;
      controller.text = '\u0000' * length;
      controller.clear();
    }
  }

  Future<void> _handleSubmit() async {
    if (_isLoading || !_canSubmit) return;

    if (!_formKey.currentState!.validate()) {
      _updateFormValidity();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final encryptionService = ref.read(encryptionSyncServiceProvider);
      final password = _passwordController.text.trim();

      if (widget.mode == EncryptionSetupMode.setup) {
        await encryptionService.setupEncryption(password);
      } else {
        await encryptionService.retrieveEncryption(password);
      }

      // SECURITY: Clear passwords from memory after successful use
      _clearPasswordFromMemory(_passwordController);
      _clearPasswordFromMemory(_confirmPasswordController);

      if (mounted) {
        Navigator.of(context).pop(true);
        widget.onSuccess?.call();
      }
    } on EncryptionException catch (error, stackTrace) {
      // SECURITY: Use user-friendly error messages from EncryptionException
      // Don't clear passwords on error - user might need to retry
      _logger.warning(
        'Encryption setup failed with encryption exception',
        data: {'mode': widget.mode.name, 'errorCode': error.code},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      // Unexpected error - show generic message
      _logger.error(
        'Unexpected error during encryption setup',
        error: error,
        stackTrace: stackTrace,
        data: {'mode': widget.mode.name},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final isSetup = widget.mode == EncryptionSetupMode.setup;
    final title = isSetup ? 'Setup Encryption' : 'Enter Encryption Password';
    final description = isSetup
        ? 'Create a password to encrypt your notes for cross-device sync. This password is used only for encryption and is never sent to our servers.'
        : 'Enter the password you used when setting up encryption on your first device.';

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.lock_outline,
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Password field
              TextFormField(
                key: const Key('encryption_password_field'),
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Encryption Password',
                  hintText: 'Enter a strong password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Password is required';
                  }

                  // Production-grade password requirements
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }

                  // For setup mode, enforce complexity and strength
                  if (widget.mode == EncryptionSetupMode.setup) {
                    // Check complexity requirements
                    final hasUppercase = value.contains(RegExp(r'[A-Z]'));
                    final hasLowercase = value.contains(RegExp(r'[a-z]'));
                    final hasSpecialChars = value.contains(
                      RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
                    );

                    if (!hasUppercase || !hasLowercase || !hasSpecialChars) {
                      return 'Include uppercase, lowercase, and a special character';
                    }

                    // Enforce minimum strength (score 2 = "Fair" is minimum acceptable)
                    if (_passwordStrength < 2) {
                      return 'Password is too weak. Please use a stronger password.';
                    }
                  }

                  return null;
                },
                onFieldSubmitted: (_) {
                  if (isSetup) {
                    _confirmPasswordFocusNode.requestFocus();
                  } else {
                    _handleSubmit();
                  }
                },
              ),

              // Password strength indicator (only for setup)
              if (isSetup && _passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildPasswordStrengthIndicator(colorScheme),
              ],

              // Confirm password field (only for setup)
              if (isSetup) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('encryption_confirm_password_field'),
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleSubmit(),
                ),
              ],

              // Info box
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSetup
                            ? 'Important: Store this password securely. If you lose it, you will not be able to decrypt your notes on other devices.'
                            : 'This is the same password you used when you first set up encryption.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.allowCancel)
          TextButton(
            onPressed: _isLoading
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
        FilledButton(
          onPressed: _isLoading || !_canSubmit ? null : _handleSubmit,
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Text(isSetup ? 'Setup' : 'Unlock'),
        ),
      ],
    );
  }

  /// Build password strength indicator widget
  Widget _buildPasswordStrengthIndicator(ColorScheme colorScheme) {
    // Color based on strength score (0-4)
    final colors = [
      Colors.red, // 0: Very Weak
      Colors.orange, // 1: Weak
      Colors.yellow, // 2: Fair
      Colors.lightGreen, // 3: Strong
      Colors.green, // 4: Very Strong
    ];

    final strengthColor = colors[_passwordStrength];
    final progress = (_passwordStrength + 1) / 5; // 0.2, 0.4, 0.6, 0.8, 1.0

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _passwordStrengthText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: strengthColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Show encryption setup dialog
Future<bool?> showEncryptionSetupDialog(
  BuildContext context, {
  EncryptionSetupMode mode = EncryptionSetupMode.setup,
  VoidCallback? onSuccess,
  bool allowCancel = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => EncryptionSetupDialog(
      mode: mode,
      onSuccess: onSuccess,
      allowCancel: allowCancel,
    ),
  );
}
