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

# Source workflow optimizer modules if feature flags are enabled
if [[ "${ENABLE_PARALLELISM_ETA:-false}" == "true" ]]; then
    # Source parallelism-eta.sh for eta efficiency calculation
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workflow-optimizer/parallelism-eta.sh" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/workflow-optimizer/parallelism-eta.sh"
    fi
fi

if [[ "${ENABLE_CONFIG_OPTIMIZER:-false}" == "true" ]]; then
    # Source config-optimizer.sh for P95-based timeout optimization
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workflow-optimizer/config-optimizer.sh" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/workflow-optimizer/config-optimizer.sh"
    fi
fi

# Source incremental cache library for Phase 4 Tier 2 Task 4 (増分合成)
INCREMENTAL_CACHE_LIB="$(dirname "${BASH_SOURCE[0]}")/incremental-cache.sh"
if [[ -f "$INCREMENTAL_CACHE_LIB" ]]; then
    source "$INCREMENTAL_CACHE_LIB" || {
        echo "WARNING: Failed to source incremental-cache.sh" >&2
    }
else
    echo "WARNING: incremental-cache.sh not found at $INCREMENTAL_CACHE_LIB" >&2
fi

# Shadow mode for optimizer decision logging without applying changes (Phase 3)
if [[ "${OPTIMIZER_SHADOW_MODE:-false}" == "true" ]]; then
    log_info "Optimizer shadow mode enabled - decisions will be logged but not applied"
fi

# ============================================================================
# Feature Flags (Phase 4: TDD Integration Implementation)
# ============================================================================

# Feature flags for workflow optimization features (default: all disabled)
export ENABLE_FAILURE_RETRY="${ENABLE_FAILURE_RETRY:-false}"
export ENABLE_PARALLELISM_ETA="${ENABLE_PARALLELISM_ETA:-false}"
export ENABLE_CONFIG_OPTIMIZER="${ENABLE_CONFIG_OPTIMIZER:-false}"

# Configuration values for workflow optimization features
export MAX_RETRIES="${MAX_RETRIES:-3}"
export ETA_THRESHOLD="${ETA_THRESHOLD:-0.7}"
export CIRCUIT_BREAKER_THRESHOLD="${CIRCUIT_BREAKER_THRESHOLD:-0.5}"

# Log feature flag states for debugging
if [[ "${ENABLE_FAILURE_RETRY}" == "true" ]]; then
    log_info "✅ FAILURE_RETRY feature enabled"
fi
if [[ "${ENABLE_PARALLELISM_ETA}" == "true" ]]; then
    log_info "✅ PARALLELISM_ETA feature enabled"
fi
if [[ "${ENABLE_CONFIG_OPTIMIZER}" == "true" ]]; then
    log_info "✅ CONFIG_OPTIMIZER feature enabled"
fi
if [[ "${OPTIMIZER_SHADOW_MODE:-false}" == "true" ]]; then
    log_info "🔍 OPTIMIZER_SHADOW_MODE enabled - decisions will be logged but not applied"
fi

# ============================================================================
# GNU Parallel Support (Phase 3)
# ============================================================================

# Check if GNU Parallel is available
check_gnu_parallel_available() {
    if command -v parallel &>/dev/null; then
        # Verify it's GNU Parallel (not moreutils parallel)
        if parallel --version 2>&1 | grep -q "GNU parallel"; then
            return 0
        fi
    fi
    return 1
}

# Get optimal --jobs parameter for GNU Parallel (Legacy, Phase 3)
# DEPRECATED: Use get_dynamic_parallel_jobs() instead (Phase 4+)
# This function is kept for backward compatibility only
get_parallel_jobs_count() {
    local max_parallel_jobs="${1:-4}"

    # Use provided max_parallel_jobs, but cap at CPU count
    local cpu_count
    if command -v nproc &>/dev/null; then
        cpu_count=$(nproc)
    else
        cpu_count=4  # Fallback default
    fi

    # Return minimum of max_parallel_jobs and cpu_count
    if [ "$max_parallel_jobs" -le "$cpu_count" ]; then
        echo "$max_parallel_jobs"
    else
        echo "$cpu_count"
    fi
}

# ============================================================================
# Phase 4: Dynamic Job Count Adjustment (2025-11-08)
# ============================================================================

