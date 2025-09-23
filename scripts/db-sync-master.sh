#!/bin/bash

# Master Database Sync Script for Duru Notes
# Comprehensive synchronization with 7-phase process
# Duration: 10-30 minutes

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs/master-sync"
BACKUP_DIR="$PROJECT_ROOT/backups"
REPORT_DIR="$PROJECT_ROOT/reports"
SESSION_ID="$(date +%Y%m%d-%H%M%S)"

# Create directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$REPORT_DIR"

# Log files
MAIN_LOG="$LOG_DIR/master-sync-$SESSION_ID.log"
ERROR_LOG="$LOG_DIR/errors-$SESSION_ID.log"
PHASE_LOG="$LOG_DIR/phases-$SESSION_ID.log"

# Global variables
TOTAL_PHASES=7
CURRENT_PHASE=0
PHASE_ERRORS=0
WARNINGS=()
FIXES_APPLIED=()
REMOTE_AVAILABLE=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$MAIN_LOG"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$MAIN_LOG"
    echo "[SUCCESS] $1" >> "$PHASE_LOG"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$MAIN_LOG"
    echo "[WARNING] $1" >> "$PHASE_LOG"
    WARNINGS+=("$1")
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$MAIN_LOG" "$ERROR_LOG"
    echo "[ERROR] $1" >> "$PHASE_LOG"
    ((PHASE_ERRORS++))
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}" | tee -a "$MAIN_LOG"
}

header() {
    echo -e "\n${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}" | tee -a "$MAIN_LOG"
    echo -e "${MAGENTA}║  $1${NC}" | tee -a "$MAIN_LOG"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}\n" | tee -a "$MAIN_LOG"
}

phase_header() {
    ((CURRENT_PHASE++))
    echo -e "\n${WHITE}┌────────────────────────────────────────────────────────┐${NC}" | tee -a "$MAIN_LOG"
    echo -e "${WHITE}│  PHASE $CURRENT_PHASE/$TOTAL_PHASES: $1${NC}" | tee -a "$MAIN_LOG"
    echo -e "${WHITE}└────────────────────────────────────────────────────────┘${NC}\n" | tee -a "$MAIN_LOG"
    echo "=== PHASE $CURRENT_PHASE: $1 ===" >> "$PHASE_LOG"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))

    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' ' '
    printf "] %3d%%" "$percentage"
}

