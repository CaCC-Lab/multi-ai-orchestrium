#!/usr/bin/env bash
# adapter-gemini.sh - Gemini-specific review adapter
# Version: 1.0.0
# Purpose: Web search-enhanced security review using Gemini AI
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.2.1

set -euo pipefail

# ============================================================================
# Source Dependencies
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_BASE="${SCRIPT_DIR}/adapter-base.sh"
REVIEW_LIB_DIR="$(dirname "$SCRIPT_DIR")"
REVIEW_PROMPT_LOADER="${REVIEW_LIB_DIR}/review-prompt-loader.sh"

# Source base adapter template
if [[ -f "$ADAPTER_BASE" ]]; then
    source "$ADAPTER_BASE"
else
    echo "Error: adapter-base.sh not found at: $ADAPTER_BASE" >&2
    exit 1
fi

# Source review prompt loader (for extend_prompt_for_gemini)
if [[ -f "$REVIEW_PROMPT_LOADER" ]]; then
    source "$REVIEW_PROMPT_LOADER"
else
    echo "Error: review-prompt-loader.sh not found at: $REVIEW_PROMPT_LOADER" >&2
    exit 1
fi

# ============================================================================
# Configuration
# ============================================================================

# AI name for this adapter
AI_NAME="gemini"

# Default timeout (10 minutes for Web search overhead)
DEFAULT_TIMEOUT=600

# CVE cache configuration (P0.3.2.1: mandatory feature for performance)
CVE_CACHE_ENABLED="${CVE_CACHE_ENABLED:-true}"
CVE_CACHE_DIR="${CACHE_DIR:-/tmp}/cve-cache"
CVE_CACHE_TTL="${CVE_CACHE_TTL:-86400}"  # 24 hours

# ============================================================================
# P1.2.1.1: Web Search Integration Prompt
# ============================================================================

# This functionality is already implemented in review-prompt-loader.sh
# as extend_prompt_for_gemini(). We inherit it from the base adapter.

# ============================================================================
# P1.2.1.2: Gemini CLI Invocation
# ============================================================================

# Call Gemini wrapper with appropriate timeout
# Usage: call_gemini_review <prompt> [timeout]
# Returns: Review output (stdout)
call_gemini_review() {
    local prompt="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"

    # Extend prompt with Gemini-specific instructions
    local extended_prompt
    extended_prompt=$(extend_prompt_for_gemini "$prompt")

    # Call base adapter's execute_ai_review
    execute_ai_review "$AI_NAME" "$extended_prompt" "$timeout"
}

# ============================================================================
# P1.2.1.3: CVE Cache Mechanism (P0.3.2.1: Mandatory)
# ============================================================================

# Initialize CVE cache directory (always called, mandatory feature)
init_cve_cache() {
    if [[ "$CVE_CACHE_ENABLED" != "true" ]]; then
        echo "Warning: CVE caching is disabled. Performance may be degraded." >&2
        return 0
    fi

    if [[ ! -d "$CVE_CACHE_DIR" ]]; then
        mkdir -p "$CVE_CACHE_DIR"
        chmod 700 "$CVE_CACHE_DIR"
    fi
}

# Get CVE information from cache or Web search
# Usage: get_cve_info <library> <version>
# Returns: CVE information (stdout)
get_cve_info() {
    local library="$1"
    local version="$2"

    if [[ "$CVE_CACHE_ENABLED" != "true" ]]; then
        # Cache disabled, skip
        return 0
    fi

    local cache_key="${library}-${version}"
    # Sanitize cache key for filename safety
    cache_key=$(echo "$cache_key" | tr '/' '_' | tr -cd '[:alnum:]._-')
    local cache_file="${CVE_CACHE_DIR}/${cache_key}.json"

    # Check cache first
    if [[ -f "$cache_file" ]]; then
        # Check if cache is still valid (within TTL)
        local cache_age
        cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))

        if [[ $cache_age -lt $CVE_CACHE_TTL ]]; then
            # Cache hit and still valid
            cat "$cache_file"
            return 0
        else
            # Cache expired, remove it
            rm -f "$cache_file"
        fi
    fi

    # Cache miss or expired - would need Web search here
    # For now, return empty (Web search will be done by Gemini during review)
    echo "{\"library\": \"$library\", \"version\": \"$version\", \"cached\": false}"

    # Note: In a full implementation, we would:
    # 1. Call Gemini for Web search
    # 2. Cache the results
    # 3. Return cached data
    # This is optional and can be enhanced later
}

# Warm up CVE cache for common libraries
# Usage: warm_cve_cache <libraries_array>
warm_cve_cache() {
    if [[ "$CVE_CACHE_ENABLED" != "true" ]]; then
        return 0
    fi

    init_cve_cache

    # This is a placeholder for cache warming
    # In a full implementation, we would parse dependencies
    # and pre-fetch CVE information for known libraries
}

# ============================================================================
# Gemini-Specific Review Function
# ============================================================================

# Main review function for Gemini adapter
# Usage: gemini_review <commit_hash_or_diff> [timeout]
# Returns: Structured review output (JSON format)
gemini_review() {
    local target="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"

    # Initialize CVE cache
    init_cve_cache

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt)

    # Add commit/diff context
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

## Code to Review

$target

EOF
)

    # Execute review with Web search enhancement
    call_gemini_review "$full_prompt" "$timeout"
}

# ============================================================================
# Exports
# ============================================================================

# Export Gemini-specific functions
export -f call_gemini_review
export -f gemini_review
export -f init_cve_cache
export -f get_cve_info
export -f warm_cve_cache

# Export configuration
export AI_NAME
export DEFAULT_TIMEOUT
export CVE_CACHE_ENABLED
export CVE_CACHE_DIR
export CVE_CACHE_TTL

# ============================================================================
# Standalone Execution Support
# ============================================================================

# Allow this adapter to be run standalone for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse arguments
    COMMIT_OR_DIFF="${1:-HEAD}"
    TIMEOUT="${2:-$DEFAULT_TIMEOUT}"

    echo "Running Gemini review adapter..." >&2
    echo "Target: $COMMIT_OR_DIFF" >&2
    echo "Timeout: ${TIMEOUT}s" >&2
    echo "" >&2

    # Execute review
    gemini_review "$COMMIT_OR_DIFF" "$TIMEOUT"
fi
