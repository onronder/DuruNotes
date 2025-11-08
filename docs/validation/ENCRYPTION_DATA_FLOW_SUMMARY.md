# ENCRYPTION DATA FLOW SUMMARY

Visual summary of how encrypted data flows through the system.

---

## SUPABASE → APP DATA FLOW

```
┌─────────────────────────────────────────────────────────────────┐
│                         SUPABASE                                 │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐    │
│  │  notes   │  │ folders  │  │ templates │  │ note_tasks │    │
│  │          │  │          │  │           │  │            │    │
│  │title_enc │  │ name_enc │  │ title_enc │  │content_enc │    │
│  │props_enc │  │props_enc │  │ body_enc  │  │ attrs_enc  │    │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘  └──────┬─────┘    │
└───────┼─────────────┼───────────────┼────────────────┼──────────┘
        │             │               │                │
        │ bytea       │ bytea         │ bytea          │ bytea
        │ as          │ as            │ as             │ as
        │ List<int>   │ List<int>     │ String?        │ String?
        │ of base64   │ of base64     │ (base64)       │ (JSON)
        ▼             ▼               ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FETCH OPERATIONS                              │
│                                                                  │
│ fetchEncryptedNotes()  fetchEncryptedFolders()                  │
│          │                     │                                 │
│          │                     │         fetchTemplates()        │
│          │                     │                │                │
│          ▼                     ▼                ▼                │
│     ┌────────┐           ┌────────┐       ┌────────┐           │
│     │asBytes │           │asBytes │       │  ??? → │           │
│     │  ✅    │           │  ✅    │       │utf8.enc│           │
│     └────┬───┘           └────┬───┘       └────┬───┘           │
│          │                     │                │                │
└──────────┼─────────────────────┼────────────────┼────────────────┘
           │                     │                │
           │ Uint8List           │ Uint8List      │ Uint8List
           │ (raw bytes)         │ (raw bytes)    │ (double-enc?)
           ▼                     ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DECRYPTION LAYER                              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ CryptoBox                                                 │  │
│  │                                                           │  │
│  │  decryptStringForNote() ← Notes (title)                  │  │
│  │  decryptJsonForNote()   ← Notes (props), Folders, Tasks  │  │
│  │                                                           │  │
│  │  _deserializeSecretBox() ← Internal format handler       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
           │
           │ Decrypted plaintext
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DOMAIN ENTITIES                             │
│                                                                  │
│     Note        Folder       Template       Task                │
│   (plaintext) (plaintext)  (plaintext)   (plaintext)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## BUG PATTERN COMPARISON

### ❌ BEFORE FIX (Broken Notes)
```
Supabase bytea column
  → List<int> [101, 121, 74, ...]  (bytes of "eyJ...")
    → UTF-8 decode → "eyJ..." (base64 string)
      → ❌ Pass to decrypt as-is
        → ❌ Decrypt tries to use "eyJ..." as encrypted bytes
          → ❌ FAILS: "eyJ..." is not valid encrypted data
```

### ✅ AFTER FIX (Working Notes)
```
Supabase bytea column
  → List<int> [101, 121, 74, ...]  (bytes of "eyJ...")
    → UTF-8 decode → "eyJ..." (base64 string)
      → ✅ Detect base64 pattern
        → ✅ base64Decode("eyJ...") → Uint8List [actual encrypted bytes]
          → ✅ Pass to decrypt
            → ✅ SUCCESS: Decrypts correctly
```

---

## ENTITY STATUS TABLE

| Entity | Supabase Table | Encrypted Columns | Format From DB | Processing | Status |
|--------|----------------|-------------------|----------------|------------|--------|
| **Notes** | `notes` | title_enc, props_enc | List<int> of base64 | asBytes() ✅ | ✅ FIXED |
| **Folders** | `folders` | name_enc, props_enc | List<int> of base64 | asBytes() ✅ | ✅ PROTECTED |
| **Templates** | `templates` | title_enc, body_enc, tags_enc, description_enc, props_enc | String? (likely base64) | utf8.encode() ❌ | 🔴 VULNERABLE |
| **Tasks** | `note_tasks` | content_enc, attrs_enc | String (JSON) | Local DB ✅ | ✅ SAFE |
| **Inbox** | `clipper_inbox` | N/A | N/A | N/A | ✅ NOT ENCRYPTED |
| **Searches** | `saved_searches` | N/A | N/A | N/A | ✅ LOCAL ONLY |
| **Attachments** | N/A | N/A | N/A | N/A | ⚠️ NOT IMPL |

---

## CODE LOCATION MAP

### Entry Points (Supabase Fetch)
```
lib/data/remote/supabase_note_api.dart
├── fetchEncryptedNotes()      [Line 58]   → Notes    ✅
├── fetchEncryptedFolders()    [Line 131]  → Folders  ✅
├── fetchTemplates()           [Line 516]  → Templates 🔴
└── fetchNoteTasks()           [Line 450]  → Tasks    ✅
```

### Format Converters
```
lib/data/remote/supabase_note_api.dart
└── asBytes()                  [Line 303]  → THE FIX ✅

lib/infrastructure/repositories/notes_core_repository.dart
└── _decryptTemplateField()    [Line 500]  → NEEDS FIX 🔴
```

### Decryption Endpoints
```
lib/services/sync/folder_remote_api.dart
└── _decryptFolderRow()        [Line 98]   → Uses asBytes() ✅

lib/services/unified_sync_service.dart
└── downloadLatestDataFromSupabase() [Line 1150] → Uses asBytes() ✅

lib/infrastructure/repositories/task_core_repository.dart
└── _decryptTask()             [Line 54]   → Local DB ✅

