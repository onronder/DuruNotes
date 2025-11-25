# Voice Notes Implementation Plan (Audio Recording)

**Scope**: Turn the existing audio recording and attachment infrastructure into a production-grade **voice note** feature (record → upload → attach to note → play back), across mobile platforms, aligned with the current Duru Notes architecture.

**Out of Scope**: Speech-to-text dictation (covered in `VOICE_DICTATION_IMPLEMENTATION_PLAN.md`), secure encrypted sharing, monetization.

---

## 1. Data & Storage Model

### 1.1 Note Attachment Metadata

- **File**: `lib/domain/entities/note.dart`
  - [ ] Define a JSON shape for voice recordings stored in `attachmentMeta`, e.g.:
    - `voiceRecordings`: array of objects `{ id, url, filename, durationSeconds, createdAt, transcript? }`.
  - [ ] Add a short inline doc comment on `attachmentMeta` describing that it may contain `voiceRecordings` metadata.

- **File**: `lib/data/local/app_db.dart`
  - [ ] Confirm `attachment_meta` column (TEXT / nullable) is present for notes (already exists).
  - [ ] Add a brief comment in the `Notes` table definition indicating that `attachment_meta` may contain voice recording metadata.

- **File**: `docs` (new or existing schema doc, e.g. `docs/NOTE_ATTACHMENT_SCHEMA.md`)
  - [ ] Document the `voiceRecordings` payload format used inside `Note.attachmentMeta`.

### 1.2 Supabase Storage Layout

- **File**: `lib/services/attachment_service.dart`
  - [ ] Confirm uploads target the `attachments` bucket; decide to reuse this bucket for audio files.
  - [ ] Ensure file naming pattern is compatible with voice notes (e.g. `userId/attachments/<timestamp>_voice_note.m4a`).
  - [ ] Add/confirm audio MIME support (e.g. `audio/m4a`, `audio/aac`, `audio/mp3`) in `_getMimeType` / validation logic.

---

## 2. Service Layer Integration

### 2.1 AudioRecordingService → AttachmentService

- **File**: `lib/services/audio_recording_service.dart`
  - [ ] Review `startRecording`, `stopRecording`, `cancelRecording`, `getRecordingBytes`, `getRecordingDuration`.
  - [ ] Add a helper method:
    - `Future<RecordingResult?> finalizeAndUpload({String? sessionId})`
      - Stops recording (if active).
      - Reads bytes with `getRecordingBytes`.
      - Uploads via `AttachmentService.uploadFromBytes`.
      - Returns `{ url, filename, durationSeconds }` or a structured `RecordingResult`.
  - [ ] Ensure all analytics events (`audio_recording_start`, `audio_recording_complete`, error events) include a `recording_type: 'voice_note'` property for later analysis.

- **File**: `lib/providers/infrastructure_providers.dart`
  - [ ] Add a Riverpod provider for `AudioRecordingService` if not already present (e.g. `audioRecordingServiceProvider`).
  - [ ] Ensure `AttachmentService` is also exposed via providers and injectable for tests.

### 2.2 Note Creation / Update

- **File**: `lib/domain/repositories/i_notes_repository.dart`
  - [ ] Add a method signature to support voice note creation, e.g.:
    - `Future<Note> createVoiceNote({required String audioUrl, required String filename, required int durationSeconds});`

- **File**: `lib/infrastructure/repositories/notes_core_repository.dart` (or equivalent)
  - [ ] Implement `createVoiceNote`:
    - Creates a note with:
      - `title`: default like `"Voice note - <date>"`.
      - `body`: brief placeholder text (`"Voice note recorded on <timestamp>"`).
      - `attachmentMeta`: JSON with one `voiceRecordings` entry.
      - Appropriate default folder (e.g. Inbox) and tags (e.g. `["voice-note"]`).
  - [ ] Ensure repository correctly persists `attachmentMeta` to `attachment_meta`.

- **File**: `lib/services/notes_service.dart` or equivalent service layer (if exists)
  - [ ] Add a high-level `createVoiceNoteFromRecording(RecordingResult result)` that:
    - Delegates to `NotesCoreRepository.createVoiceNote`.
    - Tracks analytics (event: `voice_note_created`).

---

## 3. UI Integration – Voice Note Creation

### 3.1 Notes List Screen (Floating Action Button)

- **File**: `lib/ui/notes_list_screen.dart`
  - [ ] Replace `_createVoiceNote()` implementation:
    - Currently shows “Voice note feature coming soon!” SnackBar.
    - New behavior:
      - Opens a bottom sheet / dialog with:
        - Record button (uses `AudioRecordingService.startRecording`).
        - Stop button (calls `finalizeAndUpload` + `NotesService.createVoiceNoteFromRecording`).
        - Cancel button (calls `AudioRecordingService.cancelRecording`).
      - Shows recording duration in the UI while recording.
  - [ ] Ensure FAB mini action labeled “Voice Note” toggles this flow correctly.
  - [ ] Handle permission denial:
    - If microphone permission is denied, show a SnackBar/dialog with guidance to enable mic access in system settings.

### 3.2 Modern Home Screen

