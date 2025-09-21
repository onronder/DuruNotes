# Item 1 – Toolchain, Automation & Environment Cleanup

This document inventories the current state of the toolchain/automation surface, highlights issues, and prescribes a step-by-step execution plan. Apply the steps in sequence; later tasks depend on earlier remediations.

---
## 1. Current State Assessment

### 1.1 SDK & Package Constraints
- `pubspec.yaml` pins `environment.sdk: ^3.9.0` and `flutter: ">=3.9.0"`, while dependencies mix bleeding-edge (e.g. `firebase_core ^3.4.1`) with older constraints (e.g. `shared_preferences ^2.5.3`, `flutter_riverpod ^2.6.1`). No explicit lock on Dart/Flutter toolchain versions used in CI or Docker.
- `analysis_options.yaml` rolls in `flutter_lints` but redefines ~180 individual rules, many redundant or conflicting (e.g. both `prefer_single_quotes` and `prefer_adjacent_string_concatenation`).
- Sentry tooling (`sentry_dart_plugin`) remains in `dev_dependencies`, but build scripts do not invoke it.

### 1.2 Automation Scripts & CI Assets
- `ci_scripts/` contains bespoke Xcode shell wrappers (`ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`, `fix_flutter_framework.sh`) from an older Apple pipeline. No references in repo (no GitHub Actions, Bitrise, or fastlane integration).
- `scripts/` mixes Node-based migration inspectors (`analyze_db.js`, `check_migration_status.js`) with shell utilities (`configure_ios_push.sh`), SQL fragments, JSON reports, and archived data. A full `node_modules/` tree plus `package.json` remain committed.
- Root shell helpers (`deploy_edge_functions.sh`, `deploy_quick_capture_function.sh`, `DEPLOY_TO_PRODUCTION.sh`, `docker-start.sh`, `update_app_icon.sh`, `fix_print_statements.sh`, etc.) target superseded flows (Quick Capture, legacy Supabase deployments) with hard-coded secrets/paths.
- `Makefile` duplicates `docker-start.sh` functionality using deprecated `docker-compose` CLI syntax and interactive prompts, making it unsuitable for CI automation.

### 1.3 Environment & Configuration
- Environment templates are fragmented: `env.example` (edge functions) and `docker.env.example` (full production) hold overlapping but inconsistent variables; secrets (Supabase anon/service keys, Sentry DSN) are committed in plaintext.
- `.env` (in repo root) exists, implying local secrets tracked in VCS (must confirm contents/removal).
- Docker resources (`docker-compose.yml`, `docker-start.sh`, `volumes/` scaffolding) reference Supabase ports and assume local volumes without documenting prerequisites. No pruning of volumes data or guidance for headless CI.
- Residual config: `.flutter-plugins-dependencies`, `.vscode/`, `.cursor`, `.claude`, `.metadata`, `android/.flutter-plugins`, etc. remain untracked for cleanup.

### 1.4 Deployment & Ops Artifacts
- Supabase functions deployment scripts use raw Supabase CLI without environment validation or key rotation; duplicates with `DEPLOY_TO_PRODUCTION.sh`.
- `deploy_edge_functions.sh` emphasises manual confirmation; no automated fallback/backups.
- No consolidated documentation for required secrets, CLI versions, or deployment order; docs scattered in `docs/road2prod_*` and README references stale flows.

---
## 2. Cleanup & Refactor Plan

Execute these phases sequentially. Each task lists dependencies and deliverables to keep the cleanup deterministic.

### Phase 1 — Define Supported Toolchain
1. **Lock versions**: decide target Flutter/Dart SDK (e.g. Flutter 3.22+) and update `pubspec.yaml` `environment` stanza plus `.metadata` if retained.
2. **Regenerate lock files**: run `flutter pub upgrade --major-versions` once dependencies align; update `pubspec.lock` and verify transitive constraints.
3. **Trim analysis rules**: reduce `analysis_options.yaml` to :
   - Base include: `package:flutter_lints/flutter.yaml`.
   - Keep only project-specific additions (e.g. `strict-*` language flags, 10–15 extra rules). Document rationale in comments.
4. **Confirm global scripts**: remove `sentry_dart_plugin` if unused, or wire it into CI (Phase 4). Document required global tools (Flutter, Dart, Supabase CLI, Firebase CLI) in README.

