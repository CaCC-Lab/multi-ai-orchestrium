#!/bin/bash
# codex-fallback.sh - Fallback mechanisms for Codex review
# Version: 1.0.0
# Purpose: Provide ESLint + Complexity + LLM fallback when Codex /review is unavailable
#
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Specialization: Code optimization, refactoring, integration review

set -euo pipefail

# ============================================================================
# ESLint Integration
# ============================================================================

eslint_review() {
    local files="$1"
    local project_root="${2:-.}"

    # Check if ESLint is available
    if ! command -v eslint >/dev/null 2>&1; then
        echo '{"findings": [], "error": "ESLint not installed"}' >&2
        return 1
    fi

    # Check if files exist
    if [[ -z "$files" ]]; then
        echo '{"findings": [], "error": "No files to lint"}' >&2
        return 1
    fi

    # Run ESLint with JSON output
    local eslint_output
    if eslint_output=$(eslint --format json $files 2>/dev/null || true); then
        # Convert ESLint format to REVIEW-PROMPT.md format
        echo "$eslint_output" | jq '{
            findings: [
                .[] | .messages[] | {
                    title: "[P\(if .severity == 2 then "1" else "2" end)] \(.ruleId // "eslint"): \(.message)",
                    body: "**ESLint Rule**: `\(.ruleId // "unknown")`\n**Severity**: \(if .severity == 2 then "Error" else "Warning" end)\n**File**: `\(.filePath // "unknown")`\n**Line**: \(.line // 0)\n\n\(.message)",
                    confidence_score: 0.9,
                    priority: (if .severity == 2 then 1 else 2 end),
                    code_location: {
                        absolute_file_path: ("\(env.PWD)/\(.filePath // "unknown")"),
                        line_range: {
                            start: (.line // 0),
                            end: (.endLine // .line // 0)
                        }
                    }
                }
            ]
        }'
    else
        echo '{"findings": [], "error": "ESLint execution failed"}' >&2
        return 1
    fi
}

# ============================================================================
# Complexity Analysis Integration
# ============================================================================

complexity_review() {
    local files="$1"

    # Check if complexity tool is available (we'll use a simple bash implementation)
    if ! command -v jq >/dev/null 2>&1; then
        echo '{"findings": [], "error": "jq not installed"}' >&2
        return 1
    fi

    # Simple cyclomatic complexity check using basic heuristics
    # For production, use tools like: eslint-plugin-complexity, lizard, or cc
    local findings='{"findings": []}'

    for file in $files; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        # Count decision points (simplified complexity)
        local decision_points
        decision_points=$(grep -cE '(if|while|for|case|catch|\?|\|\||&&)' "$file" 2>/dev/null | head -1 | tr -d '\n' || echo "0")
        decision_points=${decision_points:-0}

        # Count functions
        local func_count
        func_count=$(grep -cE '(function\s+\w+|const\s+\w+\s*=\s*\([^)]*\)\s*=>)' "$file" 2>/dev/null | head -1 | tr -d '\n' || echo "1")
        func_count=${func_count:-1}

        # Approximate complexity per function (ensure we have valid integers)
        if [[ "$func_count" =~ ^[0-9]+$ ]] && [[ "$func_count" -gt 0 ]]; then
            local avg_complexity=$((decision_points / func_count + 1))

            if [[ "$avg_complexity" -gt 10 ]]; then
                local priority=2
                if [[ "$avg_complexity" -gt 15 ]]; then
                    priority=1
                fi

                # Add finding
                findings=$(echo "$findings" | jq --arg file "$(readlink -f "$file")" \
                    --argjson complexity "$avg_complexity" \
                    --argjson priority "$priority" \
                    '.findings += [{
                        title: "[P\($priority)] High complexity detected (≈\($complexity))",
                        body: "**File**: `\($file)`\n**Estimated Complexity**: \($complexity)\n\n**Issue**: Cyclomatic complexity is approximately \($complexity), which exceeds the recommended threshold of 10.\n\n**Recommendation**: Consider refactoring this file by:\n1. Breaking large functions into smaller, focused functions\n2. Extracting complex conditional logic into separate functions\n3. Using design patterns (Strategy, Command) to reduce branching\n\n**Target**: Reduce complexity to < 10 per function",
                        confidence_score: 0.7,
                        priority: $priority,
                        code_location: {
                            absolute_file_path: $file,
                            line_range: {start: 1, end: 9999}
                        }
                    }]')
            fi
        fi
    done

    echo "$findings"
}

