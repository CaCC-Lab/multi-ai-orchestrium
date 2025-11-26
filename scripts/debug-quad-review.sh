#!/usr/bin/env bash
# Debug Quad Review with verbose output

set -x  # Enable debug output
set -euo pipefail

cd /home/ryu/projects/multi-ai-orchestrium

export ENABLE_WORKTREES=true
export PROJECT_ROOT="$PWD"

echo "=== DEBUG: Starting Quad Review Debug ==="
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

echo ""
echo "=== Step 2: Checking function exists ==="
if type multi-ai-quad-review >/dev/null 2>&1; then
    echo "DEBUG: Function multi-ai-quad-review exists"
else
    echo "DEBUG: Function multi-ai-quad-review NOT FOUND"
    exit 1
fi

echo ""
echo "=== Step 3: Checking dependencies ==="
echo "DEBUG: Checking sanitize_input function..."
if type sanitize_input >/dev/null 2>&1; then
    echo "DEBUG: sanitize_input found"
else
    echo "DEBUG: sanitize_input NOT FOUND"
fi

echo "DEBUG: Checking get_timestamp_ms function..."
if type get_timestamp_ms >/dev/null 2>&1; then
    echo "DEBUG: get_timestamp_ms found"
else
    echo "DEBUG: get_timestamp_ms NOT FOUND"
fi

echo ""
echo "=== Step 4: Executing multi-ai-quad-review ==="
echo "DEBUG: About to call function..."

# Call with error handling
if multi-ai-quad-review "Quad Review Debug Test"; then
    RESULT=$?
    echo "DEBUG: Function returned successfully with code $RESULT"
else
    RESULT=$?
    echo "DEBUG: Function failed with code $RESULT"
    exit $RESULT
fi

echo ""
echo "DEBUG: Quad Review debug completed"
