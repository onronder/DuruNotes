# Migration Consolidation Analysis

**Generated**: 2025-10-28T23:58:00.955275
**Total Migrations**: 9
**Applied**: 9
**Skipped**: 0

---

## Executive Summary

| Metric | Count |
|--------|-------|
| Total Migrations | 9 |
| Applied | 9 |
| Skipped | 0 |
| Conflicts | 0 |
| Naming Issues | 0 |

## Migration Categories

### SCHEMA_CHANGE (2 migrations)

- `20250301000000_initial_baseline_schema.sql` - ✅ APPLIED 
  - Tables: user_profiles, user_keys, user_encryption_keys, notes, folders, note_folders, note_blocks, note_tasks, templates, saved_searches, tags, note_tags, note_links, reminders, attachments, inbound, clipper_inbox, inbound_aliases, notification_events, user_devices, notification_preferences, notification_deliveries, user_preferences, password_history, security_alerts
  - Operations: CREATE_TABLE, ALTER_TABLE, CREATE_FUNCTION, CREATE_POLICY, CREATE_INDEX
- `20251023135444_add_task_encryption_columns.sql` - ✅ APPLIED 
  - Tables: note_tasks
  - Operations: ALTER_TABLE, CREATE_INDEX

### OTHER (6 migrations)

- `20251021120000_backfill_note_tasks_and_reminders.sql` - ✅ APPLIED 
  - Tables: note_tasks, reminders
  - Operations: CREATE_TABLE, ALTER_TABLE, CREATE_POLICY, CREATE_INDEX
- `20251103000000_clipboard_inbox_realtime.sql` - ✅ APPLIED 
  - Tables: realtime
  - Operations: ALTER_TABLE, CREATE_FUNCTION, CREATE_POLICY, CREATE_INDEX
- `20251103001000_inbox_attachments_rpc.sql` - ✅ APPLIED 
  - Tables: 
  - Operations: CREATE_FUNCTION
- `20251103002000_inbound_attachment_bucket_policies.sql` - ✅ APPLIED 
  - Tables: 
  - Operations: CREATE_POLICY
- `20251103003000_backfill_email_note_tags.sql` - ✅ APPLIED 
  - Tables: 
  - Operations: 
- `20251105000000_add_metadata_to_reminders.sql` - ✅ APPLIED 
  - Tables: reminders
  - Operations: ALTER_TABLE

### PERFORMANCE (1 migrations)

- `20251105093000_add_note_performance_indexes.sql` - ✅ APPLIED 
  - Tables: 
  - Operations: CREATE_INDEX

## Conflicts Detected

✅ No conflicts detected
## Recommendations

### Immediate Actions

1. **Fix Naming Issues** - 0 migrations need HHMMSS timestamps
2. **Review Duplicates** - 0 duplicate timestamp conflicts
3. **Analyze Skipped** - 0 skipped migrations need review

