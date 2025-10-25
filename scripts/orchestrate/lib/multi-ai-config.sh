#!/usr/bin/env bash
# Multi-AI Configuration Library
# Purpose: YAML configuration loading and workflow execution
# Responsibilities:
#   - Profile loading and validation (load_multi_ai_profile)
#   - Workflow configuration access (get_workflow_config)
#   - Phase metadata retrieval (get_phases, get_phase_info, get_phase_*)
#   - Parallel phase metadata retrieval (get_parallel_*)
#   - Phase execution (execute_phase, execute_sequential_phase, execute_parallel_phase)
#   - YAML workflow execution (execute_yaml_workflow)
#
# Dependencies:
#   - lib/7ai-core.sh (logging functions)
#   - lib/7ai-ai-interface.sh (call_ai function)
#   - yq (YAML processor)

set -euo pipefail

# ============================================================================
# YAML Caching Mechanism (P1.2.1)
# ============================================================================

# Global associative array for YAML result caching
declare -A yaml_cache

# Cache a YAML query result with file modification time
cache_yaml_result() {
    local yaml_path="$1"
    local config_file="$2"
    local result="$3"

    # Get file modification time (cross-platform: Linux + macOS)
    local mtime
    if mtime=$(stat -c %Y "$config_file" 2>/dev/null); then
        : # Linux stat succeeded
    elif mtime=$(stat -f %m "$config_file" 2>/dev/null); then
        : # macOS stat succeeded
    else
        log_error "Failed to get modification time for $config_file"
        return 1
    fi

    # Generate cache key: ${config_file}:${yaml_path}:${mtime}
    local cache_key="${config_file}:${yaml_path}:${mtime}"
    yaml_cache["$cache_key"]="$result"
}

# Get cached YAML result if available
get_cached_yaml() {
    local yaml_path="$1"
    local config_file="$2"

    # Get file modification time
    local mtime
    if mtime=$(stat -c %Y "$config_file" 2>/dev/null); then
        : # Linux
    elif mtime=$(stat -f %m "$config_file" 2>/dev/null); then
        : # macOS
    else
        return 1  # No cache if can't get mtime
    fi

    local cache_key="${config_file}:${yaml_path}:${mtime}"

    if [ -n "${yaml_cache[$cache_key]+isset}" ]; then
        echo "${yaml_cache[$cache_key]}"
        return 0
    else
        return 1
    fi
}

# Invalidate all YAML cache entries
invalidate_yaml_cache() {
    yaml_cache=()
}

# ============================================================================
# Profile and Workflow Functions (2 functions)
# ============================================================================

# Load Multi-AI profile from YAML
load_multi_ai_profile() {
    local profile="${1:-$DEFAULT_PROFILE}"

    if ! command -v yq >/dev/null 2>&1; then
        log_structured_error \
            "yq command not found - YAML parsing unavailable" \
            "yq is not installed or not in PATH" \
            "Install yq: https://github.com/mikefarah/yq#install (brew install yq, or download binary)"
        return 1
    fi

    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Validate profile exists
    local profile_check
    profile_check=$(yq eval ".profiles.\"$profile\"" "$config_file" 2>/dev/null)
    if [ "$profile_check" = "null" ] || [ -z "$profile_check" ]; then
        log_error "Profile '$profile' not found in configuration"
        log_info "Available profiles:"
        yq eval '.profiles | keys | .[]' "$config_file" 2>/dev/null | sed 's/^/  - /'
        return 1
    fi

    log_success "Loaded profile: $profile"
    return 0
}

# Get workflow configuration
get_workflow_config() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"

    if ! yq eval ".profiles.\"$profile\".workflows.\"$workflow\"" "$config_file" >/dev/null 2>&1; then
        log_error "Workflow '$workflow' not found in profile '$profile'"
        return 1
    fi

    echo "$workflow"
    return 0
}

# ============================================================================
# Phase Metadata Functions (6 functions)
# ============================================================================

# Get phases from workflow
get_phases() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases | length"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get phase info by index
get_phase_info() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"

    # Get phase name (with caching)
    local name_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].name"
    local name
    if name=$(get_cached_yaml "$name_path" "$config_file" 2>/dev/null); then
        : # Cache hit
    else
        # Cache miss: query and cache
        name=$(yq eval "$name_path" "$config_file" 2>/dev/null)
        cache_yaml_result "$name_path" "$config_file" "$name"
    fi

    # Check if phase has parallel execution (with caching)
    local parallel_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx] | has(\"parallel\")"
    local has_parallel
    if has_parallel=$(get_cached_yaml "$parallel_path" "$config_file" 2>/dev/null); then
        : # Cache hit
    else
        # Cache miss: query and cache
        has_parallel=$(yq eval "$parallel_path" "$config_file" 2>/dev/null)
        cache_yaml_result "$parallel_path" "$config_file" "$has_parallel"
    fi

    echo "$name|$has_parallel"
}

# Get phase AI (for sequential phases)
get_phase_ai() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].ai"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get phase role
get_phase_role() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].role"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get phase timeout
get_phase_timeout() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].timeout"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        local timeout="$cached_result"
        if [ "$timeout" = "null" ] || [ -z "$timeout" ]; then
            echo "120"
        else
            echo "$timeout"
        fi
        return 0
    fi

    # Cache miss: query and cache
    local timeout
    timeout=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$timeout"

    if [ "$timeout" = "null" ] || [ -z "$timeout" ]; then
        echo "120"  # Default timeout
    else
        echo "$timeout"
    fi
}

# ============================================================================
# Parallel Phase Metadata Functions (6 functions)
# ============================================================================

# Get parallel phase count
get_parallel_count() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].parallel | length"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get parallel phase AI by index
get_parallel_ai() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local parallel_idx="$4"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].parallel[$parallel_idx].ai"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get parallel phase role
get_parallel_role() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local parallel_idx="$4"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].parallel[$parallel_idx].role"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get parallel phase timeout
get_parallel_timeout() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local parallel_idx="$4"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].parallel[$parallel_idx].timeout"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        local timeout="$cached_result"
        if [ "$timeout" = "null" ] || [ -z "$timeout" ]; then
            echo "120"
        else
            echo "$timeout"
        fi
        return 0
    fi

    # Cache miss: query and cache
    local timeout
    timeout=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$timeout"

    if [ "$timeout" = "null" ] || [ -z "$timeout" ]; then
        echo "120"
    else
        echo "$timeout"
    fi
}

# Get parallel phase name
get_parallel_name() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local parallel_idx="$4"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].parallel[$parallel_idx].name"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        echo "$cached_result"
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"
    echo "$result"
}

# Get parallel phase blocking flag (defaults to true if unspecified)
get_parallel_blocking() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local parallel_idx="$4"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].parallel[$parallel_idx].blocking"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        local blocking="$cached_result"
        if [ "$blocking" = "null" ] || [ -z "$blocking" ]; then
            echo "true"
        else
            echo "$blocking"
        fi
        return 0
    fi

    # Cache miss: query and cache
    local blocking
    blocking=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$blocking"

    if [ "$blocking" = "null" ] || [ -z "$blocking" ]; then
        echo "true"
    else
        echo "$blocking"
    fi
}

# ============================================================================
# Phase Execution Functions (3 functions)
# ============================================================================

# Execute a single phase from YAML configuration
execute_phase() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local task="$4"
    local work_dir="$5"

    local phase_info
    phase_info=$(get_phase_info "$profile" "$workflow" "$phase_idx")
    local phase_name="${phase_info%|*}"
    local has_parallel="${phase_info#*|}"

    log_phase "$phase_name"

    if [ "$has_parallel" = "true" ]; then
        # Parallel execution
        execute_parallel_phase "$profile" "$workflow" "$phase_idx" "$task" "$work_dir"
    else
        # Sequential execution
        execute_sequential_phase "$profile" "$workflow" "$phase_idx" "$task" "$work_dir"
    fi

    return $?
}

# Execute sequential phase
execute_sequential_phase() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local task="$4"
    local work_dir="$5"

    local ai
    ai=$(get_phase_ai "$profile" "$workflow" "$phase_idx")

    local role
    role=$(get_phase_role "$profile" "$workflow" "$phase_idx")

    local timeout
    timeout=$(get_phase_timeout "$profile" "$workflow" "$phase_idx")

    if [ "$ai" = "null" ] || [ -z "$ai" ]; then
        log_warning "No AI specified for phase $phase_idx, skipping"
        return 0
    fi

    local output_file="$work_dir/${ai}_${role}.md"
    local prompt="$task

Role: $role
AI: $ai

Please complete this task according to your role."

    log_info "[$ai] Executing role: $role (timeout: ${timeout}s)"
    call_ai "$ai" "$prompt" "$timeout" "$output_file"
    return $?
}

