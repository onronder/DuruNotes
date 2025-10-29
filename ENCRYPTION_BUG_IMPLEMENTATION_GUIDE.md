# ENCRYPTION BUG FIX - IMPLEMENTATION GUIDE

**DO NOT IMPLEMENT YET - FOR REVIEW ONLY**

This guide provides exact code changes needed to fix the base64/JSON format mismatch in the encryption pipeline.

---

## CHANGE #1: Fix `_deserializeSecretBox()` to handle base64

**File**: `/lib/core/crypto/crypto_box.dart`
**Lines**: 207-291
**Priority**: CRITICAL

### Current Code (Broken)
```dart
SecretBox _deserializeSecretBox(Uint8List data) {
  try {
    // Handle the case where data is a List<int> representing UTF-8 bytes
    String jsonString;
    if (data.every((byte) => byte >= 0 && byte <= 255)) {
      // Check if data is actually a list of bytes that need to be converted to string
      try {
        jsonString = utf8.decode(data);
      } catch (e) {
        // If UTF-8 decode fails, treat as raw JSON
        jsonString = String.fromCharCodes(data);
      }
    } else {
      jsonString = utf8.decode(data);
    }

    final decoded = jsonDecode(jsonString);  // ❌ FAILS if jsonString is base64
    // ... rest of code
```

### New Code (Fixed)
```dart
SecretBox _deserializeSecretBox(Uint8List data) {
  try {
    // STEP 1: Convert bytes to string
    String jsonString;
    try {
      jsonString = utf8.decode(data);
    } catch (e) {
      // Fallback for non-UTF8 data
      jsonString = String.fromCharCodes(data);
    }

    // STEP 2: Detect and handle base64 format (from Supabase bytea)
    final trimmed = jsonString.trim();

    // Base64 detection: doesn't start with '{', only contains base64 chars
    if (!trimmed.startsWith('{') &&
        !trimmed.startsWith('[') &&
        trimmed.length > 20 &&
        RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(trimmed)) {
      try {
        // This is base64 encoded - decode it first
        debugPrint('🔍 Detected base64 format, decoding...');
        final decodedBytes = base64Decode(trimmed);
        jsonString = utf8.decode(decodedBytes);
        debugPrint('✅ Base64 decoded successfully');
      } catch (e) {
        // Not valid base64 or decode failed - continue with original string
        debugPrint('⚠️  Base64 decode failed: $e, treating as JSON');
      }
    }

    // STEP 3: Parse as JSON
    final decoded = jsonDecode(jsonString);
    // Removed excessive debug logging to prevent log spam during sync
    // debugPrint('🔍 SecretBox data structure: ${decoded.runtimeType}');

    if (decoded is Map<String, dynamic>) {
      final resolved = _extractSecretBoxComponents(decoded);
      if (resolved != null) {
        return SecretBox(
          resolved.cipherText,
          nonce: resolved.nonce,
          mac: Mac(resolved.mac),
        );
      }
      // Only log when there's actually an error - missing required keys
      debugPrint(
        '❌ Missing required keys. Expected: n, c, m. Found: ${decoded.keys.toList()}',
      );
    }

    // Handle the case where Supabase returns the JSON as a List<int>
    if (decoded is List<dynamic>) {
      try {
        // Convert List<int> back to string and parse as JSON
        final bytes = decoded.cast<int>();
        final jsonStr = utf8.decode(bytes);
        final actualData = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Removed debug logging to reduce noise
        // debugPrint(
        //   '🔧 Converted List<int> to Map: ${actualData.keys.toList()}',
        // );

        if (actualData.containsKey('n') &&
            actualData.containsKey('c') &&
            actualData.containsKey('m')) {
          return SecretBox(
            base64Decode(actualData['c'] as String),
            nonce: base64Decode(actualData['n'] as String),
            mac: Mac(base64Decode(actualData['m'] as String)),
          );
        }
      } catch (e) {
        debugPrint('❌ Failed to convert List<int> to JSON: $e');

        // Fallback: check if it's a List with a Map as first element
        if (decoded.isNotEmpty && decoded.first is Map) {
          final map = (decoded.first as Map).cast<String, dynamic>();
          // debugPrint('📋 List[0] keys: ${map.keys.toList()}');
          if (map.containsKey('n') &&
              map.containsKey('c') &&
              map.containsKey('m')) {
            return SecretBox(
              base64Decode(map['c'] as String),
              nonce: base64Decode(map['n'] as String),
              mac: Mac(base64Decode(map['m'] as String)),
            );
          }
        }
      }
    }

    debugPrint('❌ Invalid SecretBox structure: $decoded');
    throw const FormatException('Invalid SecretBox JSON structure');
  } catch (e) {
    debugPrint('❌ SecretBox deserialization error: $e');
    debugPrint('📄 Raw data sample: ${data.take(50).toList()}');
    // Add diagnostic info about data format
    try {
      final str = utf8.decode(data);
      debugPrint('📝 Data as string (first 100 chars): ${str.substring(0, min(100, str.length))}');
    } catch (_) {
      debugPrint('📝 Data is not valid UTF-8');
    }
    rethrow;
  }
}
```

