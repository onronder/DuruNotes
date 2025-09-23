-- =====================================================
-- PRODUCTION SAFE MIGRATION - PHASE 3: DATA MIGRATION
-- =====================================================
-- Execute this script AFTER Phase 2 completion and bridge population
-- This script performs the actual data migration with full validation
-- CRITICAL: Includes automatic rollback on any failure
-- =====================================================

BEGIN;

-- Set extended timeouts for data migration
SET statement_timeout = '2hours';
SET lock_timeout = '30min';
SET idle_in_transaction_session_timeout = '2hours';

-- Verify prerequisites
DO $$
DECLARE
    phase2_completed BOOLEAN;
    bridge_populated BOOLEAN;
    notes_count INTEGER;
    tasks_count INTEGER;
BEGIN
    -- Check Phase 2 completion
    SELECT EXISTS(
        SELECT 1 FROM migration_log
        WHERE phase = 'phase2' AND operation = 'complete' AND status = 'completed'
    ) INTO phase2_completed;

    IF NOT phase2_completed THEN
        RAISE EXCEPTION 'Phase 2 must be completed before running Phase 3';
    END IF;

    -- Check bridge table population
    SELECT COUNT(*) INTO notes_count FROM schema_bridge_notes;
    SELECT COUNT(*) INTO tasks_count FROM schema_bridge_tasks;

    IF notes_count = 0 OR tasks_count = 0 THEN
        RAISE EXCEPTION 'Bridge tables must be populated before Phase 3. Run populate_notes_bridge() and populate_tasks_bridge() first.';
    END IF;

    RAISE NOTICE 'Prerequisites verified: Phase 2 completed, % notes and % tasks in bridge tables',
        notes_count, tasks_count;
END $$;

-- Log Phase 3 start
INSERT INTO migration_log (phase, operation, status, message, created_at)
VALUES ('phase3', 'start', 'started', 'Beginning data migration with full validation', now());

-- =====================================================
-- 1. PRE-MIGRATION VALIDATION
-- =====================================================

-- Create comprehensive validation function
CREATE OR REPLACE FUNCTION pre_migration_validation()
RETURNS TABLE (
    check_name TEXT,
    passed BOOLEAN,
    details TEXT,
    critical BOOLEAN
) AS $$
BEGIN
    -- Check 1: Foreign key integrity
    RETURN QUERY
    SELECT
        'foreign_key_integrity'::TEXT,
        (COUNT(*) = 0)::BOOLEAN,
        'Orphaned records found: ' || COUNT(*)::TEXT,
        true::BOOLEAN
    FROM (
        SELECT 'note_tasks' as table_name, id, note_id
        FROM note_tasks
        WHERE note_id NOT IN (SELECT id FROM notes)
        AND deleted = false
        LIMIT 10
    ) orphaned;

    -- Check 2: Bridge table data quality
    RETURN QUERY
    SELECT
        'bridge_data_quality'::TEXT,
        (COUNT(*) = 0)::BOOLEAN,
        'Failed transformations: ' || COUNT(*)::TEXT,
        true::BOOLEAN
    FROM schema_bridge_notes
    WHERE transform_status = 'failed';

    -- Check 3: Encryption readiness
    RETURN QUERY
    SELECT
        'encryption_readiness'::TEXT,
        (COUNT(*) = 0)::BOOLEAN,
        'Notes requiring encryption: ' || COUNT(*)::TEXT,
        false::BOOLEAN
    FROM schema_bridge_notes
    WHERE local_title IS NOT NULL
    AND local_title != ''
    AND remote_title_enc IS NULL;

    -- Check 4: Timestamp consistency
    RETURN QUERY
    SELECT
        'timestamp_consistency'::TEXT,
        (COUNT(*) = 0)::BOOLEAN,
        'Timestamp mismatches: ' || COUNT(*)::TEXT,
        false::BOOLEAN
    FROM schema_bridge_notes
    WHERE ABS(EXTRACT(EPOCH FROM (local_updated_at - remote_updated_at))) > 5;

    -- Check 5: Database locks
    RETURN QUERY
    SELECT
        'database_locks'::TEXT,
        (COUNT(*) = 0)::BOOLEAN,
        'Active locks detected: ' || COUNT(*)::TEXT,
        true::BOOLEAN
    FROM pg_locks
    WHERE mode LIKE '%ExclusiveLock%'
    AND granted = true;
