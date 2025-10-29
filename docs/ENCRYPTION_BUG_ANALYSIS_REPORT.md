# CRITICAL ENCRYPTION BUG ANALYSIS REPORT
**Date**: October 23, 2025
**Severity**: CRITICAL
**Issue**: SecretBox deserialization errors after folder move operations

---

## EXECUTIVE SUMMARY

**Root Cause**: Data format mismatch in the encryption/decryption pipeline. Supabase returns `bytea` columns as **base64-encoded strings**, but the decryption code path receives these as UTF-8 bytes of the base64 string instead of the decoded binary data.

**Impact**: Notes become "Untitled (Decryption Failed)" after sync operations.

---

## 1. COMPLETE LIST OF DECRYPTION CALL SITES

### Primary Decryption Methods (crypto_box.dart)
| Method | File | Lines | Purpose |
|--------|------|-------|---------|
| `decryptStringForNote()` | `/lib/core/crypto/crypto_box.dart` | 81-89 | Decrypt plain text fields |
| `decryptJsonForNote()` | `/lib/core/crypto/crypto_box.dart` | 37-66 | Decrypt JSON objects |
| `decryptStringForNoteWithFallback()` | `/lib/core/crypto/crypto_box.dart` | 127-150 | Fallback with legacy key |
| `decryptJsonForNoteWithFallback()` | `/lib/core/crypto/crypto_box.dart` | 92-124 | Fallback with legacy key |
| `_deserializeSecretBox()` | `/lib/core/crypto/crypto_box.dart` | 207-291 | **CRITICAL** - Parse encrypted data structure |

### Repository Layer (Direct Calls)
| File | Lines | Method | What it Decrypts |
|------|-------|--------|------------------|
| `notes_core_repository.dart` | 129, 144 | `decryptStringForNote()` | Note title, body (local DB) |
| `notes_core_repository.dart` | 405, 422, 510 | `decryptStringForNote()` | Note content queries |
| `notes_core_repository.dart` | 966, 974 | `decryptJsonForNote()` | Supabase sync data |
| `notes_core_repository.dart` | 1105, 1113 | `decryptJsonForNote()` | Folder name/props |
| `task_core_repository.dart` | 67, 84, 101 | `decryptStringForNote()` | Task content, notes, labels |

### Sync Service Layer (CRITICAL - Where Bug Occurs)
| File | Lines | Method | What it Decrypts |
|------|-------|--------|------------------|
| `unified_sync_service.dart` | **1198-1242** | `decryptStringForNote()` | **🔴 NOTE TITLES FROM SUPABASE** |
| `unified_sync_service.dart` | **1252-1289** | `decryptJsonForNote()` | **🔴 NOTE PROPS FROM SUPABASE** |
| `unified_sync_service.dart` | 1773, 1782 | `decryptJsonForNote()` | Folder sync data |

### Helper Layer
| File | Lines | Method | What it Decrypts |
|------|-------|--------|------------------|
| `note_decryption_helper.dart` | 33, 61 | `decryptStringForNote()` | Note fields |
| `task_decryption_helper.dart` | 33, 62, 91 | `decryptJsonForNote()` | Task JSON fields |

### Folder Sync
| File | Lines | Method | What it Decrypts |
|------|-------|--------|------------------|
| `folder_remote_api.dart` | 110, 119 | `decryptJsonForNote()` | Folder name/props |

---

## 2. DATA FORMAT MISMATCH - ROOT CAUSE

