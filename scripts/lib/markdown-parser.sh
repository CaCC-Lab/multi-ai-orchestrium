#!/usr/bin/env bash
# markdown-parser.sh - Markdown to JSON parser for code review outputs
#
# Purpose: Parse Markdown review output from slash commands (claude /review, codex /review)
#          and convert to JSON format compatible with REVIEW-PROMPT.md schema
#
# Architecture: CodeRabbit-compatible Markdown → JSON conversion
#
# Input:  Markdown file with structured review content
#         - Headers (##, ###, ####)
#         - Priority markers ([P0], [P1], [P2], [P3], **P0**, etc.)
#         - Confidence scores (Confidence: 95%, confidence_score: 0.95)
#         - Code locations (file.ext:LINE, file.ext:START-END)
#
# Output: JSON file with REVIEW-PROMPT.md structure
#         - findings: Array of {title, body, priority, confidence_score, code_location}
#         - overall_correctness: "patch is correct" | "patch is incorrect" | "needs review"
#         - overall_explanation: Summary text
#         - overall_confidence_score: 0.0-1.0
#
# Usage:
#   source scripts/lib/markdown-parser.sh
#   parse_markdown_review "input.md" "output.json"
#
# Dependencies:
#   - jq (JSON processor)
#   - bin/vibe-logger-lib.sh (structured logging)
#
# Created: 2025-10-28
# Author: Claude Code
# Version: 1.0.0

set -euo pipefail

# Source VibeLogger for structured logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    echo "ERROR: VibeLogger library not found at $PROJECT_ROOT/bin/vibe-logger-lib.sh" >&2
    exit 1
fi

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Error handler
markdown_parser_error() {
    local error_code="$1"
    local error_message="$2"
    local context="${3:-}"

    vibe_log "error" "markdown-parser-error" \
        "{\"error_code\":\"$error_code\",\"message\":\"$error_message\",\"context\":\"$context\"}" \
        "Markdown parser error: $error_message" \
        "[\"fix-parser\",\"check-input\"]" \
        "markdown-parser"

    echo "ERROR [$error_code]: $error_message" >&2
    if [[ -n "$context" ]]; then
        echo "Context: $context" >&2
    fi
    return 1
}

# ============================================================================
# INPUT VALIDATION
# ============================================================================

# Validate input file exists and is readable
validate_input_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        markdown_parser_error "INPUT_NOT_FOUND" "Input file not found: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        markdown_parser_error "INPUT_NOT_READABLE" "Input file not readable: $file"
        return 1
    fi

    if [[ ! -s "$file" ]]; then
        markdown_parser_error "INPUT_EMPTY" "Input file is empty: $file"
        return 1
    fi

    return 0
}

# Validate output file can be written
validate_output_file() {
    local file="$1"
    local dir
    dir="$(dirname "$file")"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            markdown_parser_error "OUTPUT_DIR_CREATE_FAILED" "Cannot create output directory: $dir"
            return 1
        }
    fi

    if [[ ! -w "$dir" ]]; then
        markdown_parser_error "OUTPUT_DIR_NOT_WRITABLE" "Output directory not writable: $dir"
        return 1
    fi

    return 0
}

# ============================================================================
# PRIORITY EXTRACTION
# ============================================================================

# Extract priority level from text
# Input: "[P0] Title" or "**P1**" or "Priority: High"
# Output: 0 | 1 | 2 | 3
# Default: 2 (medium)
extract_priority() {
    local text="$1"
    local priority=2  # Default: Medium (P2)

    # Pattern 1: [P0], [P1], [P2], [P3]
    if [[ "$text" =~ \[P([0-3])\] ]]; then
        priority="${BASH_REMATCH[1]}"
    # Pattern 2: **P0**, **P1**, **P2**, **P3**
    elif [[ "$text" =~ \*\*P([0-3])\*\* ]]; then
        priority="${BASH_REMATCH[1]}"
    # Pattern 3: Priority: Critical/High/Medium/Low
    elif [[ "$text" =~ Priority:[[:space:]]*(Critical|High|Medium|Low) ]]; then
        case "${BASH_REMATCH[1]}" in
            Critical) priority=0 ;;
            High)     priority=1 ;;
            Medium)   priority=2 ;;
            Low)      priority=3 ;;
        esac
    # Pattern 4: P0:, P1:, P2:, P3: (common in reviews)
    elif [[ "$text" =~ P([0-3]): ]]; then
        priority="${BASH_REMATCH[1]}"
    fi

    echo "$priority"
}

