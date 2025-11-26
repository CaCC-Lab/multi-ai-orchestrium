#!/usr/bin/env bash
# ワークフロー実際の実行テストスクリプト
# 効率的・確実・安全にワークフローの実際の実行テストを実施

set -euo pipefail

# PROJECT_ROOTを正しく計算（tests/test-workflow-execution-actual.sh から .. でプロジェクトルート）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# テスト設定
TEST_PHASE="${1:-phase1}"  # phase1, phase2, phase3, phase4, phase5
TEST_TIMEOUT_MULTIPLIER="${2:-0.5}"  # タイムアウトの倍率（デフォルト: 0.5倍 = 半分）

# テスト環境の設定
TEST_DIR="/tmp/multi-ai-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_DIR"
export TEST_DIR

# ログ設定
LOG_FILE="$TEST_DIR/test-execution.log"
RESULTS_FILE="$TEST_DIR/test-results.json"

# テスト結果
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ログ関数
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

# テスト結果を記録
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
    
    # JSON形式で結果を記録
    jq -n \
        --arg test_name "$test_name" \
        --arg status "$status" \
        --argjson duration "$duration" \
        --arg error_msg "$error_msg" \
        '{test_name: $test_name, status: $status, duration: $duration, error_msg: $error_msg}' \
        >> "$RESULTS_FILE" 2>/dev/null || true
}

# クリーンアップ関数
cleanup() {
    log_info "Cleaning up test environment..."
    # テストディレクトリは残す（結果確認のため）
    # rm -rf "$TEST_DIR"  # 必要に応じてコメントアウトを解除
}

trap cleanup EXIT

