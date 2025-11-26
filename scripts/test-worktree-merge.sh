#!/usr/bin/env bash
# test-worktree-merge.sh - Phase 2.3 統合テスト
# マージ戦略と競合解決支援のテスト

set -euo pipefail

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# テスト結果カウンター
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# テスト用ディレクトリ
TEST_DIR="$(mktemp -d)"
trap "rm -rf '$TEST_DIR'" EXIT

# ============================================================================
# テストヘルパー関数
# ============================================================================

test_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

assert_success() {
    local cmd="$1"
    local test_name="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local output
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "   Command failed: $cmd"
        echo "   Exit code: $exit_code"
        echo "   Output: $output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_failure() {
    local cmd="$1"
    local test_name="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if ! eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "   Command should have failed: $cmd"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
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

skip_test() {
    local test_name="$1"
    local reason="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    echo -e "${YELLOW}⊙${NC} $test_name (SKIPPED: $reason)"
}

# ============================================================================
# テスト環境セットアップ
# ============================================================================

setup_test_repo() {
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # 初期コミット
    echo "# Test Project" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # mainブランチを作成（デフォルトがmasterの場合にリネーム）
    git branch -M main 2>/dev/null || true
    git checkout -q main 2>/dev/null || true
}

setup_worktree() {
    local ai_name="$1"
    local worktree_path="$TEST_DIR/worktrees/$ai_name"
    local branch_name="ai/$ai_name/test"

    # 既存のWorktreeとブランチをクリーンアップ
    teardown_worktree "$ai_name"

    # mainブランチに確実に戻る
    git checkout -q main 2>/dev/null || true

    # ブランチが存在する場合は強制削除
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        git branch -D "$branch_name" 2>/dev/null || true
    fi

    mkdir -p "$TEST_DIR/worktrees"
    git worktree add -q "$worktree_path" -b "$branch_name"

    # AIブランチで変更を作成
    (
        cd "$worktree_path"
        echo "Changes by $ai_name" >> README.md
        git add README.md
        git commit -q -m "Changes by $ai_name"
    )
}

teardown_worktree() {
    local ai_name="$1"
    local worktree_path="$TEST_DIR/worktrees/$ai_name"
    local branch_name="ai/$ai_name/test"

    # カレントディレクトリをmainリポジトリに戻す
    cd "$TEST_DIR"

    # mainブランチに確実に戻る（ブランチ削除のため）
    git checkout -q main 2>/dev/null || true

    # Worktreeを削除
    if [[ -d "$worktree_path" ]]; then
        git worktree remove -q "$worktree_path" --force 2>/dev/null || true
        rm -rf "$worktree_path" 2>/dev/null || true
    fi

    # Worktree pruneでゴミを削除
    git worktree prune 2>/dev/null || true

    # ブランチを強制削除（確実に削除）
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git branch -D "$branch_name" 2>/dev/null || true
    fi
}

# ============================================================================
# Phase 2.3.1: 基本マージ機能テスト
# ============================================================================

test_header "Phase 2.3.1: 基本マージ機能のテスト"

# ライブラリをロード
export WORKTREE_BASE_DIR="$TEST_DIR/worktrees"
export NON_INTERACTIVE=true  # 非対話モード有効化（自動テスト用）
source scripts/orchestrate/lib/worktree-merge.sh

# テスト環境構築
setup_test_repo

# Test 1.1: check_merge_conflicts() - 競合なし
setup_worktree "qwen"
cd "$TEST_DIR"
assert_success "check_merge_conflicts qwen" "check_merge_conflicts() detects no conflicts"
teardown_worktree "qwen"

# Test 1.2: merge_worktree_branch() - no-ff戦略
setup_worktree "qwen"
cd "$TEST_DIR"
git checkout -q main
assert_success "merge_worktree_branch qwen main no-ff" "merge_worktree_branch() with no-ff strategy"
assert_contains "Changes by qwen" "$(cat README.md)" "Merged changes are present"
git reset --hard -q HEAD~1  # クリーンアップ
teardown_worktree "qwen"

# Test 1.3: merge_worktree_branch() - squash戦略
setup_worktree "droid"
cd "$TEST_DIR"
git checkout -q main
assert_success "merge_worktree_branch droid main squash" "merge_worktree_branch() with squash strategy"
git reset --hard -q HEAD~1  # クリーンアップ
teardown_worktree "droid"

# ============================================================================
# Phase 2.3.2: 競合解決支援テスト
# ============================================================================

test_header "Phase 2.3.2: 競合解決支援のテスト"

# Test 2.1: visualize_merge_conflicts() - 競合なし
setup_worktree "qwen"
cd "$TEST_DIR"
output=$(visualize_merge_conflicts "qwen" 2>&1)
assert_contains "競合は検出されませんでした" "$output" "visualize_merge_conflicts() with no conflicts"
teardown_worktree "qwen"

# Test 2.2: compare_ai_changes() - 複数AI比較
setup_worktree "qwen"
setup_worktree "droid"
cd "$TEST_DIR"
output=$(compare_ai_changes "" qwen droid 2>&1)
assert_contains "AI Changes Comparison" "$output" "compare_ai_changes() shows comparison header"
assert_contains "qwen" "$output" "compare_ai_changes() shows qwen changes"
assert_contains "droid" "$output" "compare_ai_changes() shows droid changes"
teardown_worktree "qwen"
teardown_worktree "droid"

# Test 2.3: compare_ai_changes() - AI数不足でエラー
cd "$TEST_DIR"
assert_failure "compare_ai_changes '' qwen" "compare_ai_changes() fails with less than 2 AIs"

# Test 2.4: interactive_conflict_resolution() - 非対話モード
setup_worktree "qwen"
cd "$TEST_DIR"
output=$(interactive_conflict_resolution "qwen" 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    assert_equals "0" "$exit_code" "interactive_conflict_resolution() succeeds in non-interactive mode"
else
    # 競合がない場合も成功とみなす
    assert_contains "Non-interactive mode" "$output" "interactive_conflict_resolution() uses non-interactive mode"
fi
teardown_worktree "qwen"

# ============================================================================
# Phase 2.3.3: 追加マージ戦略テスト
# ============================================================================

test_header "Phase 2.3.3: 追加マージ戦略のテスト"

# Test 3.1: ours戦略 - 競合なし
setup_worktree "qwen"
cd "$TEST_DIR"
git checkout -q main
assert_success "merge_worktree_branch qwen main ours" "merge_worktree_branch() with ours strategy"
git reset --hard -q HEAD~1  # クリーンアップ
teardown_worktree "qwen"

# Test 3.2: theirs戦略 - 競合なし
setup_worktree "droid"
cd "$TEST_DIR"
git checkout -q main
assert_success "merge_worktree_branch droid main theirs" "merge_worktree_branch() with theirs strategy"
git reset --hard -q HEAD~1  # クリーンアップ
teardown_worktree "droid"

# Test 3.3: best戦略 - 自動選択
setup_worktree "qwen"
cd "$TEST_DIR"
git checkout -q main
assert_success "merge_worktree_branch qwen main best" "merge_worktree_branch() with best strategy"
git reset --hard -q HEAD~1  # クリーンアップ
teardown_worktree "qwen"

# Test 3.4: manual戦略 - 非対話モード（theirsにフォールバック）
setup_worktree "qwen"
cd "$TEST_DIR"
git checkout -q main
assert_success "merge_worktree_branch qwen main manual" "merge_worktree_branch() with manual strategy (non-interactive fallback)"
git reset --hard -q HEAD~1  # クリーンアップ
teardown_worktree "qwen"

# Test 3.5: 無効な戦略
setup_worktree "qwen"
cd "$TEST_DIR"
git checkout -q main
assert_failure "merge_worktree_branch qwen main invalid" "merge_worktree_branch() fails with invalid strategy"
teardown_worktree "qwen"

# ============================================================================
# Phase 2.3.4: merge_all_sequential() テスト
# ============================================================================

test_header "Phase 2.3.4: merge_all_sequential() のテスト"

# Test 4.1: 複数AIの順次マージ（競合を避けるため異なるファイルを作成）
# Qwen用のWorktree（qwen.txtを作成）
teardown_worktree "qwen"
git checkout -q main 2>/dev/null || true
mkdir -p "$TEST_DIR/worktrees"
git worktree add -q "$TEST_DIR/worktrees/qwen" -b "ai/qwen/test"
(cd "$TEST_DIR/worktrees/qwen" && echo "Qwen feature" > qwen.txt && git add qwen.txt && git commit -q -m "Add qwen.txt")

# Droid用のWorktree（droid.txtを作成）
teardown_worktree "droid"
git checkout -q main 2>/dev/null || true
git worktree add -q "$TEST_DIR/worktrees/droid" -b "ai/droid/test"
(cd "$TEST_DIR/worktrees/droid" && echo "Droid feature" > droid.txt && git add droid.txt && git commit -q -m "Add droid.txt")

cd "$TEST_DIR"
git checkout -q main
assert_success "merge_all_sequential main no-ff qwen droid" "merge_all_sequential() with 2 AIs"
git reset --hard -q HEAD~2  # 2つのマージをクリーンアップ
teardown_worktree "qwen"
teardown_worktree "droid"

# ============================================================================
# テスト結果サマリー
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total:   $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:  $PASSED_TESTS${NC}"
echo -e "  ${RED}Failed:  $FAILED_TESTS${NC}"
echo -e "  ${YELLOW}Skipped: $SKIPPED_TESTS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 成功率計算
if [[ $TOTAL_TESTS -gt 0 ]]; then
    success_rate=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
    echo "  Success Rate: $success_rate%"
fi

# 終了コード
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi
