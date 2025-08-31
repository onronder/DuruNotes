# Encryption & Indexing Verification for Import System

This document outlines the comprehensive testing strategy to verify that the ImportService properly integrates with the encryption and indexing systems after importing notes.

## Overview

The import system must ensure that:

1. **Encryption**: All imported notes are properly encrypted when stored in the database
2. **Indexing**: All imported notes are properly indexed for search functionality
3. **Integration**: `NotesRepository.createOrUpdate` and `NoteIndexer.indexNote` are called correctly

## Architecture

### Import Flow
```
ImportService.importMarkdown/Enex/Obsidian
    ↓
_createNoteWithValidation
    ↓
NotesRepository.createOrUpdate (encrypts and stores)
    ↓
NoteIndexer.indexNote (indexes for search)
```

### Encryption Layer
- **KeyManager**: Manages per-user master keys stored in secure storage
- **CryptoBox**: Handles encryption/decryption using XChaCha20-Poly1305
- **NotesRepository**: Encrypts notes before remote storage, keeps local copies unencrypted

### Indexing Layer
- **NoteIndexer**: Maintains in-memory search indexes
- **Tag Indexing**: Extracts and indexes #hashtags and @mentions
- **Word Indexing**: Indexes searchable words (3+ characters)
- **Link Indexing**: Indexes [[note-links]] for cross-referencing

## Test Coverage

### Unit Tests (`test/services/import_encryption_indexing_test.dart`)

**Purpose**: Verify ImportService integration with mocked dependencies

**Tests**:
- ✅ `importMarkdown` calls `NotesRepository.createOrUpdate`
- ✅ `importMarkdown` calls `NoteIndexer.indexNote` 
- ✅ Repository errors are handled gracefully
- ✅ Indexer errors don't break imports
- ✅ ENEX imports call repository/indexer for each note
- ✅ Obsidian imports call repository/indexer for each file
- ✅ Encryption roundtrip works for imported notes
- ✅ Search indexing works for imported notes

### Integration Tests (`integration_test/import_encryption_indexing_test.dart`)

**Purpose**: End-to-end verification with real database and encryption

**Tests**:
- ✅ Markdown import creates encrypted, indexed notes
- ✅ Multiple imports maintain separate encryption
- ✅ ENEX import creates encrypted, indexed notes
- ✅ Obsidian vault import creates encrypted, indexed notes
- ✅ Failed imports don't corrupt encryption/indexing
- ✅ Different users get different encryption keys
- ✅ Search functionality works across imported notes
- ✅ Tag/link indexing works correctly

## Encryption Verification

### What We Test

1. **Key Generation**: Each user gets unique master keys
2. **Note Encryption**: Title and body are encrypted with note-specific derived keys
3. **Encryption Uniqueness**: Same plaintext produces different ciphertext (nonces)
4. **Decryption Integrity**: Encrypted data can be properly decrypted
5. **User Isolation**: Users cannot decrypt each other's notes

### How It Works

```dart
// 1. Master key per user
final masterKey = await keyManager.getOrCreateMasterKey(userId);

// 2. Note-specific key derivation  
final noteKey = await hkdf.deriveKey(
  secretKey: masterKey, 
  nonce: utf8.encode('note:$noteId')
);

// 3. Encrypt with XChaCha20-Poly1305
final encrypted = await cipher.encrypt(
  plaintext, 
  secretKey: noteKey, 
  nonce: randomNonce
);
```

## Indexing Verification

### What We Test

1. **Word Indexing**: Notes are searchable by content words
2. **Tag Indexing**: #hashtags and @mentions are indexed
3. **Link Indexing**: [[note-links]] are indexed for backlinks
4. **Search Queries**: Multi-word searches work correctly
5. **Index Statistics**: Proper counts of indexed items
6. **Index Cleanup**: Deleted notes are removed from indexes

### How It Works

```dart
// 1. Extract searchable elements
final words = extractWords(note.title + ' ' + note.body);
final tags = extractTags(note.body); // #tag, @mention
final links = extractLinks(note.body); // [[link]]

// 2. Update indexes
for (final word in words) {
  wordIndex[word.toLowerCase()].add(note.id);
}
for (final tag in tags) {
  tagIndex[tag.toLowerCase()].add(note.id);
}
for (final link in links) {
  linkIndex[link].add(note.id);
}
```

## Running Tests

### Quick Test
```bash
# Run all encryption/indexing tests
dart duru_notes_app/test/run_encryption_indexing_tests.dart
```

### Individual Tests
```bash
# Unit tests only
flutter test duru_notes_app/test/services/import_encryption_indexing_test.dart

# Integration tests only  
flutter test integration_test/import_encryption_indexing_test.dart
```

### Test Output
The tests will verify:
- ✅ All imports call both repository and indexer
- ✅ Notes are properly encrypted with unique keys
- ✅ Notes are searchable after import
- ✅ Tags and links are indexed correctly
- ✅ Error handling preserves system integrity

## Troubleshooting

### Common Issues

1. **Missing Mock Generation**
   ```bash
   flutter packages pub run build_runner build
   ```

2. **Database Schema Issues**
   - Clear test database: `flutter test --delete-conflicting-outputs`

3. **Encryption Key Issues**
   - Tests use in-memory keys that are automatically cleaned up

4. **Index Corruption**
   - Tests clear indexes between runs

### Debug Mode

Add verbose logging to see detailed test execution:

```dart
// In test setup
when(mockLogger.debug(any, data: anyNamed('data')))
  .thenAnswer((invocation) {
    print('DEBUG: ${invocation.positionalArguments[0]}');
    print('DATA: ${invocation.namedArguments[#data]}');
  });
```

## Continuous Integration

These tests should be run in CI/CD to ensure:
- Import system maintains encryption integrity
- Search functionality works after imports
- No regressions in security or indexing
- Cross-platform compatibility (iOS/Android)

## Security Considerations

### Encryption
- Master keys are stored in platform secure storage (Keychain/KeyStore)
- Note-specific keys are derived, never stored
- Nonces are random for each encryption operation
- Failed decryption throws exceptions (no silent failures)

### Indexing
- Search indexes are kept in memory only
- No sensitive content is logged during indexing
- Indexes are rebuilt from encrypted local database on app start
- Cross-note references don't leak content

## Performance Considerations

### Encryption
- Key derivation uses HKDF (fast)
- Encryption is per-note, not per-block
- Batch operations minimize key derivation overhead

### Indexing
- In-memory indexes for fast search
- Incremental indexing (only changed notes)
- Word indexing limited to 3+ character words
- Index statistics for monitoring performance

## Future Enhancements

1. **Encrypted Search**: Search over encrypted content
2. **Index Persistence**: Store encrypted search indexes
3. **Batch Indexing**: Optimize for large imports
4. **Index Compression**: Reduce memory usage for large note collections