- **File**: `lib/ui/screens/modern_home_screen.dart`
  - [ ] Implement `_createVoiceNote()` (currently `// TODO`) to:
    - Toggle FAB closed.
    - Navigate to the same voice note recording sheet used by `NotesListScreen` or reuse the same widget.
  - [ ] Ensure consistent UX: same labels, icons, and flow as in notes list.

### 3.3 Note Detail / Playback UI

- **File**: `lib/ui/modern_edit_note_screen.dart` or note detail widget
  - [ ] Detect presence of `voiceRecordings` in `note.attachmentMeta`.
  - [ ] Render a list of voice recording tiles (one per recording).
  - [ ] Each tile should show:
    - Play/Pause button.
    - Duration.
    - Timestamp (createdAt).

- **File**: `lib/ui/widgets/voice_recording_player.dart` (NEW)
  - [ ] Create a reusable widget encapsulating playback logic:
    - Props: `audioUrl`, `durationSeconds`, optional `title`.
    - Internally uses an audio player (e.g. `just_audio`) to stream from `audioUrl`.
    - Shows loading/playing/paused states with appropriate icons.
  - [ ] Integrate logging and basic error handling (network errors, unsupported format).

---

## 4. Cleanup, Lifecycle, and Reliability

### 4.1 Temporary File Management

- **File**: `lib/services/audio_recording_service.dart`
  - [ ] Ensure local temp files are:
    - Deleted after a successful upload.
    - Deleted on `cancelRecording`.
  - [ ] Consider adding a `cleanupOrphanedRecordings()` method:
    - Scans temp directory for stale `voice_note_*.m4a` files.
    - Deletes files older than a certain age (e.g. 24 hours).

### 4.2 Trash & Purge Integration

- **File**: `lib/services/trash_service.dart`
  - [ ] Decide and document behavior for voice attachments when notes are permanently deleted:
    - Option A: leave audio in storage (simpler, cheaper to implement).
    - Option B: attempt to delete associated audio files from Supabase Storage:
      - Extend trash purge logic to call `AttachmentService.delete` for each `voiceRecordings.url`.
  - [ ] If implementing Option B:
    - Update purge path to iterate over `voiceRecordings` in `attachmentMeta` and queue deletions.

### 4.3 Offline Behavior

- **File**: `lib/services/audio_recording_service.dart`
  - [ ] Decide policy when uploading fails due to offline / network errors:
    - For now: show an error and allow user to retry; log the error.
  - [ ] Optionally add a TODO comment for future offline queue integration if needed later.

---

## 5. Permissions, Analytics, and Telemetry

### 5.1 Permissions UX

- **File**: `lib/services/permission_manager.dart`
  - [ ] Ensure voice recording requests are described consistently (e.g. “Record audio notes and transcribe voice”).
  - [ ] If not already, centralize microphone permission copy here and reuse across AudioRecordingService and VoiceTranscriptionService.

### 5.2 Analytics Events

- **File**: `lib/services/analytics/analytics_service.dart` (and related analytics constants)
  - [ ] Ensure these events are defined and used:
    - `audio_recording_start`
    - `audio_recording_complete`
    - `audio_recording_error`
    - `voice_note_created`
    - `voice_note_play_started`
    - `voice_note_play_completed`
  - [ ] Standardize properties (duration, file size, platform, screen).

---

## 6. Testing Strategy

### 6.1 Unit Tests

- **File**: `test/services/audio_recording_service_test.dart` (NEW)
  - [ ] Add tests for:
    - `startRecording` handles permission granted/denied cases.
    - `stopRecording` correctly ends session and logs analytics.
    - `cancelRecording` cleans up temp file and logs cancel event.

- **File**: `test/services/notes_voice_note_integration_test.dart` (NEW)
  - [ ] Test `createVoiceNote` end-to-end at service/repository level:
    - Given a `RecordingResult`, ensure a note is created with expected `attachmentMeta`.

### 6.2 Widget / Integration Tests

- **File**: `test/ui/voice_note_flow_test.dart` (NEW)
  - [ ] Scenario:
    - Open notes list.
    - Tap “Voice Note” FAB option.
    - Simulate a successful recording (mock service).
    - Verify new note appears, with voice recording tile in detail screen.

---

## 7. UX & UI Considerations (Voice Notes)

- **Files**: `lib/ui/notes_list_screen.dart`, `lib/ui/screens/modern_home_screen.dart`, `lib/ui/help_screen.dart`
  - [ ] Keep FAB options focused: only show “Voice Note” where it makes sense (avoid clutter).
  - [ ] Update help text to:
    - Explain how to create and play voice notes.
    - Mention microphone permission and troubleshooting hints.

---

## Completion Criteria (Voice Notes Feature READY)

- [ ] Recording works reliably on both iOS and Android.
- [ ] Voice notes are stored as attachments, visible in note detail, and playable.
- [ ] Permissions errors are handled gracefully with clear messaging.
- [ ] Audio files are not leaked in temp storage (normal flows).
- [ ] Analytics events fire for key actions (start, stop, play).
- [ ] Tests for core flows (service + widget) are passing.

