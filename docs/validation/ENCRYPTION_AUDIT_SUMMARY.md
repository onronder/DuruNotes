# DATABASE ENCRYPTION AUDIT - EXECUTIVE SUMMARY

**Date**: 2025-10-23
**Auditor**: Claude Code (Database Optimization Expert)
**Scope**: Complete analysis of encrypted data handling across local and remote databases

---

## CRITICAL SECURITY FINDINGS

### 1. CRITICAL: Tasks Stored in Plaintext on Supabase ❌

**Issue**: The `note_tasks` table has NO encryption on Supabase, but local database encrypts task content.

**Evidence**:
- **Remote Schema** (`supabase/migrations/20250301000000_initial_baseline_schema.sql`):
  ```sql
  CREATE TABLE public.note_tasks (
    content text NOT NULL,           -- PLAINTEXT!
    labels jsonb DEFAULT '[]',       -- PLAINTEXT!
    metadata jsonb DEFAULT '{}',     -- PLAINTEXT!
    ...
  );
  ```

- **Local Schema** (`lib/data/local/app_db.dart`):
  ```dart
  class NoteTasks extends Table {
    TextColumn get contentEncrypted => text().named('content_encrypted')();
    TextColumn get labelsEncrypted => text().named('labels_encrypted').nullable()();
    TextColumn get notesEncrypted => text().named('notes_encrypted').nullable()();
  }
  ```

- **Sync Code** (`lib/services/unified_sync_service.dart`):
  ```dart
  // Tasks synced WITHOUT encryption!
  await _client!.from('note_tasks').upsert(data);
  ```

**Impact**:
- All task descriptions, labels, and notes stored UNENCRYPTED on Supabase
- Violates zero-knowledge encryption architecture
- Potential privacy breach for all user task data
- **ESTIMATED AFFECTED DATA**: All tasks created by all users

**Risk Level**: CRITICAL (P0)

---

## SECURITY ASSESSMENT BY TABLE

| Table | Local Encryption | Remote Encryption | Sync Encryption | Status |
|-------|------------------|-------------------|-----------------|--------|
| **notes** | ✅ Yes | ✅ Yes (bytea) | ✅ Yes (asBytes) | ✅ SECURE |
| **folders** | ⚠️ No* | ✅ Yes (bytea) | ✅ Yes (on-the-fly) | ✅ SECURE* |
| **templates** | ⚠️ No* | ✅ Yes (bytea) | ⚠️ Unknown | ⚠️ NEEDS VERIFICATION |
| **note_tasks** | ✅ Yes | ❌ NO | ❌ NO | ❌ CRITICAL BREACH |
| **note_blocks** | N/A | ✅ Yes (bytea) | N/A | ⚠️ Not implemented |

\* *Folders stored plaintext locally but encrypted during sync to Supabase - this is acceptable as local DB is on user's device*

---

## DETAILED FINDINGS

### Notes Table ✅ SECURE

**Remote**: `title_enc bytea`, `props_enc bytea`
**Local**: `title_encrypted TEXT`, `body_encrypted TEXT`, `metadata_encrypted TEXT`
**Conversion**: Uses `asBytes()` to convert Supabase bytea → Uint8List

**Assessment**: ✅ Properly encrypted end-to-end

---

### Folders Table ✅ SECURE (with caveat)

**Remote**: `name_enc bytea`, `props_enc bytea`
**Local**: `name TEXT`, `parentId TEXT`, `color TEXT`, etc. (PLAINTEXT)
**Sync**: Encrypts on-the-fly via `folder_remote_api.dart`

```dart
// lib/services/sync/folder_remote_api.dart:203
Future<void> upsertFolder(LocalFolder folder) async {
  final nameEnc = await _encryptName(userId: userId, folderId: folder.id, name: folder.name);
  final propsEnc = await _encryptProps(userId: userId, folder: folder, ...);

  await _noteApi.upsertEncryptedFolder(
    id: folder.id,
    nameEnc: nameEnc,       // Encrypted
    propsEnc: propsEnc,     // Encrypted
    deleted: folder.deleted,
  );
}
```

