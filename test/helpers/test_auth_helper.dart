/// Test Authentication Helper
///
/// Provides utilities for simulating authentication flows in tests
/// Ensures proper setup and teardown of auth state
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:mockito/mockito.dart';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/guards/auth_guard.dart';

/// Test user model for authentication testing
class TestUser {
  final String id;
  final String email;
  final String password;
  final String amkKey;
  final Map<String, dynamic>? metadata;

  TestUser({
    required this.id,
    required this.email,
    required this.password,
    required this.amkKey,
    this.metadata,
  });

  /// Create a Supabase User object from test user
  supabase.User toSupabaseUser() {
    return supabase.User(
      id: id,
      email: email,
      appMetadata: metadata ?? {},
      userMetadata: metadata ?? {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Create a session for this user
  supabase.Session toSession({String? accessToken, String? refreshToken}) {
    return supabase.Session(
      accessToken: accessToken ?? 'test-access-token-$id',
      refreshToken: refreshToken ?? 'test-refresh-token-$id',
      expiresIn: 3600,
      tokenType: 'bearer',
      user: toSupabaseUser(),
    );
  }
}

/// Authentication test helper for managing test auth flows
class AuthTestHelper {
  final AppDb database;
  final supabase.SupabaseClient supabaseClient;
  final KeyManager keyManager;
  final AuthenticationGuard? authGuard;

  String? currentUserId;
  TestUser? currentUser;

  AuthTestHelper({
    required this.database,
    required this.supabaseClient,
    required this.keyManager,
    this.authGuard,
  });

  /// Sign up a new test user
  Future<void> signUpAs(TestUser user) async {
    // Clear any existing session
    await signOut();

    // Mock Supabase auth response
    final mockAuth = supabaseClient.auth as dynamic;
    when(
      mockAuth.signUp(email: user.email, password: user.password),
    ).thenAnswer(
      (_) async => supabase.AuthResponse(
        session: user.toSession(),
        user: user.toSupabaseUser(),
      ),
    );

    // Set current user
    when(mockAuth.currentUser).thenReturn(user.toSupabaseUser());
    when(mockAuth.currentSession).thenReturn(user.toSession());

    // Setup encryption key interactions for new key manager API
    await keyManager.getOrCreateMasterKey(user.id);
    await keyManager.getLegacyMasterKey(user.id);

    // Store user info
    currentUserId = user.id;
    currentUser = user;

    // Store in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_email', user.email);
    await prefs.setBool('has_amk', true);

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] Signed up as ${user.email} (${user.id})');
    }
  }

  /// Sign in as existing test user
  Future<void> signInAs(TestUser user) async {
    // Clear everything first
    await signOut();

    // Mock Supabase auth
    final mockAuth = supabaseClient.auth as dynamic;
    when(
      mockAuth.signInWithPassword(email: user.email, password: user.password),
    ).thenAnswer(
      (_) async => supabase.AuthResponse(
        session: user.toSession(),
        user: user.toSupabaseUser(),
      ),
    );

    // Set current user
    when(mockAuth.currentUser).thenReturn(user.toSupabaseUser());
    when(mockAuth.currentSession).thenReturn(user.toSession());

    // Setup key manager stubs for existing user
    await keyManager.getOrCreateMasterKey(user.id);
    await keyManager.getLegacyMasterKey(user.id);

    // Store current user
    currentUserId = user.id;
    currentUser = user;

    // Store in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_email', user.email);
    await prefs.setBool('has_amk', true);

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] Signed in as ${user.email} (${user.id})');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    // CRITICAL: Clear database first
    await database.clearAll();

    if (kDebugMode && currentUser != null) {
      debugPrint('[AuthTestHelper] Signing out ${currentUser!.email}');
    }

    // Clear auth state
    final mockAuth = supabaseClient.auth as dynamic;
    when(mockAuth.currentUser).thenReturn(null);
    when(mockAuth.currentSession).thenReturn(null);
    when(mockAuth.signOut()).thenAnswer((_) async {});

    // Clear key manager
    if (currentUserId != null) {
      await keyManager.deleteMasterKey(currentUserId!);
    }

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Clear auth guard if provided
    authGuard?.logoutAllSessions(currentUserId ?? '');

    currentUserId = null;
    currentUser = null;

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] Sign out complete - database cleared');
    }
  }

  /// Force sign in (logout previous user if any)
  Future<void> forceSignInAs(TestUser user) async {
    if (currentUserId != null && currentUserId != user.id) {
      await signOut();
    }
    await signInAs(user);
  }

  /// Simulate session expiration
  Future<void> expireSession() async {
    final mockAuth = supabaseClient.auth as dynamic;
    when(mockAuth.currentSession).thenReturn(null);

    // Clear from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] Session expired');
    }
  }

  /// Simulate token refresh
  Future<void> refreshToken() async {
    if (currentUser == null) {
      throw Exception('No current user to refresh token for');
    }

    final mockAuth = supabaseClient.auth as dynamic;
    final newSession = currentUser!.toSession(
      accessToken: 'new-access-token-${currentUser!.id}',
      refreshToken: 'new-refresh-token-${currentUser!.id}',
    );

    when(mockAuth.refreshSession()).thenAnswer(
      (_) async => supabase.AuthResponse(
        session: newSession,
        user: currentUser!.toSupabaseUser(),
      ),
    );

    when(mockAuth.currentSession).thenReturn(newSession);

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] Token refreshed for ${currentUser!.email}');
    }
  }

  /// Simulate device verification
  Future<void> verifyDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('verified_device_id', deviceId);
    await prefs.setBool('device_verified', true);

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] Device verified: $deviceId');
    }
  }

  /// Simulate MFA setup
  Future<void> setupMFA() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mfa_enabled', true);
    await prefs.setString('mfa_secret', 'test-mfa-secret');

    if (kDebugMode) {
      debugPrint('[AuthTestHelper] MFA enabled for ${currentUser?.email}');
    }
  }

  /// Verify current auth state
  Future<bool> isAuthenticated() async {
    final mockAuth = supabaseClient.auth as dynamic;
    final user = mockAuth.currentUser;
    final session = mockAuth.currentSession;

    return user != null && session != null;
  }

  /// Get current user ID
  String? getCurrentUserId() => currentUserId;

  /// Get current user
  TestUser? getCurrentUser() => currentUser;

  /// Verify database is empty (for security tests)
  Future<bool> isDatabaseEmpty() async {
    final notes = await database.select(database.localNotes).get();
    final tasks = await database.select(database.noteTasks).get();
    final folders = await database.select(database.localFolders).get();
    final searches = await database.select(database.savedSearches).get();
    final reminders = await database.select(database.noteReminders).get();

    return notes.isEmpty &&
        tasks.isEmpty &&
        folders.isEmpty &&
        searches.isEmpty &&
        reminders.isEmpty;
  }

  /// Verify no cross-user data contamination
  Future<bool> verifyUserIsolation(String expectedUserId) async {
    // Check all tables for user_id consistency
    final notes = await database.select(database.localNotes).get();
    for (final note in notes) {
      if (note.userId != null && note.userId != expectedUserId) {
        if (kDebugMode) {
          debugPrint(
            '[AuthTestHelper] ❌ User isolation breach: Note ${note.id} has userId ${note.userId}, expected $expectedUserId',
          );
        }
        return false;
      }
    }

    final tasks = await database.select(database.noteTasks).get();
    for (final task in tasks) {
      if (task.userId != expectedUserId) {
        if (kDebugMode) {
          debugPrint(
            '[AuthTestHelper] ❌ User isolation breach: Task ${task.id} has userId ${task.userId}, expected $expectedUserId',
          );
        }
        return false;
      }
    }

    final folders = await database.select(database.localFolders).get();
    for (final folder in folders) {
      if (folder.userId != expectedUserId) {
        if (kDebugMode) {
          debugPrint(
            '[AuthTestHelper] ❌ User isolation breach: Folder ${folder.id} has userId ${folder.userId}, expected $expectedUserId',
          );
        }
        return false;
      }
    }

    return true;
  }
}