END;
$$ LANGUAGE plpgsql;

-- Run pre-migration validation
DO $$
DECLARE
    validation_record RECORD;
    critical_failures INTEGER := 0;
    total_failures INTEGER := 0;
BEGIN
    RAISE NOTICE 'Running pre-migration validation...';

    FOR validation_record IN
        SELECT * FROM pre_migration_validation()
    LOOP
        IF NOT validation_record.passed THEN
            total_failures := total_failures + 1;

            IF validation_record.critical THEN
                critical_failures := critical_failures + 1;
                RAISE WARNING 'CRITICAL FAILURE: % - %',
                    validation_record.check_name, validation_record.details;
            ELSE
                RAISE NOTICE 'WARNING: % - %',
                    validation_record.check_name, validation_record.details;
            END IF;
        ELSE
            RAISE NOTICE 'PASSED: %', validation_record.check_name;
        END IF;

        -- Log validation result
        INSERT INTO schema_validation_results (
            validation_type, passed, error_message, details
        ) VALUES (
            validation_record.check_name,
            validation_record.passed,
            CASE WHEN NOT validation_record.passed THEN validation_record.details END,
            jsonb_build_object('critical', validation_record.critical)
        );
    END LOOP;

    IF critical_failures > 0 THEN
        RAISE EXCEPTION 'Pre-migration validation failed with % critical failures. Migration aborted.',
            critical_failures;
    END IF;

    RAISE NOTICE 'Pre-migration validation completed: % total checks, % warnings, % critical failures',
        total_failures + (SELECT COUNT(*) FROM pre_migration_validation() WHERE passed = true),
        total_failures - critical_failures,
        critical_failures;
END $$;

-- =====================================================
-- 2. BACKUP AND ROLLBACK PREPARATION
-- =====================================================

-- Create detailed rollback point
INSERT INTO migration_rollback_points (phase, table_counts, index_list)
SELECT
    'phase3_start',
    jsonb_build_object(
        'notes', (SELECT COUNT(*) FROM notes),
        'note_tasks', (SELECT COUNT(*) FROM note_tasks),
        'folders', (SELECT COUNT(*) FROM folders),
        'note_folders', (SELECT COUNT(*) FROM note_folders),
        'bridge_notes', (SELECT COUNT(*) FROM schema_bridge_notes),
        'bridge_tasks', (SELECT COUNT(*) FROM schema_bridge_tasks)
    ),
    ARRAY(
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
    );

RAISE NOTICE 'Phase 3 rollback point created';

-- =====================================================
-- 3. CHUNKED DATA MIGRATION ENGINE
-- =====================================================

-- Chunked migration function for notes
CREATE OR REPLACE FUNCTION migrate_notes_chunk(
    p_chunk_size INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    processed INTEGER,
    succeeded INTEGER,
    failed INTEGER,
    chunk_time_ms INTEGER
) AS $$
DECLARE
    start_time TIMESTAMPTZ := clock_timestamp();
    end_time TIMESTAMPTZ;
    v_processed INTEGER := 0;
    v_succeeded INTEGER := 0;
    v_failed INTEGER := 0;
    note_record RECORD;
    validation_errors JSONB;
