#!/usr/bin/env bash
# partial-result-handler.sh - Partial Result Acceptance Layer
# Phase 4 Tier 2 Task 6: Error Recovery Granularity Improvement
#
# Handles partial workflow results and determines if they should be accepted
# based on completion rate and critical AI success.

set -uo pipefail  # Remove -e to allow graceful error handling

# Source dependencies
_PARTIAL_RESULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$_PARTIAL_RESULT_DIR/../.." && pwd)}"

source "${PROJECT_ROOT}/scripts/lib/sanitize.sh" 2>/dev/null || true
source "${PROJECT_ROOT}/bin/vibe-logger-lib.sh" 2>/dev/null || true

# Configuration
PARTIAL_RESULT_MIN_COMPLETION="${PARTIAL_RESULT_MIN_COMPLETION:-50}"  # Minimum 50% completion
PARTIAL_RESULT_MIN_SECTIONS="${PARTIAL_RESULT_MIN_SECTIONS:-1}"       # At least 1 section

# Critical AIs that must succeed for partial acceptance
CRITICAL_AIS=("claude" "gemini")

# ============================================================
# Core Functions
# ============================================================

# extract_partial_results(output_file, expected_sections)
# Extracts and counts markdown sections from output file
#
# Arguments:
#   $1 - Output file path
#   $2 - Expected number of sections (default: 1)
# Outputs: Completion rate percentage (0-100)
# Returns: 0 if partial results found, 1 otherwise
extract_partial_results() {
    local output_file="$1"
    local expected_sections="${2:-1}"
    
    # Input validation
    if [[ -z "$output_file" ]] || [[ ! -f "$output_file" ]]; then
        # log_warn "Invalid output file: $output_file"  # Commented out to avoid dependency
        echo "0"
        return 1
    fi
    
    # Count markdown sections (## headers)
    local section_count
    section_count=$(grep -c '^##' "$output_file" 2>/dev/null || echo "0")
    
    # Check if we have at least partial results
    if [[ "$section_count" -ge "$PARTIAL_RESULT_MIN_SECTIONS" ]]; then
        # Calculate completion rate
        local completion_rate
        completion_rate=$(awk "BEGIN {printf \"%.0f\", ($section_count / $expected_sections) * 100}")
        
        # Log partial result detection
        if declare -f vibe_log >/dev/null 2>&1; then
            vibe_log "partial_result" "extracted" \
                "{\"output_file\": \"$output_file\", \"section_count\": $section_count, \"expected_sections\": $expected_sections, \"completion_rate\": $completion_rate}" \
                "Partial results extracted: $section_count/$expected_sections sections ($completion_rate%)" \
                "[]" \
                "partial-result-handler"
        fi
        
        echo "$completion_rate"
        return 0
    fi
    
    echo "0"
    return 1
}

# accept_partial_workflow_result(total_ais, success_count, critical_ai_success)
# Determines if partial workflow result should be accepted
#
# Arguments:
#   $1 - Total number of AIs
#   $2 - Number of successful AIs
#   $3 - Whether critical AI succeeded (true/false, default: false)
# Outputs: Acceptance decision (ACCEPT/REJECT)
# Returns: 0 if accepted, 1 if rejected
accept_partial_workflow_result() {
    local total_ais="$1"
    local success_count="$2"
    local critical_ai_success="${3:-false}"
    
    # Input validation
    if [[ -z "$total_ais" ]] || [[ -z "$success_count" ]]; then
        # log_warn "Invalid arguments to accept_partial_workflow_result"  # Commented out to avoid dependency
        echo "REJECT"
        return 1
    fi
    
    # Calculate success rate
    local success_rate
    success_rate=$(awk "BEGIN {printf \"%.0f\", ($success_count / $total_ais) * 100}")
    
    # Check acceptance criteria:
    # 1. Success rate >= 50%
    # 2. Critical AI (Claude or Gemini) succeeded
    if [[ "$success_rate" -ge "$PARTIAL_RESULT_MIN_COMPLETION" ]] && [[ "$critical_ai_success" == "true" ]]; then
        # Log acceptance
        if declare -f vibe_log >/dev/null 2>&1; then
            vibe_log "partial_result" "accepted" \
                "{\"total_ais\": $total_ais, \"success_count\": $success_count, \"success_rate\": $success_rate, \"critical_ai_success\": true}" \
                "Partial workflow result accepted: $success_count/$total_ais AIs succeeded ($success_rate%)" \
                "[]" \
                "partial-result-handler"
        fi
        
        echo "ACCEPT"
        return 0
    fi
    
    # Log rejection
    if declare -f vibe_log >/dev/null 2>&1; then
        vibe_log "partial_result" "rejected" \
            "{\"total_ais\": $total_ais, \"success_count\": $success_count, \"success_rate\": $success_rate, \"critical_ai_success\": $critical_ai_success}" \
            "Partial workflow result rejected: $success_count/$total_ais AIs succeeded ($success_rate%), critical_ai_success=$critical_ai_success" \
            "[]" \
            "partial-result-handler"
    fi
    
    echo "REJECT"
    return 1
}

