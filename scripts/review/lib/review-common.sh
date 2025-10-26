#!/usr/bin/env bash
# review-common.sh - Common review functions for Multi-AI Review System
# Version: 1.0.0
# Purpose: Provide shared functions for security-review.sh, quality-review.sh, enterprise-review.sh
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.1.1

set -euo pipefail

# ============================================================================
# Configuration & Setup
# ============================================================================

# Detect project root
if [[ -n "${PROJECT_ROOT:-}" ]]; then
    REVIEW_PROJECT_ROOT="$PROJECT_ROOT"
elif [[ -f "$(pwd)/CLAUDE.md" ]]; then
    REVIEW_PROJECT_ROOT="$(pwd)"
else
    REVIEW_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

# Load dependent libraries
source "$REVIEW_PROJECT_ROOT/bin/vibe-logger-lib.sh"
source "$REVIEW_PROJECT_ROOT/scripts/lib/sanitize.sh"

# Default review log directory
REVIEW_LOG_DIR="${REVIEW_LOG_DIR:-$REVIEW_PROJECT_ROOT/logs/multi-ai-reviews/$(date +%Y%m%d)}"

# Review prompt file
REVIEW_PROMPT_FILE="${REVIEW_PROMPT_FILE:-$REVIEW_PROJECT_ROOT/REVIEW-PROMPT.md}"
REVIEW_PROMPT_VERSION="${REVIEW_PROMPT_VERSION:-1.0}"

# Default timeouts per AI (seconds)
declare -A DEFAULT_TIMEOUTS=(
    ["claude"]=300
    ["gemini"]=600    # Web search requires more time
    ["qwen"]=300      # Fast prototyping
    ["droid"]=900     # Comprehensive enterprise analysis
    ["codex"]=300
    ["cursor"]=600
    ["amp"]=600
)

# ============================================================================
# Git Operations
# ============================================================================

# Get git diff for a commit or range
# Usage: get_git_diff [commit_hash]
# Returns: Git diff output (stdout)
get_git_diff() {
    local commit="${1:-HEAD}"

    # Validate we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi

    # Get diff
    if [[ "$commit" == "HEAD" ]]; then
        # Show uncommitted changes
        git diff HEAD
    else
        # Show specific commit diff
        git show "$commit" --format=fuller
    fi
}