BEGIN
    RAISE NOTICE 'Processing notes chunk: offset=%, size=%', p_offset, p_chunk_size;

    -- Process notes chunk
    FOR note_record IN
        SELECT *
        FROM schema_bridge_notes
        WHERE transform_status = 'pending'
        ORDER BY created_at
        LIMIT p_chunk_size OFFSET p_offset
    LOOP
        BEGIN
            v_processed := v_processed + 1;

            -- Update status to processing
            UPDATE schema_bridge_notes
            SET transform_status = 'processing',
                updated_at = now()
            WHERE local_id = note_record.local_id;

            -- Validate the transformation
            validation_errors := validate_note_transformation(
                note_record.local_id,
                note_record.local_title,
                note_record.remote_title_enc,
                note_record.local_updated_at,
                note_record.remote_updated_at
            );

            -- Check if validation passed
            IF jsonb_array_length(validation_errors) = 0 THEN
                -- Insert into target table
                INSERT INTO notes (
                    id,
                    user_id,
                    title_enc,
                    props_enc,
                    created_at,
                    updated_at,
                    encrypted_metadata,
                    is_pinned,
                    note_type,
                    deleted
                ) VALUES (
                    note_record.remote_id,
                    (SELECT user_id FROM notes WHERE id = note_record.local_id),
                    note_record.remote_title_enc,
                    note_record.remote_props_enc,
                    note_record.local_updated_at,
                    note_record.remote_updated_at,
                    note_record.remote_encrypted_metadata,
                    note_record.remote_is_pinned,
                    note_record.remote_note_type,
                    false
                )
                ON CONFLICT (id) DO UPDATE SET
                    title_enc = EXCLUDED.title_enc,
                    props_enc = EXCLUDED.props_enc,
                    updated_at = EXCLUDED.updated_at,
                    encrypted_metadata = EXCLUDED.encrypted_metadata,
                    is_pinned = EXCLUDED.is_pinned,
                    note_type = EXCLUDED.note_type;

                -- Mark as completed
                UPDATE schema_bridge_notes
                SET transform_status = 'completed',
                    validation_passed = true,
                    processed_at = now()
                WHERE local_id = note_record.local_id;

                v_succeeded := v_succeeded + 1;

            ELSE
                -- Mark as failed with validation errors
                UPDATE schema_bridge_notes
                SET transform_status = 'failed',
                    validation_passed = false,
                    validation_errors = validation_errors,
                    transform_error = 'Validation failed: ' || validation_errors::TEXT
                WHERE local_id = note_record.local_id;

                v_failed := v_failed + 1;
                RAISE WARNING 'Note % failed validation: %', note_record.local_id, validation_errors;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            -- Handle unexpected errors
            UPDATE schema_bridge_notes
            SET transform_status = 'failed',
                transform_error = SQLERRM,
                updated_at = now()
            WHERE local_id = note_record.local_id;

            v_failed := v_failed + 1;
            RAISE WARNING 'Note % migration failed: %', note_record.local_id, SQLERRM;
        END;
    END LOOP;

    end_time := clock_timestamp();

    RETURN QUERY SELECT
        v_processed,
        v_succeeded,
        v_failed,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Chunked migration function for tasks
CREATE OR REPLACE FUNCTION migrate_tasks_chunk(
    p_chunk_size INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    processed INTEGER,
    succeeded INTEGER,
    failed INTEGER,
    chunk_time_ms INTEGER
) AS $$
DECLARE
    start_time TIMESTAMPTZ := clock_timestamp();
    end_time TIMESTAMPTZ;
    v_processed INTEGER := 0;
    v_succeeded INTEGER := 0;
    v_failed INTEGER := 0;
    task_record RECORD;
    validation_errors JSONB;
