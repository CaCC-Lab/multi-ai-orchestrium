#!/usr/bin/env bash
# TDD Multi-AI Common Functions Library
# Version: 1.0
# Purpose: Shared functions for TDD workflow integration with Multi-AI profiles

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Script directory
LIB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PROJECT_ROOT="${LIB_PROJECT_ROOT:-$(cd "$LIB_SCRIPT_DIR/../.." && pwd)}"

# YAML config file
TDD_CONFIG_FILE="${TDD_CONFIG_FILE:-$LIB_PROJECT_ROOT/config/multi-ai-profiles.yaml}"

# Default TDD profile
DEFAULT_TDD_PROFILE="${DEFAULT_TDD_PROFILE:-balanced}"

# Colors (check if already defined)
if [[ ! -v TDD_RED ]]; then
    readonly TDD_RED='\033[0;31m'
    readonly TDD_GREEN='\033[0;32m'
    readonly TDD_BLUE='\033[0;34m'
    readonly TDD_YELLOW='\033[0;33m'
    readonly TDD_CYAN='\033[0;36m'
    readonly TDD_MAGENTA='\033[0;35m'
    readonly TDD_NC='\033[0m'
fi

# ============================================================================
# Validation Functions
# ============================================================================

# Check if yq is installed
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo -e "${TDD_RED}Error: yq is not installed${TDD_NC}" >&2
        echo "Install with: snap install yq" >&2
        return 1
    fi
}

# Validate TDD profile exists in YAML
validate_tdd_profile() {
    local profile_name="$1"

    check_yq || return 1

    # Check if profile exists (yq returns "null" for nonexistent keys)
    local result
    result=$(yq e ".tdd_workflows.$profile_name" "$TDD_CONFIG_FILE" 2>/dev/null)

    if [[ "$result" == "null" ]] || [[ -z "$result" ]]; then
        echo -e "${TDD_RED}Error: TDD profile '$profile_name' not found in $TDD_CONFIG_FILE${TDD_NC}" >&2
        return 1
    fi

    return 0
}

# List available TDD profiles
list_tdd_profiles() {
    check_yq || return 1

    echo -e "${TDD_CYAN}Available TDD Profiles:${TDD_NC}"
    yq e '.tdd_workflows | keys | .[]' "$TDD_CONFIG_FILE" 2>/dev/null || {
        echo -e "${TDD_RED}Error: Could not read TDD profiles${TDD_NC}" >&2
        return 1
    }
}

# ============================================================================
# Configuration Loading Functions
# ============================================================================

# Load TDD profile phase configuration
# Usage: load_tdd_phase_config <profile_name> <phase_name>
# Returns: JSON string with phase configuration
load_tdd_phase_config() {
    local profile_name="$1"
    local phase_name="$2"

    check_yq || return 1
    validate_tdd_profile "$profile_name" || return 1

    local config
    config=$(yq e ".tdd_workflows.$profile_name.$phase_name" "$TDD_CONFIG_FILE" 2>/dev/null)

    if [[ "$config" == "null" ]] || [[ -z "$config" ]]; then
        echo -e "${TDD_YELLOW}Warning: Phase '$phase_name' not found in profile '$profile_name'${TDD_NC}" >&2
        return 1
    fi

    echo "$config"
}

# Get AI name for a phase
# Usage: get_phase_ai <profile_name> <phase_name> <role> (role: primary|fallback|secondary|reviewer)
get_phase_ai() {
    local profile_name="$1"
    local phase_name="$2"
    # Use parameter expansion that only uses default if argument is truly unset, not if it's empty
    local role="${3-primary}"

    # Validate role is not empty
    if [[ -z "$role" ]]; then
        echo "Error: Role cannot be empty" >&2
        return 1
    fi

    local config
    config=$(load_tdd_phase_config "$profile_name" "$phase_name") || return 1

    local ai_name
    ai_name=$(echo "$config" | yq e ".$role" - 2>/dev/null)

    if [[ "$ai_name" == "null" ]] || [[ -z "$ai_name" ]]; then
        return 1
    fi

    echo "$ai_name"
}

