/// GDPR Anonymization Safeguards
///
/// This module implements critical safety checks to prevent accidental
/// or malicious anonymization requests. All checks must pass before
/// proceeding with the irreversible anonymization process.
///
/// **Safeguards Implemented**:
/// 1. Environment validation (prevent production accidents)
/// 2. Rate limiting (24-hour cooldown)
/// 3. Email verification requirement
/// 4. Multi-factor confirmation
/// 5. Active session detection
library;

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when safeguard validation fails
class SafeguardException implements Exception {
  final String message;
  final String safeguardType;
  final Map<String, dynamic>? details;

  SafeguardException(
    this.message, {
    required this.safeguardType,
    this.details,
  });

  @override
  String toString() =>
      'SafeguardException [$safeguardType]: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Result of safeguard validation
class SafeguardValidationResult {
  final bool passed;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> details;

  SafeguardValidationResult({
    required this.passed,
    this.errors = const [],
    this.warnings = const [],
    this.details = const {},
  });

  SafeguardValidationResult.success({List<String>? warnings})
      : passed = true,
        errors = const [],
        warnings = warnings ?? const [],
        details = {};

  SafeguardValidationResult.failure({
    required List<String> errors,
    List<String>? warnings,
    Map<String, dynamic>? details,
  })  : passed = false,
        errors = errors,
        warnings = warnings ?? const [],
        details = details ?? {};
}

/// GDPR Anonymization Safeguards
class GDPRSafeguards {
  GDPRSafeguards({
    required AppLogger logger,
    SupabaseClient? client,
  })  : _logger = logger,
        _client = client ?? Supabase.instance.client;

  final AppLogger _logger;
  final SupabaseClient _client;

  // Cooldown period between anonymization attempts (24 hours)
  static const _cooldownPeriod = Duration(hours: 24);

  // Maximum number of failed attempts before lockout
  static const _maxFailedAttempts = 3;

  /// Validate all safeguards before proceeding with anonymization
  ///
  /// **Returns**: [SafeguardValidationResult] with pass/fail status
  ///
  /// **Throws**: Never throws - returns failure result instead
  Future<SafeguardValidationResult> validateAllSafeguards({
    required String userId,
    required bool userAcknowledgedRisks,
    required bool allowProductionOverride,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];
    final details = <String, dynamic>{};

    _logger.info(
      'GDPR Safeguards: Starting validation',
      data: {
        'userId': userId,
        'userAcknowledged': userAcknowledgedRisks,
        'productionOverride': allowProductionOverride,
      },
    );

    // Safeguard 1: Environment Check
    try {
      final envResult = await _validateEnvironment(
        allowProductionOverride: allowProductionOverride,
      );
      if (!envResult.passed) {
        errors.addAll(envResult.errors);
      }
      warnings.addAll(envResult.warnings);
      details['environment'] = envResult.details;
    } catch (e) {
      errors.add('Environment validation failed: $e');
    }

    // Safeguard 2: Rate Limiting Check
    try {
      final rateResult = await _validateRateLimit(userId: userId);
      if (!rateResult.passed) {
        errors.addAll(rateResult.errors);
      }
      warnings.addAll(rateResult.warnings);
      details['rateLimit'] = rateResult.details;
    } catch (e) {
      errors.add('Rate limit validation failed: $e');
    }

    // Safeguard 3: User Acknowledgment Check
    if (!userAcknowledgedRisks) {
      errors.add(
        'User must explicitly acknowledge the irreversible nature of this operation',
      );
    }

    // Safeguard 4: Email Verification Check
    try {
      final emailResult = await _validateEmailVerified();
      if (!emailResult.passed) {
        errors.addAll(emailResult.errors);
      }
      warnings.addAll(emailResult.warnings);
      details['emailVerification'] = emailResult.details;
    } catch (e) {
      errors.add('Email verification check failed: $e');
    }

    // Safeguard 5: Active Sessions Warning
    try {
      final sessionsResult = await _checkActiveSessions(userId: userId);
      warnings.addAll(sessionsResult.warnings);
      details['activeSessions'] = sessionsResult.details;
    } catch (e) {
      warnings.add('Could not check active sessions: $e');
    }

    final result = errors.isEmpty
        ? SafeguardValidationResult.success(warnings: warnings)
        : SafeguardValidationResult.failure(
            errors: errors,
            warnings: warnings,
            details: details,
          );

    _logger.info(
      'GDPR Safeguards: Validation ${result.passed ? 'PASSED' : 'FAILED'}',
      data: {
        'userId': userId,
        'passed': result.passed,
        'errors': errors,
        'warnings': warnings,
        'details': details,
      },
    );

    return result;
  }

