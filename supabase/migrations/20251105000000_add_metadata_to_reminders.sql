-- Ensure reminders table stores task metadata payloads
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'reminders'
      AND column_name = 'metadata'
  ) THEN
    ALTER TABLE public.reminders
      ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
  END IF;
END;
$$;

COMMIT;
