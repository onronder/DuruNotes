# CRITICAL SECURITY FIXES - IMPLEMENTATION GUIDE

## PRIORITY 1: Fix Database Clearing (Immediate)

### Step 1: Update app_db.dart clearAll() method

```dart
// File: lib/data/local/app_db.dart
// Line: 1037

Future<void> clearAll() async {
  await transaction(() async {
    // Clear all tables in reverse dependency order
    await delete(pendingOps).go();
    await delete(noteFolders).go();
    await delete(noteTags).go();
    await delete(noteLinks).go();
    await delete(noteReminders).go();
    await delete(noteTasks).go();
    await delete(localNotes).go();
    await delete(localFolders).go();
    await delete(savedSearches).go();

    // CRITICAL ADDITIONS - These were missing!
    await delete(localTemplates).go();  // Templates contain user data
    await delete(attachments).go();      // Attachments linked to notes
    await delete(inboxItems).go();       // Inbox items are user-specific

    await customStatement('DELETE FROM fts_notes'); // Clear search index

    if (kDebugMode) {
      // Enhanced logging for verification
      debugPrint('[AppDb] ✅ All tables cleared:');
      debugPrint('  - pendingOps, noteFolders, noteTags, noteLinks');
      debugPrint('  - noteReminders, noteTasks, localNotes');
      debugPrint('  - localFolders, savedSearches');
      debugPrint('  - localTemplates, attachments, inboxItems');
      debugPrint('  - fts_notes index');
    }
  });
}
```

### Step 2: Fix Logout Race Condition in app.dart

```dart
// File: lib/app/app.dart
// Add this field to _AuthWrapperState class (around line 250)
bool _isClearing = false;

// Replace lines 612-639 with:
} else {
  // User is not authenticated

  // CRITICAL: Clear database BEFORE showing login screen
  if (!_isClearing) {
    _isClearing = true;

    // Clear immediately, not in post-frame callback
    Future.microtask(() async {
      try {
        final db = ref.read(appDbProvider);
        await db.clearAll();

        // Also clear encryption keys
        if (EncryptionFeatureFlags.enableCrossDeviceEncryption) {
          final encryptionService = ref.read(encryptionSyncServiceProvider);
          await encryptionService.clearLocalKeys();
        }

        debugPrint('[AuthWrapper] ✅ Database and keys cleared on logout');
      } catch (e) {
        debugPrint('[AuthWrapper] ⚠️ Error clearing data on logout: $e');
        // Log to Sentry
        await Sentry.captureException(
          e,
          withScope: (scope) {
            scope.level = SentryLevel.error;
            scope.setTag('operation', 'logout_cleanup');
          },
        );
      } finally {
        if (mounted) {
          setState(() {
            _isClearing = false;
          });
        }
      }
    });
  }

  // Show loading screen while clearing
  if (_isClearing) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Securing your data...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Clearing previous session',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Reset all state flags
  _hasTriggeredInitialSync = false;
  SecurityInitialization.dispose();
  _pendingSecurityInitialization = null;
  _clipperService?.stop();
  _clipperService = null;
  _notificationTapSubscription?.cancel();
  _notificationTapSubscription = null;
  _notificationHandler?.dispose();
  _notificationHandler = null;

  return const AuthScreen();
}
```

## PRIORITY 2: Add User ID Validation

### Step 3: Fix notes_core_repository.dart

```dart
// File: lib/infrastructure/repositories/notes_core_repository.dart
// Replace _hydrateDomainNote method (line 115)

Future<domain.Note?> _hydrateDomainNote(LocalNote localNote) async {
  try {
    // CRITICAL: Validate user ID first
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _logger.warning('Cannot hydrate note without authenticated user');
      return null;
    }

    // Check if note belongs to current user
    if (localNote.userId != null && localNote.userId != currentUserId) {
      _logger.error(
        'SECURITY: Attempting to hydrate note from different user',
        data: {
          'noteId': localNote.id,
          'noteUserId': localNote.userId,
          'currentUserId': currentUserId,
        },
      );

      // Critical: Delete the invalid note
      await db.delete(db.localNotes)
        .where((tbl) => tbl.id.equals(localNote.id))
        .go();

      return null;
    }

    final tags = await _loadTags(localNote.id);
    final links = await _loadDomainLinks(localNote.id);

    // Use validated userId for decryption
    final userId = localNote.userId ?? currentUserId;
    String title = '';
    String body = '';

    // ... rest of the decryption code ...
```

### Step 4: Fix Remote Sync Validation

