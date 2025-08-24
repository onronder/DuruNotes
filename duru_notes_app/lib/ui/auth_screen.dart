import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes_app/core/crypto/key_manager.dart';
import 'package:duru_notes_app/core/security/password_validator.dart';
import 'package:duru_notes_app/core/security/password_history_service.dart';
import 'package:duru_notes_app/core/auth/auth_service.dart';
import 'package:duru_notes_app/ui/widgets/password_strength_meter.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordValidator = PasswordValidator();
  final _passwordHistoryService = PasswordHistoryService();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _showPassword = false;
  String? _errorMessage;
  PasswordValidationResult? _passwordValidation;
  int? _attemptsRemaining;
  Duration? _lockoutDuration;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (_isSignUp) {
      setState(() {
        _passwordValidation = _passwordValidator.validatePassword(_passwordController.text);
      });
    }
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional password validation for sign up
    if (_isSignUp) {
      final validation = _passwordValidator.validatePassword(_passwordController.text);
      if (!validation.isValid) {
        setState(() {
          _errorMessage = 'Password does not meet security requirements. Please improve your password strength.';
        });
        return;
      }
      
      // Check password reuse for existing users (password reset scenario)
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final isReused = await _passwordHistoryService.isPasswordReused(
          currentUser.id, 
          _passwordController.text,
        );
        if (isReused) {
          setState(() {
            _errorMessage = 'You cannot reuse a previous password. Please choose a different password.';
          });
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AuthResult result;
      
      if (_isSignUp) {
        // Sign up with basic retry
        result = await _authService.signUpWithRetry(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (result.success && result.user != null) {
          // Store password hash in history for future reference
          await _passwordHistoryService.storePasswordHash(
            result.user!.id, 
            _passwordController.text,
          );
          
          // Initialize encryption key for new user
          final keyManager = KeyManager();
          await keyManager.getOrCreateMasterKey(result.user!.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // Sign in with enhanced retry and rate limiting
        result = await _authService.signInWithRetry(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          enableRetry: true,
        );
        
        if (result.success && result.user != null) {
          // Initialize encryption key for existing user
          final keyManager = KeyManager();
          await keyManager.getOrCreateMasterKey(result.user!.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signed in successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
      
      // Handle authentication result
      if (!result.success) {
        setState(() {
          _errorMessage = result.error;
          _attemptsRemaining = result.attemptsRemaining;
          _lockoutDuration = result.lockoutDuration;
        });
      }
      
    } catch (e) {
      // Log error for debugging but don't expose details to user
      if (kDebugMode) {
        print('Auth error: $e');
      }
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _attemptsRemaining = null;
        _lockoutDuration = null;
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Title
                Text(
                  'Duru Notes',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure, encrypted note-taking',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    
                    // Enhanced validation for sign up
                    if (_isSignUp) {
                      final validation = _passwordValidator.validatePassword(value);
                      if (!validation.isValid) {
                        return 'Password must meet security requirements';
                      }
                    } else {
                      // Basic validation for sign in
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                    }
                    return null;
                  },
                ),
                
                // Password Strength Meter (only for sign up)
                if (_isSignUp && _passwordValidation != null) ...[
                  const SizedBox(height: 16),
                  PasswordStrengthMeter(
                    validationResult: _passwordValidation!,
                    showCriteria: true,
                    showScore: false,
                  ),
                ],
                const SizedBox(height: 24),

                // Error Message with Rate Limiting Info
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lockoutDuration != null 
                                  ? Icons.lock_outline 
                                  : Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Additional security info
                        if (_attemptsRemaining != null && _attemptsRemaining! > 0 && !_isSignUp) ...[
                          const SizedBox(height: 8),
                          Text(
                            '⚠️ $_attemptsRemaining login attempts remaining',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        
                        if (_lockoutDuration != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Account temporarily locked for security',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                ),
                const SizedBox(height: 16),

                // Toggle Mode
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                            // Trigger password validation if switching to sign up
                            if (_isSignUp && _passwordController.text.isNotEmpty) {
                              _passwordValidation = _passwordValidator.validatePassword(_passwordController.text);
                            } else {
                              _passwordValidation = null;
                            }
                          });
                        },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
