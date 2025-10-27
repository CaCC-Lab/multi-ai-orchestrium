#!/usr/bin/env bash
# adapter-qwen.sh - Qwen-specific review adapter
# Version: 1.0.0
# Purpose: Code quality-focused review with refactoring suggestions using Qwen AI
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.2.2

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

# Source review prompt loader (for extend_prompt_for_qwen)
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
AI_NAME="qwen"

# Default timeout (5 minutes for fast review)
DEFAULT_TIMEOUT=300

# Code quality thresholds
MAX_CYCLOMATIC_COMPLEXITY="${MAX_CYCLOMATIC_COMPLEXITY:-10}"
MAX_FUNCTION_LENGTH="${MAX_FUNCTION_LENGTH:-50}"
MAX_LINE_LENGTH="${MAX_LINE_LENGTH:-120}"

# ============================================================================
# P1.2.2.1: Code Quality Specialized Prompt
# ============================================================================

# This functionality is already implemented in review-prompt-loader.sh
# as extend_prompt_for_qwen(). We inherit it from the base adapter.

# ============================================================================
# P1.2.2.2: Qwen CLI Invocation
# ============================================================================

# Call Qwen wrapper with appropriate timeout
# Usage: call_qwen_review <prompt> [timeout]
# Returns: Review output (stdout)
call_qwen_review() {
    local prompt="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"

    # Extend prompt with Qwen-specific instructions
    local extended_prompt
    extended_prompt=$(extend_prompt_for_qwen "$prompt")

    # Call base adapter's execute_ai_review
    execute_ai_review "$AI_NAME" "$extended_prompt" "$timeout"
}

# ============================================================================
# P1.2.2.3: Alternative Implementation Suggestion Feature
# ============================================================================

# Generate suggestion block with proper indentation preservation
# Usage: format_suggestion_block <code> <indentation>
# Returns: Formatted suggestion block (stdout)
format_suggestion_block() {
    local code="$1"
    local indent="${2:-}"  # Optional indentation (e.g., "  " or "    ")

    cat <<EOF
\`\`\`suggestion
$code
\`\`\`
EOF
}

# Validate suggestion block format
# Usage: validate_suggestion_format <suggestion_block>
# Returns: 0 if valid, 1 if invalid
validate_suggestion_format() {
    local suggestion="$1"

    # Check if suggestion starts and ends with ```
    if ! echo "$suggestion" | grep -q '^\`\`\`suggestion'; then
        echo "Error: Suggestion block must start with \`\`\`suggestion" >&2
        return 1
    fi

    if ! echo "$suggestion" | grep -q '\`\`\`$'; then
        echo "Error: Suggestion block must end with \`\`\`" >&2
        return 1
    fi

    # Check if code is between 1-5 lines (per spec)
    local line_count
    line_count=$(echo "$suggestion" | sed -n '/^```suggestion$/,/^```$/p' | wc -l)
    line_count=$((line_count - 2))  # Exclude ``` markers

    if [[ $line_count -gt 7 ]]; then  # 5 + 2 markers
        echo "Warning: Suggestion exceeds recommended 5 lines (has $line_count)" >&2
    fi

    return 0
}

# Extract suggestion blocks from review output
# Usage: extract_suggestions <review_output>
# Returns: Array of suggestion blocks (JSON format)
extract_suggestions() {
    local review_output="$1"

    # Try to extract from JSON first
    if echo "$review_output" | jq empty 2>/dev/null; then
        # Valid JSON, extract suggestion fields
        echo "$review_output" | jq -c '[.findings[] | select(.suggestion != null) | {title: .title, suggestion: .suggestion}]'
    else
        # Fallback: extract from Markdown
        echo "$review_output" | grep -A 10 '```suggestion' || echo "[]"
    fi
}

# ============================================================================
# Code Quality Metrics
# ============================================================================

# Analyze code complexity (placeholder - would need language-specific tools)
# Usage: analyze_complexity <code>
# Returns: Complexity metrics (JSON format)
analyze_complexity() {
    local code="$1"

    # This is a placeholder for complexity analysis
    # In a full implementation, we would use tools like:
    # - radon (Python)
    # - eslint --plugin complexity (JavaScript)
    # - gocyclo (Go)
    # - etc.

    cat <<EOF
{
  "cyclomatic_complexity": 0,
  "function_count": 0,
  "average_function_length": 0,
  "note": "Placeholder - requires language-specific analysis"
}
EOF
}

