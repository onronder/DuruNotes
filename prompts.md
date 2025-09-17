# Quick Capture Prompt Set

## Quick Capture – Share Extension
```text
You are the cross-functional owner delivering the Quick Capture share extension for Duru Notes. Coordinate Flutter, native iOS/Android, Supabase, analytics, and QA work so the flow ships production-ready.

ENGINEERING
1. Connect native share entry points to `ShareExtensionService` (`lib/services/share_extension_service.dart`).
   • iOS: add a Share Extension target under `ios/ShareExtension/`, enable App Group `group.com.fittechs.durunotes`, and bridge through method channel `com.fittechs.durunotes/share_extension` compatible with `_processSharedItems`. Handle text, URLs, single/multi image & file payloads, persist into the App Group container, include originating bundle id, capture file sizes, and remove temp files upon `clearSharedItems`.
   • Update `ios/Runner/Info.plist` plus extension plist with `NSExtensionActivationRule` entries (`public.text`, `public.url`, `public.image`, `public.movie`, `public.data`) and missing privacy strings. Keep UI response <2 s, surface localized success/failure banners, and normalize titles using `_generateTitleFromText`.
   • Android: introduce `ShareReceiverActivity` and supporting classes under `android/app/src/main/kotlin/.../`, expand `AndroidManifest.xml` with `SEND`, `SEND_MULTIPLE`, `PROCESS_TEXT` intent filters, and stream URIs into `cacheDir/share_extension` before forwarding to Dart. Enforce `AttachmentService` size limits and guard `SecurityException` when URIs are unreadable.
2. After `_createNoteFromSharedContent` returns a note id, fetch `incomingMailFolderManagerProvider` and attempt `addNoteToIncomingMail(noteId)`. Swallow only Inbox-specific failures (note remains synced) and log with `AppLogger`.
3. Enrich note metadata (`source_app`, `share_type`, `attachments`, `received_at`) and analytics (`share_extension.ingest_started`, `.note_created`, `.ingest_failed`). Ensure structured logs mirror existing conventions.
4. Cover offline/auth edge cases: queue payloads through Drift `PendingOps` when signed out, replay once authenticated, and guard `_AppWithShareExtensionState` initialization in `lib/main.dart` so it is idempotent and disposed on logout.
5. Deliver user-facing feedback: localized strings in ARB files, extension banners, and `ScaffoldMessenger` toasts when deferred payloads land in-app.
6. Testing & automation: extend `test/services/share_extension_service_test.dart` (text, URL, multi-image, Inbox routing with mocked `IncomingMailFolderManager`), add `integration_test/share_extension_flow_test.dart` exercising native-to-Dart bridging, and keep `flutter test`, `fastlane ios beta`, `./gradlew assembleRelease` green.
7. Documentation: author `docs/quick-capture/share-extension.md` covering App Group setup, Android manifest changes, QA flows, and CI updates if new Xcode schemes exist.

BACKEND & DATA
1. Add a migration in `supabase/migrations` introducing durable columns or indexed generated fields for `share_source_app`, `share_type`, `share_received_at` (or indexes on metadata JSON). Supply down migration.
2. Adjust Postgres triggers to normalize/deduplicate `note_tags` coming from the share extension.
3. Update Supabase edge functions (`supabase/functions/process-notifications/index.ts`, etc.) so realtime pushes honor `metadata->>'source' = 'share_extension'` and route Inbox signals appropriately.
4. Re-confirm RLS on `notes`, `note_tags`, and attachments storage allowing user sessions to upload while blocking anon misuse. Add targeted tests for anon vs service role access.
5. Create SQL tests (`supabase/tests/share_extension.test.sql`) inserting sample share notes, asserting trigger behavior and RLS decisions. Document deployment/rollback steps alongside new env-vars inside the share extension doc.

QUALITY
1. iOS 16.4/17.0: share plain text, Safari URL, multi-image Photos selection, and PDF from Files. Validate banners, Inbox placement, metadata (`source = share_extension`, `attachment` tag), and debug inspector data.
2. Android 13/14: repeat via Chrome, Google Photos, file manager. Ensure completion notification deep links to the created note in both foreground and cold-start states.
3. Offline capture: disable network, share text, confirm payload queues locally and syncs without duplication once online (analytics reported).
4. Signed-out case: attempt share while logged out; verify localized block message. After login, re-share and confirm success.
5. Regression: email-in and web clip ingest continue to tag correctly and Inbox badge updates as before.
6. Accessibility: VoiceOver/TalkBack announce controls, large text layouts hold, and extension UI remains operable.
```

## Quick Capture – Home Screen Widget
```text
You own the cross-functional delivery of the Quick Capture home screen widget for Duru Notes across Flutter, native targets, Supabase, analytics, and QA.

ENGINEERING
1. Add `home_widget` (and `flutter_widgetkit` if necessary) to `pubspec.yaml`. Implement `lib/services/quick_capture_service.dart` wrapping `NotesRepository`, `AttachmentService`, `IncomingMailFolderManager`, `AnalyticsService`, and `AppLogger` to create notes tagged `widget` with metadata `{source: 'widget', entry_point: <platform>}`.
2. Register `quickCaptureServiceProvider` in `lib/providers.dart`, exposing text capture, optional template capture, and recent quick capture retrieval for widgets.
3. Create platform channel `com.fittechs.durunotes/quick_capture` accepting `{text, templateId?, attachments?}` and return note id/error. Short-circuit when no Supabase session exists.
4. iOS WidgetKit target (`ios/QuickCaptureWidget/`): SwiftUI views offering “New Quick Note” and recent snippets persisted in App Group storage. Trigger `WidgetCenter.shared.reloadAllTimelines()` after Flutter updates cache and deep link `durunotes://quick-capture` into `modern_edit_note_screen.dart` once note creation succeeds.
5. Android App Widget: add `QuickCaptureAppWidgetProvider`, layout, and `QuickCaptureBroadcastReceiver` using `PendingIntent`s. Delegate widget actions to the Flutter channel, refresh via `AppWidgetManager`, and surface latest snippets.
6. Update deep-link handling (`lib/main.dart`, `lib/ui/home_screen.dart`, `lib/ui/notes_list_screen.dart`) so quick-capture intents open the editor with the new note selected and scroll to Inbox if needed.
7. Handle auth/offline states: show “Sign in to capture notes” messaging on widgets with no session, return structured errors, cache pending captures for retry when connectivity returns.
8. Instrument analytics events (`quick_capture.widget_tap`, `.widget_note_created`, `.widget_failure`) and structured logs. Localize widget strings in ARB files.
9. Testing & docs: add unit tests for `QuickCaptureService`, widget tests for Flutter UI, Swift snapshot tests for WidgetKit, Android instrumentation for the broadcast receiver, and document build/config/QA steps in `docs/quick-capture/home-widget.md` (App Group ids, widget timelines).

