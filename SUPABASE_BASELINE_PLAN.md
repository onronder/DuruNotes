# Supabase Rebuild Plan (Project `mizzxiijxtbwrqgflpnp`)

This document captures the current app → Supabase contract and defines the clean baseline we will recreate for the new project.

## 1. Environment Snapshot
- Project ref: `mizzxiijxtbwrqgflpnp`
- REST URL: `https://mizzxiijxtbwrqgflpnp.supabase.co`
- Environments: single Supabase project shared by development and (future) production — treat migrations with production-grade discipline
- Attachments storage bucket already created
- Supabase CLI linked on local machine
- All legacy migrations and documentation removed from the repo (only `supabase/config.toml` and edge functions remain)

## 2. Runtime Dependencies

### 2.1 Tables referenced by the Flutter app
Detected by scanning the Dart sources (direct `supabase.from('<table>')` usage):

| Table | Notes |
|-------|-------|
| `notes` | Encrypted note blobs (`title_enc`, `props_enc`), `deleted`, `created_at`, `updated_at`, `user_id` |
| `folders` | Encrypted folder name/props (`name_enc`, `props_enc`), `deleted`, timestamps, `user_id` |
| `note_folders` | Mapping with `note_id`, `folder_id`, `user_id`, `added_at`; app assumes one folder per note |
| `note_tasks` | Task metadata (status, priority, etc.), linked to notes |
| `templates` | Optional feature; still queried |
| `attachments` | Binary metadata + storage path (paired with the storage bucket) |
| `clipper_inbox` | Email/web clipper ingest queue |
| `inbound-attachments`, `inbound-attachments-temp` | Intermediate storage during email processing |
| `inbound_aliases` | Email alias registry |
| `notification_preferences`, `notification_deliveries` | Push notification preferences & delivery receipts |
| `user_devices` | Push token registry (synced via `user_devices_upsert` RPC) |
| `user_keys`, `user_encryption_keys` | Encryption key material |
| `user_preferences` | UI/feature preferences for each user |
| `password_history`, `security_alerts` | Security/audit data |
| `tags`, `reminders`, `notification_*` tables | Referenced in services but some flows may be dormant—validate before pruning |

> **Action:** decide whether to keep every “extended” table above or trim the scope to the MVP feature set before generating the baseline.

### 2.2 RPC functions referenced
Detected via `.rpc('…')` usage:

| RPC | Purpose (from code) |
|-----|---------------------|
| `user_devices_upsert` | Upsert / verify device push token |
| `should_send_notification` | Notification throttling decision |
| `generate_user_alias` | Inbound email alias provisioning |
| `execute_migration_sql` | Used by tooling to run ad-hoc SQL (can probably be dropped) |
| `record_migration_completion` | Migration tracking helper (optional) |

### 2.3 Edge functions still in repo
Located under `supabase/functions/`:

- Push notification pipeline: `send-push-notification`, `send-push-notification-v1`, `process-notification-queue`, `process-fcm-notifications`, `setup-push-cron`, `test-fcm-simple`, `remove-cron-spam`
- Inbound email/clipper: `email-inbox`, `inbound-web`, `inbound-web-auth`
- Shared utilities under `_shared/` and `common/`

> **Action:** review which functions we plan to re-deploy for the MVP baseline versus archive for later phases.

### 2.4 Storage
- Bucket: `attachments` (Supabase storage)
- Any additional buckets should be recreated explicitly if required by the edge functions

## 3. Target Baseline Schema (Draft)

We will generate a single forward-only migration (`2025xxxx000000_initial_baseline.sql`) that:

1. Creates the core tables listed below with Postgres-native types (`uuid`, `bytea`, `text`, `timestamptz`, `boolean`, etc.)
2. Adds required constraints / indexes:
   - Primary keys (UUIDs for all IDs)
   - Unique constraints (e.g., `folders(user_id, path)` if we retain hierarchical paths)
   - Foreign keys for `note_folders`, `note_tasks`, etc. with `ON DELETE CASCADE` where appropriate
   - Indexes for sync filters (e.g., `notes(user_id, updated_at DESC)`, `folders(user_id, updated_at DESC)`)