```dart
// File: lib/infrastructure/repositories/notes_core_repository.dart
// Replace _applyRemoteNote method (line 999)

Future<void> _applyRemoteNote(Map<String, dynamic> remoteNote) async {
  final noteId = remoteNote['id'] as String;

  try {
    // CRITICAL: Validate user context
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('No authenticated user for remote note sync');
    }

    // Validate remote note belongs to current user
    final remoteUserId = remoteNote['user_id'] as String?;
    if (remoteUserId == null || remoteUserId.isEmpty) {
      _logger.error(
        'SECURITY: Remote note missing user_id',
        data: {'noteId': noteId, 'remoteData': remoteNote},
      );

      // Report to Sentry
      await Sentry.captureMessage(
        'Security: Remote note without user_id',
        level: SentryLevel.error,
        withScope: (scope) {
          scope.setContexts('note_data', {'noteId': noteId});
        },
      );

      return; // Skip this note
    }

    if (remoteUserId != currentUserId) {
      // CRITICAL SECURITY BREACH DETECTED
      _logger.error(
        'CRITICAL: Cross-user data detected in sync',
        data: {
          'noteId': noteId,
          'remoteUserId': remoteUserId,
          'currentUserId': currentUserId,
        },
      );

      // Emergency response
      await Sentry.captureMessage(
        'CRITICAL SECURITY: Cross-user data in sync',
        level: SentryLevel.fatal,
        withScope: (scope) {
          scope.setContexts('security_breach', {
            'noteId': noteId,
            'remoteUserId': remoteUserId,
            'currentUserId': currentUserId,
          });
        },
      );

      // Clear local database as precaution
      await db.clearAll();

      throw SecurityException('Cross-user data detected - emergency cleanup initiated');
    }

    // Continue with validated note...
    // ... rest of the method ...
```

### Step 5: Add Security Exception Class

```dart
// File: lib/core/errors.dart
// Add this class

class SecurityException implements Exception {
  SecurityException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'SecurityException: $message';
}
```

## PRIORITY 3: Testing

### Create Security Test

```dart
// File: test/security/cross_user_data_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Cross-User Data Security', () {
    late AppDb db;

    setUp(() async {
      db = AppDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('clearAll() clears all tables', () async {
      // Insert test data
      await db.into(db.localNotes).insert(/*...*/);
      await db.into(db.localTemplates).insert(/*...*/);
      await db.into(db.attachments).insert(/*...*/);
      await db.into(db.inboxItems).insert(/*...*/);

      // Clear all
      await db.clearAll();

      // Verify all tables are empty
      final notes = await db.select(db.localNotes).get();
      final templates = await db.select(db.localTemplates).get();
      final attachments = await db.select(db.attachments).get();
      final inbox = await db.select(db.inboxItems).get();

      expect(notes, isEmpty);
      expect(templates, isEmpty);
      expect(attachments, isEmpty);
      expect(inbox, isEmpty);
    });

    test('Notes with wrong user_id are rejected', () async {
      // Mock different user IDs
      const currentUserId = 'user-a';
      const wrongUserId = 'user-b';

      // Create note with wrong user ID
      final wrongNote = LocalNotesCompanion(
        id: Value('note-1'),
        userId: Value(wrongUserId),
        // ... other fields
      );

      await db.into(db.localNotes).insert(wrongNote);

      // Attempt to hydrate should return null
      // and delete the invalid note
      // ... test hydration logic ...
    });
  });
}
```

## Deployment Checklist

1. **Before Deployment**:
   - [ ] Run full test suite
   - [ ] Test with 2 different user accounts
   - [ ] Verify all tables cleared on logout
   - [ ] Check Sentry for any security events

2. **Deployment Steps**:
   - [ ] Deploy to staging first
   - [ ] Test cross-user scenarios in staging
   - [ ] Monitor for 24 hours
   - [ ] Deploy to production with feature flag

3. **Post-Deployment**:
   - [ ] Monitor Sentry for security events
   - [ ] Check for "SECURITY:" log entries
   - [ ] Verify no cross-user data reports
   - [ ] Document any incidents

## Emergency Response Plan

If cross-user data is detected:

1. **Immediate Actions**:
   ```dart
   // Emergency cleanup function
   Future<void> emergencySecurityResponse() async {
     // 1. Log incident
     await Sentry.captureMessage('EMERGENCY: Cross-user data detected');

     // 2. Clear all local data
     await db.clearAll();

     // 3. Force re-authentication
     await Supabase.instance.client.auth.signOut();

     // 4. Show security notice to user
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (_) => AlertDialog(
         title: Text('Security Update'),
         content: Text('For your security, please sign in again.'),
         actions: [
           TextButton(
             onPressed: () => SystemNavigator.pop(),
             child: Text('OK'),
           ),
         ],
       ),
     );
   }
   ```

2. **Investigation**:
   - Check Sentry for details
   - Review sync logs
   - Identify affected users
   - Determine root cause

3. **Communication**:
   - Notify affected users
   - Update status page
   - Prepare incident report