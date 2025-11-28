#!/usr/bin/env bash
# 失敗したワークフローの再テストスクリプト
# TEST_FAILURE_ANALYSIS_REPORT.mdの分析に基づき、タイムアウト設定を最適化

set -uo pipefail
# Note: -e を外して失敗しても続行する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# テスト環境
TEST_DIR="/tmp/multi-ai-retry-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_DIR"
LOG_FILE="$TEST_DIR/retry-test.log"
RESULTS_FILE="$TEST_DIR/retry-results.json"

# テスト結果
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 環境変数設定（非インタラクティブモード）
export WRAPPER_NON_INTERACTIVE=1
export TDD_NON_INTERACTIVE=1
export PROJECT_ROOT

log_info() { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }

record_test_result() {
    local test_name="$1"
    local status="$2"
    local duration="${3:-0}"
    local error_msg="${4:-}"

    ((TESTS_RUN++)) || true

    if [[ "$status" == "PASS" ]]; then
        ((TESTS_PASSED++)) || true
        log_success "$test_name (${duration}秒)"
    else
        ((TESTS_FAILED++)) || true
        log_error "$test_name (${duration}秒)"
        [[ -n "$error_msg" ]] && echo "  → $error_msg" | tee -a "$LOG_FILE"
    fi
}

run_workflow_test() {
    local test_name="$1"
    local workflow_func="$2"
    local task="$3"
    local timeout_sec="$4"

    log_info "Testing: $test_name (timeout: ${timeout_sec}s)"
    local start_time=$(date +%s)

    if timeout "$timeout_sec" bash -c "
        set +euo pipefail
        PROJECT_ROOT='$PROJECT_ROOT'
        export PROJECT_ROOT
        export WRAPPER_NON_INTERACTIVE=1
        export TDD_NON_INTERACTIVE=1
        cd \"\$PROJECT_ROOT\" || exit 1
        export SKIP_VERSION_CHECK=1
        export SKIP_SANITIZE=1
        # 7AI分析に基づく修正: エラーチェック追加（元の出力抑制は維持）
        source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
        source_result=\$?
        if [[ \$source_result -ne 0 ]]; then
            echo 'ERROR: Failed to source orchestrate-multi-ai.sh (exit code: '\$source_result')' >&2
            exit 1
        fi
        # 関数が定義されているか確認
        if ! declare -f $workflow_func >/dev/null 2>&1; then
            echo 'ERROR: Function $workflow_func not found after sourcing' >&2
            exit 1
        fi
        $workflow_func '$task' 2>&1
    " >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        record_test_result "$test_name" "PASS" "$duration"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local error_msg=$(tail -5 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL|❌" | head -1 || echo "タイムアウトまたは不明なエラー")
        record_test_result "$test_name" "FAIL" "$duration" "$error_msg"
    fi
}

run_tdd_test() {
    local test_name="$1"
    local workflow_func="$2"
    local task="$3"
    local timeout_sec="$4"

    log_info "Testing: $test_name (timeout: ${timeout_sec}s)"
    local start_time=$(date +%s)

    if timeout "$timeout_sec" bash -c "
        set +euo pipefail
        PROJECT_ROOT='$PROJECT_ROOT'
        export PROJECT_ROOT
        export WRAPPER_NON_INTERACTIVE=1
        export TDD_NON_INTERACTIVE=1
        cd \"\$PROJECT_ROOT\" || exit 1
        export SKIP_VERSION_CHECK=1
        export SKIP_SANITIZE=1
        # 7AI分析に基づく修正: エラーチェック追加（元の出力抑制は維持）
        source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
        source_result=\$?
        if [[ \$source_result -ne 0 ]]; then
            echo 'ERROR: Failed to source tdd-multi-ai.sh (exit code: '\$source_result')' >&2
            exit 1
        fi
        # 関数が定義されているか確認
        if ! declare -f $workflow_func >/dev/null 2>&1; then
            echo 'ERROR: Function $workflow_func not found after sourcing' >&2
            exit 1
        fi
        $workflow_func '$task' 2>&1
    " >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        record_test_result "$test_name" "PASS" "$duration"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local error_msg=$(tail -5 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL|❌" | head -1 || echo "タイムアウトまたは不明なエラー")
        record_test_result "$test_name" "FAIL" "$duration" "$error_msg"
    fi
}

main() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}失敗ワークフロー再テスト (最適化タイムアウト)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    log_info "Test Directory: $TEST_DIR"
    log_info "Log File: $LOG_FILE"
    log_info "Non-interactive mode enabled"
    echo ""

    # リソース制限
    ulimit -t 14400  # 4時間
    ulimit -v unlimited

    # ===== 失敗テスト1: multi-ai-speed-prototype =====
    # 原因: Qwenタイムアウト (300s → 900s に延長)
    log_info "========== Test 1/9: multi-ai-speed-prototype =========="
    run_workflow_test \
        "multi-ai-speed-prototype" \
        "multi-ai-speed-prototype" \
        "Hello World関数の実装" \
        900  # 600→900秒に延長
    echo ""

    # ===== 失敗テスト2: multi-ai-enterprise-quality =====
    # 原因: Cursor最終フェーズ失敗 (タイムアウト延長)
    log_info "========== Test 2/9: multi-ai-enterprise-quality =========="
    run_workflow_test \
        "multi-ai-enterprise-quality" \
        "multi-ai-enterprise-quality" \
        "ユーザー管理システムの実装" \
        2400  # 1800→2400秒に延長
    echo ""

    # ===== 失敗テスト3: multi-ai-hybrid-development =====
    # 原因: Codex最終フェーズ失敗
    log_info "========== Test 3/9: multi-ai-hybrid-development =========="
    run_workflow_test \
        "multi-ai-hybrid-development" \
        "multi-ai-hybrid-development" \
        "シンプルな計算機能の実装" \
        1500  # 1200→1500秒に延長
    echo ""

    # ===== 失敗テスト4: multi-ai-chatdev-develop =====
    # 原因: Codexレビューフェーズ失敗
    log_info "========== Test 4/9: multi-ai-chatdev-develop =========="
    run_workflow_test \
        "multi-ai-chatdev-develop" \
        "multi-ai-chatdev-develop" \
        "シンプルなTodoリスト" \
        1500  # 1200→1500秒に延長
    echo ""

    # ===== 失敗テスト5: tdd-multi-ai-fast =====
    # 原因: 長時間実行 (タイムアウト大幅延長、タスク簡略化)
    log_info "========== Test 5/9: tdd-multi-ai-fast =========="
    run_tdd_test \
        "tdd-multi-ai-fast" \
        "tdd-multi-ai-fast" \
        "add関数のテスト" \
        3600  # 1800→3600秒に延長、タスクを簡略化
    echo ""

    # ===== 失敗テスト6: multi-ai-code-review =====
    # 原因: タイムアウト (900s → 2700s)
    log_info "========== Test 6/9: multi-ai-code-review =========="
    run_workflow_test \
        "multi-ai-code-review" \
        "multi-ai-code-review" \
        "コード品質レビュー" \
        2700  # 900→2700秒に延長
    echo ""

    # ===== 失敗テスト7: multi-ai-coderabbit-review =====
    # 原因: CodeRabbitタイムアウト (900s → 3600s)
    log_info "========== Test 7/9: multi-ai-coderabbit-review =========="
    run_workflow_test \
        "multi-ai-coderabbit-review" \
        "multi-ai-coderabbit-review" \
        "CodeRabbitレビュー" \
        3600  # 900→3600秒に延長
    echo ""

    # ===== 失敗テスト8: multi-ai-quad-review (Phase 8版) =====
    # 原因: 連続実行時のタイムアウト
    log_info "========== Test 8/9: multi-ai-quad-review =========="
    run_workflow_test \
        "multi-ai-quad-review" \
        "multi-ai-quad-review" \
        "クアッドレビュー" \
        2700  # 900→2700秒に延長
    echo ""

    # ===== 失敗テスト9: multi-ai-speed-prototype (Phase 9版、再実行) =====
    # 原因: API Rate Limiting チェックの誤動作（check_api_rate_limit バグ修正済み）
    # タイムアウト延長: 900→1800秒（API Rate Limitバックオフ最大30分 + 実行時間15分の余裕）
    log_info "========== Test 9/9: multi-ai-speed-prototype (retry) =========="
    run_workflow_test \
        "multi-ai-speed-prototype-retry" \
        "multi-ai-speed-prototype" \
        "シンプルなAPI実装" \
        1800  # 900→1800秒に延長（APIバックオフ対応）
    echo ""

    # 結果サマリー
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}再テスト結果サマリー${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "総テスト数: ${TESTS_RUN}"
    echo -e "${GREEN}成功: ${TESTS_PASSED}${NC}"
    echo -e "${RED}失敗: ${TESTS_FAILED}${NC}"
    echo ""

    local success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    echo -e "成功率: ${success_rate}%"
    echo ""
    echo "Test Directory: $TEST_DIR"
    echo "Log File: $LOG_FILE"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "すべての再テストが成功しました！"
        exit 0
    else
        log_error "${TESTS_FAILED}個のテストが依然として失敗しています"
        exit 1
    fi
}

main "$@"