# Validate commit hash format and existence
# Usage: validate_commit_hash <commit_hash>
# Returns: 0 if valid, 1 if invalid
validate_commit_hash() {
    local commit="$1"

    # Check format (40-char SHA-1 or short hash)
    if ! [[ "$commit" =~ ^[0-9a-f]{7,40}$ ]]; then
        echo "Error: Invalid commit hash format: $commit" >&2
        return 1
    fi

    # Verify commit exists in repository
    if ! git cat-file -e "${commit}^{commit}" 2>/dev/null; then
        echo "Error: Commit not found: $commit" >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Directory Management
# ============================================================================

# Setup review log directories
# Usage: setup_review_dirs <review_type>
# Returns: Review output directory path (stdout)
setup_review_dirs() {
    local review_type="$1"  # security|quality|enterprise
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    # Create main log directory
    mkdir -p "$REVIEW_LOG_DIR"

    # Create review-type specific directory
    local review_dir="$REVIEW_LOG_DIR/${timestamp}-${review_type}"
    mkdir -p "$review_dir"
    mkdir -p "$review_dir/output"
    mkdir -p "$review_dir/temp"

    # Set secure permissions
    chmod 700 "$review_dir"
    chmod 700 "$review_dir/temp"

    echo "$review_dir"
}

# Cleanup temporary review files
# Usage: cleanup_review_files <review_dir>
cleanup_review_files() {
    local review_dir="$1"

    if [[ -d "$review_dir/temp" ]]; then
        # Secure deletion of sensitive data
        find "$review_dir/temp" -type f -exec shred -u {} \; 2>/dev/null || \
            rm -rf "$review_dir/temp"
    fi
}

# ============================================================================
# VibeLogger Integration - Review-specific functions
# ============================================================================

# Log review start
# Usage: vibe_review_start <review_type> <ai_name> <commit_hash>
vibe_review_start() {
    local review_type="$1"
    local ai_name="$2"
    local commit="$3"

    local metadata
    metadata=$(cat << EOF
{
  "review_type": "$review_type",
  "ai": "$ai_name",
  "commit": "$commit",
  "timestamp_start": "$(date +%s)"
}
EOF
)

    vibe_log "review_lifecycle" "start" "$metadata" \
        "Starting $review_type review with $ai_name for commit $commit" \
        "Execute AI review, validate output" \
        "Review-${review_type}"
}

# Log review completion
# Usage: vibe_review_done <review_type> <ai_name> <status> <duration_ms> <findings_count>
vibe_review_done() {
    local review_type="$1"
    local ai_name="$2"
    local status="$3"      # success|failure|timeout
    local duration_ms="$4"
    local findings_count="${5:-0}"

    local metadata
    metadata=$(cat << EOF
{
  "review_type": "$review_type",
  "ai": "$ai_name",
  "status": "$status",
  "duration_ms": $duration_ms,
  "findings_count": $findings_count,
  "timestamp_end": "$(date +%s)"
}
EOF
)

    vibe_log "review_lifecycle" "complete" "$metadata" \
        "Completed $review_type review ($status) - $findings_count findings in ${duration_ms}ms" \
        "" \
        "Review-${review_type}"
}

# Log review error
# Usage: vibe_review_error <review_type> <ai_name> <error_message>
vibe_review_error() {
    local review_type="$1"
    local ai_name="$2"
    local error_msg="$3"

    local metadata
    metadata=$(cat << EOF
{
  "review_type": "$review_type",
  "ai": "$ai_name",
  "error": "$(echo "$error_msg" | sed 's/"/\\"/g')",
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "review_error" "error" "$metadata" \
        "Review error in $review_type ($ai_name): $error_msg" \
        "Check AI logs, verify configuration" \
        "Review-${review_type}"
}

# ============================================================================
# Input Sanitization - Review-specific
# ============================================================================

# Sanitize commit hash input
# Usage: sanitize_commit_input <commit_hash>
# Returns: Sanitized commit hash (stdout), exit code 0 on success
sanitize_commit_input() {
    local commit="$1"

    # Remove any non-hex characters (allow 0-9, a-f, A-F only)
    local sanitized
    sanitized=$(echo "$commit" | tr -cd '0-9a-fA-F')

    # Truncate to max 40 characters (SHA-1 length)
    sanitized="${sanitized:0:40}"

    if [[ -z "$sanitized" ]]; then
        echo "Error: Empty commit hash after sanitization" >&2
        return 1
    fi

    echo "$sanitized"
}

# Sanitize file path for review output
# Usage: sanitize_file_path <file_path>
# Returns: Repo-relative path (stdout)
sanitize_file_path() {
    local file_path="$1"
    local repo_root

    # Get repository root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "Error: Not in a git repository" >&2
        return 1
    }

    # Convert to absolute path if relative
    if [[ ! "$file_path" =~ ^/ ]]; then
        file_path="$(pwd)/$file_path"
    fi

    # Remove repository root prefix to get relative path
    local relative_path="${file_path#$repo_root/}"

    # Validate: no path traversal attempts
    if [[ "$relative_path" =~ \.\. ]]; then
        echo "Error: Path traversal detected: $relative_path" >&2
        return 1
    fi

    echo "$relative_path"
}

# ============================================================================
# Timeout Execution
# ============================================================================

# Run review command with timeout
# Usage: run_review_with_timeout <timeout_seconds> <command> [args...]
# Returns: Command exit code
run_review_with_timeout() {
    local timeout_sec="$1"
    shift
    local cmd=("$@")

    # Use timeout command (GNU coreutils)
    if command -v timeout &> /dev/null; then
        timeout "${timeout_sec}s" "${cmd[@]}"
        return $?
    else
        # Fallback: bash built-in with background job
        "${cmd[@]}" &
        local pid=$!

        ( sleep "$timeout_sec" && kill -TERM "$pid" 2>/dev/null ) &
        local killer_pid=$!

        wait "$pid" 2>/dev/null
        local exit_code=$?

        kill -TERM "$killer_pid" 2>/dev/null
        return $exit_code
    fi
}

# Get default timeout for AI
# Usage: get_default_timeout <ai_name>
# Returns: Timeout in seconds (stdout)
get_default_timeout() {
    local ai_name="$1"
    echo "${DEFAULT_TIMEOUTS[$ai_name]:-300}"
}

# ============================================================================
# API Key Management
# ============================================================================

# Check if required API keys are set
# Usage: check_api_keys <ai_name> [fallback_ai_name]
# Returns: 0 if all keys present, 1 if missing
check_api_keys() {
    local ai_name="$1"
    local fallback_ai="${2:-}"
    local missing_keys=()

    # Check primary AI key
    local env_var_name="${ai_name^^}_API_KEY"
    if [[ -z "${!env_var_name:-}" ]]; then
        missing_keys+=("$env_var_name")
    fi

    # Check fallback AI key if specified
    if [[ -n "$fallback_ai" ]]; then
        local fallback_var="${fallback_ai^^}_API_KEY"
        if [[ -z "${!fallback_var:-}" ]]; then
            missing_keys+=("$fallback_var")
        fi
    fi

    # Report missing keys
    if [[ ${#missing_keys[@]} -gt 0 ]]; then
        echo "Error: Missing required API keys:" >&2
        for key in "${missing_keys[@]}"; do
            echo "  - $key" >&2
        done
        echo "" >&2
        echo "Please set environment variables before running:" >&2
        for key in "${missing_keys[@]}"; do
            echo "  export $key=\"your-api-key\"" >&2
        done
        return 1
    fi

    return 0
}

# ============================================================================
# Exports
# ============================================================================

# Export all functions for use in review scripts
export -f get_git_diff
export -f validate_commit_hash
export -f setup_review_dirs
export -f cleanup_review_files
export -f vibe_review_start
export -f vibe_review_done
export -f vibe_review_error
export -f sanitize_commit_input
export -f sanitize_file_path
export -f run_review_with_timeout
export -f get_default_timeout
export -f check_api_keys

# Export configuration variables
export REVIEW_PROJECT_ROOT
export REVIEW_LOG_DIR
export REVIEW_PROMPT_FILE
export REVIEW_PROMPT_VERSION
