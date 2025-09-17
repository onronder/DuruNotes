import 'package:duru_notes/core/security/password_history_service.dart';
import 'package:duru_notes/core/security/password_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../ui/widgets/password_strength_meter.dart'; // Widget not available

/// Secure password change screen with comprehensive validation
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _passwordValidator = PasswordValidator();
  final _passwordHistoryService = PasswordHistoryService();

  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;
  String? _successMessage;
  PasswordValidationResult? _passwordValidation;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onNewPasswordChanged() {
    setState(() {
      _passwordValidation = _passwordValidator.validatePassword(
        _newPasswordController.text,
      );
    });
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'No user logged in';
      });
      return;
    }

    // Validate new password
    final validation = _passwordValidator.validatePassword(
      _newPasswordController.text,
    );
    if (!validation.isValid) {
      setState(() {
        _errorMessage = 'New password does not meet security requirements';
      });
      return;
    }

    // Check password reuse
    final isReused = await _passwordHistoryService.isPasswordReused(
      currentUser.id,
      _newPasswordController.text,
    );
    if (isReused) {
      setState(() {
        _errorMessage =
            'You cannot reuse a previous password. Please choose a different password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      // Update password with Supabase
      await client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Store new password in history
      await _passwordHistoryService.storePasswordHash(
        currentUser.id,
        _newPasswordController.text,
      );

      setState(() {
        _successMessage = 'Password changed successfully!';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _passwordValidation = null;
      });

      // Navigate back after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      // Log error for debugging but don't expose details to user
      if (kDebugMode) {
        debugPrint('Password change error: $e');
      }
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Security notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Security',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your new password must meet all security requirements and cannot be one of your last 5 passwords.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Current Password Field
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: !_showCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _showCurrentPassword = !_showCurrentPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New Password Field
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _showNewPassword = !_showNewPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password is required';
                    }

                    final validation = _passwordValidator.validatePassword(
                      value,
                    );
                    if (!validation.isValid) {
                      return 'Password must meet security requirements';
                    }

                    if (value == _currentPasswordController.text) {
                      return 'New password must be different from current password';
                    }

                    return null;
                  },
                ),

                // Password Strength Meter
                if (_passwordValidation != null) ...[
                  const SizedBox(height: 16),
                  // TODO: Implement PasswordStrengthMeter widget
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _passwordValidation!.isValid
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _passwordValidation!.isValid
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Text(
                      _passwordValidation!.isValid
                          ? 'Password meets requirements'
                          : 'Password does not meet requirements',
                      style: TextStyle(
                        color: _passwordValidation!.isValid
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }

                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Success Message
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Change Password Button
                FilledButton(
                  onPressed: _isLoading ? null : _changePassword,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change Password'),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
