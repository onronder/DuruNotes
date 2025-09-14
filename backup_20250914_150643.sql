

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."_policy_exists"("schemaname" "text", "tablename" "text", "policyname" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $_$
  select exists(
    select 1 from pg_policies 
    where schemaname = $1 and tablename = $2 and policyname = $3
  );
$_$;


ALTER FUNCTION "public"."_policy_exists"("schemaname" "text", "tablename" "text", "policyname" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_notification_events"("batch_limit" integer DEFAULT 50) RETURNS TABLE("id" "uuid", "user_id" "uuid", "event_type" "text", "event_source" "text", "priority" "text", "payload" "jsonb", "scheduled_for" timestamp with time zone, "processed_at" timestamp with time zone, "status" "text", "retry_count" integer, "max_retries" integer, "dedupe_key" "text", "error_message" "text", "error_details" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "notification_templates" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    -- Atomically claim and update events to processing status
    -- This prevents concurrent workers from processing the same events
    RETURN QUERY
    WITH claimed AS (
        SELECT ne.id
        FROM notification_events ne
        WHERE ne.status = 'pending'
          AND ne.scheduled_for <= now()
        ORDER BY ne.priority DESC, ne.scheduled_for ASC
        LIMIT batch_limit
        FOR UPDATE SKIP LOCKED
    ),
    updated AS (
        UPDATE notification_events ne
        SET status = 'processing',
            processed_at = now(),
            updated_at = now()
        FROM claimed
        WHERE ne.id = claimed.id
        RETURNING ne.*
    )
    SELECT 
        u.*,
        row_to_json(nt.*)::jsonb as notification_templates
    FROM updated u
    LEFT JOIN notification_templates nt ON nt.event_type = u.event_type;
END;
$$;


ALTER FUNCTION "public"."claim_notification_events"("batch_limit" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."claim_notification_events"("batch_limit" integer) IS 'Atomically claim notification events for processing with concurrency control';



CREATE OR REPLACE FUNCTION "public"."cleanup_old_login_attempts"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM login_attempts 
    WHERE attempt_time < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_old_login_attempts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_old_notifications"("p_days_old" integer DEFAULT 30) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    -- Delete old processed notifications
    DELETE FROM notification_events
    WHERE created_at < (now() - (p_days_old || ' days')::INTERVAL)
    AND status IN ('delivered', 'failed', 'cancelled');
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_old_notifications"("p_days_old" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."cleanup_old_notifications"("p_days_old" integer) IS 'Clean up old notification records';



CREATE OR REPLACE FUNCTION "public"."cleanup_stale_device_tokens"("p_days_old" integer DEFAULT 90) RETURNS TABLE("deleted_count" integer, "oldest_deleted" timestamp with time zone, "users_affected" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_deleted_count INTEGER;
    v_oldest TIMESTAMPTZ;
    v_users INTEGER;
BEGIN
    -- Get stats before deletion
    SELECT MIN(updated_at), COUNT(DISTINCT user_id)
    INTO v_oldest, v_users
    FROM public.user_devices
    WHERE updated_at < (now() - (p_days_old || ' days')::INTERVAL);
    
    -- Delete stale tokens
    DELETE FROM public.user_devices
    WHERE updated_at < (now() - (p_days_old || ' days')::INTERVAL);
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN QUERY SELECT v_deleted_count, v_oldest, v_users;
END;
$$;


ALTER FUNCTION "public"."cleanup_stale_device_tokens"("p_days_old" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_notification_event"("p_user_id" "uuid", "p_event_type" "text", "p_event_source" "text", "p_payload" "jsonb" DEFAULT '{}'::"jsonb", "p_priority" "text" DEFAULT 'normal'::"text", "p_scheduled_for" timestamp with time zone DEFAULT "now"(), "p_dedupe_key" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_event_id UUID;
    v_template notification_templates;
BEGIN
    -- Check if template exists and is enabled
    SELECT * INTO v_template
    FROM notification_templates
    WHERE event_type = p_event_type
    AND enabled = true;
    
    IF NOT FOUND THEN
        RAISE WARNING 'No enabled template found for event type: %', p_event_type;
        RETURN NULL;
    END IF;
    
    -- Check user preferences
    IF NOT EXISTS (
        SELECT 1 FROM notification_preferences
        WHERE user_id = p_user_id
        AND enabled = true
        AND (
            event_preferences IS NULL 
            OR event_preferences = '{}'
            OR COALESCE((event_preferences->p_event_type->>'enabled')::boolean, true) = true
        )
    ) THEN
        -- User has disabled this notification type
        RETURN NULL;
    END IF;
    
    -- Insert the event (with deduplication)
    INSERT INTO notification_events (
        user_id,
        event_type,
        event_source,
        payload,
        priority,
        scheduled_for,
        dedupe_key
    ) VALUES (
        p_user_id,
        p_event_type,
        p_event_source,
        p_payload,
        COALESCE(p_priority, v_template.priority, 'normal'),
        p_scheduled_for,
        p_dedupe_key
    )
    ON CONFLICT (user_id, dedupe_key) 
    WHERE dedupe_key IS NOT NULL
    DO UPDATE SET
        payload = EXCLUDED.payload,
        scheduled_for = EXCLUDED.scheduled_for,
        updated_at = now()
    RETURNING id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$;


ALTER FUNCTION "public"."create_notification_event"("p_user_id" "uuid", "p_event_type" "text", "p_event_source" "text", "p_payload" "jsonb", "p_priority" "text", "p_scheduled_for" timestamp with time zone, "p_dedupe_key" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_notification_event"("p_user_id" "uuid", "p_event_type" "text", "p_event_source" "text", "p_payload" "jsonb", "p_priority" "text", "p_scheduled_for" timestamp with time zone, "p_dedupe_key" "text") IS 'Create a new notification event with preference checking';



CREATE OR REPLACE FUNCTION "public"."extract_message_id"("headers" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
declare v_message_id text;
begin
  select substring(headers from 'Message-ID:\s*<([^>]+)>') into v_message_id;
  return v_message_id;
end $$;


ALTER FUNCTION "public"."extract_message_id"("headers" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_user_alias"("p_user_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  v_alias text;
  v_exists boolean;
  v_counter int := 0;
  v_max_attempts int := 10;
  v_random_suffix text;
begin
  -- only the authenticated caller can create THEIR OWN alias
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'not allowed';
  end if;

  -- return existing alias if present
  select alias into v_alias from public.inbound_aliases where user_id = p_user_id;
  if v_alias is not null then
    return v_alias;
  end if;

  -- generate unique alias note_<8-hex>
  loop
    v_random_suffix := lower(substring(md5(random()::text || clock_timestamp()::text), 1, 8));
    v_alias := 'note_' || v_random_suffix;

    select exists(select 1 from public.inbound_aliases where alias = v_alias) into v_exists;
    if not v_exists then
      insert into public.inbound_aliases (user_id, alias) values (p_user_id, v_alias);
      return v_alias;
    end if;

    v_counter := v_counter + 1;
    if v_counter >= v_max_attempts then
      raise exception 'Could not generate unique alias after % attempts', v_max_attempts;
    end if;
  end loop;
end;
$$;


ALTER FUNCTION "public"."generate_user_alias"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_notification_metrics"("p_hours" integer DEFAULT 24) RETURNS TABLE("total_events" integer, "delivered" integer, "failed" integer, "pending" integer, "cancelled" integer, "delivery_rate" numeric, "avg_retry_count" numeric, "events_per_hour" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_events,
        COUNT(CASE WHEN status = 'delivered' THEN 1 END)::INTEGER as delivered,
        COUNT(CASE WHEN status = 'failed' THEN 1 END)::INTEGER as failed,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::INTEGER as pending,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)::INTEGER as cancelled,
        ROUND(
            COUNT(CASE WHEN status = 'delivered' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN status IN ('delivered', 'failed') THEN 1 END), 0) * 100, 
            2
        ) as delivery_rate,
        ROUND(AVG(retry_count), 2) as avg_retry_count,
        ROUND(COUNT(*)::NUMERIC / NULLIF(p_hours, 0), 2) as events_per_hour
    FROM notification_events
    WHERE created_at >= (now() - (p_hours || ' hours')::INTERVAL);
END;
$$;


ALTER FUNCTION "public"."get_notification_metrics"("p_hours" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_notification_metrics"("p_hours" integer) IS 'Get notification delivery metrics for monitoring';



CREATE OR REPLACE FUNCTION "public"."get_user_device_tokens"("_user_id" "uuid") RETURNS TABLE("device_id" "text", "push_token" "text", "platform" "text", "app_version" "text", "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_user_device_tokens"("_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_user_device_tokens"("_user_id" "uuid") IS 'Get all device tokens for a user (server-side use only)';



CREATE OR REPLACE FUNCTION "public"."manual_process_notifications"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification-v1',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key'),
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('batch_size', 10)
    ) INTO result;
    
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."manual_process_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."merge_duplicate_folders"("p_canonical_folder_id" "uuid", "p_duplicate_folder_ids" "uuid"[], "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Validate that all folders belong to the same user
  IF EXISTS (
    SELECT 1 FROM public.folders 
    WHERE id = ANY(p_duplicate_folder_ids || ARRAY[p_canonical_folder_id])
      AND user_id != p_user_id
  ) THEN
    RAISE EXCEPTION 'All folders must belong to the same user';
  END IF;
  
  -- Migrate notes from duplicate folders to canonical folder
  UPDATE public.note_folders
  SET folder_id = p_canonical_folder_id,
      added_at = COALESCE(added_at, NOW())
  WHERE folder_id = ANY(p_duplicate_folder_ids)
    AND user_id = p_user_id
    AND NOT EXISTS (
      -- Don't create duplicate entries
      SELECT 1 FROM public.note_folders nf2
      WHERE nf2.note_id = note_folders.note_id
        AND nf2.folder_id = p_canonical_folder_id
    );
  
  -- Delete any remaining duplicate note_folder entries
  DELETE FROM public.note_folders
  WHERE folder_id = ANY(p_duplicate_folder_ids)
    AND user_id = p_user_id;
  
  -- Soft-delete the duplicate folders
  UPDATE public.folders
  SET deleted = true,
      updated_at = NOW()
  WHERE id = ANY(p_duplicate_folder_ids)
    AND user_id = p_user_id;
  
  RAISE NOTICE 'Merged % duplicate folders into canonical folder %', 
               array_length(p_duplicate_folder_ids, 1), p_canonical_folder_id;
END;
$$;


ALTER FUNCTION "public"."merge_duplicate_folders"("p_canonical_folder_id" "uuid", "p_duplicate_folder_ids" "uuid"[], "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_stale_clipper_inbox"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  delete from public.clipper_inbox where created_at < now() - interval '48 hours';
end $$;


ALTER FUNCTION "public"."purge_stale_clipper_inbox"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_auth_user_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin if new.user_id is null then new.user_id = auth.uid(); end if; return new; end $$;


ALTER FUNCTION "public"."set_auth_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_clipper_inbox_payload_json"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- On INSERT or UPDATE, sync payload_json with individual columns
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- If payload_json is empty but we have data in columns, build it
        IF (NEW.payload_json = '{}'::jsonb OR NEW.payload_json IS NULL) 
           AND (NEW.title IS NOT NULL OR NEW.content IS NOT NULL) THEN
            NEW.payload_json = CASE
                WHEN NEW.source_type = 'email_in' THEN
                    jsonb_build_object(
                        'to', NEW.metadata->>'to',
                        'from', NEW.metadata->>'from',
                        'subject', NEW.title,
                        'text', NEW.content,
                        'html', NEW.html,
                        'message_id', NEW.message_id,
                        'attachments', NEW.metadata->'attachments',
                        'headers', NEW.metadata->'headers',
                        'received_at', NEW.metadata->>'received_at'
                    )
                WHEN NEW.source_type = 'web' THEN
                    jsonb_build_object(
                        'title', NEW.title,
                        'text', NEW.content,
                        'html', NEW.html,
                        'url', NEW.metadata->>'url',
                        'clipped_at', NEW.metadata->>'clipped_at',
                        'clip_timestamp', NEW.metadata->>'clip_timestamp'
                    )
                ELSE NEW.payload_json
            END;
        -- If we have payload_json but empty columns, extract to columns
        ELSIF NEW.payload_json != '{}'::jsonb 
              AND (NEW.title IS NULL AND NEW.content IS NULL) THEN
            NEW.title = COALESCE(
                NEW.payload_json->>'title',
                NEW.payload_json->>'subject',
                CASE 
                    WHEN NEW.source_type = 'web' THEN 'Web Clip'
                    ELSE 'Email'
                END
            );
            NEW.content = COALESCE(
                NEW.payload_json->>'content',
                NEW.payload_json->>'text',
                NEW.payload_json->>'body',
                ''
            );
            NEW.html = COALESCE(
                NEW.payload_json->>'html',
                NEW.payload_json->>'html_body'
            );
            -- Merge metadata
            NEW.metadata = NEW.metadata || CASE
                WHEN NEW.source_type = 'email_in' THEN
                    jsonb_build_object(
                        'from', NEW.payload_json->>'from',
                        'to', NEW.payload_json->>'to',
                        'headers', NEW.payload_json->'headers',
                        'attachments', NEW.payload_json->'attachments',
                        'received_at', NEW.payload_json->>'received_at'
                    )
                WHEN NEW.source_type = 'web' THEN
                    jsonb_build_object(
                        'url', NEW.payload_json->>'url',
                        'clipped_at', NEW.payload_json->>'clipped_at',
                        'clip_timestamp', NEW.payload_json->>'clip_timestamp'
                    )
                ELSE '{}'::jsonb
            END;
        END IF;
        
        -- Always update the updated_at timestamp
        NEW.updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_clipper_inbox_payload_json"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin new.updated_at = now(); return new; end $$;


ALTER FUNCTION "public"."touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_user_keys_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end $$;


ALTER FUNCTION "public"."touch_user_keys_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_folder_share_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
    v_sharer_name TEXT;
    v_folder_name TEXT;
BEGIN
    -- Get sharer name
    SELECT email INTO v_sharer_name
    FROM auth.users
    WHERE id = NEW.shared_by
    LIMIT 1;
    
    -- Get folder name (if folders table exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'folders') THEN
        EXECUTE format('SELECT name FROM folders WHERE id = $1 LIMIT 1')
        INTO v_folder_name
        USING NEW.folder_id;
    END IF;
    
    -- Create notification for the recipient
    PERFORM create_notification_event(
        NEW.shared_with,
        'folder_shared',
        'share',
        jsonb_build_object(
            'share_id', NEW.id,
            'folder_id', NEW.folder_id,
            'sharer_id', NEW.shared_by,
            'sharer_name', COALESCE(v_sharer_name, 'Someone'),
            'folder_name', COALESCE(v_folder_name, 'a folder'),
            'permission', NEW.permission
        ),
        'high',
        now(),
        'folder_share_' || NEW.id::text
    );
    
    RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."trigger_folder_share_notification"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_folder_share_notification"() IS 'Create notification events for folder shares';



CREATE OR REPLACE FUNCTION "public"."trigger_notification_event"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
    v_event_type TEXT;
    v_event_source TEXT;
    v_payload JSONB;
    v_dedupe_key TEXT;
BEGIN
    -- Determine event details based on trigger source
    IF TG_TABLE_NAME = 'clipper_inbox' THEN
        v_user_id := NEW.user_id;
        v_event_source := NEW.source_type;
        
        IF NEW.source_type = 'email_in' THEN
            v_event_type := 'email_received';
            v_payload := jsonb_build_object(
                'inbox_id', NEW.id,
                'from', NEW.payload_json->>'from',
                'subject', NEW.payload_json->>'subject',
                'preview', LEFT(COALESCE(NEW.payload_json->>'text', ''), 100),
                'message_id', NEW.message_id
            );
            v_dedupe_key := 'email_' || NEW.message_id;
        ELSIF NEW.source_type = 'web' THEN
            v_event_type := 'web_clip_saved';
            v_payload := jsonb_build_object(
                'inbox_id', NEW.id,
                'title', NEW.payload_json->>'title',
                'url', NEW.payload_json->>'url',
                'clipped_at', NEW.payload_json->>'clipped_at'
            );
            v_dedupe_key := 'webclip_' || NEW.id::text;
        ELSE
            -- Unknown source type, skip
            RETURN NEW;
        END IF;
        
        -- Create the notification event
        PERFORM create_notification_event(
            v_user_id,
            v_event_type,
            v_event_source,
            v_payload,
            'normal',
            now(),
            v_dedupe_key
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_notification_event"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_notification_event"() IS 'Trigger function for automatic notifications';



CREATE OR REPLACE FUNCTION "public"."trigger_reminder_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    -- Only trigger for reminders that are due in the future
    IF NEW.reminder_time > now() THEN
        -- Create notification event scheduled for reminder time
        PERFORM create_notification_event(
            NEW.user_id,
            'reminder_due',
            'reminder',
            jsonb_build_object(
                'reminder_id', NEW.id,
                'note_id', NEW.note_id,
                'title', COALESCE(NEW.title, 'Reminder'),
                'message', NEW.message,
                'reminder_time', NEW.reminder_time
            ),
            'high',
            NEW.reminder_time,
            'reminder_' || NEW.id::text
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_reminder_notification"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_reminder_notification"() IS 'Create notification events for reminders';



CREATE OR REPLACE FUNCTION "public"."trigger_share_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
    v_sharer_name TEXT;
    v_note_title TEXT;
BEGIN
    -- Get sharer name (if available)
    SELECT email INTO v_sharer_name
    FROM auth.users
    WHERE id = NEW.shared_by
    LIMIT 1;
    
    -- Get note title (if notes table exists and has title)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notes') THEN
        EXECUTE format('SELECT title FROM notes WHERE id = $1 LIMIT 1')
        INTO v_note_title
        USING NEW.note_id;
    END IF;
    
    -- Create notification for the recipient
    PERFORM create_notification_event(
        NEW.shared_with,
        'note_shared',
        'share',
        jsonb_build_object(
            'share_id', NEW.id,
            'note_id', NEW.note_id,
            'sharer_id', NEW.shared_by,
            'sharer_name', COALESCE(v_sharer_name, 'Someone'),
            'note_title', COALESCE(v_note_title, 'a note'),
            'permission', NEW.permission
        ),
        'high',
        now(),
        'share_' || NEW.id::text
    );
    
    RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."trigger_share_notification"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_share_notification"() IS 'Create notification events for note shares';



CREATE OR REPLACE FUNCTION "public"."update_clipper_inbox_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_clipper_inbox_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_notification_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_notification_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_devices_upsert"("_device_id" "text", "_push_token" "text", "_platform" "text", "_app_version" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."user_devices_upsert"("_device_id" "text", "_push_token" "text", "_platform" "text", "_app_version" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."user_devices_upsert"("_device_id" "text", "_push_token" "text", "_platform" "text", "_app_version" "text") IS 'Upsert a device token for the authenticated user';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."attachments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "note_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "mime_type" "text",
    "size_bytes" integer,
    "ocr_text_enc" "bytea",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."attachments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clipper_inbox" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "source_type" "text" NOT NULL,
    "title" "text",
    "content" "text",
    "html" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "message_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "converted_to_note_id" "uuid",
    "converted_at" timestamp with time zone,
    "payload_json" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "clipper_inbox_source_type_check" CHECK (("source_type" = ANY (ARRAY['email_in'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."clipper_inbox" OWNER TO "postgres";


COMMENT ON TABLE "public"."clipper_inbox" IS 'Inbox for emails and web clips. Uses both individual columns (title, content, html) and payload_json for backward compatibility.';



COMMENT ON COLUMN "public"."clipper_inbox"."payload_json" IS 'Legacy column for backward compatibility. Automatically synced with title, content, html, and metadata columns.';



CREATE TABLE IF NOT EXISTS "public"."devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "model" "text",
    "app_version" "text",
    "registered_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_sync_at" timestamp with time zone
);


ALTER TABLE "public"."devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."folders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name_enc" "bytea" NOT NULL,
    "props_enc" "bytea" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "deleted" boolean DEFAULT false,
    CONSTRAINT "folders_user_id_check" CHECK (("user_id" IS NOT NULL))
);

ALTER TABLE ONLY "public"."folders" REPLICA IDENTITY FULL;


ALTER TABLE "public"."folders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inbound_aliases" (
    "user_id" "uuid" NOT NULL,
    "alias" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."inbound_aliases" OWNER TO "postgres";


COMMENT ON TABLE "public"."inbound_aliases" IS 'Maps unique inbound email alias -> user_id';



CREATE OR REPLACE VIEW "public"."inbox_items_view" AS
 SELECT "id",
    "user_id",
    "source_type",
    "title",
    "content",
    "html",
    "metadata",
    "message_id",
    "created_at",
    "updated_at",
    "converted_to_note_id",
    "converted_at",
        CASE
            WHEN ("converted_to_note_id" IS NOT NULL) THEN true
            ELSE false
        END AS "is_converted",
    COALESCE("title",
        CASE
            WHEN ("source_type" = 'email_in'::"text") THEN ('Email: '::"text" || COALESCE(("metadata" ->> 'from'::"text"), 'Unknown Sender'::"text"))
            WHEN ("source_type" = 'web'::"text") THEN ('Web: '::"text" || COALESCE(("metadata" ->> 'url'::"text"), 'Unknown URL'::"text"))
            ELSE 'Untitled'::"text"
        END) AS "display_title"
   FROM "public"."clipper_inbox" "ci";


ALTER VIEW "public"."inbox_items_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."login_attempts" (
    "id" bigint NOT NULL,
    "email" "text" NOT NULL,
    "success" boolean DEFAULT false NOT NULL,
    "error_message" "text",
    "attempt_time" timestamp with time zone DEFAULT "now"(),
    "ip_address" "text",
    "user_agent" "text"
);


ALTER TABLE "public"."login_attempts" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."login_attempts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."login_attempts_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."login_attempts_id_seq" OWNED BY "public"."login_attempts"."id";



CREATE TABLE IF NOT EXISTS "public"."note_blocks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "note_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "idx" numeric NOT NULL,
    "type" "text" NOT NULL,
    "content_enc" "bytea",
    "attrs_enc" "bytea",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."note_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."note_folders" (
    "note_id" "uuid" NOT NULL,
    "folder_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "added_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "note_folders_user_id_check" CHECK (("user_id" IS NOT NULL))
);

ALTER TABLE ONLY "public"."note_folders" REPLICA IDENTITY FULL;


ALTER TABLE "public"."note_folders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."note_tags" (
    "note_id" "uuid" NOT NULL,
    "tag_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "public"."note_tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title_enc" "bytea",
    "props_enc" "bytea",
    "deleted" boolean DEFAULT false NOT NULL,
    "encrypted_metadata" "text"
);

ALTER TABLE ONLY "public"."notes" REPLICA IDENTITY FULL;


ALTER TABLE "public"."notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_analytics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "date" "date" NOT NULL,
    "metrics" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_analytics" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."notification_cron_jobs" AS
 SELECT "jobname",
    "schedule",
    "command",
    "nodename",
    "nodeport",
    "database",
    "username",
    "active"
   FROM "cron"."job"
  WHERE (("jobname" ~~ '%notification%'::"text") OR ("jobname" ~~ '%cleanup%'::"text") OR ("jobname" ~~ '%retry%'::"text"))
  ORDER BY "jobname";


ALTER VIEW "public"."notification_cron_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_deliveries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "channel" "text" NOT NULL,
    "device_id" "text",
    "status" "text" NOT NULL,
    "provider_response" "jsonb",
    "provider_message_id" "text",
    "sent_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "delivered_at" timestamp with time zone,
    "opened_at" timestamp with time zone,
    "clicked_at" timestamp with time zone,
    "failed_at" timestamp with time zone,
    "error_code" "text",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_deliveries_channel_check" CHECK (("channel" = ANY (ARRAY['push'::"text", 'email'::"text", 'sms'::"text", 'in_app'::"text"]))),
    CONSTRAINT "notification_deliveries_status_check" CHECK (("status" = ANY (ARRAY['sent'::"text", 'delivered'::"text", 'failed'::"text", 'bounced'::"text", 'opened'::"text", 'clicked'::"text"])))
);


ALTER TABLE "public"."notification_deliveries" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_deliveries" IS 'Tracking and analytics for notification delivery';



CREATE TABLE IF NOT EXISTS "public"."notification_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "event_type" "text" NOT NULL,
    "event_source" "text" NOT NULL,
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "scheduled_for" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "retry_count" integer DEFAULT 0,
    "max_retries" integer DEFAULT 5,
    "dedupe_key" "text",
    "error_message" "text",
    "error_details" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_events_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'normal'::"text", 'high'::"text", 'critical'::"text"]))),
    CONSTRAINT "notification_events_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'delivered'::"text", 'failed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."notification_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_events" IS 'Central queue for all notification events';



CREATE TABLE IF NOT EXISTS "public"."notification_health_checks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "check_time" timestamp with time zone DEFAULT "now"() NOT NULL,
    "pending_count" integer,
    "processing_count" integer,
    "stuck_count" integer,
    "oldest_pending" timestamp with time zone,
    "is_healthy" boolean,
    "details" "jsonb"
);


ALTER TABLE "public"."notification_health_checks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_preferences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "enabled" boolean DEFAULT true,
    "push_enabled" boolean DEFAULT true,
    "email_enabled" boolean DEFAULT false,
    "sms_enabled" boolean DEFAULT false,
    "in_app_enabled" boolean DEFAULT true,
    "event_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "quiet_hours_enabled" boolean DEFAULT false,
    "quiet_hours_start" time without time zone,
    "quiet_hours_end" time without time zone,
    "timezone" "text" DEFAULT 'UTC'::"text",
    "dnd_enabled" boolean DEFAULT false,
    "dnd_until" timestamp with time zone,
    "batch_emails" boolean DEFAULT false,
    "batch_frequency" "text" DEFAULT 'daily'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_preferences_batch_frequency_check" CHECK (("batch_frequency" = ANY (ARRAY['realtime'::"text", 'hourly'::"text", 'daily'::"text", 'weekly'::"text"])))
);


ALTER TABLE "public"."notification_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_preferences" IS 'User preferences for notifications';



CREATE OR REPLACE VIEW "public"."notification_stats" AS
 SELECT "ne"."user_id",
    "ne"."event_type",
    "ne"."event_source",
    "date"("ne"."created_at") AS "date",
    "count"(DISTINCT "ne"."id") AS "events_created",
    "count"(DISTINCT
        CASE
            WHEN ("ne"."status" = 'delivered'::"text") THEN "ne"."id"
            ELSE NULL::"uuid"
        END) AS "events_delivered",
    "count"(DISTINCT
        CASE
            WHEN ("ne"."status" = 'failed'::"text") THEN "ne"."id"
            ELSE NULL::"uuid"
        END) AS "events_failed",
    "count"(DISTINCT "nd"."id") AS "deliveries_attempted",
    "count"(DISTINCT
        CASE
            WHEN ("nd"."status" = 'delivered'::"text") THEN "nd"."id"
            ELSE NULL::"uuid"
        END) AS "deliveries_successful",
    "avg"(EXTRACT(epoch FROM ("nd"."delivered_at" - "nd"."sent_at"))) AS "avg_delivery_time_seconds"
   FROM ("public"."notification_events" "ne"
     LEFT JOIN "public"."notification_deliveries" "nd" ON (("ne"."id" = "nd"."event_id")))
  GROUP BY "ne"."user_id", "ne"."event_type", "ne"."event_source", ("date"("ne"."created_at"));


ALTER VIEW "public"."notification_stats" OWNER TO "postgres";


COMMENT ON VIEW "public"."notification_stats" IS 'Analytics view for notification statistics';



CREATE TABLE IF NOT EXISTS "public"."notification_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_type" "text" NOT NULL,
    "push_template" "jsonb" DEFAULT '{}'::"jsonb",
    "email_template" "jsonb" DEFAULT '{}'::"jsonb",
    "sms_template" "jsonb" DEFAULT '{}'::"jsonb",
    "enabled" boolean DEFAULT true,
    "priority" "text" DEFAULT 'normal'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_templates" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_templates" IS 'Templates for different notification types';



CREATE TABLE IF NOT EXISTS "public"."password_history" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "password_hash" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."password_history" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."password_history_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."password_history_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."password_history_id_seq" OWNED BY "public"."password_history"."id";



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "settings" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name_enc" "bytea" NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "note_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "text_enc" "bytea" NOT NULL,
    "due_at_enc" "bytea",
    "repeat_enc" "bytea",
    "priority" smallint,
    "done" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "device_id" "text" NOT NULL,
    "push_token" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "app_version" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_devices_platform_check" CHECK (("platform" = ANY (ARRAY['ios'::"text", 'android'::"text", 'web'::"text", 'unknown'::"text"])))
);


ALTER TABLE "public"."user_devices" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_devices" IS 'Stores FCM push notification tokens for user devices';



COMMENT ON COLUMN "public"."user_devices"."user_id" IS 'Reference to the user who owns this device';



COMMENT ON COLUMN "public"."user_devices"."device_id" IS 'Unique identifier for the device (app-generated UUID)';



COMMENT ON COLUMN "public"."user_devices"."push_token" IS 'FCM registration token for push notifications';



COMMENT ON COLUMN "public"."user_devices"."platform" IS 'Device platform (ios, android, web, unknown)';



COMMENT ON COLUMN "public"."user_devices"."app_version" IS 'App version string (e.g., 1.0.0+1)';



CREATE TABLE IF NOT EXISTS "public"."user_keys" (
    "user_id" "uuid" NOT NULL,
    "kdf" "text" DEFAULT 'argon2id'::"text" NOT NULL,
    "kdf_params" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "wrapped_key" "text"
);


ALTER TABLE "public"."user_keys" OWNER TO "postgres";


ALTER TABLE ONLY "public"."login_attempts" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."login_attempts_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."password_history" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."password_history_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clipper_inbox"
    ADD CONSTRAINT "clipper_inbox_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."folders"
    ADD CONSTRAINT "folders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inbound_aliases"
    ADD CONSTRAINT "inbound_aliases_alias_key" UNIQUE ("alias");



ALTER TABLE ONLY "public"."inbound_aliases"
    ADD CONSTRAINT "inbound_aliases_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."login_attempts"
    ADD CONSTRAINT "login_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."note_blocks"
    ADD CONSTRAINT "note_blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."note_folders"
    ADD CONSTRAINT "note_folders_pkey" PRIMARY KEY ("note_id");



ALTER TABLE ONLY "public"."note_tags"
    ADD CONSTRAINT "note_tags_pkey" PRIMARY KEY ("note_id", "tag_id");



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_analytics"
    ADD CONSTRAINT "notification_analytics_date_key" UNIQUE ("date");



ALTER TABLE ONLY "public"."notification_analytics"
    ADD CONSTRAINT "notification_analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_deliveries"
    ADD CONSTRAINT "notification_deliveries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_events"
    ADD CONSTRAINT "notification_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_events"
    ADD CONSTRAINT "notification_events_user_id_dedupe_key_key" UNIQUE ("user_id", "dedupe_key");



ALTER TABLE ONLY "public"."notification_health_checks"
    ADD CONSTRAINT "notification_health_checks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."notification_templates"
    ADD CONSTRAINT "notification_templates_event_type_key" UNIQUE ("event_type");



ALTER TABLE ONLY "public"."notification_templates"
    ADD CONSTRAINT "notification_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."password_history"
    ADD CONSTRAINT "password_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_user_id_device_id_key" UNIQUE ("user_id", "device_id");



ALTER TABLE ONLY "public"."user_keys"
    ADD CONSTRAINT "user_keys_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "idx_clipper_inbox_converted" ON "public"."clipper_inbox" USING "btree" ("converted_to_note_id") WHERE ("converted_to_note_id" IS NOT NULL);



CREATE INDEX "idx_clipper_inbox_created_at" ON "public"."clipper_inbox" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_clipper_inbox_source_type" ON "public"."clipper_inbox" USING "btree" ("source_type");



CREATE INDEX "idx_clipper_inbox_user_id" ON "public"."clipper_inbox" USING "btree" ("user_id");



CREATE UNIQUE INDEX "idx_clipper_inbox_user_message_id" ON "public"."clipper_inbox" USING "btree" ("user_id", "message_id") WHERE ("message_id" IS NOT NULL);



CREATE INDEX "idx_folders_updated_at" ON "public"."folders" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_folders_user_deleted" ON "public"."folders" USING "btree" ("user_id", "deleted");



CREATE INDEX "idx_folders_user_id" ON "public"."folders" USING "btree" ("user_id");



CREATE INDEX "idx_inbound_aliases_alias" ON "public"."inbound_aliases" USING "btree" ("alias");



CREATE INDEX "idx_login_attempts_email" ON "public"."login_attempts" USING "btree" ("email");



CREATE INDEX "idx_login_attempts_email_time" ON "public"."login_attempts" USING "btree" ("email", "attempt_time");



CREATE INDEX "idx_login_attempts_time" ON "public"."login_attempts" USING "btree" ("attempt_time");



CREATE INDEX "idx_note_folders_folder_id" ON "public"."note_folders" USING "btree" ("folder_id");



CREATE INDEX "idx_note_folders_folder_note" ON "public"."note_folders" USING "btree" ("folder_id", "note_id");



CREATE INDEX "idx_note_folders_user_id" ON "public"."note_folders" USING "btree" ("user_id");



CREATE INDEX "idx_notes_updated_at" ON "public"."notes" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_notes_user_deleted" ON "public"."notes" USING "btree" ("user_id", "deleted");



CREATE INDEX "idx_notes_user_updated" ON "public"."notes" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "idx_notification_deliveries_event_id" ON "public"."notification_deliveries" USING "btree" ("event_id");



CREATE INDEX "idx_notification_deliveries_sent_at" ON "public"."notification_deliveries" USING "btree" ("sent_at");



CREATE INDEX "idx_notification_deliveries_user_channel" ON "public"."notification_deliveries" USING "btree" ("user_id", "channel");



CREATE INDEX "idx_notification_events_created_at" ON "public"."notification_events" USING "btree" ("created_at");



CREATE INDEX "idx_notification_events_created_status" ON "public"."notification_events" USING "btree" ("created_at", "status");



CREATE INDEX "idx_notification_events_dedupe" ON "public"."notification_events" USING "btree" ("user_id", "dedupe_key") WHERE ("dedupe_key" IS NOT NULL);



CREATE INDEX "idx_notification_events_processing" ON "public"."notification_events" USING "btree" ("status", "scheduled_for", "priority" DESC) WHERE ("status" = ANY (ARRAY['pending'::"text", 'processing'::"text"]));



CREATE INDEX "idx_notification_events_status_scheduled" ON "public"."notification_events" USING "btree" ("status", "scheduled_for") WHERE ("status" = ANY (ARRAY['pending'::"text", 'processing'::"text"]));



CREATE INDEX "idx_notification_events_user_id" ON "public"."notification_events" USING "btree" ("user_id");



CREATE INDEX "idx_notification_events_user_status" ON "public"."notification_events" USING "btree" ("user_id", "status", "created_at" DESC);



CREATE INDEX "idx_notification_preferences_user_id" ON "public"."notification_preferences" USING "btree" ("user_id");



CREATE INDEX "idx_user_devices_updated_at" ON "public"."user_devices" USING "btree" ("updated_at");



CREATE INDEX "idx_user_devices_user_id" ON "public"."user_devices" USING "btree" ("user_id");



CREATE INDEX "idx_user_keys_updated_at" ON "public"."user_keys" USING "btree" ("updated_at" DESC);



CREATE OR REPLACE TRIGGER "attachments_set_user" BEFORE INSERT ON "public"."attachments" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_user_id"();



CREATE OR REPLACE TRIGGER "blocks_set_user" BEFORE INSERT ON "public"."note_blocks" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_user_id"();



CREATE OR REPLACE TRIGGER "blocks_updated_at" BEFORE UPDATE ON "public"."note_blocks" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "note_tags_set_user" BEFORE INSERT ON "public"."note_tags" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_user_id"();



CREATE OR REPLACE TRIGGER "notes_set_user" BEFORE INSERT ON "public"."notes" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_user_id"();



CREATE OR REPLACE TRIGGER "notes_updated_at" BEFORE UPDATE ON "public"."notes" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "sync_clipper_inbox_payload_json_trigger" BEFORE INSERT OR UPDATE ON "public"."clipper_inbox" FOR EACH ROW EXECUTE FUNCTION "public"."sync_clipper_inbox_payload_json"();



CREATE OR REPLACE TRIGGER "tags_set_user" BEFORE INSERT ON "public"."tags" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_user_id"();



CREATE OR REPLACE TRIGGER "tasks_set_user" BEFORE INSERT ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_user_id"();



CREATE OR REPLACE TRIGGER "tasks_updated_at" BEFORE UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_touch_user_keys_updated_at" BEFORE UPDATE ON "public"."user_keys" FOR EACH ROW EXECUTE FUNCTION "public"."touch_user_keys_updated_at"();



CREATE OR REPLACE TRIGGER "update_clipper_inbox_updated_at" BEFORE UPDATE ON "public"."clipper_inbox" FOR EACH ROW EXECUTE FUNCTION "public"."update_clipper_inbox_updated_at"();



CREATE OR REPLACE TRIGGER "update_folders_updated_at" BEFORE UPDATE ON "public"."folders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_inbound_aliases_updated_at" BEFORE UPDATE ON "public"."inbound_aliases" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_notification_events_updated_at" BEFORE UPDATE ON "public"."notification_events" FOR EACH ROW EXECUTE FUNCTION "public"."update_notification_updated_at"();



CREATE OR REPLACE TRIGGER "update_notification_preferences_updated_at" BEFORE UPDATE ON "public"."notification_preferences" FOR EACH ROW EXECUTE FUNCTION "public"."update_notification_updated_at"();



CREATE OR REPLACE TRIGGER "update_notification_templates_updated_at" BEFORE UPDATE ON "public"."notification_templates" FOR EACH ROW EXECUTE FUNCTION "public"."update_notification_updated_at"();



CREATE OR REPLACE TRIGGER "update_user_devices_updated_at" BEFORE UPDATE ON "public"."user_devices" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clipper_inbox"
    ADD CONSTRAINT "clipper_inbox_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."folders"
    ADD CONSTRAINT "folders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inbound_aliases"
    ADD CONSTRAINT "inbound_aliases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_blocks"
    ADD CONSTRAINT "note_blocks_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_blocks"
    ADD CONSTRAINT "note_blocks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_folders"
    ADD CONSTRAINT "note_folders_folder_id_fkey" FOREIGN KEY ("folder_id") REFERENCES "public"."folders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_folders"
    ADD CONSTRAINT "note_folders_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_folders"
    ADD CONSTRAINT "note_folders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_tags"
    ADD CONSTRAINT "note_tags_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_tags"
    ADD CONSTRAINT "note_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_tags"
    ADD CONSTRAINT "note_tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_deliveries"
    ADD CONSTRAINT "notification_deliveries_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."notification_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_deliveries"
    ADD CONSTRAINT "notification_deliveries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_events"
    ADD CONSTRAINT "notification_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."password_history"
    ADD CONSTRAINT "password_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_keys"
    ADD CONSTRAINT "user_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Anyone can view notification templates" ON "public"."notification_templates" FOR SELECT USING (true);



CREATE POLICY "Service role access only" ON "public"."login_attempts" USING (false);



CREATE POLICY "Service role can insert inbox items" ON "public"."clipper_inbox" FOR INSERT WITH CHECK (true);



CREATE POLICY "Service role can manage all deliveries" ON "public"."notification_deliveries" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can manage all notification events" ON "public"."notification_events" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can manage all preferences" ON "public"."notification_preferences" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can manage notification templates" ON "public"."notification_templates" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Users can access their own password history" ON "public"."password_history" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own folders" ON "public"."folders" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own inbox items" ON "public"."clipper_inbox" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own note-folder relationships" ON "public"."note_folders" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own devices" ON "public"."user_devices" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own folders" ON "public"."folders" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own note-folder relationships" ON "public"."note_folders" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own preferences" ON "public"."notification_preferences" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can manage their own user_keys" ON "public"."user_keys" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own folders" ON "public"."folders" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own inbox items" ON "public"."clipper_inbox" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own note-folder relationships" ON "public"."note_folders" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own devices" ON "public"."user_devices" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update their own preferences" ON "public"."notification_preferences" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view own folders" ON "public"."folders" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own inbox items" ON "public"."clipper_inbox" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own note-folder relationships" ON "public"."note_folders" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own deliveries" ON "public"."notification_deliveries" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view their own devices" ON "public"."user_devices" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view their own notification events" ON "public"."notification_events" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view their own preferences" ON "public"."notification_preferences" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."attachments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clipper_inbox" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."folders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "folders_del_own" ON "public"."folders" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "folders_delete_own" ON "public"."folders" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "folders_ins_own" ON "public"."folders" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "folders_insert_own" ON "public"."folders" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "folders_select_own" ON "public"."folders" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "folders_upd_own" ON "public"."folders" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "folders_update_own" ON "public"."folders" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."inbound_aliases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."login_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."note_blocks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."note_folders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "note_folders_del" ON "public"."note_folders" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "note_folders_delete_own" ON "public"."note_folders" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "note_folders_ins" ON "public"."note_folders" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "note_folders_insert_own" ON "public"."note_folders" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "note_folders_select" ON "public"."note_folders" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "note_folders_select_own" ON "public"."note_folders" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "note_folders_upd" ON "public"."note_folders" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "note_folders_update_own" ON "public"."note_folders" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."note_tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notes_del_own" ON "public"."notes" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notes_delete_own" ON "public"."notes" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "notes_ins_own" ON "public"."notes" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "notes_insert_own" ON "public"."notes" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "notes_select_own" ON "public"."notes" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "notes_upd_own" ON "public"."notes" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notes_update_own" ON "public"."notes" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."notification_deliveries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "owner_all_attachments" ON "public"."attachments" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_blocks" ON "public"."note_blocks" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_devices" ON "public"."devices" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_note_tags" ON "public"."note_tags" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_notes" ON "public"."notes" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_profiles" ON "public"."profiles" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_tags" ON "public"."tags" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "owner_all_tasks" ON "public"."tasks" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."password_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_keys" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_keys_delete_own" ON "public"."user_keys" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "user_keys_select_own" ON "public"."user_keys" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "user_keys_update_own" ON "public"."user_keys" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "user_keys_upsert_own" ON "public"."user_keys" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "users-can-view-own-alias" ON "public"."inbound_aliases" FOR SELECT USING (("auth"."uid"() = "user_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."folders";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."note_folders";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notes";



SET SESSION AUTHORIZATION "postgres";
RESET SESSION AUTHORIZATION;






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";














































































































































































GRANT ALL ON FUNCTION "public"."_policy_exists"("schemaname" "text", "tablename" "text", "policyname" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_policy_exists"("schemaname" "text", "tablename" "text", "policyname" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_policy_exists"("schemaname" "text", "tablename" "text", "policyname" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."claim_notification_events"("batch_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."claim_notification_events"("batch_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_notification_events"("batch_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_login_attempts"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_login_attempts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_login_attempts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_notifications"("p_days_old" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_notifications"("p_days_old" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_notifications"("p_days_old" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_stale_device_tokens"("p_days_old" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_stale_device_tokens"("p_days_old" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_stale_device_tokens"("p_days_old" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_notification_event"("p_user_id" "uuid", "p_event_type" "text", "p_event_source" "text", "p_payload" "jsonb", "p_priority" "text", "p_scheduled_for" timestamp with time zone, "p_dedupe_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_notification_event"("p_user_id" "uuid", "p_event_type" "text", "p_event_source" "text", "p_payload" "jsonb", "p_priority" "text", "p_scheduled_for" timestamp with time zone, "p_dedupe_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_notification_event"("p_user_id" "uuid", "p_event_type" "text", "p_event_source" "text", "p_payload" "jsonb", "p_priority" "text", "p_scheduled_for" timestamp with time zone, "p_dedupe_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."extract_message_id"("headers" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."extract_message_id"("headers" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."extract_message_id"("headers" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."generate_user_alias"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_user_alias"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_user_alias"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_user_alias"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_notification_metrics"("p_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_notification_metrics"("p_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_notification_metrics"("p_hours" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_device_tokens"("_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_device_tokens"("_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_device_tokens"("_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."manual_process_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."manual_process_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."manual_process_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."merge_duplicate_folders"("p_canonical_folder_id" "uuid", "p_duplicate_folder_ids" "uuid"[], "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."merge_duplicate_folders"("p_canonical_folder_id" "uuid", "p_duplicate_folder_ids" "uuid"[], "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."merge_duplicate_folders"("p_canonical_folder_id" "uuid", "p_duplicate_folder_ids" "uuid"[], "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."purge_stale_clipper_inbox"() TO "anon";
GRANT ALL ON FUNCTION "public"."purge_stale_clipper_inbox"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."purge_stale_clipper_inbox"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_auth_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_auth_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_auth_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_clipper_inbox_payload_json"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_clipper_inbox_payload_json"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_clipper_inbox_payload_json"() TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_user_keys_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_user_keys_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_user_keys_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_folder_share_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_folder_share_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_folder_share_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_notification_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_notification_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_notification_event"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_reminder_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_reminder_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_reminder_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_share_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_share_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_share_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_clipper_inbox_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_clipper_inbox_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_clipper_inbox_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_notification_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_notification_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_notification_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_devices_upsert"("_device_id" "text", "_push_token" "text", "_platform" "text", "_app_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."user_devices_upsert"("_device_id" "text", "_push_token" "text", "_platform" "text", "_app_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_devices_upsert"("_device_id" "text", "_push_token" "text", "_platform" "text", "_app_version" "text") TO "service_role";
























GRANT ALL ON TABLE "public"."attachments" TO "anon";
GRANT ALL ON TABLE "public"."attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."attachments" TO "service_role";



GRANT ALL ON TABLE "public"."clipper_inbox" TO "anon";
GRANT ALL ON TABLE "public"."clipper_inbox" TO "authenticated";
GRANT ALL ON TABLE "public"."clipper_inbox" TO "service_role";



GRANT ALL ON TABLE "public"."devices" TO "anon";
GRANT ALL ON TABLE "public"."devices" TO "authenticated";
GRANT ALL ON TABLE "public"."devices" TO "service_role";



GRANT ALL ON TABLE "public"."folders" TO "anon";
GRANT ALL ON TABLE "public"."folders" TO "authenticated";
GRANT ALL ON TABLE "public"."folders" TO "service_role";



GRANT ALL ON TABLE "public"."inbound_aliases" TO "anon";
GRANT ALL ON TABLE "public"."inbound_aliases" TO "authenticated";
GRANT ALL ON TABLE "public"."inbound_aliases" TO "service_role";



GRANT ALL ON TABLE "public"."inbox_items_view" TO "anon";
GRANT ALL ON TABLE "public"."inbox_items_view" TO "authenticated";
GRANT ALL ON TABLE "public"."inbox_items_view" TO "service_role";



GRANT ALL ON TABLE "public"."login_attempts" TO "anon";
GRANT ALL ON TABLE "public"."login_attempts" TO "authenticated";
GRANT ALL ON TABLE "public"."login_attempts" TO "service_role";



GRANT ALL ON SEQUENCE "public"."login_attempts_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."login_attempts_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."login_attempts_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."note_blocks" TO "anon";
GRANT ALL ON TABLE "public"."note_blocks" TO "authenticated";
GRANT ALL ON TABLE "public"."note_blocks" TO "service_role";



GRANT ALL ON TABLE "public"."note_folders" TO "anon";
GRANT ALL ON TABLE "public"."note_folders" TO "authenticated";
GRANT ALL ON TABLE "public"."note_folders" TO "service_role";



GRANT ALL ON TABLE "public"."note_tags" TO "anon";
GRANT ALL ON TABLE "public"."note_tags" TO "authenticated";
GRANT ALL ON TABLE "public"."note_tags" TO "service_role";



GRANT ALL ON TABLE "public"."notes" TO "anon";
GRANT ALL ON TABLE "public"."notes" TO "authenticated";
GRANT ALL ON TABLE "public"."notes" TO "service_role";



GRANT ALL ON TABLE "public"."notification_analytics" TO "anon";
GRANT ALL ON TABLE "public"."notification_analytics" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_analytics" TO "service_role";



GRANT ALL ON TABLE "public"."notification_cron_jobs" TO "anon";
GRANT ALL ON TABLE "public"."notification_cron_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_cron_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."notification_deliveries" TO "anon";
GRANT ALL ON TABLE "public"."notification_deliveries" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_deliveries" TO "service_role";



GRANT ALL ON TABLE "public"."notification_events" TO "anon";
GRANT ALL ON TABLE "public"."notification_events" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_events" TO "service_role";



GRANT ALL ON TABLE "public"."notification_health_checks" TO "anon";
GRANT ALL ON TABLE "public"."notification_health_checks" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_health_checks" TO "service_role";



GRANT ALL ON TABLE "public"."notification_preferences" TO "anon";
GRANT ALL ON TABLE "public"."notification_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."notification_stats" TO "anon";
GRANT ALL ON TABLE "public"."notification_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_stats" TO "service_role";



GRANT ALL ON TABLE "public"."notification_templates" TO "anon";
GRANT ALL ON TABLE "public"."notification_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_templates" TO "service_role";



GRANT ALL ON TABLE "public"."password_history" TO "anon";
GRANT ALL ON TABLE "public"."password_history" TO "authenticated";
GRANT ALL ON TABLE "public"."password_history" TO "service_role";



GRANT ALL ON SEQUENCE "public"."password_history_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."password_history_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."password_history_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."tags" TO "anon";
GRANT ALL ON TABLE "public"."tags" TO "authenticated";
GRANT ALL ON TABLE "public"."tags" TO "service_role";



GRANT ALL ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks" TO "service_role";



GRANT ALL ON TABLE "public"."user_devices" TO "anon";
GRANT ALL ON TABLE "public"."user_devices" TO "authenticated";
GRANT ALL ON TABLE "public"."user_devices" TO "service_role";



GRANT ALL ON TABLE "public"."user_keys" TO "anon";
GRANT ALL ON TABLE "public"."user_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."user_keys" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