# Get timeout for a phase
# Usage: get_phase_timeout <profile_name> <phase_name>
get_phase_timeout() {
    local profile_name="$1"
    local phase_name="$2"

    local config
    config=$(load_tdd_phase_config "$profile_name" "$phase_name") || return 1

    local timeout
    timeout=$(echo "$config" | yq e ".timeout" - 2>/dev/null)

    if [[ "$timeout" == "null" ]] || [[ -z "$timeout" ]]; then
        echo "120"  # Default 2 minutes
    else
        echo "$timeout"
    fi
}

# Get context description for a phase
# Usage: get_phase_context <profile_name> <phase_name>
get_phase_context() {
    local profile_name="$1"
    local phase_name="$2"

    local config
    config=$(load_tdd_phase_config "$profile_name" "$phase_name") || return 1

    local context
    context=$(echo "$config" | yq e ".context" - 2>/dev/null)

    if [[ "$context" == "null" ]] || [[ -z "$context" ]]; then
        echo "No context provided"
    else
        echo "$context"
    fi
}

# Check if phase should run in parallel
# Usage: is_parallel_phase <profile_name> <phase_name>
is_parallel_phase() {
    local profile_name="$1"
    local phase_name="$2"

    local config
    config=$(load_tdd_phase_config "$profile_name" "$phase_name") || return 1

    local parallel
    parallel=$(echo "$config" | yq e ".parallel" - 2>/dev/null)

    [[ "$parallel" == "true" ]]
}

# ============================================================================
# AI Invocation Functions
# ============================================================================

# Invoke AI wrapper script
# Usage: invoke_ai <ai_name> <task_description> [timeout]
invoke_ai() {
    local ai_name="$1"
    local task="$2"
    local timeout="${3:-120}"

    local wrapper_script="$LIB_PROJECT_ROOT/bin/${ai_name}-wrapper.sh"

    if [[ ! -f "$wrapper_script" ]]; then
        echo -e "${TDD_RED}Error: Wrapper script not found: $wrapper_script${TDD_NC}" >&2
        return 1
    fi

    echo -e "${TDD_CYAN}Invoking $ai_name (timeout: ${timeout}s)...${TDD_NC}" >&2

    # Set AI-specific timeout environment variable to override AGENTS.md classification
    # This ensures YAML config timeout takes precedence over dynamic task classification
    local ai_upper
    ai_upper=$(echo "$ai_name" | tr '[:lower:]' '[:upper:]')
    local timeout_var="${ai_upper}_MCP_TIMEOUT"

    # Export timeout to override wrapper's internal timeout
    export "${timeout_var}=${timeout}"

    # Execute with timeout (outer timeout as safety net)
    timeout "${timeout}s" "$wrapper_script" --prompt "$task" 2>&1 || {
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            echo -e "${TDD_YELLOW}$ai_name timeout after ${timeout}s${TDD_NC}" >&2
            return 124
        else
            echo -e "${TDD_RED}$ai_name failed with exit code $exit_code${TDD_NC}" >&2
            return $exit_code
        fi
    }
}

# Execute with fallback AI
# Usage: execute_with_fallback <primary_ai> <fallback_ai> <task> <timeout>
execute_with_fallback() {
    local primary_ai="$1"
    local fallback_ai="$2"
    local task="$3"
    local timeout="${4:-120}"

    echo -e "${TDD_CYAN}Primary: $primary_ai${TDD_NC}" >&2

    if invoke_ai "$primary_ai" "$task" "$timeout"; then
        echo -e "${TDD_GREEN}✓ $primary_ai completed successfully${TDD_NC}" >&2
        return 0
    else
        local exit_code=$?
        echo -e "${TDD_YELLOW}⚠ $primary_ai failed/timeout, using fallback: $fallback_ai${TDD_NC}" >&2

        if invoke_ai "$fallback_ai" "$task" "$timeout"; then
            echo -e "${TDD_GREEN}✓ Fallback $fallback_ai completed successfully${TDD_NC}" >&2
            return 0
        else
            echo -e "${TDD_RED}✗ Both $primary_ai and $fallback_ai failed${TDD_NC}" >&2
            return 1
        fi
    fi
}

