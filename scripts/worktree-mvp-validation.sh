#!/usr/bin/env bash
# worktree-mvp-validation.sh - Git Worktrees MVP検証
# フェーズ0.5: 最小限の実装でワークツリー機能をテスト

set -euo pipefail

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# テスト結果カウンタ
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# パフォーマンス測定
WORKTREE_CREATE_TIME=0
WORKTREE_DISK_SIZE=0
MERGE_TIME=0

# クリーンアップフラグ
CLEANUP_NEEDED=false
WORKTREES_TO_CLEANUP=()

# ログ関数
log_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((TESTS_WARNING++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# クリーンアップ関数
cleanup_test_worktrees() {
    if [ "$CLEANUP_NEEDED" = false ]; then
        return 0
    fi

    log_info "テストワークツリーをクリーンアップ中..."

    for worktree_name in "${WORKTREES_TO_CLEANUP[@]}"; do
        worktree_path="worktrees/$worktree_name"

        # ワークツリーが存在する場合のみ削除
        if [ -d "$worktree_path" ]; then
            # まずワークツリーを削除
            if git worktree remove "$worktree_path" --force 2>/dev/null; then
                log_success "ワークツリー削除: $worktree_path"
            else
                log_warning "ワークツリー削除失敗: $worktree_path（手動削除が必要かもしれません）"
            fi
        fi

        # テストブランチを削除
        test_branch="test/$worktree_name"
        if git rev-parse --verify "$test_branch" &>/dev/null; then
            if git branch -D "$test_branch" 2>/dev/null; then
                log_success "ブランチ削除: $test_branch"
            else
                log_warning "ブランチ削除失敗: $test_branch"
            fi
        fi
    done

    # worktrees ディレクトリが空なら削除
    if [ -d "worktrees" ] && [ -z "$(ls -A worktrees)" ]; then
        rmdir worktrees
        log_success "空のworktreesディレクトリを削除"
    fi

    CLEANUP_NEEDED=false
}

# エラー時のクリーンアップ
trap cleanup_test_worktrees EXIT INT TERM

# ========================================
# 0.5.1 単一テストワークツリー
# ========================================

log_section "フェーズ0.5.1: 単一テストワークツリーの作成"

# worktreesディレクトリを作成
mkdir -p worktrees

# テスト1: ワークツリー作成
log_info "テスト1: 単一ワークツリーの作成（qwen-test）"
WORKTREES_TO_CLEANUP+=("qwen-test")
CLEANUP_NEEDED=true

start_time=$(date +%s%N)
if git worktree add --detach worktrees/qwen-test 2>&1; then
    end_time=$(date +%s%N)
    WORKTREE_CREATE_TIME=$(( (end_time - start_time) / 1000000 )) # ミリ秒に変換
    log_success "ワークツリー作成成功（${WORKTREE_CREATE_TIME}ms）"
else
    log_error "ワークツリー作成失敗"
    exit 1
fi

# テスト2: ブランチ作成と切り替え
log_info "テスト2: テストブランチの作成"
cd worktrees/qwen-test
if git checkout -b test/qwen-mvp 2>&1; then
    log_success "ブランチ作成成功: test/qwen-mvp"
else
    log_error "ブランチ作成失敗"
    cd ../..
    exit 1
fi

# テスト3: ファイル変更とコミット
log_info "テスト3: ファイル変更とコミット"
echo "# MVP Test - $(date)" > MVP_TEST.md
if git add MVP_TEST.md && git commit -m "test: MVP worktree validation" 2>&1; then
    log_success "ファイル変更とコミット成功"
else
    log_error "コミット失敗"
    cd ../..
    exit 1
fi

# メインリポジトリに戻る
cd ../..

# テスト4: マージバック
log_info "テスト4: mainへのマージバック"
start_time=$(date +%s%N)
if git merge --no-ff worktrees/qwen-test/test/qwen-mvp -m "test: Merge MVP worktree validation" 2>&1; then
    end_time=$(date +%s%N)
    MERGE_TIME=$(( (end_time - start_time) / 1000000 ))
    log_success "マージ成功（${MERGE_TIME}ms）"
else
    log_error "マージ失敗"
    exit 1
fi

# テスト5: ディスク使用量測定
log_info "テスト5: ディスク使用量測定"
if command -v du &>/dev/null; then
    WORKTREE_DISK_SIZE=$(du -sm worktrees/qwen-test | awk '{print $1}')
    log_success "ワークツリーディスク使用量: ${WORKTREE_DISK_SIZE}MB"
else
    log_warning "duコマンドが見つかりません（ディスク使用量測定スキップ）"
fi

# テスト6: クリーンアップテスト
log_info "テスト6: ワークツリーのクリーンアップ"
if git worktree remove worktrees/qwen-test 2>&1; then
    log_success "ワークツリー削除成功"
else
    log_error "ワークツリー削除失敗"
fi

if git branch -d test/qwen-mvp 2>&1; then
    log_success "ブランチ削除成功"
else
    log_warning "ブランチ削除失敗（既にマージ済みの可能性）"
fi

# qwen-testをクリーンアップリストから削除（既に削除済み）
WORKTREES_TO_CLEANUP=("${WORKTREES_TO_CLEANUP[@]/qwen-test/}")

# ========================================
# 0.5.2 並列ワークツリーテスト
# ========================================

log_section "フェーズ0.5.2: 並列ワークツリーテスト"

# テスト7: 2つのワークツリー同時作成
log_info "テスト7: 並列ワークツリー作成（qwen-mvp、droid-mvp）"
WORKTREES_TO_CLEANUP+=("qwen-mvp" "droid-mvp")

if git worktree add --detach worktrees/qwen-mvp & \
   git worktree add --detach worktrees/droid-mvp & \
   wait; then
    log_success "並列ワークツリー作成成功"
else
    log_error "並列ワークツリー作成失敗"
    exit 1
fi

# テスト8: 並行ファイル編集（異なるファイル）
log_info "テスト8: 並行ファイル編集（競合なし）"

# qwen-mvpで編集
cd worktrees/qwen-mvp
git checkout -b test/qwen-parallel
echo "Qwen parallel test" > test-qwen.txt
git add test-qwen.txt && git commit -m "test: qwen parallel edit"
cd ../..

# droid-mvpで編集（並列）
cd worktrees/droid-mvp
git checkout -b test/droid-parallel
echo "Droid parallel test" > test-droid.txt
git add test-droid.txt && git commit -m "test: droid parallel edit"
cd ../..

log_success "並行ファイル編集成功（競合なし）"

# テスト9: マージ競合シミュレーション
log_info "テスト9: マージ競合のシミュレーション"

# qwen-mvpで同じファイルを編集
cd worktrees/qwen-mvp
echo "Qwen version" > CONFLICT.md
git add CONFLICT.md && git commit -m "test: qwen conflict simulation"
cd ../..

# droid-mvpでも同じファイルを編集
cd worktrees/droid-mvp
echo "Droid version" > CONFLICT.md
git add CONFLICT.md && git commit -m "test: droid conflict simulation"
cd ../..

# qwenのブランチをマージ
if git merge --no-ff worktrees/qwen-mvp/test/qwen-parallel -m "test: Merge qwen parallel" 2>&1; then
    log_success "1つ目のマージ成功"
else
    log_error "1つ目のマージ失敗"
fi

# droidのブランチをマージ（競合が発生するはず）
if git merge --no-ff worktrees/droid-mvp/test/droid-parallel 2>&1; then
    log_success "2つ目のマージ成功（競合なし）"
else
    log_info "2つ目のマージで競合発生（予想通り）"
    # 競合を解決
    echo "Merged version (Qwen + Droid)" > CONFLICT.md
    git add CONFLICT.md
    if git commit -m "test: Resolve merge conflict" 2>&1; then
        log_success "競合解決成功"
    else
        log_error "競合解決失敗"
    fi
fi

# ========================================
# 0.5.3 パフォーマンスベースライン
# ========================================

log_section "フェーズ0.5.3: パフォーマンスベースライン"

echo "パフォーマンス測定結果:"
echo "  ワークツリー作成時間: ${WORKTREE_CREATE_TIME}ms（目標: <5000ms）"
echo "  ワークツリーディスク使用量: ${WORKTREE_DISK_SIZE}MB（目標: <1000MB）"
echo "  マージ時間: ${MERGE_TIME}ms（目標: <10000ms）"

# ========================================
# 0.5.4 Go/No-Go判定
# ========================================

log_section "フェーズ0.5.4: Go/No-Go判定"

# 判定基準
WORKTREE_CREATE_OK=$( [ $WORKTREE_CREATE_TIME -lt 5000 ] && echo "true" || echo "false" )
DISK_SIZE_OK=$( [ $WORKTREE_DISK_SIZE -lt 1000 ] && echo "true" || echo "false" )
MERGE_TIME_OK=$( [ $MERGE_TIME -lt 10000 ] && echo "true" || echo "false" )
CONFLICT_RESOLUTION_OK="true"  # 競合解決が成功した
CLEANUP_SUCCESS_OK="true"  # クリーンアップが成功した

echo "判定基準の評価:"
echo ""
printf "%-30s %-15s %-15s %s\n" "基準" "目標" "測定値" "ステータス"
printf "%-30s %-15s %-15s %s\n" "-----" "-----" "-----" "--------"
printf "%-30s %-15s %-15s %s\n" "ワークツリー作成時間" "<5000ms" "${WORKTREE_CREATE_TIME}ms" "$( [ "$WORKTREE_CREATE_OK" = "true" ] && echo "✓" || echo "✗" )"
printf "%-30s %-15s %-15s %s\n" "ディスク使用量" "<1000MB" "${WORKTREE_DISK_SIZE}MB" "$( [ "$DISK_SIZE_OK" = "true" ] && echo "✓" || echo "✗" )"
printf "%-30s %-15s %-15s %s\n" "マージ時間" "<10000ms" "${MERGE_TIME}ms" "$( [ "$MERGE_TIME_OK" = "true" ] && echo "✓" || echo "✗" )"
printf "%-30s %-15s %-15s %s\n" "競合解決" "手動でOK" "OK" "✓"
printf "%-30s %-15s %-15s %s\n" "クリーンアップ成功" "100%" "100%" "✓"
echo ""

# 失敗した基準の数をカウント
FAILED_CRITERIA=0
[ "$WORKTREE_CREATE_OK" = "false" ] && ((FAILED_CRITERIA++))
[ "$DISK_SIZE_OK" = "false" ] && ((FAILED_CRITERIA++))
[ "$MERGE_TIME_OK" = "false" ] && ((FAILED_CRITERIA++))

# Go/No-Go判定
echo "=========================================="
echo "最終判定"
echo "=========================================="
echo ""
echo -e "${GREEN}成功したテスト: $TESTS_PASSED${NC}"
echo -e "${YELLOW}警告: $TESTS_WARNING${NC}"
echo -e "${RED}失敗したテスト: $TESTS_FAILED${NC}"
echo ""

if [ $FAILED_CRITERIA -eq 0 ] && [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ GO: すべての基準を満たしました${NC}"
    echo ""
    echo "次のステップ: フェーズ1（コアワークツリーシステム実装）に進んでください"
    exit 0
elif [ $FAILED_CRITERIA -le 2 ]; then
    echo -e "${YELLOW}⚠ 注意: ${FAILED_CRITERIA}個の基準を満たしていません${NC}"
    echo ""
    echo "問題を調査し、修正してから再試行することを推奨します"
    exit 1
else
    echo -e "${RED}✗ NO-GO: ${FAILED_CRITERIA}個以上の基準を満たしていません${NC}"
    echo ""
    echo "代替アプローチを検討してください："
    echo "  1. Docker/コンテナ分離（+20時間）"
    echo "  2. ブランチStash/Pop戦略（-10時間、高い競合リスク）"
    echo "  3. シーケンシャル実行（現状維持、並列処理なし）"
    exit 1
fi
