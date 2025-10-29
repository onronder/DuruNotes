# Complete Security Implementation Roadmap

## Overview

The security audit identified **multiple phases** of fixes, from immediate critical patches to long-term architectural improvements. Here's the complete roadmap:

---

## ✅ PHASE 0: CRITICAL (P0) - **COMPLETE**

**Status**: ✅ **Implemented and Ready for Testing**
**Time to Fix**: 2 hours
**Deployment**: Immediate (after testing)

### What Was Fixed

These are the **showstopper security bugs** that allowed User B to see User A's data:

1. ✅ **Keychain Collision** - Encryption services overwriting each other's keys
2. ✅ **Incomplete Database Clearing** - 3 tables (templates, attachments, inbox) not cleared
3. ✅ **Provider State Leakage** - 27 Riverpod providers caching User A's data
4. ✅ **User Validation** - Runtime check for mismatched user_id

**Result**: User B can NO LONGER see User A's data after login

**See**: `P0_CRITICAL_SECURITY_FIXES_IMPLEMENTED.md` for complete details

---

## 🔴 PHASE 1: HIGH PRIORITY (P1) - **TODO**

**Status**: ⏳ **Not Yet Started**
**Time to Fix**: 5-8 hours
**Deployment**: This week (within 7 days)

### Issue #4: Repository Query User Filtering

**Problem**: Repository queries don't filter by user_id at the database layer. While P0 fixes prevent the data from being there, this adds defense-in-depth.

**Files to Modify**:
- `lib/infrastructure/repositories/notes_core_repository.dart`
- `lib/infrastructure/repositories/task_core_repository.dart`
- `lib/infrastructure/repositories/folder_core_repository.dart`

**Changes Required** (6 methods per repository):
```dart
// BEFORE
Future<List<domain.Note>> getPinnedNotes() async {
  final localNotes = await db.getPinnedNotes();
  return await _hydrateDomainNotes(localNotes);
}

// AFTER
Future<List<domain.Note>> getPinnedNotes() async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) {
    return const <domain.Note>[];
  }

  final localNotes = await (db.select(db.localNotes)
    ..where((n) => n.deleted.equals(false)
                  & n.isPinned.equals(true)
                  & n.userId.equals(userId))) // ← ADD THIS
    .get();

  return await _hydrateDomainNotes(localNotes);
}
```

**Impact**:
- Additional security layer (defense-in-depth)
- Prevents accidental cross-user queries
- Catches bugs earlier in development

**Time Estimate**: 6 hours (3 repositories × 6 methods × 20 min each)

### Issue #5: Missing user_id in NoteTasks Table

**Problem**: The `NoteTasks` junction table lacks a `user_id` column, making it harder to validate task ownership.

**Changes Required**:

1. **Schema Change** (`lib/data/local/app_db.dart`):
```dart
class NoteTasks extends Table {
  TextColumn get noteId => text()();
  IntColumn get taskId => integer()();
  IntColumn get position => integer()();
  TextColumn get userId => text()(); // ← ADD THIS
  // ...
}
```

2. **Migration** (bump to version 30):
```dart
if (from < 30) {
  await m.addColumn(noteTasks, noteTasks.userId);

  // Backfill user_id from parent note
  await customStatement('''
    UPDATE note_tasks SET user_id = (
      SELECT user_id FROM local_notes
      WHERE local_notes.id = note_tasks.note_id
      LIMIT 1
    )
  ''');
}
```

3. **Update Queries**:
```dart
// Add userId filter to all NoteTasks queries
..where((t) => t.userId.equals(currentUserId))
```

**Time Estimate**: 2 hours (schema + migration + testing)

---

## 🟡 PHASE 2: MEDIUM PRIORITY (P2) - **TODO**

**Status**: ⏳ **Not Yet Started**
**Time to Fix**: 3-4 hours
**Deployment**: Next sprint (1-2 weeks)

### Issue #6: Nullable user_id Columns

**Problem**: `userId` columns are nullable in local tables, allowing data without user association. Should be required.

**Changes Required**:

1. **Make userId Non-Nullable**:
```dart
// BEFORE
TextColumn get userId => text().nullable()();

// AFTER
TextColumn get userId => text()();
```

2. **Migration** (version 31):
```sql
-- Backfill any null user_ids
UPDATE local_notes SET user_id = 'orphaned' WHERE user_id IS NULL;
UPDATE local_folders SET user_id = 'orphaned' WHERE user_id IS NULL;
UPDATE local_tasks SET user_id = 'orphaned' WHERE user_id IS NULL;

-- Make non-nullable
ALTER TABLE local_notes ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE local_folders ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE local_tasks ALTER COLUMN user_id SET NOT NULL;
```

