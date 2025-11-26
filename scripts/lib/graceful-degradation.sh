#!/usr/bin/env bash
# graceful-degradation.sh - Graceful Degradation Controller
# Phase 4 Tier 2 Task 6: Error Recovery Granularity Improvement
#
# Manages AI failover order and mode switching for graceful degradation
# when workflow execution encounters failures.

set -euo pipefail

# Source dependencies
_GRACEFUL_DEGRADATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$_GRACEFUL_DEGRADATION_DIR/../.." && pwd)}"

source "${PROJECT_ROOT}/scripts/lib/sanitize.sh" 2>/dev/null || true
source "${PROJECT_ROOT}/bin/vibe-logger-lib.sh" 2>/dev/null || true

# Configuration
FAILOVER_ORDER=("claude" "gemini" "amp" "qwen" "droid" "codex" "cursor")
EXECUTION_MODES=("parallel" "sequential" "single-ai")
TIMEOUT_EXTENSION_FACTOR="${TIMEOUT_EXTENSION_FACTOR:-0.5}"  # 50% extension per retry

# Current state
declare -g CURRENT_MODE="parallel"
declare -g CURRENT_FAILOVER_INDEX=0
declare -g CURRENT_TIMEOUT_MULTIPLIER=1.0

# ============================================================
# Core Functions
# ============================================================

# get_next_failover_ai(current_ai)
# Gets the next AI in failover order
#
# Arguments:
#   $1 - Current AI name
# Outputs: Next AI name in failover order
# Returns: 0 on success, 1 if no more AIs available
get_next_failover_ai() {
    local current_ai="$1"
    local current_index=-1
    
    # Find current AI index
    for i in "${!FAILOVER_ORDER[@]}"; do
        if [[ "${FAILOVER_ORDER[$i]}" == "$current_ai" ]]; then
            current_index=$i
            break
        fi
    done
    
    # If not found, start from beginning
    if [[ $current_index -eq -1 ]]; then
        current_index=0
    fi
    
    # Get next AI
    local next_index=$((current_index + 1))
    if [[ $next_index -lt ${#FAILOVER_ORDER[@]} ]]; then
        echo "${FAILOVER_ORDER[$next_index]}"
        return 0
    fi
    
    # No more AIs available
    return 1
}

# switch_execution_mode(current_mode, failure_count)
# Switches execution mode based on failure count
#
# Arguments:
#   $1 - Current execution mode
#   $2 - Failure count
# Outputs: New execution mode
# Returns: 0 on success
switch_execution_mode() {
    local current_mode="$1"
    local failure_count="${2:-0}"
    
    local new_mode="$current_mode"
    
    # Mode switching logic:
    # - parallel → sequential (after 2 failures)
    # - sequential → single-ai (after 3 failures)
    case "$current_mode" in
        "parallel")
            if [[ $failure_count -ge 2 ]]; then
                new_mode="sequential"
            fi
            ;;
        "sequential")
            if [[ $failure_count -ge 3 ]]; then
                new_mode="single-ai"
            fi
            ;;
        "single-ai")
            # Already in single-AI mode, no further degradation
            ;;
    esac
    
    # Log mode switch
    if [[ "$new_mode" != "$current_mode" ]]; then
        if declare -f vibe_log >/dev/null 2>&1; then
            vibe_log "graceful_degradation" "mode_switch" \
                "{\"old_mode\": \"$current_mode\", \"new_mode\": \"new_mode\", \"failure_count\": $failure_count}" \
                "Execution mode switched: $current_mode → $new_mode (failures: $failure_count)" \
                "[]" \
                "graceful-degradation"
        fi
    fi
    
    CURRENT_MODE="$new_mode"
    echo "$new_mode"
    return 0
}

