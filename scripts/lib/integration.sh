#!/bin/bash

# Integration Script for Collaborative Review, CLI, and AsyncThink
# This script integrates all the new components with existing systems

set -euo pipefail

# Configuration
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
LIB_DIR="$PROJECT_ROOT/scripts/lib"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/config/default.env}"

# Define the supported AI names for compatibility
SUPPORTED_AIS=("qwen" "droid" "claude" "gemini" "codex" "cursor" "amp")
export SUPPORTED_AIS

# Worktree configuration
WORKTREE_BASE="${WORKTREE_BASE:-$PROJECT_ROOT/worktrees}"
export WORKTREE_BASE

# Background tasks directory configuration
# FIXED: Initialize BACKGROUND_TASKS_DIR to prevent "unbound variable" errors
BACKGROUND_TASKS_DIR="${BACKGROUND_TASKS_DIR:-${PROJECT_ROOT}/logs/background-tasks}"
export BACKGROUND_TASKS_DIR

# Ensure background tasks directory exists
if ! mkdir -p "$BACKGROUND_TASKS_DIR" 2>/dev/null; then
    echo "ERROR: Failed to create BACKGROUND_TASKS_DIR: $BACKGROUND_TASKS_DIR" >&2
    echo "HINT: Set BACKGROUND_TASKS_DIR to a writable directory" >&2
    # Don't exit here - allow the script to continue if this is optional
fi

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