# ============================================================================
# Claude LLM Fallback
# ============================================================================

claude_llm_review() {
    local diff_content="$1"
    local review_focus="${2:-optimization}"
    local timeout="${3:-300}"

    # Check if Claude wrapper is available
    local claude_wrapper
    claude_wrapper="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/bin/claude-wrapper.sh"

    if [[ ! -x "$claude_wrapper" ]]; then
        echo '{"findings": [], "error": "Claude wrapper not found"}' >&2
        return 1
    fi

    # Create Claude-specific review prompt
    local claude_prompt="# Claude Code Optimization Review (Codex Fallback)

You are performing a code optimization review as a fallback when Codex is unavailable.

## Review Focus: ${review_focus}

Analyze this code diff for:
1. **Optimization Opportunities**: Performance improvements, algorithm efficiency
2. **Refactoring Suggestions**: Code structure, design patterns, maintainability
3. **Alternative Patterns**: Better implementation approaches
4. **Integration Concerns**: API usage, library integration, dependency management

## Output Format (JSON - REVIEW-PROMPT.md format)

\`\`\`json
{
  \"findings\": [
    {
      \"title\": \"[P0-P3] Concise issue title\",
      \"body\": \"Detailed explanation with code examples and recommendations\",
      \"confidence_score\": 0.0-1.0,
      \"priority\": 0-3,
      \"code_location\": {
        \"absolute_file_path\": \"/absolute/path/to/file\",
        \"line_range\": {\"start\": 10, \"end\": 20}
      }
    }
  ],
  \"overall_correctness\": \"correct | incorrect | needs review\",
  \"overall_explanation\": \"Overall assessment summary\",
  \"overall_confidence_score\": 0.0-1.0
}
\`\`\`

## Code Diff

\`\`\`diff
${diff_content}
\`\`\`

**IMPORTANT**: Return ONLY the JSON output, no markdown code blocks or additional text."

    # Execute Claude wrapper
    export CLAUDE_MCP_TIMEOUT="$timeout"
    local claude_output
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/claude-llm-review-XXXXXX.txt")
    chmod 600 "$prompt_file"
    echo "$claude_prompt" > "$prompt_file"

    if claude_output=$(timeout "$timeout" "$claude_wrapper" --stdin < "$prompt_file" 2>&1); then
        # Clean output (remove markdown code blocks)
        claude_output=$(echo "$claude_output" | sed '/^```json$/d; /^```$/d')

        # Validate JSON
        if echo "$claude_output" | jq empty 2>/dev/null; then
            rm -f "$prompt_file"
            echo "$claude_output"
            return 0
        else
            rm -f "$prompt_file"
            echo '{"findings": [], "error": "Claude returned non-JSON output"}' >&2
            return 1
        fi
    else
        rm -f "$prompt_file"
        echo '{"findings": [], "error": "Claude execution failed"}' >&2
        return 1
    fi
}

# ============================================================================
# Result Merge Logic
# ============================================================================

merge_review_results() {
    local eslint_json="$1"
    local complexity_json="$2"
    local llm_json="$3"

    # Validate all inputs are valid JSON
    for json_file in "$eslint_json" "$complexity_json" "$llm_json"; do
        if [[ ! -f "$json_file" ]] || ! jq empty "$json_file" 2>/dev/null; then
            echo "ERROR: Invalid JSON file: $json_file" >&2
            return 1
        fi
    done

    # Merge findings with deduplication by title
    jq -s '{
        findings: (
            (.[0].findings // []) +
            (.[1].findings // []) +
            (.[2].findings // [])
        ) | unique_by(.title),
        overall_correctness: (
            if ((.[0].findings // [] | length) > 0) or ((.[1].findings // [] | length) > 0)
            then "needs review"
            else (.[2].overall_correctness // "unknown")
            end
        ),
        overall_explanation: (
            "Combined Codex fallback review:\n" +
            "- ESLint: \(.[0].findings // [] | length) issues\n" +
            "- Complexity Analysis: \(.[1].findings // [] | length) issues\n" +
            "- LLM Review (Claude): \(.[2].findings // [] | length) issues\n" +
            "Total: \((.[0].findings // []) + (.[1].findings // []) + (.[2].findings // []) | length) findings"
        ),
        overall_confidence_score: (
            if (((.[0].findings // []) + (.[1].findings // []) + (.[2].findings // [])) | length) > 0
            then (
                ((.[0].findings // []) + (.[1].findings // []) + (.[2].findings // []) |
                 map(.confidence_score) | add) /
                (((.[0].findings // []) + (.[1].findings // []) + (.[2].findings // [])) | length)
            )
            else 0.5
            end
        ),
        fallback_metadata: {
            sources: ["ESLint", "Complexity", "Claude LLM"],
            eslint_findings: (.[0].findings // [] | length),
            complexity_findings: (.[1].findings // [] | length),
            llm_findings: (.[2].findings // [] | length),
            fallback_reason: "Codex /review not available or failed"
        }
    }' "$eslint_json" "$complexity_json" "$llm_json"
}

# ============================================================================
# Main Fallback Orchestration
# ============================================================================

codex_fallback_full_review() {
    local files="$1"
    local diff_content="$2"
    local output_json="${3:-/tmp/codex-fallback-review.json}"

    echo "🔄 Executing Codex fallback review..." >&2

    # Step 1: ESLint review
    echo "  1/3 Running ESLint..." >&2
    local eslint_tmp
    eslint_tmp=$(mktemp "${TMPDIR:-/tmp}/eslint-review-XXXXXX.json")
    if eslint_review "$files" > "$eslint_tmp"; then
        local eslint_count
        eslint_count=$(jq '.findings | length' "$eslint_tmp")
        echo "  ✓ ESLint: $eslint_count findings" >&2
    else
        echo '{"findings": []}' > "$eslint_tmp"
        echo "  ⚠ ESLint: skipped" >&2
    fi

    # Step 2: Complexity analysis
    echo "  2/3 Running Complexity Analysis..." >&2
    local complexity_tmp
    complexity_tmp=$(mktemp "${TMPDIR:-/tmp}/complexity-review-XXXXXX.json")
    if complexity_review "$files" > "$complexity_tmp"; then
        local complexity_count
        complexity_count=$(jq '.findings | length' "$complexity_tmp")
        echo "  ✓ Complexity: $complexity_count findings" >&2
    else
        echo '{"findings": []}' > "$complexity_tmp"
        echo "  ⚠ Complexity: skipped" >&2
    fi

    # Step 3: Claude LLM review
    echo "  3/3 Running Claude LLM Review..." >&2
    local llm_tmp
    llm_tmp=$(mktemp "${TMPDIR:-/tmp}/llm-review-XXXXXX.json")
    if claude_llm_review "$diff_content" "optimization" 300 > "$llm_tmp"; then
        local llm_count
        llm_count=$(jq '.findings | length' "$llm_tmp")
        echo "  ✓ Claude LLM: $llm_count findings" >&2
    else
        echo '{"findings": [], "overall_correctness": "unknown", "overall_explanation": "LLM review failed"}' > "$llm_tmp"
        echo "  ⚠ Claude LLM: skipped" >&2
    fi

    # Step 4: Merge results
    echo "  Merging results..." >&2
    if merge_review_results "$eslint_tmp" "$complexity_tmp" "$llm_tmp" > "$output_json"; then
        local total_count
        total_count=$(jq '.findings | length' "$output_json")
        echo "✅ Fallback review complete: $total_count total findings" >&2

        # Cleanup
        rm -f "$eslint_tmp" "$complexity_tmp" "$llm_tmp"
        return 0
    else
        echo "❌ Failed to merge review results" >&2
        rm -f "$eslint_tmp" "$complexity_tmp" "$llm_tmp"
        return 1
    fi
}

# Export functions for use in other scripts
export -f eslint_review
export -f complexity_review
export -f claude_llm_review
export -f merge_review_results
export -f codex_fallback_full_review