### The Problem Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ WRITE PATH (Encryption → Supabase)                              │
├─────────────────────────────────────────────────────────────────┤
│ 1. notes_core_repository.dart:1496                              │
│    └→ crypto.encryptStringForNote(text: "Hello World")         │
│                                                                  │
│ 2. crypto_box.dart:68-78                                        │
│    └→ _serializeSecretBox() returns Uint8List                  │
│                                                                  │
│ 3. crypto_box.dart:198-204 [_serializeSecretBox()]             │
│    ┌──────────────────────────────────────────────────┐        │
│    │ map = {"n": "base64nonce",                       │        │
│    │        "c": "base64cipher",                      │        │
│    │        "m": "base64mac"}                         │        │
│    │ return Uint8List.fromList(utf8.encode(          │        │
│    │   jsonEncode(map)))                              │        │
│    └──────────────────────────────────────────────────┘        │
│    Result: UTF-8 bytes of JSON string                          │
│                                                                  │
│ 4. notes_core_repository.dart:1510                              │
│    └→ utf8.decode(titleEncryptedBytes)                         │
│    Result: Stored locally as STRING                             │
│                                                                  │
│ 5. For SYNC: unified_sync_service.dart:1863                     │
│    └→ encryptJsonForNote(json: {"title": "Hello"})             │
│    Result: Uint8List with DOUBLE JSON wrapping!                │
│                                                                  │
│ 6. supabase_note_api.dart:44                                    │
│    └→ Upload titleEnc as bytea column                          │
│    Postgres stores: BINARY data (Uint8List bytes)              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ READ PATH (Supabase → Decryption) - WHERE BUG OCCURS           │
├─────────────────────────────────────────────────────────────────┤
│ 1. supabase_note_api.dart:58-82 [fetchEncryptedNotes()]        │
│    └→ SELECT title_enc FROM notes                              │
│    ⚠️  Supabase Dart client returns bytea as:                   │
│        **BASE64-ENCODED STRING**                                │
│    Actual return: "eyJuIjoieHYxdEUxWFM5a2hF..."                │
│                                                                  │
│ 2. supabase_note_api.dart:79                                    │
│    └→ m['title_enc'] = asBytes(t)                              │
│                                                                  │
│ 3. supabase_note_api.dart:303-360 [asBytes()]                  │
│    Line 354: return base64Decode(v)                            │
│    ✅ Should decode: "eyJu..." → bytes of JSON                  │
│    Result: Uint8List [123, 34, 110, 34, 58, ...]              │
│           = UTF-8 bytes of '{"n":"...", "c":"...", "m":"..."}'  │
│                                                                  │
│ 4. unified_sync_service.dart:1190                               │
│    └→ titleEnc = note['title_enc'] as Uint8List               │
│                                                                  │
│ 5. unified_sync_service.dart:1198                               │
│    └→ title = await _cryptoBox!.decryptStringForNote(          │
│         userId: userId, noteId: noteId, data: titleEnc)        │
│                                                                  │
│ 6. crypto_box.dart:86 [decryptStringForNote()]                 │
│    └→ final sb = _deserializeSecretBox(data)                  │
│                                                                  │
│ 7. 🔴 crypto_box.dart:207-291 [_deserializeSecretBox()] 🔴      │
│    Line 214: jsonString = utf8.decode(data)                    │
│    Expected: '{"n":"...", "c":"...", "m":"..."}'               │
│    ❌ ACTUAL: "eyJuIjoieHYxdEUxWFM5a2hF..." (BASE64!)          │
│                                                                  │
│    Line 223: final decoded = jsonDecode(jsonString)            │
│    ❌ FAILS: Can't parse base64 as JSON                        │
│    Error: "FormatException: Unexpected character (at char 1)"  │
│                                                                  │
│    Raw data: [101, 121, 74, 117, 73, 106, 111, 105...]        │
│    = UTF-8 bytes of "eyJu..." = BASE64 STRING                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why asBytes() is NOT Working

**The Issue**: The error shows `_deserializeSecretBox()` receives base64 string bytes `[101, 121, 74...]` = "eyJu..."

This means **one of two things**:
1. `asBytes()` is NOT being called for some data paths
2. OR the data format returned by Supabase has changed between write and read
3. OR there's a code path that bypasses `asBytes()`

**Evidence from Error Log**:
```
Raw data sample: [101, 121, 74, 117, 73, 106, 111, 105...]
```
These bytes decode to: `"eyJuIjoieHYxdEUxWFM5a2hFVWpnMXJIMGFtQ2NxakR0ZnNiL1QiLCJjIjoiRUo1TmhuWlciLCJ..."`

This is **NOT** the expected format. It should be UTF-8 bytes of JSON: `{"n":"...", "c":"...", "m":"..."}`

---

## 3. COMPLETE ENCRYPTION FLOW TRACE

### LOCAL WRITE PATH (Repository → Local DB)
```dart
// File: notes_core_repository.dart:1496-1511
final titleEncryptedBytes = await crypto.encryptStringForNote(
  userId: userId,
  noteId: noteId,
  text: title,  // "My Note Title"
);
// Returns: Uint8List of UTF-8 encoded JSON string

// Store as STRING in local DB:
titleEncrypted: utf8.decode(titleEncryptedBytes),
// Stored: '{"n":"base64...", "c":"base64...", "m":"base64..."}'
```

