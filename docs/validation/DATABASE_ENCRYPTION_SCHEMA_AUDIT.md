# DATABASE ENCRYPTION SCHEMA AUDIT REPORT
**Date**: 2025-10-23
**Scope**: Complete analysis of all encrypted columns across local and remote database schemas

## EXECUTIVE SUMMARY

**CRITICAL FINDINGS**:
1. **MAJOR SCHEMA INCONSISTENCY**: Tasks are encrypted locally but stored PLAINTEXT on Supabase
2. **MAJOR SCHEMA INCONSISTENCY**: Folders/Templates are PLAINTEXT locally but expected encrypted on Supabase
3. **TYPE MISMATCH**: Remote uses `bytea`, local uses `TEXT` - conversion via `asBytes()` required
4. **INCOMPLETE IMPLEMENTATION**: note_blocks encrypted on Supabase but not implemented locally

---

## 1. NOTES TABLE

### Remote Schema (Supabase)
```sql
CREATE TABLE public.notes (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL,
  title_enc bytea NOT NULL,      -- ENCRYPTED
  props_enc bytea NOT NULL,      -- ENCRYPTED (contains body, tags, isPinned, etc.)
  encrypted_metadata jsonb,
  note_type integer DEFAULT 0,
  deleted boolean DEFAULT false,
  created_at timestamptz,
  updated_at timestamptz
);
```

**Encrypted Columns**: `title_enc`, `props_enc`
**Data Type**: `bytea` (binary data)
**Content**:
- `title_enc`: Encrypted note title (string)
- `props_enc`: Encrypted JSON object with `{body, tags, isPinned, folderId, ...}`

### Local Schema (Drift)
```dart
@DataClassName('LocalNote')
class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get titleEncrypted => text().named('title_encrypted')();  // ENCRYPTED
  TextColumn get bodyEncrypted => text().named('body_encrypted')();    // ENCRYPTED
  TextColumn get metadataEncrypted => text().named('metadata_encrypted').nullable()();
  IntColumn get encryptionVersion => integer().named('encryption_version')();
  // ... other fields
}
```

**Encrypted Columns**: `title_encrypted`, `body_encrypted`, `metadata_encrypted`
**Data Type**: `TEXT` (base64-encoded encrypted data)

### Data Flow Pattern

**Writing to Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:35
Future<void> upsertEncryptedNote({
  required String id,
  required Uint8List titleEnc,    // Binary data
  required Uint8List propsEnc,    // Binary data
  required bool deleted,
}) async {
  await _client.from('notes').upsert({
    'id': id,
    'user_id': _uid,
    'title_enc': titleEnc,  // Sent as Uint8List
    'props_enc': propsEnc,  // Sent as Uint8List
    'deleted': deleted,
  });
}
```

**Reading from Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:58
Future<List<Map<String, dynamic>>> fetchEncryptedNotes({DateTime? since}) async {
  final list = await _client
    .from('notes')
    .select('id, user_id, created_at, updated_at, title_enc, props_enc, deleted')
    .eq('user_id', _uid);

  // CRITICAL: Convert bytea to Uint8List
  for (final m in list) {
    if (m['title_enc'] != null) m['title_enc'] = asBytes(m['title_enc']);
    if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
  }
  return list;
}
```

**Conversion Method**: `asBytes()` at `/Users/onronder/duru-notes/lib/data/remote/supabase_note_api.dart:303`
- Handles multiple formats: Uint8List, List<int>, String (base64/hex), Map (libsodium JSON)
- Attempts UTF-8 decode then base64 decode for string data

### Assessment
✅ **CONSISTENT**: Both sides use encryption
✅ **CONVERSION**: `asBytes()` properly handles bytea → Uint8List conversion
⚠️ **SCHEMA DIFFERENCE**: Remote stores in `props_enc`, local separates into `body_encrypted` + `metadata_encrypted`

---

## 2. FOLDERS TABLE