# ============================================================================
# CONFIDENCE SCORE EXTRACTION
# ============================================================================

# Extract confidence score from text
# Input: "Confidence: 95%" or "confidence_score: 0.95" or "High confidence"
# Output: 0.95 (float)
# Default: 0.8
extract_confidence() {
    local text="$1"
    local confidence="0.8"  # Default: 80%

    # Pattern 1: Confidence: XX%
    if [[ "$text" =~ Confidence:[[:space:]]*([0-9]+)% ]]; then
        local percent="${BASH_REMATCH[1]}"
        confidence="$(echo "scale=2; $percent / 100" | bc)"
    # Pattern 2: confidence_score: 0.XX
    elif [[ "$text" =~ confidence_score:[[:space:]]*([0-9]+\.?[0-9]*) ]]; then
        confidence="${BASH_REMATCH[1]}"
    # Pattern 3: High/Medium/Low confidence (text)
    elif [[ "$text" =~ (High|Medium|Low)[[:space:]]+confidence ]]; then
        case "${BASH_REMATCH[1]}" in
            High)   confidence="0.9" ;;
            Medium) confidence="0.7" ;;
            Low)    confidence="0.5" ;;
        esac
    fi

    # Validate range [0.0, 1.0]
    if (( $(echo "$confidence > 1.0" | bc -l) )); then
        confidence="1.0"
    elif (( $(echo "$confidence < 0.0" | bc -l) )); then
        confidence="0.0"
    fi

    echo "$confidence"
}

# ============================================================================
# HEADER EXTRACTION
# ============================================================================