### REMOTE WRITE PATH (Sync → Supabase)
```dart
// File: unified_sync_service.dart:1863-1867
final encryptedTitle = await _cryptoBox!.encryptJsonForNote(
  userId: userId,
  noteId: noteId,
  json: {'title': noteData['title'] ?? ''},  // Wraps in JSON!
);
// Returns: Uint8List of UTF-8 encoded JSON:
// '{"n":"...", "c":"...", "m":"..."}'
// BUT content contains: {"title": "My Note Title"} (encrypted)

// File: supabase_note_api.dart:44
titleEnc: encryptedTitle,  // Uint8List → bytea column
// Postgres stores as BINARY
```

### REMOTE READ PATH (Supabase → Sync)
```dart
// File: supabase_note_api.dart:58-82
final dynamic res = await _client
    .from('notes')
    .select('id, user_id, created_at, updated_at, title_enc, props_enc, deleted')
    .eq('user_id', _uid);
// ⚠️  Supabase returns title_enc as: BASE64 STRING

// File: supabase_note_api.dart:79
if (t != null) m['title_enc'] = asBytes(t);
// asBytes() should decode base64 → Uint8List of JSON bytes

// File: unified_sync_service.dart:1190
final titleEnc = note['title_enc'] as Uint8List;
// ❌ BUG: This contains base64 string bytes, not decoded JSON bytes!
```

---

## 4. ROOT CAUSE EXPLANATION

### The Fundamental Issue

**Problem**: There's a **double-encoding** issue in the sync path:

1. **Local Storage** (Drift DB):
   - Stores encrypted data as **STRING**: `'{"n":"...", "c":"...", "m":"..."}'`
   - Works correctly ✅

2. **Remote Storage** (Supabase):
   - **Write**: Sends `Uint8List` → Postgres `bytea` stores as BINARY
   - **Read**: Postgres `bytea` → Supabase Dart client → **BASE64 STRING** 🔴
   - `asBytes()` should decode this, but somewhere the data is not being decoded properly

3. **Decryption expects**:
   - UTF-8 bytes of JSON string: `[123, 34, 110, 34, ...]` = `'{"n":"...", "c":"...", "m":"..."}'`

4. **Decryption receives**:
   - UTF-8 bytes of BASE64 string: `[101, 121, 74, 117, ...]` = `"eyJuIjo..."`

### Why Format Conversion Fails

The `asBytes()` function at line 354 should handle this:
```dart
// supabase_note_api.dart:354
return base64Decode(v);  // Should convert base64 → bytes
```

But the error shows it's NOT working because:
- Either the base64 decode returns a base64 string AGAIN (double encoding?)
- OR there's a code path that skips `asBytes()`
- OR Supabase is returning the data in a different format

**CRITICAL FINDING**: Looking at line 79:
```dart
if (t != null) m['title_enc'] = asBytes(t);
```

The `asBytes()` function IS being called, but the data arriving at `_deserializeSecretBox()` is still base64!

This suggests:
1. The bytea data was ALREADY base64 encoded when stored (double encoding)
2. OR `asBytes()` is decoding once, but the result is still base64
3. OR the sync service is re-fetching data without going through `asBytes()`

---

## 5. FILES REQUIRING FIXES

### CRITICAL Priority (Must Fix)

#### File 1: `/lib/core/crypto/crypto_box.dart`
**Line**: 207-291 (`_deserializeSecretBox()`)

**Current Code**:
```dart
SecretBox _deserializeSecretBox(Uint8List data) {
  try {
    String jsonString;
    if (data.every((byte) => byte >= 0 && byte <= 255)) {
      try {
        jsonString = utf8.decode(data);  // Line 214
      } catch (e) {
        jsonString = String.fromCharCodes(data);
      }
    } else {
      jsonString = utf8.decode(data);
    }

    final decoded = jsonDecode(jsonString);  // Line 223 - FAILS HERE
    // ...
```

**Problem**:
- Expects `data` to be UTF-8 bytes of JSON: `[123, 34, 110, ...]` = `'{"n":"..."}'`
- Actually receives: UTF-8 bytes of base64: `[101, 121, 74, ...]` = `"eyJu..."`

