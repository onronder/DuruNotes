# Road to Production: Task System & Reminder Refactor

This document lays out a comprehensive, end-to-end plan to bring the current refactored codebase to production readiness. It assumes the starting point is the repository state observed on the latest audit (legacy task widgets still active, unified service not yet wired through all screens, reminders recently refactored, etc.). Follow each stage in order; do not skip steps.

---

## Phase 0 – Preparation & Safety Net

1. **Confirm branch status**
   - Ensure all work is on a dedicated feature branch.
   - Pull the latest `main` and rebase to avoid integration surprises.

2. **Snapshot existing behaviour**
   - Run `flutter analyze` (or `dart analyze`) against the current tree and save the output.
   - Run the full test suite (`flutter test` / integration tests) and archive reports.
   - If a staging app exists, capture baseline screenshots or screencasts of critical task flows.

3. **Enable fast iterative testing**
   - Create scripts (if not already available) to run analyzer + unit tests (`scripts/verify_refactor_fixes.sh`, etc.).
   - Configure IDE run/debug profiles for the Task Management screen and reminder flows.

---

## Phase 1 – Stabilise Reminder & Feature Flag Infrastructure

1. **Reminder cleanup audit**
   - Confirm `ReminderCoordinator` (legacy) and `ReminderCoordinatorRefactored` do not diverge in functionality. Diff line-by-line.
   - Ensure the refactored version is behind a feature flag and defaulted to the intended audience.

2. **Feature flag wiring**
   - Verify `FeatureFlags` reads from remote config (or configure overrides for production environment).
   - Add automated sanity check (e.g., startup log or unit test) that flags are initialised before service usage.

3. **Reminder service tests**
   - Expand coverage: add integration test hitting `ReminderCoordinatorRefactored` end-to-end (create, snooze, cancel).
   - Add regression tests for notification scheduling issues identified during refactor.

4. **Docs update**
   - Ensure `docs/refactor_audit_report.md` reflects reminder status and any known caveats.

Outcome: reminder stack is production-ready, FeatureFlags are controlled centrally, rollbacks documented.

---

## Phase 2 – Legacy Task Widget Migration

### Step 2.1 – Preserve Legacy Implementation

1. **Rename legacy files**
   - Rename current widgets to `*_legacy.dart` (e.g., `task_card_legacy.dart`).
   - Update all imports referencing these files accordingly.

2. **Freeze legacy code**
   - Add comment block stating “DO NOT MODIFY – kept for reference only. Scheduled for removal in Phase 4.”
   - Optional: apply `// ignore_for_file: deprecated_member_use` hints to reduce noise.

### Step 2.2 – Implement Unified Widgets

1. **Create new widget suite** (all using `NoteTask` + `UnifiedTaskService`):
   - `task_item_widget.dart`
   - `task_tree_widget.dart`
   - `hierarchical_task_list_view.dart`
   - `task_item_with_actions.dart`
   - `task_item_shared.dart` (optional shared components)
   - `todo_block_widget.dart`
   - `hierarchical_todo_block_widget.dart`

2. **Widget implementation guidelines**
   - Inject `UnifiedTaskService` via Riverpod (`ConsumerWidget` / `ConsumerStatefulWidget`).
   - Replace `VoidCallback` props with direct service calls (e.g., `onTap: () => service.onStatusChanged(task.id, …)`).
   - Ensure widgets handle loading/error states gracefully when service operations fail (display SnackBars or inline errors).
   - Support accessibility: semantics labels, focus handling, keyboard shortcuts where appropriate.

3. **Shared util updates**
   - Remove `TaskModelConverter` usage inside new widgets. Use the database model directly.
   - Keep `TaskWidgetAdapter` temporarily for screens that still pass legacy data.

4. **Unit/UI tests**
   - Add widget tests that render each new component with a fake `UnifiedTaskService` (mock via Riverpod providers).
   - Test state transitions: toggling completion, changing priority, editing due date.

### Step 2.3 – Screen Integration

1. **Identify all screens/dialogs using task widgets**
   - `TaskManagementScreen`
   - `EnhancedTaskListScreen`
   - `TaskMetadataDialog`
   - Note editor blocks (`TodoBlockWidget`, `HierarchicalTodoBlockWidget`)
   - Analytics overlays, quick capture flows, etc.

2. **Refactor each screen**
   - Import the new widgets instead of legacy ones.
   - Replace local callback plumbing with direct service usage (e.g., pass only task IDs and let the widget call `UnifiedTaskService`).
   - Standardise on `AsyncValue<List<NoteTask>>` patterns for data loading.
   - Ensure filters (show/hide completed, priority sorting) operate on `NoteTask` enums.

3. **Remove duplicate logic**
   - Delete any screen-specific utilities that are now redundant (e.g., manual status toggles).
   - Delegate global operations (batch update, statistics) to `UnifiedTaskService` only.

4. **Manual verification**
   - Run through each screen manually:
     - Create/edit/delete tasks
     - Toggle completion
     - Adjust priority/due date
     - Work with subtasks and hierarchical views
   - Note and fix any regressions.

