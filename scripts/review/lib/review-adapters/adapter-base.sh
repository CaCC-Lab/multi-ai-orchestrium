#!/bin/bash
# adapter-base.sh - Base adapter template for AI-specific review implementations
# Version: 1.0
# Template Method Pattern for reducing duplication by 60%

# Source common libraries (will be available when review-common.sh is implemented)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_LIB_DIR="$(dirname "$SCRIPT_DIR")"

# Template method: Main review execution flow
# This function defines the skeleton of the review algorithm
# Subclasses can override specific steps without changing the overall structure
execute_ai_review() {
    local ai_name="$1"
    local prompt="$2"
    local timeout="$3"
    local file_context="$4"  # Optional: file path or git diff context

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

    # Step 3: Common postprocessing
    if [[ $exit_code -eq 0 ]]; then
        validate_review_output "$output"
        return $?
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

    # Map AI name to wrapper script
    local wrapper_script="./bin/${ai_name}-wrapper.sh"

    if [[ ! -f "$wrapper_script" ]]; then
        echo "Error: Wrapper script not found: $wrapper_script" >&2
        return 1
    fi

    # Execute with timeout using wrapper
    # The wrapper handles its own timeout mechanism
    if [[ -f "$wrapper_script" ]]; then
        timeout "${timeout}s" "$wrapper_script" --prompt "$prompt" 2>&1
        return $?
    else
        echo "Error: Failed to execute wrapper: $wrapper_script" >&2
        return 1
    fi
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

    # Default timeout values based on implementation plan
    case "$ai_name" in
        gemini)
            echo "600"  # 10 minutes (Web search overhead)
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