**Fix Required**:
```dart
SecretBox _deserializeSecretBox(Uint8List data) {
  try {
    // STEP 1: Convert bytes to string
    String rawString = utf8.decode(data);

    // STEP 2: Check if it's base64-encoded (Supabase bytea format)
    if (!rawString.trim().startsWith('{') &&
        rawString.length > 20 &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(rawString.trim())) {
      // This is base64 - decode it first
      try {
        final decoded = base64Decode(rawString);
        rawString = utf8.decode(decoded);
      } catch (e) {
        debugPrint('⚠️  Failed to decode base64: $e');
      }
    }

    // STEP 3: Now parse as JSON
    final decoded = jsonDecode(rawString);
    // ... rest of logic
```

**Lines to Modify**: 207-291
**Estimated Changes**: ~15 lines added

---

#### File 2: `/lib/data/remote/supabase_note_api.dart`
**Line**: 303-360 (`asBytes()`)

**Current Code**:
```dart
static Uint8List asBytes(dynamic v) {
  if (v is Uint8List) return v;
  if (v is List<int>) return Uint8List.fromList(v);
  if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());

  if (v is String) {
    // ... JSON parsing logic ...

    // Line 352-357: Try base64
    try {
      return base64Decode(v);
    } on FormatException {
      return Uint8List.fromList(utf8.encode(v));
    }
  }
```

**Problem**: The base64 decode might be working, but need to verify what format is returned.

**Fix Required**: Add debug logging:
```dart
static Uint8List asBytes(dynamic v) {
  // ... existing code ...

  if (v is String) {
    // Add diagnostic logging
    debugPrint('🔍 asBytes received string: ${v.substring(0, min(50, v.length))}...');

    // Try base64 decode
    try {
      final decoded = base64Decode(v);
      debugPrint('✅ Base64 decoded to ${decoded.length} bytes');

      // Verify it's valid JSON
      try {
        final str = utf8.decode(decoded);
        final _ = jsonDecode(str);  // Validate JSON
        debugPrint('✅ Decoded bytes contain valid JSON');
      } catch (e) {
        debugPrint('⚠️  Decoded bytes are NOT JSON: $e');
      }

      return decoded;
    } on FormatException catch (e) {
      debugPrint('❌ Base64 decode failed: $e');
      return Uint8List.fromList(utf8.encode(v));
    }
  }
```

**Lines to Modify**: 332-360
**Estimated Changes**: ~20 lines for logging

---

#### File 3: `/lib/services/unified_sync_service.dart`
**Line**: 1198-1242 (Title decryption), 1252-1289 (Props decryption)

**Current Code**:
```dart
// Line 1190
final titleEnc = note['title_enc'] as Uint8List;
final propsEnc = note['props_enc'] as Uint8List;

// Line 1198
title = await _cryptoBox!.decryptStringForNote(
  userId: userId,
  noteId: noteId,
  data: titleEnc,  // ❌ Contains base64 bytes!
);
```

**Problem**: The `titleEnc` might not be properly processed by `asBytes()`.

**Fix Required**: Add validation:
```dart
// Line 1190
final titleEncRaw = note['title_enc'];
final propsEncRaw = note['props_enc'];

// Ensure data is properly converted
final titleEnc = titleEncRaw is Uint8List
    ? titleEncRaw
    : SupabaseNoteApi.asBytes(titleEncRaw);

final propsEnc = propsEncRaw is Uint8List
    ? propsEncRaw
    : SupabaseNoteApi.asBytes(propsEncRaw);

// Add diagnostic logging
_logger.debug(
  '🔍 Title data format: type=${titleEnc.runtimeType}, length=${titleEnc.length}, first20=${titleEnc.take(20).toList()}',
);

// Decode to verify format
try {
  final str = utf8.decode(titleEnc);
  _logger.debug('🔍 Title decodes to: ${str.substring(0, min(50, str.length))}');
} catch (e) {
  _logger.error('❌ Title is not UTF-8 decodable: $e');
}
```

**Lines to Modify**: 1190-1242, 1252-1289
**Estimated Changes**: ~30 lines total

---

### MEDIUM Priority (Verify & Document)

#### File 4: `/lib/infrastructure/repositories/notes_core_repository.dart`
**Lines**: 966, 974, 1105, 1113

**Action**: Add logging to verify what format is being decrypted when reading from Supabase.

---

### LOW Priority (Monitor)