Outcome: entire UI backed by `UnifiedTaskService`, no legacy callbacks in active code.

---

## Phase 3 – Service Hardening & Cleanup

1. **`UnifiedTaskService` audit**
   - Ensure every public method handles errors (log + analytics + user feedback).
   - Verify stream controller is properly closed (`ref.onDispose`).
   - Review content hash strategy; replace naive `hashCode` if necessary with a stable hash or diff approach.

2. **Analytics & monitoring**
   - Confirm analytics events are consistent (`task.created`, `task.status_changed`, etc.).
   - Introduce monitoring hooks (e.g., `TaskSyncMetrics`) to track performance and failures.

3. **Performance testing**
   - Seed database with large task hierarchies and profile screens for frame build times.
   - Optimise queries (add indexes or caching if needed).

4. **API/Repository consistency**
   - Ensure other services (`EnhancedTaskService`, `BidirectionalTaskSyncService`, etc.) use `UnifiedTaskService` or are deprecated.
   - Remove conflicting services or mark them clearly as legacy.

Outcome: central task service is robust, observable, and performant.

---

## Phase 4 – Decommission Legacy Code

1. **Verify zero legacy references**
   - Global search for `UiNoteTask`, `UiTaskStatus`, `TaskWidgetAdapter`, `*legacy.dart` imports.
   - Replace or delete remaining usages.

2. **Remove legacy files**
   - Delete `*_legacy.dart`, `task_model_converter.dart`, `task_widget_adapter.dart` once no longer referenced.
   - Regenerate lint/analyser baselines.

3. **Update TODO documentation**
   - Replace `docs/TASK_WIDGET_MIGRATION_TODO.md` with a completion note.
   - Archive migration guide or convert to “Historical Reference.”

4. **Final code cleanup**
   - Run `dart format` across modified directories.
   - Ensure no lingering `ignore_for_file` or temporary backups remain.

Outcome: codebase contains only the unified task implementation; legacy shims removed entirely.

---

## Phase 5 – Testing & Quality Gates

1. **Static analysis**
   - Run `flutter analyze` (or `dart analyze`) with zero warnings/errors.
   - Fix any new lints introduced during migration.

2. **Unit & widget tests**
   - Execute `flutter test` with coverage reporting.
   - Focus on reminder flows, task CRUD, hierarchical operations, and UI behaviour.

3. **Integration tests**
   - Update or add integration tests that drive the new Task Management screen (e.g., golden tests or Flutter driver scenarios).
   - Ensure saved search filters still work after refactor.

4. **Performance regressions**
   - Run performance tests (`flutter drive`, custom benchmarks) to ensure no regressions in scrolling or data operations.

5. **Manual QA checklist**
   - Re-run all manual test cases documented in Phase 0.
   - Have another developer/QA sign off on functionality.

Outcome: thorough validation; all quality gates green.

---

## Phase 6 – Deployment Readiness

1. **Documentation**
   - Update `docs/refactor_audit_report.md`, `ROADMAP.md`, and any API docs to reflect the new architecture.
   - Produce a CHANGELOG entry summarising the migration.

2. **Training & handover**
   - Hold a knowledge-transfer session with the team.
   - Update onboarding docs or component catalogues with instructions for using the unified widgets.

3. **Feature flag strategy**
   - Decide whether to roll out task changes behind a new flag or go live immediately.
   - Plan rollout (staged vs full) and rollback procedure.

4. **Release checklist**
   - Verify localisation (strings like “Task deleted”, “Task created successfully”).
   - Ensure build pipelines (CI/CD) pass with new code.
   - Tag release candidate and run smoke tests on staging.

Outcome: codebase ready to be shipped; documentation aligned.

---

## Phase 7 – Post-Deployment Monitoring

1. **Production checks**
   - Monitor logs/analytics for increases in task-related errors or unusual patterns.
   - Track feature flag metrics if rolled out gradually.

2. **User feedback loop**
   - Collect feedback from support channels, beta testers, or internal dogfooding.
   - Prioritise bugfixes or UX adjustments as necessary.

3. **Tech debt review**
   - Schedule a follow-up review (e.g., two weeks post-release) to evaluate code quality and identify further refactors.

Outcome: deployment validated, ongoing maintenance planned.

---

## Appendix – Command Cheat Sheet

```bash
# Format & analyse
flutter format .
flutter analyze

# Run unit & widget tests
flutter test --coverage

# Integration / E2E (example)
flutter drive --target=test_driver/app.dart

# Verify feature flags script (if provided)
bash scripts/verify_feature_flags.sh

# Reminder regression tests
flutter test test/services/base_reminder_service_test.dart

# Task service widget tests (example)
flutter test test/ui/task/task_widget_test.dart
```

---

By following this plan step-by-step—without skipping migrations or cleanup—you’ll ensure the application runs live without errors and the latest task/reminder architecture is production-ready.