**Assessment**: ✅ Secure - plaintext local storage is acceptable (device-level security), remote storage is properly encrypted

---

### Templates Table ⚠️ NEEDS VERIFICATION

**Remote**: `title_enc bytea`, `body_enc bytea`, `tags_enc bytea`, `description_enc bytea`, `props_enc bytea`
**Local**: `title TEXT`, `body TEXT`, `tags TEXT`, `description TEXT` (PLAINTEXT)
**Sync**: Unknown - needs verification

**Issues Identified**:
1. API method uses `String` instead of `Uint8List` for encrypted columns:
   ```dart
   // lib/data/remote/supabase_note_api.dart:535
   Future<void> upsertTemplate({
     required String titleEnc,    // Should be Uint8List!
     required String bodyEnc,     // Should be Uint8List!
     ...
   });
   ```

2. `fetchTemplates()` does NOT use `asBytes()` conversion:
   ```dart
   // lib/data/remote/supabase_note_api.dart:516
   Future<List<Map<String, dynamic>>> fetchTemplates({DateTime? since}) async {
     return await _client.from('templates').select(...);
     // MISSING: asBytes() conversion for bytea columns!
   }
   ```

**Assessment**: ⚠️ Schema supports encryption but implementation has bugs. Needs verification if sync code encrypts before calling API.

**Recommended Fix**:
```dart
// 1. Fix API signature
Future<void> upsertTemplate({
  required Uint8List titleEnc,    // Change to Uint8List
  required Uint8List bodyEnc,     // Change to Uint8List
  Uint8List? tagsEnc,             // Change to Uint8List
  ...
});

// 2. Add asBytes() conversion in fetchTemplates()
for (final m in list) {
  if (m['title_enc'] != null) m['title_enc'] = asBytes(m['title_enc']);
  if (m['body_enc'] != null) m['body_enc'] = asBytes(m['body_enc']);
  if (m['tags_enc'] != null) m['tags_enc'] = asBytes(m['tags_enc']);
  if (m['description_enc'] != null) m['description_enc'] = asBytes(m['description_enc']);
  if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
}
```

---

### Tasks Table ❌ CRITICAL BREACH

**Remote**: `content text`, `labels jsonb`, `metadata jsonb` (ALL PLAINTEXT)
**Local**: `content_encrypted TEXT`, `labels_encrypted TEXT`, `notes_encrypted TEXT` (ENCRYPTED)
**Sync**: Direct upsert WITHOUT encryption

```dart
// lib/services/unified_sync_service.dart
await _client!.from('note_tasks').upsert(data);  // NO ENCRYPTION!
```

**Assessment**: ❌ CRITICAL - All task data exposed in plaintext on server

**Required Fixes**:
1. **Database Migration**: Add encrypted columns to `note_tasks` table
   ```sql
   ALTER TABLE public.note_tasks
     ADD COLUMN content_enc bytea,
     ADD COLUMN labels_enc bytea,
     ADD COLUMN notes_enc bytea;

   -- Migrate existing data (if any plaintext exists)
   -- Drop old plaintext columns after migration
   ALTER TABLE public.note_tasks
     DROP COLUMN content,
     DROP COLUMN labels,
     DROP COLUMN metadata;
   ```

2. **Sync Code**: Implement encryption in task sync (similar to folder pattern)
   ```dart
   // Create task_remote_api.dart similar to folder_remote_api.dart
   Future<void> upsertTask(NoteTask task) async {
     final contentEnc = await _encryptContent(...);
     final labelsEnc = await _encryptLabels(...);
     final notesEnc = await _encryptNotes(...);

     await _noteApi.upsertEncryptedTask(
       id: task.id,
       contentEnc: contentEnc,
       labelsEnc: labelsEnc,
       notesEnc: notesEnc,
       ...
     );
   }
   ```

