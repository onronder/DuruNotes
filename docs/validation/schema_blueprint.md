# Supabase Schema Blueprint

Project: `mizzxiijxtbwrqgflpnp`  
Last updated: 2025-11-05

This blueprint captures the minimum schema surface required for the production dual-sync architecture. Each table includes data types, constraints, indexes, and security expectations so that local Drift models, repositories, and Supabase migrations remain aligned.

## Core Content Tables

### `public.notes`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | Generated via `gen_random_uuid()` |
| `user_id` | `uuid` | `NOT NULL`; FK to `auth.users(id)` (`ON DELETE CASCADE`) |
| `title_enc` | `bytea` | Encrypted note title |
| `props_enc` | `bytea` | Encrypted payload (body, tags, metadata, folder id) |
| `encrypted_metadata` | `jsonb` | Optional encrypted metadata blob |
| `note_type` | `integer` | Default `0` (`NoteKind`) |
| `deleted` | `boolean` | Soft delete flag (default `false`) |
| `created_at` | `timestamptz` | Default `timezone('utc', now())` |
| `updated_at` | `timestamptz` | Default `timezone('utc', now())` |

Constraints & policies:
- PK on `id`.
- FK on `user_id` to `auth.users`.
- Row Level Security enabled with `notes_owner` (`user_id = auth.uid()`).

Indexes & triggers:
- `notes_user_updated_idx` (`user_id`, `updated_at DESC`).
- `notes_user_deleted_idx` (`user_id`, `deleted`).
- Trigger `trg_notes_updated` updates `updated_at`.

### `public.note_tasks`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | `gen_random_uuid()` |
| `note_id` | `uuid` | `NOT NULL`; FK to `public.notes(id)` (`ON DELETE CASCADE`) |
| `user_id` | `uuid` | `NOT NULL`; matches owning user |
| `content` | `text` | Decrypted by client; encrypted locally |
| `status` | `text` | Defaults to `'pending'` |
| `priority` | `integer` | Defaults to `0` |
| `position` | `integer` | Defaults to `0` |
| `due_date` | `timestamptz` | Nullable |
| `completed_at` | `timestamptz` | Nullable |
| `parent_id` | `uuid` | FK to `public.note_tasks(id)` (`ON DELETE SET NULL`) |
| `labels` | `jsonb` | **NOT NULL**, defaults to `'[]'::jsonb` |
| `metadata` | `jsonb` | **NOT NULL**, defaults to `'{}'::jsonb` |
| `deleted` | `boolean` | Soft delete flag |
| `created_at` | `timestamptz` | Default `timezone('utc', now())` |
| `updated_at` | `timestamptz` | Default `timezone('utc', now())` |

Indexes:
- `note_tasks_user_updated_idx` (`user_id`, `updated_at DESC`).
- `note_tasks_note_idx` (`note_id`).

Trigger & policies:
- `trg_note_tasks_updated` sets `updated_at`.
- RLS `note_tasks_owner` ensures `user_id = auth.uid()`.

### `public.folders`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | `gen_random_uuid()` |
| `user_id` | `uuid` | FK to `auth.users(id)` |
| `name_enc` | `bytea` | Encrypted folder name |
| `props_enc` | `bytea` | Encrypted properties (path, parent, color, etc.) |
| `deleted` | `boolean` | Soft delete flag |
| `created_at` | `timestamptz` | Default `timezone('utc', now())` |
| `updated_at` | `timestamptz` | Default `timezone('utc', now())` |

Index & trigger:
- `folders_user_updated_idx` (`user_id`, `updated_at DESC`).
- `trg_folders_updated` updates `updated_at`.
- RLS `folders_owner`.

### `public.note_folders`
| Column | Type | Notes |
| --- | --- | --- |
| `note_id` | `uuid` | PK, FK to `public.notes(id)` |
| `folder_id` | `uuid` | FK to `public.folders(id)` (`ON DELETE CASCADE`) |
| `user_id` | `uuid` | Owner |
| `added_at` | `timestamptz` | Default `timezone('utc', now())` |

