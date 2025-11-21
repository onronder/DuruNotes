## Phase 1.1 – Missing Implementation Tasks (Production-Grade Checklist)

> **Context**: The iOS scene lifecycle and bootstrap flow are stable again. Do **not** alter AppDelegate/SceneDelegate/bootstrap code unless explicitly called out.

### 0. Guard Rails

- Leave `SceneDelegate`, `AppDelegate.configureChannels(with:)`, UIScene manifest, and Adapty init untouched.
- If any change unexpectedly touches lifecycle/bootstrap, stop and get confirmation before proceeding.

### 1. Schema Upgrades (Local Drift + Supabase)

#### Drift (SQLite)
- Add nullable columns to soft-deleted tables:
  - `deletedAt`, `scheduledPurgeAt`, optional `deletedBy`.
  - Tables: `local_notes`, `local_folders`, `note_tasks`, plus `note_reminders`, `note_tags` if we soft-delete them now.
- Create Migration 40:
  - Add columns (default `null`).
  - Backfill rows where `deleted == true` → set `deleted_at = updated_at`, `scheduled_purge_at = updated_at + 10 days`.
- Update table classes/companions and bump schema version.

#### Supabase (Postgres)
- Mirror the same columns on `notes`, `folders`, `note_tasks`, `note_reminders`, `note_tags`.
- Create indexes:
  - `(user_id, deleted_at) WHERE deleted_at IS NOT NULL`.
  - `scheduled_purge_at WHERE scheduled_purge_at IS NOT NULL`.
- Add/update migration scripts and blueprint/runbook docs.

### 2. Repository & Domain Enhancements

- Extend domain entities + mappers to surface `deletedAt`/`scheduledPurgeAt`.
- Repositories (`notes_core_repository`, `folder_core_repository`, `task_core_repository`):
  - On delete: set timestamps and enqueue `upsert_*`.
  - On restore: clear timestamps and cascade to child objects.
  - Ensure `getDeleted*()` returns the new data for UI use.
- Reminders / tags / attachments:
  - Replace hard delete calls (`advanced_reminder_service`, etc.) with soft delete + restore paths.

### 3. Sync Alignment

- **Upload**: include `deleted_at`/`scheduled_purge_at` in payloads (notes + tasks). Update `ServiceAdapter`/`UnifiedSyncService`.
- **Download**: hydrate timestamps from Supabase into Drift.
- Verify pending operations still use `upsert_*` but serialize new fields when present.

### 4. Trash UI Completion (`lib/ui/trash_screen.dart`)

- Implement real actions:
  - `Delete Forever` → new service call that hard-removes locally & remote.
  - `Empty Trash` → batch the same permanent delete with confirmation dialog.
- Display “Deleted on …” using `deletedAt` and “Purged in X days” from `scheduledPurgeAt`.

### 5. Trash Service & Audit Trail

- Introduce `lib/services/trash_service.dart` (or equivalent):
  - Manage timestamps, purge scheduling, Supabase calls.
  - Log to new `trash_events` table (create with RLS policies).
- Wire analytics breadcrumb/event for restore/permanent delete.

### 6. Purge Automation Preview (Phase 1.3 Dependency)

- Add a feature-flagged scheduler/cron hook that finds items with `scheduled_purge_at <= now` and permanently deletes them.
- Document cron/automation expectations for production.

### 7. Testing

- Unit tests per repository:
  - delete sets timestamps, restore clears them, permanent delete removes rows.
- Widget tests for Trash screen: restore, delete forever, empty trash flows.
- Integration test: soft delete → restart → Trash contains item → restore returns it.
- Regression tests ensuring active lists exclude soft-deleted items.

### 8. QA / Manual Verification

- Manual checklist:
  - Delete/restore for notes, folders, tasks, reminders, tags.
  - Empty trash with multiple items.
  - Restore folder tree and verify child notes/tasks reappear.
  - Share extension/import/export behave with trashed content.
  - iOS device smoke test (watch bootstrap logs).
  - Android share intent works.
- Supabase query: verify `deleted_at` populated and purge schedule set.

### 9. Documentation Updates

- Update Master Implementation Plan + Phase 1.1 doc with new timestamp schema, purge strategy, audit trail.
- Add user/QA guidance for Trash UX and purge behaviour.

### 10. Risk Management

- Schema migrations must default to `null` and backfill carefully to avoid data loss.
- Ensure timestamps always stored in UTC and serialized consistently.
- Index creation must run before queries use the new columns (avoid full scans).
- Keep lifecycle bootstrap untouched to prevent a recurrence of the black screen bug.

> Deliver all work production-quality: migrations tested against backups, code covered with unit/widget tests, and manual QA pass documented before merging.
