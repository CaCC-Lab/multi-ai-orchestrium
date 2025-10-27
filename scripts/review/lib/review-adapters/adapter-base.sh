#!/bin/bash
# adapter-base.sh - Base adapter template for AI-specific review implementations
# Version: 1.1
# Template Method Pattern for reducing duplication by 60%

# Source common libraries (will be available when review-common.sh is implemented)
# Use ADAPTER_BASE_DIR to avoid conflict with SCRIPT_DIR in child adapters
ADAPTER_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_LIB_DIR="$(dirname "$ADAPTER_BASE_DIR")"

# Debug logging helper
# Set DEBUG_REVIEW=1 to enable debug output
debug_log() {
    if [[ "${DEBUG_REVIEW:-0}" == "1" ]]; then
        echo "DEBUG: $*" >&2
    fi
}

# Template method: Main review execution flow
# This function defines the skeleton of the review algorithm
# Subclasses can override specific steps without changing the overall structure
execute_ai_review() {
    local ai_name="$1"
    local prompt="$2"
    local timeout="$3"
    local file_context="${4:-}"  # Optional: file path or git diff context

    # Validation
    if [[ -z "$ai_name" ]] || [[ -z "$prompt" ]] || [[ -z "$timeout" ]]; then
        echo "Error: Missing required parameters" >&2
        echo "Usage: execute_ai_review AI_NAME PROMPT TIMEOUT [FILE_CONTEXT]" >&2
        return 1
    fi

    # Step 1: Common preprocessing (hook for extension)
    local extended_prompt
    extended_prompt=$(preprocess_prompt "$ai_name" "$prompt" "$file_context")

    # Step 2: AI-specific execution (must be overridden in subclasses)
    local output
    output=$(call_ai_wrapper "$ai_name" "$extended_prompt" "$timeout")
    local exit_code=$?

    debug_log "[execute_ai_review] output size after call_ai_wrapper: ${#output} bytes"

    # Step 3: Common postprocessing
    if [[ $exit_code -eq 0 ]]; then
        # Validate output (this may modify output variable)
        local validated_output
        validated_output=$(validate_review_output "$output")
        local validation_exit=$?

        debug_log "[execute_ai_review] validated_output size: ${#validated_output} bytes"
        debug_log "[execute_ai_review] validation_exit: $validation_exit"

        if [[ $validation_exit -eq 0 ]]; then
            # Echo the validated output for capture
            debug_log "[execute_ai_review] About to echo validated_output..."
            echo "$validated_output"
            debug_log "[execute_ai_review] Echoed validated_output successfully"
            return 0
        else
            debug_log "[execute_ai_review] Validation failed with code $validation_exit"
            return $validation_exit
        fi
    else
        echo "Error: AI execution failed with code $exit_code" >&2
        return $exit_code
    fi
}

# Hook method: Preprocess prompt for AI-specific requirements
# Subclasses can override this to add AI-specific prompt extensions
preprocess_prompt() {
    local ai_name="$1"
    local base_prompt="$2"
    local file_context="$3"

    # Default implementation: extend prompt using AI-specific extension function
    # The extend_prompt_for_<ai> function should be defined in the subclass
    local extend_func="extend_prompt_for_${ai_name}"

    if declare -f "$extend_func" >/dev/null 2>&1; then
        "$extend_func" "$base_prompt" "$file_context"
    else
        # No AI-specific extension, return base prompt
        echo "$base_prompt"
    fi
}

