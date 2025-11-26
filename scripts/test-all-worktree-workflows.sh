#!/usr/bin/env bash
# Comprehensive test for all 4 worktree-enabled workflows
# Phase 1.2: 全ワークフローでのWorktree統合テスト

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Enable worktrees
export ENABLE_WORKTREES=true
export PROJECT_ROOT

# Test output directory
TEST_OUTPUT_DIR="logs/worktree-integration-tests"
mkdir -p "$TEST_OUTPUT_DIR"

# Test timestamp
TEST_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_REPORT="$TEST_OUTPUT_DIR/test-report-$TEST_TIMESTAMP.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Initialize test report
init_report() {
    cat > "$TEST_REPORT" <<EOF
# Worktree Integration Test Report

**Test Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Test Timestamp:** $TEST_TIMESTAMP
**Enable Worktrees:** $ENABLE_WORKTREES

## Test Results

| Workflow | Status | Duration | Worktrees Created | Cleanup Status | Issues |
|----------|--------|----------|-------------------|----------------|--------|
EOF
}

# Test result tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test a single workflow
test_workflow() {
    local workflow_name="$1"
    local workflow_function="$2"
    local test_task="$3"
    local expected_worktrees="$4"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    log_info "Testing: $workflow_name"
    echo ""

    local start_time=$(date +%s)
    local status="FAILED"
    local cleanup_status="UNKNOWN"
    local issues=""
    local worktrees_created=0

    # Count worktrees before
    local worktrees_before=$(git worktree list | wc -l)

    # Execute workflow
    if $workflow_function "$test_task" 2>&1 | tee "$TEST_OUTPUT_DIR/${workflow_name}-${TEST_TIMESTAMP}.log"; then
        status="PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_success "$workflow_name completed successfully"
    else
        status="FAILED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        issues="Workflow execution failed"
        log_error "$workflow_name failed"
    fi

    # Count worktrees after
    local worktrees_after=$(git worktree list | wc -l)
    worktrees_created=$((worktrees_after - worktrees_before))

    # Check cleanup
    if [[ $worktrees_after -eq $worktrees_before ]]; then
        cleanup_status="SUCCESS"
        log_success "Cleanup verified: All worktrees removed"
    else
        cleanup_status="FAILED"
        issues="${issues:+$issues; }Cleanup failed: $((worktrees_after - worktrees_before)) worktrees remain"
        log_warning "Cleanup issue: $((worktrees_after - worktrees_before)) worktrees still exist"
    fi

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Record result
    TEST_RESULTS["$workflow_name"]="$status|$duration|$worktrees_created|$cleanup_status|$issues"

    # Append to report
    echo "| $workflow_name | $status | ${duration}s | $worktrees_created | $cleanup_status | $issues |" >> "$TEST_REPORT"

    echo ""
    log_info "Duration: ${duration}s"
    log_info "Worktrees created: $worktrees_created (expected: $expected_worktrees)"
    echo ""
    echo "================================================"
    echo ""
}

# Main test execution
main() {
    log_info "Starting Worktree Integration Tests"
    log_info "Test Report: $TEST_REPORT"
    echo ""

    # Initialize report
    init_report

    # Source orchestration script
    log_info "Sourcing orchestrate-multi-ai.sh"
    source scripts/orchestrate/orchestrate-multi-ai.sh
    echo ""

    # Test 1: multi-ai-speed-prototype
    test_workflow \
        "multi-ai-speed-prototype" \
        "multi-ai-speed-prototype" \
        "Phase 1.2テスト: 各AIが1行で自己紹介（高速プロトタイプ）" \
        "2"

    # Test 2: multi-ai-full-orchestrate
    test_workflow \
        "multi-ai-full-orchestrate" \
        "multi-ai-full-orchestrate" \
        "Phase 1.2テスト: 簡易機能の設計と実装（フルオーケストレーション）" \
        "7"

    # Test 3: multi-ai-enterprise-quality
    test_workflow \
        "multi-ai-enterprise-quality" \
        "multi-ai-enterprise-quality" \
        "Phase 1.2テスト: エンタープライズ品質基準の検証（高品質実装）" \
        "3"

    # Test 4: multi-ai-hybrid-development
    test_workflow \
        "multi-ai-hybrid-development" \
        "multi-ai-hybrid-development" \
        "Phase 1.2テスト: 適応的戦略選択の動作確認（ハイブリッド）" \
        "4"

    # Summary
    cat >> "$TEST_REPORT" <<EOF

## Summary

- **Total Tests:** $TOTAL_TESTS
- **Passed:** $PASSED_TESTS
- **Failed:** $FAILED_TESTS
- **Success Rate:** $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS / $TOTAL_TESTS) * 100}")%

## Detailed Logs

Individual workflow logs are available in:
\`$TEST_OUTPUT_DIR/\`

## Recommendations

EOF

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "✅ All workflows passed. Worktree integration is working correctly." >> "$TEST_REPORT"
    else
        echo "⚠️ $FAILED_TESTS workflow(s) failed. Review the logs for details." >> "$TEST_REPORT"
    fi

    echo ""
    log_info "Test Summary"
    echo "  Total Tests: $TOTAL_TESTS"
    echo "  Passed: $PASSED_TESTS"
    echo "  Failed: $FAILED_TESTS"
    echo "  Success Rate: $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS / $TOTAL_TESTS) * 100}")%"
    echo ""
    log_success "Test report saved: $TEST_REPORT"

    # Exit code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        log_error "Some tests failed"
        exit 1
    else
        log_success "All tests passed!"
        exit 0
    fi
}

# Run main
main "$@"