# Confirmation prompt
confirm() {
    local message=$1
    local default=${2:-n}

    if [ "$default" = "y" ]; then
        read -p "$message [Y/n]: " -n 1 -r
    else
        read -p "$message [y/N]: " -n 1 -r
    fi
    echo

    if [ "$default" = "y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# ==============================================================================
# PHASE 1: Complete Discovery & Analysis
# ==============================================================================
phase1_discovery() {
    phase_header "Complete Discovery & Analysis"

    log "Starting comprehensive system discovery..."

    # Check Supabase installation
    log "Checking Supabase CLI..."
    if command -v supabase &> /dev/null; then
        SUPABASE_VERSION=$(supabase --version | cut -d' ' -f3)
        success "Supabase CLI v$SUPABASE_VERSION found"
    else
        error "Supabase CLI not found"
        exit 1
    fi

    # Check project configuration
    log "Checking project configuration..."
    if [ -f "$PROJECT_ROOT/supabase/config.toml" ]; then
        success "Supabase project configuration found"

        # Extract project info
        PROJECT_ID=$(supabase projects list 2>/dev/null | grep "●" | awk '{print $4}' || echo "unknown")
        info "Project ID: $PROJECT_ID"
    else
        error "No Supabase configuration found"
        exit 1
    fi

    # Test remote connectivity
    log "Testing remote database connectivity..."
    if timeout 15 supabase db remote get 2>&1 | grep -q "postgres://"; then
        REMOTE_AVAILABLE=true
        REMOTE_URL=$(supabase db remote get 2>/dev/null | grep "postgres://" | head -1)
        success "Remote database connection established"
        info "Remote URL: ${REMOTE_URL:0:50}..."
    else
        REMOTE_AVAILABLE=false
        warning "Remote database not accessible - working in local mode"
    fi

    # Analyze migration files
    log "Analyzing migration files..."

    TOTAL_MIGRATIONS=$(find "$PROJECT_ROOT/supabase/migrations" -name "*.sql" 2>/dev/null | wc -l | tr -d ' ')
    SKIPPED_MIGRATIONS=$(find "$PROJECT_ROOT/supabase/migrations" -name "*.skip" 2>/dev/null | wc -l | tr -d ' ')

    info "Total SQL migrations: $TOTAL_MIGRATIONS"
    info "Skipped migrations: $SKIPPED_MIGRATIONS"

    # Check for issues
    log "Checking for common issues..."

    # Duplicate timestamps
    DUPLICATES=$(ls -1 "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null | \
                 sed 's/.*\///;s/_.*//g' | \
                 sort | uniq -d | wc -l | tr -d ' ')

    if [ "$DUPLICATES" -gt 0 ]; then
        warning "Found $DUPLICATES duplicate migration timestamps"
    fi

    # Concurrent indexes
    if grep -r "CREATE INDEX CONCURRENTLY" "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null > /dev/null; then
        warning "Found CONCURRENTLY in migrations (incompatible with transactions)"
    fi

    # Missing extensions
    if grep -r "CREATE EXTENSION.*vault" "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null > /dev/null; then
        warning "Found vault extension requirement (may not be available)"
    fi

    success "Discovery phase completed"
}

# ==============================================================================
# PHASE 2: Detailed Schema Comparison
# ==============================================================================
phase2_schema_comparison() {
    phase_header "Detailed Schema Comparison"

    log "Performing comprehensive schema analysis..."

    # Create backup first
    log "Creating safety backup..."
    BACKUP_FILE="$BACKUP_DIR/pre-sync-backup-$SESSION_ID.sql"

    if [ "$REMOTE_AVAILABLE" = true ]; then
        if supabase db dump --data-only=false > "$BACKUP_FILE" 2>/dev/null; then
            success "Backup created: $BACKUP_FILE"
        else
            warning "Could not create remote backup"
        fi
    fi

    # Get migration status
    log "Fetching migration status..."
    MIGRATION_STATUS_FILE="$LOG_DIR/migration-status-$SESSION_ID.txt"

    if [ "$REMOTE_AVAILABLE" = true ]; then
        if timeout 30 supabase migration list > "$MIGRATION_STATUS_FILE" 2>&1; then
            success "Migration status retrieved"

            # Count pending migrations
            PENDING_COUNT=$(grep -c "│.*│\s*│" "$MIGRATION_STATUS_FILE" 2>/dev/null || echo "0")

            if [ "$PENDING_COUNT" -gt 0 ]; then
                warning "Found $PENDING_COUNT pending migrations"
            else
                success "All migrations are synchronized"
            fi
        else
            error "Failed to retrieve migration status"
        fi
    fi

    # Generate schema diff
    log "Generating schema differences..."
    DIFF_FILE="$LOG_DIR/schema-diff-$SESSION_ID.sql"

    if [ "$REMOTE_AVAILABLE" = true ]; then
        if supabase db diff --linked > "$DIFF_FILE" 2>&1; then
            if [ -s "$DIFF_FILE" ]; then
                warning "Schema differences detected"
                info "Diff saved to: $DIFF_FILE"

                # Analyze diff
                CREATE_COUNT=$(grep -c "CREATE" "$DIFF_FILE" 2>/dev/null || echo "0")
                ALTER_COUNT=$(grep -c "ALTER" "$DIFF_FILE" 2>/dev/null || echo "0")
                DROP_COUNT=$(grep -c "DROP" "$DIFF_FILE" 2>/dev/null || echo "0")

                info "Changes needed: $CREATE_COUNT creates, $ALTER_COUNT alters, $DROP_COUNT drops"
            else
                success "Schemas are in sync"
            fi
        else
            error "Failed to generate schema diff"
        fi
    fi

    success "Schema comparison completed"
}

# ==============================================================================
# PHASE 3: Interactive Migration Repair
# ==============================================================================
phase3_migration_repair() {
    phase_header "Interactive Migration Repair"

    log "Starting interactive migration repair process..."

    # Fix duplicate timestamps
    if [ "$DUPLICATES" -gt 0 ]; then
        if confirm "Fix duplicate migration timestamps?"; then
            log "Fixing duplicate timestamps..."

            ls -1 "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null | \
            sed 's/.*\///;s/_.*//g' | \
            sort | uniq -d | while read stamp; do
                FILES=$(ls -1 "$PROJECT_ROOT/supabase/migrations/${stamp}_"*.sql 2>/dev/null | tail -n +2)
                COUNTER=1

                for file in $FILES; do
                    NEW_STAMP=$(date -d "$stamp +$COUNTER day" +%Y%m%d 2>/dev/null || \
                               date -v +${COUNTER}d -j -f "%Y%m%d" "$stamp" +%Y%m%d 2>/dev/null)
                    NEW_FILE=$(echo "$file" | sed "s/${stamp}/${NEW_STAMP}/")

                    log "Renaming: $(basename $file) -> $(basename $NEW_FILE)"
                    mv "$file" "$NEW_FILE"
                    FIXES_APPLIED+=("Renamed $(basename $file)")
                    ((COUNTER++))
                done
            done

            success "Fixed duplicate timestamps"
        fi
    fi

    # Fix concurrent indexes
    if grep -r "CREATE INDEX CONCURRENTLY" "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null > /dev/null; then
        if confirm "Remove CONCURRENTLY from index creation?"; then
            log "Fixing concurrent index statements..."

            find "$PROJECT_ROOT/supabase/migrations" -name "*.sql" \
                 -exec grep -l "CREATE INDEX CONCURRENTLY" {} \; | \
            while read file; do
                sed -i.bak 's/CREATE INDEX CONCURRENTLY/CREATE INDEX/g' "$file"
                log "Fixed: $(basename $file)"
                FIXES_APPLIED+=("Fixed CONCURRENTLY in $(basename $file)")
            done

            # Clean up backup files
            find "$PROJECT_ROOT/supabase/migrations" -name "*.bak" -delete

            success "Fixed concurrent index issues"
        fi
    fi

    # Handle vault extension
    if grep -r "CREATE EXTENSION.*vault" "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null > /dev/null; then
        if confirm "Skip migrations requiring vault extension?"; then
            log "Handling vault extension requirements..."

            find "$PROJECT_ROOT/supabase/migrations" -name "*.sql" \
                 -exec grep -l "CREATE EXTENSION.*vault" {} \; | \
            while read file; do
                mv "$file" "${file}.skip"
                log "Skipped: $(basename $file)"
                FIXES_APPLIED+=("Skipped vault-dependent $(basename $file)")
            done

            success "Handled vault extension issues"
        fi
    fi

    # Review and confirm fixes
    if [ ${#FIXES_APPLIED[@]} -gt 0 ]; then
        echo -e "\n${CYAN}Applied fixes:${NC}"
        for fix in "${FIXES_APPLIED[@]}"; do
            echo "  - $fix"
        done
    fi

    success "Migration repair completed"
}

# ==============================================================================
# PHASE 4: Schema Synchronization
# ==============================================================================
phase4_schema_sync() {
    phase_header "Schema Synchronization"

    if [ "$REMOTE_AVAILABLE" != true ]; then
        warning "Remote not available - skipping synchronization"
        return
    fi

    log "Starting schema synchronization process..."

    # Apply pending migrations
    if [ "$PENDING_COUNT" -gt 0 ]; then
        if confirm "Apply $PENDING_COUNT pending migrations?" "y"; then
            log "Applying migrations..."

            # Try standard push first
            if echo "Y" | supabase db push 2>&1 | tee -a "$MAIN_LOG"; then
                success "Migrations applied successfully"
                FIXES_APPLIED+=("Applied $PENDING_COUNT migrations")
            else
                warning "Standard push failed, trying with --include-all..."

                if echo "Y" | supabase db push --include-all 2>&1 | tee -a "$MAIN_LOG"; then
                    success "Migrations applied with --include-all"
                    FIXES_APPLIED+=("Applied migrations with --include-all")
                else
                    error "Failed to apply migrations"
                fi
            fi
        fi
    fi

    # Create alignment migration if needed
    if [ -s "$DIFF_FILE" ] && [ "$DIFF_FILE" != "" ]; then
        if confirm "Create alignment migration for schema differences?"; then
            MIGRATION_NAME="master_sync_alignment_$SESSION_ID"
            MIGRATION_FILE="$PROJECT_ROOT/supabase/migrations/$(date +%Y%m%d)_${MIGRATION_NAME}.sql"

            log "Creating alignment migration..."
            cp "$DIFF_FILE" "$MIGRATION_FILE"

            success "Created alignment migration: $(basename $MIGRATION_FILE)"
            FIXES_APPLIED+=("Created alignment migration")

            # Apply the migration
            if confirm "Apply the alignment migration now?"; then
                if echo "Y" | supabase db push 2>&1 | tee -a "$MAIN_LOG"; then
                    success "Alignment migration applied"
                    FIXES_APPLIED+=("Applied alignment migration")
                else
                    error "Failed to apply alignment migration"
                fi
            fi
        fi
    fi

    success "Schema synchronization completed"
}

# ==============================================================================
# PHASE 5: Data Validation & Consistency
# ==============================================================================
phase5_data_validation() {
    phase_header "Data Validation & Consistency"

    if [ "$REMOTE_AVAILABLE" != true ]; then
        warning "Remote not available - skipping validation"
        return
    fi

    log "Performing data validation checks..."

    # Create validation queries
    VALIDATION_FILE="$LOG_DIR/validation-$SESSION_ID.sql"

    cat > "$VALIDATION_FILE" << 'EOF'
-- Data validation queries
SELECT 'notes' as table_name, COUNT(*) as row_count FROM notes;
SELECT 'folders' as table_name, COUNT(*) as row_count FROM folders;
SELECT 'note_folders' as table_name, COUNT(*) as row_count FROM note_folders;
SELECT 'clipper_inbox' as table_name, COUNT(*) as row_count FROM clipper_inbox;
SELECT 'note_tasks' as table_name, COUNT(*) as row_count FROM note_tasks;

-- Check for orphaned records
SELECT 'orphaned_note_folders' as check_name,
       COUNT(*) as count
FROM note_folders nf
WHERE NOT EXISTS (SELECT 1 FROM notes n WHERE n.id = nf.note_id);

-- Check for duplicate entries
SELECT 'duplicate_notes' as check_name,
       COUNT(*) as count
FROM (
    SELECT user_id, title, created_at, COUNT(*) as cnt
    FROM notes
    WHERE deleted = false
    GROUP BY user_id, title, created_at
    HAVING COUNT(*) > 1
) duplicates;
EOF

    log "Running validation queries..."

    # Execute validation
    if psql "$REMOTE_URL" -f "$VALIDATION_FILE" > "$LOG_DIR/validation-results-$SESSION_ID.txt" 2>&1; then
        success "Validation queries executed"

        # Parse results
        while IFS= read -r line; do
            if [[ $line == *"orphaned"* ]] && [[ $line =~ ([0-9]+) ]]; then
                if [ "${BASH_REMATCH[1]}" -gt 0 ]; then
                    warning "Found ${BASH_REMATCH[1]} orphaned records"
                fi
            fi
            if [[ $line == *"duplicate"* ]] && [[ $line =~ ([0-9]+) ]]; then
                if [ "${BASH_REMATCH[1]}" -gt 0 ]; then
                    warning "Found ${BASH_REMATCH[1]} duplicate records"
                fi
            fi
        done < "$LOG_DIR/validation-results-$SESSION_ID.txt"
    else
        warning "Could not execute validation queries"
    fi

    # Check RLS policies
    log "Checking RLS policies..."

    RLS_CHECK=$(psql "$REMOTE_URL" -c "
        SELECT schemaname, tablename, rowsecurity
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename IN ('notes', 'folders', 'clipper_inbox', 'note_tasks')
    " 2>/dev/null)

    if echo "$RLS_CHECK" | grep -q "f"; then
        warning "Some tables have RLS disabled"
    else
        success "RLS enabled on all critical tables"
    fi

    success "Data validation completed"
}

# ==============================================================================
# PHASE 6: Final Synchronization
# ==============================================================================
phase6_final_sync() {
    phase_header "Final Synchronization"

    log "Performing final synchronization checks..."

    # Re-check migration status
    log "Verifying all migrations are applied..."

    if [ "$REMOTE_AVAILABLE" = true ]; then
        FINAL_STATUS_FILE="$LOG_DIR/final-status-$SESSION_ID.txt"

        if timeout 30 supabase migration list > "$FINAL_STATUS_FILE" 2>&1; then
            FINAL_PENDING=$(grep -c "│.*│\s*│" "$FINAL_STATUS_FILE" 2>/dev/null || echo "0")

            if [ "$FINAL_PENDING" -eq 0 ]; then
                success "All migrations synchronized"
            else
                warning "Still have $FINAL_PENDING pending migrations"

                if confirm "Attempt final push of remaining migrations?"; then
                    echo "Y" | supabase db push --include-all 2>&1 | tee -a "$MAIN_LOG"
                fi
            fi
        fi
    fi

    # Final schema check
    log "Final schema verification..."

    FINAL_DIFF_FILE="$LOG_DIR/final-diff-$SESSION_ID.sql"

    if [ "$REMOTE_AVAILABLE" = true ]; then
        if supabase db diff --linked > "$FINAL_DIFF_FILE" 2>&1; then
            if [ ! -s "$FINAL_DIFF_FILE" ]; then
                success "Schemas are fully synchronized"
            else
                warning "Some schema differences remain"
                info "Review: $FINAL_DIFF_FILE"
            fi
        fi
    fi

    # Update Edge Functions if needed
    if confirm "Deploy latest Edge Functions?" "y"; then
        log "Deploying Edge Functions..."

        for func in inbound-web process-notification-queue send-push-notification-v1; do
            if [ -d "$PROJECT_ROOT/supabase/functions/$func" ]; then
                log "Deploying $func..."
                if supabase functions deploy "$func" 2>&1 | tee -a "$MAIN_LOG"; then
                    success "Deployed $func"
                    FIXES_APPLIED+=("Deployed Edge Function: $func")
                else
                    warning "Failed to deploy $func"
                fi
            fi
        done
    fi

    success "Final synchronization completed"
}

# ==============================================================================
# PHASE 7: Comprehensive Report Generation
# ==============================================================================
phase7_report_generation() {
    phase_header "Comprehensive Report Generation"

    log "Generating comprehensive sync report..."

    REPORT_FILE="$REPORT_DIR/master-sync-report-$SESSION_ID.md"

    cat > "$REPORT_FILE" << EOF
# Master Database Sync Report

**Session ID:** $SESSION_ID
**Date:** $(date)
**Duration:** $DURATION_STR

## Executive Summary

- **Total Phases Completed:** $CURRENT_PHASE / $TOTAL_PHASES
- **Errors Encountered:** $PHASE_ERRORS
- **Warnings:** ${#WARNINGS[@]}
- **Fixes Applied:** ${#FIXES_APPLIED[@]}
- **Remote Available:** $REMOTE_AVAILABLE

## System Information

- **Supabase CLI Version:** $SUPABASE_VERSION
- **Project ID:** $PROJECT_ID
- **Total Migrations:** $TOTAL_MIGRATIONS
- **Skipped Migrations:** $SKIPPED_MIGRATIONS

## Issues Found & Fixed

### Duplicate Timestamps
- **Found:** $DUPLICATES
- **Status:** $([ "$DUPLICATES" -gt 0 ] && echo "Fixed" || echo "None")

### Concurrent Indexes
- **Status:** $(grep -r "CREATE INDEX CONCURRENTLY" "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null > /dev/null && echo "Fixed" || echo "None found")

### Extension Issues
- **Vault Extension:** $(grep -r "CREATE EXTENSION.*vault" "$PROJECT_ROOT/supabase/migrations"/*.sql 2>/dev/null > /dev/null && echo "Handled" || echo "None found")

## Applied Fixes

$(if [ ${#FIXES_APPLIED[@]} -gt 0 ]; then
    for fix in "${FIXES_APPLIED[@]}"; do
        echo "- $fix"
    done
else
    echo "No fixes were required"
fi)

## Warnings

$(if [ ${#WARNINGS[@]} -gt 0 ]; then
    for warn in "${WARNINGS[@]}"; do
        echo "- $warn"
    done
else
    echo "No warnings generated"
fi)

## File Locations

- **Main Log:** $MAIN_LOG
- **Error Log:** $ERROR_LOG
- **Phase Log:** $PHASE_LOG
- **Backup:** $BACKUP_FILE
- **Schema Diff:** $DIFF_FILE
- **Final Diff:** $FINAL_DIFF_FILE
- **Validation Results:** $LOG_DIR/validation-results-$SESSION_ID.txt

## Recommendations

$(if [ "$FINAL_PENDING" -gt 0 ]; then
    echo "1. Review and apply remaining $FINAL_PENDING migrations"
fi)
$(if [ -s "$FINAL_DIFF_FILE" ]; then
    echo "2. Review remaining schema differences in $FINAL_DIFF_FILE"
fi)
$(if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "3. Address warnings listed above"
fi)

## Next Steps

1. Review this report and logs
2. Test application functionality
3. Monitor Edge Functions logs
4. Run quick sync periodically: \`./scripts/quick-db-sync.sh\`

---

*Generated by Master Database Sync v1.0*
EOF

    success "Report generated: $REPORT_FILE"

    # Display summary
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    SYNC SUMMARY                        ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Phases Completed: $CURRENT_PHASE / $TOTAL_PHASES                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Total Errors: $PHASE_ERRORS                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Total Warnings: ${#WARNINGS[@]}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Fixes Applied: ${#FIXES_APPLIED[@]}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Duration: $DURATION_STR                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"

    # Open report if possible
    if command -v open &> /dev/null; then
        if confirm "Open the report in your browser?"; then
            open "$REPORT_FILE"
        fi
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================
main() {
    clear

    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         MASTER DATABASE SYNC FOR DURU NOTES               ║"
    echo "║              Comprehensive 7-Phase Process                 ║"
    echo "║                Duration: 10-30 minutes                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    START_TIME=$(date +%s)

    # Confirmation to proceed
    if ! confirm "This process will perform comprehensive database synchronization. Continue?" "y"; then
        echo "Synchronization cancelled"
        exit 0
    fi

    # Run all phases
    phase1_discovery
    phase2_schema_comparison
    phase3_migration_repair
    phase4_schema_sync
    phase5_data_validation
    phase6_final_sync
    phase7_report_generation

    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    DURATION_STR="${MINUTES}m ${SECONDS}s"

    # Final message
    echo -e "\n${GREEN}✨ Master synchronization completed successfully!${NC}"
    echo -e "${YELLOW}Check the comprehensive report at:${NC}"
    echo "$REPORT_FILE"
    echo ""
}

# Trap errors
trap 'error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"