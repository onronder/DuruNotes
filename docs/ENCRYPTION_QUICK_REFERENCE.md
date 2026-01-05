# Encryption Quick Reference Card

## Encrypted Columns Inventory

### ✅ NOTES - Fully Encrypted
```
Remote (Supabase)           Local (Drift)              Conversion
─────────────────────────── ────────────────────────── ─────────────
title_enc (bytea)     →     title_encrypted (TEXT)    asBytes()
props_enc (bytea)     →     body_encrypted (TEXT)     asBytes()
                            metadata_encrypted (TEXT)
```

### ✅ FOLDERS - Remote Encrypted
```
Remote (Supabase)           Local (Drift)              Conversion
─────────────────────────── ────────────────────────── ─────────────
name_enc (bytea)      →     name (TEXT) PLAINTEXT     encrypt on sync
props_enc (bytea)     →     parentId, color, etc.     encrypt on sync
```

### ❌ TASKS - PLAINTEXT ON REMOTE (CRITICAL BUG!)
```
Remote (Supabase)           Local (Drift)              Conversion
─────────────────────────── ────────────────────────── ─────────────
content (text) ⚠️     →     content_encrypted (TEXT)  ❌ NONE!
labels (jsonb) ⚠️     →     labels_encrypted (TEXT)   ❌ NONE!
metadata (jsonb) ⚠️   →     notes_encrypted (TEXT)    ❌ NONE!

⚠️ WARNING: All task data stored UNENCRYPTED on Supabase!
```

### ⚠️ TEMPLATES - Needs Verification
```
Remote (Supabase)           Local (Drift)              Conversion
─────────────────────────── ────────────────────────── ─────────────
title_enc (bytea)     →     title (TEXT) PLAINTEXT    ❌ Missing asBytes()
body_enc (bytea)      →     body (TEXT) PLAINTEXT     ❌ Missing asBytes()
tags_enc (bytea)      →     tags (TEXT) PLAINTEXT     ❌ Missing asBytes()
description_enc       →     description (TEXT)        ❌ Missing asBytes()
props_enc (bytea)     →     metadata (TEXT)           ❌ Missing asBytes()
```

---

## Data Type Reference

| Database | Encrypted Column Type | Decrypted Value Type | Notes |
|----------|----------------------|---------------------|-------|
| Supabase | `bytea` | Uint8List (binary) | PostgreSQL binary array |
| Drift    | `TEXT` | String (base64) | Base64-encoded encrypted bytes |
| Dart Code | `Uint8List` | Varies | Encrypted: Uint8List, Decrypted: String/Map |

---

## Conversion Pattern Cheatsheet

### Reading from Supabase → Local
```dart
// 1. Fetch from Supabase
final rows = await supabase.from('table').select('id, encrypted_col');

// 2. Convert bytea to Uint8List
for (final row in rows) {
  if (row['encrypted_col'] != null) {
    row['encrypted_col'] = SupabaseNoteApi.asBytes(row['encrypted_col']);
  }
}

// 3. Decrypt using CryptoBox
final decrypted = await cryptoBox.decrypt(row['encrypted_col']);

// 4. Store in local DB (as base64 TEXT)
await db.into(db.table).insert(TableCompanion(
  encryptedCol: Value(base64Encode(row['encrypted_col'])),
));
```

### Writing from Local → Supabase
```dart
// 1. Read from local DB
final local = await db.select(db.table).getSingle();

// 2. Encrypt plaintext
final encrypted = await cryptoBox.encrypt(plaintext);

// 3. Send to Supabase as Uint8List
await supabase.from('table').upsert({
  'id': id,
  'encrypted_col': encrypted,  // Uint8List
});
```

---

## The `asBytes()` Method

**Location**: `/Users/onronder/duru-notes/lib/data/remote/supabase_note_api.dart:303`

**Purpose**: Convert Supabase bytea responses to Uint8List for decryption

**Handles**:
- ✅ `Uint8List` - returns as-is
- ✅ `List<int>` - converts to Uint8List
- ✅ `String` (base64) - decodes to Uint8List
- ✅ `String` (hex `\xABCD...`) - parses to Uint8List
- ✅ `Map` (libsodium JSON `{n, c, m}`) - combines to Uint8List

**Usage**:
```dart
final bytes = SupabaseNoteApi.asBytes(supabaseValue);
final decrypted = await cryptoBox.decrypt(bytes);
```

## Canonical Encryption Path

- Canonical key source: AccountKeyService (AMK stored in `user_keys` + device secure storage).
- Canonical content cipher: CryptoBox (XChaCha20-Poly1305 + HKDF).
- Legacy AES services are migration-only; do not use for note/task content.

