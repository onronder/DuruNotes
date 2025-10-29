# Supabase Edge Functions Checklist

Use this checklist to redeploy the edge-function suite after the baseline migration. Cross-check the function inventory with `supabase/functions/` and confirm required environment variables exist in the Supabase dashboard (`Settings → API → Edge Functions Secrets`). The helper script `scripts/deploy_supabase_functions.sh` deploys all functions in the order listed below (pass additional CLI flags as needed).

| Function | Purpose | Key Dependencies | Required Env Vars | Deployment Command |
|----------|---------|------------------|-------------------|--------------------|
| `send-push-notification` | Primary push dispatcher for batching FCM sends | Tables: `notification_events`, `notification_deliveries` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVICE_ACCOUNT_KEY` | `supabase functions deploy send-push-notification` |
| `send-push-notification-v1` | Legacy push handler invoked by newer pipeline for backwards compatibility | Tables: `notification_events`; RPCs: `should_send_notification` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVICE_ACCOUNT_KEY` | `supabase functions deploy send-push-notification-v1` |
| `process-notification-queue` | Orchestrates push batch processing, cleanup, and retries | Tables: `notification_events`; Function call to `send-push-notification-v1` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` | `supabase functions deploy process-notification-queue` |
| `process-fcm-notifications` | Post-processes FCM responses (delivery receipts, retry handling) | Tables: `notification_events`, `notification_deliveries` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVICE_ACCOUNT_KEY` | `supabase functions deploy process-fcm-notifications` |
| `fcm-notification-v2` | Expanded FCM handler with webhook + project analytics hooks | Tables: `notification_events` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVICE_ACCOUNT_KEY`, optional `WEBHOOK_SECRET` | `supabase functions deploy fcm-notification-v2` |
| `setup-push-cron` | Configures Supabase cron to trigger queue processors | RPCs: cron internal APIs | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | `supabase functions deploy setup-push-cron` |
| `remove-cron-spam` | One-off cleanup to remove duplicate cron jobs | Supabase cron metadata | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | `supabase functions deploy remove-cron-spam` |
| `email-inbox` | Legacy inbound email endpoint kept for compatibility | Tables: `clipper_inbox`, `inbound-attachments`; RPC: `update_inbox_attachments` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `INBOUND_PARSE_SECRET`, `INBOUND_HMAC_SECRET`, optional `ALLOWED_ORIGIN` | `supabase functions deploy email-inbox` |
| `inbound-web` | Web clipper ingest endpoint (public) | Tables: `clipper_inbox`, `notification_events` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `INBOUND_PARSE_SECRET`, `SUPABASE_ANON_KEY` | `supabase functions deploy inbound-web` |
| `inbound-web-auth` | Authenticated variant of web clipper endpoint | Tables: `clipper_inbox` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` | `supabase functions deploy inbound-web-auth` |
| `test-fcm-simple` | Simple diagnostic FCM send for manual testing | FCM only | `FCM_SERVICE_ACCOUNT_KEY` | `supabase functions deploy test-fcm-simple` |

**Operational Notes**
- Deploy functions in the order shown above so shared dependencies (push handlers before queue processors) are ready when cron jobs trigger.
- After deploying, verify cron schedules via `supabase functions secrets list` and the Supabase dashboard.
- Update `docs/SUPABASE_RUNBOOK.md` with any deviations from this checklist (e.g., if a function is deprecated and no longer deployed).
- Legacy duplicate `email_inbox` (underscore variant) has been removed; use the remaining endpoints only.
