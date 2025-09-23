#!/bin/bash

# Quick Database Sync Script for Duru Notes
# Fast synchronization between local and remote Supabase databases
# Duration: 2-5 minutes

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="logs/quick-sync-$(date +%Y%m%d-%H%M%S).log"
mkdir -p logs

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

header() {
    echo -e "\n${MAGENTA}═══════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${MAGENTA}  $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${MAGENTA}═══════════════════════════════════════════════${NC}\n" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    header "Checking Prerequisites"

    if ! command -v supabase &> /dev/null; then
        error "Supabase CLI not found. Please install it first."
        exit 1
    fi

    if [ ! -f "supabase/config.toml" ]; then
        error "Not in Supabase project directory"
        exit 1
    fi

    success "All prerequisites met"
}

# Test remote connectivity
test_connectivity() {
    header "Testing Remote Database Connectivity"

    log "Attempting to connect to remote database..."

    if timeout 10 supabase db remote get 2>&1 | grep -q "postgres://"; then
        success "Remote database connection successful"
        return 0
    else
        warning "Remote database connection failed - will work with local only"
        return 1
    fi
}

# Analyze migration files
analyze_migrations() {
    header "Analyzing Migration Files"

    log "Scanning migration directory..."

    # Count different types of migrations
    TOTAL_SQL=$(find supabase/migrations -name "*.sql" 2>/dev/null | wc -l | tr -d ' ')
    SKIP_FILES=$(find supabase/migrations -name "*.skip" 2>/dev/null | wc -l | tr -d ' ')

    log "Found $TOTAL_SQL SQL files, $SKIP_FILES skipped files"

    # Check for duplicate timestamps
    log "Checking for duplicate migration timestamps..."
    DUPLICATES=$(ls -1 supabase/migrations/*.sql 2>/dev/null | \
                 sed 's/.*\///;s/_.*//g' | \
                 sort | uniq -d | wc -l | tr -d ' ')

    if [ "$DUPLICATES" -gt 0 ]; then
        warning "Found duplicate migration timestamps - fixing..."
        fix_duplicate_timestamps
    else
        success "No duplicate timestamps found"
    fi

    # Check for problematic migrations
    log "Scanning for problematic patterns..."

    if grep -r "CREATE INDEX CONCURRENTLY" supabase/migrations/*.sql 2>/dev/null; then
        warning "Found CONCURRENTLY in migrations - fixing..."
        fix_concurrent_indexes
    fi

    if grep -r "CREATE EXTENSION.*vault" supabase/migrations/*.sql 2>/dev/null; then
        warning "Found vault extension requirements - handling..."
        handle_vault_extension
    fi
}

# Fix duplicate timestamps
fix_duplicate_timestamps() {
    log "Fixing duplicate timestamps..."

    # Get list of duplicate timestamps
    DUPE_STAMPS=$(ls -1 supabase/migrations/*.sql 2>/dev/null | \
                  sed 's/.*\///;s/_.*//g' | \
                  sort | uniq -d)

    for stamp in $DUPE_STAMPS; do
        FILES=$(ls -1 supabase/migrations/${stamp}_*.sql 2>/dev/null | tail -n +2)
        COUNTER=1

        for file in $FILES; do
            NEW_STAMP=$(date -d "$stamp +$COUNTER day" +%Y%m%d 2>/dev/null || \
                       date -v +${COUNTER}d -j -f "%Y%m%d" "$stamp" +%Y%m%d 2>/dev/null)
            NEW_FILE=$(echo "$file" | sed "s/${stamp}/${NEW_STAMP}/")

            log "Renaming: $(basename $file) -> $(basename $NEW_FILE)"
            mv "$file" "$NEW_FILE"
            ((COUNTER++))
        done
    done

    success "Fixed duplicate timestamps"
}

# Fix concurrent indexes
fix_concurrent_indexes() {
    log "Removing CONCURRENTLY from index creation..."

    find supabase/migrations -name "*.sql" -exec grep -l "CREATE INDEX CONCURRENTLY" {} \; | \
    while read file; do
        sed -i.bak 's/CREATE INDEX CONCURRENTLY/CREATE INDEX/g' "$file"
        log "Fixed: $(basename $file)"
    done

    # Clean up backup files
    find supabase/migrations -name "*.bak" -delete

    success "Fixed concurrent index issues"
}

# Handle vault extension
handle_vault_extension() {
    log "Handling vault extension requirements..."

    find supabase/migrations -name "*.sql" -exec grep -l "CREATE EXTENSION.*vault" {} \; | \
    while read file; do
        warning "Skipping migration with vault requirement: $(basename $file)"
        mv "$file" "${file}.skip"
    done

    success "Handled vault extension issues"
}

# Get migration status
get_migration_status() {
    header "Getting Migration Status"

    log "Fetching local and remote migration status..."

    # Create temp file for migration list
    TEMP_FILE=$(mktemp)

    if timeout 30 supabase migration list 2>&1 | tee "$TEMP_FILE"; then
        # Count pending migrations
        PENDING=$(grep -c "│.*│\s*│" "$TEMP_FILE" 2>/dev/null || echo "0")

        if [ "$PENDING" -gt 0 ]; then
            warning "Found $PENDING pending migrations"
            return 1
        else
            success "All migrations are synchronized"
            return 0
        fi
    else
        error "Failed to get migration status"
        return 1
    fi

    rm -f "$TEMP_FILE"
}

# Apply pending migrations
apply_migrations() {
    header "Applying Pending Migrations"

    log "Checking for migrations to apply..."

    # First, try to apply without --include-all
    if echo "Y" | supabase db push 2>&1 | tee -a "$LOG_FILE"; then
        success "Migrations applied successfully"
        return 0
    fi

    # If that fails, try with --include-all
    warning "Standard push failed, trying with --include-all..."

    if echo "Y" | supabase db push --include-all 2>&1 | tee -a "$LOG_FILE"; then
        success "Migrations applied with --include-all"
        return 0
    else
        error "Failed to apply migrations"
        return 1
    fi
}

# Generate schema diff
generate_schema_diff() {
    header "Generating Schema Diff"

    log "Comparing local and remote schemas..."

    DIFF_FILE="logs/schema-diff-$(date +%Y%m%d-%H%M%S).sql"

    if supabase db diff --linked 2>&1 > "$DIFF_FILE"; then
        if [ -s "$DIFF_FILE" ]; then
            warning "Schema differences found - saved to $DIFF_FILE"

            echo -e "\n${YELLOW}First 20 lines of differences:${NC}"
            head -20 "$DIFF_FILE"

            return 1
        else
            success "Schemas are in sync"
            return 0
        fi
    else
        error "Failed to generate schema diff"
        return 1
    fi
}

# Create alignment migration
create_alignment_migration() {
    header "Creating Alignment Migration"

    read -p "Do you want to create an alignment migration? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        MIGRATION_NAME="align_schemas_$(date +%Y%m%d_%H%M%S)"
        MIGRATION_FILE="supabase/migrations/$(date +%Y%m%d)_${MIGRATION_NAME}.sql"

        log "Creating migration: $MIGRATION_FILE"

        # Copy the diff as the migration
        cp "$DIFF_FILE" "$MIGRATION_FILE"

        success "Created alignment migration: $(basename $MIGRATION_FILE)"

        # Apply the migration
        log "Applying alignment migration..."
        if echo "Y" | supabase db push 2>&1 | tee -a "$LOG_FILE"; then
            success "Alignment migration applied"
        else
            error "Failed to apply alignment migration"
        fi
    else
        log "Skipping alignment migration creation"
    fi
}

# Generate report
generate_report() {
    header "Quick Sync Report"

    REPORT_FILE="logs/quick-sync-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "Quick Database Sync Report"
        echo "=========================="
        echo "Date: $(date)"
        echo ""
        echo "Summary:"
        echo "--------"
        echo "Total SQL migrations: $TOTAL_SQL"
        echo "Skipped migrations: $SKIP_FILES"
        echo "Duplicate timestamps fixed: $DUPLICATES"
        echo ""
        echo "Actions Taken:"
        echo "--------------"
        grep -E "✅|⚠️|❌" "$LOG_FILE" | tail -20
        echo ""
        echo "Full log: $LOG_FILE"
    } > "$REPORT_FILE"

    cat "$REPORT_FILE"

    success "Report saved to: $REPORT_FILE"
}

# Main execution
main() {
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║      QUICK DATABASE SYNC FOR DURU NOTES    ║"
    echo "║            Duration: 2-5 minutes           ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    START_TIME=$(date +%s)

    # Run all checks and fixes
    check_prerequisites

    REMOTE_AVAILABLE=true
    test_connectivity || REMOTE_AVAILABLE=false

    analyze_migrations

    if [ "$REMOTE_AVAILABLE" = true ]; then
        get_migration_status || apply_migrations
        generate_schema_diff || create_alignment_migration
    else
        warning "Working in local-only mode due to connectivity issues"
    fi

    generate_report

    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    success "Quick sync completed in ${MINUTES}m ${SECONDS}s"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review the report at: $REPORT_FILE"
    echo "2. Check logs at: $LOG_FILE"
    echo "3. Run comprehensive sync if needed: ./scripts/db-sync-master.sh"
    echo ""
}

# Run main function
main "$@"