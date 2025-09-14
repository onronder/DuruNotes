-- =====================================================
-- Migration: Enforce Foreign Key Cascades
-- Date: 2025-01-14
-- Purpose: Ensure all foreign keys to auth.users have ON DELETE CASCADE
-- =====================================================

-- This migration ensures that when a user is deleted from auth.users,
-- all related data is automatically cleaned up via CASCADE deletes.
-- This prevents orphaned records and maintains referential integrity.

BEGIN;

-- =====================================================
-- 1. HELPER FUNCTION TO CHECK FOREIGN KEY CONSTRAINTS
-- =====================================================

CREATE OR REPLACE FUNCTION pg_temp.get_foreign_key_info()
RETURNS TABLE (
    table_name text,
    constraint_name text,
    column_name text,
    foreign_table text,
    foreign_column text,
    on_delete text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tc.table_name::text,
        tc.constraint_name::text,
        kcu.column_name::text,
        ccu.table_name::text AS foreign_table,
        ccu.column_name::text AS foreign_column,
        rc.delete_rule::text AS on_delete
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
    JOIN information_schema.referential_constraints rc
        ON rc.constraint_name = tc.constraint_name
        AND rc.constraint_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
        AND ccu.table_schema = 'auth'
        AND ccu.table_name = 'users'
    ORDER BY tc.table_name, tc.constraint_name;
END;
$$ LANGUAGE plpgsql;

-- Log current foreign key constraints for audit
DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE 'Current foreign key constraints referencing auth.users:';
    FOR r IN SELECT * FROM pg_temp.get_foreign_key_info()
    LOOP
        RAISE NOTICE '  Table: %, Constraint: %, On Delete: %', 
            r.table_name, r.constraint_name, r.on_delete;
    END LOOP;
END $$;

-- =====================================================
-- 2. FIX inbound_aliases TABLE
-- =====================================================

-- The inbound_aliases table maps email aliases to users
-- When a user is deleted, their alias should also be removed
DO $$
DECLARE
    v_constraint_exists boolean;
    v_on_delete text;
BEGIN
    -- Check if constraint exists and its current ON DELETE behavior
    SELECT EXISTS(
        SELECT 1 FROM pg_temp.get_foreign_key_info() 
        WHERE table_name = 'inbound_aliases'
    ) INTO v_constraint_exists;
    
    IF v_constraint_exists THEN
        SELECT on_delete INTO v_on_delete
        FROM pg_temp.get_foreign_key_info()
        WHERE table_name = 'inbound_aliases'
        LIMIT 1;
        
        IF v_on_delete != 'CASCADE' THEN
            RAISE NOTICE 'Fixing inbound_aliases foreign key (currently: %)', v_on_delete;
            
            -- Drop existing constraint
            ALTER TABLE public.inbound_aliases 
                DROP CONSTRAINT IF EXISTS inbound_aliases_user_id_fkey;
            
            -- Recreate with CASCADE
            ALTER TABLE public.inbound_aliases 
                ADD CONSTRAINT inbound_aliases_user_id_fkey 
                FOREIGN KEY (user_id) 
                REFERENCES auth.users(id) 
                ON DELETE CASCADE;
                
            RAISE NOTICE '  ✓ inbound_aliases now has ON DELETE CASCADE';
        ELSE
            RAISE NOTICE '  ✓ inbound_aliases already has ON DELETE CASCADE';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 3. FIX clipper_inbox TABLE
-- =====================================================

-- The clipper_inbox stores emails and web clips for users
-- When a user is deleted, their inbox items should be removed
DO $$
DECLARE
    v_constraint_exists boolean;
    v_on_delete text;
BEGIN
    -- Check if constraint exists and its current ON DELETE behavior
    SELECT EXISTS(
        SELECT 1 FROM pg_temp.get_foreign_key_info() 
        WHERE table_name = 'clipper_inbox'
    ) INTO v_constraint_exists;
    
    IF v_constraint_exists THEN
        SELECT on_delete INTO v_on_delete
        FROM pg_temp.get_foreign_key_info()
        WHERE table_name = 'clipper_inbox'
        LIMIT 1;
        
        IF v_on_delete != 'CASCADE' THEN
            RAISE NOTICE 'Fixing clipper_inbox foreign key (currently: %)', v_on_delete;
            
            -- Drop existing constraint
            ALTER TABLE public.clipper_inbox 
                DROP CONSTRAINT IF EXISTS clipper_inbox_user_id_fkey;
            
            -- Recreate with CASCADE
            ALTER TABLE public.clipper_inbox 
                ADD CONSTRAINT clipper_inbox_user_id_fkey 
                FOREIGN KEY (user_id) 
                REFERENCES auth.users(id) 
                ON DELETE CASCADE;
                
            RAISE NOTICE '  ✓ clipper_inbox now has ON DELETE CASCADE';
        ELSE
            RAISE NOTICE '  ✓ clipper_inbox already has ON DELETE CASCADE';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 4. FIX user_devices TABLE
-- =====================================================

-- The user_devices table stores push notification tokens
-- When a user is deleted, their device tokens should be removed
DO $$
DECLARE
    v_table_exists boolean;
    v_constraint_exists boolean;
    v_on_delete text;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'user_devices'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check if constraint exists and its current ON DELETE behavior
        SELECT EXISTS(
            SELECT 1 FROM pg_temp.get_foreign_key_info() 
            WHERE table_name = 'user_devices'
        ) INTO v_constraint_exists;
        
        IF v_constraint_exists THEN
            SELECT on_delete INTO v_on_delete
            FROM pg_temp.get_foreign_key_info()
            WHERE table_name = 'user_devices'
            LIMIT 1;
            
            IF v_on_delete != 'CASCADE' THEN
                RAISE NOTICE 'Fixing user_devices foreign key (currently: %)', v_on_delete;
                
                -- Drop existing constraint
                ALTER TABLE public.user_devices 
                    DROP CONSTRAINT IF EXISTS user_devices_user_id_fkey;
                
                -- Recreate with CASCADE
                ALTER TABLE public.user_devices 
                    ADD CONSTRAINT user_devices_user_id_fkey 
                    FOREIGN KEY (user_id) 
                    REFERENCES auth.users(id) 
                    ON DELETE CASCADE;
                    
                RAISE NOTICE '  ✓ user_devices now has ON DELETE CASCADE';
            ELSE
                RAISE NOTICE '  ✓ user_devices already has ON DELETE CASCADE';
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 5. FIX note_tasks TABLE
-- =====================================================

-- The note_tasks table stores task items extracted from notes
-- When a user is deleted, their tasks should be removed
DO $$
DECLARE
    v_table_exists boolean;
    v_constraint_exists boolean;
    v_on_delete text;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check if constraint exists and its current ON DELETE behavior
        SELECT EXISTS(
            SELECT 1 FROM pg_temp.get_foreign_key_info() 
            WHERE table_name = 'note_tasks'
        ) INTO v_constraint_exists;
        
        IF v_constraint_exists THEN
            SELECT on_delete INTO v_on_delete
            FROM pg_temp.get_foreign_key_info()
            WHERE table_name = 'note_tasks'
            LIMIT 1;
            
            IF v_on_delete != 'CASCADE' THEN
                RAISE NOTICE 'Fixing note_tasks foreign key (currently: %)', v_on_delete;
                
                -- Drop existing constraint
                ALTER TABLE public.note_tasks 
                    DROP CONSTRAINT IF EXISTS note_tasks_user_id_fkey;
                
                -- Recreate with CASCADE
                ALTER TABLE public.note_tasks 
                    ADD CONSTRAINT note_tasks_user_id_fkey 
                    FOREIGN KEY (user_id) 
                    REFERENCES auth.users(id) 
                    ON DELETE CASCADE;
                    
                RAISE NOTICE '  ✓ note_tasks now has ON DELETE CASCADE';
            ELSE
                RAISE NOTICE '  ✓ note_tasks already has ON DELETE CASCADE';
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 6. FIX folders TABLE
-- =====================================================

-- The folders table stores encrypted folder information
-- When a user is deleted, their folders should be removed
DO $$
DECLARE
    v_table_exists boolean;
    v_has_fk boolean;
    v_on_delete text;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'folders'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check if foreign key exists
        SELECT EXISTS(
            SELECT 1 
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public' 
                AND tc.table_name = 'folders'
                AND tc.constraint_type = 'FOREIGN KEY'
                AND kcu.column_name = 'user_id'
        ) INTO v_has_fk;
        
        IF NOT v_has_fk THEN
            RAISE NOTICE 'Adding foreign key constraint to folders table';
            
            -- Add foreign key with CASCADE
            ALTER TABLE public.folders 
                ADD CONSTRAINT folders_user_id_fkey 
                FOREIGN KEY (user_id) 
                REFERENCES auth.users(id) 
                ON DELETE CASCADE;
                
            RAISE NOTICE '  ✓ folders now has ON DELETE CASCADE';
        ELSE
            -- Check if it has CASCADE
            SELECT on_delete INTO v_on_delete
            FROM pg_temp.get_foreign_key_info()
            WHERE table_name = 'folders'
            LIMIT 1;
            
            IF v_on_delete != 'CASCADE' THEN
                RAISE NOTICE 'Fixing folders foreign key (currently: %)', v_on_delete;
                
                -- Drop existing constraint
                ALTER TABLE public.folders 
                    DROP CONSTRAINT IF EXISTS folders_user_id_fkey;
                
                -- Recreate with CASCADE
                ALTER TABLE public.folders 
                    ADD CONSTRAINT folders_user_id_fkey 
                    FOREIGN KEY (user_id) 
                    REFERENCES auth.users(id) 
                    ON DELETE CASCADE;
                    
                RAISE NOTICE '  ✓ folders now has ON DELETE CASCADE';
            ELSE
                RAISE NOTICE '  ✓ folders already has ON DELETE CASCADE';
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 7. FIX note_folders TABLE
-- =====================================================

-- The note_folders table maps notes to folders
-- When a user is deleted, their note-folder mappings should be removed
DO $$
DECLARE
    v_table_exists boolean;
    v_has_fk boolean;
    v_on_delete text;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_folders'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check if foreign key exists
        SELECT EXISTS(
            SELECT 1 
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public' 
                AND tc.table_name = 'note_folders'
                AND tc.constraint_type = 'FOREIGN KEY'
                AND kcu.column_name = 'user_id'
        ) INTO v_has_fk;
        
        IF NOT v_has_fk THEN
            RAISE NOTICE 'Adding foreign key constraint to note_folders table';
            
            -- Add foreign key with CASCADE
            ALTER TABLE public.note_folders 
                ADD CONSTRAINT note_folders_user_id_fkey 
                FOREIGN KEY (user_id) 
                REFERENCES auth.users(id) 
                ON DELETE CASCADE;
                
            RAISE NOTICE '  ✓ note_folders now has ON DELETE CASCADE';
        ELSE
            -- Check if it has CASCADE
            SELECT on_delete INTO v_on_delete
            FROM pg_temp.get_foreign_key_info()
            WHERE table_name = 'note_folders'
            LIMIT 1;
            
            IF v_on_delete != 'CASCADE' THEN
                RAISE NOTICE 'Fixing note_folders foreign key (currently: %)', v_on_delete;
                
                -- Drop existing constraint
                ALTER TABLE public.note_folders 
                    DROP CONSTRAINT IF EXISTS note_folders_user_id_fkey;
                
                -- Recreate with CASCADE
                ALTER TABLE public.note_folders 
                    ADD CONSTRAINT note_folders_user_id_fkey 
                    FOREIGN KEY (user_id) 
                    REFERENCES auth.users(id) 
                    ON DELETE CASCADE;
                    
                RAISE NOTICE '  ✓ note_folders now has ON DELETE CASCADE';
            ELSE
                RAISE NOTICE '  ✓ note_folders already has ON DELETE CASCADE';
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 8. FIX notes TABLE (if it references auth.users)
-- =====================================================

-- The notes table stores encrypted notes
-- When a user is deleted, their notes should be removed
DO $$
DECLARE
    v_table_exists boolean;
    v_has_user_id boolean;
    v_has_fk boolean;
    v_on_delete text;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'notes'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check if user_id column exists
        SELECT EXISTS(
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
                AND table_name = 'notes' 
                AND column_name = 'user_id'
        ) INTO v_has_user_id;
        
        IF v_has_user_id THEN
            -- Check if foreign key exists
            SELECT EXISTS(
                SELECT 1 
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu 
                    ON tc.constraint_name = kcu.constraint_name
                WHERE tc.table_schema = 'public' 
                    AND tc.table_name = 'notes'
                    AND tc.constraint_type = 'FOREIGN KEY'
                    AND kcu.column_name = 'user_id'
            ) INTO v_has_fk;
            
            IF NOT v_has_fk THEN
                RAISE NOTICE 'Adding foreign key constraint to notes table';
                
                -- Add foreign key with CASCADE
                ALTER TABLE public.notes 
                    ADD CONSTRAINT notes_user_id_fkey 
                    FOREIGN KEY (user_id) 
                    REFERENCES auth.users(id) 
                    ON DELETE CASCADE;
                    
                RAISE NOTICE '  ✓ notes now has ON DELETE CASCADE';
            ELSE
                -- Check if it has CASCADE
                SELECT on_delete INTO v_on_delete
                FROM pg_temp.get_foreign_key_info()
                WHERE table_name = 'notes'
                LIMIT 1;
                
                IF v_on_delete != 'CASCADE' THEN
                    RAISE NOTICE 'Fixing notes foreign key (currently: %)', v_on_delete;
                    
                    -- Drop existing constraint
                    ALTER TABLE public.notes 
                        DROP CONSTRAINT IF EXISTS notes_user_id_fkey;
                    
                    -- Recreate with CASCADE
                    ALTER TABLE public.notes 
                        ADD CONSTRAINT notes_user_id_fkey 
                        FOREIGN KEY (user_id) 
                        REFERENCES auth.users(id) 
                        ON DELETE CASCADE;
                        
                    RAISE NOTICE '  ✓ notes now has ON DELETE CASCADE';
                ELSE
                    RAISE NOTICE '  ✓ notes already has ON DELETE CASCADE';
                END IF;
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 9. VERIFICATION
-- =====================================================

-- Log final state of foreign key constraints
DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Final state of foreign key constraints:';
    FOR r IN SELECT * FROM pg_temp.get_foreign_key_info()
    LOOP
        RAISE NOTICE '  Table: %, Constraint: %, On Delete: %', 
            r.table_name, r.constraint_name, r.on_delete;
    END LOOP;
END $$;

-- Clean up temporary function
DROP FUNCTION IF EXISTS pg_temp.get_foreign_key_info();

COMMIT;

-- =====================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- =====================================================

-- Run these queries to verify the migration was successful:

-- 1. Check all foreign keys referencing auth.users have CASCADE:
/*
SELECT 
    tc.table_name,
    tc.constraint_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = tc.constraint_name
    AND rc.constraint_schema = tc.table_schema
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
ORDER BY tc.table_name;
*/

-- 2. Test cascade delete (DO NOT RUN IN PRODUCTION):
/*
-- Create a test user
INSERT INTO auth.users (id, email) VALUES 
    ('00000000-0000-0000-0000-000000000001', 'test-cascade@example.com');

-- Insert test data
INSERT INTO public.inbound_aliases (user_id, alias) VALUES 
    ('00000000-0000-0000-0000-000000000001', 'test_alias_12345');

-- Delete the user and verify cascade
DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000001';

-- Check if alias was deleted
SELECT * FROM public.inbound_aliases WHERE alias = 'test_alias_12345';
-- Should return 0 rows
*/
