# Ready-To-Go Continuation Prompt (Phase 1 – Day 3 Follow-Up)

## Completed since last session
- Landing `Migration34NoteTasksUserId` with backfill + orphan cleanup; ensured Phase 1 indexes are replayed via `Migration32Phase1PerformanceIndexes.ensureNoteTasksIndexes`.
- Regenerated Drift (schema version 34) so every task access path now requires `userId`; `AppDb` helpers/watchers, companions, and queue utilities enforce authenticated parameters.
- Hardened task stack callers: `TaskCoreRepository`, `NotesCoreRepository`, `EnhancedTaskService`, `TaskReminderBridge`, `UnifiedShareService`, `UnifiedSyncService`, and task providers all resolve `_requireUserId()` and pass IDs through to the database.
- Updated Master Plan (Phase 1 ▸ Day 3) to capture the execution notes and residual follow-ups.

## Still outstanding / next actions
1. Update remaining tests & fixtures for the new `NoteTasksCompanion.insert` signature and shore up legacy `TaskService` references (now explicitly unsupported).
2. Wire the planned telemetry for task authorization events (`SecurityAuditTrail` + `PerformanceMonitor`) and exercise the 10k-task QA checklist (`DATABASE_TESTING_SCENARIOS.md §3.2`).
3. Proceed to Phase 1 Day 4 (NoteTags/NoteLinks `user_id`) once task fixture cleanup lands.

## How to pick up
- Regenerate mocks after adjusting tests: `flutter pub run build_runner build --delete-conflicting-outputs`.
- Focus next on task-related test suites (`test/services`, `test/security/task_repository_authorization_test.dart`, helpers under `test/helpers/`) to supply explicit `userId` values.
- After tests pass, continue with migration_35 for tags/links and propagate repository filters similar to the task changes.
