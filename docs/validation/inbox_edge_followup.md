# Inbox Flow Follow-Up (Pre-Restart)

## Current Status
- Email arrives in Supabase `clipper_inbox` and appears in the app inbox.
- Attachments do not surface in the UI; note conversion completes toast but the new note is absent.
- No Supabase edge-function logs observed for inbound email during the latest run.

## Outstanding Actions
1. Redeploy the `email-inbox` edge function so the updated TypeScript (with `update_inbox_attachments`) runs in production.
   ```bash
   supabase functions deploy email-inbox --project-ref mizzxiijxtbwrqgflpnp
   supabase functions logs email-inbox --since 15m
   ```
2. After redeploy, resend a test email and verify `clipper_inbox.payload_json -> 'attachments'` populates with `{ files: [...], count: n }`.
3. Convert the new inbox item to a note while watching Flutter logs for:
   - `Converted email … to note …` (success path)
   - `⚠️ [Debug] Attachment processing SKIPPED` (payload missing) or any errors.
4. If the note still fails to appear, run `scripts/test_inbox_flow.sql` (with real `USER_ID`) to exercise the full flow via SQL and review output, then re-check the app.

## Next Session Reminder
- Start by redeploying `email-inbox`, confirm payload JSON, then retry conversion with logging enabled.
- Bring any edge-function or Flutter errors from that run for debugging.***