# Get dynamic parallel jobs based on CPU cores and AI count
# Implements Option A (Simple CPU Detection) from 7AI design discussion
# Design document: logs/7ai-reviews/20251108-223939-2269227-yaml/claude_phase1.md
#
# Arguments:
#   $1 - ai_count (default: 7): Number of AIs to execute
#   $2 - reserve_cores (default: 1): Cores to reserve for system
#
# Returns:
#   Optimal job count (min: 2, max: 32)
#
# Features:
#   - Multi-platform CPU detection (Linux, macOS, BSD)
#   - AI count awareness (never exceed number of AIs)
#   - Reserve cores mechanism (default: 1 core for system stability)
#   - Safety limits (min 2 jobs, max 32 jobs)
#   - Zero-config auto-detection
#   - Graceful degradation on unsupported platforms
#   - eta efficiency calculation when ENABLE_PARALLELISM_ETA=true
#
get_dynamic_parallel_jobs() {
    local ai_count="${1:-7}"
    local reserve_cores="${2:-1}"
    
    # Shadow mode: always use CPU-based calculation (don't apply optimization)
    if [[ "${OPTIMIZER_SHADOW_MODE:-false}" == "true" ]]; then
        # Shadow mode: log the decision but use original calculation
        if [[ "${ENABLE_PARALLELISM_ETA:-false}" == "true" ]]; then
            echo "🔍 SHADOW MODE: Would use eta efficiency calculation, but applying CPU-based fallback" >&2
        fi
        # Fall through to original CPU-based calculation below
    elif [[ "${ENABLE_PARALLELISM_ETA:-false}" == "true" ]]; then
        # Use eta efficiency calculation (normal mode, feature enabled)
        # Arguments: task_type, system_cpu_cores, available_memory_gb, io_intensive_task
        local recommended_jobs=$(recommend_parallel_jobs "default" "$ai_count")
        echo "$recommended_jobs"
        return 0
    fi

    # Original CPU-based calculation (shadow mode OR feature disabled)
    # 1. CPU detection with multi-platform support
    local cpu_count
    if command -v nproc &>/dev/null; then
        # Linux (most common)
        cpu_count=$(nproc 2>/dev/null || echo 4)
    elif [ -f /proc/cpuinfo ]; then
        # Linux fallback (when nproc not available)
        cpu_count=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 4)
    elif command -v sysctl &>/dev/null; then
        # macOS, BSD
        cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    else
        # Conservative fallback for unknown platforms
        cpu_count=4
        log_warning "Unable to detect CPU count, using fallback: ${cpu_count} cores"
    fi

    # 2. Calculate optimal jobs
    local available_cores=$((cpu_count - reserve_cores))
    local optimal_jobs

    # Never exceed number of AIs to execute
    if [ "$available_cores" -gt "$ai_count" ]; then
        optimal_jobs="$ai_count"
    else
        optimal_jobs="$available_cores"
    fi

    # 3. Apply safety limits
    local min_jobs=2
    local max_jobs=32

    if [ "$optimal_jobs" -lt "$min_jobs" ]; then
        optimal_jobs="$min_jobs"
    elif [ "$optimal_jobs" -gt "$max_jobs" ]; then
        optimal_jobs="$max_jobs"
    fi

    # 4. Log decision
    log_debug "Dynamic job calculation: CPU=${cpu_count}, Reserve=${reserve_cores}, AI count=${ai_count}, Optimal=${optimal_jobs}"

    echo "$optimal_jobs"
}

# ============================================================================
# AI Result Caching Mechanism (Phase 3)
# ============================================================================

# Cache directory for AI execution results
AI_CACHE_DIR="${PROJECT_ROOT:-.}/.cache/ai-results"
AI_CACHE_TTL="${AI_CACHE_TTL:-86400}"  # Default: 24 hours (86400 seconds)

# Initialize AI cache directory
init_ai_cache() {
    mkdir -p "$AI_CACHE_DIR" 2>/dev/null || {
        log_warning "Failed to create AI cache directory: $AI_CACHE_DIR"
        return 1
    }
    return 0
}

# Generate cache key from AI name and prompt
get_cache_key() {
    local ai="$1"
    local prompt="$2"

    # Use SHA256 hash of prompt for cache key
    local hash
    if command -v sha256sum &>/dev/null; then
        hash=$(echo -n "$prompt" | sha256sum | awk '{print $1}')
    elif command -v shasum &>/dev/null; then
        hash=$(echo -n "$prompt" | shasum -a 256 | awk '{print $1}')
    else
        # Fallback: use MD5 if SHA256 not available
        hash=$(echo -n "$prompt" | md5sum 2>/dev/null || echo -n "$prompt" | md5 2>/dev/null | awk '{print $1}')
    fi

    echo "${ai}-${hash}"
}

# Check if cache entry exists and is valid (within TTL)
check_cache() {
    local cache_key="$1"
    local cache_file="$AI_CACHE_DIR/${cache_key}.cache"
    local meta_file="$AI_CACHE_DIR/${cache_key}.meta"

    # Check if cache files exist
    if [ ! -f "$cache_file" ] || [ ! -f "$meta_file" ]; then
        # Cache verbose: Show cache miss details
        if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
            log_info "CACHE_MISS: key=${cache_key:0:16}... | file=$cache_file"
        fi
        return 1  # Cache miss
    fi

    # Read creation timestamp from meta file
    local created_at
    created_at=$(cat "$meta_file" 2>/dev/null || echo "0")

    # Check TTL
    local current_time=$(date +%s)
    local age=$((current_time - created_at))
    local ttl_remaining=$((AI_CACHE_TTL - age))

    if [ "$age" -gt "$AI_CACHE_TTL" ]; then
        # Cache expired
        if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
            log_info "CACHE_EXPIRED: key=${cache_key:0:16}... | age=${age}s > TTL=${AI_CACHE_TTL}s | expired_by=$((age - AI_CACHE_TTL))s"
        fi
        rm -f "$cache_file" "$meta_file" 2>/dev/null
        return 1
    fi

    # Cache verbose: Show cache hit details
    if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
        local file_size=$(wc -c < "$cache_file" 2>/dev/null || echo "0")
        log_info "CACHE_HIT: key=${cache_key:0:16}... | TTL_remaining=${ttl_remaining}s/${AI_CACHE_TTL}s | size=${file_size}B"
    fi

    return 0  # Cache hit
}

# Save AI execution result to cache
save_to_cache() {
    local cache_key="$1"
    local output_file="$2"

    init_ai_cache || return 1

    local cache_file="$AI_CACHE_DIR/${cache_key}.cache"
    local meta_file="$AI_CACHE_DIR/${cache_key}.meta"

    # Copy output to cache
    cp "$output_file" "$cache_file" 2>/dev/null || {
        log_warning "Failed to save cache: $cache_file"
        return 1
    }

    # Save metadata (creation timestamp)
    local created_at=$(date +%s)
    echo "$created_at" > "$meta_file"

    # Cache verbose: Show save details
    if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
        local file_size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
        local expiry_time=$((created_at + AI_CACHE_TTL))
        local expiry_date=$(date -d "@$expiry_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$expiry_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")
        log_info "CACHE_SAVE: key=${cache_key:0:16}... | size=${file_size}B | TTL=${AI_CACHE_TTL}s | expires_at=$expiry_date"
    fi

    return 0
}

