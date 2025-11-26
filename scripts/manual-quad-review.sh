#!/usr/bin/env bash
# Manual Quad Review - trap問題回避のため4つのレビューを個別実行

set -euo pipefail

cd /home/ryu/projects/multi-ai-orchestrium

export PROJECT_ROOT="$PWD"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
WORK_DIR="logs/multi-ai-reviews/$TIMESTAMP-manual-quad-review"
mkdir -p "$WORK_DIR"

echo "============================================"
echo "Manual Quad Review実行"
echo "対象: Git Worktrees統合実装（コミット96d484e）"
echo "作業ディレクトリ: $WORK_DIR"
echo "============================================"
echo ""

# Phase 1: 4つの自動レビューを順次実行
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: 4ツール自動レビュー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Codex Review
echo "[1/4] Codex Review実行中..."
CODEX_OUTPUT_DIR="$WORK_DIR/codex"
mkdir -p "$CODEX_OUTPUT_DIR"
if CODEX_REVIEW_TIMEOUT=600 OUTPUT_DIR="$CODEX_OUTPUT_DIR" bash scripts/codex-review.sh > "$CODEX_OUTPUT_DIR/execution.log" 2>&1; then
    echo "✓ Codex Review完了"
else
    echo "⚠ Codex Review失敗（継続）"
fi
echo ""

# 2. CodeRabbit Review
echo "[2/4] CodeRabbit Review実行中..."
CODERABBIT_OUTPUT_DIR="$WORK_DIR/coderabbit"
mkdir -p "$CODERABBIT_OUTPUT_DIR"
if CODERABBIT_REVIEW_TIMEOUT=900 OUTPUT_DIR="$CODERABBIT_OUTPUT_DIR" bash scripts/coderabbit-review.sh > "$CODERABBIT_OUTPUT_DIR/execution.log" 2>&1; then
    echo "✓ CodeRabbit Review完了"
else
    echo "⚠ CodeRabbit Review失敗（継続）"
fi
echo ""

# 3. Claude Comprehensive Review
echo "[3/4] Claude Comprehensive Review実行中..."
CLAUDE_COMP_OUTPUT_DIR="$WORK_DIR/claude_comprehensive"
mkdir -p "$CLAUDE_COMP_OUTPUT_DIR"
if CLAUDE_REVIEW_TIMEOUT=600 OUTPUT_DIR="$CLAUDE_COMP_OUTPUT_DIR" bash scripts/claude-review.sh > "$CLAUDE_COMP_OUTPUT_DIR/execution.log" 2>&1; then
    echo "✓ Claude Comprehensive Review完了"
else
    echo "⚠ Claude Comprehensive Review失敗（継続）"
fi
echo ""

# 4. Claude Security Review
echo "[4/4] Claude Security Review実行中..."
CLAUDE_SEC_OUTPUT_DIR="$WORK_DIR/claude_security"
mkdir -p "$CLAUDE_SEC_OUTPUT_DIR"
if CLAUDE_SECURITY_REVIEW_TIMEOUT=900 OUTPUT_DIR="$CLAUDE_SEC_OUTPUT_DIR" bash scripts/claude-security-review.sh > "$CLAUDE_SEC_OUTPUT_DIR/execution.log" 2>&1; then
    echo "✓ Claude Security Review完了"
else
    echo "⚠ Claude Security Review失敗（継続）"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1完了: 4ツール自動レビュー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# レビュー結果の集計
echo "レビュー結果サマリー:"
echo ""
for review_dir in "$WORK_DIR"/*; do
    if [ -d "$review_dir" ]; then
        review_name=$(basename "$review_dir")
        md_file=$(find "$review_dir" -name "*.md" -type f ! -name "latest_*" | head -1)
        if [ -f "$md_file" ]; then
            echo "✓ $review_name: $(wc -l < "$md_file") 行"
        else
            echo "⚠ $review_name: 結果ファイルなし"
        fi
    fi
done
echo ""

echo "============================================"
echo "Manual Quad Review完了"
echo "作業ディレクトリ: $WORK_DIR"
echo "============================================"
echo ""

# レビューファイル一覧表示
echo "生成されたレビューファイル:"
find "$WORK_DIR" -name "*.md" -type f ! -name "latest_*"
