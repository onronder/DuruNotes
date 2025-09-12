-- Create user_devices table for storing push notification tokens
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    push_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web', 'unknown')),
    app_version TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    
    -- Ensure unique device per user
    UNIQUE(user_id, device_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_updated_at ON public.user_devices(updated_at);

-- Enable Row Level Security
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only view and manage their own devices
CREATE POLICY "Users can view their own devices"
    ON public.user_devices
    FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update their own devices"
    ON public.user_devices
    FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete their own devices"
    ON public.user_devices
    FOR DELETE
    USING (user_id = auth.uid());

-- Note: INSERT is handled through the RPC function below, not directly

-- Create function for upserting device tokens
CREATE OR REPLACE FUNCTION public.user_devices_upsert(
    _device_id TEXT,
    _push_token TEXT,
    _platform TEXT,
    _app_version TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Validate inputs
    IF _device_id IS NULL OR _device_id = '' THEN
        RAISE EXCEPTION 'device_id cannot be null or empty';
    END IF;
    
    IF _push_token IS NULL OR _push_token = '' THEN
        RAISE EXCEPTION 'push_token cannot be null or empty';
    END IF;
    
    IF _platform IS NULL OR _platform = '' THEN
        RAISE EXCEPTION 'platform cannot be null or empty';
    END IF;
    
    -- Validate platform value
    IF _platform NOT IN ('ios', 'android', 'web', 'unknown') THEN
        RAISE EXCEPTION 'Invalid platform value: %', _platform;
    END IF;
    
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;
    
    -- Perform upsert
    INSERT INTO public.user_devices (
        user_id,
        device_id,
        push_token,
        platform,
        app_version,
        updated_at
    )
    VALUES (
        auth.uid(),
        _device_id,
        _push_token,
        _platform,
        _app_version,
        now()
    )
    ON CONFLICT (user_id, device_id)
    DO UPDATE SET
        push_token = EXCLUDED.push_token,
        platform = EXCLUDED.platform,
        app_version = EXCLUDED.app_version,
        updated_at = now();
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.user_devices_upsert TO authenticated;

-- Create function to get all device tokens for a user (for server-side use)
CREATE OR REPLACE FUNCTION public.get_user_device_tokens(_user_id UUID)
RETURNS TABLE (
    device_id TEXT,
    push_token TEXT,
    platform TEXT,
    app_version TEXT,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- This function is for server-side use only
    -- It can retrieve tokens for any user (for sending notifications)
    RETURN QUERY
    SELECT 
        ud.device_id,
        ud.push_token,
        ud.platform,
        ud.app_version,
        ud.updated_at
    FROM public.user_devices ud
    WHERE ud.user_id = _user_id
    ORDER BY ud.updated_at DESC;
END;
$$;

-- Grant execute permission to service role only (for server-side use)
GRANT EXECUTE ON FUNCTION public.get_user_device_tokens TO service_role;

-- Create function to clean up old/stale tokens (maintenance)
CREATE OR REPLACE FUNCTION public.cleanup_stale_device_tokens(
    _days_old INTEGER DEFAULT 90
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete tokens that haven't been updated in the specified number of days
    DELETE FROM public.user_devices
    WHERE updated_at < (now() - (_days_old || ' days')::INTERVAL);
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$;

-- Grant execute permission to service role only (for maintenance)
GRANT EXECUTE ON FUNCTION public.cleanup_stale_device_tokens TO service_role;

-- Create trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_user_devices_updated_at
    BEFORE UPDATE ON public.user_devices
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE public.user_devices IS 'Stores FCM push notification tokens for user devices';
COMMENT ON COLUMN public.user_devices.user_id IS 'Reference to the user who owns this device';
COMMENT ON COLUMN public.user_devices.device_id IS 'Unique identifier for the device (app-generated UUID)';
COMMENT ON COLUMN public.user_devices.push_token IS 'FCM registration token for push notifications';
COMMENT ON COLUMN public.user_devices.platform IS 'Device platform (ios, android, web, unknown)';
COMMENT ON COLUMN public.user_devices.app_version IS 'App version string (e.g., 1.0.0+1)';
COMMENT ON FUNCTION public.user_devices_upsert IS 'Upsert a device token for the authenticated user';
COMMENT ON FUNCTION public.get_user_device_tokens IS 'Get all device tokens for a user (server-side use only)';
COMMENT ON FUNCTION public.cleanup_stale_device_tokens IS 'Remove old device tokens that havent been updated recently';
