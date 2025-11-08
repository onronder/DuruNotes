# COMPREHENSIVE ENCRYPTION FORMAT AUDIT REPORT

**Date**: 2025-10-23
**Critical Bug**: List<int> base64 string double-encoding
**Fixed In**: `SupabaseNoteApi.asBytes()` - Lines 303-394

---

## EXECUTIVE SUMMARY

We discovered a critical bug where Supabase returns bytea columns as `List<int>` containing **bytes of a base64 string**, not the actual encrypted bytes. The fix was to detect and decode base64 strings in `asBytes()`.

This audit identifies **ALL** other locations in the codebase with the same bug pattern.

---

## 1. ENCRYPTED ENTITIES INVENTORY

### 1.1 Notes ✅ FIXED
**Encrypted Columns**: `title_enc`, `props_enc`
**Table**: `notes`
**Status**: **PROTECTED** via `SupabaseNoteApi.asBytes()`

**Data Flow**:
```
Supabase → fetchEncryptedNotes() → asBytes() [FIXED] → CryptoBox → Decrypted
```

**Files**:
- `/lib/data/remote/supabase_note_api.dart:58-130` (fetchEncryptedNotes)
- `/lib/data/remote/supabase_note_api.dart:303-394` (asBytes - FIXED)
- `/lib/services/unified_sync_service.dart:1150-1309` (downloads notes)

**Fix Applied**: Lines 323-332 in `asBytes()` now detect and decode base64 strings.

---

### 1.2 Folders ✅ PROTECTED
**Encrypted Columns**: `name_enc`, `props_enc`
**Table**: `folders`
**Status**: **PROTECTED** via `SupabaseNoteApi.asBytes()`

**Data Flow**:
```
Supabase → fetchEncryptedFolders() → asBytes() [FIXED] → CryptoBox → Decrypted
```

**Files**:
- `/lib/services/sync/folder_remote_api.dart:98-147` (_decryptFolderRow)
  - **Line 113**: `data: SupabaseNoteApi.asBytes(nameEnc)` ✅
  - **Line 122**: `data: SupabaseNoteApi.asBytes(propsEnc)` ✅
- `/lib/services/unified_sync_service.dart:1738-1850` (folder sync)
  - **Line 1776**: `data: SupabaseNoteApi.asBytes(nameEnc)` ✅
  - **Line 1785**: `data: SupabaseNoteApi.asBytes(propsEnc)` ✅

**Assessment**: All folder decryption paths use `asBytes()`, so they're protected by the fix.

---

### 1.3 Templates ⚠️ POTENTIALLY VULNERABLE
**Encrypted Columns**: `title_enc`, `body_enc`, `tags_enc`, `description_enc`, `props_enc`
**Table**: `templates`
**Status**: **NEEDS INVESTIGATION**

**Data Flow**:
```
Supabase → fetchTemplates() → _decryptTemplateField() → utf8.encode() → CryptoBox
```

**Files**:
- `/lib/data/remote/supabase_note_api.dart:516-532` (fetchTemplates)
- `/lib/infrastructure/repositories/notes_core_repository.dart:500-515` (_decryptTemplateField)

**CRITICAL CODE** (Line 509):
```dart
Future<String?> _decryptTemplateField({
  String? encrypted,
  required String userId,
  required String templateId,
}) async {
  if (encrypted == null || encrypted.isEmpty) {
    return null;
  }

  // ⚠️ POTENTIAL BUG: If 'encrypted' is already a base64 string from Supabase,
  // this utf8.encode() will double-encode it!
  final data = Uint8List.fromList(utf8.encode(encrypted));
  return crypto.decryptStringForNote(
    userId: userId,
    noteId: templateId,
    data: data,
  );
}
```

**Problem**:
1. `fetchTemplates()` returns columns as `String?` (e.g., `remoteTemplate['title_enc']`)
2. If Supabase returns these as base64 strings, `utf8.encode(encrypted)` creates bytes of the base64 string
3. This is the EXACT same bug pattern as notes before the fix

**Usage** (Lines 1315-1350):
```dart
final title = await _decryptTemplateField(
  encrypted: remoteTemplate['title_enc'] as String?,  // ⚠️ May be base64
  userId: userId,
  templateId: templateId,
);
```

**Priority**: **HIGH**
**Risk**: If templates are stored/returned in the same format as notes, they have the same bug.

---

### 1.4 Tasks ✅ LOCAL ONLY
**Encrypted Columns**: `content_encrypted`, `notes_encrypted`, `labels_encrypted`
**Table**: `note_tasks` (local only)
**Status**: **NOT VULNERABLE** (reads from local DB, not Supabase directly)

**Data Flow**:
```
Local DB → utf8.encode() → CryptoBox → Decrypted
```

**Files**:
- `/lib/infrastructure/repositories/task_core_repository.dart:54-117` (_decryptTask)
  - **Lines 64-71**: Decrypt content
  - **Lines 81-88**: Decrypt notes
  - **Lines 98-105**: Decrypt labels
- `/lib/infrastructure/helpers/task_decryption_helper.dart:20-101`

