#!/usr/bin/env bash
# Debug worktree test script with verbose output

set -euo pipefail

cd /home/ryu/projects/multi-ai-orchestrium

export ENABLE_WORKTREES=true
export PROJECT_ROOT="$PWD"

echo "DEBUG: Starting test"
echo "DEBUG: PWD=$PWD"
echo "DEBUG: ENABLE_WORKTREES=$ENABLE_WORKTREES"
echo ""

echo "=== Step 1: Sourcing orchestrate-multi-ai.sh ==="
if source scripts/orchestrate/orchestrate-multi-ai.sh; then
    echo "DEBUG: Source completed successfully"
else
    echo "DEBUG: Source failed with code $?"
    exit 1
fi

echo "DEBUG: After source, still here"
echo ""

echo "=== Step 2: Checking function exists ==="
if type multi-ai-speed-prototype >/dev/null 2>&1; then
    echo "DEBUG: Function multi-ai-speed-prototype exists"
else
    echo "DEBUG: Function multi-ai-speed-prototype NOT FOUND"
    exit 1
fi
echo ""

echo "=== Step 3: Executing multi-ai-speed-prototype ==="
echo "DEBUG: About to call function..."
multi-ai-speed-prototype "Worktreeテスト: 各AIが1行で自己紹介"
RESULT=$?

echo ""
echo "DEBUG: Function returned with code $RESULT"
echo "DEBUG: Test completed"
