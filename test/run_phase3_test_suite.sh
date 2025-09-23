#!/bin/bash

# Phase 3 Test Automation Suite Runner
# This script runs the complete Phase 3 test suite and generates a comprehensive health report

set -e

# Configuration
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="/Users/onronder/duru-notes/docs/test_reports"
SUMMARY_FILE="$REPORT_DIR/phase3_test_suite_summary_$TIMESTAMP.json"
LOG_FILE="$REPORT_DIR/phase3_test_suite_log_$TIMESTAMP.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure report directory exists
mkdir -p "$REPORT_DIR"

echo "=============================================="
echo "🚀 Phase 3 Test Automation Suite Runner"
echo "=============================================="
echo "Timestamp: $(date)"
echo "Report Directory: $REPORT_DIR"
echo "Summary File: $SUMMARY_FILE"
echo ""

# Initialize summary data
cat > "$SUMMARY_FILE" << EOF
{
  "test_suite_run": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "test_suites": {},
    "overall_summary": {
      "total_suites": 6,
      "passed_suites": 0,
      "failed_suites": 0,
      "health_score": 0,
      "deployment_ready": false
    }
  }
}
EOF

# Function to run a test and update summary
run_test() {
    local test_name="$1"
    local test_file="$2"
    local description="$3"

    echo -e "${BLUE}📋 Running: $description${NC}"
    echo "Test File: $test_file"
    echo ""

    # Start test execution
    if flutter test "$test_file" --verbose > "${LOG_FILE}.${test_name}" 2>&1; then
        echo -e "${GREEN}✅ PASSED: $description${NC}"

        # Update summary - test passed
        python3 << EOF
import json
import sys

try:
    with open('$SUMMARY_FILE', 'r') as f:
        summary = json.load(f)

    summary['test_suite_run']['test_suites']['$test_name'] = {
        'status': 'PASSED',
        'description': '$description',
        'log_file': '${LOG_FILE}.${test_name}'
    }

    summary['test_suite_run']['overall_summary']['passed_suites'] += 1

    with open('$SUMMARY_FILE', 'w') as f:
        json.dump(summary, f, indent=2)

except Exception as e:
    print(f"Error updating summary: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    else
        echo -e "${RED}❌ FAILED: $description${NC}"

        # Update summary - test failed
        python3 << EOF
import json
import sys

try:
    with open('$SUMMARY_FILE', 'r') as f:
        summary = json.load(f)

    summary['test_suite_run']['test_suites']['$test_name'] = {
        'status': 'FAILED',
        'description': '$description',
        'log_file': '${LOG_FILE}.${test_name}'
    }

    summary['test_suite_run']['overall_summary']['failed_suites'] += 1

    with open('$SUMMARY_FILE', 'w') as f:
        json.dump(summary, f, indent=2)

except Exception as e:
    print(f"Error updating summary: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    fi

    echo ""
    echo "----------------------------------------------"
    echo ""
}

# Start test execution log
echo "Phase 3 Test Suite Execution Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "===========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Run all test suites
echo "🔄 Starting Phase 3 Test Suite Execution..."
echo ""

# 1. Compilation Validation Tests
run_test "compilation_validation" \
         "test/phase3_compilation_validation_test.dart" \
         "Compilation Fix Validation Tests"

# 2. Sync System Integrity Tests
run_test "sync_system_integrity" \
         "test/phase3_sync_system_integrity_test.dart" \
         "Sync System Integrity Tests"

# 3. Provider Architecture Tests
run_test "provider_architecture" \
         "test/phase3_provider_architecture_test.dart" \
         "Provider Architecture Tests"

# 4. Migration Validation Tests
run_test "migration_validation" \
         "test/phase3_migration_validation_test.dart" \
         "Database Migration Tests"

# 5. Regression Test Framework
run_test "regression_framework" \
         "test/phase3_regression_test_framework.dart" \
         "Regression Test Framework"

# 6. Performance Monitoring Tests
run_test "performance_monitoring" \
         "test/phase3_performance_monitoring_test.dart" \
         "Performance Monitoring Tests"

# Calculate final summary
echo "📊 Calculating final test suite summary..."
python3 << EOF
import json
import sys

try:
    with open('$SUMMARY_FILE', 'r') as f:
        summary = json.load(f)

    overall = summary['test_suite_run']['overall_summary']
    passed = overall['passed_suites']
    total = overall['total_suites']

    # Calculate health score
    health_score = (passed / total) * 100
    overall['health_score'] = round(health_score, 1)

    # Determine deployment readiness (need 85% minimum)
    overall['deployment_ready'] = health_score >= 85.0

    # Determine status
    if health_score >= 95:
        overall['status'] = 'EXCELLENT'
    elif health_score >= 85:
        overall['status'] = 'GOOD'
    elif health_score >= 70:
        overall['status'] = 'FAIR'
    else:
        overall['status'] = 'POOR'

    # Add completion timestamp
    from datetime import datetime
    overall['completed_at'] = datetime.utcnow().isoformat() + 'Z'

    with open('$SUMMARY_FILE', 'w') as f:
        json.dump(summary, f, indent=2)

    # Print summary to stdout for shell script
    print(f"HEALTH_SCORE={health_score}")
    print(f"STATUS={overall['status']}")
    print(f"DEPLOYMENT_READY={str(overall['deployment_ready']).lower()}")
    print(f"PASSED_SUITES={passed}")
    print(f"TOTAL_SUITES={total}")

except Exception as e:
    print(f"Error calculating summary: {e}", file=sys.stderr)
    sys.exit(1)
EOF

# Capture the Python output
eval $(python3 << EOF
import json

try:
    with open('$SUMMARY_FILE', 'r') as f:
        summary = json.load(f)

    overall = summary['test_suite_run']['overall_summary']
    print(f"HEALTH_SCORE={overall['health_score']}")
    print(f"STATUS={overall['status']}")
    print(f"DEPLOYMENT_READY={str(overall['deployment_ready']).lower()}")
    print(f"PASSED_SUITES={overall['passed_suites']}")
    print(f"TOTAL_SUITES={overall['total_suites']}")

except Exception as e:
    print(f"HEALTH_SCORE=0")
    print(f"STATUS=ERROR")
    print(f"DEPLOYMENT_READY=false")
    print(f"PASSED_SUITES=0")
    print(f"TOTAL_SUITES=6")
EOF
)

# Display final results
echo "=============================================="
echo "🏆 Phase 3 Test Suite Results"
echo "=============================================="
echo ""

if [ "$STATUS" = "EXCELLENT" ]; then
    echo -e "${GREEN}🎉 EXCELLENT: All systems operating optimally${NC}"
elif [ "$STATUS" = "GOOD" ]; then
    echo -e "${GREEN}✅ GOOD: Minor issues but deployment ready${NC}"
elif [ "$STATUS" = "FAIR" ]; then
    echo -e "${YELLOW}⚠️  FAIR: Issues need attention before deployment${NC}"
else
    echo -e "${RED}❌ POOR: Critical issues block deployment${NC}"
fi

echo ""
echo "📊 Summary Statistics:"
echo "  • Health Score: ${HEALTH_SCORE}%"
echo "  • Test Suites Passed: ${PASSED_SUITES}/${TOTAL_SUITES}"
echo "  • Deployment Ready: ${DEPLOYMENT_READY}"
echo ""

echo "📄 Reports Generated:"
echo "  • Summary Report: $SUMMARY_FILE"
echo "  • Execution Log: $LOG_FILE"
echo "  • Individual Logs: ${LOG_FILE}.*"
echo ""

# Deployment readiness message
if [ "$DEPLOYMENT_READY" = "true" ]; then
    echo -e "${GREEN}🚀 DEPLOYMENT READY: Phase 3 optimizations can be deployed safely${NC}"
    echo "   ✅ All compilation fixes validated"
    echo "   ✅ Sync system integrity confirmed"
    echo "   ✅ No critical regressions detected"
    echo "   ✅ Performance within acceptable thresholds"
else
    echo -e "${RED}🛑 DEPLOYMENT BLOCKED: Issues must be resolved before deployment${NC}"
    echo "   ❌ Critical test failures detected"
    echo "   ❌ Review failed test logs for details"
    echo "   ❌ Fix issues and re-run test suite"
fi

echo ""
echo "=============================================="
echo "Test suite execution completed: $(date)"
echo "=============================================="

# Exit with appropriate code
if [ "$DEPLOYMENT_READY" = "true" ]; then
    exit 0
else
    exit 1
fi