**Code Pattern**:
```dart
final contentData = Uint8List.fromList(
  utf8.encode(localTask.contentEncrypted),  // ✅ From local DB
);
content = await crypto.decryptStringForNote(...);
```

**Assessment**: Safe because data comes from local SQLite, not Supabase bytea columns.

**Note**: Tasks ARE synced to Supabase via `note_tasks` table, but when pulling from remote:
- `/lib/infrastructure/repositories/notes_core_repository.dart:1160-1287` (_applyRemoteTask)
- This encrypts local data and stores it, doesn't fetch encrypted data from Supabase

---

### 1.5 Inbox Items ✅ NOT ENCRYPTED
**Table**: `clipper_inbox`
**Status**: **NOT APPLICABLE** (no encryption)

**Reason**: Inbox items are temporary and not encrypted. They're converted to encrypted notes.

**Files**:
- `/lib/infrastructure/repositories/inbox_repository.dart`

**Assessment**: No encryption vulnerability.

---

### 1.6 Attachments ⚠️ NOT IMPLEMENTED
**Status**: **FEATURE NOT IMPLEMENTED**

**Files**:
- `/lib/infrastructure/repositories/attachment_repository.dart:6-20`
  ```dart
  /// DEPRECATED: Attachments feature not yet implemented in database schema.
  @Deprecated('Attachments table does not exist in schema')
  class AttachmentRepository implements IAttachmentRepository {
  ```

**Assessment**: When implemented, must use `asBytes()` pattern.

---

### 1.7 Saved Searches ✅ LOCAL ONLY
**Table**: `saved_searches` (local only)
**Status**: **NOT VULNERABLE** (local storage, no Supabase sync)

**Files**:
- `/lib/infrastructure/repositories/search_repository.dart`

**Assessment**: Saved searches are stored locally and not encrypted.

---

## 2. CRYPTO_BOX HELPERS

### 2.1 CryptoBox._deserializeSecretBox() ✅ SAFE
**File**: `/lib/core/crypto/crypto_box.dart:420-478`

**Code**:
```dart
Uint8List? _deserializeSecretBox(dynamic value) {
  if (value is Uint8List) {
    return value;
  }

  if (value is List<int>) {
    return Uint8List.fromList(value);  // ✅ Direct conversion
  }

  if (value is String) {
    try {
      return Uint8List.fromList(base64Decode(trimmed));  // ✅ Decodes base64
    } on FormatException catch (_) {
      rethrow;
    }
  }
}
```

**Assessment**: This helper is safe because:
1. It only receives data AFTER `asBytes()` processing
2. It handles base64 strings correctly
3. It's not the entry point for Supabase data

---

## 3. POTENTIAL ISSUES FOUND

### Issue #1: Template Decryption 🔴 HIGH PRIORITY

**Location**: `/lib/infrastructure/repositories/notes_core_repository.dart:500-515`

**Current Code**:
```dart
Future<String?> _decryptTemplateField({
  String? encrypted,
  required String userId,
  required String templateId,
}) async {
  if (encrypted == null || encrypted.isEmpty) {
    return null;
  }

  // ⚠️ BUG: If 'encrypted' is a base64 string, this double-encodes
  final data = Uint8List.fromList(utf8.encode(encrypted));
  return crypto.decryptStringForNote(
    userId: userId,
    noteId: templateId,
    data: data,
  );
}
```

**Required Fix**:
```dart
Future<String?> _decryptTemplateField({
  String? encrypted,
  required String userId,
  required String templateId,
}) async {
  if (encrypted == null || encrypted.isEmpty) {
    return null;
  }

  // FIX: Use asBytes() to handle base64-encoded data from Supabase
  final data = SupabaseNoteApi.asBytes(encrypted);
  return crypto.decryptStringForNote(
    userId: userId,
    noteId: templateId,
    data: data,
  );
}
```

**Impact**:
- Affects: template title, body, tags, description, props
- Severity: HIGH (templates may fail to decrypt)
- Priority: CRITICAL

**Testing Required**:
1. Fetch template from Supabase
2. Check format of `title_enc`, `body_enc`, etc.
3. Verify they're base64 strings (like notes)
4. Test decryption with current code
5. Apply fix if decryption fails

---

### Issue #2: Unified Sync Service (Already Fixed) ✅

**Location**: `/lib/services/unified_sync_service.dart:1190-1309`

**Status**: Already casts to `Uint8List` before decryption:
```dart
final titleEnc = note['title_enc'] as Uint8List;  // ✅ Type cast
final propsEnc = note['props_enc'] as Uint8List;  // ✅ Type cast
```

**Assessment**: Safe because it receives data through `fetchEncryptedNotes()` which processes via `asBytes()`.

---

### Issue #3: Future Attachment Implementation ⚠️ REMINDER

When implementing attachments, ensure ALL Supabase fetches use `asBytes()`:

```dart
// ❌ WRONG (future code)
final data = Uint8List.fromList(utf8.encode(encrypted));

// ✅ CORRECT (future code)
final data = SupabaseNoteApi.asBytes(encrypted);
```

---

## 4. SEARCH PATTERNS FOR FUTURE AUDITS

