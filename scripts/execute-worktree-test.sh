#!/usr/bin/env bash
# Worktree統合テスト実行スクリプト
# 使い方: bash scripts/execute-worktree-test.sh [mvp|status|speed|full]

set -euo pipefail

# カラーコード
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# プロジェクトルート確認
if [[ ! -f "scripts/orchestrate/orchestrate-multi-ai.sh" ]]; then
    echo -e "${RED}エラー: プロジェクトルートで実行してください${NC}"
    exit 1
fi

# テストタイプ
TEST_TYPE="${1:-speed}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Git Worktrees統合テスト実行${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 環境クリーンアップ
echo -e "${YELLOW}1. 環境クリーンアップ中...${NC}"
git worktree prune -v 2>/dev/null || true
rm -rf worktrees/ 2>/dev/null || true
echo -e "${GREEN}✓ クリーンアップ完了${NC}"
echo ""

# mainブランチ確認
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" != "main" ]]; then
    echo -e "${YELLOW}警告: 現在のブランチは $current_branch です${NC}"
    echo -e "${YELLOW}mainブランチに切り替えますか？ (y/N): ${NC}"
    read -r confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        git checkout main
        echo -e "${GREEN}✓ mainブランチに切り替えました${NC}"
    fi
fi
echo ""

# テストタイプに応じて実行
case "$TEST_TYPE" in
    mvp)
        echo -e "${BLUE}2. MVP検証テスト実行中...${NC}"
        echo ""
        NON_INTERACTIVE=true bash scripts/worktree-mvp-validation.sh
        ;;

    status)
        echo -e "${BLUE}2. Worktreeステータス確認ツールテスト${NC}"
        echo ""
        ENABLE_WORKTREES=true bash scripts/orchestrate/lib/multi-ai-worktrees-status.sh
        ;;

    speed)
        echo -e "${BLUE}2. 高速プロトタイプ統合テスト実行中...${NC}"
        echo -e "${YELLOW}   実行時間: 約2-4分${NC}"
        echo ""

        # 監視コマンドを表示
        echo -e "${YELLOW}別ターミナルで監視する場合:${NC}"
        echo -e "  watch -n 1 'git worktree list'"
        echo ""
        sleep 3

        # 実行
        ENABLE_WORKTREES=true bash -c '
            source scripts/orchestrate/orchestrate-multi-ai.sh
            multi-ai-speed-prototype "Worktreeテスト: 各AIが自己紹介Markdownを作成"
        '
        ;;

    full)
        echo -e "${BLUE}2. 完全オーケストレーション統合テスト実行中...${NC}"
        echo -e "${YELLOW}   実行時間: 約5-8分${NC}"
        echo ""

        # 監視コマンドを表示
        echo -e "${YELLOW}別ターミナルで監視する場合:${NC}"
        echo -e "  watch -n 1 'git worktree list'"
        echo ""
        sleep 3

        # 実行
        ENABLE_WORKTREES=true bash -c '
            source scripts/orchestrate/orchestrate-multi-ai.sh
            multi-ai-full-orchestrate "Worktreeテスト: Git Worktree統合の完全検証レポート作成"
        '
        ;;

    *)
        echo -e "${RED}エラー: 不明なテストタイプ: $TEST_TYPE${NC}"
        echo ""
        echo "使い方: bash scripts/execute-worktree-test.sh [mvp|status|speed|full]"
        echo ""
        echo "テストタイプ:"
        echo "  mvp    - MVP検証スクリプト実行（基本動作確認）"
        echo "  status - Worktreeステータス確認ツール"
        echo "  speed  - 高速プロトタイプ統合テスト（推奨）"
        echo "  full   - 完全オーケストレーション統合テスト"
        exit 1
        ;;
esac

# 実行後の確認
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}テスト完了 - 結果確認${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${GREEN}3. 実行結果確認:${NC}"
echo ""

# Worktreeリスト
echo -e "${YELLOW}3-1. Worktreeリスト:${NC}"
if git worktree list 2>/dev/null; then
    echo ""
else
    echo "  （Worktreeなし - 自動クリーンアップ済み）"
    echo ""
fi

# Worktree状態ファイル
echo -e "${YELLOW}3-2. Worktree状態ファイル:${NC}"
if [[ -f "worktrees/.worktree-state.ndjson" ]]; then
    cat worktrees/.worktree-state.ndjson
    echo ""
else
    echo "  （状態ファイルなし）"
    echo ""
fi

# 生成ファイル
echo -e "${YELLOW}3-3. 生成ファイル:${NC}"
if [[ -d "logs/7ai-discussions" ]]; then
    ls -lart logs/7ai-discussions/ | tail -5
    echo ""
else
    echo "  （ディスカッションログなし）"
    echo ""
fi

# ログ
echo -e "${YELLOW}3-4. 最新ログ（最後の5行）:${NC}"
if [[ -d "logs/vibe/$(date +%Y%m%d)" ]]; then
    tail -5 logs/vibe/$(date +%Y%m%d)/*.jsonl 2>/dev/null | tail -5 || echo "  （ログファイルなし）"
    echo ""
else
    echo "  （ログディレクトリなし）"
    echo ""
fi

# Git status
echo -e "${YELLOW}3-5. Git Status:${NC}"
git status --short | head -10
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}テスト実行完了！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "詳細な手順書: WORKTREE_TEST_PROCEDURE.md"
echo ""
