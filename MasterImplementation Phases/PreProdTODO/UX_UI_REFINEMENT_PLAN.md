# UX & UI Refinement Plan (Pre-Production)

**Scope**: Reduce clutter, simplify flows, and make the app more approachable **without removing functionality**, focusing on navigation, FAB actions, editor tools, and settings.

**Out of Scope**: Visual rebranding, complete redesign of navigation structure, monetization UX (paywall flows).

---

## 1. Analytics-Driven Audit

### 1.1 Instrument Core Actions

- **File**: `lib/services/analytics/analytics_service.dart`
  - [x] Ensure analytics events exist for:
    - FAB actions: `fab_action_text_note`, `fab_action_checklist`, `fab_action_voice_note`, `fab_action_template`.
    - Menu items: settings opened, help opened, trash opened, etc.

- **File**: `lib/ui/notes_list_screen.dart`
  - [x] Track which FAB mini-actions are used (log events when tapped).

- **File**: `lib/ui/screens/modern_home_screen.dart`
  - [x] Track FAB usage similarly.

### 1.2 Short-Term Internal Usage Logging

- **File**: `docs/UX_AUDIT_NOTES.md` (NEW)
  - [x] Capture findings after a short internal usage period:
    - Which actions are used heavily.
    - Which screens/menus feel redundant or confusing.

---

## 2. FAB & Primary Actions Simplification

### 2.1 Notes List Screen FAB

- **File**: `lib/ui/notes_list_screen.dart`
  - [x] Keep a **single primary FAB** plus an expandable menu.
  - [x] Limit mini-actions to at most 3–4:
    - Text Note
    - Checklist
    - Voice Note
    - (Optional) Quick Template
  - [x] Remove or relocate rarely used actions from the FAB into menus or other entry points.

### 2.2 Modern Home Screen FAB

- **File**: `lib/ui/screens/modern_home_screen.dart`
  - [x] Align FAB actions with notes list (same core actions: text note, checklist, voice note; template remains optional).
  - [x] Avoid duplicate or conflicting labels between screens.

---

## 3. Editor Toolbar & Menus

### 3.1 Editor Toolbar Review

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] List all toolbar buttons (bold, italic, highlight, attachments, voice dictation, etc.).
  - [x] Group rarely-used formatting into a secondary “More” menu or bottom sheet.
  - [x] Ensure voice dictation mic icon is visible but not overwhelming:
    - Single mic icon.
    - Simple state toggle (idle/listening).

### 3.2 Contextual Actions

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [x] Keep context menus focused on actions relevant to the current note (e.g. share, secure share, move to folder).
  - [x] Move global actions (e.g. app settings) out of this screen and into the main navigation.

---

## 4. Settings & Advanced Options

### 4.1 Consolidate Settings

- **File**: `lib/ui/settings_screen.dart`
  - [x] Group settings into clear sections:
    - General
    - Notes & Organization
    - Voice & Audio
    - Security & Privacy
  - [x] Move advanced/rarely-used toggles from scattered screens into Settings:
    - E.g. some debug or advanced search options, where appropriate.

### 4.2 Voice & OCR Section

- **File**: `lib/ui/settings_screen.dart`
  - [x] Add a “Voice & OCR” section that links to:
    - Voice note description & help.
    - Dictation help (STT).
    - Troubleshooting for microphone issues.

---

## 5. Help & Onboarding

### 5.1 Help Screen Updates

- **File**: `lib/ui/help_screen.dart`
  - [x] Ensure “Voice & OCR Capture” section is up-to-date:
    - Document new voice note and dictation flows.
  - [x] Keep sections concise; move detailed content to docs or the website if it’s too long.

### 5.2 Onboarding / Hints

- **File**: `lib/ui/help_screen.dart` or a dedicated onboarding flow
  - [x] Add lightweight onboarding hints:
    - First-time tooltip on FAB explaining primary actions.
    - Optional one-time hint for voice dictation.

---

## 6. Visual Consistency & Accessibility

### 6.1 Shared Components

- **Files**: `lib/ui/widgets/*`
  - [x] Identify and extract common patterns (e.g., tile layouts, action rows) into shared widgets.
  - [x] Use consistent iconography for similar actions (mic, share, trash).

### 6.2 Accessibility Checks

- **Files**:
  - `lib/ui/utils/accessibility_implementation_guide.md`
  - `lib/ui/utils/accessibility_quick_reference.md`
  - Relevant screens (notes list, editor, settings)
  - [x] Verify:
    - VoiceOver/TalkBack can navigate FAB and key actions.
    - All new voice-related controls have proper labels/semantics.

---

## 7. Completion Criteria (UX/UI Pass for Pre-Prod)

- [x] FABs present only primary, high-value actions.
- [x] Editor toolbar is not overloaded; advanced options are discoverable but not noisy.
- [x] Settings are grouped logically; advanced options aren’t scattered.
- [x] Voice note and dictation flows are easy to discover and understand.
- [x] Help text matches actual behavior.
- [x] Accessibility standards are maintained for primary flows.
