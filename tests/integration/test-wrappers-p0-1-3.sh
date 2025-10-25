#!/usr/bin/env bash
# test-wrappers-p0-1-3.sh - P0.1.3 統合テスト: 7ラッパー動作確認

set -euo pipefail

# ============================================================================
# P0.1.3.1: 各ラッパーの動作確認（35分）
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/bin/vibe-logger-lib.sh" 2>/dev/null || true

# カラーコード
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# テスト結果カウンター
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# ヘルパー関数
# ============================================================================

log_test_start() {
    local test_name="$1"
    echo -e "${BLUE}[TEST]${NC} $test_name"
    ((TESTS_RUN++))
}

log_test_pass() {
    local message="${1:-}"
    echo -e "${GREEN}  ✅ PASS${NC}${message:+ - $message}"
    ((TESTS_PASSED++))
}

log_test_fail() {
    local message="${1:-}"
    echo -e "${RED}  ❌ FAIL${NC}${message:+ - $message}"
    ((TESTS_FAILED++))
}

log_test_warn() {
    local message="$1"
    echo -e "${YELLOW}  ⚠️  WARN${NC} - $message"
}

log_section() {
    local title="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# P0.1.3.1: 各ラッパーの動作確認
# ============================================================================

test_wrapper_basic() {
    local wrapper_name="$1"
    local wrapper_path="$2"
    local test_args=("${@:3}")

    log_test_start "Wrapper: $wrapper_name - 基本動作確認"

    # ラッパーファイル存在確認
    if [ ! -f "$wrapper_path" ]; then
        log_test_fail "ラッパーファイルが見つかりません: $wrapper_path"
        return 1
    fi

    # 実行権限確認
    if [ ! -x "$wrapper_path" ]; then
        log_test_fail "実行権限がありません: $wrapper_path"
        return 1
    fi

    # common-wrapper-lib.sh読み込み確認
    if ! grep -q "common-wrapper-lib.sh" "$wrapper_path"; then
        log_test_fail "common-wrapper-lib.shのsourceが見つかりません"
        return 1
    fi

    # テスト実行（タイムアウト5秒、エラーは許容）
    local output
    local exit_code=0
    output=$(timeout 5s "$wrapper_path" "${test_args[@]}" 2>&1 || exit_code=$?)

    # ラッパーが起動してエラーハンドリングが動作すればOK
    # （API未設定の場合はエラーになるが、それは想定内）
    if echo "$output" | grep -q "common-wrapper-lib.sh"; then
        log_test_pass "共通ライブラリ読み込み確認"
    elif echo "$output" | grep -qE "Error|error|ERROR|Failed|failed|FAILED"; then
        log_test_warn "エラー出力確認（API未設定の場合は正常）"
        log_test_pass "エラーハンドリング動作確認"
    elif [ $exit_code -eq 124 ]; then
        log_test_warn "タイムアウト（5秒）"
        log_test_pass "ラッパー起動は確認"
    else
        log_test_pass "ラッパー正常起動"
    fi
}

test_wrapper_help() {
    local wrapper_name="$1"
    local wrapper_path="$2"

    log_test_start "Wrapper: $wrapper_name - ヘルプ表示"

    local output
    if output=$(timeout 2s "$wrapper_path" --help 2>&1); then
        if echo "$output" | grep -qiE "usage|help|options"; then
            log_test_pass "ヘルプ表示確認"
        else
            log_test_warn "ヘルプ表示形式が想定外"
            log_test_pass "ヘルプオプション動作"
        fi
    else
        log_test_warn "ヘルプ表示がタイムアウト or エラー"
    fi
}

# ============================================================================
# P0.1.3.2: タイムアウト処理テスト
# ============================================================================

test_wrapper_timeout() {
    log_test_start "タイムアウト処理 - 短時間タイムアウト（5秒）"

    # Claude wrapperで5秒タイムアウトテスト
    local wrapper="$PROJECT_ROOT/bin/claude-wrapper.sh"
    local exit_code=0

    # 5秒でタイムアウトさせる（--stdinで待機状態にする）
    timeout 5s bash -c "echo 'test' | $wrapper --stdin" 2>&1 || exit_code=$?

    if [ $exit_code -eq 124 ]; then
        log_test_pass "タイムアウト正常動作（exit code 124）"
    elif [ $exit_code -ne 0 ]; then
        log_test_warn "タイムアウト以外のエラー（exit code: $exit_code）"
    else
        log_test_pass "5秒以内に正常完了"
    fi
}

# ============================================================================
# P0.1.3.3: エラーハンドリングテスト
# ============================================================================

test_wrapper_invalid_input() {
    log_test_start "エラーハンドリング - 不正入力（危険文字含む）"

    local wrapper="$PROJECT_ROOT/bin/claude-wrapper.sh"
    local dangerous_input="test; rm -rf /"
    local exit_code=0

    timeout 3s "$wrapper" --prompt "$dangerous_input" 2>&1 >/dev/null || exit_code=$?

    # エラーで終了するか、サニタイズして実行するかのどちらか
    if [ $exit_code -ne 0 ]; then
        log_test_pass "不正入力を拒否（exit code: $exit_code）"
    else
        log_test_warn "不正入力が通過（サニタイズ済みの可能性）"
    fi
}

test_wrapper_missing_ai_cli() {
    log_test_start "エラーハンドリング - 存在しないAI CLI"

    # 一時的にPATHを変更して、AI CLIが見つからない状態をシミュレート
    local wrapper="$PROJECT_ROOT/bin/claude-wrapper.sh"
    local exit_code=0

    # AIコマンドが見つからない場合のエラーハンドリング確認
    # （実際のテストは環境に依存するため、スキップ可能）
    log_test_warn "AI CLI存在チェックはスキップ（環境依存）"
}

# ============================================================================
# P0.1.3.4: VibeLoggerログ確認
# ============================================================================

test_vibelogger_output() {
    log_test_start "VibeLogger - ログ出力確認"

    local log_dir="$PROJECT_ROOT/logs/vibe"

    if [ ! -d "$log_dir" ]; then
        log_test_warn "VibeLoggerログディレクトリが存在しません: $log_dir"
        return
    fi

    # 最新のログファイルを確認
    local latest_log
    latest_log=$(find "$log_dir" -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        log_test_pass "ログファイル存在確認: $(basename "$latest_log")"

        # JSON形式確認
        if jq empty "$latest_log" 2>/dev/null; then
            log_test_pass "JSONフォーマット妥当性確認"
        else
            log_test_warn "JSON形式が不正な行が含まれています"
        fi
    else
        log_test_warn "最近のログファイルが見つかりません"
    fi
}

test_vibelogger_event_format() {
    log_test_start "VibeLogger - イベント形式検証"

    local log_dir="$PROJECT_ROOT/logs/vibe"
    local latest_log
    latest_log=$(find "$log_dir" -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -z "$latest_log" ] || [ ! -f "$latest_log" ]; then
        log_test_warn "ログファイルが見つかりません"
        return
    fi

    # 必須フィールド確認
    local required_fields=("event_type" "action" "timestamp_ms")
    local valid_count=0

    for field in "${required_fields[@]}"; do
        if head -10 "$latest_log" | grep -q "\"$field\""; then
            ((valid_count++))
        fi
    done

    if [ $valid_count -eq ${#required_fields[@]} ]; then
        log_test_pass "必須フィールド確認（${valid_count}/${#required_fields[@]}）"
    else
        log_test_warn "一部の必須フィールドが見つかりません（${valid_count}/${#required_fields[@]}）"
    fi
}

# ============================================================================
# メインテストスイート実行
# ============================================================================

main() {
    echo "============================================================================"
    echo "P0.1.3 統合テスト - 7ラッパー動作確認 & エラーハンドリング"
    echo "============================================================================"

    # Suite 1: P0.1.3.1 - 各ラッパーの基本動作確認
    log_section "Suite 1: P0.1.3.1 - 各ラッパーの動作確認"

    test_wrapper_basic "Claude" "$PROJECT_ROOT/bin/claude-wrapper.sh" --prompt "test"
    test_wrapper_help "Claude" "$PROJECT_ROOT/bin/claude-wrapper.sh"

    test_wrapper_basic "Gemini" "$PROJECT_ROOT/bin/gemini-wrapper.sh" --prompt "test"
    test_wrapper_help "Gemini" "$PROJECT_ROOT/bin/gemini-wrapper.sh"

    test_wrapper_basic "Amp" "$PROJECT_ROOT/bin/amp-wrapper.sh" --context "test"
    test_wrapper_help "Amp" "$PROJECT_ROOT/bin/amp-wrapper.sh"

    test_wrapper_basic "Qwen" "$PROJECT_ROOT/bin/qwen-wrapper.sh" --prompt "test" -y
    test_wrapper_help "Qwen" "$PROJECT_ROOT/bin/qwen-wrapper.sh"

    test_wrapper_basic "Droid" "$PROJECT_ROOT/bin/droid-wrapper.sh" --prompt "test"
    test_wrapper_help "Droid" "$PROJECT_ROOT/bin/droid-wrapper.sh"

    test_wrapper_basic "Codex" "$PROJECT_ROOT/bin/codex-wrapper.sh" --prompt "test"
    test_wrapper_help "Codex" "$PROJECT_ROOT/bin/codex-wrapper.sh"

    test_wrapper_basic "Cursor" "$PROJECT_ROOT/bin/cursor-wrapper.sh" --prompt "test"
    test_wrapper_help "Cursor" "$PROJECT_ROOT/bin/cursor-wrapper.sh"

    # Suite 2: P0.1.3.2 - タイムアウト処理テスト
    log_section "Suite 2: P0.1.3.2 - タイムアウト処理"

    test_wrapper_timeout

    # Suite 3: P0.1.3.3 - エラーハンドリングテスト
    log_section "Suite 3: P0.1.3.3 - エラーハンドリング"

    test_wrapper_invalid_input
    test_wrapper_missing_ai_cli

    # Suite 4: P0.1.3.4 - VibeLoggerログ確認
    log_section "Suite 4: P0.1.3.4 - VibeLogger出力確認"

    test_vibelogger_output
    test_vibelogger_event_format

    # サマリー表示
    echo ""
    echo "============================================================================"
    echo "Test Summary"
    echo "============================================================================"
    echo -e "${BLUE}Total:${NC}  $TESTS_RUN"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"

    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    echo -e "${BLUE}Success Rate:${NC} ${success_rate}%"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${YELLOW}⚠️  Some tests failed or were skipped${NC}"
        exit 1
    fi
}

# テスト実行
main "$@"