lib/infrastructure/repositories/notes_core_repository.dart
└── _applyRemoteTemplate()     [Line 1289] → Calls _decryptTemplateField() 🔴
```

---

## THE CRITICAL DIFFERENCE

### Working Code (Notes & Folders)
```dart
// Step 1: Fetch from Supabase
final rows = await api.fetchEncryptedNotes();

// Step 2: Extract encrypted column
final titleEnc = row['title_enc'];  // List<int> or dynamic

// Step 3: Normalize format with asBytes() ✅
final data = SupabaseNoteApi.asBytes(titleEnc);
//   → Detects List<int>
//   → Decodes UTF-8 → "eyJ..." (base64 string)
//   → Detects base64 pattern
//   → base64Decodes → Uint8List (actual encrypted bytes)

// Step 4: Decrypt
final title = await crypto.decryptStringForNote(data: data);
//   → Receives correct encrypted bytes
//   → SUCCESS! ✅
```

### Broken Code (Templates)
```dart
// Step 1: Fetch from Supabase
final rows = await api.fetchTemplates();

// Step 2: Extract encrypted column
final titleEnc = row['title_enc'] as String?;  // "eyJ..." (base64 string)

// Step 3: Convert to bytes ❌
final data = Uint8List.fromList(utf8.encode(titleEnc));
//   → Takes base64 string "eyJ..."
//   → Encodes to UTF-8 bytes [101, 121, 74, ...]
//   → This is bytes OF the base64 string, not the encrypted data!

// Step 4: Try to decrypt
final title = await crypto.decryptStringForNote(data: data);
//   → Receives bytes of "eyJ..." instead of encrypted bytes
//   → FAILURE! ❌
```

---

## VISUAL: THE BUG

```
┌──────────────────────────────────────────────────────────────────┐
│                    WHAT SUPABASE STORES                          │
│                                                                  │
│  Encrypted Data (binary): [0x1A, 0x2B, 0x3C, 0x4D, ...]        │
│         ↓                                                        │
│  Base64 Encode: "Gis8TQ==" (for storage/transport)             │
│         ↓                                                        │
│  PostgreSQL bytea column stores: "Gis8TQ=="                     │
└──────────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────────┐
│              WHAT SUPABASE RETURNS (THE PROBLEM)                 │
│                                                                  │
│  Option A: List<int> [71, 105, 115, 56, 84, 81, 61, 61]        │
│            ↑ These are bytes of the STRING "Gis8TQ=="           │
│            ↑ NOT the actual encrypted bytes!                     │
│                                                                  │
│  Option B: String "Gis8TQ==" (base64 encoded)                   │
└──────────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────────┐
│                       THE FIX                                    │
│                                                                  │
│  asBytes() detects this and does:                               │
│    1. If List<int>: Convert to Uint8List                        │
│    2. UTF-8 decode → "Gis8TQ==" (string)                        │
│    3. Detect base64 pattern → YES                               │
│    4. base64Decode("Gis8TQ==") → [0x1A, 0x2B, 0x3C, 0x4D]      │
│    5. Return correct encrypted bytes ✅                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## WHY TEMPLATES MAY BE BROKEN

Looking at the code:

```dart
// templates come from:
final remoteTemplates = await _secureApi.fetchTemplates();

// Then decoded via:
final title = await _decryptTemplateField(
  encrypted: remoteTemplate['title_enc'] as String?,  // ← Cast to String?
  userId: userId,
  templateId: templateId,
);

// Inside _decryptTemplateField:
final data = Uint8List.fromList(utf8.encode(encrypted));  // ← BUG!
```

**Problem**: If `title_enc` comes as a base64 string (like notes did), then:
1. `utf8.encode("eyJ...")` → bytes of the string
2. Decrypt receives wrong format
3. Decryption fails ❌

**Solution**: Use `asBytes()` instead:
```dart
final data = SupabaseNoteApi.asBytes(encrypted);  // ✅ Handles all formats
```

---

## TESTING THE FIX

### Quick Test Script
```dart
// Test current behavior
void testTemplateEncryption() async {
  final templates = await api.fetchTemplates();
  final template = templates.first;

  print('title_enc type: ${template['title_enc'].runtimeType}');
  print('title_enc value: ${template['title_enc']}');

  // Try current method
  try {
    final titleOld = await _decryptTemplateField(
      encrypted: template['title_enc'] as String?,
      userId: userId,
      templateId: template['id'],
    );
    print('Old method SUCCESS: $titleOld');
  } catch (e) {
    print('Old method FAILED: $e');  // ← Expect this
  }

  // Try fixed method
  try {
    final data = SupabaseNoteApi.asBytes(template['title_enc']);
    final titleNew = await crypto.decryptStringForNote(
      userId: userId,
      noteId: template['id'],
      data: data,
    );
    print('New method SUCCESS: $titleNew');  // ← Should work
  } catch (e) {
    print('New method FAILED: $e');
  }
}
```

---

## SUCCESS METRICS

### Before Fix (Expected)
- Notes: ❌ Decryption failures
- Folders: ❌ Decryption failures
- Templates: ❌ Decryption failures

### After Notes Fix (Current)
- Notes: ✅ Working (asBytes() applied)
- Folders: ✅ Working (uses asBytes())
- Templates: ❌ Still broken (doesn't use asBytes())

### After Template Fix (Goal)
- Notes: ✅ Working
- Folders: ✅ Working
- Templates: ✅ Working (asBytes() applied)

---

**Summary**: The bug is consistent across all encrypted entities that fetch from Supabase. The fix is simple: use `SupabaseNoteApi.asBytes()` instead of `utf8.encode()`.