# check_critical_ai_success(ai_results_json)
# Checks if critical AIs (Claude/Gemini) succeeded
#
# Arguments:
#   $1 - JSON array of AI results: [{"ai": "claude", "success": true}, ...]
# Outputs: true/false
# Returns: 0 if critical AI succeeded, 1 otherwise
check_critical_ai_success() {
    local ai_results_json="$1"
    
    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        # log_warn "jq not available, cannot check critical AI success"  # Commented out to avoid dependency
        echo "false"
        return 1
    fi
    
    # Check each critical AI
    for critical_ai in "${CRITICAL_AIS[@]}"; do
        local success
        success=$(echo "$ai_results_json" | jq -r ".[] | select(.ai == \"$critical_ai\") | .success" 2>/dev/null || echo "false")
        
        if [[ "$success" == "true" ]]; then
            echo "true"
            return 0
        fi
    done
    
    echo "false"
    return 1
}

# save_partial_result(task_id, output_file, completion_rate)
# Saves partial result for later recovery
#
# Arguments:
#   $1 - Task ID
#   $2 - Output file path
#   $3 - Completion rate (0-100)
# Returns: 0 on success
save_partial_result() {
    local task_id="$1"
    local output_file="$2"
    local completion_rate="$3"
    
    local partial_result_dir="${PROJECT_ROOT}/logs/partial-results"
    mkdir -p "$partial_result_dir"
    
    local result_file="${partial_result_dir}/${task_id}.json"
    
    # Create result metadata
    local metadata
    metadata=$(jq -n \
        --arg task_id "$task_id" \
        --arg output_file "$output_file" \
        --argjson completion_rate "$completion_rate" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            task_id: $task_id,
            output_file: $output_file,
            completion_rate: $completion_rate,
            timestamp: $timestamp,
            status: "partial"
        }' 2>/dev/null || echo "{}")
    
    echo "$metadata" > "$result_file"
    
    # Log save event
    if declare -f vibe_log >/dev/null 2>&1; then
        vibe_log "partial_result" "saved" \
            "{\"task_id\": \"$task_id\", \"completion_rate\": $completion_rate}" \
            "Partial result saved for task $task_id ($completion_rate% complete)" \
            "[]" \
            "partial-result-handler"
    fi
    
    return 0
}

# load_partial_result(task_id)
# Loads saved partial result
#
# Arguments:
#   $1 - Task ID
# Outputs: JSON metadata
# Returns: 0 if found, 1 otherwise
load_partial_result() {
    local task_id="$1"
    local result_file="${PROJECT_ROOT}/logs/partial-results/${task_id}.json"
    
    if [[ -f "$result_file" ]]; then
        cat "$result_file"
        return 0
    fi
    
    return 1
}

# Export functions
export -f extract_partial_results
export -f accept_partial_workflow_result
export -f check_critical_ai_success
export -f save_partial_result
export -f load_partial_result