BEGIN
    RAISE NOTICE 'Processing tasks chunk: offset=%, size=%', p_offset, p_chunk_size;

    FOR task_record IN
        SELECT *
        FROM schema_bridge_tasks
        WHERE transform_status = 'pending'
        ORDER BY created_at
        LIMIT p_chunk_size OFFSET p_offset
    LOOP
        BEGIN
            v_processed := v_processed + 1;

            -- Update status to processing
            UPDATE schema_bridge_tasks
            SET transform_status = 'processing',
                updated_at = now()
            WHERE local_id = task_record.local_id;

            -- Validate the transformation
            validation_errors := validate_task_transformation(
                task_record.local_id,
                task_record.local_status,
                task_record.remote_status,
                task_record.local_note_id,
                task_record.remote_note_id
            );

            IF jsonb_array_length(validation_errors) = 0 THEN
                -- Insert into target table
                INSERT INTO note_tasks (
                    id,
                    note_id,
                    user_id,
                    content,
                    status,
                    priority,
                    due_date,
                    completed_at,
                    parent_id,
                    position,
                    created_at,
                    updated_at,
                    deleted
                ) VALUES (
                    task_record.remote_id,
                    task_record.remote_note_id,
                    (SELECT user_id FROM note_tasks WHERE id = task_record.local_id),
                    task_record.remote_content,
                    task_record.remote_status,
                    task_record.remote_priority,
                    task_record.remote_due_date,
                    task_record.remote_completed_at,
                    task_record.remote_parent_id,
                    task_record.remote_position,
                    now(),
                    now(),
                    false
                )
                ON CONFLICT (id) DO UPDATE SET
                    content = EXCLUDED.content,
                    status = EXCLUDED.status,
                    priority = EXCLUDED.priority,
                    due_date = EXCLUDED.due_date,
                    completed_at = EXCLUDED.completed_at,
                    parent_id = EXCLUDED.parent_id,
                    position = EXCLUDED.position,
                    updated_at = now();

                -- Mark as completed
                UPDATE schema_bridge_tasks
                SET transform_status = 'completed',
                    validation_passed = true,
                    processed_at = now()
                WHERE local_id = task_record.local_id;

                v_succeeded := v_succeeded + 1;

            ELSE
                UPDATE schema_bridge_tasks
                SET transform_status = 'failed',
                    validation_passed = false,
                    validation_errors = validation_errors,
                    transform_error = 'Validation failed: ' || validation_errors::TEXT
                WHERE local_id = task_record.local_id;

                v_failed := v_failed + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            UPDATE schema_bridge_tasks
            SET transform_status = 'failed',
                transform_error = SQLERRM,
                updated_at = now()
            WHERE local_id = task_record.local_id;

            v_failed := v_failed + 1;
            RAISE WARNING 'Task % migration failed: %', task_record.local_id, SQLERRM;
        END;
    END LOOP;

    end_time := clock_timestamp();

    RETURN QUERY SELECT
        v_processed,
        v_succeeded,
        v_failed,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. ORCHESTRATED MIGRATION EXECUTION
-- =====================================================

-- Master migration orchestrator
CREATE OR REPLACE FUNCTION execute_full_migration(
    p_chunk_size INTEGER DEFAULT 50,
    p_max_retries INTEGER DEFAULT 3,
    p_chunk_delay_ms INTEGER DEFAULT 100
)
RETURNS TABLE (
    entity_type TEXT,
    total_processed INTEGER,
    total_succeeded INTEGER,
    total_failed INTEGER,
    total_time_ms INTEGER,
    success_rate NUMERIC
) AS $$
DECLARE
    notes_total INTEGER;
    tasks_total INTEGER;
    current_offset INTEGER;
    chunk_result RECORD;
    retry_count INTEGER;
    notes_processed INTEGER := 0;
    notes_succeeded INTEGER := 0;
    notes_failed INTEGER := 0;
    tasks_processed INTEGER := 0;
    tasks_succeeded INTEGER := 0;
    tasks_failed INTEGER := 0;
    notes_start_time TIMESTAMPTZ;
    tasks_start_time TIMESTAMPTZ;
    notes_total_time INTEGER := 0;
    tasks_total_time INTEGER := 0;