3. Establishes minimal RLS policies:
   - `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
   - Policy template: `USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid())`
4. Defines required RPCs (`user_devices_upsert`, etc.) and grants execution rights
5. Seeds any required bootstrap data (e.g., default templates if the UI expects them)

### 3.1 Mandatory table specs (to refine while drafting the migration)

| Table | Core columns (remote) | Notes |
|-------|-----------------------|-------|
| `notes` | `id uuid pk`, `user_id uuid`, `title_enc bytea`, `props_enc bytea`, `deleted bool default false`, `created_at timestamptz default now()`, `updated_at timestamptz default now()`, optional `encrypted_metadata jsonb` | Keep bytea-only architecture; no legacy text columns |
| `folders` | `id uuid pk`, `user_id uuid`, `name_enc bytea`, `props_enc bytea`, `deleted bool`, timestamps | Consider unique `(user_id, props ->> 'path')` if paths used |
| `note_folders` | `note_id uuid pk`, `folder_id uuid`, `user_id uuid`, `added_at timestamptz default now()` | Ensure FK to `notes` / `folders` |
| `note_tasks` | Align with current service (status, priority enums as smallint/int, text blobs for encrypted payloads) |
| `templates` | If kept, store encrypted payloads similar to notes/folders |
| `attachments` | Metadata about storage objects (id, user_id, note_id, storage_path, mime_type, size, encryption info) |
| `clipper_inbox` | `id uuid`, `user_id`, plaintext fields or encrypted? (check inbound service) |
| `inbound_aliases` | `(user_id, alias)` composite PK |
| `notification_preferences` / `notification_deliveries` | Denormalized JSON/text columns as per service usage |
| `user_devices` | `id uuid`, `user_id uuid`, `device_id text`, `push_token text`, `platform text`, `app_version text`, timestamps |
| `user_keys`, `user_encryption_keys` | Mirror current encryption flow (key IDs, cipher text blobs) |
| `user_preferences` | JSON/text columns as per new feature module |
| `password_history`, `security_alerts` | Straight text + timestamp tables |

> The initial version of the migration will be generated from a curated schema map so we can review before applying.

## 4. Build Roadmap

1. **Schema mapping (in progress)**  
   - Extract final column/type decisions per table  
   - Confirm which “extended” tables (notifications, analytics, etc.) are in scope for the MVP

2. **Baseline migration authoring**  
   - Write `supabase/migrations/2025xxxx000000_initial_baseline.sql` implementing Section 3  
   - Add companion validation script (psql) to diff Supabase schema vs. locally-generated spec

3. **Environment configuration**  
   - Update `.env` templates (`assets/env/*.env`, root `.env.example`) with new `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`  
   - Remove old project refs (e.g., `jtaedgpxesshdrnbgvjr`) from scripts and code comments  
   - Document deploy commands in `supabase/README.md`

4. **Apply baseline**  
   - `supabase db push` (or `psql -f`) against the new project  
   - Run validation script and archive outputs

5. **Re-deploy edge functions (optional per scope)**  
   - Decide which functions to keep for MVP  
   - Update env variables/secrets (`SUPABASE_URL`, service role) for those functions  
   - `supabase functions deploy <name>`

6. **Forward-only workflow**  
   - Every schema change: update Drift → generate new migration → run validation → commit  
   - Maintain a lightweight `docs/SUPABASE_RUNBOOK.md` (or extend this doc) with the process

## 5. Open Questions / Decisions Needed
- Which notification/analytics/security tables do we truly need for the MVP? (Delete unused ones to keep baseline lean.)
- Do we keep both versions of push functions (`send-push-notification` and `-v1`) or consolidate?
- Are inbound email flows required on day one, or can the related tables/functions be deferred?
- Do we store `encrypted_metadata` as JSONB everywhere (matching server expectations) or keep text fields?
- **Authentication redesign:** confirm the target auth flow (Supabase Auth, external providers, invite-only, etc.), required metadata fields, and whether we need companion tables or edge functions (e.g., onboarding hooks, session logging). Align the Flutter login/signup/reset flows with the new contract before finalizing the baseline.

Once the schema mapping in Section 3 is finalized, I’ll produce the concrete baseline migration and validation scripts. Let me know if you want to trim/add anything before I codify it.
