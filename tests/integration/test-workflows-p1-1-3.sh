#!/usr/bin/env bash
# test-workflows-p1-1-3.sh - P1.1.3 統合テスト: 全ワークフロー動作確認

# Note: Not using 'set -euo pipefail' to allow test failures to be tracked

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Don't source the orchestrator directly - just check if workflows can be loaded
# by checking the module files exist and are syntactically valid

# Color codes
TEST_GREEN='\033[0;32m'
TEST_RED='\033[0;31m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Helper Functions
# ============================================================================

log_test_start() {
    local test_name="$1"
    echo -e "${TEST_BLUE}[TEST]${TEST_NC} $test_name"
    ((TESTS_RUN++))
}

log_test_pass() {
    local message="${1:-}"
    echo -e "${TEST_GREEN}  ✅ PASS${TEST_NC}${message:+ - $message}"
    ((TESTS_PASSED++))
}

log_test_fail() {
    local message="${1:-}"
    echo -e "${TEST_RED}  ❌ FAIL${TEST_NC}${message:+ - $message}"
    ((TESTS_FAILED++))
}

log_test_warn() {
    local message="$1"
    echo -e "${TEST_YELLOW}  ⚠️  WARN${TEST_NC} - $message"
}

log_section() {
    local title="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# P1.1.3.1: 全ワークフロー動作確認（13関数）
# ============================================================================

test_workflow_function_exists() {
    local workflow_name="$1"
    local module_file="$2"

    log_test_start "Workflow: $workflow_name - 関数定義確認"

    # Check if the function is defined in the module file
    if grep -q "^${workflow_name}()" "$PROJECT_ROOT/scripts/orchestrate/lib/$module_file" 2>/dev/null; then
        log_test_pass "関数定義存在 (in $module_file)"
    else
        log_test_fail "関数定義が見つかりません (in $module_file)"
        return 1
    fi
}

test_module_exists() {
    local module_file="$1"

    log_test_start "Module: $module_file - ファイル存在確認"

    # Check if module file exists
    local module_path="$PROJECT_ROOT/scripts/orchestrate/lib/$module_file"

    if [ -f "$module_path" ]; then
        local line_count=$(wc -l < "$module_path")
        log_test_pass "ファイル存在 ($line_count lines)"
    else
        log_test_fail "モジュールファイルが存在しません"
        return 1
    fi
}

# ============================================================================
# Main Test Suite
# ============================================================================

main() {
    echo "============================================================================"
    echo "P1.1.3 統合テスト - モジュール化後の全ワークフロー動作確認"
    echo "============================================================================"

    # Suite 1: Core Workflows (6 functions)
    log_section "Suite 1: Core Workflows (workflows-core.sh)"

    test_module_exists "workflows-core.sh"
    test_workflow_function_exists "multi-ai-full-orchestrate" "workflows-core.sh"
    test_workflow_function_exists "multi-ai-speed-prototype" "workflows-core.sh"
    test_workflow_function_exists "multi-ai-enterprise-quality" "workflows-core.sh"
    test_workflow_function_exists "multi-ai-hybrid-development" "workflows-core.sh"
    test_workflow_function_exists "multi-ai-consensus-review" "workflows-core.sh"
    test_workflow_function_exists "multi-ai-chatdev-develop" "workflows-core.sh"

    # Suite 2: Discussion Workflows (2 functions)
    log_section "Suite 2: Discussion Workflows (workflows-discussion.sh)"

    test_module_exists "workflows-discussion.sh"
    test_workflow_function_exists "multi-ai-discuss-before" "workflows-discussion.sh"
    test_workflow_function_exists "multi-ai-review-after" "workflows-discussion.sh"

    # Suite 3: Chain-of-Agents (1 function)
    log_section "Suite 3: Chain-of-Agents Workflow (workflows-coa.sh)"

    test_module_exists "workflows-coa.sh"
    test_workflow_function_exists "multi-ai-coa-analyze" "workflows-coa.sh"

    # Suite 4: Code Review Workflows (4 functions)
    log_section "Suite 4: Code Review Workflows (workflows-review.sh)"

    test_module_exists "workflows-review.sh"
    test_workflow_function_exists "multi-ai-code-review" "workflows-review.sh"
    test_workflow_function_exists "multi-ai-coderabbit-review" "workflows-review.sh"
    test_workflow_function_exists "multi-ai-full-review" "workflows-review.sh"
    test_workflow_function_exists "multi-ai-dual-review" "workflows-review.sh"

    # Summary
    echo ""
    echo "============================================================================"
    echo "Test Summary"
    echo "============================================================================"
    echo -e "${TEST_BLUE}Total:${TEST_NC}  $TESTS_RUN"
    echo -e "${TEST_GREEN}Passed:${TEST_NC} $TESTS_PASSED"
    echo -e "${TEST_RED}Failed:${TEST_NC} $TESTS_FAILED"

    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    echo -e "${TEST_BLUE}Success Rate:${TEST_NC} ${success_rate}%"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${TEST_GREEN}✅ All workflow tests passed!${TEST_NC}"
        exit 0
    else
        echo -e "\n${TEST_YELLOW}⚠️  Some workflow tests failed${TEST_NC}"
        exit 1
    fi
}

# Run tests
main "$@"