#### Files 5-7: Helper Files
- `note_decryption_helper.dart`
- `task_decryption_helper.dart`
- `folder_remote_api.dart`

**Action**: These use the same underlying crypto methods. Once crypto_box is fixed, these should work.

---

## 6. VERIFICATION PLAN

### Step 1: Add Diagnostic Logging
Add logging at each stage to trace data format:

```dart
// In asBytes()
debugPrint('🔍 asBytes input: type=${v.runtimeType}, sample=${_sample(v)}');

// In _deserializeSecretBox()
debugPrint('🔍 _deserializeSecretBox input: ${data.take(50).toList()}');
debugPrint('🔍 Decoded string: ${rawString.substring(0, min(100, rawString.length))}');

// In unified_sync_service
_logger.debug('🔍 Fetched note: titleEnc type=${titleEnc.runtimeType}, length=${titleEnc.length}');
```

### Step 2: Test Scenarios
1. **Create new note** → Sync → Verify remote format
2. **Download note** → Verify decryption succeeds
3. **Move note to folder** → Trigger sync → Verify title preserved

### Step 3: Format Validation
Check at each stage:
- What bytes are stored in Supabase bytea column?
- What format does Supabase Dart client return?
- What format does asBytes() produce?
- What format does _deserializeSecretBox() receive?

---

## 7. RECOMMENDED FIX STRATEGY

### Option A: Fix Decryption (RECOMMENDED)
**Pros**:
- No risk to existing encrypted data
- Handles both JSON and base64 formats
- Backward compatible

**Cons**:
- Adds complexity to deserialization

**Implementation**:
1. Update `_deserializeSecretBox()` to detect and decode base64
2. Add fallback chain: base64 → JSON → legacy formats
3. Log which format was detected

### Option B: Fix Data Pipeline
**Pros**:
- Cleaner long-term solution
- Standardizes on one format

**Cons**:
- May require data migration
- Risk of breaking existing notes

**Implementation**:
1. Add base64 decode in `asBytes()` BEFORE returning
2. Ensure all code paths use `asBytes()`
3. Verify with production data

---

## 8. EXACT FIXES NEEDED

### Fix #1: crypto_box.dart Line 207
**Add base64 detection and decoding**

### Fix #2: supabase_note_api.dart Line 354
**Add validation that decoded data is JSON, not base64**

### Fix #3: unified_sync_service.dart Line 1190
**Ensure asBytes() is called even if data comes as Uint8List**

### Fix #4: Add test cases
**Test all format combinations**:
- Local JSON string
- Remote base64 string
- Remote base64 → JSON bytes
- Direct Uint8List

---

## APPENDIX: ALL AFFECTED FILES

### Core Crypto Layer
- `/lib/core/crypto/crypto_box.dart` (lines 207-291) **CRITICAL**
- `/lib/core/crypto/key_manager.dart` (indirect)

### Data Layer
- `/lib/data/remote/supabase_note_api.dart` (lines 58-82, 303-360) **CRITICAL**
- `/lib/data/local/app_db.dart` (schema, indirect)

### Service Layer
- `/lib/services/unified_sync_service.dart` (lines 1146-1289, 1760-1809) **CRITICAL**
- `/lib/services/sync/folder_remote_api.dart` (lines 110, 119)

### Repository Layer
- `/lib/infrastructure/repositories/notes_core_repository.dart` (lines 129, 144, 405, 422, 510, 966, 974, 1105, 1113)
- `/lib/infrastructure/repositories/task_core_repository.dart` (lines 67, 84, 101)

### Helper Layer
- `/lib/infrastructure/helpers/note_decryption_helper.dart` (lines 33, 61)
- `/lib/infrastructure/helpers/task_decryption_helper.dart` (lines 33, 62, 91)

---

## CONCLUSION

**Root Cause**: Base64 encoding mismatch in Supabase bytea column handling.

**Primary Fix Location**: `/lib/core/crypto/crypto_box.dart` line 207-291

**Secondary Fix**: Add format detection and double-decode protection in `_deserializeSecretBox()`.

**Verification**: All fixes must handle BOTH:
1. Local DB format: JSON string `'{"n":"...", "c":"...", "m":"..."}'`
2. Supabase format: Base64 string → decode → JSON bytes

**Success Criteria**:
- Notes sync without "Untitled" errors ✅
- Folder moves preserve note titles ✅
- No SecretBox deserialization errors in logs ✅