Indexes:
- `note_folders_note_idx` (`note_id`).
- `note_folders_folder_idx` (`folder_id`).
- `note_folders_folder_updated` (`folder_id`, `added_at DESC`) – used for sync diffing.

### `public.note_tags`
| Column | Type | Notes |
| --- | --- | --- |
| `note_id` | `uuid` | PK component; FK to `public.notes(id)` |
| `tag` | `text` | PK component -
| `user_id` | `uuid` | Owner |
| `metadata` | `jsonb` | Default `'{}'::jsonb` |
| `created_at` | `timestamptz` | Default `timezone('utc', now())` |

Indexes:
- `note_tags_tag_idx` (`tag`, `note_id`).
- `note_tags_batch_load_idx` (`note_id`, `tag`) – created via client migration 27.

### `public.reminders`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | `gen_random_uuid()` |
| `note_id` | `uuid` | FK to `public.notes(id)` |
| `user_id` | `uuid` | Owner |
| `title` | `text` | Default `''` |
| `body` | `text` | Default `''` |
| `type` | `text` | e.g. `task_time` |
| `remind_at` | `timestamptz` | Nullable |
| `is_active` | `boolean` | Default `true` |
| `recurrence_pattern` | `text` | Default `'none'` |
| `recurrence_interval` | `integer` | Default `1` |
| `recurrence_end_date` | `timestamptz` | Nullable |
| `latitude` / `longitude` / `radius` | Geofence support |
| `location_name` | `text` | Optional |
| `snoozed_until` | `timestamptz` | Nullable |
| `snooze_count` | `integer` | Default `0` |
| `trigger_count` | `integer` | Default `0` |
| `last_triggered` | `timestamptz` | Nullable |
| `created_at` | `timestamptz` | Default `timezone('utc', now())` |
| `updated_at` | `timestamptz` | Default `timezone('utc', now())` |
| `metadata` | `jsonb` | **NOT NULL**, Default `'{}'::jsonb` (added 2025-11-05) |

Indexes:
- `reminders_user_note_idx` (`user_id`, `note_id`).
- `reminders_active_idx` (`user_id`, `is_active`).

Policies/trigger:
- `trg_reminders_updated`.
- RLS `reminders_owner`.

## Supporting Tables / Functions

- `public.notification_events`, `notification_deliveries`, `notification_preferences`: required for push reminders; ensure Supabase secrets include FCM keys.
- Edge functions rely on RPCs such as `generate_user_alias`, `create_notification_event`, etc. When redeploying functions, confirm dependent objects exist.

## RPC & Edge Function Requirements

- `create_notification_event(user_id, event_type, ...)` – used by reminders & edge functions to enqueue push notifications.
- `clipper_inbox_broadcast_trigger` – keeps inbox real-time feed in sync.
- Edge functions (`process-fcm-notifications`, `setup-push-cron`, `remove-cron-spam`, etc.) must be redeployed with `supabase functions deploy`.

## Security Expectations

- All application tables must have RLS enabled with policies enforcing `user_id = auth.uid()`.
- Service-role operations (e.g., onboarding, cron jobs) use Supabase secrets; verify via `supabase secrets list`.
- Cron/Edge deployments must set `verify_jwt` appropriately (webhooks disabled, user-driven functions enabled).

## Migration / Drift Alignment

- Whenever a table contract changes, update:
  1. Drift schema (local SQLite) and migrations.
  2. Supabase migration scripts in `supabase/migrations/`.
  3. Validation script (`supabase/validation/check_baseline.sql`).
  4. Documentation (`docs/schema_blueprint.md`, `docs/SUPABASE_RUNBOOK.md`).

Keeping this document in sync with the production Postgres schema ensures that dual-sync logic across Flutter, Drift, and Supabase remains deterministic and auditable.
