# Database Audit Fixes - Production Implementation

## Immediate Actions Required

### 1. Fix Web Clipper Database Issue
```sql
-- Check if alias exists
SELECT * FROM inbound_aliases WHERE alias = 'note_test1234';

-- If not exists, insert it
INSERT INTO inbound_aliases (alias, user_id) 
VALUES ('note_test1234', '49b58975-6446-4482-bed5-5c6b0ec46675')
ON CONFLICT (alias) DO UPDATE SET user_id = EXCLUDED.user_id;
```

### 2. Fix Existing Notes for Filter Compatibility
```sql
-- Add tags to existing email notes
UPDATE notes 
SET body = body || E'\n\n#Email'
WHERE id IN (
  SELECT id FROM notes 
  WHERE encrypted_metadata::text LIKE '%"source":"email%'
  AND body NOT LIKE '%#Email%'
);

-- Add tags to existing web clips
UPDATE notes 
SET body = body || E'\n\n#Web'
WHERE id IN (
  SELECT id FROM notes 
  WHERE encrypted_metadata::text LIKE '%"source":"web%'
  AND body NOT LIKE '%#Web%'
);
```

### 3. Implement Tag Indexing

Add to `NotesRepository.createOrUpdate()`:
```dart
// After note is saved
final tags = NoteIndexer.extractTags(body);
if (tags.isNotEmpty) {
  await db.replaceTagsForNote(noteId, tags);
}
```

### 4. Fix Folder Sync Issues

Add to `lib/repository/notes_repository.dart`:
```dart
// Add stream controller for folder updates
final _folderUpdateController = StreamController<void>.broadcast();
Stream<void> get folderUpdates => _folderUpdateController.stream;

// In pullFoldersSince() after updating folders
_folderUpdateController.add(null); // Trigger UI refresh
```

### 5. Implement Device Tracking

```dart
// Add to app initialization
Future<void> registerDevice() async {
  final deviceInfo = await DeviceInfoPlugin().deviceInfo;
  await supabase.from('devices').upsert({
    'user_id': userId,
    'device_id': deviceInfo.id,
    'device_name': deviceInfo.name,
    'platform': Platform.operatingSystem,
    'last_seen': DateTime.now().toIso8601String(),
  });
}
```

## Code Changes Applied

### Fixed Filter Metadata Check
- Updated `lib/ui/note_search_delegate.dart`
- Now checks both `email_inbox` and `email_in` for email notes
- Enhanced attachment detection with tag fallback

### Fixed Web Clipper Icons
- Replaced corrupted icon files in `tools/web-clipper-extension/icons/`
- Updated `background.js` to use `chrome.runtime.getURL()` for icon paths
- Fixed `popup.html` to use image instead of emoji

## Testing Checklist

- [ ] Verify web clipper creates entries in `clipper_inbox`
- [ ] Confirm filters show correct notes (Attachments, Email Notes, Web Clips)
- [ ] Check that only one "Incoming Mail" folder exists
- [ ] Verify folders appear consistently after sync
- [ ] Test that tags are being indexed in `note_tags` table
- [ ] Confirm inbox counter resets after viewing

## Monitoring Queries

```sql
-- Check web clipper activity
SELECT created_at, source_type, payload_json->>'title' as title
FROM clipper_inbox 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675'
ORDER BY created_at DESC LIMIT 10;

-- Check tag indexing
SELECT nt.tag, COUNT(*) as count
FROM note_tags nt
JOIN notes n ON nt.note_id = n.id
WHERE n.user_id = '49b58975-6446-4482-bed5-5c6b0ec46675'
GROUP BY nt.tag;

-- Check folder duplicates
SELECT name, COUNT(*) as count
FROM folders
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675'
AND deleted = false
GROUP BY name
HAVING COUNT(*) > 1;
```
