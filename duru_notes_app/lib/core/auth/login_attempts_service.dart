import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account lockout status information
class LockoutStatus {
  const LockoutStatus({
    required this.isLocked,
    this.remainingLockoutTime,
    this.attemptsRemaining,
    this.lastAttemptAt,
  });

  final bool isLocked;
  final Duration? remainingLockoutTime;
  final int? attemptsRemaining;
  final DateTime? lastAttemptAt;
}

/// Service to track login attempts and manage account lockouts
class LoginAttemptsService {
  LoginAttemptsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Security constants
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  static const Duration _attemptWindowDuration = Duration(minutes: 30);

  /// Check if a user can attempt to login
  Future<bool> canAttemptLogin(String email) async {
    try {
      final lockStatus = await checkAccountLockout(email);
      return !lockStatus.isLocked;
    } catch (e) {
      // If there's an error checking lockout status, allow login attempt
      // This ensures the app doesn't break if the table doesn't exist
      if (kDebugMode) {
        print('Error checking login attempts: $e');
      }
      return true;
    }
  }

  /// Check account lockout status
  Future<LockoutStatus> checkAccountLockout(String email) async {
    try {
      final now = DateTime.now();
      final windowStart = now.subtract(_attemptWindowDuration);

      // Get failed attempts in the current window
      final response = await _client
          .from('login_attempts')
          .select('attempt_time, success')
          .eq('email', email)
          .gte('attempt_time', windowStart.toIso8601String())
          .order('attempt_time', ascending: false);

      final attempts = response as List<dynamic>;
      
      if (attempts.isEmpty) {
        return const LockoutStatus(isLocked: false, attemptsRemaining: _maxFailedAttempts);
      }

      // Count consecutive failed attempts from most recent
      int consecutiveFailures = 0;
      DateTime? lastAttemptAt;
      
      for (final attempt in attempts) {
        final attemptTime = DateTime.parse(attempt['attempt_time'] as String);
        final wasSuccessful = attempt['success'] as bool;
        
        if (lastAttemptAt == null) {
          lastAttemptAt = attemptTime;
        }
        
        if (wasSuccessful) {
          // Stop counting at first successful login
          break;
        } else {
          consecutiveFailures++;
        }
      }

      // Check if account should be locked
      if (consecutiveFailures >= _maxFailedAttempts && lastAttemptAt != null) {
        final lockoutEnd = lastAttemptAt.add(_lockoutDuration);
        
        if (now.isBefore(lockoutEnd)) {
          return LockoutStatus(
            isLocked: true,
            remainingLockoutTime: lockoutEnd.difference(now),
            attemptsRemaining: 0,
            lastAttemptAt: lastAttemptAt,
          );
        }
      }

      // Account not locked - calculate remaining attempts
      final attemptsRemaining = _maxFailedAttempts - consecutiveFailures;
      
      return LockoutStatus(
        isLocked: false,
        attemptsRemaining: attemptsRemaining > 0 ? attemptsRemaining : _maxFailedAttempts,
        lastAttemptAt: lastAttemptAt,
      );

    } catch (e) {
      if (kDebugMode) {
        print('Error checking account lockout: $e');
      }
      // On error, assume account is not locked
      return const LockoutStatus(isLocked: false, attemptsRemaining: _maxFailedAttempts);
    }
  }

