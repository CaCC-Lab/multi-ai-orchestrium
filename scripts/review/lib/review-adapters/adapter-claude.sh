#!/bin/bash
# adapter-claude.sh - Claude Quality Review Adapter
# Version: 1.0
# Direct wrapper approach for quality-focused code review

# Detect project root
ADAPTER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_PROJECT_ROOT="$(cd "$ADAPTER_SCRIPT_DIR/../../../.." && pwd)"

# Call Claude via wrapper with JSON extraction
# Usage: call_claude_review <prompt> <timeout>
call_claude_review() {
    local prompt="$1"
    local timeout="${2:-600}"

    # Use claude MCP tool via wrapper
    local wrapper_script="${ADAPTER_PROJECT_ROOT}/bin/claude-wrapper.sh"

    if [[ ! -f "$wrapper_script" ]]; then
        echo "Error: Claude wrapper not found: $wrapper_script" >&2
        return 1
    fi

    # Execute Claude with timeout and extract JSON from markdown code fence
    # SIGPIPE Fix: Use temp file instead of pipe to avoid Exit code 141
    local temp_prompt_file
    temp_prompt_file=$(mktemp -t claude-review-prompt.XXXXXX)
    chmod 600 "$temp_prompt_file"
    trap "rm -f '$temp_prompt_file'" EXIT INT TERM

    # Write prompt to temp file
    echo "$prompt" > "$temp_prompt_file"

    # Execute with stdin redirect (no pipe, no SIGPIPE risk)
    local raw_output
    raw_output=$(timeout "${timeout}s" bash "$wrapper_script" --stdin < "$temp_prompt_file" 2>&1)
    local exit_code=$?

    # Cleanup
    rm -f "$temp_prompt_file"
    trap - EXIT INT TERM

    if [[ $exit_code -ne 0 ]]; then
        echo "Error: AI execution failed with code $exit_code" >&2
        return $exit_code
    fi

    # Extract JSON from markdown code fence (\`\`\`json ... \`\`\`)
    # Use sed to extract lines between \`\`\`json and \`\`\` (excluding both markers)
    local json_output
    json_output=$(echo "$raw_output" | sed -n '/^\`\`\`json$/,/^\`\`\`$/{/^\`\`\`/d;p;}')

    if [[ -z "$json_output" ]]; then
        echo "Error: No JSON found in Claude output" >&2
        echo "Raw output (first 500 chars):" >&2
        echo "$raw_output" | head -c 500 >&2
        return 1
    fi

    echo "$json_output"
    return 0
}

# Extend prompt for quality review focus
extend_prompt_for_quality() {
    local base_prompt="$1"
    local diff_content="$2"

    cat <<EOF
$base_prompt

# Code Diff to Review

\`\`\`diff
$diff_content
\`\`\`

# Code Quality Review Focus

Please perform a code quality review with the following priorities:
1. **Bug Detection**: Identify logic errors, edge cases, and potential crashes
2. **Refactoring Opportunities**: Suggest cleaner, more maintainable alternatives
3. **Type Safety**: Check for type inconsistencies and missing validations
4. **Code Smells**: Detect duplications, long functions, high complexity
5. **Performance**: Identify inefficient algorithms or resource usage

# Requirements for Suggestions

- Keep comments concise (1 paragraph maximum per finding)
- For refactoring suggestions, provide alternative implementation using \`suggestion\` blocks:

\`\`\`suggestion
// Improved code here
\`\`\`

- Maintain proper indentation in suggestions
- Focus on actionable, concrete improvements

Provide output in the JSON format specified in the prompt above.
EOF
}

# Execute quality review with Claude
execute_claude_quality_review() {
    local commit="$1"
    local timeout="${2:-600}"
    local output_dir="$3"

    # Get git diff
    local diff_content
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi

    if [[ "$commit" == "HEAD" ]]; then
        diff_content=$(git diff HEAD)
    else
        diff_content=$(git show "$commit" --format=fuller)
    fi

    if [[ -z "$diff_content" ]]; then
        echo "Error: No diff content found for commit: $commit" >&2
        return 1
    fi

    # Load base review prompt
    local base_prompt
    local prompt_file="${ADAPTER_PROJECT_ROOT}/REVIEW-PROMPT.md"
    if [[ ! -f "$prompt_file" ]]; then
        echo "Error: Review prompt not found: $prompt_file" >&2
        return 1
    fi
    base_prompt=$(cat "$prompt_file")

    # Construct full prompt with diff and quality focus
    local full_prompt
    full_prompt=$(extend_prompt_for_quality "$base_prompt" "$diff_content")

    # Execute Claude review with timeout
    local review_output
    local exit_code=0
    local start_time=$(date +%s%3N)

    review_output=$(call_claude_review "$full_prompt" "$timeout") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Claude quality review failed with exit code: $exit_code" >&2
        return $exit_code
    fi

    # Output the JSON result
    echo "$review_output"
    return 0
}

# Export functions for use in review scripts
export -f call_claude_review
export -f extend_prompt_for_quality
export -f execute_claude_quality_review

# Default timeout for quality reviews
export CLAUDE_QUALITY_TIMEOUT=600