# Execute parallel phase
execute_parallel_phase() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local task="$4"
    local work_dir="$5"

    local parallel_count
    parallel_count=$(get_parallel_count "$profile" "$workflow" "$phase_idx")

    if [ "$parallel_count" -eq 0 ]; then
        log_warning "No parallel tasks defined, skipping"
        return 0
    fi

    # P0.3.2.1: Get max_parallel_jobs from YAML or use default (4)
    local max_parallel_jobs=4
    if command -v yq &>/dev/null; then
        local yaml_max
        yaml_max=$(yq eval ".execution.max_parallel_jobs // 4" "$MULTI_AI_CONFIG" 2>/dev/null || echo "4")
        if [[ "$yaml_max" =~ ^[0-9]+$ ]] && [ "$yaml_max" -gt 0 ]; then
            max_parallel_jobs=$yaml_max
        fi
    fi

    log_info "Starting $parallel_count parallel AI tasks (max concurrent: $max_parallel_jobs)..."

    # P0.3.2.1: Initialize job pool with resource limiting
    init_job_pool "$max_parallel_jobs"

    # Arrays to track task metadata
    local pids=()
    local ai_names=()
    local blocking_flags=()

    # Launch all parallel tasks with job pool control
    for ((i = 0; i < parallel_count; i++)); do
        local ai
        ai=$(get_parallel_ai "$profile" "$workflow" "$phase_idx" "$i")
        local role
        role=$(get_parallel_role "$profile" "$workflow" "$phase_idx" "$i")
        local timeout
        timeout=$(get_parallel_timeout "$profile" "$workflow" "$phase_idx" "$i")
        local name
        name=$(get_parallel_name "$profile" "$workflow" "$phase_idx" "$i")
        local blocking
        blocking=$(get_parallel_blocking "$profile" "$workflow" "$phase_idx" "$i")

        if [ "$ai" = "null" ] || [ -z "$ai" ]; then
            log_warning "No AI specified for parallel task $i, skipping"
            continue
        fi

        local output_file="$work_dir/${ai}_${role}_${i}.md"
        local prompt="$task

Role: $role
AI: $ai
Task Name: $name

Please complete this task according to your role."

        log_info "[$ai] Starting: $name (timeout: ${timeout}s)"

        # P0.3.2.1: Wait for job slot before launching (resource limiting)
        wait_for_slot

        # Launch in background
        call_ai "$ai" "$prompt" "$timeout" "$output_file" &
        local pid=$!
        pids+=($pid)
        ai_names+=("$ai")
        blocking_flags+=("$blocking")

        # Track PID in job pool
        JOB_POOL_PIDS+=($pid)
        ((JOB_POOL_RUNNING++))
    done

    # Wait for all parallel tasks to complete
    local phase_failed=false
    local nonblocking_issue=false
    for ((i = 0; i < ${#pids[@]}; i++)); do
        local pid=${pids[$i]}
        local ai_name=${ai_names[$i]}
        local is_blocking=${blocking_flags[$i]}

        wait "$pid" || {
            if [[ "$is_blocking" == "true" ]]; then
                log_warning "[$ai_name] Task failed or timed out (blocking)"
                phase_failed=true
            else
                log_warning "[$ai_name] Task failed or timed out (non-blocking)"
                nonblocking_issue=true
            fi
        }
    done

    # P0.3.2.1: Cleanup job pool
    cleanup_job_pool

    if ! $phase_failed; then
        if $nonblocking_issue; then
            log_warning "Some non-blocking tasks failed (continuing)"
        else
            log_success "All parallel tasks completed successfully"
        fi
        return 0
    else
        log_error "Blocking parallel tasks failed"
        return 1
    fi
}

# ============================================================================
# Workflow Execution Function (1 function)
# ============================================================================

# Execute entire workflow from YAML
execute_yaml_workflow() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local task="$3"

    # Load and validate profile
    load_multi_ai_profile "$profile" || return 1

    # Validate workflow exists
    get_workflow_config "$profile" "$workflow" >/dev/null || return 1

    # Get number of phases
    local phase_count
    phase_count=$(get_phases "$profile" "$workflow")

    if [ "$phase_count" -eq 0 ]; then
        log_error "No phases found in workflow '$workflow'"
        return 1
    fi

    log_info "Workflow: $workflow ($phase_count phases)"
    echo ""

    # Setup work directory - persistent logs for audit trail
    local WORK_DIR="$PROJECT_ROOT/logs/7ai-reviews/$(date +%Y%m%d-%H%M%S)-$$-yaml"
    mkdir -p "$WORK_DIR"
    log_info "Work directory: $WORK_DIR (logs will be preserved)"

    # Execute all phases sequentially
    for ((phase_idx = 0; phase_idx < phase_count; phase_idx++)); do
        execute_phase "$profile" "$workflow" "$phase_idx" "$task" "$WORK_DIR" || {
            log_error "Phase $((phase_idx + 1)) failed"
            return 1
        }
    done

    # Display results
    echo ""
    log_success "Workflow '$workflow' Complete! 🎉"
    echo ""
    log_info "Generated Files:"
    ls -lh "$WORK_DIR" 2>/dev/null || log_warning "No files generated"
    echo ""

    return 0
}
