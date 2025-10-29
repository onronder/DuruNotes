# COMPREHENSIVE SECURITY AUDIT REPORT

## EXECUTIVE SUMMARY
Critical data leakage vulnerabilities discovered allowing User B to potentially access User A's data after login. Found 3 CRITICAL issues with incomplete database clearing, improper user ID validation during sync, and race conditions in authentication state transitions. Immediate patches required before production use.

## CRITICAL VULNERABILITIES (Fix immediately)

### 1. INCOMPLETE DATABASE CLEARING ON LOGOUT - CRITICAL
**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:1037-1055`

**Current code**:
```dart
Future<void> clearAll() async {
  await transaction(() async {
    await delete(pendingOps).go();
    await delete(noteFolders).go();
    await delete(noteTags).go();
    await delete(noteLinks).go();
    await delete(noteReminders).go();
    await delete(noteTasks).go();
    await delete(localNotes).go();
    await delete(localFolders).go();
    await delete(savedSearches).go();
    await customStatement('DELETE FROM fts_notes');
  });
}
```

**Missing tables NOT cleared**:
- `localTemplates` (line 374) - User templates remain after logout
- `attachments` (line 420) - File attachments remain after logout
- `inboxItems` (line 454) - Inbox items remain after logout

**Fix**:
```dart
Future<void> clearAll() async {
  await transaction(() async {
    // Clear in reverse dependency order
    await delete(pendingOps).go();
    await delete(noteFolders).go();
    await delete(noteTags).go();
    await delete(noteLinks).go();
    await delete(noteReminders).go();
    await delete(noteTasks).go();
    await delete(localNotes).go();
    await delete(localFolders).go();
    await delete(savedSearches).go();
    await delete(localTemplates).go(); // CRITICAL: Add this
    await delete(attachments).go();     // CRITICAL: Add this
    await delete(inboxItems).go();      // CRITICAL: Add this
    await customStatement('DELETE FROM fts_notes');
  });
}
```

### 2. RACE CONDITION IN LOGOUT DATABASE CLEARING
**File**: `/Users/onronder/duru-notes/lib/app/app.dart:616-624`

**Current code**:
```dart
// User is not authenticated - show login screen
WidgetsBinding.instance.addPostFrameCallback((_) async {
  try {
    final db = ref.read(appDbProvider);
    await db.clearAll();
    debugPrint('[AuthWrapper] ✅ Database cleared on logout');
  } catch (e) {
    debugPrint('[AuthWrapper] ⚠️ Error clearing database on logout: $e');
  }
});
```

**Problem**: Database clearing happens AFTER AuthScreen is shown, creating a race condition where User B could authenticate before User A's data is cleared.

**Fix**:
```dart
// User is not authenticated - MUST clear database before showing login
if (!_isClearing) {
  _isClearing = true;
  // Block UI until database is cleared
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final db = ref.read(appDbProvider);
      await db.clearAll();
      debugPrint('[AuthWrapper] ✅ Database cleared before login screen');
    } catch (e) {
      debugPrint('[AuthWrapper] ⚠️ Error clearing database: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  });
}

if (_isClearing) {
  return const Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Clearing previous session...'),
        ],
      ),
    ),
  );
}

return const AuthScreen();
```

### 3. MISSING USER ID VALIDATION IN SYNC
**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart`

**Multiple locations with fallback to current user**:
- Line 121: `final userId = localNote.userId ?? _supabase.auth.currentUser?.id ?? '';`
- Line 1002-1008: Remote note sync fallback
- Line 1141-1147: Remote folder sync fallback
- Line 914-917: Template sync fallback

**Problem**: If remote data lacks user_id or local data has null user_id, it falls back to current user, potentially mixing data between users.

**Fix for line 121**:
```dart
// CRITICAL: Validate user ID matches current user
final currentUserId = _supabase.auth.currentUser?.id;
if (currentUserId == null) {
  throw StateError('No authenticated user for note hydration');
}

final noteUserId = localNote.userId;
if (noteUserId != null && noteUserId != currentUserId) {
  _logger.error(
    'SECURITY: Note user_id mismatch',
    data: {
      'noteId': localNote.id,
      'noteUserId': noteUserId,
      'currentUserId': currentUserId,
    },
  );
  return null; // Reject note with wrong user_id
}

final userId = noteUserId ?? currentUserId;
```

**Fix for sync methods (lines 1002-1008)**:
```dart
Future<void> _applyRemoteNote(Map<String, dynamic> remoteNote) async {
  final noteId = remoteNote['id'] as String;
  try {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('No authenticated user for remote note sync');
    }

    final remoteUserId = remoteNote['user_id'] as String?;
    if (remoteUserId == null) {
      _logger.error('SECURITY: Remote note missing user_id', data: {'noteId': noteId});
      return; // Skip note without user_id
    }

    if (remoteUserId != currentUserId) {
      _logger.error(
        'SECURITY: Remote note user_id mismatch',
        data: {
          'noteId': noteId,
          'remoteUserId': remoteUserId,
          'currentUserId': currentUserId,
        },
      );
      return; // Reject note from different user
    }

    // Continue with sync...
```

## HIGH PRIORITY ISSUES

### 4. FRESH INSTALL DETECTION VULNERABILITY
**File**: `/Users/onronder/duru-notes/lib/app/app.dart:814-840`

**Problem**: Fresh install detection only runs on initial load (`_amkCheckKey == 0`). If iOS Keychain persists AMK after app deletion, stale keys may be trusted.

**Fix**:
```dart
// Check on every app start, not just initial load
if (userId != null) {
  try {
    final db = ref.read(appDbProvider);
    final localNotes = await (db.select(db.localNotes)..limit(1)).get();

    // Also check if user_id in local notes matches current user
    if (localNotes.isNotEmpty) {
      final noteUserId = localNotes.first.userId;
      if (noteUserId != null && noteUserId != userId) {
        // Data from different user detected!
        await encryptionService.clearLocalKeys();
        await db.clearAll();
        return false; // Force re-authentication
      }
    }
  } catch (e) {
    debugPrint('[AuthWrapper] Error checking fresh install: $e');
  }
}
```

### 5. NO USER ID VALIDATION IN UNIFIED SYNC SERVICE
**File**: `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart:1318-1336`

**Problem**: `_getRemoteNotes()` and `_getRemoteFolders()` fetch data but don't validate user_id matches current user.

**Fix**:
```dart
Future<List<Map<String, dynamic>>> _getRemoteNotes() async {
  try {
    final currentUserId = _client!.auth.currentUser?.id;
    if (currentUserId == null) {
      _logger.error('Cannot fetch notes without authenticated user');
      return [];
    }

    final api = SupabaseNoteApi(_client!);
    final encryptedNotes = await api.fetchEncryptedNotes();

    // CRITICAL: Filter out notes from other users
    final validNotes = <Map<String, dynamic>>[];
    for (final note in encryptedNotes) {
      final noteUserId = note['user_id'] as String?;
      if (noteUserId == currentUserId) {
        validNotes.add(note);
      } else {
        _logger.error(
          'SECURITY: Received note from different user',
          data: {
            'noteId': note['id'],
            'noteUserId': noteUserId,
            'currentUserId': currentUserId,
          },
        );
      }
    }

    return validNotes;
```

## MEDIUM PRIORITY ISSUES

### 6. NULLABLE USER_ID IN LOCAL TABLES
**File**: `/Users/onronder/duru-notes/lib/data/local/app_db.dart:50`

**Problem**: `userId` column is nullable in LocalNotes table, allowing notes without user association.

**Fix**: Migration to make userId required:
```sql
-- Migration to enforce user_id
UPDATE local_notes SET user_id = (SELECT id FROM auth.users LIMIT 1) WHERE user_id IS NULL;
ALTER TABLE local_notes ALTER COLUMN user_id SET NOT NULL;
```

### 7. ENCRYPTION FORMAT INCONSISTENCY
**File**: `/Users/onronder/duru-notes/lib/infrastructure/repositories/notes_core_repository.dart:129-142`

**Problem**: Mixed encryption formats (raw JSON vs base64-encoded) causing "SecretBox deserialization error".

