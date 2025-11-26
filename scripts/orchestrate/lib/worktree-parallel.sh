#!/usr/bin/env bash
#
# worktree-parallel.sh - Parallel Worktree Operations for Multi-AI System
#
# Purpose: Optimize parallel worktree creation/cleanup with 75% speedup
#
# Team: A (Qwen + Droid)
# Created: 2025-11-12 (Day 3)
# Dependencies: worktree-manager.sh, vibe-logger-lib.sh
#
# Performance Goals:
#   - Parallel creation: 28s → 7s (75% speedup)
#   - 7 concurrent worktrees supported
#   - GNU parallel or xargs-based fallback
#
# API:
#   create_worktrees_parallel <ai1> <ai2> ... <aiN>
#   cleanup_worktrees_parallel <ai1> <ai2> ... <aiN>
#

set -euo pipefail

# =========================================
# Dependencies
# =========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source required libraries
source "$SCRIPT_DIR/worktree-manager.sh"
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"

# =========================================
# Configuration
# =========================================

# Parallel execution settings
PARALLEL_JOBS="${PARALLEL_JOBS:-7}"  # Default: 7 parallel jobs (one per AI)
PARALLEL_TIMEOUT="${PARALLEL_TIMEOUT:-300}"  # 5 minutes per worktree

# Fallback mode (if GNU parallel not available)
USE_XARGS_FALLBACK="${USE_XARGS_FALLBACK:-auto}"  # auto | always | never

# =========================================
# Utility Functions
# =========================================