# Abstract method: Call AI wrapper
# This is a template that delegates to the AI wrapper scripts
call_ai_wrapper() {
    local ai_name="$1"
    local prompt="$2"
    local timeout="$3"

    # Get project root from REVIEW_LIB_DIR
    # REVIEW_LIB_DIR = /path/to/project/scripts/review/lib
    # PROJECT_ROOT = /path/to/project
    local PROJECT_ROOT="$(cd "$REVIEW_LIB_DIR/../../.." && pwd)"

    # Map AI name to wrapper script (absolute path)
    local wrapper_script="${PROJECT_ROOT}/bin/${ai_name}-wrapper.sh"

    if [[ ! -f "$wrapper_script" ]]; then
        echo "Error: Wrapper script not found: $wrapper_script" >&2
        return 1
    fi

    # Debug: Log prompt size
    local prompt_size=${#prompt}
    debug_log "Prompt size: $prompt_size bytes"
    debug_log "Wrapper: $wrapper_script"
    debug_log "Timeout: ${timeout}s"
    debug_log "Prompt first 100 chars: ${prompt:0:100}"

    # Execute with timeout using wrapper
    # The wrapper handles its own timeout mechanism
    # Use --non-interactive to avoid approval prompts in automated review context
    # Use stdin instead of --prompt for large prompts to avoid argument length limits
    # Suppress stderr to get only JSON output (2>/dev/null)
    local output
    debug_log "Executing wrapper with stdin..."
    output=$(echo "$prompt" | WRAPPER_NON_INTERACTIVE=1 timeout "${timeout}s" "$wrapper_script" --stdin --non-interactive 2>/dev/null)
    local exit_code=$?
    debug_log "Wrapper exit code: $exit_code"
    debug_log "Output preview (first 500 chars): $(echo "$output" | head -c 500)"

    # Extract JSON from markdown code blocks if present
    # Qwen often wraps JSON in ```json ... ``` blocks
    if echo "$output" | head -1 | grep -q '```json'; then
        debug_log "Extracting JSON from markdown code block..."
        # Remove first line (```json) and last line (```)
        output=$(echo "$output" | sed '1d;$d')
    elif echo "$output" | head -1 | grep -q '```'; then
        debug_log "Extracting content from generic code block..."
        output=$(echo "$output" | sed '1d;$d')
    fi

    # Fix duplicate "suggestion" fields if present (Qwen sometimes duplicates this)
    # Use jq to clean up JSON by removing duplicate keys
    if echo "$output" | jq empty 2>/dev/null; then
        debug_log "Cleaning up potential duplicate fields with jq..."
        # jq automatically handles duplicate keys by keeping the last value
        output=$(echo "$output" | jq -c '.')
    fi

    debug_log "Final output preview (first 500 chars): $(echo "$output" | head -c 500)"

    # Save full output to temp file for inspection (debug mode only)
    if [[ "${DEBUG_REVIEW:-0}" == "1" ]]; then
        echo "$output" > /tmp/adapter-output-debug.json
        debug_log "Full output saved to /tmp/adapter-output-debug.json ($(echo "$output" | wc -c) bytes)"
    fi

    echo "$output"
    return $exit_code
}

# Hook method: Validate review output format
# Subclasses can override for AI-specific validation
validate_review_output() {
    local output="$1"

    # Basic validation: check if output is not empty
    if [[ -z "$output" ]]; then
        echo "Error: Empty review output" >&2
        return 1
    fi

    # Check for common error patterns
    if echo "$output" | grep -qi "error\|failed\|timeout"; then
        echo "Warning: Review output contains error indicators" >&2
        # Don't fail, just warn - output might still be useful
    fi

    # TODO: Add JSON format validation when review-prompt-loader.sh is implemented
    # This will check against REVIEW-PROMPT.md schema

    echo "$output"
    return 0
}

# Utility: Get AI-specific timeout value
# Subclasses can override to provide AI-specific defaults
get_default_timeout() {
    local ai_name="$1"

    # Default timeout values based on implementation plan and real-world usage
    case "$ai_name" in
        gemini)
            echo "900"  # 15 minutes (Web search + security analysis overhead)
            ;;
        qwen)
            echo "300"  # 5 minutes (fast review)
            ;;
        droid)
            echo "900"  # 15 minutes (comprehensive analysis)
            ;;
        claude)
            echo "600"  # 10 minutes (fallback)
            ;;
        codex)
            echo "600"  # 10 minutes (automated review)
            ;;
        *)
            echo "300"  # 5 minutes (default)
            ;;
    esac
}

# Utility: Extract findings from review output
# Helper function to parse structured output
extract_findings() {
    local output="$1"
    local format="${2:-text}"  # text|json|markdown

    # TODO: Implement when review-prompt-loader.sh is available
    # This will parse the structured JSON output from REVIEW-PROMPT.md format

    echo "$output"
}

# Export functions for use in subclasses
export -f execute_ai_review
export -f preprocess_prompt
export -f call_ai_wrapper
export -f validate_review_output
export -f get_default_timeout
export -f extract_findings