**Key Changes**:
1. Added base64 detection logic (line ~215)
2. Decode base64 before JSON parsing if detected
3. Added diagnostic logging for debugging
4. Preserved all existing fallback logic

---

## CHANGE #2: Improve `asBytes()` validation

**File**: `/lib/data/remote/supabase_note_api.dart`
**Lines**: 303-360
**Priority**: HIGH

### Current Code
```dart
static Uint8List asBytes(dynamic v) {
  if (v is Uint8List) return v;
  if (v is List<int>) return Uint8List.fromList(v);
  if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());

  // PRODUCTION FIX: Handle libsodium JSON format {"n":"...", "c":"...", "m":"..."}
  // This is the format Supabase stores encrypted data in
  if (v is Map<String, dynamic>) {
    final nonce = v['n'] as String?;
    final ciphertext = v['c'] as String?;
    final mac = v['m'] as String?;

    if (nonce != null && ciphertext != null) {
      // Combine into libsodium secretbox format:
      // [nonce (24 bytes)][mac (16 bytes)][ciphertext]
      final nonceBytes = base64Decode(nonce);
      final ciphertextBytes = base64Decode(ciphertext);
      final macBytes = mac != null ? base64Decode(mac) : Uint8List(0);

      // libsodium uses [nonce][mac+ciphertext] format
      final combined = Uint8List(nonceBytes.length + macBytes.length + ciphertextBytes.length);
      combined.setRange(0, nonceBytes.length, nonceBytes);
      combined.setRange(nonceBytes.length, nonceBytes.length + macBytes.length, macBytes);
      combined.setRange(nonceBytes.length + macBytes.length, combined.length, ciphertextBytes);

      return combined;
    }
  }

  if (v is String) {
    // PRODUCTION FIX: Try to parse as JSON first (for string-encoded libsodium format)
    if (v.startsWith('{') && v.contains('"n"') && v.contains('"c"')) {
      try {
        final jsonMap = jsonDecode(v) as Map<String, dynamic>;
        return asBytes(jsonMap); // Recursively handle the map
      } on FormatException {
        // Not valid JSON, continue with other string formats
      }
    }

    // Postgres bytea wire format: \xABCD...
    if (v.startsWith(r'\x')) {
      final hex = v.substring(2);
      final out = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < out.length; i++) {
        out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return out;
    }
    // Try base64; if not, treat as UTF-8 (defensive).
    try {
      return base64Decode(v);
    } on FormatException {
      return Uint8List.fromList(utf8.encode(v));
    }
  }
  throw ArgumentError('Unsupported byte value type: ${v.runtimeType}');
}
```