# Load existing system libraries
load_existing_systems() {
    # Worktree manager (from main scripts directory)
    if [[ -f "$PROJECT_ROOT/scripts/worktree-manager.sh" ]]; then
        # We'll source its library functions by calling the script
        # The worktree manager expects SCRIPT_DIR and PROJECT_ROOT to be set
        export SCRIPT_DIR="$PROJECT_ROOT/scripts"
        export PROJECT_ROOT
    fi
    
    # Task state management
    if [[ -f "$LIB_DIR/task-state.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/task-state.sh"
    fi
    
    # Task router
    if [[ -f "$LIB_DIR/task-router.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/task-router.sh"
    fi
    
    # Task executor
    if [[ -f "$LIB_DIR/task-executor.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/task-executor.sh"
    fi
    
    # Error recovery
    if [[ -f "$LIB_DIR/error-recovery.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/error-recovery.sh"
    fi
    
    # Agent matcher
    if [[ -f "$LIB_DIR/agent-matcher.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/agent-matcher.sh"
    fi
}

# Load our new system components
load_new_components() {
    # Collaborative Review System
    if [[ -f "$LIB_DIR/collaborative-review.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/collaborative-review.sh"
    fi
    
    # AsyncThink Integration
    if [[ -f "$LIB_DIR/asyncthink-integration.sh" ]]; then
        # shellcheck source=/dev/null
        source "$LIB_DIR/asyncthink-integration.sh"
    fi
}

# Initialize all systems
initialize_integrated_system() {
    echo "INFO: Initializing integrated system..."
    
    # Initialize worktree system
    if declare -f init_worktree_manager >/dev/null 2>&1; then
        init_worktree_manager
    else
        echo "INFO: Worktree manager initialization not available"
    fi
    
    # Initialize task state system
    if declare -f task_state_init >/dev/null 2>&1; then
        echo "INFO: Task state system ready"
    else
        echo "WARNING: Task state system not available"
    fi
    
    # Initialize collaborative review system
    if declare -f init_collaborative_review >/dev/null 2>&1; then
        init_collaborative_review
    fi
    
    # Initialize AsyncThink integration
    if declare -f init_asyncthink_integration >/dev/null 2>&1; then
        init_asyncthink_integration
    fi
    
    echo "SUCCESS: Integrated system initialized"
}

# Enhanced task routing with collaborative review
enhanced_task_route() {
    local spec_file="$1"
    local ai_profiles_file="${2:-$PROJECT_ROOT/config/ai-profiles.yaml}"
    
    echo "INFO: Enhanced routing for specification: $spec_file"
    
    # Use the existing task router to extract and route tasks
    if declare -f task_router_route >/dev/null 2>&1; then
        task_router_route "$spec_file" "$ai_profiles_file"
    else
        echo "ERROR: task_router_route function not available" >&2
        return 1
    fi
}

# Execute specification with collaborative review integration
execute_spec_with_review() {
    local spec_file="$1"
    local review_type="${2:-full}"
    
    echo "INFO: Executing specification with collaborative review: $spec_file"
    
    # First, route the specification
    local routing_result
    routing_result=$(mktemp)
    if enhanced_task_route "$spec_file" > "$routing_result"; then
        echo "INFO: Task routing completed"
        
        # Execute tasks based on routing
        if declare -f task_executor_run_spec >/dev/null 2>&1; then
            # Pass the routing result to task executor
            task_executor_run_spec "$spec_file"
        else
            echo "WARNING: task_executor_run_spec not available, using fallback"
            # Fallback execution
            echo "INFO: Fallback execution for spec: $spec_file"
        fi
        
        # Run collaborative review after execution
        if declare -f run_collaborative_review >/dev/null 2>&1; then
            run_collaborative_review "$spec_file" "$review_type"
        else
            echo "WARNING: Collaborative review not available"
        fi
    else
        echo "ERROR: Task routing failed" >&2
        rm -f "$routing_result"
        return 1
    fi
    
    rm -f "$routing_result"
    return 0
}

# Run asynchronous execution with worktree and review
async_spec_execution() {
    local spec_file="$1"
    local ai_name="${2:-qwen}"
    local review_type="${3:-full}"
    local task_priority="${4:-medium}"
    
    echo "INFO: Running asynchronous specification execution for: $spec_file"
    
    # Create a worktree for this task
    local worktree_path
    local task_id
    task_id="async_spec_$(date +%s)_${ai_name}"
    
    # In an actual implementation, we'd create a worktree
    # For now, we'll use a mock implementation
    if [[ -d "$WORKTREE_BASE" ]]; then
        worktree_path="$WORKTREE_BASE/$ai_name/$(basename "$spec_file" .md)_$(date +%s)"
        mkdir -p "$worktree_path"
        echo "INFO: Worktree created at: $worktree_path"
    else
        worktree_path="/tmp/spec_worktree_$$"
        mkdir -p "$worktree_path"
        echo "INFO: Temporary worktree created at: $worktree_path"
    fi
    
    # Copy spec to worktree
    cp "$spec_file" "$worktree_path/"
    
    # Submit execution as background task
    local async_task_id
    async_task_id=$(submit_background_task "spec_execution" \
        "{\"spec_file\": \"$(basename "$spec_file")\", \"ai_name\": \"$ai_name\", \"review_type\": \"$review_type\"}" \
        "$ai_name" "$task_priority")
    
    # Start the actual execution in background
    (
        cd "$worktree_path" || exit 1
        execute_spec_with_review "$(basename "$spec_file")" "$review_type"
        local exit_code=$?
        
        # Cleanup worktree after execution
        rm -rf "$worktree_path"
        
        if [[ $exit_code -eq 0 ]]; then
            update_task_status "$async_task_id" "completed"
        else
            update_task_status "$async_task_id" "failed"
        fi
    ) &
    
    local bg_pid=$!
    echo "$bg_pid" > "$BACKGROUND_TASKS_DIR/${async_task_id}.pid"
    
    echo "INFO: Asynchronous execution started - Task ID: $async_task_id, PID: $bg_pid"
    echo "$async_task_id"
}

# Enhanced review command that integrates with existing systems
integrated_review() {
    local spec_file="$1"
    local review_type="${2:-full}"
    
    echo "INFO: Running integrated review for: $spec_file"
    
    # First, ensure there are AI reviews to aggregate
    echo "INFO: Collecting individual AI reviews..."
    
    # This would normally call individual AI review scripts
    # For now, we'll simulate this by looking for existing review files
    local review_files
    review_files=$(find "$PROJECT_ROOT/reviews" -name "*$(basename "$spec_file" .md)*_review.md" 2>/dev/null | wc -l)
    
    if [[ $review_files -eq 0 ]]; then
        echo "WARNING: No individual AI reviews found for $spec_file"
        echo "INFO: You may need to run individual AI reviews first"
    fi
    
    # Run the collaborative review system
    if declare -f run_collaborative_review >/dev/null 2>&1; then
        run_collaborative_review "$spec_file" "$review_type"
    else
        echo "ERROR: Collaborative review function not available" >&2
        return 1
    fi
}

# Status command that combines information from all systems
integrated_status() {
    local task_id="${1:-all}"

    echo "INFO: Fetching integrated status..."

    # Show task state information
    if [[ "$task_id" == "all" ]]; then
        if declare -f task_state_list >/dev/null 2>&1; then
            echo "=== Task States ==="
            task_state_list
        fi
    else
        if declare -f task_state_print >/dev/null 2>&1; then
            echo "=== Task State for $task_id ==="
            task_state_print "$task_id"
        fi
    fi

    # Show background tasks status
    # Ensure BACKGROUND_TASKS_DIR is set before accessing
    local bg_tasks_dir="${BACKGROUND_TASKS_DIR:-$PROJECT_ROOT/background-tasks}"
    if [[ -d "$bg_tasks_dir" ]]; then
        echo "=== Background Tasks ==="
        for task_file in "$bg_tasks_dir"/*.json; do
            if [[ -f "$task_file" ]]; then
                local task_id_local
                task_id_local=$(basename "$task_file" .json)
                # Use get_task_status function if available, otherwise just show file info
                if declare -f get_task_status >/dev/null 2>&1; then
                    local status
                    status=$(get_task_status "$task_id_local" 2>/dev/null || echo "unknown")
                    echo "$task_id_local: $status"
                else
                    echo "$task_id_local: status_function_not_available"
                fi
            fi
        done
    else
        echo "=== Background Tasks ==="
        echo "Background tasks directory not found: $bg_tasks_dir"
    fi
    
    # Show worktree status
    if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
        echo "=== Git Worktrees ==="
        git worktree list || echo "No worktrees or git not available"
    fi
}

# Initialize the integrated system on script load
initialize_integrated_system

echo "INFO: System integration completed successfully"

# Example usage functions (these would be called by the CLI)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Integration script loaded successfully"
    echo "Functions available for use in other scripts:"
    echo "- enhanced_task_route <spec_file> [profiles_file]"
    echo "- execute_spec_with_review <spec_file> [review_type]"
    echo "- async_spec_execution <spec_file> [ai_name] [review_type] [priority]"
    echo "- integrated_review <spec_file> [review_type]"
    echo "- integrated_status [task_id]"
fi