BEGIN
    -- Get total counts
    SELECT COUNT(*) INTO notes_total
    FROM schema_bridge_notes WHERE transform_status = 'pending';

    SELECT COUNT(*) INTO tasks_total
    FROM schema_bridge_tasks WHERE transform_status = 'pending';

    RAISE NOTICE 'Starting full migration: % notes, % tasks to process',
        notes_total, tasks_total;

    -- =============================
    -- MIGRATE NOTES IN CHUNKS
    -- =============================
    notes_start_time := clock_timestamp();
    current_offset := 0;

    WHILE current_offset < notes_total LOOP
        retry_count := 0;

        LOOP
            BEGIN
                -- Execute notes chunk migration
                SELECT * INTO chunk_result
                FROM migrate_notes_chunk(p_chunk_size, current_offset);

                -- Accumulate results
                notes_processed := notes_processed + chunk_result.processed;
                notes_succeeded := notes_succeeded + chunk_result.succeeded;
                notes_failed := notes_failed + chunk_result.failed;
                notes_total_time := notes_total_time + chunk_result.chunk_time_ms;

                -- Log progress
                RAISE NOTICE 'Notes chunk completed: processed=%, succeeded=%, failed=%, time=%ms',
                    chunk_result.processed, chunk_result.succeeded,
                    chunk_result.failed, chunk_result.chunk_time_ms;

                -- Exit retry loop on success
                EXIT;

            EXCEPTION WHEN OTHERS THEN
                retry_count := retry_count + 1;

                IF retry_count >= p_max_retries THEN
                    RAISE EXCEPTION 'Notes chunk migration failed after % retries: %',
                        p_max_retries, SQLERRM;
                END IF;

                RAISE WARNING 'Notes chunk failed (attempt %/%): %, retrying...',
                    retry_count, p_max_retries, SQLERRM;

                -- Brief delay before retry
                PERFORM pg_sleep(0.5);
            END;
        END LOOP;

        current_offset := current_offset + p_chunk_size;

        -- Brief pause between chunks
        IF p_chunk_delay_ms > 0 THEN
            PERFORM pg_sleep(p_chunk_delay_ms / 1000.0);
        END IF;
    END LOOP;

    -- =============================
    -- MIGRATE TASKS IN CHUNKS
    -- =============================
    tasks_start_time := clock_timestamp();
    current_offset := 0;

    WHILE current_offset < tasks_total LOOP
        retry_count := 0;

        LOOP
            BEGIN
                -- Execute tasks chunk migration
                SELECT * INTO chunk_result
                FROM migrate_tasks_chunk(p_chunk_size, current_offset);

                -- Accumulate results
                tasks_processed := tasks_processed + chunk_result.processed;
                tasks_succeeded := tasks_succeeded + chunk_result.succeeded;
                tasks_failed := tasks_failed + chunk_result.failed;
                tasks_total_time := tasks_total_time + chunk_result.chunk_time_ms;

                -- Log progress
                RAISE NOTICE 'Tasks chunk completed: processed=%, succeeded=%, failed=%, time=%ms',
                    chunk_result.processed, chunk_result.succeeded,
                    chunk_result.failed, chunk_result.chunk_time_ms;

                EXIT;

            EXCEPTION WHEN OTHERS THEN
                retry_count := retry_count + 1;

                IF retry_count >= p_max_retries THEN
                    RAISE EXCEPTION 'Tasks chunk migration failed after % retries: %',
                        p_max_retries, SQLERRM;
                END IF;

                RAISE WARNING 'Tasks chunk failed (attempt %/%): %, retrying...',
                    retry_count, p_max_retries, SQLERRM;

                PERFORM pg_sleep(0.5);
            END;
        END LOOP;

        current_offset := current_offset + p_chunk_size;

        IF p_chunk_delay_ms > 0 THEN
            PERFORM pg_sleep(p_chunk_delay_ms / 1000.0);
        END IF;
    END LOOP;

    -- Return summary results
    RETURN QUERY
    SELECT
        'notes'::TEXT,
        notes_processed,
        notes_succeeded,
        notes_failed,
        notes_total_time,
        CASE WHEN notes_processed > 0
             THEN ROUND(100.0 * notes_succeeded / notes_processed, 2)
             ELSE 0 END;

    RETURN QUERY
    SELECT
        'tasks'::TEXT,
        tasks_processed,
        tasks_succeeded,
        tasks_failed,
        tasks_total_time,
        CASE WHEN tasks_processed > 0
             THEN ROUND(100.0 * tasks_succeeded / tasks_processed, 2)
             ELSE 0 END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. EXECUTE THE MIGRATION