**Fix**: Implement migration to standardize all encryption to base64 format:
```dart
Future<void> migrateEncryptionFormat() async {
  final notes = await db.select(db.localNotes).get();
  for (final note in notes) {
    if (note.titleEncrypted.startsWith('{')) {
      // Migrate from raw JSON to proper encrypted format
      final parsed = jsonDecode(note.titleEncrypted);
      final plainTitle = parsed['title'] as String? ?? '';

      // Re-encrypt properly
      final encrypted = await crypto.encryptStringForNote(
        userId: note.userId ?? currentUserId,
        noteId: note.id,
        text: plainTitle,
      );

      await db.update(db.localNotes).replace(
        note.copyWith(titleEncrypted: base64Encode(encrypted)),
      );
    }
  }
}
```

## ARCHITECTURE RECOMMENDATIONS

### 1. Implement Defense in Depth
- Add user_id validation at EVERY layer (UI, Service, Repository, Database)
- Never trust data from any source without validation
- Log all security-relevant events for audit trail

### 2. Synchronous Logout Flow
```dart
Future<void> signOut() async {
  try {
    // 1. Clear encryption keys first (prevents decryption)
    await encryptionService.clearLocalKeys();

    // 2. Clear database (removes all data)
    await db.clearAll();

    // 3. Sign out from Supabase (invalidates session)
    await supabase.auth.signOut();

    // 4. Clear any in-memory caches
    ref.invalidate(allProviders);

    // 5. Navigate to login only after everything is cleared
    Navigator.of(context).pushReplacementNamed('/login');
  } catch (e) {
    // Log but continue - security takes precedence
    logger.error('Error during sign out', error: e);
  }
}
```

### 3. Implement User ID Stamping
Every entity creation should stamp the current user_id:
```dart
Future<void> createNote(String title, String body) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw StateError('Not authenticated');

  final note = LocalNote(
    id: uuid.v4(),
    userId: userId, // REQUIRED field
    titleEncrypted: await encrypt(title, userId),
    bodyEncrypted: await encrypt(body, userId),
    updatedAt: DateTime.now(),
  );

  await db.into(db.localNotes).insert(note);
}
```

### 4. Add Security Middleware
```dart
class SecurityMiddleware {
  static Future<T> validateUserContext<T>(
    Future<T> Function(String userId) operation,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw SecurityException('No authenticated user');
    }

    try {
      return await operation(userId);
    } catch (e) {
      if (e.toString().contains('different user')) {
        // Potential security breach - clear everything
        await emergencyCleanup();
        throw SecurityException('User context violation detected');
      }
      rethrow;
    }
  }
}
```

## TESTING CHECKLIST

- [ ] Test User A logs in, creates notes, logs out
- [ ] Test User B logs in immediately after - should see NO data from User A
- [ ] Test database tables after logout - all should be empty
- [ ] Test with iOS Keychain persistence - stale AMK should be rejected
- [ ] Test sync with mismatched user_id - should be rejected
- [ ] Test encryption key isolation - User A's keys cannot decrypt User B's data
- [ ] Test race condition - rapid logout/login switching
- [ ] Test templates, attachments, inbox items cleared on logout
- [ ] Test sync validation rejects cross-user data
- [ ] Test all error paths maintain security (fail closed, not open)

## IMMEDIATE ACTION ITEMS

1. **PATCH clearAll() method** - Add missing tables (templates, attachments, inbox)
2. **Fix logout race condition** - Clear database synchronously before showing login
3. **Add user_id validation** - Check every sync operation for matching user_id
4. **Deploy hotfix** - These are critical security issues

## MONITORING RECOMMENDATIONS

Add security event logging:
```dart
class SecurityEventLogger {
  static void logSecurityEvent({
    required String event,
    required String severity,
    Map<String, dynamic>? data,
  }) {
    Sentry.captureMessage(
      'SECURITY: $event',
      level: severity == 'critical' ? SentryLevel.error : SentryLevel.warning,
      withScope: (scope) {
        scope.setTag('security_event', event);
        scope.setContexts('security_data', data ?? {});
      },
    );
  }
}
```

Monitor for:
- User ID mismatches
- Failed encryption/decryption
- Unexpected data in clearAll()
- Cross-user data access attempts
- Authentication state anomalies