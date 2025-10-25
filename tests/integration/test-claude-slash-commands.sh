#!/usr/bin/env bash
# test-claude-slash-commands.sh - Integration tests for Claude review CLI scripts
# Version: 1.0.0

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
log_test_start() {
    local test_name="$1"
    echo -e "${YELLOW}[TEST]${NC} $test_name"
    ((TESTS_TOTAL++))
}

log_test_pass() {
    local test_name="$1"
    echo -e "${GREEN}[PASS]${NC} $test_name"
    ((TESTS_PASSED++))
}

log_test_fail() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}[FAIL]${NC} $test_name: $reason"
    ((TESTS_FAILED++))
}

# Test 3.4.1.1: claude-review.sh の実行確認
test_claude_review_execution() {
    local test_name="claude-review.sh execution"
    log_test_start "$test_name"

    if [[ ! -x "$PROJECT_ROOT/scripts/claude-review.sh" ]]; then
        log_test_fail "$test_name" "Script not found or not executable"
        return 1
    fi

    # Test help output
    if "$PROJECT_ROOT/scripts/claude-review.sh" --help &>/dev/null; then
        log_test_pass "$test_name"
        return 0
    else
        log_test_fail "$test_name" "Help command failed"
        return 1
    fi
}

# Test 3.4.1.2: claude-security-review.sh の実行確認
test_claude_security_review_execution() {
    local test_name="claude-security-review.sh execution"
    log_test_start "$test_name"

    if [[ ! -x "$PROJECT_ROOT/scripts/claude-security-review.sh" ]]; then
        log_test_fail "$test_name" "Script not found or not executable"
        return 1
    fi

    # Test help output
    if "$PROJECT_ROOT/scripts/claude-security-review.sh" --help &>/dev/null; then
        log_test_pass "$test_name"
        return 0
    else
        log_test_fail "$test_name" "Help command failed"
        return 1
    fi
}

# Test 3.4.1.3: 両スクリプトの連続実行
test_consecutive_execution() {
    local test_name="Consecutive script execution"
    log_test_start "$test_name"

    # Create temporary output directories
    local review_output="/tmp/claude-review-test-$$"
    local security_output="/tmp/claude-security-review-test-$$"

    mkdir -p "$review_output" "$security_output"

    # Run both scripts with --help (safe test)
    if "$PROJECT_ROOT/scripts/claude-review.sh" --help &>/dev/null && \
       "$PROJECT_ROOT/scripts/claude-security-review.sh" --help &>/dev/null; then
        log_test_pass "$test_name"
        rm -rf "$review_output" "$security_output"
        return 0
    else
        log_test_fail "$test_name" "Consecutive execution failed"
        rm -rf "$review_output" "$security_output"
        return 1
    fi
}

# Test 3.4.1.4: 出力ファイルの整合性確認
test_output_consistency() {
    local test_name="Output file consistency"
    log_test_start "$test_name"

    # Check if scripts have proper shebang and set -euo pipefail
    if (grep -q "^#!/usr/bin/env bash" "$PROJECT_ROOT/scripts/claude-review.sh" || grep -q "^#!/bin/bash" "$PROJECT_ROOT/scripts/claude-review.sh") && \
       grep -q "set -euo pipefail" "$PROJECT_ROOT/scripts/claude-review.sh" && \
       (grep -q "^#!/usr/bin/env bash" "$PROJECT_ROOT/scripts/claude-security-review.sh" || grep -q "^#!/bin/bash" "$PROJECT_ROOT/scripts/claude-security-review.sh") && \
       grep -q "set -euo pipefail" "$PROJECT_ROOT/scripts/claude-security-review.sh"; then
        log_test_pass "$test_name"
        return 0
    else
        log_test_fail "$test_name" "Scripts missing shebang or error handling"
        return 1
    fi
}

# Main test execution
main() {
    echo "=== Claude Review CLI Scripts Integration Tests ==="
    echo ""

    # Run all tests
    test_claude_review_execution || true
    test_claude_security_review_execution || true
    test_consecutive_execution || true
    test_output_consistency || true

    # Print summary
    echo ""
    echo "=== Test Summary ==="
    echo "Total:  $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

main "$@"
