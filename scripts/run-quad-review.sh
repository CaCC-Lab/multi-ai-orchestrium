#!/usr/bin/env bash
# Quad Review実行スクリプト - バックグラウンド実行対応

set -euo pipefail

cd /home/ryu/projects/multi-ai-orchestrium

export ENABLE_WORKTREES=true
export PROJECT_ROOT="$PWD"

LOGFILE="/tmp/quad-review-$(date +%Y%m%d-%H%M%S).log"

echo "============================================"
echo "Quad Review実行開始"
echo "対象: Git Worktrees統合実装（コミット96d484e）"
echo "ログファイル: $LOGFILE"
echo "============================================"
echo ""

echo "推定所要時間: 約30分"
echo "  - Phase 1: 4ツール自動レビュー（並列）: 15分"
echo "  - Phase 2: 6AI協調分析（並列）: 10分"
echo "  - Phase 3: 統合レポート生成: 5分"
echo ""

# バックグラウンドで実行
{
    source scripts/orchestrate/orchestrate-multi-ai.sh
    multi-ai-quad-review "Git Worktrees統合実装の包括的レビュー（コミット96d484e）- セキュリティ、品質、エンタープライズ基準の徹底検証"
} > "$LOGFILE" 2>&1 &

PID=$!

echo "✓ Quad Review開始（PID: $PID）"
echo ""
echo "監視コマンド:"
echo "  tail -f $LOGFILE"
echo ""
echo "進捗確認:"
echo "  grep '━━━' $LOGFILE"
echo ""
echo "完了確認:"
echo "  grep '✅' $LOGFILE | tail -5"
echo ""
echo "レポート場所:"
echo "  find logs/multi-ai-reviews -name 'QUAD_REVIEW_REPORT.md' -newer $LOGFILE"
echo ""
