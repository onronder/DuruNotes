# ENCRYPTION BUG - QUICK REFERENCE GUIDE

## THE PROBLEM IN ONE SENTENCE
Supabase returns `bytea` columns as base64-encoded strings, but `_deserializeSecretBox()` expects UTF-8 bytes of JSON, causing "Unexpected character" parse errors.

---

## ERROR SIGNATURE
```
❌ SecretBox deserialization error: FormatException: Unexpected character (at character 1)
eyJuIjoieHYxdEUxWFM5a2hFVWpnMXJIMGFtQ2NxakR0ZnNiL1QiLCJjIjoiRUo1TmhuWlciLCJ...
Raw data sample: [101, 121, 74, 117, 73, 106, 111, 105...]
```

**Translation**:
- Bytes `[101, 121, 74, 117...]` = UTF-8 of "eyJu..." (base64)
- `_deserializeSecretBox()` tries to parse this as JSON → FAILS

---

## ROOT CAUSE
**Two-step encoding mismatch**:

1. **WRITE** (Encryption):
   ```
   Plaintext → Encrypt → SecretBox → JSON {"n":"...", "c":"...", "m":"..."}
   → UTF-8 encode → Uint8List → Supabase bytea
   ```

2. **READ** (Decryption):
   ```
   Supabase bytea → BASE64 STRING "eyJu..."
   → asBytes() decodes → Uint8List [101, 121, 74, ...]
   → BUT: These are bytes of base64 string, NOT bytes of JSON!
   → _deserializeSecretBox() expects JSON bytes → ERROR
   ```

---

## CRITICAL FILES TO FIX

### 1. `/lib/core/crypto/crypto_box.dart` Line 207-291
**Function**: `_deserializeSecretBox(Uint8List data)`

**Current Issue**:
```dart
String jsonString = utf8.decode(data);  // Gets "eyJu..." instead of '{"n":"..."}'
final decoded = jsonDecode(jsonString); // FAILS
```

**Fix**:
```dart
String jsonString = utf8.decode(data);

// Detect base64 format
if (!jsonString.trim().startsWith('{') &&
    RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(jsonString.trim())) {
  // Decode base64 first
  final decoded = base64Decode(jsonString);
  jsonString = utf8.decode(decoded);
}

final decoded = jsonDecode(jsonString);  // Now works!
```

---

### 2. `/lib/data/remote/supabase_note_api.dart` Line 303-360
**Function**: `asBytes(dynamic v)`

**Current Issue**: Base64 decode returns bytes, but need to verify format.

**Fix**: Add validation after base64 decode:
```dart
if (v is String) {
  try {
    final decoded = base64Decode(v);

    // VERIFY: Check if decoded bytes are valid UTF-8 JSON
    try {
      final str = utf8.decode(decoded);
      if (str.trim().startsWith('{')) {
        // Valid JSON - return as-is
        return decoded;
      }
    } catch (_) {}

    return decoded;
  } on FormatException {
    return Uint8List.fromList(utf8.encode(v));
  }
}
```

---

### 3. `/lib/services/unified_sync_service.dart` Line 1190-1242
**Location**: `_getRemoteNotes()` method

**Current Issue**:
```dart
final titleEnc = note['title_enc'] as Uint8List;  // Might be base64 bytes!
```

**Fix**: Force re-processing through asBytes():
```dart
final titleEncRaw = note['title_enc'];
final titleEnc = SupabaseNoteApi.asBytes(titleEncRaw);  // Ensure proper format
```

---

## DECRYPTION CALL SITES SUMMARY

### HIGH RISK (Supabase Sync)
| File | Line | Method | Status |
|------|------|--------|--------|
| `unified_sync_service.dart` | 1198 | `decryptStringForNote()` | 🔴 BROKEN |
| `unified_sync_service.dart` | 1252 | `decryptJsonForNote()` | 🔴 BROKEN |
| `unified_sync_service.dart` | 1773 | `decryptJsonForNote()` | 🔴 BROKEN |

