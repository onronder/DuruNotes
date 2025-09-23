-- =====================================================
-- PRODUCTION SAFE MIGRATION - PHASE 2: SCHEMA BRIDGE
-- =====================================================
-- Execute this script AFTER Phase 1 completion
-- This script creates schema transformation bridge tables
-- SAFE TO RUN: Creates temporary tables without modifying existing data
-- =====================================================

BEGIN;

-- Set safety timeouts
SET statement_timeout = '45min';
SET lock_timeout = '10min';

-- Verify Phase 1 completion
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM migration_log
        WHERE phase = 'phase1' AND operation = 'complete' AND status = 'completed'
    ) THEN
        RAISE EXCEPTION 'Phase 1 must be completed before running Phase 2';
    END IF;

    RAISE NOTICE 'Phase 1 verification passed. Starting Phase 2 at %', now();
END $$;

-- Log Phase 2 start
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('phase2', 'start', 'started', 'Beginning schema bridge creation');

-- =====================================================
-- 1. SCHEMA TRANSFORMATION BRIDGE TABLES
-- =====================================================

-- Notes transformation bridge table
CREATE TABLE IF NOT EXISTS schema_bridge_notes (
    -- Original local fields (for reference)
    local_id TEXT NOT NULL,
    local_title TEXT,
    local_body TEXT,
    local_updated_at TIMESTAMPTZ,
    local_metadata TEXT,
    local_is_pinned BOOLEAN DEFAULT false,
    local_note_type TEXT DEFAULT 'note',

    -- Transformed remote fields
    remote_id UUID DEFAULT gen_random_uuid(),
    remote_title_enc BYTEA,
    remote_props_enc BYTEA,
    remote_updated_at TIMESTAMPTZ,
    remote_encrypted_metadata TEXT,
    remote_is_pinned BOOLEAN DEFAULT false,
    remote_note_type TEXT DEFAULT 'note',

    -- Transformation tracking
    transform_status TEXT DEFAULT 'pending' CHECK (
        transform_status IN ('pending', 'processing', 'completed', 'failed', 'verified')
    ),
    transform_error TEXT,
    validation_passed BOOLEAN,
    validation_errors JSONB DEFAULT '[]',

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    processed_at TIMESTAMPTZ,

    -- Constraints
    PRIMARY KEY (local_id),
    UNIQUE (remote_id)
);

-- Tasks transformation bridge table
CREATE TABLE IF NOT EXISTS schema_bridge_tasks (
    -- Original local fields
    local_id TEXT NOT NULL,
    local_note_id TEXT,
    local_content TEXT,
    local_status INTEGER,
    local_priority INTEGER,
    local_due_date TIMESTAMPTZ,
    local_completed_at TIMESTAMPTZ,
    local_parent_task_id TEXT,
    local_position INTEGER DEFAULT 0,

    -- Transformed remote fields
    remote_id UUID DEFAULT gen_random_uuid(),
    remote_note_id UUID,
    remote_content TEXT,
    remote_status TEXT,
    remote_priority INTEGER,
    remote_due_date TIMESTAMPTZ,
    remote_completed_at TIMESTAMPTZ,
    remote_parent_id UUID,
    remote_position INTEGER DEFAULT 0,

    -- Transformation tracking
    transform_status TEXT DEFAULT 'pending' CHECK (
        transform_status IN ('pending', 'processing', 'completed', 'failed', 'verified')
    ),
    transform_error TEXT,
    validation_passed BOOLEAN,
    validation_errors JSONB DEFAULT '[]',

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    processed_at TIMESTAMPTZ,

    -- Constraints
    PRIMARY KEY (local_id),
    UNIQUE (remote_id)
);

-- Folders transformation bridge table
CREATE TABLE IF NOT EXISTS schema_bridge_folders (
    -- Original local fields
    local_id TEXT NOT NULL,
    local_name TEXT,
    local_parent_id TEXT,
    local_path TEXT,
    local_sort_order INTEGER DEFAULT 0,

    -- Transformed remote fields
    remote_id UUID DEFAULT gen_random_uuid(),
    remote_name_enc BYTEA,
    remote_props_enc BYTEA,
    remote_parent_id UUID,
    remote_sort_order INTEGER DEFAULT 0,

    -- Transformation tracking
    transform_status TEXT DEFAULT 'pending',
    transform_error TEXT,
    validation_passed BOOLEAN,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    PRIMARY KEY (local_id),
    UNIQUE (remote_id)
);