---

## Encryption Patterns by Entity

### Pattern A: Local + Remote Encrypted (Notes)
```
User Input → Encrypt → Store Local (encrypted fields; DB file not SQLCipher) → Sync → Store Remote (bytea)
                ↓
         Field-level encrypted locally + encrypted remotely
```

**Tables**: `notes`

**Code**:
```dart
// Encrypt before local storage
final encrypted = await cryptoBox.encrypt(plaintext);
await db.into(db.localNotes).insert(
  LocalNotesCompanion(
    titleEncrypted: Value(base64Encode(encrypted)),
  ),
);

// Sync to remote
await api.upsertEncryptedNote(
  titleEnc: encrypted,  // Uint8List
);
```

---

### Pattern B: Local Plaintext, Remote Encrypted (Folders)
```
User Input → Store Local (PLAINTEXT) → Encrypt on Sync → Store Remote (bytea)
                                              ↓
                                  Encrypted only on remote
```

**Tables**: `folders`, `templates` (intended)

**Code**:
```dart
// Store plaintext locally (acceptable - device security)
await db.into(db.localFolders).insert(
  LocalFoldersCompanion(
    name: Value(plaintext),  // No encryption
  ),
);

// Encrypt during sync
final nameEnc = await cryptoBox.encrypt(folder.name);
await api.upsertEncryptedFolder(
  nameEnc: nameEnc,  // Uint8List
);
```

**Rationale**:
- Local DB on user's device - OS-level encryption sufficient
- Remote DB in cloud - must be encrypted for zero-knowledge architecture
- Reduces local storage overhead and encryption/decryption cycles

---

### Pattern C: ❌ BROKEN - Local Encrypted, Remote Plaintext (Tasks)
```
User Input → Encrypt → Store Local (TEXT) → Sync → ❌ Store Remote (PLAINTEXT!)
                ↓                                           ↓
         Encrypted locally                         EXPOSED REMOTELY
```

**Tables**: `note_tasks` (CURRENT STATE - BUG!)

**Problem**: Defeats purpose of encryption - data exposed on server

**Fix Required**: Change to Pattern A or Pattern B

---

## When to Use `asBytes()`

### ✅ Always Use When:
- Reading any `bytea` column from Supabase
- Before decrypting data from remote
- Processing encrypted data in sync operations

### ❌ Never Use When:
- Writing to Supabase (send Uint8List directly)
- Working with local database TEXT columns
- Processing plaintext data

### Example - Notes Sync:
```dart
// ✅ CORRECT
Future<List<Map<String, dynamic>>> fetchEncryptedNotes() async {
  final list = await _client.from('notes').select('title_enc, props_enc');

  for (final m in list) {
    if (m['title_enc'] != null) m['title_enc'] = asBytes(m['title_enc']);
    if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
  }
  return list;
}

// ❌ WRONG - Missing asBytes()
Future<List<Map<String, dynamic>>> fetchEncryptedNotes() async {
  return await _client.from('notes').select('title_enc, props_enc');
  // Will fail - wrong data type for decryption
}
```

---

## Testing Encryption Roundtrip

### Test Template:
```dart
test('encryption roundtrip for [entity]', () async {
  // 1. Original plaintext
  final original = 'Test data';

  // 2. Encrypt
  final encrypted = await cryptoBox.encrypt(original);
  expect(encrypted, isA<Uint8List>());

  // 3. Store in Supabase
  await supabase.from('table').upsert({
    'id': testId,
    'encrypted_col': encrypted,
  });

  // 4. Fetch from Supabase
  final fetched = await supabase.from('table')
    .select('encrypted_col')
    .eq('id', testId)
    .single();

  // 5. Convert with asBytes()
  final bytes = SupabaseNoteApi.asBytes(fetched['encrypted_col']);

  // 6. Decrypt
  final decrypted = await cryptoBox.decrypt(bytes);

  // 7. Verify
  expect(decrypted, equals(original));
});
```

---

## Common Pitfalls

### ❌ Pitfall #1: Forgetting asBytes()
```dart
// WRONG
final data = await supabase.from('notes').select('title_enc');
final decrypted = await cryptoBox.decrypt(data['title_enc']);  // FAILS!

// CORRECT
final data = await supabase.from('notes').select('title_enc');
final bytes = asBytes(data['title_enc']);
final decrypted = await cryptoBox.decrypt(bytes);
```