# Check if GNU parallel is available
check_parallel_available() {
    if command -v parallel >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Determine execution mode (parallel vs xargs)
get_parallel_mode() {
    if [[ "$USE_XARGS_FALLBACK" == "never" ]]; then
        echo "parallel"
        return 0
    fi

    if [[ "$USE_XARGS_FALLBACK" == "always" ]]; then
        echo "xargs"
        return 0
    fi

    # Auto-detect
    if check_parallel_available; then
        echo "parallel"
    else
        echo "xargs"
    fi
}

# =========================================
# Parallel Worktree Creation
# =========================================

# Create multiple worktrees in parallel
#
# Usage: create_worktrees_parallel <ai1> <ai2> ... <aiN>
#
# Args:
#   ai1, ai2, ..., aiN: AI names (e.g., qwen, droid, codex)
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   create_worktrees_parallel qwen droid codex
#   # Creates 3 worktrees in parallel (3 jobs)
#
# Performance:
#   - Sequential: 7 AIs × 4s = 28s
#   - Parallel (7 jobs): max(4s) = 4-7s (75% speedup)
#
create_worktrees_parallel() {
    local ais=("$@")
    local mode
    local start_time
    local end_time
    local duration

    if [[ ${#ais[@]} -eq 0 ]]; then
        echo "ERROR [PARALLEL_CREATE]: No AI names provided" >&2
        return 1
    fi

    mode=$(get_parallel_mode)
    start_time=$(date +%s)

    vibe_log "worktree-parallel" "create-start" \
        "{\"ai_count\": ${#ais[@]}, \"mode\": \"$mode\", \"jobs\": $PARALLEL_JOBS}" \
        "Starting parallel worktree creation for ${#ais[@]} AIs" \
        "{\"next\": [\"monitor\", \"merge\"]}" \
        "worktree-parallel"

    # Execute parallel creation based on mode
    local exit_code=0
    if [[ "$mode" == "parallel" ]]; then
        _create_worktrees_gnu_parallel "${ais[@]}" || exit_code=$?
    else
        _create_worktrees_xargs "${ais[@]}" || exit_code=$?
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        vibe_log "worktree-parallel" "create-success" \
            "{\"ai_count\": ${#ais[@]}, \"duration\": $duration, \"mode\": \"$mode\"}" \
            "Parallel worktree creation completed in ${duration}s" \
            "{\"action\": \"proceed\"}" \
            "worktree-parallel"
    else
        vibe_log "worktree-parallel" "create-failure" \
            "{\"ai_count\": ${#ais[@]}, \"duration\": $duration, \"exit_code\": $exit_code}" \
            "Parallel worktree creation failed after ${duration}s" \
            "{\"action\": \"investigate\", \"rollback\": true}" \
            "worktree-parallel"
    fi

    return $exit_code
}

# Internal: Create worktrees using GNU parallel
_create_worktrees_gnu_parallel() {
    local ais=("$@")

    printf '%s\n' "${ais[@]}" | \
        parallel --jobs "$PARALLEL_JOBS" \
                 --timeout "$PARALLEL_TIMEOUT" \
                 --halt soon,fail=1 \
                 --line-buffer \
                 "_create_single_worktree {}"
}

# Internal: Create worktrees using xargs (fallback)
_create_worktrees_xargs() {
    local ais=("$@")
    local failed=0

    printf '%s\n' "${ais[@]}" | \
        xargs -n 1 -P "$PARALLEL_JOBS" -I {} \
            bash -c "_create_single_worktree {}" || failed=$?

    return $failed
}

# Internal: Create single worktree (called by parallel/xargs)
_create_single_worktree() {
    local ai="$1"
    local branch="feature/${ai}-parallel-$(date +%s)"
    local task_id="${ai}-task-$(date +%Y%m%d%H%M%S)"
    local worktree_path

    echo "Creating worktree for $ai..."

    # Call worktree-manager.sh API
    if worktree_path=$(create_worktree "$ai" "$branch" "$task_id"); then
        echo "✅ Worktree created for $ai: $worktree_path"
        return 0
    else
        echo "❌ Failed to create worktree for $ai" >&2
        return 1
    fi
}

# Export for parallel/xargs subshells
export -f _create_single_worktree
export -f create_worktree
export -f sanitize_worktree_input
# Note: sanitize_input from sanitize.sh is sourced by worktree-manager.sh
export SCRIPT_DIR
export PROJECT_ROOT

# =========================================
# Parallel Worktree Cleanup
# =========================================

# Cleanup multiple worktrees in parallel
#
# Usage: cleanup_worktrees_parallel <ai1> <ai2> ... <aiN>
#
# Args:
#   ai1, ai2, ..., aiN: AI names (e.g., qwen, droid, codex)
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   cleanup_worktrees_parallel qwen droid codex
#
cleanup_worktrees_parallel() {
    local ais=("$@")
    local mode
    local start_time
    local end_time
    local duration

    if [[ ${#ais[@]} -eq 0 ]]; then
        echo "ERROR [PARALLEL_CLEANUP]: No AI names provided" >&2
        return 1
    fi

    mode=$(get_parallel_mode)
    start_time=$(date +%s)

    vibe_log "worktree-parallel" "cleanup-start" \
        "{\"ai_count\": ${#ais[@]}, \"mode\": \"$mode\"}" \
        "Starting parallel worktree cleanup for ${#ais[@]} AIs" \
        "{\"next\": [\"verify\"]}" \
        "worktree-parallel"

    # Execute parallel cleanup based on mode
    local exit_code=0
    if [[ "$mode" == "parallel" ]]; then
        _cleanup_worktrees_gnu_parallel "${ais[@]}" || exit_code=$?
    else
        _cleanup_worktrees_xargs "${ais[@]}" || exit_code=$?
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        vibe_log "worktree-parallel" "cleanup-success" \
            "{\"ai_count\": ${#ais[@]}, \"duration\": $duration}" \
            "Parallel worktree cleanup completed in ${duration}s" \
            "{\"action\": \"done\"}" \
            "worktree-parallel"
    else
        vibe_log "worktree-parallel" "cleanup-failure" \
            "{\"ai_count\": ${#ais[@]}, \"duration\": $duration, \"exit_code\": $exit_code}" \
            "Parallel worktree cleanup failed after ${duration}s" \
            "{\"action\": \"manual-cleanup\"}" \
            "worktree-parallel"
    fi

    return $exit_code
}

# Internal: Cleanup worktrees using GNU parallel
_cleanup_worktrees_gnu_parallel() {
    local ais=("$@")

    printf '%s\n' "${ais[@]}" | \
        parallel --jobs "$PARALLEL_JOBS" \
                 --timeout "$PARALLEL_TIMEOUT" \
                 --line-buffer \
                 "_cleanup_single_worktree {}"
}

# Internal: Cleanup worktrees using xargs (fallback)
_cleanup_worktrees_xargs() {
    local ais=("$@")
    local failed=0

    printf '%s\n' "${ais[@]}" | \
        xargs -n 1 -P "$PARALLEL_JOBS" -I {} \
            bash -c "_cleanup_single_worktree {}" || failed=$?

    return $failed
}

# Internal: Cleanup single worktree (called by parallel/xargs)
_cleanup_single_worktree() {
    local ai="$1"
    local task_id="${ai}-task-*"  # Wildcard pattern

    echo "Cleaning up worktree for $ai..."

    # Call worktree-manager.sh API
    if cleanup_worktree "$ai" "$task_id" "true"; then
        echo "✅ Worktree cleaned up for $ai"
        return 0
    else
        echo "❌ Failed to cleanup worktree for $ai" >&2
        return 1
    fi
}

# Export for parallel/xargs subshells
export -f _cleanup_single_worktree
export -f cleanup_worktree

# =========================================
# Status and Monitoring
# =========================================

# List parallel worktree creation status
#
# Usage: list_parallel_worktrees
#
# Output: JSON array of active worktrees
#
list_parallel_worktrees() {
    list_active_worktrees
}

# =========================================
# Performance Benchmarking
# =========================================

# Benchmark parallel vs sequential worktree creation
#
# Usage: benchmark_parallel_creation <ai_count>
#
# Args:
#   ai_count: Number of AIs to test (default: 7)
#
# Example:
#   benchmark_parallel_creation 7
#
benchmark_parallel_creation() {
    local ai_count="${1:-7}"
    local test_ais=()
    local i
    local seq_start
    local seq_end
    local par_start
    local par_end
    local seq_duration
    local par_duration
    local speedup

    # Generate test AI names
    for ((i=1; i<=ai_count; i++)); do
        test_ais+=("test-ai-$i")
    done

    echo "Benchmarking Worktree Creation..."
    echo "AI Count: $ai_count"
    echo "---"

    # Sequential benchmark
    echo "Running sequential creation..."
    seq_start=$(date +%s%3N)
    for ai in "${test_ais[@]}"; do
        _create_single_worktree "$ai" >/dev/null 2>&1
    done
    seq_end=$(date +%s%3N)
    seq_duration=$((seq_end - seq_start))

    # Cleanup
    for ai in "${test_ais[@]}"; do
        _cleanup_single_worktree "$ai" >/dev/null 2>&1
    done

    # Parallel benchmark
    echo "Running parallel creation..."
    par_start=$(date +%s%3N)
    create_worktrees_parallel "${test_ais[@]}" >/dev/null 2>&1
    par_end=$(date +%s%3N)
    par_duration=$((par_end - par_start))

    # Cleanup
    cleanup_worktrees_parallel "${test_ais[@]}" >/dev/null 2>&1

    # Results
    speedup=$((100 - (par_duration * 100 / seq_duration)))

    echo "---"
    echo "Results:"
    echo "  Sequential: ${seq_duration}ms"
    echo "  Parallel:   ${par_duration}ms"
    echo "  Speedup:    ${speedup}%"

    vibe_log "worktree-parallel" "benchmark" \
        "{\"ai_count\": $ai_count, \"seq_ms\": $seq_duration, \"par_ms\": $par_duration, \"speedup_pct\": $speedup}" \
        "Benchmark: ${speedup}% speedup achieved" \
        "{\"target_speedup\": 75}" \
        "worktree-parallel"
}

# =========================================
# Module Info
# =========================================

# Display module information
worktree_parallel_info() {
    cat <<EOF
worktree-parallel.sh - Parallel Worktree Operations

Version: 1.0.0
Team: A (Qwen + Droid)
Created: 2025-11-12 (Day 3)

API Functions:
  create_worktrees_parallel <ai1> <ai2> ... <aiN>
  cleanup_worktrees_parallel <ai1> <ai2> ... <aiN>
  list_parallel_worktrees
  benchmark_parallel_creation [ai_count]

Performance:
  Target Speedup: 75% (28s → 7s for 7 AIs)
  Parallel Jobs: $PARALLEL_JOBS
  Mode: $(get_parallel_mode)

Dependencies:
  - worktree-manager.sh (create/merge/cleanup)
  - vibe-logger-lib.sh (audit logging)
  - GNU parallel (optional, xargs fallback available)
EOF
}

# =========================================
# Module Initialization
# =========================================

# Validate dependencies
if ! command -v parallel >/dev/null 2>&1; then
    if [[ "$USE_XARGS_FALLBACK" == "never" ]]; then
        echo "ERROR: GNU parallel not found and fallback disabled" >&2
        exit 1
    else
        echo "WARNING: GNU parallel not found, using xargs fallback" >&2
    fi
fi

# End of worktree-parallel.sh