RAISE NOTICE 'Bridge tables created successfully';

-- =====================================================
-- 2. BRIDGE TABLE INDEXES
-- =====================================================

-- Notes bridge indexes
CREATE INDEX IF NOT EXISTS idx_bridge_notes_status
ON schema_bridge_notes(transform_status);

CREATE INDEX IF NOT EXISTS idx_bridge_notes_remote_id
ON schema_bridge_notes(remote_id);

CREATE INDEX IF NOT EXISTS idx_bridge_notes_created_at
ON schema_bridge_notes(created_at);

-- Tasks bridge indexes
CREATE INDEX IF NOT EXISTS idx_bridge_tasks_status
ON schema_bridge_tasks(transform_status);

CREATE INDEX IF NOT EXISTS idx_bridge_tasks_note_id
ON schema_bridge_tasks(local_note_id, remote_note_id);

-- Folders bridge indexes
CREATE INDEX IF NOT EXISTS idx_bridge_folders_status
ON schema_bridge_folders(transform_status);

CREATE INDEX IF NOT EXISTS idx_bridge_folders_parent
ON schema_bridge_folders(local_parent_id, remote_parent_id);

RAISE NOTICE 'Bridge table indexes created successfully';

-- =====================================================
-- 3. DATA TRANSFORMATION FUNCTIONS
-- =====================================================

-- Function to transform note type enum
CREATE OR REPLACE FUNCTION transform_note_type(local_type INTEGER)
RETURNS TEXT AS $$
BEGIN
    CASE local_type
        WHEN 0 THEN RETURN 'note';
        WHEN 1 THEN RETURN 'template';
        ELSE RETURN 'note';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to transform task status enum
CREATE OR REPLACE FUNCTION transform_task_status(local_status INTEGER)
RETURNS TEXT AS $$
BEGIN
    CASE local_status
        WHEN 0 THEN RETURN 'pending';
        WHEN 1 THEN RETURN 'in_progress';
        WHEN 2 THEN RETURN 'completed';
        WHEN 3 THEN RETURN 'cancelled';
        ELSE RETURN 'pending';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to validate transformation