# Extract headers from Markdown
# Input: Markdown content
# Output: JSON array of {level, title, line_number}
extract_headers() {
    local markdown_file="$1"
    local line_num=0
    local headers_json="[]"

    while IFS= read -r line; do
        ((line_num++)) || true

        # Match ## Header (level 2)
        if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
            local title="${BASH_REMATCH[1]}"
            local header_json
            header_json=$(jq -n \
                --argjson level 2 \
                --arg title "$title" \
                --argjson line_num "$line_num" \
                '{"level": $level, "title": $title, "line_number": $line_num}')
            headers_json=$(echo "$headers_json" | jq --argjson h "$header_json" '. += [$h]')

        # Match ### Header (level 3)
        elif [[ "$line" =~ ^###[[:space:]]+(.+)$ ]]; then
            local title="${BASH_REMATCH[1]}"
            local header_json
            header_json=$(jq -n \
                --argjson level 3 \
                --arg title "$title" \
                --argjson line_num "$line_num" \
                '{"level": $level, "title": $title, "line_number": $line_num}')
            headers_json=$(echo "$headers_json" | jq --argjson h "$header_json" '. += [$h]')

        # Match #### Header (level 4)
        elif [[ "$line" =~ ^####[[:space:]]+(.+)$ ]]; then
            local title="${BASH_REMATCH[1]}"
            local header_json
            header_json=$(jq -n \
                --argjson level 4 \
                --arg title "$title" \
                --argjson line_num "$line_num" \
                '{"level": $level, "title": $title, "line_number": $line_num}')
            headers_json=$(echo "$headers_json" | jq --argjson h "$header_json" '. += [$h]')
        fi
    done < "$markdown_file"

    echo "$headers_json"
}

# ============================================================================
# TEXT SANITIZATION FOR JSON
# ============================================================================

# Sanitize text for safe JSON embedding
# Removes invalid escape sequences that cause jq parsing errors
# Input: Raw text string (may contain backticks, dollar signs, etc.)
# Output: Sanitized text safe for JSON
sanitize_text_for_json() {
    local text="$1"

    # Remove invalid escape sequences that are not valid in JSON
    # JSON only allows: \" \\ \/ \b \f \n \r \t \uXXXX

    # 1. Backticks: \` → ` (backticks don't need escaping in JSON)
    text="${text//\\\`/\`}"

    # 2. Dollar signs: \$ → $ (dollar signs don't need escaping in JSON)
    text="${text//\\\$/\$}"

    # 3. Curly braces: \{ and \} → { and } (not valid JSON escapes)
    text="${text//\\\{/\{}"
    text="${text//\\\}/\}}"

    # 4. Parentheses: \( and \) → ( and ) (not valid JSON escapes)
    text="${text//\\\(/\(}"
    text="${text//\\\)/\)}"

    echo "$text"
}

# ============================================================================
# CODE LOCATION EXTRACTION
# ============================================================================

# Extract code location from text
# Input: "app.js:42" or "app.js:42-50" or "Line 42 in app.js" or "N/A:?-?"
# Output: JSON {file, start_line, end_line} or null
extract_code_location() {
    local text="$1"
    local file=""
    local start_line=""
    local end_line=""

    # Pattern 0: N/A or invalid location (return null)
    if [[ "$text" =~ (N/A|n/a|unknown|UNKNOWN|\?-\?) ]]; then
        echo "null"
        return 0
    fi

    # Pattern 1: file.ext:LINE
    if [[ "$text" =~ ([a-zA-Z0-9_/.-]+):([0-9]+)$ ]]; then
        file="${BASH_REMATCH[1]}"
        start_line="${BASH_REMATCH[2]}"
        end_line="$start_line"

    # Pattern 2: file.ext:START-END
    elif [[ "$text" =~ ([a-zA-Z0-9_/.-]+):([0-9]+)-([0-9]+) ]]; then
        file="${BASH_REMATCH[1]}"
        start_line="${BASH_REMATCH[2]}"
        end_line="${BASH_REMATCH[3]}"

    # Pattern 3: Line X in file.ext
    elif [[ "$text" =~ Line[[:space:]]+([0-9]+)[[:space:]]+in[[:space:]]+([a-zA-Z0-9_/.-]+) ]]; then
        start_line="${BASH_REMATCH[1]}"
        file="${BASH_REMATCH[2]}"
        end_line="$start_line"

    # Pattern 4: at file.ext:LINE
    elif [[ "$text" =~ at[[:space:]]+([a-zA-Z0-9_/.-]+):([0-9]+) ]]; then
        file="${BASH_REMATCH[1]}"
        start_line="${BASH_REMATCH[2]}"
        end_line="$start_line"
    fi

    # Convert relative path to absolute path
    if [[ -n "$file" ]] && [[ ! "$file" =~ ^/ ]]; then
        file="$(cd "$PROJECT_ROOT" 2>/dev/null && realpath "$file" 2>/dev/null || echo "$PROJECT_ROOT/$file")"
    fi

    # Return JSON
    if [[ -n "$file" ]]; then
        # Ensure numeric values for line numbers
        local start_num="${start_line:-0}"
        local end_num="${end_line:-0}"
        [[ ! "$start_num" =~ ^[0-9]+$ ]] && start_num=0
        [[ ! "$end_num" =~ ^[0-9]+$ ]] && end_num=0

        # Use --argjson with validated numbers
        # Note: Renamed "end" to "end_line" to avoid jq reserved keyword
        jq -n --arg file "$file" --argjson start "$start_num" --argjson end_line "$end_num" \
            '{"absolute_file_path": $file, "line_range": {"start": $start, "end": $end_line}}'
    else
        echo "null"
    fi
}

# ============================================================================
# FINDING EXTRACTION
# ============================================================================

# Extract findings from Markdown sections
# Input: Markdown file
# Output: JSON array of findings
extract_findings() {
    local markdown_file="$1"
    local findings_json="[]"

    # Extract headers first
    local headers_json
    headers_json="$(extract_headers "$markdown_file")"
    local header_count
    header_count="$(echo "$headers_json" | jq 'length')"

    # Process each header as a potential finding
    for ((i=0; i<header_count; i++)); do
        local header
        header="$(echo "$headers_json" | jq -r ".[$i]")"
        local title
        title="$(echo "$header" | jq -r '.title')"
        local start_line
        start_line="$(echo "$header" | jq -r '.line_number')"

        # Get end line (next header or EOF)
        local end_line
        if ((i + 1 < header_count)); then
            end_line="$(echo "$headers_json" | jq -r ".[$((i+1))].line_number")"
            ((end_line--)) || true
        else
            end_line="$(wc -l < "$markdown_file")"
        fi

        # Extract body text between headers
        local body
        body="$(sed -n "${start_line},${end_line}p" "$markdown_file" | sed '1d')"  # Skip header line itself

        # Extract priority and confidence from title or body
        local priority
        priority="$(extract_priority "$title $body")"
        local confidence
        confidence="$(extract_confidence "$body")"

        # Extract code location from body
        local location_json
        location_json="$(extract_code_location "$body")"

        # Sanitize title and body for safe JSON embedding
        title="$(sanitize_text_for_json "$title")"
        body="$(sanitize_text_for_json "$body")"

        # Create finding JSON
        local finding_json
        finding_json=$(jq -n \
            --arg title "$title" \
            --arg body "$body" \
            --argjson priority "$priority" \
            --argjson confidence "$confidence" \
            --argjson location "$location_json" \
            '{
                title: $title,
                body: $body,
                priority: $priority,
                confidence_score: $confidence,
                code_location: $location
            }')

        findings_json=$(echo "$findings_json" | jq --argjson f "$finding_json" '. += [$f]')
    done

    echo "$findings_json"
}

# ============================================================================
# OVERALL CORRECTNESS EXTRACTION
# ============================================================================

# Extract overall correctness assessment
# Input: Markdown content
# Output: "patch is correct" | "patch is incorrect" | "needs review"
extract_overall_correctness() {
    local markdown_file="$1"
    local content
    content="$(cat "$markdown_file")"

    # Pattern 1: Explicit "Overall: Correct/Incorrect"
    if [[ "$content" =~ Overall:[[:space:]]*(Correct|Incorrect) ]]; then
        case "${BASH_REMATCH[1]}" in
            Correct)   echo "patch is correct" ;;
            Incorrect) echo "patch is incorrect" ;;
        esac
        return
    fi

    # Pattern 2: "Summary: Pass/Fail"
    if [[ "$content" =~ Summary:[[:space:]]*(Pass|Fail) ]]; then
        case "${BASH_REMATCH[1]}" in
            Pass) echo "patch is correct" ;;
            Fail) echo "patch is incorrect" ;;
        esac
        return
    fi

    # Heuristic: Check for Critical (P0) issues
    local findings_json
    findings_json="$(extract_findings "$markdown_file")"
    local p0_count
    p0_count="$(echo "$findings_json" | jq '[.[] | select(.priority == 0)] | length')"

    if ((p0_count > 0)); then
        echo "patch is incorrect"
    else
        echo "patch is correct"
    fi
}

