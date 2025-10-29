# Legacy Test Status Tracker

| Test File | Status | Reason for Skip | Owner / Follow-up |
| --- | --- | --- | --- |
| test/step2_sync_verification_deployment_test.dart | Restored | Rebuilt against current sync validator + Supabase harness (`AppDb.forTesting`, fake remote APIs) | Add folder drift regression coverage before declaring suite complete |
| test/integration/notes_full_workflow_test.dart | Restored | In-memory end-to-end note lifecycle using NotesCoreRepository + stubbed auth | Consider UI-driven integration once widget harness is ready |
| test/critical/database_clearing_test.dart | Restored | Reauthored with in-memory AppDb verifying `clearAll()` purges all tables + FTS | Add regression for concurrent sign-out once multi-user harness exists |
| test/critical/database_isolation_integration_test.dart | Restored | Uses NotesCoreRepository with stubbed Supabase auth verifying per-user scoping | Add concurrency regression (multi-session switch) in future |
| test/critical/rls_enforcement_test.dart | Restored | Contract tests ensure NotesCoreRepository enforces per-user guards with stubbed Supabase auth | Add live Supabase contract test when integration env is available |
| test/critical/encryption_integrity_test.dart | Restored | Exercised AccountKeyService key lifecycle with in-memory secure storage | Add remote Supabase contract tests for user_keys upsert later |
| test/critical/user_id_validation_test.dart | Restored | Contract tests ensure NotesCoreRepository requires authenticated user for mutations | Add Supabase integration coverage for remote APIs later |
| test/features/notes/pagination_regression_test.dart | Restored | Validates NotesPaginationNotifier paging + dedupe guards with counting repository harness | Add ENEX pagination regression coverage once widget harness lands |
| test/features/templates/template_management_integration_test.dart | Restored | Validates TemplateCoreRepository create/apply flows with fake notes repo + sync queue | Extend to cover duplicateTemplate once note duplication harness ships |
| test/features/folders/inbox_preset_chip_test.dart | Restored | Widget tests cover inbox preset chip visibility + toggling with fake repositories | Extend with failure-state coverage (invalid attachments, error analytics) |
| test/features/folders/folder_undo_service_test.dart | Restored | Covers FolderUndoService add/undo flows with recording repository and history stream | Add multi-user collision + failure-path regression cases |
| test/features/folders/all_notes_drop_target_test.dart | Restored | Widget tests cover All Notes drop target hover + unfile flows with fake repositories | Extend coverage for undo snackbar tap-through once integration harness exists |
| test/repositories/notes_core_repository_test.dart | Restored | In-memory AppDb harness validates hydration, pagination ordering, and create/update encryption paths | Extend with delete/undo flows, tag/link persistence, and indexer invocation assertions once harness available |
| test/services/undo_redo_service_test.dart | Restored | Modern undo stack tests cover note/batch folder moves, expiration handling, and persistence rehydration | Add cross-user isolation + analytics hooks once service exposes them |
| test/services/metadata_preservation_test.dart | Restored | TaskCoreRepository metadata suite ensures labels, reminders, and position survive updates | Add domain-level sync coverage when UnifiedSyncService note parsing stabilizes |
| test/services/import_encryption_indexing_test.dart | Restored | Validates ImportService markdown path with mocked repo/indexer and analytics hooks | Add ENEX multi-note + progress callback edge cases next |
| test/services/import_integration_simple_test.dart | Restored | Uses in-memory AppDb + NotesCoreRepository to verify end-to-end markdown/Obsidian import wiring | Extend to cover ENEX parsing + attachment metadata flows |
| test/services/share_extension_service_test.dart | Restored | Validates share extension text/image/file flows via ReceiveSharingIntent + mocked attachments | Add iOS app group method-channel coverage when platform harness exists |
| test/services/no_duplicate_tasks_test.dart | Restored | Validates TaskCoreRepository stable-hash dedupe & TaskSyncMetrics tracking | Add domain-level dedupe integration once UnifiedSyncService harness is ready |
| test/services/deep_linking_test.dart | Restored | Exercised deep link fallbacks + task action plumbing with modern service | Expand coverage for successful navigation flows when widget harness is ready |
| test/debug_import_test.dart | Restored | Smoke-tests UnifiedImportService debug harness with fake repos | Consider integration coverage with real repositories if diagnostics expand |
| test/providers/notes_repository_auth_regression_test.dart | Restored | Re-authored with modern provider overrides ensuring auth guard resilience | Expand with signed-in scenarios once auth harness is available |
| test/search/unified_search_service_test.dart | Restored | Rewritten with in-memory domain repositories verifying user-scoped search | Maintain coverage as unified search expands (FTS path still pending) |
| test/infrastructure/repositories/template_core_repository_test.dart | Restored | Reauthored with in-memory AppDb and userId resolver verifying per-user isolation | Expand to cover updateTemplate/watchTemplates flows |
| test/infrastructure/repositories/folder_core_repository_test.dart | Restored | In-memory AppDb + user resolver to exercise folder isolation/ownership paths | Extend to cover note listing once decryption cache has test harness |
| test/services/note_link_parser_test.dart | Restored | Replaced with in-memory domain coverage for link extraction/search respecting user isolation | Extend once NoteIndexer gains multi-user scenarios |
| test/services/permission_manager_test.dart | Restored | Reworked around unified permission manager singleton covering observers + request flow smoke tests | Layer in channel-mocked regressions to assert per-platform results |
| test/services/quick_capture_service_test.dart | Restored | Verifies modern QuickCaptureService capture flow, queue fallback, widget payload formatting (ISO8601, snippets), and cache refresh | Add platform channel + widget integration coverage after WidgetKit rollout |
| test/services/snooze_functionality_test.dart | Restored | Covers SnoozeReminderService flow with mocked DB + notifications verifying limits & rescheduling | Add processSnoozedReminders coverage with batch reschedule scenarios |
| test/services/task_reminder_linking_test.dart | Restored | Ports TaskReminderBridge flows with Riverpod-injected mocks covering create/cancel/snooze linking | Add tests for failure retries and remote sync error handling |
| test/services/analytics_goals_test.dart | Restored | Rebuilt with SharedPreferences-backed ProductivityGoalsService and mocked analytics stats | Add reminder notification assertions once unified notification harness exists |
| test/services/base_reminder_service_test.dart | Restored | Covers database + notification flow on new BaseReminderService via Riverpod-injected mocks | Expand with permission channel assertions once platform harness exists |
| test/services/domain_task_controller_test.dart | Restored | Reauthored with fake task repo + stubbed EnhancedTaskService verifying reminder orchestration | Add multi-user collision + failure paths when reminder bridge harness lands |
| test/services/enhanced_task_service_isolation_test.dart | Restored | Uses in-memory AppDb + stub crypto to enforce per-user task isolation post-migration | Expand to cover reminder updates and note deletion cascades |
| test/services/gdpr_export_compliance_test.dart | Restored | In-memory AppDb + mock crypto/export stack verifying GDPR export decryption | Add Supabase contract coverage once remote export pipeline stabilizes |
| test/services/data_migration/saved_search_migration_service_test.dart | Restored | In-memory AppDb verifying saved search user_id backfill with mocked Supabase auth | Add partial failure + remote sync regressions later |
| test/services/task_analytics_service_test.dart | Restored | Provider overrides + fake task repo compute category metrics on new domain stack | Extend with productivity goals + trend analytics scenarios |

> This tracker is the single source of truth for legacy suites. When a test is rewritten, update this table (status → Replaced/Restored) and link to the new coverage.