CREATE OR REPLACE FUNCTION validate_note_transformation(
    p_local_id TEXT,
    p_local_title TEXT,
    p_remote_title_enc BYTEA,
    p_local_updated_at TIMESTAMPTZ,
    p_remote_updated_at TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
    errors JSONB := '[]';
    time_diff INTERVAL;
BEGIN
    -- Check required fields
    IF p_local_id IS NULL OR p_local_id = '' THEN
        errors := errors || '["Missing local ID"]';
    END IF;

    -- Check encryption
    IF p_local_title IS NOT NULL AND p_local_title != '' AND p_remote_title_enc IS NULL THEN
        errors := errors || '["Title encryption failed"]';
    END IF;

    -- Check timestamp conversion
    IF p_local_updated_at IS NOT NULL AND p_remote_updated_at IS NULL THEN
        errors := errors || '["Timestamp conversion failed"]';
    END IF;

    -- Check timestamp accuracy (allow 1 second difference)
    IF p_local_updated_at IS NOT NULL AND p_remote_updated_at IS NOT NULL THEN
        time_diff := ABS(EXTRACT(EPOCH FROM (p_local_updated_at - p_remote_updated_at)));
        IF time_diff > 1 THEN
            errors := errors || jsonb_build_array('Timestamp mismatch: ' || time_diff || ' seconds');
        END IF;
    END IF;

    RETURN errors;
END;
$$ LANGUAGE plpgsql;

-- Function to validate task transformation
CREATE OR REPLACE FUNCTION validate_task_transformation(
    p_local_id TEXT,
    p_local_status INTEGER,
    p_remote_status TEXT,
    p_local_note_id TEXT,
    p_remote_note_id UUID
)
RETURNS JSONB AS $$
DECLARE
    errors JSONB := '[]';
    expected_status TEXT;
BEGIN
    -- Check required fields
    IF p_local_id IS NULL OR p_local_id = '' THEN
        errors := errors || '["Missing local ID"]';
    END IF;

    -- Check status transformation
    expected_status := transform_task_status(p_local_status);
    IF p_remote_status != expected_status THEN
        errors := errors || jsonb_build_array('Status mismatch: expected ' || expected_status || ', got ' || p_remote_status);
    END IF;

    -- Check note ID mapping
    IF p_local_note_id IS NOT NULL AND p_remote_note_id IS NULL THEN
        errors := errors || '["Note ID mapping failed"]';
    END IF;

    RETURN errors;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'Transformation functions created successfully';

-- =====================================================
-- 4. BULK TRANSFORMATION PROCEDURES
-- =====================================================

-- Procedure to populate notes bridge table
CREATE OR REPLACE FUNCTION populate_notes_bridge(
    p_batch_size INTEGER DEFAULT 100,
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    processed_count INTEGER,
    error_count INTEGER,
    batch_time_ms INTEGER
) AS $$
DECLARE
    start_time TIMESTAMPTZ := clock_timestamp();
    end_time TIMESTAMPTZ;
    v_processed INTEGER := 0;
    v_errors INTEGER := 0;
    note_record RECORD;
    validation_result JSONB;
BEGIN
    RAISE NOTICE 'Starting notes bridge population with batch size %', p_batch_size;

    -- Process notes in batches
    FOR note_record IN
        SELECT
            id,
            title,
            body,
            updated_at,
            encrypted_metadata,
            is_pinned,
            note_type
        FROM notes
        WHERE deleted = false
        AND (p_user_id IS NULL OR user_id = p_user_id)
        AND id NOT IN (SELECT local_id FROM schema_bridge_notes)
        LIMIT p_batch_size
    LOOP
        BEGIN
            -- Insert into bridge table with basic transformation
            INSERT INTO schema_bridge_notes (
                local_id,
                local_title,
                local_body,
                local_updated_at,
                local_metadata,
                local_is_pinned,
                local_note_type,
                remote_updated_at,
                remote_encrypted_metadata,
                remote_is_pinned,
                remote_note_type,
                transform_status
            ) VALUES (
                note_record.id,
                note_record.title,
                note_record.body,
                note_record.updated_at,
                note_record.encrypted_metadata,
                note_record.is_pinned,
                transform_note_type(note_record.note_type),
                note_record.updated_at,
                note_record.encrypted_metadata,
                note_record.is_pinned,
                transform_note_type(note_record.note_type),
                'pending'
            );

            v_processed := v_processed + 1;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to process note %: %', note_record.id, SQLERRM;
            v_errors := v_errors + 1;
        END;
    END LOOP;

    end_time := clock_timestamp();

    RAISE NOTICE 'Notes bridge population completed: % processed, % errors',
        v_processed, v_errors;

    RETURN QUERY SELECT
        v_processed,
        v_errors,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Procedure to populate tasks bridge table
CREATE OR REPLACE FUNCTION populate_tasks_bridge(
    p_batch_size INTEGER DEFAULT 100,
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    processed_count INTEGER,
    error_count INTEGER,
    batch_time_ms INTEGER
) AS $$
DECLARE
    start_time TIMESTAMPTZ := clock_timestamp();
    end_time TIMESTAMPTZ;
    v_processed INTEGER := 0;
    v_errors INTEGER := 0;
    task_record RECORD;
    mapped_note_id UUID;
BEGIN
    RAISE NOTICE 'Starting tasks bridge population with batch size %', p_batch_size;

    FOR task_record IN
        SELECT
            id,
            note_id,
            content,
            status,
            priority,
            due_date,
            completed_at,
            parent_task_id,
            position
        FROM note_tasks
        WHERE deleted = false
        AND (p_user_id IS NULL OR user_id = p_user_id)
        AND id NOT IN (SELECT local_id FROM schema_bridge_tasks)
        LIMIT p_batch_size
    LOOP
        BEGIN
            -- Find mapped note ID from bridge table
            SELECT remote_id INTO mapped_note_id
            FROM schema_bridge_notes
            WHERE local_id = task_record.note_id;

            IF mapped_note_id IS NULL THEN
                RAISE WARNING 'No mapped note ID found for task %, note_id %',
                    task_record.id, task_record.note_id;
                v_errors := v_errors + 1;
                CONTINUE;
            END IF;

            -- Insert into bridge table
            INSERT INTO schema_bridge_tasks (
                local_id,
                local_note_id,
                local_content,
                local_status,
                local_priority,
                local_due_date,
                local_completed_at,
                local_parent_task_id,
                local_position,
                remote_note_id,
                remote_content,
                remote_status,
                remote_priority,
                remote_due_date,
                remote_completed_at,
                remote_position,
                transform_status
            ) VALUES (
                task_record.id,
                task_record.note_id,
                task_record.content,
                task_record.status,
                task_record.priority,
                task_record.due_date,
                task_record.completed_at,
                task_record.parent_task_id,
                task_record.position,
                mapped_note_id,
                task_record.content,
                transform_task_status(task_record.status),
                task_record.priority,
                task_record.due_date,
                task_record.completed_at,
                task_record.position,
                'pending'
            );

            v_processed := v_processed + 1;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to process task %: %', task_record.id, SQLERRM;
            v_errors := v_errors + 1;
        END;
    END LOOP;

    end_time := clock_timestamp();

    RETURN QUERY SELECT
        v_processed,
        v_errors,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::INTEGER;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'Bulk transformation procedures created successfully';

-- =====================================================
-- 5. VALIDATION AND MONITORING
-- =====================================================

-- Function to validate bridge table integrity
CREATE OR REPLACE FUNCTION validate_bridge_integrity()
RETURNS TABLE (
    bridge_table TEXT,
    total_records INTEGER,
    pending_records INTEGER,
    completed_records INTEGER,
    failed_records INTEGER,
    validation_passed INTEGER,
    validation_failed INTEGER
) AS $$
BEGIN
    -- Notes bridge validation
    RETURN QUERY
    SELECT
        'schema_bridge_notes'::TEXT,
        COUNT(*)::INTEGER,
        COUNT(CASE WHEN transform_status = 'pending' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN transform_status = 'completed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN transform_status = 'failed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN validation_passed = true THEN 1 END)::INTEGER,
        COUNT(CASE WHEN validation_passed = false THEN 1 END)::INTEGER
    FROM schema_bridge_notes;

    -- Tasks bridge validation
    RETURN QUERY
    SELECT
        'schema_bridge_tasks'::TEXT,
        COUNT(*)::INTEGER,
        COUNT(CASE WHEN transform_status = 'pending' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN transform_status = 'completed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN transform_status = 'failed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN validation_passed = true THEN 1 END)::INTEGER,
        COUNT(CASE WHEN validation_passed = false THEN 1 END)::INTEGER
    FROM schema_bridge_tasks;

    -- Folders bridge validation
    RETURN QUERY
    SELECT
        'schema_bridge_folders'::TEXT,
        COUNT(*)::INTEGER,
        COUNT(CASE WHEN transform_status = 'pending' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN transform_status = 'completed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN transform_status = 'failed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN validation_passed = true THEN 1 END)::INTEGER,
        COUNT(CASE WHEN validation_passed = false THEN 1 END)::INTEGER
    FROM schema_bridge_folders;
END;
$$ LANGUAGE plpgsql;

-- Create monitoring view for bridge progress
CREATE OR REPLACE VIEW bridge_transformation_progress AS
SELECT
    'notes' as entity_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN transform_status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN transform_status = 'processing' THEN 1 END) as processing,
    COUNT(CASE WHEN transform_status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN transform_status = 'failed' THEN 1 END) as failed,
    ROUND(
        100.0 * COUNT(CASE WHEN transform_status = 'completed' THEN 1 END) / COUNT(*),
        2
    ) as completion_percentage