### Remote Schema (Supabase)
```sql
CREATE TABLE public.folders (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL,
  name_enc bytea NOT NULL,       -- ENCRYPTED
  props_enc bytea NOT NULL,      -- ENCRYPTED (contains parentId, color, icon, description, sortOrder)
  deleted boolean DEFAULT false,
  created_at timestamptz,
  updated_at timestamptz
);
```

**Encrypted Columns**: `name_enc`, `props_enc`
**Data Type**: `bytea`
**Content**:
- `name_enc`: Encrypted folder name
- `props_enc`: Encrypted JSON with folder properties

### Local Schema (Drift)
```dart
@DataClassName('LocalFolder')
class LocalFolders extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text();                    // PLAINTEXT!
  TextColumn get parentId => text().nullable();     // PLAINTEXT!
  TextColumn get path => text();                    // PLAINTEXT!
  TextColumn get color => text().nullable();        // PLAINTEXT!
  TextColumn get icon => text().nullable();         // PLAINTEXT!
  TextColumn get description => text();             // PLAINTEXT!
  IntColumn get sortOrder => integer();
  DateTimeColumn get createdAt => dateTime();
  DateTimeColumn get updatedAt => dateTime();
  BoolColumn get deleted => boolean();
}
```

**Encrypted Columns**: **NONE**
**Data Type**: All TEXT - stored in plaintext

### Data Flow Pattern

**Writing to Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:111
Future<void> upsertEncryptedFolder({
  required String id,
  required Uint8List nameEnc,    // Expected encrypted
  required Uint8List propsEnc,   // Expected encrypted
  required bool deleted,
}) async {
  await _client.from('folders').upsert({
    'id': id,
    'user_id': _uid,
    'name_enc': nameEnc,
    'props_enc': propsEnc,
    'deleted': deleted,
  });
}
```

**Reading from Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:131
Future<List<Map<String, dynamic>>> fetchEncryptedFolders({DateTime? since}) async {
  final list = await _client
    .from('folders')
    .select('id, user_id, created_at, updated_at, name_enc, props_enc, deleted');

  // CRITICAL: Convert bytea to Uint8List
  for (final m in list) {
    if (m['name_enc'] != null) m['name_enc'] = asBytes(m['name_enc']);
    if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
  }
  return list;
}
```

### Assessment
❌ **CRITICAL INCONSISTENCY**: Remote expects encrypted data, local stores PLAINTEXT
⚠️ **SECURITY RISK**: Folder names and properties are NOT encrypted in local database
⚠️ **SYNC FAILURE**: Folder sync likely broken - local plaintext cannot be sent as encrypted to remote

---

## 3. TASKS TABLE (note_tasks)

### Remote Schema (Supabase)
```sql
CREATE TABLE public.note_tasks (
  id uuid PRIMARY KEY,
  note_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL,           -- PLAINTEXT!
  status text DEFAULT 'pending',
  priority integer DEFAULT 0,
  position integer DEFAULT 0,
  due_date timestamptz,
  completed_at timestamptz,
  parent_id uuid,
  labels jsonb DEFAULT '[]',       -- PLAINTEXT!
  metadata jsonb DEFAULT '{}',     -- PLAINTEXT!
  deleted boolean DEFAULT false,
  created_at timestamptz,
  updated_at timestamptz
);
```

**Encrypted Columns**: **NONE**
**Data Type**: All TEXT/JSONB - stored in plaintext

### Local Schema (Drift)
```dart
@DataClassName('NoteTask')
class NoteTasks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get contentEncrypted => text().named('content_encrypted')();  // ENCRYPTED
  TextColumn get labelsEncrypted => text().named('labels_encrypted').nullable()();  // ENCRYPTED
  TextColumn get notesEncrypted => text().named('notes_encrypted').nullable()();    // ENCRYPTED
  IntColumn get encryptionVersion => integer().named('encryption_version')();
  IntColumn get status => intEnum<TaskStatus>();
  IntColumn get priority => intEnum<TaskPriority>();
  DateTimeColumn get dueDate => dateTime().nullable();
  // ... other fields
}
```

**Encrypted Columns**: `content_encrypted`, `labels_encrypted`, `notes_encrypted`
**Data Type**: TEXT (base64-encoded encrypted data)