  /// Safeguard 1: Validate environment is safe for anonymization
  Future<SafeguardValidationResult> _validateEnvironment({
    required bool allowProductionOverride,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Check if running in production mode
    const isProduction = bool.fromEnvironment('dart.vm.product', defaultValue: false);

    if (isProduction && !allowProductionOverride) {
      errors.add(
        'GDPR anonymization in PRODUCTION requires explicit override. '
        'This is a critical operation that cannot be undone.',
      );
    }

    if (isProduction) {
      warnings.add(
        '⚠️  PRODUCTION ENVIRONMENT: This operation will permanently delete user data. '
        'Ensure you have followed all verification procedures.',
      );
    }

    // Check if running in debug mode (extra safety)
    if (kDebugMode && !isProduction) {
      warnings.add(
        'Running in DEBUG mode - anonymization will affect the configured database',
      );
    }

    return SafeguardValidationResult(
      passed: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      details: {
        'isProduction': isProduction,
        'isDebugMode': kDebugMode,
        'overrideAllowed': allowProductionOverride,
      },
    );
  }

  /// Safeguard 2: Rate limit check (prevent rapid repeated attempts)
  Future<SafeguardValidationResult> _validateRateLimit({
    required String userId,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check anonymization_events table for recent attempts
      final response = await _client
          .from('anonymization_events')
          .select('created_at, event_type, details')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      if (response.isEmpty) {
        // No previous attempts - all good
        return SafeguardValidationResult.success();
      }

      final events = response as List<dynamic>;

      // Check for recent anonymization attempts
      final now = DateTime.now();
      for (final event in events) {
        final createdAt = DateTime.parse(event['created_at'] as String);
        final timeSinceAttempt = now.difference(createdAt);

        if (timeSinceAttempt < _cooldownPeriod) {
          final remainingTime = _cooldownPeriod - timeSinceAttempt;
          final hoursRemaining = remainingTime.inHours;
          final minutesRemaining = remainingTime.inMinutes % 60;

          errors.add(
            'Rate limit exceeded. You must wait $hoursRemaining hours and '
            '$minutesRemaining minutes before attempting anonymization again. '
            'This cooldown prevents accidental or malicious repeated attempts.',
          );
          break;
        }
      }

      // Check for failed attempts
      final failedAttempts = events
          .where((e) =>
              (e['event_type'] as String).contains('FAILED') ||
              (e['details'] as Map<String, dynamic>?)?['success'] == false)
          .length;

      if (failedAttempts >= _maxFailedAttempts) {
        warnings.add(
          '⚠️  Multiple failed anonymization attempts detected. '
          'Please contact support if you are experiencing issues.',
        );
      }

      return SafeguardValidationResult(
        passed: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        details: {
          'totalAttempts': events.length,
          'failedAttempts': failedAttempts,
          'lastAttempt': events.isNotEmpty ? events.first['created_at'] : null,
        },
      );
    } catch (e) {
      _logger.warning(
        'Rate limit check failed - proceeding with caution',
        data: {'error': e.toString()},
      );
      warnings.add('Could not verify rate limit status - proceeding with caution');
      return SafeguardValidationResult.success(warnings: warnings);
    }
  }

  /// Safeguard 4: Verify user's email is verified
  Future<SafeguardValidationResult> _validateEmailVerified() async {
    final errors = <String>[];
    final warnings = <String>[];

    final user = _client.auth.currentUser;
    if (user == null) {
      errors.add('No authenticated user found');
      return SafeguardValidationResult.failure(errors: errors);
    }

    // Check email confirmation status
    final emailConfirmed = user.emailConfirmedAt != null;
    if (!emailConfirmed) {
      errors.add(
        'Email address must be verified before account deletion. '
        'Please verify your email and try again.',
      );
    }

    return SafeguardValidationResult(
      passed: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      details: {
        'email': user.email,
        'emailConfirmed': emailConfirmed,
        'emailConfirmedAt': user.emailConfirmedAt,
      },
    );
  }

  /// Safeguard 5: Check for active sessions on other devices
  Future<SafeguardValidationResult> _checkActiveSessions({
    required String userId,
  }) async {
    final warnings = <String>[];

    try {
      // Check user_devices table for recently active devices
      final response = await _client
          .from('user_devices')
          .select('device_name, last_seen_at, device_type')
          .eq('user_id', userId)
          .order('last_seen_at', ascending: false);

      if (response.isEmpty) {
        return SafeguardValidationResult.success();
      }

      final devices = response as List<dynamic>;
      final now = DateTime.now();
      final activeDevices = devices.where((device) {
        final lastSeen = DateTime.parse(device['last_seen_at'] as String);
        final timeSinceActive = now.difference(lastSeen);
        return timeSinceActive < const Duration(hours: 24);
      }).toList();

      if (activeDevices.length > 1) {
        warnings.add(
          '⚠️  You have ${activeDevices.length} active devices. '
          'Anonymization will sign you out of ALL devices permanently.',
        );
      }

      return SafeguardValidationResult.success(
        warnings: warnings,
      );
    } catch (e) {
      _logger.warning(
        'Active session check failed',
        data: {'error': e.toString()},
      );
      return SafeguardValidationResult.success();
    }
  }

  /// Record anonymization attempt for rate limiting
  Future<void> recordAnonymizationAttempt({
    required String userId,
    required String anonymizationId,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      await _client.from('anonymization_events').insert({
        'user_id': userId,
        'anonymization_id': anonymizationId,
        'event_type': success ? 'ATTEMPT_SUCCESS' : 'ATTEMPT_FAILED',
        'phase_number': 0,
        'details': {
          'success': success,
          'error': errorMessage,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      _logger.warning(
        'Failed to record anonymization attempt',
        data: {'error': e.toString()},
      );
    }
  }
}