# Load AI execution result from cache
load_from_cache() {
    local cache_key="$1"
    local output_file="$2"

    local cache_file="$AI_CACHE_DIR/${cache_key}.cache"
    local meta_file="$AI_CACHE_DIR/${cache_key}.meta"

    if [ ! -f "$cache_file" ]; then
        return 1  # Cache miss
    fi

    # Copy cache to output file
    cp "$cache_file" "$output_file" 2>/dev/null || {
        log_warning "Failed to load cache: $cache_file"
        return 1
    }

    # Cache verbose: Show load details
    if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
        local file_size=$(wc -c < "$cache_file" 2>/dev/null || echo "0")
        local created_at=$(cat "$meta_file" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local age=$((current_time - created_at))
        local ttl_remaining=$((AI_CACHE_TTL - age))
        log_info "CACHE_LOAD: key=${cache_key:0:16}... | size=${file_size}B | TTL_remaining=${ttl_remaining}s/${AI_CACHE_TTL}s | age=${age}s"
    else
        log_info "Cache hit - loaded from cache (TTL: ${AI_CACHE_TTL}s)"
    fi

    return 0
}

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
# Dependency Check Functions (P0.1.2)
# ============================================================================

# check_yq_dependency - Verify yq v4.x+ is installed for YAML parsing
# Usage: check_yq_dependency
# Returns: 0 if yq v4+ is available, 1 if missing or incompatible
# Output: Error messages to structured logging if yq is not found or version incompatible
check_yq_dependency() {
    if ! command -v yq &>/dev/null; then
        log_structured_error \
            "yq command not found" \
            "YAML parsing requires yq binary" \
            "Install yq: https://github.com/mikefarah/yq#install"
        return 1
    fi

    # yq version check (v4.x required)
    local yq_version
    # Use grep -E for macOS compatibility (grep -P not available on macOS)
    yq_version=$(yq --version 2>&1 | grep -oE 'version v?[0-9]+' | grep -oE '[0-9]+' | head -1)

    if [[ -z "$yq_version" ]]; then
        log_structured_error \
            "yq version detection failed" \
            "Unable to parse yq --version output" \
            "Ensure yq v4.x or later is installed: https://github.com/mikefarah/yq#install"
        return 1
    fi

    if [[ "$yq_version" -lt 4 ]]; then
        log_structured_error \
            "yq version too old (v$yq_version)" \
            "Requires yq v4.x or later" \
            "Upgrade yq: https://github.com/mikefarah/yq#install"
        return 1
    fi

    return 0
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

# Get phase input_from list (array of AI names)
get_phase_input_from() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
    local yaml_path=".profiles.\"$profile\".workflows.\"$workflow\".phases[$phase_idx].input_from"

    # Try cache first
    local cached_result
    if cached_result=$(get_cached_yaml "$yaml_path" "$config_file" 2>/dev/null); then
        if [ "$cached_result" = "null" ] || [ -z "$cached_result" ]; then
            echo ""
        else
            echo "$cached_result"
        fi
        return 0
    fi

    # Cache miss: query and cache
    local result
    result=$(yq eval "$yaml_path" "$config_file" 2>/dev/null)
    cache_yaml_result "$yaml_path" "$config_file" "$result"

    if [ "$result" = "null" ] || [ -z "$result" ]; then
        echo ""
    else
        echo "$result"
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
    local workflow_id="${6:-default}"  # Phase 4 Tier 2: workflow ID for incremental composition

    local phase_info
    phase_info=$(get_phase_info "$profile" "$workflow" "$phase_idx")
    local phase_name="${phase_info%|*}"
    local has_parallel="${phase_info#*|}"

    log_phase "$phase_name"

    # Phase 4 Tier 2 Task 4: Build dependency hashes using incremental-cache library
    local dependency_hashes="{}"
    if [ "$phase_idx" -gt 0 ]; then
        # Build list of dependency phase indices (0 to phase_idx-1)
        local dep_indices=()
        for ((dep_idx = 0; dep_idx < phase_idx; dep_idx++)); do
            dep_indices+=("$dep_idx")
        done

        # Use incremental-cache library to build dependency hashes
        if command -v build_dependency_hashes >/dev/null 2>&1; then
            dependency_hashes=$(build_dependency_hashes "$workflow_id" "${dep_indices[@]}" 2>/dev/null) || dependency_hashes="{}"
        fi
    fi

    # Phase 4 Tier 2 Task 4: Check cache validity using incremental-cache library
    if command -v check_phase_cache_valid >/dev/null 2>&1 && \
       check_phase_cache_valid "$workflow_id" "$phase_idx" "$dependency_hashes" 2>/dev/null; then
        # Cache valid - load from cache using incremental-cache library
        local ai
        ai=$(get_phase_ai "$profile" "$workflow" "$phase_idx" 2>/dev/null || echo "unknown")
        local cache_output="$work_dir/${ai}_phase${phase_idx}.md"

        if command -v load_phase_from_cache >/dev/null 2>&1 && \
           load_phase_from_cache "$workflow_id" "$phase_idx" "$cache_output" 2>/dev/null; then
            log_success "✓ Phase $((phase_idx + 1)) loaded from cache (incremental composition - 15-30% faster)"
            return 0
        else
            log_warning "Cache load failed, will re-execute phase"
        fi
    fi

    # Execute phase (existing logic)
    local exit_code=0
    if [ "$has_parallel" = "true" ]; then
        # Parallel execution
        execute_parallel_phase "$profile" "$workflow" "$phase_idx" "$task" "$work_dir"
        exit_code=$?
    else
        # Sequential execution
        execute_sequential_phase "$profile" "$workflow" "$phase_idx" "$task" "$work_dir"
        exit_code=$?
    fi

    # Phase 4 Tier 2: Save phase metadata if successful
    if [ $exit_code -eq 0 ]; then
        local ai
        ai=$(get_phase_ai "$profile" "$workflow" "$phase_idx" 2>/dev/null || echo "unknown")
        local role
        role=$(get_phase_role "$profile" "$workflow" "$phase_idx" 2>/dev/null || echo "unknown")
        local output_file="$work_dir/${ai}_phase${phase_idx}.md"

        if [ -f "$output_file" ]; then
            # Save metadata
            save_phase_metadata "$workflow_id" "$phase_idx" "$ai" "$role" "$output_file" "$dependency_hashes" 2>/dev/null || {
                log_warning "Failed to save phase metadata (non-critical)"
            }

            # Save output to cache
            local cached_file="$AI_CACHE_DIR/${workflow_id}/phase_${phase_idx}.cache"
            local cache_dir
            cache_dir=$(dirname "$cached_file")
            mkdir -p "$cache_dir" 2>/dev/null
            cp "$output_file" "$cached_file" 2>/dev/null || {
                log_warning "Failed to cache phase output (non-critical)"
            }
        fi
    fi

    return $exit_code
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

    # Use simple filename to avoid "filename too long" errors
    local output_file="$work_dir/${ai}_phase${phase_idx}.md"
    
    # Build prompt with input_from if specified
    local prompt="$task

Role: $role
AI: $ai"

    # Process input_from if specified
    local input_from
    input_from=$(get_phase_input_from "$profile" "$workflow" "$phase_idx")
    if [ -n "$input_from" ] && [ "$input_from" != "null" ]; then
        # Parse input_from array (comma-separated or YAML array format)
        local input_files=""
        local prev_phase_idx=$((phase_idx - 1))
        
        # Try to find output files from previous phase
        if [ "$prev_phase_idx" -ge 0 ]; then
            # Check if previous phase was parallel
            local prev_phase_info
            prev_phase_info=$(get_phase_info "$profile" "$workflow" "$prev_phase_idx")
            local prev_has_parallel="${prev_phase_info#*|}"
            
            if [ "$prev_has_parallel" = "true" ]; then
                # Previous phase was parallel - look for task files
                local parallel_count
                parallel_count=$(get_parallel_count "$profile" "$workflow" "$prev_phase_idx")
                for ((i = 0; i < parallel_count; i++)); do
                    local prev_ai
                    prev_ai=$(get_parallel_ai "$profile" "$workflow" "$prev_phase_idx" "$i")
                    local prev_output_file="$work_dir/${prev_ai}_task${i}.md"
                    if [ -f "$prev_output_file" ]; then
                        # Check if this AI is in input_from list
                        if echo "$input_from" | grep -q "\"$prev_ai\"" || echo "$input_from" | grep -q "$prev_ai"; then
                            if [ -n "$input_files" ]; then
                                input_files="$input_files\n\n"
                            fi
                            input_files="${input_files}--- $prev_ai output ---\n$(cat "$prev_output_file")"
                        fi
                    fi
                done
            else
                # Previous phase was sequential - look for phase file
                local prev_ai
                prev_ai=$(get_phase_ai "$profile" "$workflow" "$prev_phase_idx")
                local prev_output_file="$work_dir/${prev_ai}_phase${prev_phase_idx}.md"
                if [ -f "$prev_output_file" ]; then
                    input_files="--- Previous phase output ---\n$(cat "$prev_output_file")"
                fi
            fi
        fi
        
        if [ -n "$input_files" ]; then
            prompt="$prompt

Input from previous phase:
$input_files

Please synthesize the above inputs according to your role."
        fi
    else
        prompt="$prompt

Please complete this task according to your role."
    fi

    log_info "[$ai] Executing role: $role (timeout: ${timeout}s)"
    call_ai "$ai" "$prompt" "$timeout" "$output_file"
    return $?
}

# Execute parallel phase
# Execute parallel phase using GNU Parallel (Phase 3 optimization)
execute_parallel_phase_with_gnu_parallel() {
    local profile="${1:-$DEFAULT_PROFILE}"
    local workflow="$2"
    local phase_idx="$3"
    local task="$4"
    local work_dir="$5"
    local max_parallel_jobs="$6"

    local parallel_count
    parallel_count=$(get_parallel_count "$profile" "$workflow" "$phase_idx")

    if [ "$parallel_count" -eq 0 ]; then
        log_warning "No parallel tasks defined, skipping"
        return 0
    fi

    # Phase 4: Get dynamically adjusted --jobs count based on CPU detection
    local jobs_count
    jobs_count=$(get_dynamic_parallel_jobs "$parallel_count")

    log_info "Using dynamic parallel jobs (--jobs $jobs_count, detected from CPU count) for $parallel_count tasks..."

    # Create temporary directory for task metadata
    local task_metadata_dir
    task_metadata_dir=$(mktemp -d)
    trap "rm -rf '$task_metadata_dir'" EXIT INT TERM

    # Generate task metadata files (one per task)
    for ((i = 0; i < parallel_count; i++)); do
        local ai
        ai=$(get_parallel_ai "$profile" "$workflow" "$phase_idx" "$i")
        local role
        role=$(get_parallel_role "$profile" "$workflow" "$phase_idx" "$i")
        local timeout
        timeout=$(get_parallel_timeout "$profile" "$workflow" "$phase_idx" "$i")
        # Remove 's' suffix if present (GNU Parallel expects integer seconds)
        timeout="${timeout%s}"
        local name
        name=$(get_parallel_name "$profile" "$workflow" "$phase_idx" "$i")

        if [ "$ai" = "null" ] || [ -z "$ai" ]; then
            log_warning "No AI specified for parallel task $i, skipping"
            continue
        fi

        # Use simple filename to avoid "filename too long" errors
        local output_file="$work_dir/${ai}_task${i}.md"

        # Create metadata file for this task
        local metadata_file="$task_metadata_dir/task_${i}.meta"
        cat > "$metadata_file" <<EOF
AI=$ai
ROLE=$role
TIMEOUT=$timeout
TASK_NAME=$name
OUTPUT_FILE=$output_file
EOF

        # Create prompt file for this task
        local prompt_file="$task_metadata_dir/task_${i}.prompt"
        cat > "$prompt_file" <<EOF
$task

Role: $role
AI: $ai
Task Name: $name

Please complete this task according to your role.
EOF
    done

    # Execute tasks using Bash background jobs with parallel control
    log_info "Starting parallel execution with progress tracking..."

    local exit_code=0
    local start_time=$(date +%s)
    local -a bg_pids=()
    local completed=0
    local total_tasks=0

    # Count total tasks
    total_tasks=$(find "$task_metadata_dir" -name "*.meta" | wc -l)

    log_info "Using Bash background jobs with dynamic job count (max parallel: $jobs_count) for $total_tasks tasks..."

    # Execute each task
    for metadata_file in "$task_metadata_dir"/*.meta; do
        [ ! -f "$metadata_file" ] && continue

        # Wait if we've reached the parallel limit
        while [ "${#bg_pids[@]}" -ge "$jobs_count" ]; do
            # Check for completed jobs
            local new_pids=()
            for pid in "${bg_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                else
                    ((completed++))
                    wait "$pid" || exit_code=$?
                fi
            done
            bg_pids=("${new_pids[@]}")

            # Brief sleep to avoid busy-waiting
            [ "${#bg_pids[@]}" -ge "$jobs_count" ] && sleep 0.5
        done

        # Start task in background
        (
            # Ensure PROJECT_ROOT is set in subshell (inherit from parent if available)
            if [ -z "${PROJECT_ROOT:-}" ]; then
                # Fallback: try to detect from script location
                local script_dir
                script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
                PROJECT_ROOT=$(cd "$script_dir/../../.." && pwd)
            fi
            export PROJECT_ROOT

            # Source required libraries in subshell to ensure functions are available
            # This is necessary because subshells don't inherit exported functions reliably
            if [ -f "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh" ]; then
                source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh" >/dev/null 2>&1
            fi
            if [ -f "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-ai-interface.sh" ]; then
                source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-ai-interface.sh" >/dev/null 2>&1
            fi

            # Read metadata variables safely (without sourcing)
            local AI=$(grep "^AI=" "$metadata_file" | cut -d'=' -f2-)
            local ROLE=$(grep "^ROLE=" "$metadata_file" | cut -d'=' -f2-)
            local TIMEOUT=$(grep "^TIMEOUT=" "$metadata_file" | cut -d'=' -f2-)
            local TASK_NAME=$(grep "^TASK_NAME=" "$metadata_file" | cut -d'=' -f2-)
            local OUTPUT_FILE=$(grep "^OUTPUT_FILE=" "$metadata_file" | cut -d'=' -f2-)

            # Get corresponding prompt file
            local task_num="${metadata_file%.meta}"
            task_num="${task_num##*/task_}"
            local prompt_file="$task_metadata_dir/task_${task_num}.prompt"

            # Debug: Verify prompt file exists and has content
            if [ ! -f "$prompt_file" ]; then
                echo "ERROR: Prompt file not found: $prompt_file" >&2
                exit 1
            fi

            # Read full prompt from file
            local full_prompt
            full_prompt=$(cat "$prompt_file")

            # Debug: Verify prompt is not empty
            if [ -z "$full_prompt" ]; then
                echo "ERROR: Prompt is empty for task $task_num" >&2
                exit 1
            fi

            # Debug: Log prompt size and first 50 chars (using log_info if available)
            local prompt_size=${#full_prompt}
            local prompt_preview="${full_prompt:0:50}"
            if command -v log_info >/dev/null 2>&1; then
                log_info "[$AI] DEBUG: Calling with prompt (size: ${prompt_size}B, preview: ${prompt_preview}...)"
            else
                echo "DEBUG: [$AI] Calling with prompt (size: ${prompt_size}B, preview: ${prompt_preview}...)" >&2
            fi

            # Use call_ai_with_context to handle large prompts properly
            call_ai_with_context "$AI" "$full_prompt" "$TIMEOUT" "$OUTPUT_FILE"
        ) &

        local bg_pid=$!
        bg_pids+=("$bg_pid")

        # Get AI name from metadata for logging
        local ai_name
        ai_name=$(grep "^AI=" "$metadata_file" | cut -d'=' -f2)
        log_info "Started $ai_name (PID: $bg_pid, $((completed + ${#bg_pids[@]}))/$total_tasks)"
    done

    # Wait for all remaining jobs to complete
    log_info "Waiting for remaining tasks to complete..."
    local failed_tasks=0
    for pid in "${bg_pids[@]}"; do
        local task_exit_code=0
        wait "$pid" || task_exit_code=$?
        ((completed++))
        if [ "$task_exit_code" -ne 0 ]; then
            log_warning "Task $completed/$total_tasks failed with exit code: $task_exit_code"
            exit_code=$task_exit_code
            ((failed_tasks++))
        else
            log_info "Task completed ($completed/$total_tasks)"
        fi
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Parallel execution completed in ${duration}s"

    # Cleanup
    rm -rf "$task_metadata_dir"

    if [ "$exit_code" -ne 0 ]; then
        log_warning "Some tasks failed (exit code: $exit_code, failed tasks: $failed_tasks/$total_tasks)"
        # Don't fail the entire phase if some tasks failed - allow workflow to continue
        # This is a design decision: parallel tasks are independent, so partial failure is acceptable
        # The workflow can still proceed to Phase 2 with successful outputs
        return 0  # Return success to allow workflow to continue
    fi

    log_info "All parallel tasks completed successfully (Bash background jobs)"
    return 0
}

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
        local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
        yaml_max=$(yq eval ".execution.max_parallel_jobs // 4" "$config_file" 2>/dev/null || echo "4")
        if [[ "$yaml_max" =~ ^[0-9]+$ ]] && [ "$yaml_max" -gt 0 ]; then
            max_parallel_jobs=$yaml_max
        fi
    fi

    # Phase 3: Use GNU Parallel if available (5-7x speedup expected)
    if check_gnu_parallel_available; then
        log_info "GNU Parallel detected - using optimized execution"
        execute_parallel_phase_with_gnu_parallel "$profile" "$workflow" "$phase_idx" "$task" "$work_dir" "$max_parallel_jobs"
        return $?
    fi

    # Fallback to manual background job management
    log_info "Starting $parallel_count parallel AI tasks (max concurrent: $max_parallel_jobs)..."
    log_warning "GNU Parallel not available - using fallback implementation"

    # Track start time for duration calculation
    local start_time=$(date +%s)

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

        # Use simple filename to avoid "filename too long" errors
        local output_file="$work_dir/${ai}_task${i}.md"
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

    log_info "All tasks launched, waiting for completion..."

    # Wait for all parallel tasks to complete with progress tracking
    local phase_failed=false
    local nonblocking_issue=false
    local completed_count=0

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

        ((completed_count++))
        log_info "Progress: $completed_count/${#pids[@]} tasks completed"
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # P0.3.2.1: Cleanup job pool
    cleanup_job_pool

    if ! $phase_failed; then
        if $nonblocking_issue; then
            log_warning "Some non-blocking tasks failed (continuing) - Total time: ${duration}s"
        else
            log_success "All parallel tasks completed successfully in ${duration}s"
        fi
        return 0
    else
        log_error "Blocking parallel tasks failed after ${duration}s"
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

    # Phase 4 Tier 2: Generate workflow ID for incremental composition
    local WORKFLOW_ID
    WORKFLOW_ID=$(echo "${profile}-${workflow}-${task}" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo "$(date +%s)-$$")
    WORKFLOW_ID="${WORKFLOW_ID:0:16}"  # Use first 16 chars for brevity

    # Execute all phases sequentially
    for ((phase_idx = 0; phase_idx < phase_count; phase_idx++)); do
        execute_phase "$profile" "$workflow" "$phase_idx" "$task" "$WORK_DIR" "$WORKFLOW_ID" || {
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

# ============================================================================
# Phase 4 Tier 1: Enhanced Progress Display (2025-11-09)
# ============================================================================

# Environment variables for progress display
PROGRESS_MODE="${PROGRESS_MODE:-simple}"  # simple | verbose | minimal
CACHE_VERBOSE="${CACHE_VERBOSE:-false}"   # true | false

# Global progress tracking arrays
declare -gA PROGRESS_AI_STATUS=()    # AI name -> status (running|completed|failed|queued)
declare -gA PROGRESS_AI_ELAPSED=()   # AI name -> elapsed seconds
declare -gA PROGRESS_AI_PID=()       # AI name -> process ID
declare -g PROGRESS_TOTAL=0          # Total AI count
declare -g PROGRESS_COMPLETED=0      # Completed AI count
declare -g PROGRESS_START_TIME=0     # Workflow start time

# Load latency profiles from logs/metrics/ai-latency-profile.json
load_latency_profiles() {
    local profile_file="$PROJECT_ROOT/logs/metrics/ai-latency-profile.json"

    if [ ! -f "$profile_file" ]; then
        log_warning "Latency profile not found: $profile_file"
        return 1
    fi

    # Parse p50 values for each AI using jq
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, ETA estimation will use defaults"
        return 1
    fi

    # Load into associative array
    declare -gA AI_LATENCY_P50=(
        ["claude"]=$(jq -r '.claude.p50 // 30' "$profile_file" 2>/dev/null || echo 30)
        ["gemini"]=$(jq -r '.gemini.p50 // 48' "$profile_file" 2>/dev/null || echo 48)
        ["amp"]=$(jq -r '.amp.p50 // 16' "$profile_file" 2>/dev/null || echo 16)
        ["qwen"]=$(jq -r '.qwen.p50 // 9' "$profile_file" 2>/dev/null || echo 9)
        ["droid"]=$(jq -r '.droid.p50 // 42' "$profile_file" 2>/dev/null || echo 42)
        ["codex"]=$(jq -r '.codex.p50 // 2' "$profile_file" 2>/dev/null || echo 2)
        ["cursor"]=$(jq -r '.cursor.p50 // 2' "$profile_file" 2>/dev/null || echo 2)
    )

    return 0
}

# Get estimated execution time for an AI
get_ai_estimated_time() {
    local ai_name="$1"
    local default_time="${2:-60}"

    # Return from latency profile if available
    if [ -n "${AI_LATENCY_P50[$ai_name]+x}" ]; then
        echo "${AI_LATENCY_P50[$ai_name]}"
    else
        echo "$default_time"
    fi
}

# Calculate ETA based on remaining AIs and their latency profiles
calculate_eta() {
    local total_estimated=0
    local ai_name

    # Sum up estimated time for queued and running AIs
    for ai_name in "${!PROGRESS_AI_STATUS[@]}"; do
        local status="${PROGRESS_AI_STATUS[$ai_name]}"
        if [ "$status" = "queued" ] || [ "$status" = "running" ]; then
            local estimated=$(get_ai_estimated_time "$ai_name" 30)
            total_estimated=$((total_estimated + estimated))
        fi
    done

    echo "$total_estimated"
}

# Format time duration (seconds -> human readable)
format_time() {
    local seconds="$1"

    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        printf "%dm %02ds" "$mins" "$secs"
    else
        local hours=$((seconds / 3600))
        local mins=$(( (seconds % 3600) / 60))
        printf "%dh %02dm" "$hours" "$mins"
    fi
}

# Simple progress display (one line)
show_progress_simple() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - PROGRESS_START_TIME))
    local percent=0

    if [ "$PROGRESS_TOTAL" -gt 0 ]; then
        percent=$(( (PROGRESS_COMPLETED * 100) / PROGRESS_TOTAL ))
    fi

    local eta=$(calculate_eta)
    local eta_str=$(format_time "$eta")

    # Cache statistics (if cache verbose enabled)
    local cache_info=""
    if [ "$CACHE_VERBOSE" = "true" ]; then
        # Count cache hits/misses from recent logs
        local cache_hits=$(grep -c "CACHE_HIT" logs/vibe/$(date +%Y%m%d)/*.jsonl 2>/dev/null || echo 0)
        local cache_total=$(grep -c "CACHE_" logs/vibe/$(date +%Y%m%d)/*.jsonl 2>/dev/null || echo 1)
        cache_info=" | Cache: ${cache_hits}/${cache_total} hits"
    fi

    # Display progress line
    printf "\r[%d/%d] Progress: %3d%% | ETA: %s%s" \
        "$PROGRESS_COMPLETED" "$PROGRESS_TOTAL" "$percent" "$eta_str" "$cache_info"
}

# Verbose progress display (multi-line with per-AI status)
show_progress_verbose() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - PROGRESS_START_TIME))

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    printf "║ Multi-AI Progress [%d/%d completed]\n" "$PROGRESS_COMPLETED" "$PROGRESS_TOTAL"
    echo "╠════════════════════════════════════════════════════════════╣"

    # Display each AI status with progress bar
    local ai_name
    for ai_name in "${!PROGRESS_AI_STATUS[@]}"; do
        local status="${PROGRESS_AI_STATUS[$ai_name]}"
        local ai_elapsed="${PROGRESS_AI_ELAPSED[$ai_name]:-0}"
        local ai_estimated=$(get_ai_estimated_time "$ai_name" 60)

        # Status icon
        local icon="⏳"
        case "$status" in
            completed) icon="✅" ;;
            failed) icon="❌" ;;
            running) icon="🔄" ;;
            queued) icon="⏸️" ;;
        esac

        # Progress bar (20 characters)
        local progress=0
        if [ "$status" = "running" ] && [ "$ai_estimated" -gt 0 ]; then
            progress=$(( (ai_elapsed * 20) / ai_estimated ))
            [ "$progress" -gt 20 ] && progress=20
        elif [ "$status" = "completed" ]; then
            progress=20
        fi

        local bar=""
        for ((i=0; i<20; i++)); do
            if [ "$i" -lt "$progress" ]; then
                bar+="█"
            else
                bar+="░"
            fi
        done

        # Display AI row
        printf "║ %s %-8s [%s] %s\n" "$icon" "$ai_name" "$bar" "$status"
    done

    echo "╚════════════════════════════════════════════════════════════╝"

    # Cache statistics (if verbose)
    if [ "$CACHE_VERBOSE" = "true" ]; then
        local today=$(date +%Y%m%d)
        local cache_hits=$(grep -c "CACHE_HIT" logs/vibe/${today}/*.jsonl 2>/dev/null || echo 0)
        local cache_misses=$(grep -c "CACHE_MISS" logs/vibe/${today}/*.jsonl 2>/dev/null || echo 0)
        local cache_total=$((cache_hits + cache_misses))

        echo ""
        echo "Cache Statistics:"
        echo "  Hits: $cache_hits / $cache_total ($((cache_hits * 100 / (cache_total > 0 ? cache_total : 1)))%)"
        echo "  Misses: $cache_misses"
    fi
}

# Update progress display based on mode
update_progress() {
    case "$PROGRESS_MODE" in
        verbose)
            show_progress_verbose
            ;;
        minimal)
            # Minimal mode: no output
            :
            ;;
        simple|*)
            show_progress_simple
            ;;
    esac
}

# Initialize progress tracking for a workflow
init_progress_tracking() {
    local ai_list=("$@")

    PROGRESS_TOTAL=${#ai_list[@]}
    PROGRESS_COMPLETED=0
    PROGRESS_START_TIME=$(date +%s)

    # Load latency profiles
    load_latency_profiles

    # Initialize all AIs as queued
    local ai_name
    for ai_name in "${ai_list[@]}"; do
        PROGRESS_AI_STATUS["$ai_name"]="queued"
        PROGRESS_AI_ELAPSED["$ai_name"]=0
        PROGRESS_AI_PID["$ai_name"]=""
    done

    # Initial display
    update_progress
}

# Mark AI as running
mark_ai_running() {
    local ai_name="$1"
    local pid="${2:-}"

    PROGRESS_AI_STATUS["$ai_name"]="running"
    PROGRESS_AI_PID["$ai_name"]="$pid"
    PROGRESS_AI_ELAPSED["$ai_name"]=0

    update_progress
}

# Mark AI as completed
mark_ai_completed() {
    local ai_name="$1"
    local duration="${2:-0}"

    PROGRESS_AI_STATUS["$ai_name"]="completed"
    PROGRESS_AI_ELAPSED["$ai_name"]="$duration"
    PROGRESS_COMPLETED=$((PROGRESS_COMPLETED + 1))

    update_progress
}

# Mark AI as failed
mark_ai_failed() {
    local ai_name="$1"
    local duration="${2:-0}"

    PROGRESS_AI_STATUS["$ai_name"]="failed"
    PROGRESS_AI_ELAPSED["$ai_name"]="$duration"
    PROGRESS_COMPLETED=$((PROGRESS_COMPLETED + 1))

    update_progress
}

# ============================================================================
# Phase 4 Tier 2: Incremental Composition (Task 4) (2025-11-09)
# ============================================================================

# Calculate content hash of a file using SHA256
# Arguments:
#   $1 - file_path
# Returns:
#   SHA256 hash (stdout), empty string on failure
calculate_content_hash() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        log_warning "File not found for hashing: $file_path"
        echo ""
        return 1
    fi

    # Use sha256sum (Linux) or shasum -a 256 (macOS)
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | cut -d' ' -f1
    else
        log_error "No SHA256 utility available (sha256sum or shasum required)"
        echo ""
        return 1
    fi
}

# Save phase metadata with content hash and dependencies
# Arguments:
#   $1 - workflow_id
#   $2 - phase_idx
#   $3 - ai_name
#   $4 - role
#   $5 - output_file
#   $6 - dependency_hashes (JSON string, e.g., '{"phase_0": "abc123"}')
# Returns:
#   0 on success, 1 on failure
save_phase_metadata() {
    local workflow_id="$1"
    local phase_idx="$2"
    local ai_name="$3"
    local role="$4"
    local output_file="$5"
    local dependency_hashes="${6:-{}}"

    # Create metadata directory
    local meta_dir="$AI_CACHE_DIR/${workflow_id}"
    mkdir -p "$meta_dir" || {
        log_error "Failed to create metadata directory: $meta_dir"
        return 1
    }

    local meta_file="$meta_dir/phase_${phase_idx}.meta"

    # Calculate output hash
    local output_hash
    output_hash=$(calculate_content_hash "$output_file")
    if [ -z "$output_hash" ]; then
        log_warning "Failed to calculate hash for: $output_file"
        output_hash="error"
    fi

    local timestamp=$(date +%s)

    # Generate JSON metadata
    cat > "$meta_file" <<EOF
{
  "phase_idx": $phase_idx,
  "ai": "$ai_name",
  "role": "$role",
  "output_hash": "$output_hash",
  "dependency_hashes": $dependency_hashes,
  "timestamp": $timestamp,
  "ttl": $AI_CACHE_TTL
}
EOF

    # Cache verbose logging
    if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
        local hash_short="${output_hash:0:16}"
        log_info "PHASE_META_SAVE: workflow=$workflow_id | phase=$phase_idx | ai=$ai_name | hash=${hash_short}..."
    fi

    return 0
}

# Check if phase output has changed since last execution
# Arguments:
#   $1 - workflow_id
#   $2 - phase_idx
#   $3 - current_dependency_hashes (JSON string)
# Returns:
#   0 - No change detected (can use cache)
#   1 - Change detected (must re-execute)
# DEPRECATED: Use check_phase_cache_valid() from incremental-cache.sh instead
# This function is kept for backward compatibility but will be removed in future versions
# Migration path: Replace check_phase_changed() with check_phase_cache_valid()
check_phase_changed() {
    local workflow_id="$1"
    local phase_idx="$2"
    local current_dependency_hashes="${3:-{}}"

    # Redirect to new implementation if available
    if command -v check_phase_cache_valid >/dev/null 2>&1; then
        check_phase_cache_valid "$workflow_id" "$phase_idx" "$current_dependency_hashes"
        return $?
    fi

    # Fallback to legacy implementation
    local meta_file="$AI_CACHE_DIR/${workflow_id}/phase_${phase_idx}.meta"

    # No previous execution - must execute
    if [ ! -f "$meta_file" ]; then
        if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
            log_info "PHASE_CHANGE_DETECT: workflow=$workflow_id | phase=$phase_idx | status=NO_CACHE"
        fi
        return 1
    fi

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
            log_warning "PHASE_CHANGE_DETECT: jq not available, skipping dependency check"
        fi
        return 1
    fi

    # Read previous metadata
    local prev_dependency_hashes
    prev_dependency_hashes=$(jq -r '.dependency_hashes' "$meta_file" 2>/dev/null || echo "{}")

    # Compare dependency hashes (normalize JSON for comparison)
    local prev_normalized
    local curr_normalized
    prev_normalized=$(echo "$prev_dependency_hashes" | jq -S -c '.' 2>/dev/null || echo "{}")
    curr_normalized=$(echo "$current_dependency_hashes" | jq -S -c '.' 2>/dev/null || echo "{}")

    if [ "$prev_normalized" != "$curr_normalized" ]; then
        if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
            log_info "PHASE_CHANGE_DETECT: workflow=$workflow_id | phase=$phase_idx | status=DEPENDENCY_CHANGED"
        fi
        return 1
    fi

    # Check TTL
    local timestamp
    timestamp=$(jq -r '.timestamp' "$meta_file" 2>/dev/null || echo "0")
    # Handle null, empty, or non-numeric values
    if [[ ! "$timestamp" =~ ^[0-9]+$ ]]; then
        timestamp=0
    fi
    local current_time=$(date +%s)
    local age=$((current_time - timestamp))

    if [ "$age" -gt "$AI_CACHE_TTL" ]; then
        if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
            log_info "PHASE_CHANGE_DETECT: workflow=$workflow_id | phase=$phase_idx | status=TTL_EXPIRED | age=${age}s > TTL=${AI_CACHE_TTL}s"
        fi
        return 1
    fi

    # No change detected
    if [ "${CACHE_VERBOSE:-false}" = "true" ]; then
        local ttl_remaining=$((AI_CACHE_TTL - age))
        log_info "PHASE_CHANGE_DETECT: workflow=$workflow_id | phase=$phase_idx | status=NO_CHANGE | TTL_remaining=${ttl_remaining}s"
    fi

    return 0
}