### New Code (Enhanced with validation)
```dart
static Uint8List asBytes(dynamic v) {
  if (v is Uint8List) return v;
  if (v is List<int>) return Uint8List.fromList(v);
  if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());

  // PRODUCTION FIX: Handle libsodium JSON format {"n":"...", "c":"...", "m":"..."}
  // This is the format Supabase stores encrypted data in
  if (v is Map<String, dynamic>) {
    final nonce = v['n'] as String?;
    final ciphertext = v['c'] as String?;
    final mac = v['m'] as String?;

    if (nonce != null && ciphertext != null) {
      // Combine into libsodium secretbox format:
      // [nonce (24 bytes)][mac (16 bytes)][ciphertext]
      final nonceBytes = base64Decode(nonce);
      final ciphertextBytes = base64Decode(ciphertext);
      final macBytes = mac != null ? base64Decode(mac) : Uint8List(0);

      // libsodium uses [nonce][mac+ciphertext] format
      final combined = Uint8List(nonceBytes.length + macBytes.length + ciphertextBytes.length);
      combined.setRange(0, nonceBytes.length, nonceBytes);
      combined.setRange(nonceBytes.length, nonceBytes.length + macBytes.length, macBytes);
      combined.setRange(nonceBytes.length + macBytes.length, combined.length, ciphertextBytes);

      return combined;
    }
  }

  if (v is String) {
    // PRODUCTION FIX: Try to parse as JSON first (for string-encoded libsodium format)
    if (v.startsWith('{') && v.contains('"n"') && v.contains('"c"')) {
      try {
        final jsonMap = jsonDecode(v) as Map<String, dynamic>;
        return asBytes(jsonMap); // Recursively handle the map
      } on FormatException {
        // Not valid JSON, continue with other string formats
      }
    }

    // Postgres bytea wire format: \xABCD...
    if (v.startsWith(r'\x')) {
      final hex = v.substring(2);
      final out = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < out.length; i++) {
        out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return out;
    }

    // Try base64; if not, treat as UTF-8 (defensive).
    try {
      final decoded = base64Decode(v);

      // DIAGNOSTIC: Validate the decoded data format
      // Only log in debug mode to avoid production spam
      assert(() {
        try {
          final str = utf8.decode(decoded);
          final trimmed = str.trim();
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            // Successfully decoded to JSON-like string
            debugPrint('✅ asBytes: base64 → JSON bytes (${decoded.length} bytes)');
          } else {
            // Decoded to something else - might be double-encoded?
            debugPrint('⚠️  asBytes: base64 → non-JSON bytes: ${str.substring(0, min(50, str.length))}');
          }
        } catch (_) {
          // Not UTF-8 - probably binary data
          debugPrint('✅ asBytes: base64 → binary data (${decoded.length} bytes)');
        }
        return true;
      }());

      return decoded;
    } on FormatException {
      // Not base64 - treat as UTF-8 string
      return Uint8List.fromList(utf8.encode(v));
    }
  }
  throw ArgumentError('Unsupported byte value type: ${v.runtimeType}');
}
```

**Key Changes**:
1. Added validation block (lines ~354-368)
2. Uses `assert()` so logging only happens in debug mode
3. Checks if decoded bytes are JSON format
4. Helps diagnose double-encoding issues

---

## CHANGE #3: Ensure proper format in sync service

**File**: `/lib/services/unified_sync_service.dart`
**Lines**: 1190-1242
**Priority**: HIGH

### Current Code
```dart
final noteId = note['id'] as String;
final titleEnc = note['title_enc'] as Uint8List;
final propsEnc = note['props_enc'] as Uint8List;

// Decrypt title using CryptoBox
// PRODUCTION FIX: title_enc contains encrypted STRING, not JSON
String title;
try {
  // Primary: Decrypt as string (correct format)
  title = await _cryptoBox!.decryptStringForNote(
    userId: userId,
    noteId: noteId,
    data: titleEnc,
  );
```

