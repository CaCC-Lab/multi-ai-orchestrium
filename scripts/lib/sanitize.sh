#!/bin/bash
# Input Sanitization Library
# Provides functions to sanitize user inputs before shell execution
#
# Security: Prevents command injection attacks
# Reference: CodeRabbit Review - Issue #3

set -euo pipefail

# Maximum prompt size for standard operations (100KB)
# Increased from 10KB to support workflow operations with large prompts
# File-based prompt system handles >100KB automatically via temporary files
readonly MAX_PROMPT_SIZE=102400

# Maximum prompt size for workflow operations (1MB)
# Used for multi-AI workflows that may generate very large combined prompts
readonly MAX_WORKFLOW_PROMPT_SIZE=1048576

# Sanitize user prompts for safe shell execution
#
# Arguments:
#   $1 - Input prompt string
#
# Returns:
#   Sanitized prompt string (stdout)
#   Exit code 0 on success, 1 on error
#
# Example:
#   sanitized=$(sanitize_prompt "$user_input")
#
sanitize_prompt() {
    local prompt="$1"

    # Validation: Check for empty/null input
    if [ -z "${prompt:-}" ]; then
        echo "ERROR: Empty prompt provided" >&2
        return 1
    fi

    # Validation: Check prompt length
    local prompt_length=${#prompt}
    if [ "$prompt_length" -gt "$MAX_PROMPT_SIZE" ]; then
        echo "ERROR: Prompt exceeds maximum size ($prompt_length > $MAX_PROMPT_SIZE bytes)" >&2
        return 1
    fi

    # Escape shell metacharacters to prevent command injection
    # Dangerous characters: ' ` $ \ " ; | & < > ( ) { } [ ] * ? # ~ !
    #
    # Strategy: Use printf '%q' for shell-safe quoting (bash built-in)
    # This properly escapes all special characters while preserving the string content
    printf '%q' "$prompt"

    return 0
}

# Sanitize prompt and save to temporary file for large inputs
#
# Arguments:
#   $1 - Input prompt string
#   $2 - (Optional) Output file path. If not provided, creates temp file
#
# Returns:
#   Path to file containing sanitized prompt (stdout)
#   Exit code 0 on success, 1 on error
#
# Example:
#   prompt_file=$(sanitize_prompt_to_file "$large_prompt")
#
sanitize_prompt_to_file() {
    local prompt="$1"
    local output_file="${2:-}"

    # Create temp file if not provided
    if [ -z "$output_file" ]; then
        output_file=$(mktemp "${TMPDIR:-/tmp}/prompt.XXXXXX")
    fi

    # Validate and sanitize
    local sanitized
    sanitized=$(sanitize_prompt "$prompt") || return 1

    # Write to file
    echo "$sanitized" > "$output_file"

    # Output file path
    echo "$output_file"

    return 0
}

# Check if prompt should use file-based input (size threshold: 1KB)
#
# Arguments:
#   $1 - Input prompt string
#
# Returns:
#   Exit code 0 if should use file, 1 if can use direct argument
#
# Example:
#   if should_use_file "$prompt"; then
#       prompt_file=$(sanitize_prompt_to_file "$prompt")
#   fi
#
should_use_file() {
    local prompt="$1"
    local prompt_length=${#prompt}

    # Use file for prompts larger than 1KB
    [ "$prompt_length" -gt 1024 ]
}

# Sanitize log output to prevent sensitive data leakage
#
# Arguments:
#   $1 - Log message
#
# Returns:
#   Sanitized log message (stdout)
#
# Redacts:
#   - API keys (pattern: *_KEY, *_TOKEN, *_SECRET)
#   - Email addresses
#   - IP addresses (optionally)
#   - URLs with credentials
#
# Example:
#   safe_log=$(sanitize_log_output "$log_message")
#
sanitize_log_output() {
    local log_message="$1"

    # Redact API keys, tokens, secrets
    log_message=$(echo "$log_message" | sed -E 's/([A-Z_]+_(KEY|TOKEN|SECRET)=)[^ ]+/\1***REDACTED***/g')

    # Redact email addresses
    log_message=$(echo "$log_message" | sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/***EMAIL_REDACTED***/g')

    # Redact URLs with credentials (e.g., https://user:pass@example.com)
    log_message=$(echo "$log_message" | sed -E 's|(https?://)[^:]+:[^@]+@|\1***CREDS_REDACTED***@|g')

    # Redact JWT tokens (Bearer tokens)
    log_message=$(echo "$log_message" | sed -E 's/(Bearer )[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/\1***JWT_REDACTED***/g')

    echo "$log_message"
}

# Get sanitized prompt length (for logging without exposing content)
#
# Arguments:
#   $1 - Input prompt string
#
# Returns:
#   Prompt length in bytes (stdout)
#
# Example:
#   log_info "Prompt length: $(get_prompt_length "$prompt") bytes"
#
get_prompt_length() {
    local prompt="$1"
    echo "${#prompt}"
}

# Get SHA256 hash of prompt (for logging/tracking without exposing content)
#
# Arguments:
#   $1 - Input prompt string
#
# Returns:
#   SHA256 hash (stdout)
#
# Example:
#   prompt_hash=$(get_prompt_hash "$prompt")
#   log_info "Processing prompt (hash: $prompt_hash)"
#
get_prompt_hash() {
    local prompt="$1"
    echo -n "$prompt" | sha256sum | awk '{print $1}'
}

# Sanitize prompts for workflow operations (relaxed size limits)
#
# Arguments:
#   $1 - Input prompt string
#   $2 - (Optional) Force file mode: "auto" (default) | "file" | "direct"
#
# Returns:
#   Sanitized prompt string (stdout)
#   Exit code 0 on success, 1 on error
#
# Strategy:
#   - Uses MAX_WORKFLOW_PROMPT_SIZE (1MB) instead of MAX_PROMPT_SIZE (100KB)
#   - Automatically uses file mode for prompts >100KB
#   - Supports force file mode for testing/debugging
#
# Example:
#   sanitized=$(sanitize_workflow_prompt "$large_prompt")
#   sanitized=$(sanitize_workflow_prompt "$prompt" "file")
#
sanitize_workflow_prompt() {
    local prompt="$1"
    local mode="${2:-auto}"

    # Validation: Check for empty/null input
    if [ -z "${prompt:-}" ]; then
        echo "ERROR: Empty prompt provided" >&2
        return 1
    fi

    # Validation: Check prompt length
    local prompt_length=${#prompt}
    if [ "$prompt_length" -gt "$MAX_WORKFLOW_PROMPT_SIZE" ]; then
        echo "ERROR: Prompt exceeds maximum workflow size ($prompt_length > $MAX_WORKFLOW_PROMPT_SIZE bytes)" >&2
        echo "HINT: Use file-based input or split into smaller chunks" >&2
        return 1
    fi

    # Auto-detect file mode for large prompts (>100KB)
    if [ "$mode" = "auto" ] && [ "$prompt_length" -gt "$MAX_PROMPT_SIZE" ]; then
        mode="file"
    fi

    # If file mode is required/recommended, log a hint
    if [ "$mode" = "file" ] || [ "$prompt_length" -gt "$MAX_PROMPT_SIZE" ]; then
        echo "INFO: Large prompt detected ($prompt_length bytes), recommend file-based input" >&2
    fi

    # Escape shell metacharacters to prevent command injection
    printf '%q' "$prompt"

    return 0
}

# Validate and sanitize prompt with automatic fallback strategy
#
# Arguments:
#   $1 - Input prompt string
#
# Returns:
#   Sanitized prompt string (stdout)
#   Exit code 0 on success, 1 on error
#
# Fallback Strategy:
#   1. Try standard sanitize (MAX_PROMPT_SIZE=100KB)
#   2. If size exceeded, try workflow sanitize (MAX_WORKFLOW_PROMPT_SIZE=1MB)
#   3. If still exceeded, fail with clear error message
#
# Example:
#   sanitized=$(sanitize_with_fallback "$potentially_large_prompt")
#
sanitize_with_fallback() {
    local prompt="$1"
    local prompt_length=${#prompt}

    # Try standard sanitize first
    if [ "$prompt_length" -le "$MAX_PROMPT_SIZE" ]; then
        sanitize_prompt "$prompt"
        return $?
    fi

    # Fallback to workflow sanitize
    echo "WARN: Prompt size ($prompt_length bytes) exceeds standard limit, using workflow sanitize" >&2
    sanitize_workflow_prompt "$prompt"
    return $?
}

# Export functions for use in other scripts
export -f sanitize_prompt
export -f sanitize_prompt_to_file
export -f should_use_file
export -f sanitize_log_output
export -f get_prompt_length
export -f get_prompt_hash
export -f sanitize_workflow_prompt
export -f sanitize_with_fallback