# Detect code duplication (simple heuristic)
# Usage: detect_duplication <code>
# Returns: Duplication report (JSON format)
detect_duplication() {
    local code="$1"

    # Simple duplication detection using line hashing
    # This is a basic heuristic - full implementation would use tools like jscpd

    local duplicates
    duplicates=$(echo "$code" | sort | uniq -c | awk '$1 > 1 {print}' | wc -l)

    cat <<EOF
{
  "duplicate_lines": $duplicates,
  "note": "Simple heuristic - use jscpd for accurate detection"
}
EOF
}

# ============================================================================
# Qwen-Specific Review Function
# ============================================================================

# Main review function for Qwen adapter
# Usage: qwen_review <commit_hash_or_diff> [timeout] [--fast]
# Returns: Structured review output (JSON format)
qwen_review() {
    local target="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local fast_mode="${3:-false}"

    # Fast mode: reduced timeout for quick feedback
    if [[ "$fast_mode" == "--fast" || "$fast_mode" == "true" ]]; then
        timeout=120  # 2 minutes
    fi

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt)

    # Add commit/diff context
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

## Code to Review

$target

## Quality Thresholds

- Maximum Cyclomatic Complexity: $MAX_CYCLOMATIC_COMPLEXITY
- Maximum Function Length: $MAX_FUNCTION_LENGTH lines
- Maximum Line Length: $MAX_LINE_LENGTH characters

EOF
)

    # Execute review with code quality focus
    local review_output
    review_output=$(call_qwen_review "$full_prompt" "$timeout")

    # Validate suggestion blocks if present
    if echo "$review_output" | grep -q '```suggestion'; then
        local suggestions
        suggestions=$(extract_suggestions "$review_output")

        # Log suggestion count for metrics
        local suggestion_count
        suggestion_count=$(echo "$suggestions" | jq 'length' 2>/dev/null || echo "0")
        echo "# Generated $suggestion_count refactoring suggestions" >&2
    fi

    echo "$review_output"
}

# Fast quality review mode (2-minute timeout, P0-P1 only)
# Usage: qwen_fast_review <commit_hash_or_diff>
# Returns: Filtered review output (JSON format)
qwen_fast_review() {
    local target="$1"

    # Execute fast review
    local review_output
    review_output=$(qwen_review "$target" 120 true)

    # Filter to P0-P1 findings only
    if echo "$review_output" | jq empty 2>/dev/null; then
        echo "$review_output" | jq '{
            findings: [.findings[] | select(.priority <= 1)],
            overall_correctness: .overall_correctness,
            overall_explanation: .overall_explanation,
            overall_confidence_score: .overall_confidence_score,
            metadata: (.metadata + {fast_mode: true})
        }'
    else
        echo "$review_output"
    fi
}

# ============================================================================
# Exports
# ============================================================================

# Export Qwen-specific functions
export -f call_qwen_review
export -f qwen_review
export -f qwen_fast_review
export -f format_suggestion_block
export -f validate_suggestion_format
export -f extract_suggestions
export -f analyze_complexity
export -f detect_duplication

# Export configuration
export AI_NAME
export DEFAULT_TIMEOUT
export MAX_CYCLOMATIC_COMPLEXITY
export MAX_FUNCTION_LENGTH
export MAX_LINE_LENGTH

# ============================================================================
# Standalone Execution Support
# ============================================================================

# Allow this adapter to be run standalone for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse arguments
    COMMIT_OR_DIFF="${1:-HEAD}"
    TIMEOUT="${2:-$DEFAULT_TIMEOUT}"
    FAST_MODE="${3:-false}"

    echo "Running Qwen review adapter..." >&2
    echo "Target: $COMMIT_OR_DIFF" >&2
    echo "Timeout: ${TIMEOUT}s" >&2
    echo "Fast mode: $FAST_MODE" >&2
    echo "" >&2

    # Execute review
    if [[ "$FAST_MODE" == "--fast" || "$FAST_MODE" == "true" ]]; then
        qwen_fast_review "$COMMIT_OR_DIFF"
    else
        qwen_review "$COMMIT_OR_DIFF" "$TIMEOUT"
    fi
fi