### Data Flow Pattern

**Writing to Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:465
Future<void> upsertNoteTask({
  required String id,
  required String noteId,
  required String content,       // PLAINTEXT expected
  required String status,
  Map<String, dynamic>? labels,  // PLAINTEXT expected
  Map<String, dynamic>? metadata, // PLAINTEXT expected
  bool deleted = false,
}) async {
  await _client.from('note_tasks').upsert({
    'id': id,
    'note_id': noteId,
    'content': content,           // Sent as plaintext
    'labels': labels ?? {},       // Sent as plaintext
    'metadata': metadata ?? {},   // Sent as plaintext
    // ...
  });
}
```

**Reading from Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:424
Future<List<Map<String, dynamic>>> fetchNoteTasks({DateTime? since}) async {
  return await _client
    .from('note_tasks')
    .select('id, note_id, content, status, labels, metadata, ...')
    .eq('user_id', _uid);
  // NO asBytes() conversion - data is plaintext
}
```

### Assessment
❌ **CRITICAL INCONSISTENCY**: Local encrypts data, remote expects PLAINTEXT
❌ **SECURITY BREACH**: Task data is stored UNENCRYPTED on Supabase
❌ **SYNC FAILURE**: Sync code likely sends encrypted data to plaintext columns or vice versa

---

## 4. TEMPLATES TABLE

### Remote Schema (Supabase)
```sql
CREATE TABLE public.templates (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL,
  title_enc bytea NOT NULL,          -- ENCRYPTED
  body_enc bytea NOT NULL,           -- ENCRYPTED
  tags_enc bytea,                    -- ENCRYPTED
  description_enc bytea,             -- ENCRYPTED
  category text,
  icon text,
  sort_order integer DEFAULT 0,
  props_enc bytea,                   -- ENCRYPTED
  is_system boolean DEFAULT false,
  deleted boolean DEFAULT false,
  created_at timestamptz,
  updated_at timestamptz
);
```

**Encrypted Columns**: `title_enc`, `body_enc`, `tags_enc`, `description_enc`, `props_enc`
**Data Type**: `bytea`

### Local Schema (Drift)
```dart
@DataClassName('LocalTemplate')
class LocalTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable();
  TextColumn get title => text();              // PLAINTEXT!
  TextColumn get body => text();               // PLAINTEXT!
  TextColumn get tags => text();               // PLAINTEXT!
  TextColumn get description => text();        // PLAINTEXT!
  TextColumn get category => text();
  TextColumn get icon => text();
  TextColumn get metadata => text().nullable(); // PLAINTEXT!
  IntColumn get sortOrder => integer();
  BoolColumn get isSystem => boolean();
  DateTimeColumn get createdAt => dateTime();
  DateTimeColumn get updatedAt => dateTime();
}
```

**Encrypted Columns**: **NONE**
**Data Type**: All TEXT - stored in plaintext

### Data Flow Pattern

