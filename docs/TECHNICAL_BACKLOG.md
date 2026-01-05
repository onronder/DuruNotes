# Technical Backlog

Generated: 2026-01-05T08:15:45Z
Updated: 2026-01-05T11:00:46Z

Context:
- App is currently distributed via TestFlight, not full production.
- This backlog captures all audit findings; items are open unless marked otherwise.

## P0 - Critical

P0-SEC-01 Remove or explicitly accept committed secrets
- Status: Done (risk acceptance documented)
- Scope: `sentry.properties`, `assets/env/dev.env`, `assets/env/staging.env`, `assets/env/prod.env`
- Risk: Auth tokens and keys can be abused even in TestFlight or dev environments.
- Subtasks:
  - Document acceptance for keeping existing values in TestFlight. (Done: `docs/SECURITY_RISK_ACCEPTANCE.md`)
  - If removal is chosen later, rotate tokens and update CI secrets.
  - Ensure local secrets remain untracked.
- Acceptance criteria:
  - Secrets are not stored in VCS (or risk acceptance is documented in `docs/`).
  - If removal is chosen, revoke/rotate tokens and regenerate build secrets.

P0-SEC-02 Restore local at-rest encryption or update security claims
- Status: Done (docs aligned; SQLCipher deferred)
- Scope: `lib/data/local/app_db.dart`, `lib/core/security/database_migration_helper.dart`, `pubspec.yaml`
- Risk: Local SQLite DB is unencrypted; FTS stores plaintext.
- Subtasks:
  - Pick local encryption strategy (SQLCipher or field-level only).
  - Wire migration helper into database initialization.
  - Update security docs and UX messaging if local DB stays plaintext.
- Acceptance criteria:
  - SQLCipher (or equivalent) is enabled and migration is wired, or
  - Security docs/README explicitly state local DB is not encrypted and UX messaging is aligned.

P0-OPS-01 Align CI env output with runtime loader
- Status: Done (working tree)
- Scope: `lib/core/config/environment_config.dart`, `.github/workflows/ci-build-test.yml`, `.github/workflows/deploy-production.yml`
- Risk: Builds can ship with stale or wrong env values.
- Subtasks:
  - Verify CI writes `assets/env/dev.env`, `assets/env/staging.env`, `assets/env/prod.env`.
  - Validate runtime loader resolves these files in all build modes.
- Acceptance criteria:
  - CI outputs `assets/env/dev.env`, `assets/env/staging.env`, `assets/env/prod.env`.
  - Environment loader resolves these files in all build modes.

P0-CRYPTO-01 Consolidate encryption architecture
- Status: In progress (migration runner wired; legacy AES services deprecated)
- Scope: `lib/core/crypto/crypto_box.dart`, `lib/services/encryption_sync_service.dart`, `lib/services/account_key_service.dart`, `lib/services/security/encryption_service.dart`, `lib/services/security/proper_encryption_service.dart`, `supabase/migrations/20250301000000_initial_baseline_schema.sql`
- Risk: Multiple encryption systems and key tables increase data loss/unlock failure risk.
- Subtasks:
  - Select canonical encryption path and key source of truth. (Done: AccountKeyService + CryptoBox)
  - Gate cross-device flow to avoid unintended use. (Done)
  - Deprecate unused AES-based services. (Done)
  - Implement migration + tests for legacy ciphertext formats. (Runner wired; tests pending)
- Acceptance criteria:
  - One canonical encryption path and key source of truth.
  - Migration plan + tests for old ciphertext formats and keys.

## P1 - High

P1-SEC-03 Eliminate plaintext task/FTS storage
- Status: Open
- Scope: `supabase/migrations/20250301000000_initial_baseline_schema.sql`, `supabase/migrations/20251023135444_add_task_encryption_columns.sql`, `lib/data/local/app_db.dart`
- Risk: Task content and FTS index plaintext undermines zero-knowledge claims.
- Subtasks:
  - Backfill encrypted task columns and stop plaintext writes.
  - Remove plaintext task columns after verification.
  - Rebuild FTS from decrypted data only.
- Acceptance criteria:
  - Encrypted columns are source of truth; plaintext columns removed after backfill.
  - FTS indexes only decrypted content derived at runtime.

P1-OBS-01 Redact PII from logs and audit trails
- Status: Open
- Scope: `lib/services/unified_sync_service.dart`, `lib/services/security/security_audit_trail.dart`, `lib/services/trash_audit_logger.dart`, `lib/core/monitoring/app_logger.dart`, `lib/core/logging/logger_config.dart`
- Risk: Note titles/content/metadata can leak via logs and Sentry.
- Subtasks:
  - Inventory log lines with note content or metadata.
  - Add redaction or remove sensitive fields in release mode.
  - Validate Sentry scrubbing rules in release builds.
- Acceptance criteria:
  - Release builds redact or disable sensitive fields.
  - Sentry scrubbing and local log sanitization verified.

P1-SYNC-01 Complete conflict resolution logic
- Status: Open
- Scope: `lib/services/unified_sync_service.dart`
- Risk: Remote conflicts can drop data or produce inconsistent states.
- Subtasks:
  - Implement remote-to-local conversion in conflict resolution.
  - Add deterministic merge strategy for notes/tasks/folders.
  - Cover conflict cases with tests.
