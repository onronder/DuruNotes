#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "$1"; }

log "🔍 Supabase Remote Schema Verification"
log "======================================\n"

if ! command -v supabase >/dev/null 2>&1; then
  log "${RED}❌ Supabase CLI not found${NC}"
  exit 1
fi
log "${GREEN}✓ Supabase CLI found${NC}"

if [[ ! -f .supabase/config.toml && ! -f supabase/config.toml ]]; then
  log "${YELLOW}⚠️  Project not linked${NC}"
  log "Run: supabase link --project-ref <PROJECT_REF>"
  exit 1
fi
log "${GREEN}✓ Project linked${NC}\n"

TMP_SCHEMA=$(mktemp -t supabase_schema.XXXX.sql)
trap 'rm -f "$TMP_SCHEMA"' EXIT

log "📥 Dumping remote schema (public)..."
if ! supabase db dump --schema public --linked --file "$TMP_SCHEMA" >/dev/null; then
  log "${RED}❌ Failed to dump schema${NC}"
  exit 1
fi
log "${GREEN}✓ Schema dump saved to $TMP_SCHEMA${NC}\n"

check_table() {
  local table=$1
  if grep -q "CREATE TABLE IF NOT EXISTS \"public\".\"${table}\"" "$TMP_SCHEMA"; then
    log "${GREEN}✓ Table '${table}' present${NC}"
  else
    log "${RED}❌ Table '${table}' missing${NC}"
  fi
}

log "📋 Core table presence"
for tbl in notes note_tasks note_folders note_tags folders reminders; do
  check_table "$tbl"
done
log ""

log "🔐 RLS enablement"
for tbl in notes note_tasks note_folders note_tags folders reminders; do
  if grep -q "ALTER TABLE \"public\".\"${tbl}\" ENABLE ROW LEVEL SECURITY" "$TMP_SCHEMA"; then
    log "${GREEN}✓ ${tbl}: RLS enabled${NC}"
  else
    log "${RED}❌ ${tbl}: RLS not enabled${NC}"
  fi
  if grep -q "CREATE POLICY \".*\" ON \"public\".\"${tbl}\"" "$TMP_SCHEMA"; then
    log "   ↳ policy entries detected"
  else
    log "${YELLOW}   ↳ no policies found (check manually)${NC}"
  fi
done
log ""

log "⚙️  Critical columns"
if grep -Fq '"metadata" "jsonb" DEFAULT '\''{}'\''::"jsonb" NOT NULL' "$TMP_SCHEMA"; then
  log "${GREEN}✓ reminders.metadata is jsonb NOT NULL with default${NC}"
else
  log "${RED}❌ reminders.metadata missing or incorrect${NC}"
fi
if grep -Fq '"labels" "jsonb" DEFAULT '\''[]'\''::"jsonb" NOT NULL' "$TMP_SCHEMA"; then
  log "${GREEN}✓ note_tasks.labels is jsonb NOT NULL with default${NC}"
else
  log "${RED}❌ note_tasks.labels missing or incorrect${NC}"
fi
log ""

log "🚀 Performance indexes"
for idx in notes_user_updated_idx note_tasks_user_updated_idx note_tasks_note_idx note_folders_folder_updated note_tags_batch_load_idx reminders_active_idx reminders_user_note_idx folders_user_updated_idx; do
  if grep -q "CREATE INDEX \"${idx}\"" "$TMP_SCHEMA"; then
    log "${GREEN}✓ ${idx}${NC}"
  else
    log "${YELLOW}⚠️  ${idx} not found${NC}"
  fi
done
log ""

log "✅ Verification complete"
log "Remove temporary dump if not needed: $TMP_SCHEMA"
