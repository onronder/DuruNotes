#!/usr/bin/env bash
#
# Deploy Supabase edge functions in the documented order.
# Usage:
#   scripts/deploy_supabase_functions.sh [additional supabase args...]
#
# Example (after supabase link):
#   scripts/deploy_supabase_functions.sh --project-ref mizzxiijxtbwrqgflpnp

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Error: supabase CLI not found in PATH. Install it before running this script." >&2
  exit 1
fi

functions=(
  send-push-notification
  send-push-notification-v1
  process-notification-queue
  process-fcm-notifications
  fcm-notification-v2
  setup-push-cron
  remove-cron-spam
  email-inbox
  inbound-web
  inbound-web-auth
  test-fcm-simple
)

for fn in "${functions[@]}"; do
  echo "Deploying function: $fn"
  supabase functions deploy "$fn" "$@"
done

echo "All functions deployed."