# メイン実行
main() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}ワークフロー実際の実行テスト${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    log_info "Phase: $TEST_PHASE"
    log_info "Timeout Multiplier: ${TEST_TIMEOUT_MULTIPLIER}x"
    log_info "Test Directory: $TEST_DIR"
    log_info "Log File: $LOG_FILE"
    echo ""

    # リソース制限の設定
    log_info "Setting resource limits..."
    ulimit -t 7200  # 2時間でタイムアウト
    ulimit -v unlimited  # メモリ制限を解除（Phase 1-2で2GBでは不足）
    export PARALLEL_JOBS=6  # 並列ジョブ数を増加（7AI対応）

    # 自動テスト環境では全ワークフローで承認を自動化（AGENTS.md CRITICAL分類対応）
    # Phase 2/3で大規模プロンプト（9KB-15KB）がCRITICAL判定 → 承認待ちタイムアウト対策
    export WRAPPER_NON_INTERACTIVE=1
    log_info "Non-interactive mode enabled (auto-approve CRITICAL tasks)"
    echo ""
    
    # PROJECT_ROOTをエクスポート（サブシェルで使用）
    export PROJECT_ROOT
    
    # Phase 1: 最小限の実行テスト
    if [[ "$TEST_PHASE" == "phase1" ]]; then
        log_info "Phase 1: 最小限の実行テスト（5-10分想定）"
        echo ""
        
        # タイムアウトを適切に設定（実際のAI API呼び出しを完了させる）
        export SPEED_PROTOTYPE_TIMEOUT=300  # 300秒（5分）
        export DISCUSS_TIMEOUT=300          # 300秒（5分）
        
        # テスト1: speed-prototype
        log_info "Test 1: multi-ai-speed-prototype"
        local start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-speed-prototype 'Hello World関数の実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-speed-prototype" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-speed-prototype" "FAIL" "$duration" "$error_msg"
        fi
        echo ""
        
        # テスト2: discuss-before
        log_info "Test 2: multi-ai-discuss-before"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-discuss-before '簡単なAPI設計について' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-discuss-before" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-discuss-before" "FAIL" "$duration" "$error_msg"
        fi
        echo ""
        
        log_success "Phase 1 completed"
    fi
    
    # Phase 2: 中規模ワークフローのテスト
    if [[ "$TEST_PHASE" == "phase2" ]]; then
        log_info "Phase 2: 中規模ワークフローのテスト（15-30分想定）"
        echo ""
        
        # タイムアウトを中程度に設定
        export FULL_ORCHESTRATE_TIMEOUT=300
        export CONSENSUS_REVIEW_TIMEOUT=200
        
        # テスト1: full-orchestrate
        log_info "Test 1: multi-ai-full-orchestrate"
        local start_time=$(date +%s)
        if timeout 2400 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-full-orchestrate 'ユーザー認証APIの実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-full-orchestrate" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-full-orchestrate" "FAIL" "$duration" "$error_msg"
        fi
        echo ""
        
        log_success "Phase 2 completed"
    fi
    
    # Phase 3: 大規模ワークフローのテスト
    if [[ "$TEST_PHASE" == "phase3" ]]; then
        log_info "Phase 3: 大規模ワークフローのテスト（30-60分想定）"
        echo ""

        # タイムアウトを適切に設定
        export QUAD_REVIEW_TIMEOUT=600

        # テスト1: quad-review
        log_info "Test 1: multi-ai-quad-review"
        local start_time=$(date +%s)
        # Timeout increased: 700s → 2400s (40 min) for Claude 1200s integrated report + overhead
        if timeout 2400 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-quad-review '最新コミットの包括的レビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-quad-review" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-quad-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""
        
        log_success "Phase 3 completed"
    fi

    # Phase 4: 中規模ワークフローのテスト（30-40分想定）
    if [[ "$TEST_PHASE" == "phase4" ]]; then
        log_info "Phase 4: 中規模ワークフローのテスト（30-40分想定）"
        echo ""

        # タイムアウトを中程度に設定
        export ENTERPRISE_QUALITY_TIMEOUT=1800
        export REVIEW_AFTER_TIMEOUT=1800
        export CONSENSUS_REVIEW_TIMEOUT=1800

        # テスト1: enterprise-quality
        log_info "Test 1: multi-ai-enterprise-quality"
        local start_time=$(date +%s)
        if timeout 1800 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-enterprise-quality 'ユーザー管理システムの実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-enterprise-quality" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-enterprise-quality" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: review-after
        log_info "Test 2: multi-ai-review-after"
        start_time=$(date +%s)
        if timeout 1800 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-review-after 'scripts/orchestrate/lib/multi-ai-core.sh' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-review-after" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-review-after" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト3: consensus-review
        log_info "Test 3: multi-ai-consensus-review"
        start_time=$(date +%s)
        if timeout 1800 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-consensus-review '認証システムの実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-consensus-review" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-consensus-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 4 completed"
    fi

    # Phase 5: 中規模ワークフローのテスト（15-20分想定）
    if [[ "$TEST_PHASE" == "phase5" ]]; then
        log_info "Phase 5: 中規模ワークフローのテスト（15-20分想定）"
        echo ""

        # タイムアウトを適切に設定
        export HYBRID_DEVELOPMENT_TIMEOUT=1200
        export CHATDEV_DEVELOP_TIMEOUT=1200
        export COA_ANALYZE_TIMEOUT=1200

        # テスト1: hybrid-development
        log_info "Test 1: multi-ai-hybrid-development"
        local start_time=$(date +%s)
        if timeout 1200 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-hybrid-development 'シンプルな計算機能（加算・減算）の実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-hybrid-development" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-hybrid-development" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: chatdev-develop
        log_info "Test 2: multi-ai-chatdev-develop"
        start_time=$(date +%s)
        if timeout 1200 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-chatdev-develop 'シンプルなTodoリスト（追加・削除・一覧表示）' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-chatdev-develop" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-chatdev-develop" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト3: coa-analyze
        log_info "Test 3: multi-ai-coa-analyze"
        start_time=$(date +%s)
        if timeout 1200 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-coa-analyze '7つのAIによるマルチAIオーケストレーションシステムのアーキテクチャを分析' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-coa-analyze" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-coa-analyze" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 5 completed"
    fi

    # Phase 6: 大規模ワークフローのテスト（30-60分想定）
    if [[ "$TEST_PHASE" == "phase6" ]]; then
        log_info "Phase 6: 大規模ワークフローのテスト（30-60分想定）"
        echo ""

        # タイムアウトを適切に設定（大規模ワークフローのため長めに設定）
        export COLLABORATIVE_PLANNING_TIMEOUT=3000  # 50分
        export COLLABORATIVE_TESTING_TIMEOUT=4500   # 75分

        # テスト1: collaborative-planning (~45分想定)
        log_info "Test 1: multi-ai-collaborative-planning"
        local start_time=$(date +%s)
        if timeout 3000 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-collaborative-planning 'Webベースのタスク管理システムの実装計画' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-collaborative-planning" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-collaborative-planning" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: collaborative-testing (~70分想定)
        log_info "Test 2: multi-ai-collaborative-testing"
        start_time=$(date +%s)
        if timeout 4500 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-collaborative-testing 'RESTful APIエンドポイントのテスト設計と実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-collaborative-testing" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "multi-ai-collaborative-testing" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 6 completed"
    fi

    # Phase 7: TDDワークフローのテスト（10-20分想定）
    if [[ "$TEST_PHASE" == "phase7" ]]; then
        log_info "Phase 7: TDDワークフローのテスト（30-60分想定）"
        echo ""

        # タイムアウトを延長（TDDサイクルは5フェーズ×各フェーズ最大600秒）
        # tdd-multi-ai-cycle: PLAN + RED + GREEN + REFACTOR + REVIEW = 最大30分
        # tdd-multi-ai-fast: 同様に最大30分（ただしread待ちなし）
        export TDD_CYCLE_TIMEOUT=1800  # 30分
        export TDD_FAST_TIMEOUT=1800   # 30分

        # テスト1: tdd-multi-ai-cycle (~30分想定)
        log_info "Test 1: tdd-multi-ai-cycle"
        local start_time=$(date +%s)
        if timeout 1800 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/tdd/tdd-multi-ai.sh ]]; then
                echo \"ERROR: tdd-multi-ai.sh not found at \$PROJECT_ROOT/scripts/tdd/tdd-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-cycle 'シンプルな計算機関数（add/subtract機能）' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-cycle" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "tdd-multi-ai-cycle" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: tdd-multi-ai-fast (~30分想定)
        log_info "Test 2: tdd-multi-ai-fast"
        start_time=$(date +%s)
        if timeout 1800 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/tdd/tdd-multi-ai.sh ]]; then
                echo \"ERROR: tdd-multi-ai.sh not found at \$PROJECT_ROOT/scripts/tdd/tdd-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-fast 'シンプルなTodoリスト（add/list機能）' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-fast" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || tail -1)
            record_test_result "tdd-multi-ai-fast" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 7 completed"
    fi

    # Phase 8: レビューワークフローのテスト（15-30分想定）
    if [[ "$TEST_PHASE" == "phase8" ]]; then
        log_info "Phase 8: レビューワークフローのテスト（15-30分想定）"
        echo ""

        # タイムアウトを適切に設定（レビューワークフローのため長めに設定）
        export REVIEW_TIMEOUT=900  # 15分

        # テスト1: multi-ai-code-review (~15分想定)
        log_info "Test 1: multi-ai-code-review"
        local start_time=$(date +%s)
        if timeout 900 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found at \$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh\"
                echo \"Current directory: \$(pwd)\"
                echo \"PROJECT_ROOT: \$PROJECT_ROOT\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-code-review 'コード品質レビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-code-review" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-code-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: multi-ai-coderabbit-review (~15分想定)
        log_info "Test 2: multi-ai-coderabbit-review"
        start_time=$(date +%s)
        if timeout 900 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-coderabbit-review 'CodeRabbitレビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-coderabbit-review" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-coderabbit-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト3: multi-ai-dual-review (~15分想定)
        log_info "Test 3: multi-ai-dual-review"
        start_time=$(date +%s)
        if timeout 900 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-dual-review 'デュアルレビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-dual-review" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-dual-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト4: multi-ai-quad-review (~15分想定)
        log_info "Test 4: multi-ai-quad-review"
        start_time=$(date +%s)
        if timeout 900 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/orchestrate/orchestrate-multi-ai.sh ]]; then
                echo \"ERROR: orchestrate-multi-ai.sh not found\"
                exit 1
            fi
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-quad-review 'クアッドレビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-quad-review" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-quad-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 8 completed"
    fi

    # Phase 9: サポートワークフロー（ディスカッション/プロトタイプ系、10-15分想定）
    if [[ "$TEST_PHASE" == "phase9" ]]; then
        log_info "Phase 9: サポートワークフロー（ディスカッション/プロトタイプ系、10-15分想定）"
        echo ""

        # タイムアウトを適切に設定（サポートワークフローのため中程度に設定）
        export SUPPORT_WORKFLOW_TIMEOUT=600  # 10分

        # テスト1: multi-ai-speed-prototype (~5分想定)
        log_info "Test 1: multi-ai-speed-prototype"
        local start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-speed-prototype 'シンプルなAPIエンドポイント' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-speed-prototype" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-speed-prototype" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: multi-ai-discuss-before (~10分想定)
        log_info "Test 2: multi-ai-discuss-before"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-discuss-before '新機能: ユーザー認証システム' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-discuss-before" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-discuss-before" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 9 completed"
    fi

    # Phase 10: サポートワークフロー（総合レビュー、15-20分想定）
    if [[ "$TEST_PHASE" == "phase10" ]]; then
        log_info "Phase 10: サポートワークフロー（総合レビュー、15-20分想定）"
        echo ""

        # タイムアウトを適切に設定（総合レビューのため長めに設定）
        export FULL_REVIEW_TIMEOUT=1200  # 20分

        # テスト1: multi-ai-full-review (~20分想定)
        log_info "Test 1: multi-ai-full-review"
        local start_time=$(date +%s)
        if timeout 1200 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-full-review 'フル統合レビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "multi-ai-full-review" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-full-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 10 completed"
    fi

    # Phase 11: TDD個別フェーズのテスト（15-25分想定）
    if [[ "$TEST_PHASE" == "phase11" ]]; then
        log_info "Phase 11: TDD個別フェーズのテスト（15-25分想定）"
        echo ""

        # タイムアウトを適切に設定（TDD個別フェーズのため中程度に設定）
        export TDD_PHASE_TIMEOUT=600  # 10分

        # テスト1: tdd-multi-ai-plan (~5分想定)
        log_info "Test 1: tdd-multi-ai-plan"
        local start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/tdd/tdd-multi-ai.sh ]]; then
                echo \"ERROR: tdd-multi-ai.sh not found\"
                exit 1
            fi
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-plan 'シンプルな文字列処理ユーティリティ' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-plan" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "tdd-multi-ai-plan" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: tdd-multi-ai-red (~5分想定)
        log_info "Test 2: tdd-multi-ai-red"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-red '数値変換関数のテスト' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-red" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "tdd-multi-ai-red" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト3: tdd-multi-ai-green (~5分想定)
        log_info "Test 3: tdd-multi-ai-green"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-green 'テストを通す実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-green" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "tdd-multi-ai-green" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト4: tdd-multi-ai-refactor (~5分想定)
        log_info "Test 4: tdd-multi-ai-refactor"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-refactor 'コードの最適化' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-refactor" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "tdd-multi-ai-refactor" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト5: tdd-multi-ai-review (~5分想定)
        log_info "Test 5: tdd-multi-ai-review"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            tdd-multi-ai-review '実装のレビュー' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "tdd-multi-ai-review" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "tdd-multi-ai-review" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 11 completed"
    fi

    # Phase 12: ペアプログラミング・Fork-Joinのテスト（15-20分想定）
    if [[ "$TEST_PHASE" == "phase12" ]]; then
        log_info "Phase 12: ペアプログラミング・Fork-Joinのテスト（15-20分想定）"
        echo ""

        # タイムアウトを適切に設定
        export PAIR_TIMEOUT=600  # 10分
        export FORK_JOIN_TIMEOUT=600  # 10分

        # テスト1: pair-multi-ai-driver (~15分想定)
        # 注: この関数はqwen(120秒) + droid(600秒) = 720秒 + オーバーヘッドが必要
        log_info "Test 1: pair-multi-ai-driver"
        local start_time=$(date +%s)
        if timeout 900 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd to \$PROJECT_ROOT\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            if [[ ! -f scripts/tdd/tdd-multi-ai.sh ]]; then
                echo \"ERROR: tdd-multi-ai.sh not found\"
                exit 1
            fi
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            pair-multi-ai-driver 'シンプルなHTTPクライアント実装' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            record_test_result "pair-multi-ai-driver" "PASS" "$duration"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "pair-multi-ai-driver" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト2: pair-multi-ai-navigator (~10分想定)
        log_info "Test 2: pair-multi-ai-navigator"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export TDD_NON_INTERACTIVE=1
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/tdd/tdd-multi-ai.sh >/dev/null 2>&1
            pair-multi-ai-navigator 'コードレビューとアドバイス' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "pair-multi-ai-navigator" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "pair-multi-ai-navigator" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        # テスト3: multi-ai-simple-fork-join (~10分想定)
        log_info "Test 3: multi-ai-simple-fork-join"
        start_time=$(date +%s)
        if timeout 600 bash -c "
            set +euo pipefail
            PROJECT_ROOT='$PROJECT_ROOT'
            export PROJECT_ROOT
            export WRAPPER_NON_INTERACTIVE=1
            cd \"\$PROJECT_ROOT\" || { echo \"ERROR: Failed to cd\"; exit 1; }
            SKIP_VERSION_CHECK=1
            SKIP_SANITIZE=1
            export SKIP_VERSION_CHECK=1
            export SKIP_SANITIZE=1
            source scripts/orchestrate/orchestrate-multi-ai.sh >/dev/null 2>&1
            multi-ai-simple-fork-join 'シンプルな並列処理テスト' 2>&1
        " >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            record_test_result "multi-ai-simple-fork-join" "PASS" "$duration"
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            error_msg=$(tail -10 "$LOG_FILE" | grep -E "ERROR|error|失敗|FAIL" | head -1 || echo "タイムアウトまたは不明なエラー")
            record_test_result "multi-ai-simple-fork-join" "FAIL" "$duration" "$error_msg"
        fi
        echo ""

        log_success "Phase 12 completed"
    fi

    # 結果サマリー
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}テスト結果サマリー${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "総テスト数: ${TESTS_RUN}"
    echo -e "${GREEN}成功: ${TESTS_PASSED}${NC}"
    echo -e "${RED}失敗: ${TESTS_FAILED}${NC}"
    echo ""
    echo "Test Directory: $TEST_DIR"
    echo "Log File: $LOG_FILE"
    echo "Results File: $RESULTS_FILE"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "すべてのテストが成功しました"
        exit 0
    else
        log_error "${TESTS_FAILED}個のテストが失敗しました"
        exit 1
    fi
}

# 実行
main "$@"