### 4.1 Vulnerable Patterns to Search For

**Pattern 1**: Direct utf8.encode on Supabase data
```bash
grep -r "utf8\.encode.*\['.*_enc" lib/
```

**Pattern 2**: Uint8List.fromList without asBytes()
```bash
grep -r "Uint8List\.fromList.*_enc" lib/
```

**Pattern 3**: Missing asBytes() on fetch methods
```bash
grep -r "fetch.*Encrypted" lib/ | grep -v "asBytes"
```

---

## 5. SUMMARY OF FINDINGS

| Entity | Status | Priority | Action Required |
|--------|--------|----------|-----------------|
| Notes | ✅ FIXED | N/A | Monitor for regressions |
| Folders | ✅ PROTECTED | N/A | Uses asBytes() |
| Templates | ⚠️ VULNERABLE | 🔴 CRITICAL | Apply fix to _decryptTemplateField() |
| Tasks | ✅ SAFE | N/A | Local DB only |
| Inbox Items | ✅ N/A | N/A | Not encrypted |
| Attachments | ⚠️ NOT IMPL | 🟡 MEDIUM | Implement with asBytes() |
| Saved Searches | ✅ SAFE | N/A | Local only |

---

## 6. RECOMMENDED ACTIONS

### Immediate (Next 24 Hours)
1. ✅ **DONE**: Fix notes via `asBytes()` base64 detection
2. 🔴 **TODO**: Test template decryption in production
3. 🔴 **TODO**: Apply fix to `_decryptTemplateField()` if templates fail

### Short-term (This Week)
1. Add integration tests for all encrypted entity types
2. Document encryption format expectations in code comments
3. Create encryption format validation utility
4. Add Sentry alerts for decryption failures

### Long-term (This Month)
1. Standardize all Supabase fetch operations through `asBytes()`
2. Create encryption helper class with consistent API
3. Add type-safe encryption/decryption wrappers
4. Implement encryption format migration utility

---

## 7. TESTING CHECKLIST

### Template Testing (HIGH PRIORITY)
- [ ] Fetch template from Supabase
- [ ] Log raw format of `title_enc` column
- [ ] Check if it's a base64 string or List<int>
- [ ] Test current decryption (expect failure if base64)
- [ ] Apply fix to `_decryptTemplateField()`
- [ ] Re-test decryption (expect success)
- [ ] Verify all template fields decrypt correctly

### Regression Testing
- [ ] Notes continue to decrypt correctly
- [ ] Folders continue to sync correctly
- [ ] Tasks encrypt/decrypt correctly
- [ ] Import/export preserves encryption
- [ ] Sync maintains data integrity

---

## 8. CODE QUALITY IMPROVEMENTS

### Add Type Safety
```dart
// Instead of dynamic 'encrypted' parameter
Future<String?> _decryptTemplateField({
  String? encrypted,  // ❌ Ambiguous type
  ...
}) async {

// Use explicit types with asBytes()
Future<String?> _decryptTemplateField({
  dynamic encryptedData,  // ✅ Clear it's raw Supabase data
  required String userId,
  required String templateId,
}) async {
  if (encryptedData == null) return null;
  final data = SupabaseNoteApi.asBytes(encryptedData);  // ✅ Explicit conversion
  return crypto.decryptStringForNote(...);
}
```

### Add Documentation
```dart
/// Decrypt a template field from Supabase.
///
/// IMPORTANT: Template encrypted columns come from Supabase as either:
/// - `List<int>` containing bytes of a base64 string (most common)
/// - `String` containing base64-encoded data
/// - `Uint8List` containing raw bytes
///
/// Always use `SupabaseNoteApi.asBytes()` to normalize the format.
Future<String?> _decryptTemplateField({
  dynamic encryptedData,
  required String userId,
  required String templateId,
}) async {
```

---

## 9. PREVENTION STRATEGIES

### 9.1 Code Review Checklist
When adding new encrypted entities:
- [ ] Does it fetch from Supabase?
- [ ] Does it use `asBytes()` for format conversion?
- [ ] Does it handle base64 strings correctly?
- [ ] Are there integration tests?
- [ ] Is error handling comprehensive?

### 9.2 Linting Rules (Future)
Create custom lint rules to detect:
```dart
// ❌ Flag this pattern
utf8.encode(supabaseData['*_enc'])

// ✅ Suggest this instead
SupabaseNoteApi.asBytes(supabaseData['*_enc'])
```

---

## 10. CONCLUSION

**Critical Finding**: Templates likely have the same bug as notes had before the fix.

**Action Items**:
1. **URGENT**: Test template decryption in production
2. **URGENT**: Apply `asBytes()` fix to `_decryptTemplateField()` if needed
3. Monitor for other encrypted entities (future attachments)
4. Standardize encryption handling across the codebase

**Risk Assessment**:
- **High**: Template decryption may be broken in production
- **Medium**: Future encrypted entities may repeat the pattern
- **Low**: Notes and folders are now protected

---

**Report Generated**: 2025-10-23
**Next Audit**: After template fix is deployed
**Signed**: Claude (AI Code Auditor)
