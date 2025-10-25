#!/usr/bin/env bash
# test-trap-handling.sh - Integration tests for P0.3.1 Trap Management System
# Part of P0.3.1: Non-Overwriting Cleanup Handler Implementation
#
# Tests:
# 1. Multiple cleanup handler registration
# 2. Duplicate detection and idempotent behavior
# 3. Execution order verification (FIFO)
# 4. Handler failure tolerance (best-effort cleanup)
# 5. Empty handler validation

set -euo pipefail

# ============================================================================
# Setup
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Source libraries
source "scripts/orchestrate/lib/multi-ai-core.sh"

# Test tracking
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Test temp directory
TEST_TMP_DIR="/tmp/trap-test-$$"
mkdir -p "$TEST_TMP_DIR"

# Cleanup test directory on script exit
trap "rm -rf '$TEST_TMP_DIR'" EXIT

# Colors already defined in multi-ai-core.sh

# ============================================================================
# Helper Functions
# ============================================================================

log_test_start() {
    local test_name="$1"
    ((TEST_COUNT++))
    echo -e "${BLUE}[TEST $TEST_COUNT]${NC} $test_name"
}

log_test_pass() {
    ((PASS_COUNT++))
    echo -e "  ${GREEN}✓ PASS${NC}"
}

log_test_fail() {
    local reason="$1"
    ((FAIL_COUNT++))
    echo -e "  ${RED}✗ FAIL${NC}: $reason"
}

# Reset cleanup handlers between tests
reset_cleanup_handlers() {
    CLEANUP_HANDLERS=()
    trap - EXIT INT TERM
    trap "rm -rf '$TEST_TMP_DIR'" EXIT  # Restore main cleanup
}

# ============================================================================
# Test Cases
# ============================================================================

test_single_handler_registration() {
    log_test_start "Single handler registration"
    reset_cleanup_handlers

    local test_file="$TEST_TMP_DIR/test1.log"

    add_cleanup_handler "echo 'handler1' > '$test_file'"

    if [ "${#CLEANUP_HANDLERS[@]}" -eq 1 ]; then
        log_test_pass
    else
        log_test_fail "Expected 1 handler, got ${#CLEANUP_HANDLERS[@]}"
    fi
}

test_multiple_handler_accumulation() {
    log_test_start "Multiple handler accumulation"
    reset_cleanup_handlers

    add_cleanup_handler "echo handler1"
    add_cleanup_handler "echo handler2"
    add_cleanup_handler "echo handler3"

    if [ "${#CLEANUP_HANDLERS[@]}" -eq 3 ]; then
        log_test_pass
    else
        log_test_fail "Expected 3 handlers, got ${#CLEANUP_HANDLERS[@]}"
    fi
}

test_duplicate_detection() {
    log_test_start "Duplicate handler detection (idempotent)"
    reset_cleanup_handlers

    add_cleanup_handler "echo duplicate_handler"
    add_cleanup_handler "echo duplicate_handler"  # Should be ignored
    add_cleanup_handler "echo another_handler"

    if [ "${#CLEANUP_HANDLERS[@]}" -eq 2 ]; then
        log_test_pass
    else
        log_test_fail "Expected 2 handlers (duplicate ignored), got ${#CLEANUP_HANDLERS[@]}"
    fi
}

test_execution_order_fifo() {
    log_test_start "Execution order verification (FIFO)"
    reset_cleanup_handlers

    local test_file="$TEST_TMP_DIR/order_test.log"
    rm -f "$test_file"

    add_cleanup_handler "echo '1' >> '$test_file'"
    add_cleanup_handler "echo '2' >> '$test_file'"
    add_cleanup_handler "echo '3' >> '$test_file'"

    # Manually trigger cleanup for testing
    run_all_cleanup_handlers > /dev/null 2>&1

    if [ -f "$test_file" ]; then
        local content=$(cat "$test_file" | tr '\n' ' ' | tr -d ' ')
        if [ "$content" = "123" ]; then
            log_test_pass
        else
            log_test_fail "Expected '123', got '$content'"
        fi
    else
        log_test_fail "Test file not created"
    fi
}

test_empty_handler_validation() {
    log_test_start "Empty handler validation"
    reset_cleanup_handlers

    # Should return 1 and not add handler
    if add_cleanup_handler "" 2>/dev/null; then
        log_test_fail "Empty handler should have been rejected"
    else
        if [ "${#CLEANUP_HANDLERS[@]}" -eq 0 ]; then
            log_test_pass
        else
            log_test_fail "Empty handler was added (count: ${#CLEANUP_HANDLERS[@]})"
        fi
    fi
}

test_handler_failure_tolerance() {
    log_test_start "Handler failure tolerance (best-effort cleanup)"
    reset_cleanup_handlers

    local test_file="$TEST_TMP_DIR/failure_test.log"
    rm -f "$test_file"

    add_cleanup_handler "echo 'before_failure' >> '$test_file'"
    add_cleanup_handler "false"  # This handler will fail
    add_cleanup_handler "echo 'after_failure' >> '$test_file'"

    # Run handlers (should continue despite failure)
    run_all_cleanup_handlers > /dev/null 2>&1 || true

    if [ -f "$test_file" ]; then
        local line_count=$(wc -l < "$test_file")
        if [ "$line_count" -eq 2 ]; then
            log_test_pass
        else
            log_test_fail "Expected 2 lines (failure should not stop execution), got $line_count"
        fi
    else
        log_test_fail "Test file not created"
    fi
}

test_no_handlers_graceful_handling() {
    log_test_start "No handlers registered (graceful handling)"
    reset_cleanup_handlers

    # Should return 0 with no errors
    if run_all_cleanup_handlers > /dev/null 2>&1; then
        log_test_pass
    else
        log_test_fail "Should handle zero handlers gracefully"
    fi
}

test_complex_handler_commands() {
    log_test_start "Complex handler commands (pipes, redirects)"
    reset_cleanup_handlers

    local test_file="$TEST_TMP_DIR/complex_test.log"
    rm -f "$test_file"

    # Complex command with pipe and redirect
    add_cleanup_handler "echo 'test data' | tr 'a-z' 'A-Z' > '$test_file'"

    run_all_cleanup_handlers > /dev/null 2>&1

    if [ -f "$test_file" ]; then
        local content=$(cat "$test_file")
        if [[ "$content" == *"TEST DATA"* ]]; then
            log_test_pass
        else
            log_test_fail "Expected 'TEST DATA', got '$content'"
        fi
    else
        log_test_fail "Test file not created"
    fi
}

# ============================================================================
# Test Execution
# ============================================================================

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  P0.3.1 Trap Management System - Integration Tests        ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Run all tests
test_single_handler_registration
test_multiple_handler_accumulation
test_duplicate_detection
test_execution_order_fifo
test_empty_handler_validation
test_handler_failure_tolerance
test_no_handlers_graceful_handling
test_complex_handler_commands

# ============================================================================
# Summary
# ============================================================================

echo
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Test Summary                                              ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "  Total Tests: $TEST_COUNT"
echo -e "  ${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "  ${RED}Failed:${NC} $FAIL_COUNT"
echo

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All trap management tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