- Acceptance criteria:
  - `useRemote` and `merge` branches implemented.
  - Conflict cases covered by tests.

P1-CRYPTO-02 Gate cross-device encryption rollout
- Status: Done (flag off)
- Scope: `lib/features/encryption/encryption_feature_flag.dart`, `lib/app/app.dart`, `lib/features/auth/providers/encryption_state_providers.dart`
- Risk: Test-only features enabled in release flows can break unlock/migration.
- Subtasks:
  - Default flags off in release builds or gate by flavor.
  - Track unlock/migration failures with telemetry.
  - Define rollback switch and recovery steps.
- Acceptance criteria:
  - Flags default off for release or feature is fully hardened.
  - Migration telemetry confirms safe unlock rates.

P1-BACKEND-01 Harden edge function security controls
- Status: Done
- Scope: `supabase/functions/email-inbox/index.ts`, `supabase/functions/inbound-web/index.ts`, `supabase/config.toml`
- Risk: HMAC compare not constant-time, rate limits are in-memory, JWT verification disabled for webhooks.
- Subtasks:
  - Replace HMAC compare with constant-time comparison. (Done)
  - Persist rate limits (DB-backed in edge functions). (Done)
  - Document and enforce JWT/origin policy per endpoint. (Done)
- Acceptance criteria:
  - Constant-time HMAC compare.
  - Durable rate limiting (Redis or DB).
  - JWT and origin policies documented and enforced for each endpoint.

## P2 - Medium

P2-SEC-04 Remove weak DB encryption fallback
- Status: Open
- Scope: `lib/core/security/database_encryption.dart`
- Risk: Deterministic fallback key reduces local security.
- Subtasks:
  - Remove deterministic fallback key generation.
  - Define user recovery behavior when key is unavailable.
  - Add tests for failure and recovery paths.
- Acceptance criteria:
  - Fail-safe behavior or explicit user recovery flow.
  - No fixed or predictable fallback keys.

P2-SEC-05 Use cryptographic RNG for auth secrets
- Status: Open
- Scope: `lib/core/security/security_initialization.dart`
- Risk: JWT/CSRF secrets derived from time-based values.
- Subtasks:
  - Generate secrets via secure RNG.
  - Store in secure storage or rotate per session.
  - Add rotation policy and tests.
- Acceptance criteria:
  - Secrets generated from a secure RNG.
  - Stored in secure storage or rotated per session.

P2-CRYPTO-03 Reduce key table/KDF fragmentation
- Status: Open
- Scope: `supabase/migrations/20250301000000_initial_baseline_schema.sql`, `lib/services/encryption_sync_service.dart`, `lib/services/account_key_service.dart`
- Risk: Multiple key tables and KDFs complicate migrations and decryption.
- Subtasks:
  - Choose canonical key table and KDF policy.
  - Migrate existing users to the canonical table.
  - Deprecate legacy table and update clients.
- Acceptance criteria:
  - Single key table/KDF policy.
  - Deprecation path for legacy table with migration tooling.

P2-BACKEND-02 Persist edge rate limits and queues
- Status: Open
- Scope: `supabase/functions/email-inbox/index.ts`, `supabase/functions/inbound-web/index.ts`
- Risk: In-memory rate limits reset on cold starts or deploys.
- Subtasks:
  - Implement Redis or Postgres backed rate limiting.
  - Add queueing/retry strategy for inbound events.
  - Document operational runbooks.
- Acceptance criteria:
  - Rate limits stored in Redis or Postgres.
  - Queueing/retry strategy documented.

## P3 - Low / Debt

P3-CODE-01 Remove unused or duplicate services/providers
- Status: Open
- Scope: `lib/services/auth/secure_auth_service.dart`, `lib/services/security/proper_encryption_service.dart`, `lib/providers/providers.dart`, `lib/providers/providers_refactored.dart`
- Subtasks:
  - Identify unused providers and services.
  - Remove or consolidate implementations.
  - Update references and tests.
- Acceptance criteria:
  - Dead code removed or consolidated.
  - References updated and tests pass.

P3-DEV-01 Tighten analyzer coverage
- Status: Open
- Scope: `analysis_options.yaml`
- Subtasks:
  - Re-evaluate test exclusions.
  - Promote critical lints to error where possible.
  - Update CI policy for analyzer warnings.
- Acceptance criteria:
  - Tests are included or excluded with justification.
  - Critical lints promoted to error as appropriate.

P3-OPS-01 Document scripts and ownership
- Status: Open
- Scope: `scripts/README.md`
- Subtasks:
  - Inventory scripts and categorize by use.
  - Add usage notes and owners.
  - Link to related docs where applicable.
- Acceptance criteria:
  - Each script listed with purpose, usage, and owner/contact.

P3-HYGIENE-01 Remove committed log/test artifacts
- Status: Open
- Scope: `analysis.log`, `run.log`, `test_output.log`, similar
- Subtasks:
  - Remove tracked artifacts from VCS.
  - Add ignore rules for new artifacts.
  - Verify clean working tree after test runs.
- Acceptance criteria:
  - Artifacts removed from VCS and ignored in `.gitignore`.
