# Supabase Schema Inventory (Code-First)

_Project_: `mizzxiijxtbwrqgflpnp`

This inventory is derived from the current Flutter/Dart codebase. It groups requirements into **MVP** (must exist for the existing code to run without gaps) and **After MVP** (future enhancements referenced in code but not yet wired end-to-end).

---

## 1. Authentication & Profiles
### 1.1 `auth.users` (Supabase built-in)
- Email/password auth only. UI collects email, password, passphrase.

### 1.2 `user_profiles` (MVP)
- **Purpose**: Store firstname/lastname (onboarding), optional passphrase hint.
- **Columns**: `user_id uuid primary key references auth.users(id)`, `email text`, `first_name text`, `last_name text`, `passphrase_hint text`, `created_at timestamptz default now()`, `updated_at timestamptz default now()`.
- **RLS**: `USING (user_id = auth.uid())`.
- **Used in**: Onboarding screens (future), settings/profile UI.

## 2. Encryption & Key Management (MVP)
### 2.1 `user_keys`
- **Columns**: `user_id uuid primary key`, `wrapped_key text`, `kdf text`, `kdf_params jsonb`, `created_at`, `updated_at`.
- **Used in**: `AccountKeyService` (passphrase wrapping/unwrapping).

### 2.2 `user_encryption_keys`
- **Columns**: `user_id uuid primary key`, `encrypted_amk text`, `amk_salt text`, `algorithm text`, `created_at`, `updated_at`.
- **Used in**: `EncryptionSyncService` for cross-device AMK sync.

## 3. Notes & Folders Domain (MVP)
### 3.1 `notes`
- `id uuid`, `user_id`, `title_enc bytea`, `props_enc bytea`, `encrypted_metadata jsonb`, `note_type int`, `deleted bool default false`, `created_at`, `updated_at`.
- Indexes: `(user_id, updated_at DESC)`, `(user_id, deleted)`, optional JSON indexes on metadata.

### 3.2 `folders`
- `id uuid`, `user_id`, `name_enc bytea`, `props_enc bytea`, `deleted bool`, timestamps.
- Optional unique `(user_id, props ->> 'path')` depending on props schema.

### 3.3 `note_folders`
- `note_id uuid primary key`, `folder_id uuid`, `user_id uuid`, `added_at timestamptz`.
- FK with `ON DELETE CASCADE`.

### 3.4 `note_tasks`
- `id uuid`, `note_id`, `user_id`, `content text`, `status text`, `priority int`, `position int`, `due_date`, `completed_at`, `parent_id`, `labels jsonb`, `metadata jsonb`, `deleted bool`, `created_at`, `updated_at`.
- Indexes: `(user_id, updated_at DESC)`, `(note_id)`.

### 3.5 `templates`
- `id uuid`, `user_id`, encrypted blobs (`title_enc`, `body_enc`, `tags_enc`, `description_enc`), `category`, `icon`, `sort_order`, `props_enc`, `is_system bool`, `deleted`, timestamps.

### 3.6 `saved_searches`
- `id text` (UUID string generated client-side), `user_id`, `name`, `query`, `search_type`, `parameters jsonb`, `sort_order`, `color`, `icon`, `is_pinned`, `created_at`, `last_used_at`, `usage_count`.
- Used by `SavedSearchManagementScreen`, saved search chips.

### 3.7 `tags` & `note_tags`
- `tags`: `id text` (tag slug/name), `user_id`, `name`, `color`, `icon`, `usage_count`, `created_at`, `updated_at`.
- `note_tags`: `note_id`, `tag`, `user_id`, `created_at`, `metadata jsonb`.
- Used in tags screen, note editor tag chips.

### 3.8 `note_links`
- `source_id`, `target_id`, `target_title`, `user_id`, `link_type`, `created_at`.
- Supports backlinks & link dialog.

### 3.9 `reminders`
- Full reminder metadata: titles, bodies, types, timestamps, recurrence, geolocation, snooze counts.
- Supports reminders UI and services.

### 3.10 `note_blocks`
- Block editor data (feature flag in note editor).
- `id uuid`, `note_id`, `user_id`, `idx int`, `type`, `content_enc`, `attrs_enc`, timestamps.

## 4. Attachments & Storage (MVP)
### 4.1 Storage buckets
- `attachments` (already created)
- `inbound-attachments`, `inbound-attachments-temp` (staging for email ingest) – create as needed.

### 4.2 `attachments`
- `id text`, `user_id`, `note_id`, `file_name`, `storage_path`, `mime_type`, `size`, `url`, `uploaded_at`, `created_at`, `deleted`.
- Used by attachment service and inbox processing.

### 4.3 `inbound_attachments`, `inbound_attachments_temp`
- Mirror attachment metadata plus processing status fields.
- Used by `InboxManagementService` and inbound email edge functions.
- RPC `update_inbox_attachments` persists attachment metadata back onto the parent `clipper_inbox` row so the app can surface files during conversion.

## 5. Inbound Email & Clipper (MVP)
### 5.1 `clipper_inbox`
- `id`, `user_id`, `source_type`, `title`, `content`, `html`, `metadata`, `message_id`, `payload_json`, `converted_to_note_id`, `converted_at`, timestamps.
- `converted_to_note_id`/`converted_at` replaces the old `is_processed` flag; rows stay in place for history while the UI filters processed items.