  /// Record a failed login attempt
  Future<void> recordFailedLogin(String email, String errorMessage) async {
    try {
      await _client.from('login_attempts').insert({
        'email': email,
        'success': false,
        'error_message': errorMessage,
        'attempt_time': DateTime.now().toIso8601String(),
        'ip_address': await _getClientIpAddress(),
        'user_agent': await _getUserAgent(),
      });

      // Clean up old attempts
      await _cleanupOldAttempts();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error recording failed login: $e');
      }
      // Don't throw - logging failures shouldn't break auth flow
    }
  }

  /// Record a successful login attempt
  Future<void> recordSuccessfulLogin(String email) async {
    try {
      await _client.from('login_attempts').insert({
        'email': email,
        'success': true,
        'attempt_time': DateTime.now().toIso8601String(),
        'ip_address': await _getClientIpAddress(),
        'user_agent': await _getUserAgent(),
      });

      // Clean up old attempts
      await _cleanupOldAttempts();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error recording successful login: $e');
      }
      // Don't throw - logging failures shouldn't break auth flow
    }
  }

  /// Clear all login attempts for a user (useful for admin actions)
  Future<void> clearLoginAttempts(String email) async {
    try {
      await _client
          .from('login_attempts')
          .delete()
          .eq('email', email);
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing login attempts: $e');
      }
    }
  }

  /// Get recent login attempts for monitoring (admin feature)
  Future<List<Map<String, dynamic>>> getRecentAttempts({
    String? email,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('login_attempts')
          .select('email, success, error_message, attempt_time, ip_address');

      if (email != null) {
        query = query.eq('email', email);
      }

      final response = await query
          .order('attempt_time', ascending: false)
          .limit(limit);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting recent attempts: $e');
      }
      return [];
    }
  }

  /// Clean up old login attempts (older than 7 days)
  Future<void> _cleanupOldAttempts() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      await _client
          .from('login_attempts')
          .delete()
          .lt('attempt_time', cutoffDate.toIso8601String());
          
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old attempts: $e');
      }
    }
  }

  /// Get client IP address (simplified - in real implementation might use headers)
  Future<String?> _getClientIpAddress() async {
    try {
      // In a real implementation, this might extract from request headers
      // For now, return a placeholder
      return 'client_ip';
    } catch (e) {
      return null;
    }
  }

  /// Get user agent string
  Future<String?> _getUserAgent() async {
    try {
      // In a real implementation, this might extract from request headers
      // For now, return a Flutter-specific identifier
      return 'DuruNotes-Flutter/${kDebugMode ? 'debug' : 'release'}';
    } catch (e) {
      return null;
    }
  }

  /// Get lockout statistics for monitoring
  Future<Map<String, dynamic>> getLockoutStatistics() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      
      // Get stats for last 24 hours
      final response = await _client
          .from('login_attempts')
          .select('email, success')
          .gte('attempt_time', last24Hours.toIso8601String());

      final attempts = response as List<dynamic>;
      
      final totalAttempts = attempts.length;
      final failedAttempts = attempts.where((a) => !(a['success'] as bool)).length;
      final successfulAttempts = totalAttempts - failedAttempts;
      
      // Count unique emails with failed attempts
      final failedEmails = attempts
          .where((a) => !(a['success'] as bool))
          .map((a) => a['email'] as String)
          .toSet();

      return {
        'total_attempts_24h': totalAttempts,
        'failed_attempts_24h': failedAttempts,
        'successful_attempts_24h': successfulAttempts,
        'unique_failed_emails_24h': failedEmails.length,
        'failure_rate_24h': totalAttempts > 0 ? (failedAttempts / totalAttempts) : 0.0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting lockout statistics: $e');
      }
      return {
        'error': 'Failed to retrieve statistics',
      };
    }
  }
}

/// SQL script to create the login_attempts table in Supabase
/// Run this in the Supabase SQL editor:
/*
-- Create login_attempts table for rate limiting
CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    success BOOLEAN NOT NULL DEFAULT FALSE,
    error_message TEXT,
    attempt_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address TEXT,
    user_agent TEXT,
    
    -- Indexes for faster lookups
    INDEX idx_login_attempts_email ON login_attempts(email),
    INDEX idx_login_attempts_time ON login_attempts(attempt_time),
    INDEX idx_login_attempts_email_time ON login_attempts(email, attempt_time)
);

-- Enable Row Level Security (optional - for admin access only)
ALTER TABLE login_attempts ENABLE ROW LEVEL SECURITY;

-- Create policy for system access (no user access to this table)
-- Only service role should access this table
CREATE POLICY "Service role access only" ON login_attempts
    FOR ALL USING (false);

-- Grant permissions to service role only
GRANT ALL ON login_attempts TO service_role;
GRANT USAGE ON SEQUENCE login_attempts_id_seq TO service_role;

-- Optional: Create a function to clean up old attempts automatically
CREATE OR REPLACE FUNCTION cleanup_old_login_attempts()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM login_attempts 
    WHERE attempt_time < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Optional: Create a scheduled job to run cleanup (requires pg_cron extension)
-- SELECT cron.schedule('cleanup-login-attempts', '0 2 * * *', 'SELECT cleanup_old_login_attempts();');
*/
