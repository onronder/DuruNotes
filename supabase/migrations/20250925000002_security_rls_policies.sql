-- Migration: Row Level Security Policies for Production-Grade Security
-- Version: Aligned with AuthenticationGuard and Security Services
-- Description: Multi-layered security policies for billion-scale operations

-- ============================================================================
-- ENABLE RLS ON EXISTING TABLES
-- ============================================================================

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_folders ENABLE ROW LEVEL SECURITY;

-- Enable RLS on note_tasks if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'note_tasks' AND table_schema = 'public'
  ) THEN
    ALTER TABLE note_tasks ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- ============================================================================
-- SIMPLIFIED SECURITY HELPER FUNCTIONS
-- ============================================================================

-- Function to verify basic JWT claims
CREATE OR REPLACE FUNCTION public.verify_jwt_claims()
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if user is authenticated
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- NOTES TABLE RLS POLICIES
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS notes_select_policy ON notes;
DROP POLICY IF EXISTS notes_insert_policy ON notes;
DROP POLICY IF EXISTS notes_update_policy ON notes;
DROP POLICY IF EXISTS notes_delete_policy ON notes;

-- Select: Users can only see their own notes
CREATE POLICY notes_select_policy ON notes
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND deleted = false
  );

-- Insert: Users can insert their own notes
CREATE POLICY notes_insert_policy ON notes
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
  );

-- Update: Only own notes
CREATE POLICY notes_update_policy ON notes
  FOR UPDATE
  USING (
    user_id = auth.uid()
  )
  WITH CHECK (
    user_id = auth.uid()
  );

-- Delete: Soft delete only
CREATE POLICY notes_delete_policy ON notes
  FOR UPDATE
  USING (
    user_id = auth.uid()
    AND deleted = false
  )
  WITH CHECK (
    user_id = auth.uid()
    AND deleted = true
  );

-- ============================================================================
-- NOTE_TASKS TABLE RLS POLICIES
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'note_tasks' AND table_schema = 'public'
  ) THEN
    DROP POLICY IF EXISTS note_tasks_select_policy ON note_tasks;
    DROP POLICY IF EXISTS note_tasks_insert_policy ON note_tasks;
    DROP POLICY IF EXISTS note_tasks_update_policy ON note_tasks;

    CREATE POLICY note_tasks_select_policy ON note_tasks
      FOR SELECT
      USING (
        user_id = auth.uid()
        AND deleted = false
      );

    CREATE POLICY note_tasks_insert_policy ON note_tasks
      FOR INSERT
      WITH CHECK (
        user_id = auth.uid()
      );

    CREATE POLICY note_tasks_update_policy ON note_tasks
      FOR UPDATE
      USING (
        user_id = auth.uid()
      )
      WITH CHECK (
        user_id = auth.uid()
      );
  END IF;
END $$;

-- ============================================================================
-- FOLDERS TABLE RLS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS folders_select_policy ON folders;
DROP POLICY IF EXISTS folders_insert_policy ON folders;
DROP POLICY IF EXISTS folders_update_policy ON folders;

CREATE POLICY folders_select_policy ON folders
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND deleted = false
  );

CREATE POLICY folders_insert_policy ON folders
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
  );

CREATE POLICY folders_update_policy ON folders
  FOR UPDATE
  USING (
    user_id = auth.uid()
  )
  WITH CHECK (
    user_id = auth.uid()
  );

-- ============================================================================
-- NOTE_FOLDERS RELATIONSHIP RLS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS note_folders_select_policy ON note_folders;
DROP POLICY IF EXISTS note_folders_insert_policy ON note_folders;
DROP POLICY IF EXISTS note_folders_delete_policy ON note_folders;

CREATE POLICY note_folders_select_policy ON note_folders
  FOR SELECT
  USING (
    user_id = auth.uid()
  );

CREATE POLICY note_folders_insert_policy ON note_folders
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM notes WHERE id = note_id AND user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM folders WHERE id = folder_id AND user_id = auth.uid()
    )
  );

CREATE POLICY note_folders_delete_policy ON note_folders
  FOR DELETE
  USING (
    user_id = auth.uid()
  );

-- ============================================================================
-- SECURITY AUDIT TABLES (Optional - Create if needed)
-- ============================================================================

-- Create rate limit logging table
CREATE TABLE IF NOT EXISTS rate_limit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  operation TEXT NOT NULL,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_log_user ON rate_limit_log(user_id, operation, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rate_limit_log_cleanup ON rate_limit_log(created_at);

-- Create user sessions table for device tracking
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  session_id TEXT NOT NULL,
  device_fingerprint TEXT,
  ip_address INET,
  user_agent TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  last_activity TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(user_id, is_active, last_activity DESC);

-- Create security events table
CREATE TABLE IF NOT EXISTS security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  description TEXT,
  metadata JSONB,
  ip_address INET,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_events_user ON security_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type, severity, created_at DESC);

-- Enable RLS on security tables
ALTER TABLE rate_limit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events ENABLE ROW LEVEL SECURITY;

-- Only allow system to write to security tables
CREATE POLICY rate_limit_log_system_only ON rate_limit_log
  FOR ALL
  USING (false)
  WITH CHECK (false);

CREATE POLICY user_sessions_select ON user_sessions
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY security_events_select ON security_events
  FOR SELECT
  USING (user_id = auth.uid());

-- ============================================================================
-- GRANT NECESSARY PERMISSIONS
-- ============================================================================

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_jwt_claims() TO authenticated;