### 5.2 `inbound_aliases`
- Composite key `(user_id, alias)`, `created_at`, `updated_at`.
- Used by alias generation RPC and inbox UI.

## 6. Notifications & Push (MVP)
### 6.1 `user_devices`
- `id`, `user_id`, `device_id`, `push_token`, `platform`, `app_version`, `created_at`, `updated_at`.

### 6.2 `notification_preferences`
- `id`, `user_id` (unique), `enabled`, `push_enabled`, `email_enabled`, `sms_enabled`, quiet-hour fields, `event_preferences jsonb`, timestamps.

### 6.3 `notification_events`
- Queue backing push/email notifications: `id`, `user_id`, `event_type`, `priority`, `payload jsonb`, `scheduled_for`, `status`, retry/dedupe fields, timestamps.
- Required by edge functions (`process-notification-queue`, `send-push-notification`, etc.) to claim work.

### 6.4 `notification_deliveries`
- Delivery audit data: `event_id`, `user_id`, `channel`, `device_id`, status timestamps (`sent_at`, `delivered_at`, etc.), `provider_response`, `error_code`, `created_at`.

### 6.5 RPCs & cron
- `user_devices_upsert` RPC required.
- `should_send_notification`, `generate_user_alias` RPCs remain.
- Edge functions: push pipeline (`send-push-notification`, `process-notification-queue`, etc.), inbound email suite (to be redeployed).

## 7. User Preferences & Security (MVP)
### 7.1 `user_preferences`
- `user_id` (unique), `language`, `theme`, `notifications_enabled`, `created_at`, `updated_at`.

### 7.2 `password_history`, `security_alerts`
- Basic tables to log password changes and security incidents.
- Fields: `id uuid`, `user_id`, `payload/json`, `created_at`, optional metadata columns.

### 7.3 Other audit tables (After MVP)
- `security_events`, `login_attempts`, `rate_limits`, `rate_limit_log`, etc. Keep flagged as Post MVP for future analytics/hardening.

## 8. Feature-Specific Tables
### 8.1 Productivity & Time Tracking (MVP)
- Use `note_tasks.metadata` to store `estimatedMinutes`, `actualMinutes`.
- Keep schema flexible with jsonb fields.

### 8.2 Analytics (After MVP)
- Tables such as `analytics_events`, `notification_stats`, `notification_templates`, `notification_health_checks`, `notification_cron_jobs` can be added later once analytics UI is wired.

## 9. Mapping to UI & Services

| Feature / Screen | Tables involved | Services / Notes |
|------------------|-----------------|------------------|
| Auth + onboarding | `auth.users`, `user_profiles`, `user_keys`, `user_encryption_keys` | `AccountKeyService`, `EncryptionSyncService`, onboarding dialog. |
| Notes list & filters | `notes`, `folders`, `note_folders`, `saved_searches`, `tags`, `clipper_inbox` | `SupabaseNoteApi`, filters UI, badge widget. |
| Note editor & block editor | `notes`, `note_blocks`, `note_tags`, `tags`, `attachments`, `note_links`, `note_tasks`, `reminders` | unified editor, attachments, backlinks, tasks. |
| Saved search management | `saved_searches` | repository + dialogs. |
| Tags screens | `tags`, `note_tags`, `notes` | renaming, counts. |
| Reminders screen | `reminders` | coordinator & UI. |
| Tasks/analytics | `note_tasks`, `user_preferences` | `TaskAnalyticsService`, time tracking dashboard. |
| Inbox & clipper | `clipper_inbox`, `inbound_aliases`, `inbound_attachments`, `attachments` | email/web clipper flows, alias management. |
| Notifications | `user_devices`, `notification_preferences`, `notification_events`, `notification_deliveries` | push token sync, queue processing, delivery audit. |
| Settings | `user_preferences`, `password_history`, `security_alerts`, `user_keys`, `user_encryption_keys` | theme/language, passphrase change, security logs. |
| GDPR/export cleanup | `notes`, `note_tasks`, `folders`, `tags`, `reminders`, `attachments`, `notification_deliveries`, `user_devices`, `password_history`,`security_alerts` | ensures delete/export routines work. |

## 10. RPC & Edge Function Summary
- **RPCs (MVP)**: `user_devices_upsert`, `generate_user_alias`, `should_send_notification`.
- **RPCs (Post-migration)**: `update_inbox_attachments` (writes attachment metadata to `clipper_inbox` for email ingest pipeline).
- **Edge functions (MVP)**: `email-inbox`, `inbound-web`, `inbound-web-auth`, `send-push-notification`, `send-push-notification-v1`, `process-notification-queue`, `process-fcm-notifications`, `fcm-notification-v2`, `setup-push-cron`, `test-fcm-simple`, `remove-cron-spam`.
- Ensure service role secrets are configured for each function post-migration.

## 11. After MVP Candidates
- `notification_events`, `notification_templates`, `notification_stats`, `notification_health_checks`, `notification_cron_jobs`.
- Advanced analytics tables (`analytics_events`, etc.).
- Additional security/audit tables (`security_events`, `login_attempts`, `rate_limits`, `rate_limit_log`).
- Review once new feature sets are scoped; update UI/service layers accordingly.

---

Use this document when authoring the baseline migration (`2025xxxx000000_initial_baseline.sql`). Any future schema change must update this inventory so the code and database remain aligned.
