# Supabase Schema Blueprint

The blueprint converts the code-first inventory into concrete Postgres definitions. Use this as the reference when implementing `supabase/migrations/2025xxxx000000_initial_baseline.sql`.

Notation:
- `PK` – primary key definition.
- `FK` – foreign key.
- `IDX` – index (add the exact SQL in migration).
- `RLS` – row-level security policy.

---

## 1. Authentication & Profiles

### 1.1 `user_profiles` (MVP)
- Columns:
  - `user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
  - `email text NOT NULL`
  - `first_name text NOT NULL DEFAULT ''`
  - `last_name text NOT NULL DEFAULT ''`
  - `passphrase_hint text`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- Triggers: optional `updated_at` trigger.
- RLS:
  ```sql
  ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
  CREATE POLICY user_profiles_owner ON user_profiles
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  ```

## 2. Encryption & Key Management

### 2.1 `user_keys`
- Columns:
  - `user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
  - `wrapped_key text NOT NULL`
  - `kdf text NOT NULL DEFAULT 'pbkdf2-hmac-sha256'`
  - `kdf_params jsonb NOT NULL DEFAULT '{}'::jsonb`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- RLS: same pattern as above (`user_id = auth.uid()`).

### 2.2 `user_encryption_keys`
- Columns:
  - `user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
  - `encrypted_amk text NOT NULL`
  - `amk_salt text NOT NULL`
  - `algorithm text NOT NULL DEFAULT 'Argon2id'`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- RLS: same as above.

## 3. Notes & Folders Domain

### 3.1 `notes`
- Columns:
  - `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
  - `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
  - `title_enc bytea NOT NULL`
  - `props_enc bytea NOT NULL`
  - `encrypted_metadata jsonb`
  - `note_type integer NOT NULL DEFAULT 0`
  - `deleted boolean NOT NULL DEFAULT false`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- IDX:
  - `notes_user_updated_idx ON notes(user_id, updated_at DESC)`
  - `notes_user_deleted_idx ON notes(user_id, deleted)`
- RLS: `user_id = auth.uid()`.

### 3.2 `folders`
- Columns:
  - `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
  - `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
  - `name_enc bytea NOT NULL`
  - `props_enc bytea NOT NULL`
  - `deleted boolean NOT NULL DEFAULT false`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- IDX:
  - `folders_user_updated_idx ON folders(user_id, updated_at DESC)`
  - Optional unique: `folders_user_path_unique` if path stored separately later.
- RLS: same pattern.

### 3.3 `note_folders`
- Columns:
  - `note_id uuid PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE`
  - `folder_id uuid NOT NULL REFERENCES folders(id) ON DELETE CASCADE`
  - `user_id uuid NOT NULL`
  - `added_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- Constraints:
  - `CHECK (user_id = (SELECT user_id FROM notes WHERE id = note_id))` optional via trigger.
- RLS: `user_id = auth.uid()`.

### 3.4 `note_tasks`
- Columns:
  - `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
  - `note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
  - `user_id uuid NOT NULL`
  - `content text NOT NULL`
  - `status text NOT NULL DEFAULT 'pending'`
  - `priority integer NOT NULL DEFAULT 0`
  - `position integer NOT NULL DEFAULT 0`
  - `due_date timestamptz`
  - `completed_at timestamptz`
  - `parent_id uuid REFERENCES note_tasks(id) ON DELETE SET NULL`
  - `labels jsonb DEFAULT '[]'::jsonb`
  - `metadata jsonb DEFAULT '{}'::jsonb`
  - `deleted boolean NOT NULL DEFAULT false`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- IDX:
  - `note_tasks_user_updated_idx ON note_tasks(user_id, updated_at DESC)`
  - `note_tasks_note_idx ON note_tasks(note_id)`
- RLS: `user_id = auth.uid()`.

### 3.5 `templates`
- Similar pattern to notes: encrypted blobs, `user_id`, `deleted`, timestamps.
- Add indexes on `(user_id, is_system, deleted)`.

### 3.6 `saved_searches`
- Columns:
  - `id text PRIMARY KEY` (client generates UUID strings; stored as text for compatibility with legacy clients)
  - `user_id uuid NOT NULL`
  - `name text NOT NULL`
  - `query text NOT NULL`
  - `search_type text NOT NULL DEFAULT 'text'`
  - `parameters jsonb DEFAULT '{}'::jsonb`
  - `sort_order integer NOT NULL DEFAULT 0`
  - `color text`
  - `icon text`
  - `is_pinned boolean NOT NULL DEFAULT false`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `last_used_at timestamptz`
  - `usage_count integer NOT NULL DEFAULT 0`
