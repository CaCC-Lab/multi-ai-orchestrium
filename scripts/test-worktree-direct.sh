#!/usr/bin/env bash
# Direct worktree test script

set -euo pipefail

cd /home/ryu/projects/multi-ai-orchestrium

export ENABLE_WORKTREES=true
export PROJECT_ROOT="$PWD"

echo "=== Sourcing orchestrate-multi-ai.sh ==="
source scripts/orchestrate/orchestrate-multi-ai.sh

echo ""
echo "=== Executing multi-ai-speed-prototype ==="
multi-ai-speed-prototype "Worktreeテスト: 各AIが1行で自己紹介"