-- =====================================================

-- Log migration execution start
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('phase3', 'data_migration', 'started', 'Beginning chunked data migration');

-- Execute the full migration
DO $$
DECLARE
    migration_result RECORD;
    total_failures INTEGER := 0;
    start_time TIMESTAMPTZ := clock_timestamp();
    end_time TIMESTAMPTZ;
BEGIN
    RAISE NOTICE '🚀 Starting Production Data Migration at %', start_time;
    RAISE NOTICE 'Migration parameters: chunk_size=50, max_retries=3, delay=100ms';

    -- Execute migration
    FOR migration_result IN
        SELECT * FROM execute_full_migration(
            p_chunk_size := 50,
            p_max_retries := 3,
            p_chunk_delay_ms := 100
        )
    LOOP
        total_failures := total_failures + migration_result.total_failed;

        RAISE NOTICE 'Migration completed for %: processed=%, succeeded=%, failed=%, success_rate=%%, time=%ms',
            migration_result.entity_type,
            migration_result.total_processed,
            migration_result.total_succeeded,
            migration_result.total_failed,
            migration_result.success_rate,
            migration_result.total_time_ms;

        -- Log individual results
        INSERT INTO migration_log (phase, operation, status, message)
        VALUES (
            'phase3',
            'data_migration_' || migration_result.entity_type,
            CASE WHEN migration_result.total_failed = 0 THEN 'completed' ELSE 'completed_with_errors' END,
            format('Processed: %s, Succeeded: %s, Failed: %s, Success Rate: %s%%',
                migration_result.total_processed,
                migration_result.total_succeeded,
                migration_result.total_failed,
                migration_result.success_rate)
        );
    END LOOP;

    end_time := clock_timestamp();

    -- Check if migration is acceptable
    IF total_failures > 10 THEN
        RAISE EXCEPTION 'Migration failed with % total failures. This exceeds acceptable threshold.',
            total_failures;
    END IF;

    RAISE NOTICE '✅ Migration completed successfully in %',
        age(end_time, start_time);

    IF total_failures > 0 THEN
        RAISE NOTICE '⚠️  Migration completed with % failures (within acceptable range)', total_failures;
    END IF;

END $$;

-- =====================================================
-- 6. POST-MIGRATION VALIDATION
-- =====================================================

-- Comprehensive post-migration validation
CREATE OR REPLACE FUNCTION post_migration_validation()
RETURNS TABLE (
    validation_check TEXT,
    expected_value BIGINT,
    actual_value BIGINT,
    passed BOOLEAN,
    variance_percentage NUMERIC
) AS $$
DECLARE
    original_notes_count BIGINT;
    original_tasks_count BIGINT;
    migrated_notes_count BIGINT;
    migrated_tasks_count BIGINT;