- IDX: `(user_id, is_pinned DESC, sort_order ASC)`.
- RLS: `user_id = auth.uid()`.

### 3.7 `tags` and `note_tags`
- `tags` columns:
  - `id text PRIMARY KEY` (stores tag name/slug to match existing client expectations)
  - `user_id uuid NOT NULL`
  - `name text NOT NULL`
  - `color text`
  - `icon text`
  - `usage_count integer NOT NULL DEFAULT 0`
  - `created_at`, `updated_at`
- `note_tags` columns:
  - `note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
  - `tag text NOT NULL`
  - `user_id uuid NOT NULL`
  - `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
  - `metadata jsonb DEFAULT '{}'::jsonb`
  - PK on `(note_id, tag)`
- RLS: `user_id = auth.uid()` on both tables.

### 3.8 `note_links`
- `source_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
- `target_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
- `target_title text NOT NULL`
- `user_id uuid NOT NULL`
- `link_type text DEFAULT 'manual'`
- `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- PK: `(source_id, target_id)`
- RLS: `user_id = auth.uid()`.

### 3.9 `reminders`
- Columns include recurrence/geolocation:
  - `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
  - `note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
  - `user_id uuid NOT NULL`
  - `title text NOT NULL DEFAULT ''`
  - `body text NOT NULL DEFAULT ''`
  - `type text NOT NULL`
  - `remind_at timestamptz`
  - `is_active boolean NOT NULL DEFAULT true`
  - `recurrence_pattern text NOT NULL DEFAULT 'none'`
  - `recurrence_interval integer NOT NULL DEFAULT 1`
  - `recurrence_end_date timestamptz`
  - `latitude double precision`
  - `longitude double precision`
  - `radius double precision`
  - `location_name text`
  - `snoozed_until timestamptz`
  - `snooze_count integer NOT NULL DEFAULT 0`
  - `trigger_count integer NOT NULL DEFAULT 0`
  - `created_at`, `updated_at`, `last_triggered timestamptz`
- IDX: `(user_id, note_id)`, `(user_id, is_active)`.
- RLS: `user_id = auth.uid()`.

### 3.10 `note_blocks`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
- `user_id uuid NOT NULL`
- `idx integer NOT NULL`
- `type text NOT NULL`
- `content_enc bytea NOT NULL`
- `attrs_enc bytea`
- `created_at`, `updated_at`
- IDX: `(note_id, idx)`
- RLS: `user_id = auth.uid()`.

## 4. Attachments & Storage

### 4.1 `attachments`
- `id text PRIMARY KEY`
- `user_id uuid NOT NULL`
- `note_id uuid REFERENCES notes(id) ON DELETE SET NULL`
- `file_name text NOT NULL`
- `storage_path text NOT NULL`
- `mime_type text`
- `size integer`
- `url text`
- `uploaded_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- `deleted boolean NOT NULL DEFAULT false`
- RLS: `user_id = auth.uid()`.

### 4.2 `inbound_attachments` / `inbound_attachments_temp`
- Same core columns as `attachments` plus:
  - `status text`, `ingested boolean`, `error text`, `processed_at timestamptz`
- RLS: `user_id = auth.uid()`.

## 5. Inbound Email & Clipper

### 5.1 `clipper_inbox`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid NOT NULL`
- `source_type text`
- `title text`
- `content text`
- `html text`
- `metadata jsonb`
- `message_id text`
- `payload_json jsonb`
- `converted_to_note_id uuid`
- `converted_at timestamptz`
- `created_at`, `updated_at`
- IDX: `(user_id, created_at DESC)` plus `(user_id, converted_to_note_id)`
- RLS: `user_id = auth.uid()`.

### 5.2 `inbound_aliases`
- `user_id uuid NOT NULL`
- `alias text NOT NULL`
- `created_at`, `updated_at`
- PK `(user_id, alias)`
- RLS: `user_id = auth.uid()`.

## 6. Notifications & Push

### 6.1 `user_devices`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid NOT NULL`
- `device_id text NOT NULL`
- `push_token text`
- `platform text`
- `app_version text`
- `created_at`, `updated_at`
- Unique index `(user_id, device_id)`
- RLS: `user_id = auth.uid()`.

