# Voice Dictation Implementation Plan (Speech-to-Text)

**Scope**: Use the existing `VoiceTranscriptionService` to provide robust speech-to-text dictation inside the note editor, with clean UX and minimal clutter, across mobile platforms.

**Out of Scope**: Audio recording as standalone voice notes (see `VOICE_NOTES_IMPLEMENTATION_PLAN.md`), secure encrypted sharing, monetization gating (beyond basic hooks).

---

## 1. STT Engine & Permissions

### 1.1 Validate Speech Engine Integration

- **File**: `lib/services/voice_transcription_service.dart`
  - [x] Confirm dependency on `speech_to_text` is correct and up to date in `pubspec.yaml`.
  - [x] Review `initialize`, `start`, `stop`, `cancel`, `_handleResult`, `_handleError`, `_handleStatus`.
  - [x] Add a `localeId` parameter to `start(...)` (used for multi-language support).
  - [x] Ensure `_handleError` surfaces clear error messages (currently forwards plugin error message to UI).

- **File**: `lib/services/permission_manager.dart`
  - [x] Ensure microphone permission copy covers dictation use (“Record audio notes and transcribe voice”).
  - [x] Provide a reusable helper to show a “Go to Settings” CTA when mic is permanently denied (`openAppSettings` + SnackBar action).

### 1.2 Platform Configuration

- **File**: `ios/Runner/Info.plist`
  - [x] Verify microphone usage description explicitly mentions speech-to-text (already present).

- **File**: `android/app/src/main/AndroidManifest.xml`
  - [x] Ensure `RECORD_AUDIO` permission is declared.
  - [x] If using Google speech services, confirm no conflicting permissions or configuration.

---

## 2. Note Editor Integration

### 2.1 Entry Points for Dictation

- **File**: `lib/ui/modern_edit_note_screen.dart` (or primary note editor)
  - [x] Identify the main editor widget and text controller used for note body.
  - [x] Add a **mic icon** to the editor toolbar:
    - Placements:
      - Next to formatting icons, or
      - In a secondary “more” menu if toolbar is crowded.
    - Behavior:
      - Tap mic → start dictation.
      - Tap mic again or tap “Stop” → end dictation.
      - Long-press mic → open language picker.

### 2.2 Wiring Editor ↔ VoiceTranscriptionService

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Inject `VoiceTranscriptionService` via Riverpod (provider added in `lib/services/providers/services_providers.dart`).
  - [x] Implement methods:
    - `_startDictation()`:
      - Calls `voiceTranscriptionService.start(onPartial: ..., onFinal: ...)`.
      - Sets local state `_isDictating = true`.
    - `_stopDictation()`:
      - Calls `voiceTranscriptionService.stop()`.
      - Sets `_isDictating = false`.
  - [ ] `onPartial` handler:
    - (Deferred) Currently not used to avoid flicker; partials may be used later for live previews.
  - [x] `onFinal` handler:
    - Commit final transcript to the note body at current cursor position (with auto-spacing).

### 2.3 Text Merge Strategy

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Decide text merge rules:
    - Behavior A (recommended): insert dictated text at current cursor position, preserving existing text.
    - Behavior B: always append at end of note body.
  - [x] Implement insertion logic using the current `TextEditingController`:
    - Uses current selection (or appends at end if invalid).
    - On final text, rebuilds `text` and updates selection to end of inserted transcript.

---

## 3. UX & Visual Feedback

### 3.1 Dictation States

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Maintain `_isDictating` state in the editor.
  - [x] Mic icon states:
    - Idle: regular mic icon.
    - Active: highlighted mic icon (e.g. different color, animated).
  - [ ] Overlay/indicator:
    - (Optional, not implemented) A dedicated “Listening…” banner could be added later if needed.
    - Short error messages are currently shown via SnackBar when `_onError` is invoked.

### 3.2 Error & Permission Handling

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Handle failure cases:
    - `initialize()` fails → show “Speech not available on this device” SnackBar.
    - Permission denied → show SnackBar with “Enable microphone access” + “Settings” action using `PermissionManager.openAppSettings()`.
  - [x] Use `VoiceTranscriptionService._onError` callback to display user-friendly error text.

---

## 4. Feature Gating Hooks (Monetization-Ready, Disabled for Now)

- **File**: `lib/core/feature_flags.dart`
  - [x] Confirm `voice_dictation_enabled` flag exists and is exposed via `voiceDictationEnabled`.

- **File**: `lib/services/subscription_service.dart`
  - [ ] Confirm `hasFeatureAccess(FeatureFlags.voiceEnabled)` is implemented.

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Wrap mic button visibility with feature flag (`voiceDictationEnabled`).
  - [ ] Add subscription gating:
    - For now: mic calls dictation directly (assume free).
    - Future: check `hasFeatureAccess(voiceEnabled)` and show “Upgrade to use voice dictation” prompt if access is denied.
  - [ ] Add TODO comments marking where the paywall prompt will appear when monetization is turned on.

---

## 5. Testing & QA

### 5.1 Unit Tests