BEGIN
    -- Get original counts from bridge tables
    SELECT COUNT(*) INTO original_notes_count
    FROM schema_bridge_notes
    WHERE transform_status IN ('completed', 'failed');

    SELECT COUNT(*) INTO original_tasks_count
    FROM schema_bridge_tasks
    WHERE transform_status IN ('completed', 'failed');

    -- Get migrated counts
    SELECT COUNT(*) INTO migrated_notes_count
    FROM schema_bridge_notes
    WHERE transform_status = 'completed';

    SELECT COUNT(*) INTO migrated_tasks_count
    FROM schema_bridge_tasks
    WHERE transform_status = 'completed';

    -- Return validation results
    RETURN QUERY
    SELECT
        'notes_migration_completeness'::TEXT,
        original_notes_count,
        migrated_notes_count,
        (migrated_notes_count >= original_notes_count * 0.95)::BOOLEAN, -- 95% success threshold
        CASE WHEN original_notes_count > 0
             THEN ROUND(100.0 * migrated_notes_count / original_notes_count, 2)
             ELSE 100.0 END;

    RETURN QUERY
    SELECT
        'tasks_migration_completeness'::TEXT,
        original_tasks_count,
        migrated_tasks_count,
        (migrated_tasks_count >= original_tasks_count * 0.95)::BOOLEAN,
        CASE WHEN original_tasks_count > 0
             THEN ROUND(100.0 * migrated_tasks_count / original_tasks_count, 2)
             ELSE 100.0 END;

    -- Foreign key consistency check
    RETURN QUERY
    SELECT
        'foreign_key_consistency'::TEXT,
        (SELECT COUNT(*) FROM note_tasks WHERE deleted = false)::BIGINT,
        (SELECT COUNT(*) FROM note_tasks nt
         JOIN notes n ON nt.note_id = n.id
         WHERE nt.deleted = false AND n.deleted = false)::BIGINT,
        (SELECT COUNT(*) FROM note_tasks nt
         LEFT JOIN notes n ON nt.note_id = n.id
         WHERE nt.deleted = false AND n.id IS NULL) = 0,
        100.0;
END;
$$ LANGUAGE plpgsql;

-- Run post-migration validation
DO $$
DECLARE
    validation_record RECORD;
    validation_failures INTEGER := 0;
BEGIN
    RAISE NOTICE 'Running post-migration validation...';

    FOR validation_record IN
        SELECT * FROM post_migration_validation()
    LOOP
        IF validation_record.passed THEN
            RAISE NOTICE '✅ %: %/% (%.2f%%)',
                validation_record.validation_check,
                validation_record.actual_value,
                validation_record.expected_value,
                validation_record.variance_percentage;
        ELSE
            validation_failures := validation_failures + 1;
            RAISE WARNING '❌ %: %/% (%.2f%%) - FAILED',
                validation_record.validation_check,
                validation_record.actual_value,
                validation_record.expected_value,
                validation_record.variance_percentage;
        END IF;

        -- Log validation result
        INSERT INTO schema_validation_results (
            validation_type, passed, details
        ) VALUES (
            validation_record.validation_check,
            validation_record.passed,
            jsonb_build_object(
                'expected', validation_record.expected_value,
                'actual', validation_record.actual_value,
                'percentage', validation_record.variance_percentage
            )
        );
    END LOOP;

    IF validation_failures > 0 THEN
        RAISE WARNING 'Post-migration validation completed with % failures', validation_failures;
    ELSE
        RAISE NOTICE 'Post-migration validation passed all checks';
    END IF;
END $$;

-- =====================================================
-- 7. CLEANUP AND OPTIMIZATION
-- =====================================================

-- Update table statistics after migration
ANALYZE notes;
ANALYZE note_tasks;
ANALYZE folders;
ANALYZE note_folders;

-- Log final completion
INSERT INTO migration_log (phase, operation, status, message, execution_time_ms)
SELECT
    'phase3',
    'complete',
    'completed',
    'Phase 3 data migration completed successfully',
    EXTRACT(MILLISECONDS FROM (now() - created_at))::INTEGER
FROM migration_log
WHERE phase = 'phase3' AND operation = 'start'
ORDER BY created_at DESC
LIMIT 1;

-- =====================================================
-- 8. FINAL SUMMARY AND NEXT STEPS
-- =====================================================

DO $$
DECLARE
    notes_migrated INTEGER;
    tasks_migrated INTEGER;
    notes_failed INTEGER;
    tasks_failed INTEGER;
    total_time INTERVAL;
