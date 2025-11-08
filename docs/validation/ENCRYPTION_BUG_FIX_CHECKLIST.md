# ENCRYPTION BUG FIX CHECKLIST

**Critical Issue**: Supabase returns bytea as List<int> of base64 string bytes, not raw encrypted bytes.

---

## QUICK REFERENCE

### ✅ FIXED
- **Notes**: Uses `SupabaseNoteApi.asBytes()` with base64 detection (Lines 323-332)
- **Folders**: Uses `SupabaseNoteApi.asBytes()` in folder_remote_api.dart (Lines 113, 122)

### 🔴 HIGH PRIORITY - NEEDS FIX
- **Templates**: Uses `utf8.encode()` directly → MUST use `asBytes()` instead

### ✅ SAFE (Local Only)
- **Tasks**: Reads from local DB, not Supabase
- **Saved Searches**: Local storage only
- **Inbox Items**: Not encrypted

### ⚠️ FUTURE
- **Attachments**: Not implemented yet - MUST use `asBytes()` when implemented

---

## THE FIX (Already Applied to Notes)

**File**: `/lib/data/remote/supabase_note_api.dart`
**Lines**: 323-332

```dart
// NEW: Detect and decode base64 strings
if (_isBase64String(str)) {
  try {
    return base64Decode(str);
  } on FormatException {
    // Not valid base64, return original bytes
    return bytes;
  }
}
```

---

## TEMPLATE FIX REQUIRED

**File**: `/lib/infrastructure/repositories/notes_core_repository.dart`
**Function**: `_decryptTemplateField()` (Line 500)

### Before (BROKEN):
```dart
Future<String?> _decryptTemplateField({
  String? encrypted,
  required String userId,
  required String templateId,
}) async {
  if (encrypted == null || encrypted.isEmpty) {
    return null;
  }

  // ❌ BUG: Double-encodes base64 strings
  final data = Uint8List.fromList(utf8.encode(encrypted));
  return crypto.decryptStringForNote(
    userId: userId,
    noteId: templateId,
    data: data,
  );
}
```

### After (FIXED):
```dart
Future<String?> _decryptTemplateField({
  String? encrypted,
  required String userId,
  required String templateId,
}) async {
  if (encrypted == null || encrypted.isEmpty) {
    return null;
  }

  // ✅ FIX: Use asBytes() to handle base64-encoded data
  final data = SupabaseNoteApi.asBytes(encrypted);
  return crypto.decryptStringForNote(
    userId: userId,
    noteId: templateId,
    data: data,
  );
}
```

---

## TESTING STEPS

### 1. Verify Templates are Broken (Expected)
```bash
# Run app and try to load a template
# Check logs for decryption errors
```

### 2. Apply Fix
```bash
# Edit: lib/infrastructure/repositories/notes_core_repository.dart
# Line 509: Replace utf8.encode() with SupabaseNoteApi.asBytes()
```

### 3. Test Fix
```bash
# Run app and verify templates load correctly
# Check all template fields (title, body, tags, description)
```

---

## FILES TO REVIEW

### Critical Files (Need Changes)
- `/lib/infrastructure/repositories/notes_core_repository.dart:500-515` 🔴
  - Function: `_decryptTemplateField()`
  - Action: Replace `utf8.encode()` with `SupabaseNoteApi.asBytes()`

### Protected Files (Already Fixed)
- `/lib/data/remote/supabase_note_api.dart:303-394` ✅
  - Function: `asBytes()`
  - Status: Fixed with base64 detection

- `/lib/services/sync/folder_remote_api.dart:98-147` ✅
  - Function: `_decryptFolderRow()`
  - Status: Uses `asBytes()` on lines 113, 122

### Safe Files (No Changes Needed)
- `/lib/infrastructure/repositories/task_core_repository.dart:54-117` ✅
  - Local DB only, not vulnerable

- `/lib/infrastructure/repositories/inbox_repository.dart` ✅
  - Not encrypted

- `/lib/infrastructure/repositories/search_repository.dart` ✅
  - Local only

---

## IMPACT ASSESSMENT

### Notes ✅
- **Before Fix**: Decryption failures in production
- **After Fix**: Working correctly
- **Confidence**: 100%

### Folders ✅
- **Status**: Protected by using `asBytes()`
- **Risk**: Low (already protected)
- **Confidence**: 100%

### Templates 🔴
- **Current Status**: Likely broken (uses `utf8.encode()`)
- **Risk**: HIGH
- **Impact**: Templates fail to load/decrypt
- **Fix Required**: YES - Replace with `asBytes()`
- **Confidence**: 90% this is broken

### Tasks ✅
- **Status**: Safe (local DB only)
- **Risk**: None
- **Confidence**: 100%

---

## SEARCH COMMANDS

### Find Potential Issues
```bash
# Search for utf8.encode on encrypted columns
grep -rn "utf8\.encode.*\['.*_enc" lib/

# Search for Uint8List.fromList without asBytes()
grep -rn "Uint8List\.fromList.*utf8\.encode" lib/

# Find all encrypted column references
grep -rn "_enc\>" lib/ --include="*.dart"
```

### Verify asBytes() Usage
```bash
# Check all uses of asBytes()
grep -rn "asBytes(" lib/ --include="*.dart"

# Expected results:
# - folder_remote_api.dart (2 uses) ✅
# - unified_sync_service.dart (2 uses) ✅
# - supabase_note_api.dart (definition + internal uses) ✅
```

---

## ROLLOUT PLAN

### Phase 1: Testing (Now)
1. Test template loading in production/staging
2. Check logs for decryption errors
3. Verify the format of template encrypted data

### Phase 2: Fix (If Broken)
1. Apply fix to `_decryptTemplateField()`
2. Add import: `import 'package:duru_notes/data/remote/supabase_note_api.dart';`
3. Test locally with real Supabase data

### Phase 3: Deploy
1. Run full test suite
2. Deploy to staging
3. Monitor Sentry for decryption errors
4. Deploy to production
5. Monitor for 24-48 hours

### Phase 4: Verify
1. Test template creation
2. Test template editing
3. Test template deletion
4. Verify sync works correctly
5. Check all template fields decrypt properly

---

## SENTRY MONITORING

### Alerts to Watch
```
decryptStringForNote failure
decryptJsonForNote failure
_decryptTemplateField error
FormatException: Invalid character
```

### Expected After Fix
- Decryption error rate should drop to ~0%
- Template load success rate should increase to ~100%
- No FormatException errors related to encryption

---

## SUCCESS CRITERIA

### Templates Fixed When:
- [ ] Templates load without decryption errors
- [ ] All fields decrypt correctly (title, body, tags, description)
- [ ] No FormatException in logs
- [ ] Sentry shows 0 template decryption errors
- [ ] Users can create/edit/view templates normally

### Regression Tests Pass When:
- [ ] Notes continue to work (already fixed)
- [ ] Folders continue to work (already protected)
- [ ] Tasks continue to work (local only)
- [ ] Sync maintains data integrity
- [ ] No new decryption errors appear

---

## CONTACT

If decryption errors persist after fix:
1. Check Supabase data format in production
2. Verify `asBytes()` is being called
3. Add debug logging to trace data format
4. Check if there are other code paths fetching templates

---

**Last Updated**: 2025-10-23
**Status**: Template fix pending verification and deployment