- **File**: `test/services/voice_transcription_service_test.dart` (NEW)
  - [ ] Test `initialize` success/failure paths (mock `SpeechToText`).
  - [ ] Test `start` and `stop` sequences, including:
    - Already listening, stopping properly.
    - Error cases in `listen`.
  - [ ] Test `_handleResult` partial vs final text behavior.

### 5.2 Widget Tests

- **File**: `test/ui/voice_dictation_editor_test.dart` (NEW)
  - [x] Scenario:
    - Open editor with empty note.
    - Tap mic button → simulate STT partial/final callbacks.
    - Verify text controller contains dictated text.
    - Verify mic icon state toggles as expected.

### 5.3 Manual QA

- **Checklist**:
  - iOS:
    - Dictation works, mic permission flow correct. (✅ validated during development)
    - Behavior when speech recognition not available. (⚠️ needs explicit QA checklist)
  - Android:
    - Dictation works with Google speech services. (⚠️ manual QA required)
    - Behavior if device has no speech engine or disabled network. (⚠️ manual QA required)
  - Edge Cases:
    - Long dictation (>1–2 minutes). (⚠️ manual QA required)
    - No speech detected. (⚠️ manual QA required)
    - Interrupted by phone call or app going to background. (⚠️ manual QA required)

---

## 6. Completion Criteria (Dictation READY)

- [x] Microphone permission flow is clean and localized.
- [x] Dictation can insert text into note editor at appropriate position.
- [x] Errors (no speech engine, permission denied) are handled gracefully.
- [ ] Dictation works on both iOS and Android in basic manual tests (Android + edge cases still to be formally QA’d).
- [x] Core service + editor integration tests are passing (widget-level insertion tests implemented).

---

## 7. Multi-Language Dictation (Completed)

- **File**: `lib/services/voice_transcription_service.dart`
  - [x] Added `DictationLocale` model (localeId, name, languageCode, countryCode).
  - [x] Implemented `getAvailableLocales()` and `getSystemLocale()` using `speech_to_text` locales.
  - [x] Extended `start()` to accept `localeId` and fall back to system locale when null.

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Added `_selectedDictationLocale` state and persistence via `SharedPreferences`.
  - [x] Implemented `_loadDictationLocale()` / `_saveDictationLocale()` for remembering user choice.
  - [x] Implemented `_showDictationLocalePicker()` as a bottom sheet with:
    - System default option.
    - Search by language name or locale ID.
    - Flag / 🌐 icon mapping for common locales.
    - Current selection highlighted with checkmark.
  - [x] Updated `_startDictation()` to use the selected locale’s `localeId`.
  - [x] Updated mic tooltip to show current locale and hint for long-press language selection.

---

## 8. Intentionally Deferred Items (v2 Polish)

The following items are explicitly NOT implemented in v1 to keep scope focused:

| Item | Rationale | v2 Consideration |
|------|-----------|------------------|
| `onPartial` real-time display | Causes UI flicker and complexity; final text is sufficient for good UX | Add "Listening…" overlay with live preview text |
| "Listening…" banner/overlay | Not essential for core functionality | Add animated waveform or pulsing indicator |
| Unit tests for VoiceTranscriptionService | Service is thin wrapper; edge cases covered by widget tests | Add mocked SpeechToText tests for init/start/stop/error paths |
| OEM-specific Android speech engine handling | Requires device farm testing | Add graceful fallback messaging for devices without Google Speech |

---

## 9. Privacy & Permissions

### What Voice Dictation Does

- **Microphone Access**: Uses device microphone to capture audio for speech-to-text conversion.
- **On-Device Processing**: Speech recognition is performed by the OS speech engine (Apple Speech on iOS, Google Speech Services on Android).
- **No Raw Audio Storage**: Duru Notes does not store, upload, or retain raw audio recordings from dictation.
- **Transcribed Text Only**: Only the final transcribed text is inserted into your note.

### Permission Flow

1. First use of dictation prompts for microphone permission.
2. If denied, a SnackBar appears with a "Settings" button to open system settings.
3. Permission status is checked each time dictation starts.

### Data Flow

```
[User Speech] → [Device Microphone] → [OS Speech Engine] → [Transcribed Text] → [Note Editor]
                                              ↓
                                    (No audio stored by Duru Notes)
```

---

## 10. Platform-Specific QA Checklist

### iOS

| Test | Status | Notes |
|------|--------|-------|
| Basic dictation (short) | ✅ | Works correctly |
| Long dictation (2-5 min) | ⚠️ TODO | Test for timeouts and memory |
| Interrupted by call | ⚠️ TODO | Verify cleanup and state reset |
| App backgrounded during dictation | ⚠️ TODO | Verify graceful stop |
| Speech recognition unavailable | ⚠️ TODO | Test on older devices |

### Android

| Test | Status | Notes |
|------|--------|-------|
| Basic dictation with Google Speech | ⚠️ TODO | Test on multiple devices |
| Google Speech disabled/not installed | ⚠️ TODO | Verify error messaging |
| Poor network conditions | ⚠️ TODO | Some speech engines require network |
| OEM speech engines (Samsung, Huawei) | ⚠️ TODO | May behave differently |
| Long dictation | ⚠️ TODO | Test for memory/timeout issues |
