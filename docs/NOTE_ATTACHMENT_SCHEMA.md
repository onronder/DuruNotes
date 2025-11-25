# Note Attachment Schema

This document defines the JSON schema for the `attachmentMeta` field in the `Note` entity.

## Overview

The `attachmentMeta` field is a TEXT column in the database that stores JSON data about various types of attachments associated with a note. This field enables rich media features like voice recordings, images, files, and other attachment types without requiring additional database tables.

## Database Column

- **Table**: `notes`
- **Column**: `attachment_meta`
- **Type**: TEXT (nullable)
- **Format**: JSON string

## Schema Structure

The `attachmentMeta` JSON can contain multiple attachment types. Each type is stored as a top-level key with an array of attachment objects.

```json
{
  "voiceRecordings": [...],
  "images": [...],
  "files": [...]
}
```

## Voice Recordings

Voice recordings are audio files recorded within the app and uploaded to Supabase Storage.

### Structure

```json
{
  "voiceRecordings": [
    {
      "id": "string (UUID)",
      "url": "string (Supabase Storage URL)",
      "filename": "string",
      "durationSeconds": "number (integer)",
      "createdAt": "string (ISO 8601 timestamp)",
      "transcript": "string (optional)"
    }
  ]
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (UUID v4) for this recording |
| `url` | string | Yes | Full URL to the audio file in Supabase Storage bucket (`attachments`) |
| `filename` | string | Yes | Original filename (e.g., `voice_note_1732291234567.m4a`) |
| `durationSeconds` | number | Yes | Duration of the recording in seconds (integer) |
| `createdAt` | string | Yes | ISO 8601 timestamp when the recording was created |
| `transcript` | string | No | Optional transcription of the audio (future feature) |

### Example

```json
{
  "voiceRecordings": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "url": "https://your-project.supabase.co/storage/v1/object/public/attachments/user123/attachments/1732291234567_voice_note.m4a",
      "filename": "voice_note_1732291234567.m4a",
      "durationSeconds": 45,
      "createdAt": "2025-11-22T14:30:00.000Z"
    },
    {
      "id": "b2c3d4e5-f6g7-8901-bcde-f12345678901",
      "url": "https://your-project.supabase.co/storage/v1/object/public/attachments/user123/attachments/1732291456789_voice_note.m4a",
      "filename": "voice_note_1732291456789.m4a",
      "durationSeconds": 120,
      "createdAt": "2025-11-22T15:45:00.000Z",
      "transcript": "This is an optional transcription of the voice recording."
    }
  ]
}
```

### Storage Location

Voice recordings are stored in the Supabase Storage `attachments` bucket with the following path pattern:

```
{userId}/attachments/{timestamp}_{filename}
```

Example:
```
user-abc123/attachments/1732291234567_voice_note.m4a
```

### Supported Audio Formats

- `.m4a` (AAC audio, recommended - default from iOS)
- `.aac` (AAC audio)
- `.mp3` (MP3 audio)

**MIME Types**:
- `audio/m4a`
- `audio/aac`
- `audio/mp3`

## Usage Examples

### Creating a Note with Voice Recording

```dart
final voiceRecording = {
  'id': const Uuid().v4(),
  'url': 'https://example.supabase.co/storage/v1/object/public/attachments/...',
  'filename': 'voice_note_1732291234567.m4a',
  'durationSeconds': 45,
  'createdAt': DateTime.now().toIso8601String(),
};

final attachmentMeta = jsonEncode({
  'voiceRecordings': [voiceRecording],
});

final note = Note(
  id: const Uuid().v4(),
  title: 'Voice note - Nov 22, 2025',
  body: 'Voice note recorded on 2025-11-22 at 14:30',
  attachmentMeta: attachmentMeta,
  // ... other fields
);
```

### Parsing Voice Recordings from a Note

```dart
if (note.attachmentMeta != null) {
  final meta = jsonDecode(note.attachmentMeta!);
  final voiceRecordings = meta['voiceRecordings'] as List<dynamic>?;

  if (voiceRecordings != null && voiceRecordings.isNotEmpty) {
    for (final recording in voiceRecordings) {
      final url = recording['url'] as String;
      final duration = recording['durationSeconds'] as int;
      // Use the recording data to display player UI
    }
  }
}
```

## Future Extensions

The `attachmentMeta` schema is designed to be extensible. Future attachment types can be added without schema migrations:

### Planned Extensions

- **Images**: Photos and screenshots
  ```json
  "images": [
    {
      "id": "uuid",
      "url": "storage_url",
      "thumbnailUrl": "thumbnail_url",
      "width": 1920,
      "height": 1080,
      "createdAt": "ISO 8601"
    }
  ]
  ```

- **Files**: Generic file attachments
  ```json
  "files": [
    {
      "id": "uuid",
      "url": "storage_url",
      "filename": "document.pdf",
      "mimeType": "application/pdf",
      "fileSize": 1024000,
      "createdAt": "ISO 8601"
    }
  ]
  ```

- **Email Attachments**: Forwarded from email
  ```json
  "emailAttachments": [
    {
      "id": "uuid",
      "url": "storage_url",
      "filename": "attachment.pdf",
      "mimeType": "application/pdf",
      "emailSubject": "Important Document",
      "receivedAt": "ISO 8601"
    }
  ]
  ```

## Best Practices

1. **Always validate JSON**: Parse with try-catch and handle invalid JSON gracefully
2. **Check for null/undefined**: Both `attachmentMeta` and individual arrays can be null
3. **Use type guards**: TypeScript/Dart type checking when parsing
4. **Clean up storage**: When notes are permanently deleted, delete associated files from storage
5. **Limit file sizes**: Enforce reasonable limits (e.g., 50MB max for voice notes)
6. **Use UUIDs**: Generate unique IDs for each attachment to avoid collisions

## Related Documentation

- [Voice Notes Implementation Plan](/MasterImplementation Phases/PreProdTODO/VOICE_NOTES_IMPLEMENTATION_PLAN.md)
- [AttachmentService](/lib/services/attachment_service.dart)
- [AudioRecordingService](/lib/services/audio_recording_service.dart)
- [Note Entity](/lib/domain/entities/note.dart)