/// Test data builder for authentication scenarios
class AuthTestDataBuilder {
  /// Create standard test users
  static TestUser createUserA() {
    return TestUser(
      id: 'user-a-${DateTime.now().millisecondsSinceEpoch}',
      email: 'user.a@test.com',
      password: 'SecurePassword123!',
      amkKey: 'user-a-encryption-key-32-bytes!!',
      metadata: {
        'full_name': 'User A',
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  static TestUser createUserB() {
    return TestUser(
      id: 'user-b-${DateTime.now().millisecondsSinceEpoch}',
      email: 'user.b@test.com',
      password: 'SecurePassword456!',
      amkKey: 'user-b-encryption-key-32-bytes!!',
      metadata: {
        'full_name': 'User B',
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  static TestUser createAdminUser() {
    return TestUser(
      id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
      email: 'admin@test.com',
      password: 'AdminPassword789!',
      amkKey: 'admin-encryption-key-32-bytes!!!',
      metadata: {
        'full_name': 'Admin User',
        'role': 'admin',
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Create user with specific attributes
  static TestUser createCustomUser({
    String? id,
    required String email,
    String? password,
    String? amkKey,
    Map<String, dynamic>? metadata,
  }) {
    return TestUser(
      id: id ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      password: password ?? 'DefaultPassword123!',
      amkKey: amkKey ?? 'default-encryption-key-32-bytes!',
      metadata: metadata,
    );
  }
}

/// Security test utilities
class SecurityTestUtils {
  /// Check for data leakage between users
  static Future<List<String>> checkForDataLeakage({
    required AppDb database,
    required String expectedUserId,
  }) async {
    final violations = <String>[];

    // Check notes
    final notes = await database.select(database.localNotes).get();
    for (final note in notes) {
      if (note.userId != null && note.userId != expectedUserId) {
        violations.add(
          'Note ${note.id} belongs to ${note.userId}, expected $expectedUserId',
        );
      }
    }

    // Check tasks
    final tasks = await database.select(database.noteTasks).get();
    for (final task in tasks) {
      if (task.userId != expectedUserId) {
        violations.add(
          'Task ${task.id} belongs to ${task.userId}, expected $expectedUserId',
        );
      }
    }

    // Check folders
    final folders = await database.select(database.localFolders).get();
    for (final folder in folders) {
      if (folder.userId != expectedUserId) {
        violations.add(
          'Folder ${folder.id} belongs to ${folder.userId}, expected $expectedUserId',
        );
      }
    }

    // Check saved searches
    final searches = await database.select(database.savedSearches).get();
    for (final search in searches) {
      if (search.userId != null && search.userId != expectedUserId) {
        violations.add(
          'Search ${search.id} belongs to ${search.userId}, expected $expectedUserId',
        );
      }
    }

    // Check reminders
    final reminders = await database.select(database.noteReminders).get();
    for (final reminder in reminders) {
      if (reminder.userId != expectedUserId) {
        violations.add(
          'Reminder ${reminder.id} belongs to ${reminder.userId}, expected $expectedUserId',
        );
      }
    }

    return violations;
  }

  /// Verify encryption keys are properly isolated
  static Future<bool> verifyKeyIsolation({
    required String userAKey,
    required String userBKey,
    required String userAData,
    required String userBData,
  }) async {
    // Try to decrypt User A's data with User B's key
    try {
      // This should fail - if it succeeds, we have a security breach
      // Implementation depends on your encryption service
      return false; // Should not reach here
    } catch (e) {
      // Expected - decryption should fail
      return true;
    }
  }
}