### 6.2 `notification_preferences`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid NOT NULL UNIQUE`
- `enabled boolean NOT NULL DEFAULT true`
- `push_enabled boolean NOT NULL DEFAULT true`
- `email_enabled boolean NOT NULL DEFAULT true`
- `sms_enabled boolean NOT NULL DEFAULT false`
- `in_app_enabled boolean NOT NULL DEFAULT true`
- `event_preferences jsonb DEFAULT '{}'::jsonb`
- `quiet_hours_enabled boolean NOT NULL DEFAULT false`
- `quiet_hours_start text`
- `quiet_hours_end text`
- `timezone text`
- `dnd_enabled boolean NOT NULL DEFAULT false`
- `dnd_until timestamptz`
- `batch_emails boolean NOT NULL DEFAULT false`
- `batch_frequency text`
- `created_at`, `updated_at`
- RLS: `user_id = auth.uid()`.

### 6.3 `notification_deliveries`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `event_id uuid`
- `user_id uuid NOT NULL`
- `channel text NOT NULL`
- `device_id uuid`
- `status text`
- `provider_response jsonb`
- `provider_message_id text`
- `sent_at`, `delivered_at`, `opened_at`, `clicked_at`, `failed_at`
- `error_code text`, `error_message text`
- `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- IDX: `(user_id, created_at DESC)`, `(channel)`
- RLS: `user_id = auth.uid()`.

### 6.4 `notification_events`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid NOT NULL`
- `event_type text NOT NULL`
- `event_source text`
- `priority text NOT NULL DEFAULT 'normal'`
- `payload jsonb NOT NULL`
- `scheduled_for timestamptz NOT NULL DEFAULT timezone('utc', now())`
- `processed_at timestamptz`
- `status text NOT NULL DEFAULT 'pending'`
- `retry_count integer NOT NULL DEFAULT 0`
- `max_retries integer NOT NULL DEFAULT 3`
- `dedupe_key text`
- `error_message text`
- `error_details jsonb`
- `created_at`, `updated_at`
- IDX: `(user_id, dedupe_key) WHERE dedupe_key IS NOT NULL`, plus processing indexes as needed by edge functions.
- RLS: `user_id = auth.uid()`.

### 6.5 RPCs
- `user_devices_upsert(_device_id text, _push_token text, _platform text, _app_version text)` with security definer.
- `should_send_notification(...)` – reuse existing logic or reimplement.
- `generate_user_alias()` – returns alias + ensures uniqueness.
- `update_inbox_attachments(inbox_id uuid, attachment_data jsonb)` – merges attachment metadata into `clipper_inbox.payload_json` and `metadata`; security definer restricted to edge inbox functions.

## 7. User Preferences & Security

### 7.1 `user_preferences`
- `user_id uuid PRIMARY KEY`
- `language text`
- `theme text`
- `notifications_enabled boolean`
- `created_at`, `updated_at`
- RLS: `user_id = auth.uid()`.

### 7.2 `password_history`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid NOT NULL`
- `password_hash text NOT NULL`
- `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- RLS: `user_id = auth.uid()`.

### 7.3 `security_alerts`
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid`
- `event_type text NOT NULL`
- `severity text NOT NULL`
- `description text`
- `metadata jsonb`
- `created_at timestamptz NOT NULL DEFAULT timezone('utc', now())`
- RLS: `user_id = auth.uid()` OR allow null user for global alerts.

### 7.4 After MVP security tables (stubs)
- `security_events`, `login_attempts`, `rate_limits`, `rate_limit_log` – keep definitions ready but mark for future creation.

## 8. Productivity & Analytics (MVP scope)
- No separate table required; rely on `note_tasks.metadata` for `estimatedMinutes` / `actualMinutes`.
- Ensure JSON keys exist in code; add CHECK constraints optionally after MVP.

## 9. After MVP Tables (placeholders)
- `notification_templates`, `notification_stats`, `notification_health_checks`, `notification_cron_jobs`.
- `analytics_events`, `index_statistics`, `notification_analytics`.
- Documented but not created in the MVP migration.

## 10. Policies & Helper Functions
- Add `set_updated_at` trigger function for tables with `updated_at`.
- Ensure all tables with `user_id` have:
  ```sql
  ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
  CREATE POLICY <table>_owner ON <table>
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  ```
- Service-role users (edge functions) may require additional policies (e.g., cron functions reading across users). Document exceptions when implementing functions.

---

Next step: translate this blueprint into the initial Supabase migration and accompanying validation script.
