#!/usr/bin/env bash
# Test suite for P1.4 Structured Error Handling
# Tests: log_structured_error, print_stack_trace, handle_critical_error

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Source core library
source scripts/orchestrate/lib/multi-ai-core.sh

# Colors (use existing if already defined in multi-ai-core.sh)
if [[ ! -v GREEN ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    echo -e "\n${YELLOW}[TEST $((TESTS_RUN+1))]${NC} $1"
    ((TESTS_RUN++))
}

test_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

# ============================================================================
# Test 1: log_structured_error creates JSON log file
# ============================================================================
test_start "log_structured_error creates JSON log file"

# Clean up old logs
rm -f logs/errors/$(date +%Y%m%d).jsonl

# Call log_structured_error
log_structured_error \
    "Test error message" \
    "Test cause" \
    "Test remediation" 2>/dev/null

# Check if log file was created
if [ -f "logs/errors/$(date +%Y%m%d).jsonl" ]; then
    test_pass "Error log file created: logs/errors/$(date +%Y%m%d).jsonl"
else
    test_fail "Error log file not created"
fi

# ============================================================================
# Test 2: log_structured_error generates valid JSON
# ============================================================================
test_start "log_structured_error generates valid JSON"

# Read last line from log
LAST_LOG=$(tail -1 "logs/errors/$(date +%Y%m%d).jsonl" 2>/dev/null || echo "{}")

# Validate JSON with jq
if echo "$LAST_LOG" | jq . >/dev/null 2>&1; then
    test_pass "JSON is valid"
else
    test_fail "JSON is invalid"
fi

# ============================================================================
# Test 3: log_structured_error includes required fields
# ============================================================================
test_start "log_structured_error includes required fields (what/why/how)"

WHAT=$(echo "$LAST_LOG" | jq -r '.what' 2>/dev/null)
WHY=$(echo "$LAST_LOG" | jq -r '.why' 2>/dev/null)
HOW=$(echo "$LAST_LOG" | jq -r '.how' 2>/dev/null)

if [[ "$WHAT" == "Test error message" ]] && \
   [[ "$WHY" == "Test cause" ]] && \
   [[ "$HOW" == "Test remediation" ]]; then
    test_pass "All fields present and correct"
else
    test_fail "Missing or incorrect fields (what=$WHAT, why=$WHY, how=$HOW)"
fi

# ============================================================================
# Test 4: log_structured_error includes metadata
# ============================================================================
test_start "log_structured_error includes metadata (script/function/line)"

SCRIPT=$(echo "$LAST_LOG" | jq -r '.script' 2>/dev/null)
FUNCTION=$(echo "$LAST_LOG" | jq -r '.function' 2>/dev/null)
LINE=$(echo "$LAST_LOG" | jq -r '.line' 2>/dev/null)

if [[ -n "$SCRIPT" ]] && [[ -n "$FUNCTION" ]] && [[ "$LINE" =~ ^[0-9]+$ ]]; then
    test_pass "Metadata present (script=$SCRIPT, function=$FUNCTION, line=$LINE)"
else
    test_fail "Missing metadata"
fi

# ============================================================================
# Test 5: print_stack_trace produces output
# ============================================================================
test_start "print_stack_trace produces output"

# Capture stderr output
STACK_OUTPUT=$(print_stack_trace 2>&1)

if [[ -n "$STACK_OUTPUT" ]]; then
    test_pass "Stack trace output generated"
else
    test_fail "No stack trace output"
fi

# ============================================================================
# Test 6: log_structured_error handles special characters
# ============================================================================
test_start "log_structured_error handles special characters (quotes/newlines)"

log_structured_error \
    "Error with \"quotes\" and \$variables" \
    "Multi-line
cause
text" \
    "How with 'single quotes'" 2>/dev/null

LAST_LOG=$(tail -1 "logs/errors/$(date +%Y%m%d).jsonl" 2>/dev/null)
if echo "$LAST_LOG" | jq . >/dev/null 2>&1; then
    test_pass "Special characters handled correctly"
else
    test_fail "Special characters broke JSON"
fi

# ============================================================================
# Test 7: log_structured_error creates logs/errors directory
# ============================================================================
test_start "log_structured_error creates logs/errors directory if missing"

# Remove directory
rm -rf logs/errors

# Call log_structured_error
log_structured_error "Test" "Test" "Test" 2>/dev/null

if [ -d "logs/errors" ]; then
    test_pass "logs/errors directory auto-created"
else
    test_fail "logs/errors directory not created"
fi

# ============================================================================
# Test Summary
# ============================================================================
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total tests: ${YELLOW}$TESTS_RUN${NC}"
echo -e "Passed:      ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:      ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed${NC}"
    exit 1
fi
