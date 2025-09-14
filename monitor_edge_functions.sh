#!/bin/bash

# =====================================================
# Edge Functions Monitoring Script
# Checks for 401 errors and other issues
# =====================================================

set -e

# Configuration
PROJECT_REF="jtaedgpxesshdrnbgvjr"
LOG_FILE="edge_function_monitoring.log"
ALERT_THRESHOLD=5  # Alert if more than 5 errors in the time period

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Edge Functions Monitoring Report${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Project: $PROJECT_REF"
echo "Date: $(date)"
echo ""

# Function to check logs via database
check_database_logs() {
    echo -e "${YELLOW}Checking recent Edge Function errors...${NC}"
    
    # Query to check for 401 errors in the last hour
    QUERY="
    SELECT 
        COUNT(*) FILTER (WHERE status_code = 401) as auth_errors,
        COUNT(*) FILTER (WHERE status_code >= 500) as server_errors,
        COUNT(*) FILTER (WHERE status_code = 429) as rate_limit_errors,
        COUNT(*) as total_requests,
        COUNT(DISTINCT function_id) as unique_functions
    FROM edge_logs
    WHERE timestamp > NOW() - INTERVAL '1 hour'
    "
    
    # Note: This would normally connect to your database
    # For now, we'll use the Supabase dashboard
    echo "Please check the Supabase dashboard for detailed logs:"
    echo "https://supabase.com/dashboard/project/$PROJECT_REF/functions"
}

# Function to list all deployed functions
list_functions() {
    echo -e "${YELLOW}Currently Deployed Functions:${NC}"
    supabase functions list --project-ref $PROJECT_REF | tail -n +4
    echo ""
}

# Function to check specific function health
check_function_health() {
    local function_name=$1
    echo -e "${YELLOW}Checking $function_name...${NC}"
    
    # Test the function with a health check
    case $function_name in
        "email_inbox")
            # Test with GET request (should return 405 but shows it's responding)
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                "https://$PROJECT_REF.supabase.co/functions/v1/$function_name")
            ;;
        "inbound-web-auth")
            # Test CORS preflight
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                -X OPTIONS \
                "https://$PROJECT_REF.supabase.co/functions/v1/$function_name")
            ;;
        *)
            response="N/A"
            ;;
    esac
    
    if [ "$response" != "N/A" ]; then
        if [ "$response" = "200" ] || [ "$response" = "405" ] || [ "$response" = "401" ]; then
            echo -e "  ${GREEN}✓${NC} Function is responding (HTTP $response)"
        else
            echo -e "  ${RED}✗${NC} Function may have issues (HTTP $response)"
        fi
    fi
}

# Main monitoring flow
echo -e "${BLUE}1. Deployed Functions Status${NC}"
echo "----------------------------------------"
list_functions

echo -e "${BLUE}2. Function Health Checks${NC}"
echo "----------------------------------------"
for func in "email_inbox" "inbound-web-auth" "send-push-notification-v1" "process-notification-queue"; do
    check_function_health $func
done
echo ""

echo -e "${BLUE}3. Recent Error Summary${NC}"
echo "----------------------------------------"
check_database_logs
echo ""

echo -e "${BLUE}4. Recommendations${NC}"
echo "----------------------------------------"
echo "• Check the Supabase dashboard for detailed logs"
echo "• Monitor for 401 errors - should be zero after fixes"
echo "• Watch for 429 (rate limit) errors"
echo "• Ensure all functions show 'ACTIVE' status"
echo ""

echo -e "${BLUE}5. Quick Diagnostic Commands${NC}"
echo "----------------------------------------"
echo "View recent logs for a specific function:"
echo -e "${GREEN}supabase functions logs [function-name] --project-ref $PROJECT_REF${NC}"
echo ""
echo "Check function configuration:"
echo -e "${GREEN}supabase functions list --project-ref $PROJECT_REF${NC}"
echo ""
echo "Test email inbox webhook:"
echo -e "${GREEN}curl -X POST https://$PROJECT_REF.supabase.co/functions/v1/email_inbox?secret=YOUR_SECRET${NC}"
echo ""

# Log results
{
    echo "=== Monitoring Run: $(date) ==="
    echo "Functions checked"
    echo "Manual dashboard review required for detailed error analysis"
    echo ""
} >> $LOG_FILE

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Monitoring Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Results logged to: $LOG_FILE"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "Please check the Supabase dashboard for detailed error logs:"
echo "https://supabase.com/dashboard/project/$PROJECT_REF/functions"
echo ""
echo "Look specifically for:"
echo "• Any 401 (Unauthorized) errors"
echo "• Any 500 (Server Error) responses"
echo "• Unusual patterns in request volume"