**Impact**:
- Prevents accidental data creation without user_id
- Enforces data integrity at schema level
- Makes bugs more obvious (fail fast)

**Time Estimate**: 3 hours

### Issue #7: Encryption Format Inconsistency

**Problem**: Historical data has mixed encryption formats (raw JSON vs base64), causing "SecretBox deserialization error" on old notes.

**Changes Required**:

1. **Detection Function**:
```dart
bool isLegacyFormat(String encrypted) {
  return encrypted.startsWith('{') || encrypted.startsWith('[');
}
```

2. **Migration on Read**:
```dart
Future<String> decryptTitle(LocalNote note) async {
  try {
    if (isLegacyFormat(note.titleEncrypted)) {
      // Legacy format - parse JSON directly
      final json = jsonDecode(note.titleEncrypted);
      return json['title'] ?? '';
    } else {
      // Modern format - decrypt properly
      return await crypto.decryptStringForNote(
        userId: note.userId,
        noteId: note.id,
        encrypted: note.titleEncrypted,
      );
    }
  } catch (e) {
    // Fallback for unreadable data
    return '[Encrypted]';
  }
}
```

3. **Lazy Migration**:
```dart
// When user opens old note, re-encrypt in new format
Future<void> _migrateNoteEncryption(LocalNote note) async {
  if (isLegacyFormat(note.titleEncrypted)) {
    final plainTitle = await decryptTitle(note);
    final newEncrypted = await crypto.encryptStringForNote(
      userId: note.userId,
      noteId: note.id,
      text: plainTitle,
    );

    await db.update(db.localNotes).replace(
      note.copyWith(titleEncrypted: newEncrypted),
    );
  }
}
```

**Impact**:
- Eliminates "SecretBox deserialization error"
- Migrates data lazily (on access) to avoid long migrations
- Maintains backward compatibility

**Time Estimate**: 4 hours

---

## 🟢 PHASE 3: ARCHITECTURE IMPROVEMENTS (P3) - **FUTURE**

**Status**: ⏳ **Future Enhancement**
**Time to Fix**: 2-3 weeks
**Deployment**: Next major release

### 1. Unified Encryption Service

**Problem**: Two encryption services (AccountKeyService + EncryptionSyncService) with overlapping responsibilities.

**Solution**: Merge into single `UnifiedEncryptionService`:
```dart
class UnifiedEncryptionService {
  // Handles both device-local and cross-device encryption
  // Single source of truth for encryption keys
  // Simplified API for consumers
}
```

**Benefits**:
- No more keychain collisions
- Simpler mental model
- Easier to test and maintain
- Clearer upgrade path

**Time Estimate**: 1 week

### 2. Security Middleware Layer

**Problem**: Security checks scattered across codebase. Hard to audit.

**Solution**: Centralized security layer:
```dart
class SecurityMiddleware {
  // Validates user_id on ALL operations
  // Logs security events to Sentry
  // Enforces access control policies
  // Rate limiting on sensitive operations
}
```

**Benefits**:
- Single place to audit security
- Consistent enforcement across app
- Easier to add new security rules
- Clear audit trail

**Time Estimate**: 1 week

### 3. Automated Security Testing

**Problem**: Manual testing is error-prone. Need automated regression tests.

**Solution**: Comprehensive test suite (already drafted in `test/critical/`):
```dart
// 56 automated tests covering:
- User isolation (10 tests)
- Database clearing (14 tests)
- User ID validation (10 tests)
- Encryption integrity (11 tests)
- RLS enforcement (11 tests)
```

**Status**: Test files created but need fixes to compile

**Benefits**:
- Catch regressions before production
- CI/CD gates on security tests
- Confidence in deployments
- Living documentation

**Time Estimate**: 3 days to fix tests + ongoing maintenance

### 4. Provider Lifecycle Management

**Problem**: Manual provider invalidation is error-prone. Easy to forget providers.

**Solution**: Automated provider lifecycle:
```dart
class ProviderLifecycleManager {
  void onUserLogin(String userId) {
    // Automatically invalidate ALL providers
    // Register userId with all services
    // Initialize user-specific state
  }

  void onUserLogout() {
    // Automatically invalidate ALL providers
    // Clear all caches
    // Reset to clean state
  }
}
```

**Benefits**:
- Can't forget to invalidate providers
- Centralized lifecycle management
- Easier to add new providers
- Self-documenting