# Execute parallel AI invocations
# Usage: execute_parallel <ai1> <ai2> <task> <timeout>
execute_parallel() {
    local ai1="$1"
    local ai2="$2"
    local task="$3"
    local timeout="${4:-120}"

    local output1="/tmp/tdd_${ai1}_$$.log"
    local output2="/tmp/tdd_${ai2}_$$.log"

    echo -e "${TDD_CYAN}Parallel execution: $ai1 + $ai2${TDD_NC}" >&2

    # Run in parallel
    (invoke_ai "$ai1" "$task" "$timeout" > "$output1" 2>&1) &
    local pid1=$!

    (invoke_ai "$ai2" "$task" "$timeout" > "$output2" 2>&1) &
    local pid2=$!

    # Wait for both
    local status1=0
    local status2=0

    wait $pid1 || status1=$?
    wait $pid2 || status2=$?

    # Display results
    if [ $status1 -eq 0 ]; then
        echo -e "${TDD_GREEN}✓ $ai1 completed${TDD_NC}" >&2
        [[ -f "$output1" ]] && cat "$output1"
    else
        echo -e "${TDD_YELLOW}⚠ $ai1 failed/timeout${TDD_NC}" >&2
    fi

    echo "" >&2

    if [ $status2 -eq 0 ]; then
        echo -e "${TDD_GREEN}✓ $ai2 completed${TDD_NC}" >&2
        [[ -f "$output2" ]] && cat "$output2"
    else
        echo -e "${TDD_YELLOW}⚠ $ai2 failed/timeout${TDD_NC}" >&2
    fi

    # Cleanup
    rm -f "$output1" "$output2"

    # Return success if at least one succeeded
    if [ $status1 -eq 0 ] || [ $status2 -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Logging Functions
# ============================================================================

# Log phase start
log_phase_start() {
    local phase_name="$1"
    local ai_name="${2:-}"

    echo "" >&2
    echo -e "${TDD_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${TDD_NC}" >&2
    if [[ -n "$ai_name" ]]; then
        echo -e "${TDD_MAGENTA}🚀 $phase_name ($ai_name)${TDD_NC}" >&2
    else
        echo -e "${TDD_MAGENTA}🚀 $phase_name${TDD_NC}" >&2
    fi
    echo -e "${TDD_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${TDD_NC}" >&2
    echo "" >&2
}

# Log phase end
log_phase_end() {
    local phase_name="$1"
    local status="${2:-success}"

    echo "" >&2
    if [[ "$status" == "success" ]]; then
        echo -e "${TDD_GREEN}✅ $phase_name completed${TDD_NC}" >&2
    else
        echo -e "${TDD_YELLOW}⚠️  $phase_name completed with warnings${TDD_NC}" >&2
    fi
    echo "" >&2
}

# Record metrics (placeholder for future implementation)
record_metrics() {
    local phase_name="$1"
    local duration="$2"
    local status="$3"

    # TODO: Implement metrics recording to YAML/JSON
    # For now, just log to stderr
    echo "[METRICS] $phase_name: ${duration}s, status=$status" >&2
}

# ============================================================================
# Helper Functions
# ============================================================================

# Get timestamp in milliseconds
get_timestamp_ms() {
    local ts
    ts=$(date +%s%3N 2>/dev/null)
    if [[ "$ts" == *"%"* ]]; then
        echo "$(date +%s)000"
    else
        echo "$ts"
    fi
}

# Calculate duration
calculate_duration() {
    local start_ms="$1"
    local end_ms="$2"

    echo $(( (end_ms - start_ms) / 1000 ))
}

# ============================================================================
# Initialization
# ============================================================================

# Export functions for use in other scripts
export -f check_yq
export -f validate_tdd_profile
export -f list_tdd_profiles
export -f load_tdd_phase_config
export -f get_phase_ai
export -f get_phase_timeout
export -f get_phase_context
export -f is_parallel_phase
export -f invoke_ai
export -f execute_with_fallback
export -f execute_parallel
export -f log_phase_start
export -f log_phase_end
export -f record_metrics
export -f get_timestamp_ms
export -f calculate_duration

# Validate configuration on load (only if not in quiet mode)
if [[ -z "${TDD_Multi-AI_QUIET:-}" ]]; then
    if check_yq; then
        echo -e "${TDD_CYAN}TDD Multi-AI Common Library loaded${TDD_NC}" >&2
        echo "Config file: $TDD_CONFIG_FILE" >&2
    else
        echo -e "${TDD_RED}Warning: yq not installed, some functions will not work${TDD_NC}" >&2
    fi
fi