BACKEND & DATA
1. Create migration adding an index on `(metadata->>'source')` (or equivalent) for quick filtering of `source = 'widget'`.
2. Provide an RPC or Edge Function (`rpc_get_quick_capture_summaries`) returning the latest N widget-tagged notes respecting RLS and pagination.
3. Update backend notification/analytics flows (`process-notifications` etc.) to include the widget source metadata so downstream automation fires.
4. Extend RLS tests (`supabase/tests/quick_capture_widget.test.sql`) covering RPC access for owners vs anonymous users. Document rate limits and caching strategy in the widget documentation.

QUALITY
1. iOS 17: install small/medium widgets, tap “New Quick Note” with app foregrounded and terminated; ensure editor opens <1.5 s, note appears in Inbox, widget refreshes with latest snippet.
2. Android 13/14: repeatedly use the widget, confirm PendingIntents are one-shot (no duplicates) and widget state persists after reboot.
3. Signed-out scenario: widget displays sign-in call-to-action and routes to login without creating notes.
4. Offline capture: trigger quick note while disconnected, reopen app, ensure note syncs once online without duplicates and retry analytics logged.
5. Performance: verify tap-to-editor latency and widget refresh stay within platform guidance, avoiding excessive CPU/wakeups.
6. Accessibility/localization: VoiceOver/TalkBack labels, large text support, localized strings render correctly.
```

## Quick Capture – Note Templates
```text
Drive the end-to-end delivery of reusable note templates that power Quick Capture, covering Flutter, Supabase, analytics, and QA responsibilities.

ENGINEERING
1. Extend Drift schema with `NoteTemplates` table (id TEXT PK, name, body, tags JSON/text, description, updatedAt, deleted flag) plus generated code in `lib/data/local/app_db.dart`. Create the parallel Supabase table through migration and ensure migrations execute on upgrade.
2. Implement a `TemplateService` or expand `NotesRepository` with `listTemplates`, `getTemplate`, `saveTemplate`, `deleteTemplate`, `duplicateTemplateToNote`, queuing operations in `PendingOps` for offline support.
3. Seed default templates (Meeting Notes, Daily Journal, Task Checklist) using `assets/templates/default_templates.json` on first login, respecting localization.
4. Build Riverpod providers and UI: template picker sheet in `lib/ui/note_edit_screen.dart`, integrate with quick capture flows, allow favorites, and render previews via `flutter_markdown`.
5. When duplicating a template into a note, call `createOrUpdate` with merged tags, metadata `{'template_id': ..., 'source': 'template'}`, and route to Inbox via `IncomingMailFolderManager`.
6. Add “Save as template” action in `modern_edit_note_screen.dart`, storing note title/body/tags (plus optional icon/color metadata) as templates.
7. Analytics/logging: emit `quick_capture.template_used`, `.template_created`, and ensure structured logs note template ids.
8. Settings integration: add toggle in `lib/ui/settings/` to enable/disable template suggestions.
9. Testing: Drift migration tests, repository/service unit tests, widget tests for picker UI, integration test verifying quick capture + template populates correctly. Document behavior and edge cases in `docs/quick-capture/templates.md`.

BACKEND & DATA
1. Migration for Supabase `note_templates` (id uuid, user_id uuid FK, name text, body text, tags text[], description text, updated_at timestamptz default now(), deleted boolean default false) with index `(user_id, updated_at)` and unique `(user_id, lower(name))`.
2. Triggers maintaining `updated_at` and normalizing tags to lowercase with deduplication (`array(select distinct lower(tag) from unnest(tags))`).
3. RLS policies granting owners full CRUD (`auth.uid() = user_id`) and service role unrestricted access. Provide helper RPCs if batch fetch needed.
4. Seed default templates for new users via migration SQL or onboarding edge function, honoring localization data shared with client seeds.
5. SQL tests (`supabase/tests/note_templates.test.sql`) for CRUD, RLS, triggers. Document deployment/rollback steps in the templates doc.

QUALITY
1. Validate default templates appear on fresh accounts with localized titles/bodies and correct tag suggestions.
2. Create/edit/favorite/delete templates, confirm sync to secondary device and immediate availability in quick capture flows.
3. Generate notes from each template through editor, share extension, and widget; ensure metadata `source = template`, tags apply, and notes land in Inbox.
4. Save an existing note as template, sign out/in, confirm persistence; delete and verify removal without affecting original note.
5. Offline scenarios: manipulate templates offline, reconnect, validate Drift queue replay without conflicts.
6. Regression: ensure standard note creation, saved searches, and folder filtering behave with template suggestions toggled on/off.
```
