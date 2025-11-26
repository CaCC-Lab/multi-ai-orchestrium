#!/usr/bin/env bash
# AI Tools Checker - Error Classification System
# Version: 1.0.0
# Date: 2025-01-14
#
# Automatically classifies errors into 4 categories for intelligent retry decisions:
# - TRANSIENT: Network issues, timeouts (retry recommended)
# - PERSISTENT: API rate limits, auth errors (retry after delay)
# - FATAL: Syntax errors, invalid arguments (no retry)
# - CONFIGURATION: Missing env vars, CLI not installed (manual fix required)
#
# Features:
# - Exit code + error message pattern matching
# - JSON-based error pattern configuration
# - Integration with error-cache.sh for classification caching
# - VibeLogger integration for structured logging

# Source dependencies
_CLASSIFIER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$_CLASSIFIER_DIR/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/sanitize.sh" 2>/dev/null || true
source "${PROJECT_ROOT}/bin/vibe-logger-lib.sh" 2>/dev/null || true
source "${PROJECT_ROOT}/src/core/error-cache.sh" 2>/dev/null || true

# ============================================================
# Error Classification Categories
# ============================================================

# Error categories
readonly ERROR_CLASS_TRANSIENT="TRANSIENT"
readonly ERROR_CLASS_PERSISTENT="PERSISTENT"
readonly ERROR_CLASS_FATAL="FATAL"
readonly ERROR_CLASS_CONFIGURATION="CONFIGURATION"
readonly ERROR_CLASS_UNKNOWN="UNKNOWN"

# Error patterns configuration file
ERROR_PATTERNS_FILE="${PROJECT_ROOT}/config/error-patterns.json"

# ============================================================
# Core Classification Functions
# ============================================================

# classify_error(error_message, exit_code)
# Classifies an error based on message and exit code
#
# Arguments:
#   $1 - Error message
#   $2 - Exit code
# Outputs: Error classification (TRANSIENT|PERSISTENT|FATAL|CONFIGURATION|UNKNOWN)
# Returns: 0 on success
classify_error() {
    local error_message="$1"
    local exit_code="$2"

    # Input validation
    if [[ -z "$error_message" ]]; then
        log_warn "Empty error message provided to classify_error"
        echo "$ERROR_CLASS_UNKNOWN"
        return 0
    fi

    # Try cache first (if error-cache.sh is available)
    if declare -f cached_classify_error >/dev/null 2>&1; then
        local cached_result
        if cached_result=$(get_cached_classification "$error_message" "$exit_code"); then
            log_debug "Using cached classification: $cached_result"
            echo "$cached_result"
            return 0
        fi
    fi

    # Perform classification
    local classification
    classification=$(classify_by_exit_code "$exit_code" "$error_message")

    # If exit code classification is inconclusive, try message patterns
    if [[ "$classification" == "$ERROR_CLASS_UNKNOWN" ]]; then
        classification=$(classify_by_message "$error_message")
    fi

    # Cache the result (if error-cache.sh is available)
    if declare -f cache_classification >/dev/null 2>&1; then
        cache_classification "$error_message" "$exit_code" "$classification"
    fi

    # Log classification event
    if declare -f vibe_log >/dev/null 2>&1; then
        vibe_log "error_classification" "classified" \
            "{\"exit_code\": $exit_code, \"classification\": \"$classification\"}" \
            "Error classified as $classification" \
            "[]" \
            "error-classifier"
    fi

    echo "$classification"
    return 0
}

# classify_by_exit_code(exit_code, error_message)
# Classifies error based on exit code
#
# Arguments:
#   $1 - Exit code
#   $2 - Error message (for additional context)
# Outputs: Error classification
# Returns: 0 on success
classify_by_exit_code() {
    local exit_code="$1"
    local error_message="$2"

    case "$exit_code" in
        # Timeout errors - TRANSIENT
        124)
            echo "$ERROR_CLASS_TRANSIENT"
            ;;

        # Command not found - CONFIGURATION
        127)
            echo "$ERROR_CLASS_CONFIGURATION"
            ;;

        # Permission denied - CONFIGURATION
        126)
            echo "$ERROR_CLASS_CONFIGURATION"
            ;;

        # General error (1) - need message analysis
        1)
            # Check for specific patterns in message
            if [[ "$error_message" =~ rate.?limit|quota.?exceeded|too.?many.?requests ]]; then
                echo "$ERROR_CLASS_PERSISTENT"
            elif [[ "$error_message" =~ network|connection|timeout ]]; then
                echo "$ERROR_CLASS_TRANSIENT"
            elif [[ "$error_message" =~ syntax|invalid.?argument|parse.?error ]]; then
                echo "$ERROR_CLASS_FATAL"
            elif [[ "$error_message" =~ not.?found|command.?not.?found|no.?such ]]; then
                echo "$ERROR_CLASS_CONFIGURATION"
            else
                echo "$ERROR_CLASS_UNKNOWN"
            fi
            ;;

        # Connection errors - TRANSIENT
        110|111)
            echo "$ERROR_CLASS_TRANSIENT"
            ;;

        # Authentication errors - PERSISTENT
        401|403)
            echo "$ERROR_CLASS_PERSISTENT"
            ;;

        # Not found - FATAL (likely wrong resource)
        404)
            echo "$ERROR_CLASS_FATAL"
            ;;

        # Rate limit - PERSISTENT
        429)
            echo "$ERROR_CLASS_PERSISTENT"
            ;;

        # Server errors - TRANSIENT (might recover)
        500|502|503|504)
            echo "$ERROR_CLASS_TRANSIENT"
            ;;

        # Success or unknown
        0)
            echo "SUCCESS"
            ;;

        *)
            echo "$ERROR_CLASS_UNKNOWN"
            ;;
    esac
}