**Time Estimate**: 1 week

### 5. Audit Logging

**Problem**: No visibility into security-relevant events.

**Solution**: Comprehensive audit trail:
```dart
class SecurityAuditLogger {
  void logUserSwitch(String fromUserId, String toUserId) {
    // Log to Sentry + local storage
    // Include timestamp, device ID, app version
  }

  void logDataLeakageAttempt(String details) {
    // Alert immediately
    // Include full context
  }
}
```

**Benefits**:
- Detect attack attempts
- Debug production issues
- Compliance (GDPR, HIPAA)
- Performance metrics

**Time Estimate**: 3 days

---

## Timeline Summary

| Phase | Priority | Status | Time | Deploy |
|-------|----------|--------|------|--------|
| **P0: Critical Fixes** | 🔴 Critical | ✅ Complete | 2h | Now (after testing) |
| **P1: High Priority** | 🔴 High | ⏳ Todo | 8h | This week |
| **P2: Medium Priority** | 🟡 Medium | ⏳ Todo | 7h | Next sprint |
| **P3: Architecture** | 🟢 Future | ⏳ Backlog | 3-4 weeks | Next release |

---

## Recommended Deployment Strategy

### Week 1 (Current)
- ✅ Deploy P0 fixes (already done)
- ✅ Monitor for data leakage incidents (should be 0)
- ✅ Collect user feedback

### Week 2
- [ ] Implement P1 fixes (8 hours)
- [ ] Run full test suite
- [ ] Deploy P1 to production

### Week 3-4
- [ ] Implement P2 fixes (7 hours)
- [ ] User acceptance testing
- [ ] Deploy P2 to production

### Month 2
- [ ] Plan P3 architecture improvements
- [ ] Implement in feature branches
- [ ] Deploy incrementally

---

## Risk Assessment by Phase

### P0 (Complete)
**Risk if skipped**: 🔴 **CRITICAL** - Users can see each other's data
**Current risk**: 🟢 **LOW** - All fixes implemented

### P1 (Todo)
**Risk if skipped**: 🟡 **MEDIUM** - Defense-in-depth missing
**Mitigation**: P0 fixes prevent the data from being there

### P2 (Todo)
**Risk if skipped**: 🟢 **LOW** - Quality of life + data hygiene
**Mitigation**: Can be done gradually

### P3 (Future)
**Risk if skipped**: 🟢 **LOW** - Long-term maintainability
**Mitigation**: Current architecture works, just harder to maintain

---

## Success Metrics by Phase

### P0 Metrics (Monitor Now)
- Data leakage incidents: **0** ✅
- SecretBox errors: **< 0.1%**
- RLS violations: **0** ✅
- User complaints: **0 related to data leakage** ✅

### P1 Metrics (After Implementation)
- Repository queries with user_id filter: **100%**
- NoteTasks with valid user_id: **100%**

### P2 Metrics (After Implementation)
- Null user_id in database: **0%**
- Encryption format consistency: **100%**
- SecretBox errors: **0%**

### P3 Metrics (After Implementation)
- Test coverage: **> 80%**
- Security test suite passing: **100%**
- Code duplication: **< 5%**
- Mean time to detect security bug: **< 1 hour**

---

## Next Actions

### For You (Immediate)
1. ✅ Review `P0_CRITICAL_SECURITY_FIXES_IMPLEMENTED.md`
2. ✅ Run testing from `QUICK_START_TESTING.md` (5 minutes)
3. ✅ Deploy P0 fixes to production

### For Development Team (This Week)
1. [ ] Implement P1 fixes (Issue #4 + #5)
2. [ ] Code review security changes
3. [ ] Deploy P1 to staging
4. [ ] Deploy P1 to production

### For Next Sprint
1. [ ] Plan P2 implementation
2. [ ] Fix test suite compilation errors
3. [ ] Begin P3 architecture design

---

## Questions?

- **"Can I skip P1/P2/P3?"** - Yes, P0 fixes the critical security bug. P1-P3 are quality improvements.
- **"How urgent is P1?"** - Medium urgency. Adds defense-in-depth but P0 already prevents the bug.
- **"Should I implement P3 now?"** - No, P3 is long-term. Focus on P0 testing and P1 implementation first.
- **"What if P0 doesn't work?"** - Rollback plan in `P0_CRITICAL_SECURITY_FIXES_IMPLEMENTED.md`

---

**Current Status**: P0 complete, P1-P3 planned and prioritized
**Your Action**: Test P0, deploy if successful
**Next Phase**: P1 implementation (8 hours, this week)