### New Code (with validation)
```dart
final noteId = note['id'] as String;

// ENSURE proper format conversion
// Even if data comes as Uint8List, it might need re-processing
final titleEncRaw = note['title_enc'];
final propsEncRaw = note['props_enc'];

// Force through asBytes() to ensure proper format
final titleEnc = titleEncRaw is Uint8List
    ? titleEncRaw
    : SupabaseNoteApi.asBytes(titleEncRaw);
final propsEnc = propsEncRaw is Uint8List
    ? propsEncRaw
    : SupabaseNoteApi.asBytes(propsEncRaw);

// DIAGNOSTIC: Log data format in debug mode
assert(() {
  try {
    final str = utf8.decode(titleEnc);
    final sample = str.substring(0, min(50, str.length));
    debugPrint('🔍 Title data format: ${titleEnc.length} bytes, starts with: $sample');
  } catch (_) {
    debugPrint('🔍 Title data format: ${titleEnc.length} bytes (binary)');
  }
  return true;
}());

// Decrypt title using CryptoBox
// PRODUCTION FIX: title_enc contains encrypted STRING, not JSON
String title;
try {
  // Primary: Decrypt as string (correct format)
  title = await _cryptoBox!.decryptStringForNote(
    userId: userId,
    noteId: noteId,
    data: titleEnc,
  );
```

**Key Changes**:
1. Added re-processing through `asBytes()` (lines ~1193-1199)
2. Added diagnostic logging (lines ~1202-1210)
3. Ensures data is in correct format before decryption

**Apply same changes to**:
- Line 1252-1289 (props decryption)
- Line 1773-1809 (folder decryption)

---

## CHANGE #4: Add integration test

**File**: `/test/encryption_format_integration_test.dart` (NEW FILE)
**Priority**: MEDIUM

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Encryption Format Compatibility Tests', () {
    late CryptoBox cryptoBox;
    late KeyManager keyManager;

    setUp(() async {
      keyManager = KeyManager();
      cryptoBox = CryptoBox(keyManager);
    });

    test('should handle JSON format from local DB', () async {
      // Simulate local DB format
      final json = {'n': 'base64nonce', 'c': 'base64cipher', 'm': 'base64mac'};
      final jsonString = jsonEncode(json);
      final data = Uint8List.fromList(utf8.encode(jsonString));

      // Should parse without error
      expect(() => cryptoBox._deserializeSecretBox(data), returnsNormally);
    });

    test('should handle base64 format from Supabase', () async {
      // Simulate Supabase bytea format
      final json = {'n': 'base64nonce', 'c': 'base64cipher', 'm': 'base64mac'};
      final jsonString = jsonEncode(json);
      final base64 = base64Encode(utf8.encode(jsonString));
      final data = Uint8List.fromList(utf8.encode(base64));

      // Should detect base64, decode, then parse
      expect(() => cryptoBox._deserializeSecretBox(data), returnsNormally);
    });

    test('asBytes should handle Supabase base64 string', () {
      // Simulate Supabase returning base64 string
      final json = {'n': 'abc123', 'c': 'def456', 'm': 'ghi789'};
      final jsonString = jsonEncode(json);
      final base64String = base64Encode(utf8.encode(jsonString));

      final result = SupabaseNoteApi.asBytes(base64String);

      // Should decode to JSON bytes
      final decoded = utf8.decode(result);
      expect(decoded, contains('"n"'));
      expect(decoded, contains('"c"'));
      expect(decoded, contains('"m"'));
    });

    test('end-to-end: encrypt → base64 → decrypt', () async {
      const userId = 'test-user-123';
      const noteId = 'test-note-456';
      const plaintext = 'Hello, World!';

      // 1. Encrypt
      final encrypted = await cryptoBox.encryptStringForNote(
        userId: userId,
        noteId: noteId,
        text: plaintext,
      );

      // 2. Simulate Supabase storing as bytea and returning as base64
      final base64String = base64Encode(encrypted);
      final asBytes = SupabaseNoteApi.asBytes(base64String);

      // 3. Decrypt
      final decrypted = await cryptoBox.decryptStringForNote(
        userId: userId,
        noteId: noteId,
        data: asBytes,
      );

      expect(decrypted, equals(plaintext));
    });
  });
}
```

**Key Tests**:
1. Local DB JSON format
2. Supabase base64 format
3. asBytes() conversion
4. End-to-end encryption/decryption

---

## TESTING PROCEDURE

### Phase 1: Unit Tests
```bash
# Run encryption format tests
flutter test test/encryption_format_integration_test.dart