# classify_by_message(error_message)
# Classifies error based on message patterns
#
# Arguments:
#   $1 - Error message
# Outputs: Error classification
# Returns: 0 on success
classify_by_message() {
    local error_message="$1"

    # Load patterns from JSON if available
    if [[ -f "$ERROR_PATTERNS_FILE" ]]; then
        classify_from_json_patterns "$error_message"
        return $?
    fi

    # Fallback to built-in patterns
    if [[ "$error_message" =~ network|connection|timed?out|unreachable|refused ]]; then
        echo "$ERROR_CLASS_TRANSIENT"
    elif [[ "$error_message" =~ rate.?limit|quota|throttle|too.?many ]]; then
        echo "$ERROR_CLASS_PERSISTENT"
    elif [[ "$error_message" =~ syntax|parse|invalid|malformed|illegal ]]; then
        echo "$ERROR_CLASS_FATAL"
    elif [[ "$error_message" =~ not.?found|missing|absent|undefined|unset ]]; then
        echo "$ERROR_CLASS_CONFIGURATION"
    elif [[ "$error_message" =~ auth|credential|permission|forbidden|unauthorized ]]; then
        echo "$ERROR_CLASS_PERSISTENT"
    else
        echo "$ERROR_CLASS_UNKNOWN"
    fi
}

# classify_from_json_patterns(error_message)
# Classifies error using JSON pattern file
#
# Arguments:
#   $1 - Error message
# Outputs: Error classification
# Returns: 0 on success
classify_from_json_patterns() {
    local error_message="$1"

    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq not available, falling back to built-in patterns"
        classify_by_message "$error_message"
        return $?
    fi

    # Read patterns from JSON
    local patterns
    patterns=$(jq -r '.patterns[] | "\(.pattern):\(.class)"' "$ERROR_PATTERNS_FILE" 2>/dev/null)

    if [[ -z "$patterns" ]]; then
        log_warn "No patterns found in $ERROR_PATTERNS_FILE"
        echo "$ERROR_CLASS_UNKNOWN"
        return 0
    fi

    # Match against each pattern
    while IFS=: read -r pattern class; do
        if [[ "$error_message" =~ $pattern ]]; then
            echo "$class"
            return 0
        fi
    done <<< "$patterns"

    # No match found
    echo "$ERROR_CLASS_UNKNOWN"
}

# ============================================================
# Cache Integration (Task 6.2)
# ============================================================

# get_cached_classification(error_message, exit_code)
# Retrieves cached classification result
#
# Arguments:
#   $1 - Error message
#   $2 - Exit code
# Outputs: Cached classification (if found)
# Returns: 0 if hit, 1 if miss
get_cached_classification() {
    local error_message="$1"
    local exit_code="$2"

    # Check if error-cache.sh functions are available
    if ! declare -f generate_cache_key >/dev/null 2>&1; then
        return 1
    fi

    local cache_key
    cache_key=$(generate_cache_key "$error_message" "$exit_code")

    if ! declare -f cache_get >/dev/null 2>&1; then
        return 1
    fi

    cache_get "$cache_key"
}

# cache_classification(error_message, exit_code, classification)
# Caches classification result
#
# Arguments:
#   $1 - Error message
#   $2 - Exit code
#   $3 - Classification result
# Returns: 0 on success
cache_classification() {
    local error_message="$1"
    local exit_code="$2"
    local classification="$3"

    # Check if error-cache.sh functions are available
    if ! declare -f generate_cache_key >/dev/null 2>&1; then
        return 0
    fi

    local cache_key
    cache_key=$(generate_cache_key "$error_message" "$exit_code")

    if ! declare -f cache_set >/dev/null 2>&1; then
        return 0
    fi

    cache_set "$cache_key" "$classification"
}

# ============================================================
# Utility Functions
# ============================================================

# is_retriable(classification)
# Determines if an error should be retried based on classification
#
# Arguments:
#   $1 - Error classification
# Returns: 0 if retriable, 1 if not
is_retriable() {
    local classification="$1"

    case "$classification" in
        "$ERROR_CLASS_TRANSIENT"|"$ERROR_CLASS_PERSISTENT")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# get_retry_delay(classification, attempt)
# Suggests retry delay based on classification
#
# Arguments:
#   $1 - Error classification
#   $2 - Retry attempt number (default: 1)
# Outputs: Suggested delay in seconds
# Returns: 0 on success
get_retry_delay() {
    local classification="$1"
    local attempt="${2:-1}"

    case "$classification" in
        "$ERROR_CLASS_TRANSIENT")
            # Short delay with exponential backoff
            echo $(( 5 * (2 ** (attempt - 1)) ))
            ;;
        "$ERROR_CLASS_PERSISTENT")
            # Longer delay (e.g., for rate limits)
            echo $(( 60 * (2 ** (attempt - 1)) ))
            ;;
        *)
            # No retry
            echo "0"
            ;;
    esac
}

# format_classification_result(classification, is_retriable, retry_delay)
# Formats classification result as JSON
#
# Arguments:
#   $1 - Classification
#   $2 - Is retriable (true/false)
#   $3 - Retry delay in seconds
# Outputs: JSON formatted result
# Returns: 0 on success
format_classification_result() {
    local classification="$1"
    local is_retriable="$2"
    local retry_delay="$3"

    cat <<EOF
{
  "classification": "$classification",
  "retriable": $is_retriable,
  "retry_delay_seconds": $retry_delay
}
EOF
}

# ============================================================
# Logging Helpers
# ============================================================

log_debug() {
    [[ "${VERBOSE:-false}" == "true" ]] && echo "[DEBUG] $*" >&2
    return 0
}

log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Export functions for external use
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "This script should be sourced, not executed directly"
    exit 1
fi

log_debug "Error classifier module loaded"