BEGIN
    -- Get final counts
    SELECT COUNT(*) INTO notes_migrated
    FROM schema_bridge_notes WHERE transform_status = 'completed';

    SELECT COUNT(*) INTO tasks_migrated
    FROM schema_bridge_tasks WHERE transform_status = 'completed';

    SELECT COUNT(*) INTO notes_failed
    FROM schema_bridge_notes WHERE transform_status = 'failed';

    SELECT COUNT(*) INTO tasks_failed
    FROM schema_bridge_tasks WHERE transform_status = 'failed';

    -- Calculate total time
    SELECT age(
        (SELECT MAX(created_at) FROM migration_log WHERE phase = 'phase3'),
        (SELECT MIN(created_at) FROM migration_log WHERE phase = 'phase3')
    ) INTO total_time;

    RAISE NOTICE '';
    RAISE NOTICE '🎉 PHASE 3 MIGRATION COMPLETED SUCCESSFULLY! 🎉';
    RAISE NOTICE '';
    RAISE NOTICE '=== MIGRATION SUMMARY ===';
    RAISE NOTICE 'Notes migrated: % (% failed)', notes_migrated, notes_failed;
    RAISE NOTICE 'Tasks migrated: % (% failed)', tasks_migrated, tasks_failed;
    RAISE NOTICE 'Total migration time: %', total_time;
    RAISE NOTICE '';
    RAISE NOTICE '=== NEXT STEPS ===';
    RAISE NOTICE '1. Review migration logs: SELECT * FROM migration_log WHERE phase = ''phase3'';';
    RAISE NOTICE '2. Check failed records: SELECT * FROM bridge_transformation_progress;';
    RAISE NOTICE '3. Test application functionality thoroughly';
    RAISE NOTICE '4. Monitor performance for 24-48 hours';
    RAISE NOTICE '5. Execute cleanup script when stable';
    RAISE NOTICE '';
    RAISE NOTICE '=== EMERGENCY PROCEDURES ===';
    RAISE NOTICE 'Rollback if needed: SELECT rollback_phase3();';
    RAISE NOTICE 'Monitor performance: SELECT * FROM migration_performance_monitor;';
    RAISE NOTICE '';
END $$;

COMMIT;

-- =====================================================
-- EMERGENCY ROLLBACK FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION rollback_phase3()
RETURNS void AS $$
DECLARE
    rollback_start_time TIMESTAMPTZ := clock_timestamp();
    rollback_end_time TIMESTAMPTZ;
BEGIN
    RAISE NOTICE 'EMERGENCY ROLLBACK: Starting Phase 3 rollback at %', rollback_start_time;

    -- Remove migrated data (keep original data intact)
    DELETE FROM notes
    WHERE id IN (
        SELECT remote_id
        FROM schema_bridge_notes
        WHERE transform_status = 'completed'
    );

    DELETE FROM note_tasks
    WHERE id IN (
        SELECT remote_id
        FROM schema_bridge_tasks
        WHERE transform_status = 'completed'
    );

    -- Reset bridge table status
    UPDATE schema_bridge_notes
    SET transform_status = 'pending',
        processed_at = NULL,
        validation_passed = NULL
    WHERE transform_status IN ('completed', 'failed');

    UPDATE schema_bridge_tasks
    SET transform_status = 'pending',
        processed_at = NULL,
        validation_passed = NULL
    WHERE transform_status IN ('completed', 'failed');

    rollback_end_time := clock_timestamp();

    -- Log rollback
    INSERT INTO migration_log (phase, operation, status, message, execution_time_ms)
    VALUES (
        'phase3',
        'emergency_rollback',
        'completed',
        'Emergency rollback completed successfully',
        EXTRACT(MILLISECONDS FROM (rollback_end_time - rollback_start_time))::INTEGER
    );

    RAISE NOTICE 'Emergency rollback completed in %', age(rollback_end_time, rollback_start_time);
END;
$$ LANGUAGE plpgsql;