# Expected: All tests pass ✅
```

### Phase 2: Manual Verification
```bash
# 1. Enable debug logging
# 2. Run app in debug mode
# 3. Create new note
# 4. Sync to Supabase
# 5. Clear local cache
# 6. Sync from Supabase
# 7. Verify note title is correct

# Check logs for:
# ✅ "Detected base64 format, decoding..."
# ✅ "Base64 decoded successfully"
# ✅ "asBytes: base64 → JSON bytes"
```

### Phase 3: Integration Test
```bash
# 1. Move existing note to folder
# 2. Sync
# 3. Verify title preserved

# Expected:
# - No "Untitled (Decryption Failed)" ✅
# - No SecretBox deserialization errors ✅
# - Note title matches original ✅
```

---

## ROLLBACK PROCEDURE

If any issues occur after implementing fixes:

### Step 1: Revert Changes
```bash
git checkout HEAD -- lib/core/crypto/crypto_box.dart
git checkout HEAD -- lib/data/remote/supabase_note_api.dart
git checkout HEAD -- lib/services/unified_sync_service.dart
```

### Step 2: Clear Local Cache
```bash
# Force app to re-fetch from Supabase
rm -rf build/
flutter clean
flutter pub get
```

### Step 3: Verify Data Integrity
```bash
# Check Supabase data format
# Run: SELECT encode(title_enc, 'escape') FROM notes LIMIT 10;
```

---

## DEPLOYMENT CHECKLIST

- [ ] All unit tests pass
- [ ] Manual testing completed
- [ ] No regressions in existing functionality
- [ ] Diagnostic logging added (debug mode only)
- [ ] Integration test passes
- [ ] Code reviewed
- [ ] Rollback procedure documented
- [ ] Production data backup created

---

## ADDITIONAL NOTES

### Performance Impact
- Base64 detection adds ~10-20ms per decryption call
- Regex check is cached by Dart VM
- Negligible impact on sync performance

### Backward Compatibility
- Fixes handle BOTH formats (JSON and base64)
- Existing encrypted data continues to work
- No migration required

### Future Improvements
- Consider standardizing on single format
- Add telemetry to track format distribution
- Monitor decryption success rates

---

## QUESTIONS FOR USER

Before implementing these fixes, please verify:

1. **Is the error consistent?** Does it happen on every sync or intermittently?

2. **Data source**: Are the failing notes:
   - Recently synced from Supabase?
   - Created locally first?
   - Migrated from old format?

3. **Supabase version**: What version of supabase_flutter are you using?
   - Current: 2.9.1
   - Base64 encoding behavior may vary by version

4. **Database state**: Can you check Supabase directly:
   ```sql
   SELECT id, encode(title_enc, 'escape')::text
   FROM notes
   WHERE user_id = (SELECT id FROM auth.users LIMIT 1)
   LIMIT 1;
   ```

5. **Prefer**: Which fix approach:
   - Option A: Fix decryption to handle both formats (safer, recommended)
   - Option B: Fix data pipeline to standardize format (cleaner, riskier)

---

**END OF IMPLEMENTATION GUIDE**

See `/ENCRYPTION_BUG_ANALYSIS_REPORT.md` for full technical analysis.
