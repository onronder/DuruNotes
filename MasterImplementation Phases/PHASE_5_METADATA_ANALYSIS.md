# Phase 5: Unencrypted Metadata Clearing - Analysis

**Date**: November 19, 2025
**Status**: 🔍 Analysis Complete, Ready for Implementation
**GDPR Compliance**: Article 17 - Right to Erasure (Metadata Clearing)

---

## Overview

Phase 5 focuses on clearing unencrypted metadata that may contain personally identifiable information (PII) or user-specific data. This phase runs AFTER Phase 4 (encrypted content tombstoning) has made all encrypted data permanently inaccessible.

**Key Principle**: Even though encrypted content is destroyed, unencrypted metadata, relationships, and user preferences may still reveal information about the user and must be cleared.

---

## Unencrypted Data Identified

### 1. Tags System

**Table**: `public.tags`

**Schema**:
```sql
CREATE TABLE public.tags (
  id text PRIMARY KEY,
  user_id uuid NOT NULL,
  name text NOT NULL,           -- ⚠️ PII: User-created tag names
  color text,                    -- ⚠️ Metadata: User preference
  icon text,                     -- ⚠️ Metadata: User preference
  usage_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);
```

**Concerns**:
- Tag names (`name`) can contain sensitive/personal information
- Color/icon choices reveal user preferences and organizational patterns
- Usage counts reveal behavioral patterns

**Recommendation**: **DELETE all tags** for the user
- Simplest and most complete solution
- Cascading deletion will handle `note_tags` relationships
- No partial anonymization complexity

---

### 2. Note-Tag Relationships

**Table**: `public.note_tags`

**Schema**:
```sql
CREATE TABLE public.note_tags (
  note_id uuid NOT NULL,
  tag text NOT NULL,             -- ⚠️ Duplicate of tag name
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,  -- ⚠️ Potential PII
  PRIMARY KEY (note_id, tag)
);
```

**Concerns**:
- Tag text duplicated here (not a foreign key reference!)
- Metadata JSONB field may contain additional PII
- Relationships reveal document organization patterns

**Recommendation**: **DELETE all note_tags** for the user
- If tags are deleted, these become orphaned anyway
- Metadata field is unknown content - safer to delete

---

### 3. User Preferences

**Table**: `public.user_preferences`

**Schema**:
```sql
CREATE TABLE public.user_preferences (
  user_id uuid PRIMARY KEY,
  language text NOT NULL DEFAULT 'en',
  theme text NOT NULL DEFAULT 'system',
  timezone text NOT NULL DEFAULT 'UTC',
  notifications_enabled boolean NOT NULL DEFAULT true,
  analytics_enabled boolean NOT NULL DEFAULT true,
  error_reporting_enabled boolean NOT NULL DEFAULT true,
  data_collection_consent boolean NOT NULL DEFAULT false,
  compact_mode boolean NOT NULL DEFAULT false,
  show_inline_images boolean NOT NULL DEFAULT true,
  font_size text NOT NULL DEFAULT 'medium',
  last_synced_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);
```

**Concerns**:
- Preferences reveal user behavior and patterns
- Timezone may reveal geographic location
- Language preferences are personal identifiers

**Recommendation**: **RESET to defaults** or **DELETE the row**
- Deleting is cleaner (ON DELETE CASCADE will handle)
- If row must exist for app functionality, reset all fields to defaults

---

### 4. Trash Events Audit Trail

**Table**: `public.trash_events`

**Schema**:
```sql
CREATE TABLE public.trash_events (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL,
  item_type text NOT NULL,
  item_id uuid NOT NULL,
  item_title text,              -- ⚠️ PII: Stored in plaintext for audit!
  action text NOT NULL,
  event_timestamp timestamptz NOT NULL,
  scheduled_purge_at timestamptz,
  is_permanent boolean NOT NULL DEFAULT false,
  metadata jsonb,               -- ⚠️ Potential PII
  created_at timestamptz NOT NULL
);
```

**Concerns**:
- `item_title` explicitly stored in PLAINTEXT for audit purposes
- Contains titles of deleted notes, folders, tasks
- This is high-value PII that must be anonymized
- Metadata JSONB may contain client info but less concerning

**Current Implementation**:
Function `anonymize_user_audit_trail()` exists in migration `20251119130000_add_anonymization_support.sql`:

