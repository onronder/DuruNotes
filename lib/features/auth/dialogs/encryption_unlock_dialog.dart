import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/features/auth/providers/encryption_state_providers.dart';

/// Dialog for unlocking encryption on sign-in
class EncryptionUnlockDialog extends ConsumerStatefulWidget {
  const EncryptionUnlockDialog({
    super.key,
    this.allowSkip = true,
    this.onUnlockComplete,
    this.onSkip,
  });

  final bool allowSkip;
  final VoidCallback? onUnlockComplete;
  final VoidCallback? onSkip;

  @override
  ConsumerState<EncryptionUnlockDialog> createState() => _EncryptionUnlockDialogState();

  /// Show dialog and return true if unlock was successful
  static Future<bool?> show(
    BuildContext context, {
    bool allowSkip = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: allowSkip,
      builder: (context) => EncryptionUnlockDialog(
        allowSkip: allowSkip,
      ),
    );
  }
}

class _EncryptionUnlockDialogState extends ConsumerState<EncryptionUnlockDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _shake() {
    _shakeController.forward(from: 0.0);
  }

  Future<void> _unlockEncryption() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    final password = _passwordController.text;
    final success = await ref.read(encryptionStateProvider.notifier).unlockEncryption(password);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      widget.onUnlockComplete?.call();
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(encryptionStateProvider);
      setState(() {
        _isLoading = false;
        _attemptCount++;
        _errorMessage = state.error ?? 'Failed to unlock encryption';
      });

      _shake();
      HapticFeedback.heavyImpact();

      // Clear password field after failed attempt
      _passwordController.clear();

      // Lock user out after max attempts
      if (_attemptCount >= _maxAttempts) {
        if (mounted) {
          _showMaxAttemptsDialog();
        }
      }
    }
  }

  void _showMaxAttemptsDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Too Many Attempts'),
        content: const Text(
          'You have entered an incorrect password too many times. '
          'Please try again later or contact support if you\'ve forgotten your password.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _skip() {
    widget.onSkip?.call();
    Navigator.of(context).pop(false);
  }

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password?'),
        content: const Text(
          'Unfortunately, encryption passwords cannot be recovered. '
          'If you\'ve lost your password, you\'ll need to reset your encryption, '
          'which will delete all encrypted data.\n\n'
          'Contact support for assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement reset encryption flow
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: DuruColors.error,
            ),
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final attemptsRemaining = _maxAttempts - _attemptCount;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = 10 * (_shakeController.value * 4 * (1 - _shakeController.value));
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1A1A),
                      DuruColors.primary.withValues(alpha: 0.1),
                    ]
                  : [
                      Colors.white,
                      DuruColors.primary.withValues(alpha: 0.02),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(DuruSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(theme),
                  SizedBox(height: DuruSpacing.lg),

                  // Description
                  _buildDescription(theme),
                  SizedBox(height: DuruSpacing.lg),

                  // Password Field
                  _buildPasswordField(theme),

                  // Attempts Warning
                  if (_attemptCount > 0) ...[
                    SizedBox(height: DuruSpacing.sm),
                    _buildAttemptsWarning(theme, attemptsRemaining),
                  ],

                  // Error Message
                  if (_errorMessage != null) ...[
                    SizedBox(height: DuruSpacing.md),
                    _buildErrorMessage(theme),
                  ],

                  SizedBox(height: DuruSpacing.lg),

                  // Action Buttons
                  _buildActionButtons(theme),

                  // Forgot Password Link
                  SizedBox(height: DuruSpacing.md),
                  _buildForgotPasswordLink(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DuruColors.primary, DuruColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: DuruColors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.lock_shield_fill,
            size: 40,
            color: Colors.white,
          ),
        ),
        SizedBox(height: DuruSpacing.md),
        Text(
          'Unlock Your Notes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDescription(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(DuruSpacing.md),
      decoration: BoxDecoration(
        color: DuruColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DuruColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.info_circle_fill,
            size: 20,
            color: DuruColors.primary,
          ),
          SizedBox(width: DuruSpacing.sm),
          Expanded(
            child: Text(
              'Enter your encryption password to access your notes on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      enabled: !_isLoading && _attemptCount < _maxAttempts,
      autofocus: true,
      onFieldSubmitted: (_) => _unlockEncryption(),
      decoration: InputDecoration(
        labelText: 'Encryption Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(CupertinoIcons.lock, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: DuruColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: DuruColors.error,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
        return null;
      },
    );
  }

  Widget _buildAttemptsWarning(ThemeData theme, int remaining) {
    final isLowAttempts = remaining <= 2;

    return Container(
      padding: EdgeInsets.all(DuruSpacing.sm),
      decoration: BoxDecoration(
        color: isLowAttempts
            ? DuruColors.error.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLowAttempts
              ? DuruColors.error.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 16,
            color: isLowAttempts ? DuruColors.error : Colors.orange[700],
          ),
          SizedBox(width: DuruSpacing.sm),
          Expanded(
            child: Text(
              'Incorrect password. $remaining ${remaining == 1 ? 'attempt' : 'attempts'} remaining.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isLowAttempts ? DuruColors.error : Colors.orange[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(DuruSpacing.md),
      decoration: BoxDecoration(
        color: DuruColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DuruColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 20,
            color: DuruColors.error,
          ),
          SizedBox(width: DuruSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: DuruColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Unlock Button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: (_isLoading || _attemptCount >= _maxAttempts) ? null : _unlockEncryption,
            style: ElevatedButton.styleFrom(
              backgroundColor: DuruColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: _isLoading ? 0 : 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Unlock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        // Skip Button (if allowed)
        if (widget.allowSkip) ...[
          SizedBox(height: DuruSpacing.sm),
          OutlinedButton(
            onPressed: _isLoading ? null : _skip,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Continue Without Encryption',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForgotPasswordLink(ThemeData theme) {
    return TextButton(
      onPressed: _isLoading ? null : _forgotPassword,
      child: Text(
        'Forgot Password?',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