**Writing to Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:535
Future<void> upsertTemplate({
  required String id,
  required String titleEnc,       // Expected as STRING (not Uint8List!)
  required String bodyEnc,        // Expected as STRING
  String? tagsEnc,                // Expected as STRING
  String? descriptionEnc,         // Expected as STRING
  String? propsEnc,               // Expected as STRING
  // ...
}) async {
  await _client.from('templates').upsert({
    'title_enc': titleEnc,        // Sent as string
    'body_enc': bodyEnc,          // Sent as string
    'tags_enc': tagsEnc,
    'description_enc': descriptionEnc,
    'props_enc': propsEnc,
  });
}
```

**Reading from Supabase**:
```dart
// lib/data/remote/supabase_note_api.dart:516
Future<List<Map<String, dynamic>>> fetchTemplates({DateTime? since}) async {
  return await _client
    .from('templates')
    .select('id, title_enc, body_enc, tags_enc, description_enc, props_enc, ...')
    .eq('user_id', _uid);
  // NO asBytes() conversion!
}
```

### Assessment
❌ **CRITICAL INCONSISTENCY**: Remote expects bytea encrypted data, local stores PLAINTEXT
⚠️ **TYPE MISMATCH**: API accepts STRING but Supabase expects bytea
⚠️ **SECURITY RISK**: Template content is NOT encrypted in local database
❌ **SYNC FAILURE**: Template sync likely broken - plaintext cannot be stored in bytea columns

---

## 5. NOTE_BLOCKS TABLE

### Remote Schema (Supabase)
```sql
CREATE TABLE public.note_blocks (
  id uuid PRIMARY KEY,
  note_id uuid NOT NULL,
  user_id uuid NOT NULL,
  idx integer NOT NULL,
  type text NOT NULL,
  content_enc bytea NOT NULL,     -- ENCRYPTED
  attrs_enc bytea,                -- ENCRYPTED
  created_at timestamptz,
  updated_at timestamptz
);
```

**Encrypted Columns**: `content_enc`, `attrs_enc`
**Data Type**: `bytea`

### Local Schema (Drift)
**NOT IMPLEMENTED** - No LocalBlocks table exists

### Assessment
⚠️ **INCOMPLETE**: Feature exists on Supabase but not implemented locally
⚠️ **UNUSED**: Likely feature-flagged or deprecated

---

## 6. COMPLETE ENCRYPTED COLUMN INVENTORY

| Table | Remote Column | Remote Type | Local Column | Local Type | Conversion | Status |
|-------|---------------|-------------|--------------|------------|------------|--------|
| **notes** | title_enc | bytea | title_encrypted | TEXT | asBytes() | ✅ Consistent |
| **notes** | props_enc | bytea | body_encrypted, metadata_encrypted | TEXT | asBytes() | ⚠️ Schema diff |
| **folders** | name_enc | bytea | name | TEXT | asBytes() | ❌ Local plaintext |
| **folders** | props_enc | bytea | (multiple fields) | TEXT | asBytes() | ❌ Local plaintext |
| **note_tasks** | content | text | content_encrypted | TEXT | None | ❌ Remote plaintext |
| **note_tasks** | labels | jsonb | labels_encrypted | TEXT | None | ❌ Remote plaintext |
| **note_tasks** | metadata | jsonb | notes_encrypted | TEXT | None | ❌ Remote plaintext |
| **templates** | title_enc | bytea | title | TEXT | None | ❌ Local plaintext |
| **templates** | body_enc | bytea | body | TEXT | None | ❌ Local plaintext |
| **templates** | tags_enc | bytea | tags | TEXT | None | ❌ Local plaintext |
| **templates** | description_enc | bytea | description | TEXT | None | ❌ Local plaintext |
| **templates** | props_enc | bytea | metadata | TEXT | None | ❌ Local plaintext |
| **note_blocks** | content_enc | bytea | N/A | N/A | N/A | ⚠️ Not implemented |
| **note_blocks** | attrs_enc | bytea | N/A | N/A | N/A | ⚠️ Not implemented |

---

## 7. DATA TYPE CONSISTENCY ANALYSIS

### Remote Database (Supabase PostgreSQL)
- **All encrypted columns**: `bytea` type
- **Binary data**: Stored as PostgreSQL bytea (binary array)
- **Wire format**: May return as:
  - Uint8List (native binary)
  - List<int> (JSON array of bytes)
  - String (hex format `\xABCD...` or base64)
  - Map (libsodium JSON `{n: "nonce", c: "ciphertext", m: "mac"}`)

### Local Database (Drift SQLite)
- **All encrypted columns**: `TEXT` type
- **Encoding**: Base64-encoded encrypted binary data
- **Storage**: String representation of encrypted bytes

### Conversion Requirements
**For all encrypted data flowing FROM Supabase**:
```dart
// Must use asBytes() to convert bytea → Uint8List
final bytes = SupabaseNoteApi.asBytes(row['column_enc']);
```

**For all encrypted data flowing TO Supabase**:
```dart
// Must provide Uint8List (from local base64 or encryption)
final bytes = base64Decode(localEncrypted); // or encrypt() result
await api.upsertEncrypted(bytes: bytes);
```

---

## 8. QUERY PATTERN ANALYSIS

### Notes - Uses asBytes() ✅
```dart
// lib/data/remote/supabase_note_api.dart:76-80
for (final m in list) {
  if (m['title_enc'] != null) m['title_enc'] = asBytes(m['title_enc']);
  if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
}
```

### Folders - Uses asBytes() ✅
```dart
// lib/data/remote/supabase_note_api.dart:149-153
for (final m in list) {
  if (m['name_enc'] != null) m['name_enc'] = asBytes(m['name_enc']);
  if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
}
```

### Tasks - NO conversion ❌
```dart
// lib/data/remote/supabase_note_api.dart:424-439
// Fetches plaintext directly, no asBytes() conversion
final res = await _client
  .from('note_tasks')
  .select('content, labels, metadata, ...');
