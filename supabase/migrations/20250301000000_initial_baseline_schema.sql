-- Baseline migration for project mizzxiijxtbwrqgflpnp
-- Creates core tables, policies, and helper functions required by the Duru Notes app.

BEGIN;

-- Ensure crypto helpers are available for UUID and random bytes.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Utility function to automatically maintain updated_at timestamps.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

-- =====================================================================
-- 1. Profiles & Encryption
-- =====================================================================

CREATE TABLE public.user_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email text NOT NULL,
  first_name text NOT NULL DEFAULT '',
  last_name text NOT NULL DEFAULT '',
  passphrase_hint text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_user_profiles_updated
BEFORE UPDATE ON public.user_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_profiles_owner ON public.user_profiles
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.user_keys (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  wrapped_key text NOT NULL,
  kdf text NOT NULL DEFAULT 'pbkdf2-hmac-sha256',
  kdf_params jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_user_keys_updated
BEFORE UPDATE ON public.user_keys
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_keys_owner ON public.user_keys
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.user_encryption_keys (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  encrypted_amk text NOT NULL,
  amk_salt text NOT NULL,
  algorithm text NOT NULL DEFAULT 'Argon2id',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_user_encryption_keys_updated
BEFORE UPDATE ON public.user_encryption_keys
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_encryption_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_encryption_keys_owner ON public.user_encryption_keys
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- 2. Notes & Folders
-- =====================================================================

CREATE TABLE public.notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title_enc bytea NOT NULL,
  props_enc bytea NOT NULL,
  encrypted_metadata jsonb,
  note_type integer NOT NULL DEFAULT 0,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX notes_user_updated_idx ON public.notes (user_id, updated_at DESC);
CREATE INDEX notes_user_deleted_idx ON public.notes (user_id, deleted);

CREATE TRIGGER trg_notes_updated
BEFORE UPDATE ON public.notes
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY notes_owner ON public.notes
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  name_enc bytea NOT NULL,
  props_enc bytea NOT NULL,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX folders_user_updated_idx ON public.folders (user_id, updated_at DESC);

CREATE TRIGGER trg_folders_updated
BEFORE UPDATE ON public.folders
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
CREATE POLICY folders_owner ON public.folders
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.note_folders (
  note_id uuid PRIMARY KEY REFERENCES public.notes (id) ON DELETE CASCADE,
  folder_id uuid NOT NULL REFERENCES public.folders (id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  added_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.note_folders ENABLE ROW LEVEL SECURITY;
CREATE POLICY note_folders_owner ON public.note_folders
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.note_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  idx integer NOT NULL,
  type text NOT NULL,
  content_enc bytea NOT NULL,
  attrs_enc bytea,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX note_blocks_note_idx ON public.note_blocks (note_id, idx);

CREATE TRIGGER trg_note_blocks_updated
BEFORE UPDATE ON public.note_blocks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.note_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY note_blocks_owner ON public.note_blocks
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

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

CREATE INDEX note_tasks_user_updated_idx ON public.note_tasks (user_id, updated_at DESC);
CREATE INDEX note_tasks_note_idx ON public.note_tasks (note_id);

CREATE TRIGGER trg_note_tasks_updated
BEFORE UPDATE ON public.note_tasks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.note_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY note_tasks_owner ON public.note_tasks
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title_enc bytea NOT NULL,
  body_enc bytea NOT NULL,
  tags_enc bytea,
  description_enc bytea,
  category text,
  icon text,
  sort_order integer NOT NULL DEFAULT 0,
  props_enc bytea,
  is_system boolean NOT NULL DEFAULT false,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX templates_user_idx ON public.templates (user_id, deleted, is_system);

CREATE TRIGGER trg_templates_updated
BEFORE UPDATE ON public.templates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY templates_owner ON public.templates
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.saved_searches (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  query text NOT NULL,
  search_type text NOT NULL DEFAULT 'text',
  parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  color text,
  icon text,
  is_pinned boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  last_used_at timestamptz,
  usage_count integer NOT NULL DEFAULT 0
);

CREATE INDEX saved_searches_user_idx
  ON public.saved_searches (user_id, is_pinned DESC, sort_order ASC);

ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;
CREATE POLICY saved_searches_owner ON public.saved_searches
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.tags (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  color text,
  icon text,
  usage_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_tags_updated
BEFORE UPDATE ON public.tags
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY tags_owner ON public.tags
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.note_tags (
  note_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
  tag text NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (note_id, tag)
);

ALTER TABLE public.note_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY note_tags_owner ON public.note_tags
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.note_links (
  source_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
  target_title text NOT NULL,
  user_id uuid NOT NULL,
  link_type text NOT NULL DEFAULT 'manual',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (source_id, target_id)
);

ALTER TABLE public.note_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY note_links_owner ON public.note_links
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

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

CREATE INDEX reminders_user_note_idx ON public.reminders (user_id, note_id);
CREATE INDEX reminders_active_idx ON public.reminders (user_id, is_active);

CREATE TRIGGER trg_reminders_updated
BEFORE UPDATE ON public.reminders
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY reminders_owner ON public.reminders
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- 3. Attachments & Inbound Email
-- =====================================================================

CREATE TABLE public.attachments (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  note_id uuid REFERENCES public.notes (id) ON DELETE SET NULL,
  file_name text NOT NULL,
  storage_path text NOT NULL,
  mime_type text,
  size integer,
  url text,
  uploaded_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  deleted boolean NOT NULL DEFAULT false
);

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
CREATE POLICY attachments_owner ON public.attachments
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public."inbound-attachments" (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  inbox_id uuid,
  file_name text NOT NULL,
  storage_path text NOT NULL,
  mime_type text,
  size integer,
  url text,
  status text NOT NULL DEFAULT 'pending',
  ingested boolean NOT NULL DEFAULT false,
  error text,
  uploaded_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public."inbound-attachments" ENABLE ROW LEVEL SECURITY;
CREATE POLICY inbound_attachments_owner ON public."inbound-attachments"
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public."inbound-attachments-temp" (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  inbox_id uuid,
  file_name text NOT NULL,
  storage_path text NOT NULL,
  mime_type text,
  size integer,
  url text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public."inbound-attachments-temp" ENABLE ROW LEVEL SECURITY;
CREATE POLICY inbound_attachments_temp_owner ON public."inbound-attachments-temp"
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.clipper_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  source_type text NOT NULL,
  title text,
  content text,
  html text,
  metadata jsonb,
  message_id text,
  payload_json jsonb,
  converted_to_note_id uuid,
  converted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_clipper_inbox_updated
BEFORE UPDATE ON public.clipper_inbox
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.clipper_inbox ENABLE ROW LEVEL SECURITY;
CREATE POLICY clipper_inbox_owner ON public.clipper_inbox
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.inbound_aliases (
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  alias text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (user_id, alias)
);

CREATE UNIQUE INDEX inbound_aliases_alias_key ON public.inbound_aliases (alias);

CREATE TRIGGER trg_inbound_aliases_updated
BEFORE UPDATE ON public.inbound_aliases
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.inbound_aliases ENABLE ROW LEVEL SECURITY;
CREATE POLICY inbound_aliases_owner ON public.inbound_aliases
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- 4. Notifications & Push
-- =====================================================================

CREATE TABLE public.notification_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_type text NOT NULL,
  event_source text,
  priority text NOT NULL DEFAULT 'normal',
  payload jsonb NOT NULL,
  scheduled_for timestamptz NOT NULL DEFAULT timezone('utc', now()),
  processed_at timestamptz,
  status text NOT NULL DEFAULT 'pending',
  retry_count integer NOT NULL DEFAULT 0,
  max_retries integer NOT NULL DEFAULT 3,
  dedupe_key text,
  error_message text,
  error_details jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX notification_events_dedupe_idx
  ON public.notification_events (user_id, dedupe_key)
  WHERE dedupe_key IS NOT NULL;

CREATE TRIGGER trg_notification_events_updated
BEFORE UPDATE ON public.notification_events
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY notification_events_owner ON public.notification_events
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  device_id text NOT NULL,
  push_token text,
  platform text,
  app_version text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX user_devices_device_idx
  ON public.user_devices (user_id, device_id);

CREATE TRIGGER trg_user_devices_updated
BEFORE UPDATE ON public.user_devices
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_devices_owner ON public.user_devices
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT true,
  push_enabled boolean NOT NULL DEFAULT true,
  email_enabled boolean NOT NULL DEFAULT false,
  in_app_enabled boolean NOT NULL DEFAULT true,
  sms_enabled boolean NOT NULL DEFAULT false,
  quiet_hours_enabled boolean NOT NULL DEFAULT false,
  quiet_hours_start text,
  quiet_hours_end text,
  dnd_enabled boolean NOT NULL DEFAULT false,
  dnd_until timestamptz,
  batch_notifications boolean NOT NULL DEFAULT false,
  notification_cooldown_minutes integer NOT NULL DEFAULT 5,
  max_daily_notifications integer NOT NULL DEFAULT 50,
  min_priority text NOT NULL DEFAULT 'low',
  event_preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  timezone text NOT NULL DEFAULT 'UTC',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  last_notification_sent_at timestamptz,
  daily_notification_count integer NOT NULL DEFAULT 0,
  daily_count_reset_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  version integer NOT NULL DEFAULT 1
);

CREATE TRIGGER trg_notification_preferences_updated
BEFORE UPDATE ON public.notification_preferences
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY notification_preferences_owner ON public.notification_preferences
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES public.notification_events (id) ON DELETE SET NULL,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  channel text NOT NULL,
  device_id uuid REFERENCES public.user_devices (id) ON DELETE SET NULL,
  status text,
  provider_response jsonb,
  provider_message_id text,
  sent_at timestamptz,
  delivered_at timestamptz,
  opened_at timestamptz,
  clicked_at timestamptz,
  failed_at timestamptz,
  error_code text,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX notification_deliveries_user_idx
  ON public.notification_deliveries (user_id, created_at DESC);

ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
CREATE POLICY notification_deliveries_owner ON public.notification_deliveries
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Trigger to maintain daily notification counts.
CREATE OR REPLACE FUNCTION public.notification_preferences_increment_daily()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.daily_notification_count = 1 THEN
    IF OLD.daily_count_reset_at IS NULL
       OR (timezone('utc', now())::date > OLD.daily_count_reset_at::date) THEN
      NEW.daily_notification_count := 1;
      NEW.daily_count_reset_at := timezone('utc', now());
    ELSE
      NEW.daily_notification_count := OLD.daily_notification_count + 1;
      NEW.daily_count_reset_at := OLD.daily_count_reset_at;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notification_preferences_daily
BEFORE UPDATE ON public.notification_preferences
FOR EACH ROW
WHEN (NEW.daily_notification_count = 1 OR NEW.daily_notification_count IS NULL)
EXECUTE FUNCTION public.notification_preferences_increment_daily();

-- =====================================================================
-- 5. User Preferences & Security
-- =====================================================================

CREATE TABLE public.user_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  language text NOT NULL DEFAULT 'en',
  theme text NOT NULL DEFAULT 'system',
  timezone text NOT NULL DEFAULT 'UTC',
  notifications_enabled boolean NOT NULL DEFAULT true,
  analytics_enabled boolean NOT NULL DEFAULT true,
  error_reporting_enabled boolean NOT NULL DEFAULT true,
  data_collection_consent boolean NOT NULL DEFAULT false,
  compact_mode boolean NOT NULL DEFAULT false,
  show_inline_images boolean NOT NULL DEFAULT true,
  font_size text NOT NULL DEFAULT 'medium',
  last_synced_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_user_preferences_updated
BEFORE UPDATE ON public.user_preferences
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_preferences_owner ON public.user_preferences
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.password_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.password_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY password_history_owner ON public.password_history
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE public.security_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  event_type text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  description text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY security_alerts_owner ON public.security_alerts
  USING (user_id IS NULL OR user_id = auth.uid())
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

-- =====================================================================
-- 6. Helper Functions / RPCs
-- =====================================================================

CREATE OR REPLACE FUNCTION public.generate_user_alias(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias text;
BEGIN
  SELECT alias INTO v_alias
  FROM public.inbound_aliases
  WHERE user_id = p_user_id
  LIMIT 1;

  IF FOUND THEN
    RETURN v_alias;
  END IF;

  LOOP
    v_alias := lower(replace(encode(gen_random_bytes(6), 'base64'), '/', ''));
    v_alias := regexp_replace(v_alias, '[^a-z0-9]', '', 'g');
    IF length(v_alias) < 6 THEN
      CONTINUE;
    END IF;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.inbound_aliases WHERE alias = v_alias
    );
  END LOOP;

  INSERT INTO public.inbound_aliases (user_id, alias)
  VALUES (p_user_id, v_alias)
  ON CONFLICT (user_id, alias) DO NOTHING;

  RETURN v_alias;
END;
$$;

CREATE OR REPLACE FUNCTION public.should_send_notification(
  p_user_id uuid,
  p_event_type text,
  p_channel text,
  p_priority text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  prefs record;
  current_priority int;
  min_priority int;
BEGIN
  SELECT *,
         CASE LOWER(min_priority)
           WHEN 'low' THEN 1
           WHEN 'normal' THEN 2
           WHEN 'high' THEN 3
           WHEN 'urgent' THEN 4
           ELSE 1
         END AS min_priority_value
  INTO prefs
  FROM public.notification_preferences
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN true;
  END IF;

  IF NOT prefs.enabled THEN
    RETURN false;
  END IF;

  IF prefs.dnd_enabled AND (prefs.dnd_until IS NULL OR prefs.dnd_until > timezone('utc', now())) THEN
    IF LOWER(p_priority) <> 'urgent' THEN
      RETURN false;
    END IF;
  END IF;

  -- Reset daily counter if needed
  IF prefs.daily_count_reset_at IS NULL
     OR timezone('utc', now())::date > prefs.daily_count_reset_at::date THEN
    UPDATE public.notification_preferences
      SET daily_notification_count = 0,
          daily_count_reset_at = timezone('utc', now())
      WHERE user_id = p_user_id;
    prefs.daily_notification_count := 0;
    prefs.daily_count_reset_at := timezone('utc', now());
  END IF;

  IF prefs.daily_notification_count >= prefs.max_daily_notifications THEN
    RETURN false;
  END IF;

  IF LOWER(p_channel) = 'push' AND NOT prefs.push_enabled THEN
    RETURN false;
  ELSIF LOWER(p_channel) = 'email' AND NOT prefs.email_enabled THEN
    RETURN false;
  ELSIF LOWER(p_channel) = 'inapp' AND NOT prefs.in_app_enabled THEN
    RETURN false;
  ELSIF LOWER(p_channel) = 'sms' AND NOT prefs.sms_enabled THEN
    RETURN false;
  END IF;

  CASE LOWER(p_priority)
    WHEN 'low' THEN current_priority := 1;
    WHEN 'normal' THEN current_priority := 2;
    WHEN 'high' THEN current_priority := 3;
    WHEN 'urgent' THEN current_priority := 4;
    ELSE current_priority := 1;
  END CASE;

  min_priority := prefs.min_priority_value;
  IF current_priority < min_priority THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_notification_event(
  p_user_id uuid,
  p_event_type text,
  p_event_source text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_priority text DEFAULT 'normal',
  p_scheduled_for timestamptz DEFAULT timezone('utc', now()),
  p_dedupe_key text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_dedupe_key IS NOT NULL THEN
    SELECT id INTO v_id
    FROM public.notification_events
    WHERE user_id = p_user_id
      AND dedupe_key = p_dedupe_key
      AND status = 'pending'
    LIMIT 1;

    IF FOUND THEN
      RETURN v_id;
    END IF;
  END IF;

  INSERT INTO public.notification_events (
    user_id,
    event_type,
    event_source,
    priority,
    payload,
    scheduled_for,
    dedupe_key
  )
  VALUES (
    p_user_id,
    p_event_type,
    p_event_source,
    p_priority,
    p_payload,
    p_scheduled_for,
    p_dedupe_key
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.user_devices_upsert(
  _device_id text,
  _push_token text,
  _platform text,
  _app_version text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  INSERT INTO public.user_devices (
    user_id,
    device_id,
    push_token,
    platform,
    app_version
  )
  VALUES (
    v_user_id,
    _device_id,
    _push_token,
    _platform,
    _app_version
  )
  ON CONFLICT (user_id, device_id)
  DO UPDATE SET
    push_token = EXCLUDED.push_token,
    platform = EXCLUDED.platform,
    app_version = EXCLUDED.app_version,
    updated_at = timezone('utc', now());
END;
$$;

-- =====================================================================
-- 7. Final
-- =====================================================================

COMMIT;
