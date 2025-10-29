# Supabase/Postgres Migration Conventions

We follow a strict naming and authoring scheme to keep migrations predictable across all environments.

## File naming

- Prefix every migration with a UTC timestamp in `YYYYMMDDHHMMSS` format.
- Add a short snake_case description after the timestamp.
- Example: `20250301000000_initial_baseline_schema.sql`
- For multipart batches, append an ordering suffix: `20250301000000_01_create_orders.sql`.

## Authoring guidelines

- Use `BEGIN; ... COMMIT;` blocks and guard DDL with `IF EXISTS` / `IF NOT EXISTS` where safe.
- Keep each migration focused on a single logical change. Include dependent index/RLS statements in the same file.
- Annotate irreversible operations (`DROP TABLE`, etc.) so reviewers can call out risk.
- Explicitly qualify schema names (`public.notes`, `auth.users`).
- When adding RLS, also add indexes for columns referenced by policies.

## Workflow

1. Generate the migration under `supabase/migrations/`.
2. Add associated validation scripts under `supabase/validation/` if useful.
3. Document the change in `docs/SUPABASE_SCHEMA_INVENTORY.md` / `docs/SUPABASE_SCHEMA_BLUEPRINT.md`.
4. Never rename a migration after it has been applied in any environment; create a follow-up migration instead.

Adhering to these rules prevents ordering conflicts and keeps review/rollback safe.

## Local (Drift) Schema Version Tracker

| Version | Migration | Purpose | Data Safety Notes |
|---------|-----------|---------|-------------------|
| 36 | Inline (AppDb) | Add `created_at` column to `local_notes` | Backfills with prior `updated_at` timestamp; guarded by timestamp comparison to avoid repeated writes. |
| 37 | `migration_37_note_tags_links_userid.dart` | Add `user_id` columns to `note_tags` and `note_links`, rebuild tables | Backfills from parent note ownership; orphaned rows removed post-migration; indexes re-applied idempotently. |
| 38 | `migration_38_note_folders_userid.dart` | Add `user_id` column to `note_folders` | Backfills from owning note or folder; rows with unresolved ownership deleted before indexes restored. |

> _Note:_ Earlier schema versions (≤35) are documented inline in `AppDb.onUpgrade` and remain unchanged.
