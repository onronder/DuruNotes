# Production Cleanup Plan

The following sequence standardises cleanup across the repository. Work through each section in order; downstream steps assume upstream tasks are complete.

## 1. Toolchain, Automation & Environments
- Align Flutter/Dart constraints (`pubspec.yaml`, `analysis_options.yaml`, CI scripts) and drop unused scripts under `scripts/`, `ci_scripts/`, `tools/`; remove legacy shell helpers replaced by current workflows.
- Reconcile environment samples (`env.example`, `docker.env.example`, `Makefile`, `docker-compose.yml`) with production requirements; delete stale *.example files and sync secrets/flags naming.
- Audit Git hooks, `Makefile` targets, and automation scripts (`scripts/verify_task_system.sh`, `scripts/create_test_templates.dart`) for obsolete arguments; remove or rewrite against the modern service layer.

## 2. Core Application Bootstrap
- Simplify entrypoints (`lib/main.dart`, `lib/app.dart`, platform-specific `ios/`, `android/` runners) and excise unused global singletons (e.g. `analytics`, `logger` indirections) in favour of DI via Riverpod providers.
- Consolidate configuration loaders (`lib/core/feature_flags.dart`, `.env` ingestion, `supabase/` setup) and delete dead flag definitions or toggles referencing removed features.

## 3. Data & Storage Layer
- Regenerate Drift schema (`lib/data/local/app_db.dart`, `lib/data/local/app_db.g.dart`, `drift_schemas/`) after pruning unused tables/columns (e.g. legacy reminder/task adapters, deprecated metadata fields).
- Remove duplicate repositories (`lib/repository/`) where services already expose equivalent APIs (e.g. `TemplateRepository`, `NotesRepository` duplicates) and rewrite call sites to shared data sources.
- Eliminate raw SQL helpers (`cleanup_duplicate_folders.sql`, ad-hoc maintenance scripts) once functionality is captured in automated migrations or services.

## 4. Services & Domain Logic
- Collapse parallel reminder implementations (`lib/services/reminders/*` legacy vs refactored) into a single coordinator; delete unused adapters (`reminder_coordinator_refactored.dart`, legacy snooze/geofence variants) and update providers accordingly.
- Merge task services (`enhanced_task_service.dart`, `unified_task_service.dart`, `note_task_coordinator.dart`, `bidirectional_task_sync_service.dart`) into a single authoritative module; remove legacy Hierarchical sync layers once callers migrate.
- Review AI/analytics utilities (`lib/services/ai/*`, `task_analytics_service.dart`, `ai_insights_service.dart`) for placeholders and incomplete models; delete stubs that aren't wired into production flows.
- Standardise monitoring/performance helpers (`lib/services/monitoring/*`, `lib/services/performance/*`) after Sentry update—remove unused wrappers, ensure caching/optimizer utilities share common logging and leave only active entry points.

## 5. Presentation Layer (UI & Widgets)
- Remove legacy widget stacks suffixed `_legacy` or `old` (`lib/ui/widgets/blocks/*_legacy.dart`, `lib/ui/widgets/task_tree_widget_legacy.dart`, `lib/ui/widgets/hierarchical_task_list_view_legacy.dart`); migrate remaining screens to the unified task/reminder flow.
- Delete unused screens and dialogs (`lib/ui/reminders_screen.dart`, redundant modals) once functionality is covered elsewhere, or rewrite them against current providers if still required.
- Clean up feature-flagged UI branches (`lib/ui/widgets/blocks/feature_flagged_block_factory.dart`, `lib/ui/widgets/task_model_converter.dart`) by removing toggles for decommissioned features and consolidating to a single code path.
- Purge unused assets (`assets/`, `design/` comps) and deprecated localization entries (`lib/l10n/*.arb`) after UI rationalisation; rerun `flutter gen-l10n`.

## 6. Testing & QA Infrastructure
- Delete skipped or obsolete integration suites (`integration_test/quick_capture_integration_test.dart`, legacy pagination tests) and rebuild coverage around the unified task/reminder flows.
- Update mocks/generators (`test/**/*.mocks.dart`) once services are consolidated; remove generated files for deleted classes to avoid stale analyzer errors.
- Refresh golden tests/assets if UI output changes; drop unused baselines under `test/` and `docs/baselines/`.

## 7. Documentation & Operational Notes
- Replace fragmented road-to-production docs (`docs/road2prod_phase*.md`, `docs/reminder_coordinator_diff.md`, status notes) with a single up-to-date runbook outlining architecture, feature flags, deployment steps, and rollback procedures.
- Audit README and onboarding guides to match the cleaned feature set; remove references to retired modules and ensure dependency/setup instructions are accurate.

## 8. Dependency & Build Verification
- After each removal, run `dart analyze`, `flutter test`, and relevant integration checks; ensure CI pipelines reflect the trimmed surface area.
- Finalise by generating a minimal CHANGELOG entry summarising the cleanup and tagging a release candidate once the repository is analyzer- and test-clean.
