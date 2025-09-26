-- Migration: Data Validation Constraints for Production-Grade Integrity
-- Version: Aligned with InputValidationService
-- Description: Database-level validation matching app-side security

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

-- Email validation function
CREATE OR REPLACE FUNCTION validate_email(email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN email ~* '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- URL validation function
CREATE OR REPLACE FUNCTION validate_url(url TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN url ~* '^https?://[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- UUID validation function
CREATE OR REPLACE FUNCTION validate_uuid(id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Sanitize text function (removes potential XSS)
CREATE OR REPLACE FUNCTION sanitize_text(input_text TEXT)
RETURNS TEXT AS $$
BEGIN
  -- Remove script tags and dangerous HTML
  RETURN regexp_replace(
    regexp_replace(
      regexp_replace(
        input_text,
        '<script[^>]*>.*?</script>', '', 'gi'
      ),
      '<iframe[^>]*>.*?</iframe>', '', 'gi'
    ),
    'javascript:', '', 'gi'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- NOTES TABLE CONSTRAINTS (Only for existing columns)
-- ============================================================================

-- Add check constraints to notes table
DO $$
BEGIN
  -- Check if constraints don't already exist before adding
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_notes_id_format'
  ) THEN
    ALTER TABLE notes
      ADD CONSTRAINT chk_notes_id_format
        CHECK (validate_uuid(id::TEXT));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_notes_user_id_format'
  ) THEN
    ALTER TABLE notes
      ADD CONSTRAINT chk_notes_user_id_format
        CHECK (validate_uuid(user_id::TEXT));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_notes_title_length'
  ) THEN
    ALTER TABLE notes
      ADD CONSTRAINT chk_notes_title_length
        CHECK (LENGTH(title_enc::TEXT) <= 10000);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_notes_props_length'
  ) THEN
    ALTER TABLE notes
      ADD CONSTRAINT chk_notes_props_length
        CHECK (LENGTH(props_enc::TEXT) <= 5000000);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_notes_updated_at_valid'
  ) THEN
    ALTER TABLE notes
      ADD CONSTRAINT chk_notes_updated_at_valid
        CHECK (updated_at <= NOW() + INTERVAL '1 minute');
  END IF;
END $$;

-- ============================================================================
-- NOTE_TASKS TABLE CONSTRAINTS (Only for existing columns)
-- ============================================================================

DO $$
BEGIN
  -- Check if note_tasks table exists first
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'note_tasks' AND table_schema = 'public'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.check_constraints
      WHERE constraint_name = 'chk_note_tasks_user_id_format'
    ) THEN
      ALTER TABLE note_tasks
        ADD CONSTRAINT chk_note_tasks_user_id_format
          CHECK (validate_uuid(user_id::TEXT));
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.check_constraints
      WHERE constraint_name = 'chk_note_tasks_content_length'
    ) THEN
      ALTER TABLE note_tasks
        ADD CONSTRAINT chk_note_tasks_content_length
          CHECK (LENGTH(content) <= 10000);
    END IF;

    -- Status column type may vary, skip constraint
    -- IF NOT EXISTS (
    --   SELECT 1 FROM information_schema.check_constraints
    --   WHERE constraint_name = 'chk_note_tasks_status_valid'
    -- ) THEN
    --   ALTER TABLE note_tasks
    --     ADD CONSTRAINT chk_note_tasks_status_valid
    --       CHECK (status IN ('0', '1', '2'));
    -- END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.check_constraints
      WHERE constraint_name = 'chk_note_tasks_due_date_reasonable'
    ) THEN
      ALTER TABLE note_tasks
        ADD CONSTRAINT chk_note_tasks_due_date_reasonable
          CHECK (due_date IS NULL OR (due_date > '2020-01-01' AND due_date < NOW() + INTERVAL '10 years'));
    END IF;
  END IF;
END $$;

-- ============================================================================
-- FOLDERS TABLE CONSTRAINTS (Only for existing columns)
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_folders_id_format'
  ) THEN
    ALTER TABLE folders
      ADD CONSTRAINT chk_folders_id_format
        CHECK (validate_uuid(id::TEXT));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_folders_user_id_format'
  ) THEN
    ALTER TABLE folders
      ADD CONSTRAINT chk_folders_user_id_format
        CHECK (validate_uuid(user_id::TEXT));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_folders_name_length'
  ) THEN
    ALTER TABLE folders
      ADD CONSTRAINT chk_folders_name_length
        CHECK (LENGTH(name_enc::TEXT) <= 1000);
  END IF;
END $$;

-- ============================================================================
-- TRIGGER FUNCTIONS FOR VALIDATION
-- ============================================================================

-- Generic function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to relevant tables only if trigger doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'update_notes_updated_at'
  ) THEN
    CREATE TRIGGER update_notes_updated_at
      BEFORE UPDATE ON notes
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;

  -- Check if note_tasks table exists before creating trigger
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'note_tasks' AND table_schema = 'public'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.triggers
      WHERE trigger_name = 'update_note_tasks_updated_at'
    ) THEN
      CREATE TRIGGER update_note_tasks_updated_at
        BEFORE UPDATE ON note_tasks
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'update_folders_updated_at'
  ) THEN
    CREATE TRIGGER update_folders_updated_at
      BEFORE UPDATE ON folders
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION validate_email IS 'RFC-compliant email validation';
COMMENT ON FUNCTION validate_url IS 'URL validation with protocol requirement';
COMMENT ON FUNCTION validate_uuid IS 'UUID format validation';
COMMENT ON FUNCTION sanitize_text IS 'XSS prevention by removing dangerous HTML/JS';
COMMENT ON CONSTRAINT chk_notes_props_length ON notes IS 'Prevents DoS via large content';