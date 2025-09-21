import 'package:duru_notes/core/security/password_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage password history and prevent password reuse
class PasswordHistoryService {
  PasswordHistoryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Number of previous passwords to check
  static const int _historyLimit = 5;

  /// Check if a password has been used before
  Future<bool> isPasswordReused(String userId, String newPassword) async {
    try {
      // Query the password history table
      final response = await _client
          .from('password_history')
          .select('password_hash')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(_historyLimit);

      final passwordHistory = response as List<dynamic>;

      // Check if the new password matches any previous password using secure verification
      for (final record in passwordHistory) {
        final historicalHash = record['password_hash'] as String;
        if (PasswordValidator.verifyPassword(newPassword, historicalHash)) {
          return true; // Password has been used before
        }
      }

      return false; // Password is new
    } catch (e) {
      // If there's an error (e.g., table doesn't exist), allow the password
      // This ensures the app doesn't break if password history isn't set up
      return false;
    }
  }

  /// Store a new password hash in the history
  Future<void> storePasswordHash(String userId, String password) async {
    try {
      final passwordHash = PasswordValidator.hashPassword(password);

      // Insert the new password hash
      await _client.from('password_history').insert({
        'user_id': userId,
        'password_hash': passwordHash,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Clean up old password history (keep only the most recent ones)
      await _cleanupOldPasswords(userId);
    } catch (e) {
      // If there's an error, don't fail the registration process
      // Log the error in production
      return;
    }
  }

  /// Remove old password history beyond the limit
  Future<void> _cleanupOldPasswords(String userId) async {
    try {
      // Get all password history for the user, ordered by creation date
      final response = await _client
          .from('password_history')
          .select('id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final passwordHistory = response as List<dynamic>;

      // If we have more than the limit, delete the oldest ones
      if (passwordHistory.length > _historyLimit) {
        final idsToDelete = passwordHistory
            .skip(_historyLimit)
            .map((record) => record['id'])
            .toList();

        if (idsToDelete.isNotEmpty) {
          await _client
              .from('password_history')
              .delete()
              .inFilter('id', idsToDelete);
        }
      }
    } catch (e) {
      // If cleanup fails, it's not critical
      return;
    }
  }

  /// Get the creation date of the last password change
  Future<DateTime?> getLastPasswordChangeDate(String userId) async {
    try {
      final response = await _client
          .from('password_history')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return DateTime.parse(response['created_at'] as String);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clear all password history for a user (useful for account deletion)
  Future<void> clearPasswordHistory(String userId) async {
    try {
      await _client.from('password_history').delete().eq('user_id', userId);
    } catch (e) {
      // If cleanup fails, it's not critical
      return;
    }
  }
}

/// SQL script to create the password_history table in Supabase
/// Run this in the Supabase SQL editor:
/*
-- Create password_history table
CREATE TABLE IF NOT EXISTS password_history (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Index for faster lookups
    INDEX idx_password_history_user_id ON password_history(user_id),
    INDEX idx_password_history_created_at ON password_history(created_at)
);

-- Enable Row Level Security
ALTER TABLE password_history ENABLE ROW LEVEL SECURITY;

-- Create policy so users can only access their own password history
CREATE POLICY "Users can access their own password history" ON password_history
    FOR ALL USING (auth.uid() = user_id);

-- Grant permissions to authenticated users
GRANT ALL ON password_history TO authenticated;
GRANT USAGE ON SEQUENCE password_history_id_seq TO authenticated;
*/