FROM schema_bridge_notes

UNION ALL

SELECT
    'tasks' as entity_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN transform_status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN transform_status = 'processing' THEN 1 END) as processing,
    COUNT(CASE WHEN transform_status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN transform_status = 'failed' THEN 1 END) as failed,
    ROUND(
        100.0 * COUNT(CASE WHEN transform_status = 'completed' THEN 1 END) / COUNT(*),
        2
    ) as completion_percentage
FROM schema_bridge_tasks;

RAISE NOTICE 'Validation and monitoring views created successfully';

-- =====================================================
-- 6. EMERGENCY ROLLBACK PROCEDURES
-- =====================================================

-- Function to rollback Phase 2 (drop bridge tables)
CREATE OR REPLACE FUNCTION rollback_phase2()
RETURNS void AS $$
BEGIN
    RAISE NOTICE 'Starting Phase 2 rollback...';

    -- Drop bridge tables
    DROP TABLE IF EXISTS schema_bridge_notes CASCADE;
    DROP TABLE IF EXISTS schema_bridge_tasks CASCADE;
    DROP TABLE IF EXISTS schema_bridge_folders CASCADE;

    -- Drop transformation functions
    DROP FUNCTION IF EXISTS transform_note_type(INTEGER);
    DROP FUNCTION IF EXISTS transform_task_status(INTEGER);
    DROP FUNCTION IF EXISTS validate_note_transformation(TEXT, TEXT, BYTEA, TIMESTAMPTZ, TIMESTAMPTZ);
    DROP FUNCTION IF EXISTS validate_task_transformation(TEXT, INTEGER, TEXT, TEXT, UUID);
    DROP FUNCTION IF EXISTS populate_notes_bridge(INTEGER, UUID);
    DROP FUNCTION IF EXISTS populate_tasks_bridge(INTEGER, UUID);
    DROP FUNCTION IF EXISTS validate_bridge_integrity();

    -- Drop views
    DROP VIEW IF EXISTS bridge_transformation_progress;

    -- Log rollback
    INSERT INTO migration_log (phase, operation, status, message)
    VALUES ('phase2', 'rollback', 'completed', 'Phase 2 rollback completed successfully');

    RAISE NOTICE 'Phase 2 rollback completed successfully';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. CREATE PHASE 2 ROLLBACK POINT