# adjust_timeout(base_timeout, retry_count)
# Adjusts timeout dynamically based on retry count
#
# Arguments:
#   $1 - Base timeout in seconds
#   $2 - Retry count
# Outputs: Adjusted timeout in seconds
# Returns: 0 on success
adjust_timeout() {
    local base_timeout="$1"
    local retry_count="${2:-0}"
    
    # Calculate timeout multiplier: base_timeout × (1 + retry_count × 0.5)
    local multiplier
    multiplier=$(awk "BEGIN {printf \"%.2f\", 1 + $retry_count * $TIMEOUT_EXTENSION_FACTOR}")
    
    local adjusted_timeout
    adjusted_timeout=$(awk "BEGIN {printf \"%.0f\", $base_timeout * $multiplier}")
    
    CURRENT_TIMEOUT_MULTIPLIER="$multiplier"
    
    # Log timeout adjustment
    if declare -f vibe_log >/dev/null 2>&1; then
        vibe_log "graceful_degradation" "timeout_adjusted" \
            "{\"base_timeout\": $base_timeout, \"retry_count\": $retry_count, \"multiplier\": $multiplier, \"adjusted_timeout\": $adjusted_timeout}" \
            "Timeout adjusted: ${base_timeout}s × $multiplier = ${adjusted_timeout}s (retry: $retry_count)" \
            "[]" \
            "graceful-degradation"
    fi
    
    echo "$adjusted_timeout"
    return 0
}

# execute_with_failover(primary_ai, command, [args...])
# Executes command with automatic failover
#
# Arguments:
#   $1 - Primary AI name
#   $2 - Command to execute
#   $3+ - Command arguments
# Returns: Exit code of successful execution, 1 if all failovers exhausted
execute_with_failover() {
    local primary_ai="$1"
    shift
    local command=("$@")
    
    local current_ai="$primary_ai"
    local attempt=0
    local max_attempts=${#FAILOVER_ORDER[@]}
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Log failover attempt
        if declare -f vibe_log >/dev/null 2>&1; then
            vibe_log "graceful_degradation" "failover_attempt" \
                "{\"ai\": \"$current_ai\", \"attempt\": $attempt, \"max_attempts\": $max_attempts}" \
                "Failover attempt $attempt: using AI $current_ai" \
                "[]" \
                "graceful-degradation"
        fi
        
        # Execute command (simplified - actual implementation would call AI)
        if "${command[@]}"; then
            # Success
            if declare -f vibe_log >/dev/null 2>&1; then
                vibe_log "graceful_degradation" "failover_success" \
                    "{\"ai\": \"$current_ai\", \"attempt\": $attempt}" \
                    "Failover succeeded with AI $current_ai" \
                    "[]" \
                    "graceful-degradation"
            fi
            return 0
        fi
        
        # Failure - get next AI
        local next_ai
        if next_ai=$(get_next_failover_ai "$current_ai"); then
            current_ai="$next_ai"
            attempt=$((attempt + 1))
        else
            # No more AIs available
            if declare -f vibe_log >/dev/null 2>&1; then
                vibe_log "graceful_degradation" "failover_exhausted" \
                    "{\"attempt\": $attempt}" \
                    "All failover AIs exhausted after $attempt attempts" \
                    "[]" \
                    "graceful-degradation"
            fi
            return 1
        fi
    done
    
    return 1
}

# reset_degradation_state()
# Resets graceful degradation state to initial values
#
# Returns: 0 on success
reset_degradation_state() {
    CURRENT_MODE="parallel"
    CURRENT_FAILOVER_INDEX=0
    CURRENT_TIMEOUT_MULTIPLIER=1.0
    
    if declare -f vibe_log >/dev/null 2>&1; then
        vibe_log "graceful_degradation" "state_reset" \
            "{}" \
            "Graceful degradation state reset to initial values" \
            "[]" \
            "graceful-degradation"
    fi
    
    return 0
}

# Export functions
export -f get_next_failover_ai
export -f switch_execution_mode
export -f adjust_timeout
export -f execute_with_failover
export -f reset_degradation_state