### Phase 2 — Rationalise Environment Files
1. **Sanitise secrets**: remove committed `.env`; rotate any leaked Supabase/Sentry keys. Replace sensitive values in templates with placeholders.
2. **Merge templates**: consolidate `env.example` and `docker.env.example` into a single `.env.example` with environment-specific overrides (use comments or `.env.local`/`.env.prod` pattern). Delete redundant templates.
3. **Document variables**: add a `docs/environment.md` describing each variable, default, and where it is consumed.
4. **Update Docker assets**: parameterise `docker-compose.yml` using the unified env file (e.g. referencing `${SUPABASE_URL}`) and remove embedded default secrets.

### Phase 3 — Prune Legacy Automation Scripts
1. **Inventory usage**: map each file under `scripts/` to current workflows. Categorise: *still required*, *replace with CLI*, *obsolete*. Remove reports (`*.json`), archived SQL, and unused `archive/` directories.
2. **Remove Node toolchain**: if no active scripts require Node, delete `scripts/package.json`, `package-lock.json`, and `node_modules/`. If some scripts stay, convert them to Dart or document Node version + usage.
3. **Delete unused root scripts**: retire `deploy_edge_functions.sh`, `deploy_quick_capture_function.sh`, `DEPLOY_TO_PRODUCTION.sh`, `fix_print_statements.sh`, `fix_with_opacity.sh`, `fix_with_values.sh`, etc., unless they remain part of release flow.
4. **Simplify Makefile / docker-start**: choose a single entry point (prefer Makefile with non-interactive commands). Update to `docker compose` syntax, add env validation, and remove overlapping `docker-start.sh`.

### Phase 4 — Standardise CI / CD Hooks
1. **Assess `ci_scripts/`**: determine if any platform (Xcode Cloud, Fastlane, GitHub Actions) still invokes these shell scripts. If not, remove folder; otherwise migrate logic into the new CI provider.
2. **Add modern pipeline templates**: introduce minimal GitHub Actions (or chosen CI) workflow invoking `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed` using the locked toolchain.
3. **Codify static checks**: add scripts (e.g. `tool/ci.sh`) to wrap analyzer/tests for local use, ensuring parity with CI.

### Phase 5 — Document & Verify
1. **Write `docs/toolchain.md`** summarising supported SDK versions, required CLIs, env setup steps, and how to run local services.
2. **Update README** with simplified setup instructions referencing the new env template, Docker commands, and CI pipeline.
3. **Run validation**: execute `dart format`, `dart analyze`, `flutter test`, and Docker health checks to confirm no references to removed files remain.
4. **Track in changelog**: log major cleanup actions, highlighting removed automation scripts and new setup steps.

---
## 3. Deliverables Checklist
- [x] Updated `pubspec.yaml` & `analysis_options.yaml` reflecting supported SDK and streamlined lint rules.
- [x] Single `.env.example` template with sanitized values and supporting documentation.
- [x] Pruned `scripts/`, `ci_scripts/`, root shell helpers, and `node_modules/` (unless still required).
- [x] Simplified Docker tooling (`Makefile` or replacement) with non-interactive commands and documented usage.
- [x] Configured CI workflow aligned with the locked toolchain.
- [x] Documentation (README + `docs/toolchain.md`) describing setup, env variables, and automation expectations.
- [ ] Analyzer/tests passing with no references to removed artifacts.

## Status
- [x] Locked Flutter/Dart SDK versions and refreshed dependency constraints via `flutter pub upgrade --major-versions`.
- [x] Reduced `analysis_options.yaml` to project-specific additions on top of `flutter_lints`.
- [x] Replaced duplicated environment templates with a unified `env.example`, removed `.env` from version control, and documented variables in `docs/environment.md`.
- [x] Removed legacy automation scripts (Node-based tools, deployment shells, archived reports) and rebuilt `scripts/` with a single verification entry point.
- [x] Migrated to `docker compose` commands in the `Makefile` and scrubbed hard-coded secrets from `docker-compose.yml`.
- [x] Introduced GitHub Actions CI (`.github/workflows/ci.yml`) running format/analyze/tests.
- [x] Added `docs/toolchain.md` and updated the project `README.md` to reflect the new workflow.
- [ ] Run analyzer/tests: pending due to existing code issues outside the scope of Item 1.
