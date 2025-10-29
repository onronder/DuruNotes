# Supabase Runbook – Project `mizzxiijxtbwrqgflpnp`

## Prerequisites
- Supabase CLI installed (`npm install -g supabase` or download binary).
- Supabase personal access token with project access.
- Service-role database password (from Supabase Dashboard → Settings → Database) stored securely.
- `psql` client available locally.

## CLI Authentication & Linking
```bash
supabase login                # paste personal access token
supabase link --project-ref mizzxiijxtbwrqgflpnp
```

The link command writes the project reference into `supabase/config.toml`, so subsequent CLI commands target this project.

## Local Dry Run (Disposable Postgres Container)
1. Start a fresh container:
   ```bash
   docker run --rm --name supabase-dryrun \
     -e POSTGRES_USER=postgres \
     -e POSTGRES_PASSWORD=postgres \
     -e POSTGRES_DB=duru \
     -p 5434:5432 \
     -d postgres:15
   ```
2. Seed minimal Supabase auth stubs (required for policies):
   ```bash
   docker exec supabase-dryrun psql -U postgres -d duru -c \
     "CREATE SCHEMA IF NOT EXISTS auth;
      CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";
      CREATE TABLE IF NOT EXISTS auth.users (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        email text,
        raw_user_meta_data jsonb,
        created_at timestamptz,
        updated_at timestamptz
      );"

   docker exec supabase-dryrun psql -U postgres -d duru -c \
     \"CREATE OR REPLACE FUNCTION auth.uid()
        RETURNS uuid
        LANGUAGE sql
        STABLE
        AS \$\$ SELECT '00000000-0000-0000-0000-000000000000'::uuid; \$\$;\"
   ```
3. Apply the baseline migration:
   ```bash
    docker exec -i supabase-dryrun psql -U postgres -d duru -v ON_ERROR_STOP=1 \
      -f - < supabase/migrations/20250301000000_initial_baseline_schema.sql
   ```
4. Run the validation checklist:
   ```bash
   docker exec -i supabase-dryrun psql -U postgres -d duru -v ON_ERROR_STOP=1 \
     -f - < supabase/validation/check_baseline.sql
   ```
5. Stop the container when finished:
   ```bash
   docker stop supabase-dryrun
   ```

## Applying to Supabase Cloud
1. Export the database URL (replace placeholders):
   ```bash
   export SUPABASE_DB_URL='postgres://postgres:<SERVICE_ROLE_PASSWORD>@db.mizzxiijxtbwrqgflpnp.supabase.co:5432/postgres'
   ```
2. Push the migration:
   ```bash
   supabase db push --db-url "$SUPABASE_DB_URL"
   ```
3. Run the validation script against the hosted database:
   ```bash
   psql "$SUPABASE_DB_URL" -f supabase/validation/check_baseline.sql
   ```
4. Confirm the inbox attachments RPC shipped with the latest migration:
   ```bash
   psql "$SUPABASE_DB_URL" -c "\df+ update_inbox_attachments"
   ```
5. Archive the validation output in `docs/validation/baseline_<date>.md`.

## Edge Functions & Cron Jobs
Recommended deployment order (matches `supabase/functions` directories):
```bash
supabase functions deploy send-push-notification
supabase functions deploy process-fcm-notifications
supabase functions deploy remove-cron-spam
supabase functions deploy setup-push-cron
supabase functions deploy test-fcm-simple
```

After deploying:
1. Register cron schedules:
   ```bash
   supabase functions invoke setup-push-cron
   ```
2. Confirm secrets:
   ```bash
   supabase secrets list
   ```
   Make sure the service-role key, FCM credentials, inbound email secrets, and reminder payload keys are set.
3. Smoke test `process-fcm-notifications` and `send-push-notification` with a safe payload (use non-production device tokens).
4. Log results in `docs/validation/baseline_<date>.md`.

## Schema Validation Checklist
Run after every migration or Supabase deployment:
```bash
psql "$SUPABASE_DB_URL" -f supabase/validation/check_baseline.sql
```

Interpretation guide:
- Missing tables ⇒ migration or deployment failed.
- Nullable `user_id` columns ⇒ violates RLS assumptions; fix immediately.
- Missing indexes ⇒ dual-sync performance will regress; add via migration.
- RLS disabled ⇒ critical security issue; block release.

Document each run in `docs/validation/baseline_<yyyy-mm-dd>.md`.

## Dual Sync QA (Manual)
Perform before promoting a client build:
1. **Folders** – Move a note across multiple folders and back; confirm the second device mirrors the change after sync.
2. **Tasks** – Create tasks with tags, due dates, reminders, completions; verify Supabase `note_tasks` rows retain `labels` (`[]` when empty) and `metadata`.
3. **Reminders** – Create, snooze, and cancel reminders; inspect `public.reminders.metadata` for persisted payloads.
4. **Analytics** – Ensure time-tracking dashboards in Flutter update after the sync cycle.
5. Capture pass/fail with timestamps in `docs/validation/baseline_<date>.md`.

## Troubleshooting
- **`schema "auth" does not exist`**: create the `auth` schema and `auth.users` table before running migrations in local dry runs.
- **`function auth.uid() does not exist`**: define the stub helper shown above; the migration’s RLS policies call it.
- **Policy check fails in validation**: ensure `supabase/validation/check_baseline.sql` is up to date (`policyname` column) and re-run the migration if previous attempts were interrupted.

## Change Management
- All schema updates after the baseline must be delivered via new, forward-only migration files (timestamped `YYYYMMDDHHMMSS_description.sql`).
- Every schema change should update:
  1. `docs/schema_blueprint.md`
  2. `docs/SUPABASE_SCHEMA_INVENTORY.md`
  3. Add a new migration + corresponding validation notes.
