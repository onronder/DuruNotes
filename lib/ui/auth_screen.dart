import 'dart:async';

import 'package:duru_notes/features/encryption/encryption_feature_flag.dart';
import 'package:duru_notes/features/encryption/pending_onboarding_provider.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/core/errors.dart';
import 'package:duru_notes/core/providers/security_providers.dart'
    show accountKeyServiceProvider;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/providers/services_providers.dart'
    show pushNotificationServiceProvider;
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modern authentication screen with gradient design
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  AppLogger get _logger => ref.read(loggerProvider);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _passphraseConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _passphraseController.dispose();
    _passphraseConfirmController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      if (_isSignUp) {
        final signUpRes = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        _logger.info(
          'User sign-up completed',
          data: {
            'flow': 'signUp',
            'emailDomain': _extractEmailDomain(email),
          },
        );

        // Get the user ID from the signup response or current auth state
        final uid =
            signUpRes.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          // Provision AMK with passphrase, passing the user ID explicitly
          final passphrase = _passphraseController.text;
          final svc = ref.read(accountKeyServiceProvider);
          await svc.provisionAmkForUser(passphrase: passphrase, userId: uid);

          // OPTIONAL: Cross-device encryption onboarding
          // SAFETY: Completely non-blocking, user can skip, feature flag controlled
          // If disabled (default), this is a no-op
          if (kDebugMode) {
            debugPrint('[Auth] 📝 Sign-up successful, checking cross-device encryption...');
            debugPrint('[Auth] Feature flag enabled: ${EncryptionFeatureFlags.enableCrossDeviceEncryption}');
          }

          try {
            if (EncryptionFeatureFlags.enableCrossDeviceEncryption && EncryptionFeatureFlags.showOnSignUp) {
              if (kDebugMode) {
                debugPrint('[Auth] ✅ Cross-device encryption enabled, flagging for onboarding');
              }

              // Set flag for AuthWrapper to show onboarding
              // This prevents unmounting issues
              ref.read(pendingOnboardingProvider.notifier).setPending();
            } else {
              if (kDebugMode) {
                debugPrint('[Auth] ⏭️ Cross-device encryption disabled by feature flag, skipping onboarding');
              }
            }
          } catch (e, stack) {
            _logger.error(
              'Cross-device encryption onboarding failed',
              error: e,
              stackTrace: stack,
              data: {
                'flow': 'signUp',
                'featureEnabled': EncryptionFeatureFlags.enableCrossDeviceEncryption,
              },
            );
            unawaited(Sentry.captureException(e, stackTrace: stack));
            if (kDebugMode) {
              debugPrint(
                '[Auth] ❌ Cross-device encryption onboarding failed (non-critical): $e',
              );
              debugPrint('[Auth] Stack trace: $stack');
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Check your email to confirm your account!'),
              backgroundColor: DuruColors.accent,
            ),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        _logger.info(
          'User sign-in completed',
          data: {
            'flow': 'signIn',
            'emailDomain': _extractEmailDomain(email),
          },
        );

        // Register push token after successful login
        _registerPushTokenInBackground();
      }
    } catch (error, stack) {
      final appError = ErrorFactory.fromException(error, stack);
      final logData = <String, dynamic>{
        'flow': _isSignUp ? 'signUp' : 'signIn',
        'emailDomain': _extractEmailDomain(email),
        'recoverable': appError.isRecoverable,
      };
      if (appError.code != null) {
        logData['code'] = appError.code;
      }

      _logger.error(
        'Authentication flow failed',
        error: error,
        stackTrace: stack,
        data: logData,
      );
      unawaited(Sentry.captureException(error, stackTrace: stack));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.userMessage),
            backgroundColor: DuruColors.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                unawaited(_authenticate());
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerPushTokenInBackground() async {
    try {
      final pushService = ref.read(pushNotificationServiceProvider);
      await pushService.registerWithBackend();
      _logger.debug(
        'Push token registration executed',
        data: {'flow': _isSignUp ? 'signUp' : 'signIn'},
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to register push token',
        error: e,
        stackTrace: stack,
      );
    }
  }

  String? _extractEmailDomain(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0 || atIndex == email.length - 1) {
      return null;
    }
    return email.substring(atIndex + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A1A),
                    DuruColors.primary.withValues(alpha: 0.2),
                    DuruColors.accent.withValues(alpha: 0.1),
                  ]
                : [
                    DuruColors.primary.withValues(alpha: 0.05),
                    Colors.white,
                    DuruColors.accent.withValues(alpha: 0.05),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(DuruSpacing.lg),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: DuruSpacing.xl),

                      // Logo and Branding
                      _buildLogo(context),
                      SizedBox(height: DuruSpacing.xl * 2),

                      // Auth Card
                      _buildAuthCard(context),
                      SizedBox(height: DuruSpacing.lg),

                      // Social Login Options
                      _buildSocialLogin(context),
                      SizedBox(height: DuruSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Animated Logo
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DuruColors.primary, DuruColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: DuruColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.doc_text_viewfinder,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: DuruSpacing.lg),

        // App Name
        Text(
          'Duru Notes',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            background: Paint()
              ..shader = LinearGradient(
                colors: [DuruColors.primary, DuruColors.accent],
              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
            color: Colors.transparent,
          ),
        ),
        SizedBox(height: DuruSpacing.xs),

        // Tagline
        Text(
          _isSignUp
            ? 'Create your secure workspace'
            : 'Welcome back to your notes',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(DuruSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab Switcher
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      context,
                      title: 'Sign In',
                      isActive: !_isSignUp,
                      onTap: () {
                        setState(() => _isSignUp = false);
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      context,
                      title: 'Sign Up',
                      isActive: _isSignUp,
                      onTap: () {
                        setState(() => _isSignUp = true);
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: DuruSpacing.lg),

            // Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: CupertinoIcons.mail,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            SizedBox(height: DuruSpacing.md),

            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: CupertinoIcons.lock,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (_isSignUp && value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            // Confirm Password (Sign Up only)
            if (_isSignUp) ...[
              SizedBox(height: DuruSpacing.md),
              _buildTextField(
                controller: _passwordConfirmController,
                label: 'Confirm Password',
                icon: CupertinoIcons.lock_shield,
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              // Passphrase for encryption
              SizedBox(height: DuruSpacing.lg),
              Container(
                padding: EdgeInsets.all(DuruSpacing.md),
                decoration: BoxDecoration(
                  color: DuruColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DuruColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.shield_fill,
                          size: 20,
                          color: DuruColors.primary,
                        ),
                        SizedBox(width: DuruSpacing.sm),
                        Text(
                          'Encryption Passphrase',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DuruSpacing.xs),
                    Text(
                      'This passphrase encrypts your notes. Keep it safe!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: DuruSpacing.md),
                    _buildTextField(
                      controller: _passphraseController,
                      label: 'Passphrase',
                      icon: CupertinoIcons.lock,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Passphrase is required for encryption';
                        }
                        if (value.length < 8) {
                          return 'Passphrase must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: DuruSpacing.sm),
                    _buildTextField(
                      controller: _passphraseConfirmController,
                      label: 'Confirm Passphrase',
                      icon: CupertinoIcons.lock_fill,
                      obscureText: true,
                      validator: (value) {
                        if (value != _passphraseController.text) {
                          return 'Passphrases do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Forgot Password Link
            if (!_isSignUp) ...[
              SizedBox(height: DuruSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Navigate to password reset
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: DuruColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],

            SizedBox(height: DuruSpacing.lg),

            // Submit Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DuruColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: _isLoading ? 0 : 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSignUp ? 'Create Account' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: DuruSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
            ? theme.colorScheme.surface
            : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        ),
        child: Center(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isActive
                ? DuruColors.primary
                : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: !_isLoading,
      validator: validator,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
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
    );
  }

  Widget _buildSocialLogin(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DuruSpacing.md),
              child: Text(
                'Or continue with',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
        SizedBox(height: DuruSpacing.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              context,
              icon: Icons.g_mobiledata,
              label: 'Google',
              onTap: () {
                // Google sign in
              },
            ),
            _buildSocialButton(
              context,
              icon: Icons.apple,
              label: 'Apple',
              onTap: () {
                // Apple sign in
              },
            ),
            _buildSocialButton(
              context,
              icon: Icons.mail_outline,
              label: 'Magic Link',
              onTap: () {
                // Magic link sign in
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: DuruSpacing.lg,
          vertical: DuruSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24),
            SizedBox(height: DuruSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