-- =====================================================

INSERT INTO migration_rollback_points (phase, table_counts, index_list)
SELECT
    'phase2_start',
    get_table_counts(),
    ARRAY(
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
        AND (indexname LIKE 'idx_%' OR indexname LIKE 'bridge_%')
    );

RAISE NOTICE 'Phase 2 rollback point created';

-- =====================================================
-- 8. PHASE 2 COMPLETION
-- =====================================================

-- Log phase completion
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('phase2', 'complete', 'completed', 'Schema bridge creation completed successfully');

-- Display summary
DO $$
DECLARE
    bridge_tables_count INTEGER;
    functions_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO bridge_tables_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name LIKE 'schema_bridge_%';

    SELECT COUNT(*) INTO functions_count
    FROM information_schema.routines
    WHERE routine_schema = 'public'
    AND (routine_name LIKE '%transform%' OR routine_name LIKE '%bridge%');

    RAISE NOTICE '=== PHASE 2 SUMMARY ===';
    RAISE NOTICE 'Bridge tables created: %', bridge_tables_count;
    RAISE NOTICE 'Transformation functions created: %', functions_count;
    RAISE NOTICE 'Phase 2 completed at: %', now();
    RAISE NOTICE 'Next step: Populate bridge tables and execute Phase 3';
    RAISE NOTICE '======================';
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION INSTRUCTIONS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 Phase 2 Migration Completed Successfully!';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Populate bridge tables: SELECT * FROM populate_notes_bridge(100);';
    RAISE NOTICE '2. Monitor progress: SELECT * FROM bridge_transformation_progress;';
    RAISE NOTICE '3. Validate integrity: SELECT * FROM validate_bridge_integrity();';
    RAISE NOTICE '4. Execute Phase 3 when ready';
    RAISE NOTICE '';
    RAISE NOTICE 'Emergency Rollback: SELECT rollback_phase2();';
    RAISE NOTICE '';
END $$;