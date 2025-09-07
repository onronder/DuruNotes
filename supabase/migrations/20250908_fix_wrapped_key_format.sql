-- Migration to fix wrapped_key format issue
-- Converts existing bytea wrapped_keys to base64 text format

-- First, let's check if there are any existing wrapped_keys in bytea format
DO $$
BEGIN
    -- Check if the wrapped_key column exists and is bytea type
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_keys' 
        AND column_name = 'wrapped_key'
        AND data_type = 'bytea'
    ) THEN
        -- Add a temporary column for the base64 version
        ALTER TABLE user_keys ADD COLUMN IF NOT EXISTS wrapped_key_b64 TEXT;
        
        -- Convert existing bytea values to base64
        UPDATE user_keys 
        SET wrapped_key_b64 = encode(wrapped_key::bytea, 'base64')
        WHERE wrapped_key IS NOT NULL;
        
        -- Drop the old column and rename the new one
        ALTER TABLE user_keys DROP COLUMN wrapped_key;
        ALTER TABLE user_keys RENAME COLUMN wrapped_key_b64 TO wrapped_key;
        
        RAISE NOTICE 'Successfully migrated wrapped_key from bytea to text (base64)';
    ELSIF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_keys' 
        AND column_name = 'wrapped_key'
        AND data_type = 'text'
    ) THEN
        RAISE NOTICE 'wrapped_key is already text type, no migration needed';
    ELSE
        RAISE NOTICE 'user_keys table or wrapped_key column not found';
    END IF;
END $$;