# ============================================================================
# OVERALL EXPLANATION EXTRACTION
# ============================================================================

# Extract overall explanation/summary
# Input: Markdown file
# Output: Summary text (max 200 chars)
extract_overall_explanation() {
    local markdown_file="$1"
    local explanation=""

    # Try to find Summary section
    if grep -q "^## Summary" "$markdown_file"; then
        explanation="$(sed -n '/^## Summary/,/^##/p' "$markdown_file" | sed '1d;$d' | head -n 3 | tr '\n' ' ')"

    # Try to find Conclusion section
    elif grep -q "^## Conclusion" "$markdown_file"; then
        explanation="$(sed -n '/^## Conclusion/,/^##/p' "$markdown_file" | sed '1d;$d' | head -n 3 | tr '\n' ' ')"

    # Fallback: First paragraph
    else
        explanation="$(head -n 10 "$markdown_file" | grep -v '^#' | grep -v '^$' | head -n 1)"
    fi

    # Truncate to 200 characters
    if [[ ${#explanation} -gt 200 ]]; then
        explanation="${explanation:0:197}..."
    fi

    # Sanitize for safe JSON embedding
    explanation="$(sanitize_text_for_json "$explanation")"

    echo "$explanation"
}

# ============================================================================
# MAIN CONVERSION FUNCTION
# ============================================================================

# Parse Markdown review and generate JSON output
# Usage: parse_markdown_review "input.md" "output.json"
parse_markdown_review() {
    local markdown_file="$1"
    local output_json="$2"

    vibe_log "step" "parse-markdown-review-start" \
        "{\"input\":\"$markdown_file\",\"output\":\"$output_json\"}" \
        "Starting Markdown → JSON conversion" \
        "[\"extract-findings\",\"generate-json\"]" \
        "markdown-parser"

    # Validate inputs
    validate_input_file "$markdown_file" || return 1
    validate_output_file "$output_json" || return 1

    # Extract findings
    local findings_json
    findings_json="$(extract_findings "$markdown_file")"

    # Extract overall assessment
    local correctness
    correctness="$(extract_overall_correctness "$markdown_file")"
    local explanation
    explanation="$(extract_overall_explanation "$markdown_file")"
    local overall_confidence="0.8"  # Default

    # Try to extract overall confidence from content
    local content
    content="$(cat "$markdown_file")"
    local extracted_confidence
    extracted_confidence="$(extract_confidence "$content")"
    if [[ "$extracted_confidence" != "0.8" ]]; then
        overall_confidence="$extracted_confidence"
    fi

    # Generate complete JSON
    local complete_json
    complete_json=$(jq -n \
        --argjson findings "$findings_json" \
        --arg correctness "$correctness" \
        --arg explanation "$explanation" \
        --argjson confidence "$overall_confidence" \
        '{
            findings: $findings,
            overall_correctness: $correctness,
            overall_explanation: $explanation,
            overall_confidence_score: $confidence
        }')

    # Write JSON output
    echo "$complete_json" | jq '.' > "$output_json" || {
        markdown_parser_error "JSON_WRITE_FAILED" "Failed to write JSON output: $output_json"
        return 1
    }

    vibe_log "done" "parse-markdown-review-done" \
        "{\"findings_count\":$(echo "$findings_json" | jq 'length'),\"correctness\":\"$correctness\"}" \
        "Markdown → JSON conversion completed successfully" \
        "[]" \
        "markdown-parser"

    return 0
}

# ============================================================================
# SECURITY METADATA EXTRACTION
# ============================================================================

# Extract CWE (Common Weakness Enumeration) number from text
# Input: "CWE-89: SQL Injection" or "CWE-79"
# Output: 89 | 79 | empty
extract_cwe() {
    local text="$1"

    # Pattern: CWE-XXX
    if [[ "$text" =~ CWE-([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Extract CVSS v3.1 score from text
# Input: "CVSS Score: 9.8 (Critical)" or "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"
# Output: 9.8 | empty
extract_cvss() {
    local text="$1"

    # Pattern 1: CVSS Score: X.X
    if [[ "$text" =~ CVSS[[:space:]]*Score:[[:space:]]*([0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    # Pattern 2: CVSS:3.1/... (extract from vector string - simplified)
    elif [[ "$text" =~ CVSS:3\.1 ]]; then
        # For now, return empty and let the caller parse the vector string
        # Full CVSS vector parsing would be complex
        echo ""
    else
        echo ""
    fi
}

# Extract OWASP Top 10 category from text
# Input: "OWASP A01:2021 - Broken Access Control" or "A03:2021"
# Output: "A01:2021" | "A03:2021" | empty
extract_owasp() {
    local text="$1"

    # Pattern: A01:2021, A02:2021, etc.
    if [[ "$text" =~ (A[0-9]{2}:20[0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Map severity to CVSS score range
# Input: Critical | High | Medium | Low
# Output: CVSS score (middle of range)
severity_to_cvss() {
    local severity="$1"

    case "$severity" in
        Critical) echo "9.5" ;;  # 9.0-10.0
        High)     echo "7.5" ;;  # 7.0-8.9
        Medium)   echo "5.5" ;;  # 4.0-6.9
        Low)      echo "2.0" ;;  # 0.1-3.9
        *)        echo "0.0" ;;
    esac
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for external use
export -f markdown_parser_error
export -f validate_input_file
export -f validate_output_file
export -f extract_priority
export -f extract_confidence
export -f extract_headers
export -f extract_code_location
export -f extract_findings
export -f extract_overall_correctness
export -f extract_overall_explanation
export -f parse_markdown_review
export -f extract_cwe
export -f extract_cvss
export -f extract_owasp
export -f severity_to_cvss
