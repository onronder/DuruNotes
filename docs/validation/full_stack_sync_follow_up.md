# Full-Stack Sync Follow-Up

## Completed Work
- `lib/ui/components/duru_note_card.dart:613` launches `EnhancedMoveToFolderDialog` so single-note moves reuse the folder picker and snack-bar confirmation used by bulk moves.
- `lib/infrastructure/repositories/notes_core_repository.dart:1609` only rewrites `note_folders` when `updateFolder` is set, preventing unintended folder unlinks during note edits. `_pushNoteOp` at `lib/infrastructure/repositories/notes_core_repository.dart:517` re-encrypts the note payload and mirrors folder relations in Supabase.
- `lib/services/sync/folder_remote_api.dart:1` and `lib/data/remote/supabase_note_api.dart:111` encrypt/decrypt folder names and props while preserving `user_id`, keeping Supabase folders compatible with the encrypted schema.
- `lib/infrastructure/repositories/notes_core_repository.dart:760` decrypts task content/metadata before pushing via `_secureApi.upsertNoteTask`, so due dates, reminders, and analytics fields survive round-trips.
- `lib/ui/time_tracking_dashboard_screen.dart:507` reads `actualMinutes`/`estimatedMinutes` from task metadata to populate the time-tracking dashboards shown in `docs/validation/6.png` and `docs/validation/7.png`.
- `lib/data/migrations/migration_27_performance_indexes.dart:1` ships composite indexes for folders, tasks, reminders, and pending ops, aligning Drift performance with the new domain-sync flows.
- `supabase/migrations/20251105000000_add_metadata_to_reminders.sql` adds a `metadata` jsonb column with a safe default so reminder sync payloads persist across Supabase environments.
- `lib/data/remote/supabase_note_api.dart:399` now normalizes task labels to `{'labels': []}` when no tags are present, satisfying the `NOT NULL` constraint on `public.note_tasks.labels` during remote upserts.
- Verified on the production Supabase project (`supabase db dump --schema public --linked`) that `public.reminders` includes the new `metadata jsonb NOT NULL DEFAULT '{}'::jsonb` column.
- `supabase/migrations/20251105093000_add_note_performance_indexes.sql` recreates the missing `note_folders_folder_updated` and `note_tags_batch_load_idx` indexes so Supabase matches the local performance profile once pushed.

## Pending Deployment
- Promote migration `20251105000000_add_metadata_to_reminders.sql` through staging and production Supabase projects once preflight checks pass.
- Backfill any Supabase reminder rows that were created before the metadata column existed (using `supabase/migrations/20251021120000_backfill_note_tasks_and_reminders.sql` as the foundation if needed).

## Required Follow-Up & Verification
- Run `scripts/verify_remote_schema.sh` (or the corresponding Terraform pipeline) against Supabase after applying the migration to confirm the `metadata` column is present and defaulted.
- Execute targeted `dart analyze` for `lib/data/remote/supabase_note_api.dart` and the surrounding sync surfaces, then run the sync smoke tests once the repo’s global analyzer blockers are cleared.
- Perform a dual-device sync QA: move a note across folders, create a task with due date/reminder/tag metadata, mark it complete, and confirm reminders and analytics remain consistent after pull/push cycles.
