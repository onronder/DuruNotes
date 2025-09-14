Dumping schemas from remote database...


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
