CREATE OR REPLACE FUNCTION public.update_inbox_attachments(
  inbox_id uuid,
  attachment_data jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payload jsonb := COALESCE(attachment_data, '{"files": [], "count": 0}'::jsonb);
BEGIN
  UPDATE public.clipper_inbox
  SET payload_json = jsonb_set(
        COALESCE(payload_json, '{}'::jsonb),
        ARRAY['attachments'],
        v_payload,
        true
      ),
      metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        ARRAY['attachments'],
        v_payload,
        true
      ),
      updated_at = timezone('utc', now())
  WHERE id = inbox_id;
END;
$$;
