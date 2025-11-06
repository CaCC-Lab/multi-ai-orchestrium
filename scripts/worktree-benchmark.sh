#!/usr/bin/env bash
#
# worktree-benchmark.sh
# Phase 3.2: GNU Parallel vs 基本的な並列処理のベンチマーク
#
# Usage:
#   bash scripts/worktree-benchmark.sh
#

set -euo pipefail

# プロジェクトルートを検出
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# worktree-core.shをソース
source "$PROJECT_ROOT/scripts/orchestrate/lib/worktree-core.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Worktree並列処理ベンチマーク"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 前提条件チェック
if ! command -v hyperfine &>/dev/null; then
  echo "警告: hyperfineが見つかりません"
  echo "インストール: brew install hyperfine  # または cargo install hyperfine"
  echo ""
  echo "基本的な時間測定にフォールバックします..."
  echo ""

  # 基本的な時間測定
  echo "━━━ テスト1: 基本的な並列処理 ━━━"
  time create_all_worktrees
  cleanup_all_worktrees

  echo ""
  echo "━━━ テスト2: GNU Parallel統合 ━━━"
  time create_all_worktrees_parallel
  cleanup_all_worktrees

  exit 0
fi

# GNU Parallelが利用可能かチェック
if ! command -v parallel &>/dev/null; then
  echo "警告: GNU Parallelが見つかりません"
  echo "インストール: brew install parallel  # または sudo apt install parallel"
  echo ""
  echo "基本的な並列処理のみテストします..."
  hyperfine --warmup 1 \
    --prepare 'cleanup_all_worktrees' \
    --cleanup 'cleanup_all_worktrees' \
    'create_all_worktrees'
  exit 0
fi

# hyperfineでベンチマーク
echo "hyperfineを使用したベンチマーク実行中..."
echo "（各実装を10回実行して統計を取得）"
echo ""

hyperfine \
  --warmup 1 \
  --runs 10 \
  --prepare 'cleanup_all_worktrees' \
  --cleanup 'cleanup_all_worktrees' \
  --export-markdown "$PROJECT_ROOT/logs/worktree-benchmark-results.md" \
  --export-json "$PROJECT_ROOT/logs/worktree-benchmark-results.json" \
  'create_all_worktrees' \
  'create_all_worktrees_parallel'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ベンチマーク結果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Markdown結果: logs/worktree-benchmark-results.md"
echo "JSON結果: logs/worktree-benchmark-results.json"
echo ""

# 結果を表示
if [[ -f "$PROJECT_ROOT/logs/worktree-benchmark-results.md" ]]; then
  cat "$PROJECT_ROOT/logs/worktree-benchmark-results.md"
fi
