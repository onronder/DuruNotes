# Post-Migration Follow-Up

## Critical
- Diagnose and fix note creation flow (UI interactions, repository writes, Supabase RPCs, realtime updates).
  - Review the new instrumentation in `ModernEditNoteScreen` and `NotesCoreRepository.createOrUpdate`; capture sample logs for successful vs. failing note saves.
  - Inspect local `_initialText` comparison to ensure `_hasChanges` is true when starting from an empty note.
  - Capture Supabase RPC results for note sync to catch auth or RLS issues silently returning empty responses.
  - Instrument `ModernEditNoteScreen` to log create/save attempts and errors.
  - Verify `Navigator.pop` signals success back to the list screen.
  - Confirm `NotesCoreRepository.createOrUpdate` inserts into local cache and enqueues sync operations.
  - Ensure realtime refreshes (or manual refresh) surface the new note immediately after creation.
- Audit reminders/tasks pipeline:
  - Manual creation and editing of reminders/tasks.
  - Automatic conversions between notes and tasks.
  - Reminder scheduling and notification delivery.
  - Capture console output using the new instrumentation in `ReminderCoordinator` and `DomainTaskController` to pinpoint failures.
- Validate templates end-to-end:
  - Template creation, editing, and persistence.
  - Applying templates to new notes or tasks.
  - Template storage across Supabase tables/functions.
  - Use the debug output from `UnifiedTemplateService.createTemplate` to confirm persistence paths.
- Review edge functions touching notes/reminders/tasks to ensure secrets and service keys are present after migration.
- Confirm Supabase migrations affecting notes, tasks, reminders, and templates ran successfully (schema, indexes, triggers, RLS policies).
  - Apply `20251021120000_backfill_note_tasks_and_reminders.sql` in each environment and verify `note_tasks`/`reminders` row-level policies.

## High Priority
- Add structured logging around note creation attempts to surface errors during the current regression.
- Verify local caches refresh immediately after note/reminder/task mutations (pagination notifier, filtered providers, realtime listeners).
- Reconcile inbox badge counts with backend state (e.g., deleted items, archived items).
- Exercise push notification edge flows outside of email: note assignment, task reminders, custom notification events.

## Medium Priority
- Re-run automated tests covering notes/tasks/templates once the flows are restored.
- Document operational runbooks for deploying edge functions and verifying environment variables (FCM keys, service role tokens).
- Build dashboards/alerts for push failure rates and note/task creation errors.
