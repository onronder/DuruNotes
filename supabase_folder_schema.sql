-- =====================================================
-- Supabase Schema for Folder System (CORRECTED)
-- Run this in your Supabase SQL Editor
-- =====================================================

-- Create folders table in Supabase
-- Note: Using UUID type to match existing notes table structure
CREATE TABLE public.folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Folder metadata (encrypted)
    name_enc BYTEA NOT NULL,    -- encrypted folder name
    props_enc BYTEA NOT NULL,   -- encrypted folder properties (parentId, color, icon, etc.)
    
    -- Server-side metadata (not encrypted)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted BOOLEAN DEFAULT FALSE,
    
    -- Constraints
    CONSTRAINT folders_user_id_check CHECK (user_id IS NOT NULL)
);

-- Create note_folders relationship table in Supabase  
-- Note: Using UUID types to match existing table structures
CREATE TABLE public.note_folders (
    note_id UUID NOT NULL,
    folder_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Primary key and constraints
    PRIMARY KEY (note_id),
    FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE,
    FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
    
    CONSTRAINT note_folders_user_id_check CHECK (user_id IS NOT NULL)
);

-- =====================================================
-- Indexes for Performance
-- =====================================================

-- Folders indexes
CREATE INDEX idx_folders_user_id ON folders(user_id);
CREATE INDEX idx_folders_user_deleted ON folders(user_id, deleted);
CREATE INDEX idx_folders_updated_at ON folders(updated_at DESC);

-- Note-folder relationship indexes
CREATE INDEX idx_note_folders_folder_id ON note_folders(folder_id);
CREATE INDEX idx_note_folders_user_id ON note_folders(user_id);

-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_folders ENABLE ROW LEVEL SECURITY;

-- Folders policies
CREATE POLICY "Users can view own folders" ON folders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own folders" ON folders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own folders" ON folders
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own folders" ON folders
    FOR DELETE USING (auth.uid() = user_id);

-- Note-folders relationship policies
CREATE POLICY "Users can view own note-folder relationships" ON note_folders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own note-folder relationships" ON note_folders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own note-folder relationships" ON note_folders
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own note-folder relationships" ON note_folders
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- Triggers for Updated At
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for folders table
CREATE TRIGGER update_folders_updated_at
    BEFORE UPDATE ON folders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Optional: Realtime Subscriptions
-- =====================================================

-- Enable realtime for folders (optional)
-- ALTER PUBLICATION supabase_realtime ADD TABLE folders;
-- ALTER PUBLICATION supabase_realtime ADD TABLE note_folders;

-- =====================================================
-- Verification Queries
-- =====================================================

-- Check if tables were created successfully
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('folders', 'note_folders');

-- Check if indexes were created
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename IN ('folders', 'note_folders');

-- Check if RLS policies are enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('folders', 'note_folders');

-- =====================================================
-- Test Data Types Match (Verification)
-- =====================================================

-- Verify notes table structure for compatibility
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'notes' 
AND column_name = 'id';

-- Verify folder tables structure
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN ('folders', 'note_folders')
ORDER BY table_name, ordinal_position;