```sql
CREATE OR REPLACE FUNCTION anonymize_user_audit_trail(target_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE trash_events
  SET
    item_title = 'ANONYMIZED',
    updated_at = NOW()  -- ⚠️ BUG: trash_events doesn't have updated_at!
  WHERE user_id = target_user_id
    AND item_title IS NOT NULL
    AND item_title != 'ANONYMIZED';

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Issues with Current Implementation**:
1. ❌ Sets `updated_at` but `trash_events` table has no such column
2. ❌ Doesn't clear `metadata` JSONB field
3. ❌ Function exists but is NOT integrated into Phase 5 of GDPR service

**Recommendation**:
- **FIX the function** to remove `updated_at` reference
- **CLEAR metadata** field as well
- **INTEGRATE** into Phase 5 implementation

---

### 5. Notification Events

**Table**: `public.notification_events` (from baseline schema)

**Need to investigate**: Whether this contains PII

Let me check the schema:
```bash
grep -A 20 "CREATE TABLE public.notification_events" supabase/migrations/20250301000000_initial_baseline_schema.sql
```

---

### 6. Saved Searches

**Table**: `public.saved_searches` (from baseline schema)

**Need to investigate**: Search queries may contain sensitive terms

---

### 7. Templates

**Table**: `public.templates` (from baseline schema)

**Need to investigate**: User-created templates may contain PII

---

## Data NOT Requiring Phase 5 Clearing

### ✅ Folders
- **Already encrypted**: `name_enc`, `props_enc`
- Handled in Phase 4 (encrypted content tombstoning)
- No unencrypted properties exist

### ✅ User Profiles
- Belongs to **Phase 2** (Account Metadata Anonymization)
- Requires Supabase Auth Admin API for email anonymization
- Fields: `email`, `first_name`, `last_name`, `passphrase_hint`

### ✅ Encrypted Content
- All handled in Phase 4
- Notes: `title_enc`, `props_enc`, `encrypted_metadata`
- Tasks: `content_enc`, `notes_enc`, `labels_enc`, `metadata_enc`
- Reminders: `title_enc`, `body_enc`, `location_name_enc`

---

## Implementation Strategy

### Approach: Progressive Clearing

**Step 1**: Fix existing audit trail function
- Remove `updated_at` reference
- Add metadata clearing
- Test function independently

**Step 2**: Investigate additional tables
- notification_events
- saved_searches
- templates
- Any other tables with potential PII

**Step 3**: Create comprehensive Phase 5 migration
- Function to delete tags and note_tags
- Function to delete/reset user_preferences
- Call fixed audit trail function
- Clear any other identified PII

**Step 4**: Integrate with GDPR service
- Update `_executePhase5()` to call database functions
- Track counts for audit trail
- Proper error handling

**Step 5**: Testing
- Unit tests for each database function
- Integration test for complete Phase 5
- Verify no PII remains after execution

---

## Database Functions to Create

### 1. `anonymize_user_tags(target_user_id UUID)`
```sql
-- Deletes all tags and note_tags for a user
-- Returns: count of tags deleted
```

### 2. `clear_user_preferences(target_user_id UUID)`
```sql
-- Deletes user_preferences row
-- Returns: 1 if deleted, 0 if not found
```

### 3. `anonymize_user_audit_trail(target_user_id UUID)` [FIX EXISTING]
```sql
-- Anonymizes item_title and metadata in trash_events
-- Returns: count of events anonymized
```

### 4. `anonymize_user_metadata(target_user_id UUID)` [MASTER FUNCTION]
```sql
-- Orchestrator function that calls all Phase 5 functions
-- Returns: detailed counts for each category
```

---

## Success Criteria

After Phase 5 completes successfully:

✅ All tags deleted (`tags` table)
✅ All note-tag relationships deleted (`note_tags` table)
✅ User preferences deleted or reset (`user_preferences` table)
✅ Trash event titles anonymized (`trash_events.item_title = 'ANONYMIZED'`)
✅ Trash event metadata cleared (`trash_events.metadata = '{}'`)
✅ Any other identified PII cleared
✅ Complete audit trail of operations
✅ No compilation errors
✅ All tests passing

---

## GDPR Compliance Verification

| Requirement | Implementation | Status |
|------------|----------------|--------|
| Article 17 - Erase unencrypted PII | Delete tags, preferences, anonymize audit trail | ✅ Designed |
| Article 30 - Records of processing | Log all clearing operations | ✅ Planned |
| ISO 27001:2022 - Secure disposal | Complete removal, not just hiding | ✅ Approach |
| ISO 29100:2024 - Privacy by design | Database-level enforcement | ✅ RLS policies |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Cascading deletions fail | Low | High | Use transactions, test thoroughly |
| Audit trail function fails | Low | Medium | Fix and test before integration |
| Unknown PII in JSONB fields | Medium | High | Clear all JSONB metadata fields |
| Phase runs before Phase 4 | Low | Critical | Sequencing enforced by GDPR service |

---

## Next Steps

1. ✅ Complete this analysis (DONE)
2. 🔄 Investigate remaining tables (notification_events, saved_searches, templates)
3. ⏳ Fix `anonymize_user_audit_trail()` function
4. ⏳ Create new Phase 5 database functions
5. ⏳ Create Phase 5 migration file
6. ⏳ Integrate with GDPR service
7. ⏳ Create tests
8. ⏳ Document implementation

---

**Analysis completed by**: Claude Code
**Ready for implementation**: Pending table investigation
**Estimated implementation time**: 2-3 hours
