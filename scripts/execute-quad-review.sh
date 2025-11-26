#!/usr/bin/env bash
# Quad Review実行スクリプト - Git Worktrees統合実装のレビュー

set -euo pipefail

cd /home/ryu/projects/multi-ai-orchestrium

export ENABLE_WORKTREES=true
export PROJECT_ROOT="$PWD"

echo "============================================"
echo "Quad Review実行開始"
echo "対象: Git Worktrees統合実装"
echo "コミット: 96d484e"
echo "============================================"
echo ""

echo "Step 1: Sourcing orchestrate-multi-ai.sh..."
source scripts/orchestrate/orchestrate-multi-ai.sh

echo "Step 2: Executing multi-ai-quad-review..."
echo ""

multi-ai-quad-review "Git Worktrees統合実装の包括的レビュー（コミット96d484e）- セキュリティ、品質、エンタープライズ基準の徹底検証"

echo ""
echo "============================================"
echo "Quad Review完了"
echo "============================================"