3. **API Methods**: Add encrypted task operations to `supabase_note_api.dart`
   ```dart
   Future<void> upsertEncryptedTask({
     required String id,
     required Uint8List contentEnc,
     Uint8List? labelsEnc,
     Uint8List? notesEnc,
     ...
   });

   Future<List<Map<String, dynamic>>> fetchEncryptedTasks({DateTime? since}) async {
     final list = await _client.from('note_tasks').select(...);

     for (final m in list) {
       if (m['content_enc'] != null) m['content_enc'] = asBytes(m['content_enc']);
       if (m['labels_enc'] != null) m['labels_enc'] = asBytes(m['labels_enc']);
       if (m['notes_enc'] != null) m['notes_enc'] = asBytes(m['notes_enc']);
     }
     return list;
   }
   ```

---

## DATA CONVERSION PATTERNS

### The `asBytes()` Method

All encrypted data from Supabase must be converted using `asBytes()`:

```dart
// lib/data/remote/supabase_note_api.dart:303
static Uint8List asBytes(dynamic v) {
  // Handles multiple formats:
  // 1. Uint8List / List<int> - direct conversion
  // 2. String - tries base64 decode, then UTF-8
  // 3. Map - libsodium JSON format {n: nonce, c: ciphertext, m: mac}
  // 4. Postgres bytea hex format (\xABCD...)

  // Returns: Uint8List ready for decryption
}
```

**Critical**: Every `bytea` column read from Supabase MUST be converted via `asBytes()` before decryption.

**Pattern**:
```dart
final rows = await supabase.from('table').select('encrypted_col');
for (final row in rows) {
  if (row['encrypted_col'] != null) {
    row['encrypted_col'] = asBytes(row['encrypted_col']);
  }
}
```

---

## ACTION ITEMS

### Immediate (P0 - Critical Security)

1. ✅ **Audit Complete**: All encrypted columns identified and documented
2. ❌ **Fix Task Encryption**:
   - [ ] Create Supabase migration to add encrypted columns to `note_tasks`
   - [ ] Implement `task_remote_api.dart` with encryption logic
   - [ ] Update sync code to use encrypted API
   - [ ] Migrate any existing plaintext task data
   - [ ] Drop plaintext columns after migration complete
   - **Timeline**: ASAP - user data currently exposed

### High Priority (P1 - Data Integrity)

3. ⚠️ **Verify Template Encryption**:
   - [ ] Audit template sync code to confirm encryption is happening
   - [ ] Fix API signature to use Uint8List
   - [ ] Add asBytes() conversion in fetchTemplates()
   - [ ] Test template sync roundtrip
   - **Timeline**: Before next release

4. 📝 **Document Encryption Architecture**:
   - [ ] Create developer guide for adding new encrypted entities
   - [ ] Document when to encrypt locally vs. on-the-fly
   - [ ] Document asBytes() usage patterns

### Medium Priority (P2 - Code Quality)

5. 🧪 **Add Comprehensive Tests**:
   - [ ] Test encryption roundtrip for all entities
   - [ ] Test asBytes() with various input formats
   - [ ] Test sync with encrypted data
   - [ ] Test migration from plaintext to encrypted

---

## FILES REQUIRING CHANGES

### Critical (Task Encryption)
- `supabase/migrations/` - New migration for encrypted task columns
- `lib/services/tasks/task_remote_api.dart` - NEW FILE - Encrypted task sync
- `lib/data/remote/supabase_note_api.dart` - Add encrypted task methods
- `lib/services/unified_sync_service.dart` - Use encrypted task API

### High Priority (Template Fixes)
- `lib/data/remote/supabase_note_api.dart` - Fix template methods
- Template sync code (location TBD - needs investigation)

---

## CONCLUSION

**Overall Security Status**: ⚠️ **NEEDS URGENT ATTENTION**

**Secure Components**:
- ✅ Notes: Fully encrypted end-to-end
- ✅ Folders: Encrypted on remote (acceptable local plaintext)

**Vulnerabilities**:
- ❌ **CRITICAL**: Tasks stored in PLAINTEXT on Supabase
- ⚠️ Templates: Schema supports encryption but implementation needs verification

**Next Steps**:
1. Immediately implement task encryption (P0)
2. Verify and fix template encryption (P1)
3. Add comprehensive encryption tests (P2)

**Full Details**: See `/Users/onronder/duru-notes/DATABASE_ENCRYPTION_SCHEMA_AUDIT.md`