// Returns plaintext - no encryption handling
```

### Templates - NO conversion ❌
```dart
// lib/data/remote/supabase_note_api.dart:516-532
// Fetches columns but does NOT convert bytea
final res = await _client
  .from('templates')
  .select('title_enc, body_enc, tags_enc, ...');
// Missing asBytes() conversion - will fail or return wrong format
```

---

## 9. CRITICAL BUGS IDENTIFIED

### BUG #1: Tasks Schema Mismatch
**Location**: note_tasks table
**Issue**: Local encrypts (`content_encrypted`), remote expects plaintext (`content text`)
**Impact**:
- Task data stored UNENCRYPTED on Supabase
- Sync will either fail or send encrypted data to plaintext column
- SECURITY BREACH: All task content visible in database

**Fix Required**:
```sql
-- Option A: Encrypt remote (RECOMMENDED)
ALTER TABLE note_tasks
  ADD COLUMN content_enc bytea,
  ADD COLUMN labels_enc bytea,
  ADD COLUMN notes_enc bytea;
-- Migrate existing data
-- Drop plaintext columns

-- Option B: Decrypt local (NOT RECOMMENDED - security downgrade)
-- Remove encryption from local schema
```

### BUG #2: Folders Not Encrypted Locally
**Location**: LocalFolders table
**Issue**: Local stores plaintext, remote expects encrypted bytea
**Impact**:
- Folder names/properties NOT encrypted at rest locally
- Sync code must encrypt on-the-fly before sending to Supabase
- Inconsistent with zero-knowledge architecture

**Fix Required**:
```dart
// Add encrypted columns to LocalFolders
class LocalFolders extends Table {
  TextColumn get nameEncrypted => text().named('name_encrypted')();
  TextColumn get propsEncrypted => text().named('props_encrypted')();
  // Migrate existing plaintext data to encrypted format
}
```

### BUG #3: Templates Not Encrypted Locally
**Location**: LocalTemplates table
**Issue**: Local stores plaintext, remote expects encrypted bytea
**Impact**:
- Template content NOT encrypted at rest locally
- API uses STRING instead of Uint8List for encrypted columns
- Type mismatch will cause insertion failures

**Fix Required**:
```dart
// Add encrypted columns to LocalTemplates
class LocalTemplates extends Table {
  TextColumn get titleEncrypted => text().named('title_encrypted')();
  TextColumn get bodyEncrypted => text().named('body_encrypted')();
  TextColumn get tagsEncrypted => text().named('tags_encrypted').nullable()();
  TextColumn get descriptionEncrypted => text().named('description_encrypted').nullable()();
  TextColumn get propsEncrypted => text().named('props_encrypted').nullable()();
}

