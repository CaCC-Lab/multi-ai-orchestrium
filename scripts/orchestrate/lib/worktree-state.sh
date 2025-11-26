#!/usr/bin/env bash
# worktree-state.sh - NDJSON状態管理
# 責務：Worktree状態の記録、検証、照会
# Phase 2.1.1実装

set -euo pipefail

# State transition validation
# Valid transitions: none → creating → active → cleaning → none

# 依存関係をソース（既にworktree-core.shでソースされているが、単体テスト用に保持）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh" ]]; then
    source "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh"
fi

if [[ -f "$SCRIPT_DIR/worktree-errors.sh" ]]; then
    source "$SCRIPT_DIR/worktree-errors.sh"
fi

# Define valid states
VALID_STATES=("none" "creating" "active" "cleaning")

# Function to check if a state is valid
is_valid_state() {
    local state="$1"
    for valid_state in "${VALID_STATES[@]}"; do
        if [[ "$state" == "$valid_state" ]]; then
            return 0
        fi
      done
    return 1
}

# Function to validate state transitions
validate_worktree_state_transition() {
    local ai="$1"
    local from_state="$2"
    local to_state="$3"
    
    # Log the transition attempt
    if command -v log_info >/dev/null 2>&1; then
        log_info "Validating state transition for AI $ai: $from_state → $to_state"
    fi
    
    # Define valid transitions
    case "$from_state" in
        "none")
            if [[ "$to_state" == "creating" ]]; then
                return 0
            fi
            ;;
        "creating")
            if [[ "$to_state" == "active" ]]; then
                return 0
            fi
            ;;
        "active")
            if [[ "$to_state" == "cleaning" ]]; then
                return 0
            fi
            ;;
        "cleaning")
            if [[ "$to_state" == "none" ]]; then
                return 0
            fi
            ;;
        *)
            if command -v log_error >/dev/null 2>&1; then
                log_error "Invalid from_state: $from_state"
            fi
            return 1
            ;;
    esac
    
    if command -v log_error >/dev/null 2>&1; then
        log_error "Invalid state transition for AI $ai: $from_state → $to_state"
    fi
    return 1
}

# Function to get the state file path for a specific date
get_state_file_path() {
    local date_string="${1:-$(date +%Y%m%d)}"
    local state_dir="logs/worktree-states/$date_string"
    
    # Create directory if it doesn't exist
    mkdir -p "$state_dir"
    
    echo "$state_dir/states.ndjson"
}

# Function to update worktree state with NDJSON logging
update_worktree_state() {
    local ai="$1"
    local state="$2"
    local metadata="$3"  # JSON string containing additional metadata like branch, worktree, etc.
    
    # Validate state
    if ! is_valid_state "$state"; then
        if command -v log_error >/dev/null 2>&1; then
            log_error "Invalid state: $state"
        fi
        if command -v worktree_error >/dev/null 2>&1; then
            worktree_error "INVALID_STATE" "Invalid state: $state"
        fi
        return 1
    fi
    
    # Get current timestamp in ISO 8601 format
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Prepare the NDJSON line
    local ndjson_line="{\"timestamp\":\"$timestamp\",\"ai\":\"$ai\",\"state\":\"$state\""
    
    # If metadata is provided, append it to the JSON object
    if [[ -n "$metadata" ]]; then
        # Ensure metadata is properly formatted JSON (remove leading/trailing braces if present and add comma)
        local clean_metadata="$metadata"
        if [[ "${clean_metadata:0:1}" == "{" ]]; then
            clean_metadata="${clean_metadata:1}"
        fi
        if [[ "${clean_metadata: -1}" == "}" ]]; then
            clean_metadata="${clean_metadata:0:-1}"
        fi
        # Ensure we don't add a comma if the clean metadata starts with a comma
        if [[ "${clean_metadata:0:1}" != "," ]]; then
            clean_metadata=",$clean_metadata"
        fi
        ndjson_line="$ndjson_line$clean_metadata"
    fi
    
    ndjson_line="$ndjson_line}"
    
    # Get the state file path for today
    local state_file
    state_file=$(get_state_file_path)
    
    # Write the NDJSON line to the file ensuring it's a single line
    echo "$ndjson_line" >> "$state_file"
    
    # Log the state update
    if command -v log_info >/dev/null 2>&1; then
        log_info "Updated worktree state for AI $ai: $state"
    fi
    
    return 0
}

# Function to get the current state for a specific AI
get_worktree_state() {
    local ai="$1"
    
    # Get the state file path for today
    local state_file
    state_file=$(get_state_file_path)
    
    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        if command -v log_warn >/dev/null 2>&1; then
            log_warn "State file does not exist: $state_file"
        fi
        echo '{"timestamp":null,"ai":"'$ai'","state":"none","branch":null,"worktree":null}'
        return 0
    fi
    
    # Get the last line containing the AI's state
    local last_state_line
    last_state_line=$(grep "\"ai\":\"$ai\"" "$state_file" | tail -n 1)
    
    if [[ -n "$last_state_line" ]]; then
        echo "$last_state_line"
    else
        echo '{"timestamp":null,"ai":"'$ai'","state":"none","branch":null,"worktree":null}'
    fi
}

# Function to get all worktree states for all AIs
get_all_worktree_states() {
    local date_string="${1:-$(date +%Y%m%d)}"
    local state_file
    state_file=$(get_state_file_path "$date_string")
    
    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        if command -v log_warn >/dev/null 2>&1; then
            log_warn "State file does not exist: $state_file"
        fi
        return 0
    fi
    
    # Output all state lines
    cat "$state_file"
}

# Function to get the current state value for an AI (just the state string)
get_worktree_state_value() {
    local ai="$1"
    local state_json
    state_json=$(get_worktree_state "$ai")
    
    # Extract the state value from the JSON
    local state
    state=$(echo "$state_json" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
    
    if [[ -z "$state" ]]; then
        echo "none"
    else
        echo "$state"
    fi
}

# Function to get previous states for an AI (to check transition validity)
get_previous_worktree_state() {
    local ai="$1"
    
    # Get the state file path for today
    local state_file
    state_file=$(get_state_file_path)
    
    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        echo "none"
        return 0
    fi
    
    # Get the last two lines containing the AI's state
    local states
    states=$(grep "\"ai\":\"$ai\"" "$state_file" | tail -n 2)
    
    # If only one state exists, return it; otherwise return the second-to-last
    local count
    count=$(echo "$states" | wc -l)
    
    if [[ $count -eq 1 ]]; then
        echo "$states"
    else
        echo "$states" | head -n 1
    fi
}