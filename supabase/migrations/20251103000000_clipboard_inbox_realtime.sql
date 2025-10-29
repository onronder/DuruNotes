-- Enable efficient lookups for RLS and trigger logic
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_user_id
  ON public.clipper_inbox (user_id);

-- Broadcast clipper_inbox changes to per-user realtime topics
CREATE OR REPLACE FUNCTION public.clipper_inbox_broadcast_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := COALESCE(NEW.user_id, OLD.user_id);
  v_topic   text := 'inbox:user:' || v_user_id::text;
BEGIN
  -- Skip when we cannot determine the user (defensive guard)
  IF v_user_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  PERFORM realtime.broadcast_changes(
    v_topic,          -- topic name
    TG_OP,            -- event label (INSERT | UPDATE | DELETE)
    TG_OP,            -- event name
    TG_TABLE_NAME,    -- table name
    TG_TABLE_SCHEMA,  -- schema
    NEW,              -- new row (may be NULL on DELETE)
    OLD               -- old row (may be NULL on INSERT)
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Attach trigger to broadcast changes after mutations
DROP TRIGGER IF EXISTS clipper_inbox_broadcast_trigger
  ON public.clipper_inbox;

CREATE TRIGGER clipper_inbox_broadcast_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.clipper_inbox
FOR EACH ROW
EXECUTE FUNCTION public.clipper_inbox_broadcast_trigger();

-- Ensure RLS is active on realtime.messages before adding policies
ALTER TABLE IF EXISTS realtime.messages
  ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to receive messages for their own inbox topic
DROP POLICY IF EXISTS inbox_read ON realtime.messages;
CREATE POLICY inbox_read
ON realtime.messages
FOR SELECT
TO authenticated
USING (
  topic LIKE 'inbox:user:%'
  AND (split_part(topic, ':', 3))::uuid = auth.uid()
);

-- Allow authenticated users to publish to their own inbox topic (optional)
DROP POLICY IF EXISTS inbox_write ON realtime.messages;
CREATE POLICY inbox_write
ON realtime.messages
FOR INSERT
TO authenticated
WITH CHECK (
  topic LIKE 'inbox:user:%'
  AND (split_part(topic, ':', 3))::uuid = auth.uid()
);
