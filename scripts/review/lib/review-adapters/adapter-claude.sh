#!/bin/bash
# adapter-claude.sh - Claude Quality Review Adapter
# Version: 2.0
# Slash command + wrapper hybrid approach for quality-focused code review

# Detect project root
ADAPTER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_PROJECT_ROOT="$(cd "$ADAPTER_SCRIPT_DIR/../../../.." && pwd)"

# Review mode control
# USE_SLASH_COMMANDS=true: Use native Claude slash commands (claude /review)
# USE_SLASH_COMMANDS=false: Use legacy wrapper approach
USE_SLASH_COMMANDS="${USE_SLASH_COMMANDS:-true}"

# Load Markdown parser library (for slash command mode)
MARKDOWN_PARSER_AVAILABLE="false"
MARKDOWN_PARSER_PATH="${ADAPTER_PROJECT_ROOT}/scripts/lib/markdown-parser.sh"
if [[ -f "$MARKDOWN_PARSER_PATH" ]]; then
    source "$MARKDOWN_PARSER_PATH"
    MARKDOWN_PARSER_AVAILABLE="true"
fi

# Call Claude with hybrid slash/wrapper support
# Usage: call_claude_review <prompt|diff_content> <timeout> [mode]
# mode: "slash" or "wrapper" (default: from USE_SLASH_COMMANDS)
call_claude_review() {
    local input_content="$1"
    local timeout="${2:-600}"
    local mode="${3:-$USE_SLASH_COMMANDS}"

    # Convert boolean to mode string
    if [[ "$mode" == "true" ]]; then
        mode="slash"
    elif [[ "$mode" == "false" ]]; then
        mode="wrapper"
    fi

    local json_output=""
    local exit_code=0

    # Try slash command mode first (if enabled)
    if [[ "$mode" == "slash" ]]; then
        echo "Attempting Claude /review slash command..." >&2

        # Create temporary markdown file
        local temp_md_file
        temp_md_file=$(mktemp -t claude-review-md.XXXXXX.md)
        chmod 600 "$temp_md_file"

        # Execute claude /review slash command
        # Input should be git diff content for slash mode
        if echo "$input_content" | timeout "${timeout}s" claude /review > "$temp_md_file" 2>&1; then
            echo "Slash command succeeded, converting Markdown to JSON..." >&2

            # Convert Markdown to JSON using markdown-parser
            if [[ "$MARKDOWN_PARSER_AVAILABLE" == "true" ]]; then
                local temp_json_file
                temp_json_file=$(mktemp -t claude-review-json.XXXXXX.json)
                chmod 600 "$temp_json_file"

                if parse_markdown_review "$temp_md_file" "$temp_json_file"; then
                    json_output=$(cat "$temp_json_file")
                    rm -f "$temp_json_file"
                    echo "Markdown → JSON conversion successful" >&2
                else
                    echo "Warning: Markdown → JSON conversion failed, falling back to wrapper" >&2
                    exit_code=1
                fi
            else
                echo "Warning: Markdown parser not available, falling back to wrapper" >&2
                exit_code=1
            fi
        else
            exit_code=$?
            echo "Warning: Slash command failed (exit: $exit_code), falling back to wrapper" >&2
        fi

        rm -f "$temp_md_file"
    fi

    # Fallback to wrapper mode if slash failed or disabled
    if [[ -z "$json_output" || $exit_code -ne 0 ]]; then
        echo "Using Claude wrapper mode (legacy)..." >&2

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
        # In wrapper mode, input_content should be the full prompt
        echo "$input_content" > "$temp_prompt_file"

        # Execute with stdin redirect (no pipe, no SIGPIPE risk)
        # Capture stderr separately to avoid JSON extraction interference
        local raw_output
        local stderr_output
        local temp_stderr
        temp_stderr=$(mktemp -t claude-review-stderr.XXXXXX)
        chmod 600 "$temp_stderr"

        raw_output=$(timeout "${timeout}s" bash "$wrapper_script" --stdin --non-interactive < "$temp_prompt_file" 2>"$temp_stderr")
        exit_code=$?

        stderr_output=$(cat "$temp_stderr")
        rm -f "$temp_stderr"

        # Cleanup
        rm -f "$temp_prompt_file"
        trap - EXIT INT TERM

        if [[ $exit_code -ne 0 ]]; then
            echo "Error: AI execution failed with code $exit_code" >&2
            if [[ -n "$stderr_output" ]]; then
                echo "Error output:" >&2
                echo "$stderr_output" >&2
            fi
            return $exit_code
        fi

        # Extract JSON from markdown code fence (\`\`\`json ... \`\`\`)
        # Use sed to extract lines between \`\`\`json and \`\`\` (excluding both markers)
        # Made more flexible: allows whitespace, handles missing closing fence
        json_output=$(echo "$raw_output" | sed -n '/^[[:space:]]*\`\`\`json[[:space:]]*$/,/^[[:space:]]*\`\`\`[[:space:]]*$/{/\`\`\`/d;p;}')

        # If code fence extraction failed, try extracting raw JSON (fallback)
        if [[ -z "$json_output" ]]; then
            # Try to extract JSON object directly (from first { to last })
            json_output=$(echo "$raw_output" | sed -n '/{/,/}/p' | sed '/^[[:space:]]*```/d')
        fi

        if [[ -z "$json_output" ]]; then
            echo "Error: No JSON found in Claude output" >&2
            echo "Raw output (first 500 chars):" >&2
            echo "$raw_output" | head -c 500 >&2
            if [[ -n "$stderr_output" ]]; then
                echo "Stderr output:" >&2
                echo "$stderr_output" | head -c 500 >&2
            fi
            return 1
        fi

        echo "Wrapper mode succeeded" >&2
    fi

    # Output JSON result
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

# Execute quality review with Claude (hybrid slash/wrapper mode)
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

    # Prepare input content based on mode
    local input_content
    if [[ "$USE_SLASH_COMMANDS" == "true" ]]; then
        # Slash mode: Pass raw diff content
        # Claude /review will handle the review format internally
        input_content="$diff_content"
        echo "Using slash command mode: passing diff content directly" >&2
    else
        # Wrapper mode: Construct full prompt with quality focus
        local base_prompt
        local prompt_file="${ADAPTER_PROJECT_ROOT}/REVIEW-PROMPT.md"
        if [[ ! -f "$prompt_file" ]]; then
            echo "Error: Review prompt not found: $prompt_file" >&2
            return 1
        fi
        base_prompt=$(cat "$prompt_file")

        input_content=$(extend_prompt_for_quality "$base_prompt" "$diff_content")
        echo "Using wrapper mode: constructed full prompt" >&2
    fi

    # Execute Claude review with timeout
    local review_output
    local exit_code=0
    local start_time=$(date +%s%3N)

    review_output=$(call_claude_review "$input_content" "$timeout") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Claude quality review failed with exit code: $exit_code" >&2
        return $exit_code
    fi

    echo "Review completed in ${duration_ms}ms" >&2

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
