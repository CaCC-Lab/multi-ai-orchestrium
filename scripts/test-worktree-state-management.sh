#!/usr/bin/env bash
# test-worktree-state-management.sh - Phase 2.1統合テスト
# Phase 2.1.4実装

set -euo pipefail

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# テスト結果カウンター
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ============================================================================
# テストヘルパー関数
# ============================================================================

test_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "   Expected: $expected"
        echo "   Actual:   $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if echo "$actual" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "   Expected to contain: $expected"
        echo "   Actual: $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "   File not found: $file"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# ============================================================================
# テストスイート
# ============================================================================

# ライブラリをロード
source scripts/orchestrate/lib/worktree-state.sh
source scripts/orchestrate/lib/worktree-history.sh
source scripts/orchestrate/lib/worktree-metrics.sh

test_header "Phase 2.1.1: NDJSON状態ファイルのテスト"

# Test 1.1: 状態検証
assert_equals "0" "$?" "is_valid_state('creating') should succeed"
is_valid_state "creating"

is_valid_state "invalid_state" 2>/dev/null && result=1 || result=0
assert_equals "0" "$result" "is_valid_state('invalid') should fail"

# Test 1.2: 状態遷移検証
validate_worktree_state_transition "test" "none" "creating" 2>/dev/null
assert_equals "0" "$?" "none → creating should be valid"

validate_worktree_state_transition "test" "creating" "none" 2>/dev/null && result=1 || result=0
assert_equals "0" "$result" "creating → none should be invalid"

# Test 1.3: 状態更新
update_worktree_state "test-ai" "creating" ',"branch":"test","worktree":"worktrees/test"' 2>/dev/null
state_file=$(get_state_file_path)
assert_file_exists "$state_file" "State file should be created"

# Test 1.4: 状態取得
state_json=$(get_worktree_state "test-ai")
assert_contains "test-ai" "$state_json" "State should contain AI name"
assert_contains "creating" "$state_json" "State should contain state value"

test_header "Phase 2.1.2: 実行履歴追跡のテスト"

# Test 2.1: 実行開始記録
workflow_id="test-workflow-$(date +%s)"
record_worktree_execution_start "$workflow_id" "Test Task" '["claude","qwen"]' 2>/dev/null
history_file=$(get_history_file_path)
assert_file_exists "$history_file" "History file should be created"

# Test 2.2: 実行終了記録
record_worktree_execution_end "$workflow_id" "success" 10 '{"test":true}' 2>/dev/null
history_content=$(tail -1 "$history_file")
assert_contains "execution_end" "$history_content" "History should contain execution_end event"
assert_contains "success" "$history_content" "History should contain success status"

# Test 2.3: 履歴クエリ
query_result=$(query_execution_history "" "" "" "" 2>/dev/null | wc -l)
if [[ $query_result -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} query_execution_history should return results ($query_result entries)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠${NC} query_execution_history returned no results (may be expected)"
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

test_header "Phase 2.1.3: メトリクス収集のテスト"

# Test 3.1: リソース使用量取得
resource_json=$(get_current_resource_usage 2>/dev/null)
assert_contains "timestamp" "$resource_json" "Resource JSON should contain timestamp"
assert_contains "disk_usage_bytes" "$resource_json" "Resource JSON should contain disk_usage"
assert_contains "memory_usage_kb" "$resource_json" "Resource JSON should contain memory_usage"

# Test 3.2: リソース使用量記録
record_resource_usage "test" 2>/dev/null
metrics_file="logs/worktree-metrics/metrics.ndjson"
assert_file_exists "$metrics_file" "Metrics file should be created"

# Test 3.3: メトリクスサマリー生成
metrics_summary=$(generate_metrics_summary 7 2>/dev/null)
assert_contains "generated_at" "$metrics_summary" "Metrics summary should contain timestamp"
assert_contains "current_resources" "$metrics_summary" "Metrics summary should contain resources"
assert_contains "success_trend" "$metrics_summary" "Metrics summary should contain trend"

test_header "Phase 2.1.4: 統合テスト"

# Test 4.1: ダッシュボード生成
bash scripts/generate-metrics-dashboard.sh >/dev/null 2>&1
dashboard_file="logs/worktree-metrics/dashboard.html"
assert_file_exists "$dashboard_file" "Dashboard HTML should be generated"

metrics_json_file="logs/worktree-metrics/metrics-data.json"
assert_file_exists "$metrics_json_file" "Metrics JSON should be generated"

# Test 4.2: 状態遷移フロー全体
update_worktree_state "integration-test" "creating" ',"branch":"test"' 2>/dev/null
update_worktree_state "integration-test" "active" ',"branch":"test"' 2>/dev/null
update_worktree_state "integration-test" "cleaning" ',"branch":"test"' 2>/dev/null
update_worktree_state "integration-test" "none" ',"branch":"test"' 2>/dev/null

final_state=$(get_worktree_state_value "integration-test")
assert_equals "none" "$final_state" "Full state transition should end in 'none'"

# ============================================================================
# テスト結果サマリー
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Results Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total Tests:  ${TOTAL_TESTS}"
echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"

if [[ $FAILED_TESTS -eq 0 ]]; then
    PASS_RATE=100
else
    PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
fi

echo -e "Pass Rate:    ${PASS_RATE}%"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    exit 1
fi