// Fix API to use Uint8List
Future<void> upsertTemplate({
  required Uint8List titleEnc,  // Change from String
  required Uint8List bodyEnc,   // Change from String
  // ...
});
```

### BUG #4: Templates Missing asBytes() Conversion
**Location**: `/Users/onronder/duru-notes/lib/data/remote/supabase_note_api.dart:516`
**Issue**: fetchTemplates() does not convert bytea columns to Uint8List
**Impact**: Downstream code receives wrong data type, will fail to decrypt

**Fix Required**:
```dart
Future<List<Map<String, dynamic>>> fetchTemplates({DateTime? since}) async {
  final list = await _client.from('templates').select(...);

  // ADD THIS:
  for (final m in list) {
    if (m['title_enc'] != null) m['title_enc'] = asBytes(m['title_enc']);
    if (m['body_enc'] != null) m['body_enc'] = asBytes(m['body_enc']);
    if (m['tags_enc'] != null) m['tags_enc'] = asBytes(m['tags_enc']);
    if (m['description_enc'] != null) m['description_enc'] = asBytes(m['description_enc']);
    if (m['props_enc'] != null) m['props_enc'] = asBytes(m['props_enc']);
  }
  return list;
}
```

---

## 10. RECOMMENDATIONS

### Immediate Actions (P0 - Critical Security)

1. **Fix Task Encryption Schema** (HIGHEST PRIORITY)
   - Add encrypted columns to Supabase note_tasks table
   - Migrate existing plaintext task data to encrypted format
   - Update sync code to handle encrypted task data
   - **RISK**: All user task data currently exposed in plaintext on server

2. **Fix Folder Encryption Locally**
   - Add encrypted columns to LocalFolders table
   - Implement encryption/decryption in folder repository
   - Migrate existing folder data to encrypted format
   - Verify sync code properly encrypts before sending to Supabase

3. **Fix Template Encryption Locally**
   - Add encrypted columns to LocalTemplates table
   - Fix API signature to use Uint8List instead of String
   - Add asBytes() conversion in fetchTemplates()
   - Implement encryption/decryption in template repository

### Medium Priority (P1 - Data Integrity)

4. **Standardize Encryption Patterns**
   - Create unified encryption helper for all entities
   - Ensure consistent use of CryptoBox across all tables
   - Document encryption format for each column

5. **Add Comprehensive Tests**
   - Test encryption roundtrip for each entity type
   - Test asBytes() conversion for all bytea columns
   - Test sync with encrypted data for all tables
   - Verify local-remote schema compatibility

### Long Term (P2 - Architecture)

6. **Schema Migration Strategy**
   - Plan backward-compatible migration for production data
   - Consider online migration vs. maintenance window
   - Implement rollback procedures

7. **Audit Logging**
   - Log encryption/decryption failures
   - Monitor for plaintext data leaks
   - Track migration progress

---

## 11. FILES REQUIRING CHANGES

### Schema Migrations
- `/Users/onronder/duru-notes/supabase/migrations/` - New migration for task encryption
- `/Users/onronder/duru-notes/lib/data/local/app_db.dart` - Add encrypted columns to LocalFolders, LocalTemplates

### Data Layer
- `/Users/onronder/duru-notes/lib/data/remote/supabase_note_api.dart` - Fix template API, add asBytes() for templates
- `/Users/onronder/duru-notes/lib/infrastructure/repositories/folder_core_repository.dart` - Add encryption
- `/Users/onronder/duru-notes/lib/infrastructure/repositories/template_core_repository.dart` - Add encryption
- `/Users/onronder/duru-notes/lib/infrastructure/repositories/task_core_repository.dart` - Update for remote encryption

### Mappers
- `/Users/onronder/duru-notes/lib/infrastructure/mappers/folder_mapper.dart` - Handle encrypted data
- `/Users/onronder/duru-notes/lib/infrastructure/mappers/task_mapper.dart` - Update for remote encryption

### Sync
- `/Users/onronder/duru-notes/lib/services/unified_sync_service.dart` - Fix folder/template/task sync

---

## CONCLUSION

The current implementation has **CRITICAL SECURITY VULNERABILITIES**:

1. ❌ **Task data stored in PLAINTEXT on Supabase** - immediate security breach
2. ❌ **Folder/template data stored in PLAINTEXT locally** - violates zero-knowledge architecture
3. ❌ **Schema mismatches prevent proper encryption** - sync likely broken or leaking plaintext

**All three major issues (tasks, folders, templates) must be fixed before production deployment.**

The notes table is the ONLY entity properly encrypted on both sides.
