# Supabase Rebuild Master Plan

_Target project_: `mizzxiijxtbwrqgflpnp` (single environment for dev + future prod)

## Phase 0 – Baseline Preparation (WIP)
1. **Schema inventory (complete)**  
   - See `docs/SUPABASE_SCHEMA_INVENTORY.md` for code-driven table/RPC requirements.
2. **Auth decision (complete)**  
   - Email/password only; collect first/last name + passphrase during onboarding.
3. **Repository cleanup (complete)**  
   - Old `docs/` removed, `supabase/migrations/` emptied, new plan docs added.

## Phase 1 – Schema Blueprint
1. Resolve open decisions:
   - Trim or keep extended tables (notifications, analytics, security audits).  
     - **Decision**: Keep push notification queue (`notification_events`) in the MVP baseline; defer analytics/health-check tables to Post-MVP.
   - Confirm inbound email + push notification flows needed for MVP.
   - Finalize onboarding data contract (first name, last name, passphrase hint) and update auth UI to capture required fields.
2. Design Postgres DDL for each required table:
   - Data types (uuid, bytea, jsonb), defaults, timestamps.
   - Primary keys, foreign keys, unique constraints.
   - Row-level security policies (`user_id = auth.uid()`).
   - Required indexes for sync/queries.
3. Define required RPCs (`user_devices_upsert`, `generate_user_alias`, etc.) and grant permissions.
4. Document Supabase auth extensions:
   - `user_profiles` table structure.
   - Any onboarding metadata / passphrase hints.

**Deliverable**: `docs/schema_blueprint.md` (✅ 2025-11-05) summarises tables, columns, constraints, policies, and index expectations.

## Phase 2 – Baseline Migration Authoring
1. Create `supabase/migrations/2025xxxx000000_initial_baseline.sql` implementing the blueprint:
   - Table creation order (dependencies respected).
   - Defaults (timestamps, booleans).
   - RLS enablement + policy creation.
   - RPC/function definitions.
   - Seed data if required (e.g., default templates).
2. Generate validation script `supabase/validation/check_baseline.sql` (✅ 2025-11-05):
   - Confirms table existence, column types, RLS status.
   - Can be run manually via `psql` or Supabase SQL editor.
3. Update environment helpers:
   - `.env.example`, `assets/env/*.env` (done for Supabase URL/keys).
   - Supabase CLI instructions (`supabase/README.md` or top-level runbook) — ✅ runbook updated 2025-11-05.

**Deliverable**: migration SQL + validation SQL checked into repo (baseline migrations already present; validation script added).

## Phase 3 – Apply & Verify Baseline
1. Apply migration to `mizzxiijxtbwrqgflpnp`:
   - `supabase db push` or `psql -f supabase/migrations/...` (✅ through 20251105000000).
2. Run validation script and archive results (`docs/validation/baseline_<date>.md`) — ✅ `baseline_20251105.md` added.
3. Update Flutter app config:
   - Confirm login/signup + passphrase flows succeed (manual QA).
   - Run integration tests touching Supabase. *(Pending)*
4. Document verification outcomes in `docs/SUPABASE_VALIDATION_LOG.md`. *(Pending — create log once full QA executes.)*

## Phase 4 – Edge Functions & Cron Deployment
1. For each function we keep:
   - Review dependencies (tables, RPCs, storage).
   - Update environment variables / secrets.
   - `supabase functions deploy <name>`.
   - **Reference**: `docs/SUPABASE_RUNBOOK.md` now lists the canonical deployment order (2025-11-05).
2. Recreate cron jobs if needed (`supabase functions deploy setup-push-cron`, `cron.schedule` SQL).
3. Log deployments and smoke test endpoints. *(Pending for the current cycle.)*

## Phase 5 – Forward-Only Workflow
1. Every schema change must include:
   - Drift update (if applicable).
   - New Supabase migration file.
   - Updated inventory doc if schema contract changes.
   - Validation steps (psql checks or automated tests).
2. Maintain `docs/SUPABASE_RUNBOOK.md` with:
   - Apply/testing instructions.
   - Rollback plan (restore from backups).
   - Edge function deployment notes.

## Immediate Next Actions
1. Deploy the edge function suite using `docs/SUPABASE_FUNCTIONS_CHECKLIST.md` and confirm cron jobs (`setup-push-cron`) are registered.  
2. Verify Supabase secrets (`SUPABASE_SERVICE_ROLE_KEY`, inbound HMAC/parse secrets, FCM key) are set for the project after deployment.  
3. Run the Supabase integration tests (auth + notifications) against the new project and log results in `docs/validation/baseline_<date>.md` or the validation log. *(Pending)*
4. Apply the inbox attachment migration (`20251103001000_inbox_attachments_rpc.sql`) and confirm the `update_inbox_attachments` RPC exists so email conversions retain linked files. *(Pending validation check – migration present but RPC still needs smoke test)*