### ❌ Pitfall #2: Wrong API Signature
```dart
// WRONG - Using String for encrypted data
Future<void> upsertTemplate({required String titleEnc}) async {
  await supabase.from('templates').upsert({'title_enc': titleEnc});
  // Type mismatch - bytea expects binary, not string
}

// CORRECT - Using Uint8List
Future<void> upsertTemplate({required Uint8List titleEnc}) async {
  await supabase.from('templates').upsert({'title_enc': titleEnc});
}
```

### ❌ Pitfall #3: Schema Mismatch
```dart
// WRONG - Local encrypted, remote plaintext
class LocalTable {
  TextColumn get dataEncrypted => text().named('data_encrypted')();
}
// Supabase: content TEXT (plaintext)

// Sync fails - can't decrypt plaintext OR plaintext stored encrypted
```

---

## Adding a New Encrypted Entity

### Checklist:

1. **Design Schema**
   - [ ] Decide: Pattern A (both encrypted) or Pattern B (remote only)?
   - [ ] Remote: Use `bytea` for all encrypted columns
   - [ ] Local: Use `TEXT` if encrypted, or appropriate type if Pattern B

2. **Create Supabase Migration**
   ```sql
   CREATE TABLE public.new_entity (
     id uuid PRIMARY KEY,
     user_id uuid NOT NULL,
     field_enc bytea NOT NULL,  -- For encrypted data
     field text,                 -- For plaintext data
     ...
   );
   ```

3. **Update Local Schema**
   ```dart
   @DataClassName('LocalEntity')
   class LocalEntities extends Table {
     TextColumn get id => text()();
     TextColumn get fieldEncrypted => text().named('field_encrypted')();  // If Pattern A
     // OR
     TextColumn get field => text();  // If Pattern B
   }
   ```

4. **Add API Methods**
   ```dart
   // In supabase_note_api.dart
   Future<void> upsertEncryptedEntity({
     required String id,
     required Uint8List fieldEnc,  // Always Uint8List!
   }) async {
     await _client.from('entities').upsert({
       'id': id,
       'field_enc': fieldEnc,
     });
   }

   Future<List<Map<String, dynamic>>> fetchEncryptedEntities() async {
     final list = await _client.from('entities').select('field_enc');

     // CRITICAL: Add asBytes() conversion
     for (final m in list) {
       if (m['field_enc'] != null) m['field_enc'] = asBytes(m['field_enc']);
     }
     return list;
   }
   ```

5. **Implement Sync Logic**
   ```dart
   // Create entity_remote_api.dart
   class EntityRemoteApi {
     Future<void> upsertEntity(LocalEntity entity) async {
       final fieldEnc = await _cryptoBox.encrypt(entity.field);
       await _api.upsertEncryptedEntity(id: entity.id, fieldEnc: fieldEnc);
     }

     Future<LocalEntity> fetchEntity(String id) async {
       final data = await _api.fetchEncryptedEntities();
       final bytes = data['field_enc'] as Uint8List;  // Already converted
       final decrypted = await _cryptoBox.decrypt(bytes);
       return LocalEntity(id: id, field: decrypted);
     }
   }
   ```

6. **Write Tests**
   - [ ] Test encryption roundtrip
   - [ ] Test asBytes() conversion
   - [ ] Test sync in both directions
   - [ ] Test with null/empty values

---

## Quick Debugging

### Problem: Decryption fails
**Check**:
- Did you call `asBytes()` before decrypt?
- Is the data actually encrypted (check with `hexdump`)?
- Are you using the right encryption key?

### Problem: Type mismatch on upsert
**Check**:
- API method signature uses `Uint8List`, not `String`
- Not sending base64 string to bytea column
- Not sending plaintext to encrypted column

### Problem: Data not syncing
**Check**:
- Is sync code encrypting before send?
- Is fetch code calling `asBytes()`?
- Does schema match (bytea remote, TEXT local)?

---

## Reference Files

| Purpose | File Path |
|---------|-----------|
| Main audit report | `/Users/onronder/duru-notes/DATABASE_ENCRYPTION_SCHEMA_AUDIT.md` |
| Executive summary | `/Users/onronder/duru-notes/ENCRYPTION_AUDIT_SUMMARY.md` |
| Quick reference | `/Users/onronder/duru-notes/ENCRYPTION_QUICK_REFERENCE.md` |
| asBytes() implementation | `lib/data/remote/supabase_note_api.dart:303` |
| Notes sync (working example) | `lib/services/unified_sync_service.dart` |
| Folders sync (working example) | `lib/services/sync/folder_remote_api.dart` |
| Local schema | `lib/data/local/app_db.dart` |
| Remote schema | `supabase/migrations/20250301000000_initial_baseline_schema.sql` |