### MEDIUM RISK (Repository Layer)
| File | Lines | Method | Status |
|------|-------|--------|--------|
| `notes_core_repository.dart` | 129, 144, 405, 422, 510 | `decryptStringForNote()` | ⚠️ MAY FAIL |
| `notes_core_repository.dart` | 966, 974, 1105, 1113 | `decryptJsonForNote()` | ⚠️ MAY FAIL |

### LOW RISK (Local DB Only)
| File | Lines | Status |
|------|-------|--------|
| `task_core_repository.dart` | 67, 84, 101 | ✅ OK (uses local data) |
| `note_decryption_helper.dart` | 33, 61 | ✅ OK (uses fixed crypto) |

---

## DATA FORMAT EXAMPLES

### Format 1: Local DB (WORKS)
```
Type: String
Value: '{"n":"base64nonce", "c":"base64cipher", "m":"base64mac"}'
```

### Format 2: Supabase bytea → Dart (BROKEN)
```
Postgres stores: BINARY (Uint8List bytes)
Supabase returns: BASE64 STRING "eyJuIjoiYmFzZTY0bm9uY2UiLCJjIjoiYmFzZTY0Y2lwaGVyIiwibSI6ImJhc2U2NG1hYyJ9"
asBytes() decodes: Uint8List [101, 121, 74, 117, ...] (bytes of base64!)
_deserializeSecretBox() expects: [123, 34, 110, 34, ...] (bytes of JSON!)
```

### Format 3: What We Need (TARGET)
```
Supabase bytea → asBytes() → Uint8List [123, 34, 110, 34, ...]
                               = UTF-8 bytes of '{"n":"...", "c":"...", "m":"..."}'
```

---

## TESTING CHECKLIST

### Test Case 1: Verify Format Detection
```dart
// Base64 string
final base64 = "eyJuIjoiYmFzZTY0bm9uY2UifQ==";
final bytes = Uint8List.fromList(utf8.encode(base64));
// _deserializeSecretBox(bytes) should:
// 1. Detect base64
// 2. Decode to JSON
// 3. Parse successfully
```

### Test Case 2: Verify JSON Format
```dart
// JSON string
final json = '{"n":"base64nonce", "c":"base64cipher", "m":"base64mac"}';
final bytes = Uint8List.fromList(utf8.encode(json));
// _deserializeSecretBox(bytes) should:
// 1. Skip base64 decode
// 2. Parse JSON directly
// 3. Extract SecretBox
```

### Test Case 3: End-to-End
```dart
// 1. Create note locally
// 2. Sync to Supabase
// 3. Clear local cache
// 4. Sync from Supabase
// 5. Verify note title matches original
```

---

## VERIFICATION STEPS

1. **Add Debug Logging**:
   ```dart
   debugPrint('🔍 Data format: ${utf8.decode(data).substring(0, 50)}');
   ```

2. **Run Sync**:
   - Move a note to a folder
   - Check console logs

3. **Check Format**:
   - If logs show "eyJu..." → Base64 detected ✅
   - If logs show '{"n":"..."' → JSON detected ✅
   - If error occurs → Fix not working ❌

---

## SUCCESS CRITERIA

✅ **No more "FormatException: Unexpected character" errors**
✅ **Notes sync without becoming "Untitled"**
✅ **Folder moves preserve note titles**
✅ **Both local and remote decrypt successfully**

---

## ROLLBACK PLAN

If fixes break existing data:

1. **Revert crypto_box.dart changes**
2. **Add migration to re-encrypt all notes**:
   ```sql
   -- Find notes with base64-encoded encrypted fields
   SELECT id, encode(title_enc, 'escape') FROM notes LIMIT 10;
   ```
3. **Run batch re-encryption script**

---

## RELATED DOCUMENTATION

- Full analysis: `/ENCRYPTION_BUG_ANALYSIS_REPORT.md`
- Previous fix attempt: `/docs/todo/todo_10232025.md`
- Crypto implementation: `/lib/core/crypto/crypto_box.dart`
- Supabase API: `/lib/data/remote/supabase_note_api.dart`
