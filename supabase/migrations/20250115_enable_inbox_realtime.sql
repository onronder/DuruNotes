-- Enable realtime on clipper_inbox table
ALTER TABLE clipper_inbox REPLICA IDENTITY FULL;

-- Add to realtime publication if not already there
DO $$
BEGIN
  -- Check if already in publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'clipper_inbox'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE clipper_inbox;
    RAISE NOTICE 'Added clipper_inbox to realtime publication';
  ELSE
    RAISE NOTICE 'clipper_inbox already in realtime publication';
  END IF;
END $$;

-- Verify realtime is enabled
SELECT 
  'clipper_inbox realtime enabled' as status,
  EXISTS(
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'clipper_inbox'
  ) as enabled;
