-- Ensure note_tasks and reminders tables (plus supporting policies/indexes) exist
-- for post-migration task/reminder flows.

BEGIN;

------------------------------------------------------------
-- note_tasks
------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'note_tasks'
  ) THEN
    CREATE TABLE public.note_tasks (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      note_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
      user_id uuid NOT NULL,
      content text NOT NULL,
      status text NOT NULL DEFAULT 'pending',
      priority integer NOT NULL DEFAULT 0,
      position integer NOT NULL DEFAULT 0,
      due_date timestamptz,
      completed_at timestamptz,
      parent_id uuid REFERENCES public.note_tasks (id) ON DELETE SET NULL,
      labels jsonb NOT NULL DEFAULT '[]'::jsonb,
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      deleted boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
      updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
    );
  END IF;
END;
$$;

ALTER TABLE public.note_tasks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'note_tasks'
      AND policyname = 'note_tasks_owner'
  ) THEN
    CREATE POLICY note_tasks_owner ON public.note_tasks
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_note_tasks_updated'
      AND tgrelid = 'public.note_tasks'::regclass
  ) THEN
    CREATE TRIGGER trg_note_tasks_updated
      BEFORE UPDATE ON public.note_tasks
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS note_tasks_user_updated_idx
  ON public.note_tasks (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS note_tasks_note_idx
  ON public.note_tasks (note_id);

------------------------------------------------------------
-- reminders
------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'reminders'
  ) THEN
    CREATE TABLE public.reminders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      note_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
      user_id uuid NOT NULL,
      title text NOT NULL DEFAULT '',
      body text NOT NULL DEFAULT '',
      type text NOT NULL,
      remind_at timestamptz,
      is_active boolean NOT NULL DEFAULT true,
      recurrence_pattern text NOT NULL DEFAULT 'none',
      recurrence_interval integer NOT NULL DEFAULT 1,
      recurrence_end_date timestamptz,
      latitude double precision,
      longitude double precision,
      radius double precision,
      location_name text,
      snoozed_until timestamptz,
      snooze_count integer NOT NULL DEFAULT 0,
      trigger_count integer NOT NULL DEFAULT 0,
      last_triggered timestamptz,
      created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
      updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
    );
  END IF;
END;
$$;

ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reminders'
      AND policyname = 'reminders_owner'
  ) THEN
    CREATE POLICY reminders_owner ON public.reminders
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_reminders_updated'
      AND tgrelid = 'public.reminders'::regclass
  ) THEN
    CREATE TRIGGER trg_reminders_updated
      BEFORE UPDATE ON public.reminders
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS reminders_user_note_idx
  ON public.reminders (user_id, note_id);
CREATE INDEX IF NOT EXISTS reminders_active_idx
  ON public.reminders (user_id, is_active);

COMMIT;
