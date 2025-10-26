#!/usr/bin/env bash
# security-review.sh - Security-focused code review using Gemini + Claude fallback
# Version: 1.0.0
# Purpose: Primary security review with Web search-enhanced CVE detection
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.3.1

set -euo pipefail

# ============================================================================
# P1.3.1.1: Script Configuration & Library Loading
# ============================================================================

REVIEW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$REVIEW_SCRIPT_DIR/../.." && pwd)"

# Load common review library
REVIEW_LIB="${REVIEW_SCRIPT_DIR}/lib/review-common.sh"
if [[ ! -f "$REVIEW_LIB" ]]; then
    echo "Error: review-common.sh not found at: $REVIEW_LIB" >&2
    exit 1
fi
source "$REVIEW_LIB"

# Load Gemini adapter (primary)
GEMINI_ADAPTER="${REVIEW_SCRIPT_DIR}/lib/review-adapters/adapter-gemini.sh"
if [[ ! -f "$GEMINI_ADAPTER" ]]; then
    echo "Error: adapter-gemini.sh not found at: $GEMINI_ADAPTER" >&2
    exit 1
fi
source "$GEMINI_ADAPTER"

# Load Claude Security adapter (fallback)
CLAUDE_SECURITY_ADAPTER="${REVIEW_SCRIPT_DIR}/lib/review-adapters/adapter-claude-security.sh"
if [[ ! -f "$CLAUDE_SECURITY_ADAPTER" ]]; then
    echo "Error: adapter-claude-security.sh not found at: $CLAUDE_SECURITY_ADAPTER" >&2
    exit 1
fi
source "$CLAUDE_SECURITY_ADAPTER"

# ============================================================================
# Configuration
# ============================================================================

REVIEW_TYPE="security"
DEFAULT_COMMIT="HEAD"
DEFAULT_TIMEOUT=600  # 10 minutes for Gemini (Web search overhead)
FALLBACK_TIMEOUT=900  # 15 minutes for Claude Security

# Output formats
OUTPUT_JSON=true
OUTPUT_MARKDOWN=true
OUTPUT_SARIF=false  # Optional SARIF format for IDE integration

# ============================================================================
# P1.3.1.1: Argument Parsing
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Security-focused code review using Gemini AI with Claude fallback

OPTIONS:
    --commit HASH       Commit hash to review (default: HEAD)
    --timeout SECONDS   Primary AI timeout in seconds (default: 600)
    --output-dir PATH   Output directory for reports (default: auto-generated)
    --format FORMAT     Output format: json|markdown|sarif|all (default: json,markdown)
    --no-fallback       Disable fallback to Claude Security on timeout
    --help              Show this help message

EXAMPLES:
    # Review latest commit
    $0

    # Review specific commit
    $0 --commit abc123

    # Custom timeout and output directory
    $0 --commit HEAD --timeout 900 --output-dir ./my-reports

    # Generate all output formats including SARIF
    $0 --format all

ENVIRONMENT VARIABLES:
    GEMINI_API_KEY      Required: Gemini API key
    CLAUDE_API_KEY      Required for fallback: Claude API key

For more information, see: docs/REVIEW_ARCHITECTURE.md
EOF
}

# Parse arguments
COMMIT="$DEFAULT_COMMIT"
TIMEOUT="$DEFAULT_TIMEOUT"
OUTPUT_DIR=""
OUTPUT_FORMATS="json,markdown"
ENABLE_FALLBACK=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --commit)
            COMMIT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMATS="$2"
            shift 2
            ;;
        --no-fallback)
            ENABLE_FALLBACK=false
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# Note: API keys are not required - AI tools work without them

# ============================================================================
# Validation & Setup
# ============================================================================

# Sanitize and validate commit input
COMMIT=$(sanitize_commit_input "$COMMIT")
if [[ "$COMMIT" != "HEAD" ]]; then
    validate_commit_hash "$COMMIT" || exit 1
fi

# Setup output directories
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR=$(setup_review_dirs "$REVIEW_TYPE")
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# ============================================================================
# P1.3.1.2: Primary AI Execution - Gemini with Web Search
# ============================================================================

execute_primary_review() {
    local commit="$1"
    local timeout="$2"
    local output_dir="$3"

    # P1.3.1.5: VibeLogger integration - review start
    vibe_review_start "gemini" "$commit" "$REVIEW_TYPE"

    # Get git diff
    local diff_content
    diff_content=$(get_git_diff "$commit") || {
        vibe_review_error "gemini" "Failed to get git diff for commit: $commit"
        return 1
    }

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt) || {
        vibe_review_error "gemini" "Failed to load REVIEW-PROMPT.md"
        return 1
    }

    # Construct full prompt with diff
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

# Code Diff to Review

\`\`\`diff
$diff_content
\`\`\`

# Security Review Focus

Please perform a security-focused review with the following priorities:
1. Web search for CVE information on used libraries
2. Identify common security vulnerabilities (OWASP Top 10)
3. Check for authentication/authorization issues
4. Verify input validation and sanitization
5. Check for sensitive data exposure

Provide output in the JSON format specified in the prompt above.
EOF
)

    # Initialize CVE cache if enabled
    init_cve_cache

    # Execute Gemini review with timeout
    local review_output
    local exit_code=0
    local start_time=$(date +%s%3N)

    review_output=$(call_gemini_review "$full_prompt" "$timeout") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    # P1.3.1.5: VibeLogger integration - review done
    vibe_review_done "gemini" "$REVIEW_TYPE" "$duration_ms" "$exit_code"

    if [[ $exit_code -ne 0 ]]; then
        vibe_review_error "gemini" "Primary review failed with exit code: $exit_code"
        return $exit_code
    fi

    # Validate review output
    if ! validate_review_output "$review_output"; then
        vibe_review_error "gemini" "Review output validation failed"
        return 1
    fi

    # Save output
    echo "$review_output" > "$output_dir/gemini-review.json"

    return 0
}

# ============================================================================
# P1.3.1.3: Fallback AI - Claude Security
# ============================================================================

execute_fallback_review() {
    local commit="$1"
    local timeout="$2"
    local output_dir="$3"

    # P1.3.1.5: VibeLogger integration - fallback start
    vibe_review_start "claude-security" "$commit" "$REVIEW_TYPE"

    echo "Primary AI (Gemini) failed or timed out. Falling back to Claude Security..." >&2

    # Get git diff
    local diff_content
    diff_content=$(get_git_diff "$commit") || {
        vibe_review_error "claude-security" "Failed to get git diff for commit: $commit"
        return 1
    }

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt) || {
        vibe_review_error "claude-security" "Failed to load REVIEW-PROMPT.md"
        return 1
    }

    # Construct full prompt with diff
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

# Code Diff to Review

\`\`\`diff
$diff_content
\`\`\`

# Security Review Focus

Please perform a comprehensive security review focusing on:
1. Common security vulnerabilities (OWASP Top 10, CWE)
2. Authentication and authorization issues
3. Input validation and sanitization
4. Sensitive data handling
5. Cryptographic weaknesses

Provide output in the JSON format specified in the prompt above.
EOF
)

    # Execute Claude Security review with timeout
    local review_output
    local exit_code=0
    local start_time=$(date +%s%3N)

    review_output=$(call_claude_security_review "$full_prompt" "$timeout") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    # P1.3.1.5: VibeLogger integration - review done
    vibe_review_done "claude-security" "$REVIEW_TYPE" "$duration_ms" "$exit_code"

    if [[ $exit_code -ne 0 ]]; then
        vibe_review_error "claude-security" "Fallback review failed with exit code: $exit_code"
        return $exit_code
    fi

    # Validate review output
    if ! validate_review_output "$review_output"; then
        vibe_review_error "claude-security" "Fallback review output validation failed"
        return 1
    fi

    # Save output
    echo "$review_output" > "$output_dir/claude-security-review.json"

    return 0
}

# ============================================================================
# P1.3.1.4: Output Format Unification
# ============================================================================

generate_markdown_report() {
    local json_file="$1"
    local output_file="$2"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Parse JSON and generate Markdown
    # This uses jq to parse the JSON output
    cat > "$output_file" <<EOF
# Security Review Report

**Commit**: $COMMIT
**Reviewer**: $(jq -r '.metadata.ai_reviewer // "unknown"' "$json_file")
**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Duration**: $(jq -r '.metadata.review_duration_ms // 0' "$json_file" | awk '{printf "%.2fs", $1/1000}')

## Overall Assessment

**Status**: $(jq -r '.overall_correctness' "$json_file")
**Confidence**: $(jq -r '.overall_confidence_score // 0' "$json_file" | awk '{printf "%.0f%%", $1*100}')

**Explanation**: $(jq -r '.overall_explanation // "N/A"' "$json_file")

## Findings

EOF

    # Add findings
    local findings_count
    findings_count=$(jq '.findings | length' "$json_file")

    if [[ "$findings_count" -eq 0 ]]; then
        echo "No security issues found." >> "$output_file"
    else
        jq -r '.findings[] |
            "### " + .title + "\n\n" +
            "**Location**: `" + (.code_location.absolute_file_path // "N/A") + ":" +
            ((.code_location.line_range.start // "?") | tostring) + "-" +
            ((.code_location.line_range.end // "?") | tostring) + "`\n" +
            "**Confidence**: " + (((.confidence_score // 0) * 100 | floor) | tostring) + "%\n" +
            "**Priority**: P" + ((.priority // "?") | tostring) + "\n\n" +
            .body + "\n"' \
            "$json_file" >> "$output_file"
    fi

    echo "Markdown report generated: $output_file"
}

generate_sarif_report() {
    local json_file="$1"
    local output_file="$2"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Convert custom JSON format to SARIF format
    # SARIF is used by IDEs like VS Code for displaying security issues
    cat > "$output_file" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Multi-AI Security Review",
          "version": "1.0.0",
          "informationUri": "https://github.com/your-org/multi-ai-orchestrium"
        }
      },
      "results": $(jq '[.findings[] | {
        "ruleId": "security-review",
        "level": (if .priority <= 1 then "error" elif .priority == 2 then "warning" else "note" end),
        "message": {
          "text": .title
        },
        "locations": [{
          "physicalLocation": {
            "artifactLocation": {
              "uri": (.code_location.absolute_file_path // "unknown")
            },
            "region": {
              "startLine": (.code_location.line_range.start // 1),
              "endLine": (.code_location.line_range.end // 1)
            }
          }
        }]
      }]' "$json_file")
    }
  ]
}
EOF

    echo "SARIF report generated: $output_file"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local primary_success=false
    local fallback_success=false
    local primary_output=""
    local fallback_output=""

    echo "=== Security Review Starting ===" >&2
    echo "Commit: $COMMIT" >&2
    echo "Output directory: $OUTPUT_DIR" >&2
    echo "" >&2

    # Execute primary review (Gemini)
    if execute_primary_review "$COMMIT" "$TIMEOUT" "$OUTPUT_DIR"; then
        primary_success=true
        primary_output="$OUTPUT_DIR/gemini-review.json"
        echo "✓ Primary review (Gemini) completed successfully" >&2
    else
        echo "✗ Primary review (Gemini) failed" >&2

        # Execute fallback if enabled
        if [[ "$ENABLE_FALLBACK" == "true" ]]; then
            if execute_fallback_review "$COMMIT" "$FALLBACK_TIMEOUT" "$OUTPUT_DIR"; then
                fallback_success=true
                fallback_output="$OUTPUT_DIR/claude-security-review.json"
                echo "✓ Fallback review (Claude Security) completed successfully" >&2
            else
                echo "✗ Fallback review (Claude Security) failed" >&2
            fi
        fi
    fi

    # Determine which output to use for report generation
    local final_output=""
    if [[ "$primary_success" == "true" ]]; then
        final_output="$primary_output"
    elif [[ "$fallback_success" == "true" ]]; then
        final_output="$fallback_output"
    else
        echo "Error: Both primary and fallback reviews failed" >&2
        return 1
    fi

    # P1.3.1.4: Generate output formats
    echo "" >&2
    echo "=== Generating Reports ===" >&2

    # Parse output formats
    IFS=',' read -ra FORMATS <<< "$OUTPUT_FORMATS"

    # P0.2.4.2: Convert JSON paths to relative before generating other formats
    if [[ -f "$final_output" ]]; then
        echo "Converting file paths to relative..." >&2
        if convert_json_to_relative_paths "$final_output"; then
            echo "✓ File paths converted to relative" >&2
        else
            echo "Warning: Could not convert all file paths to relative" >&2
        fi
    fi

    for format in "${FORMATS[@]}"; do
        case "$format" in
            json)
                # JSON already saved and converted
                echo "✓ JSON report: $final_output" >&2
                ;;
            markdown|md)
                local md_file="${final_output%.json}.md"
                generate_markdown_report "$final_output" "$md_file"
                ;;
            sarif)
                local sarif_file="${final_output%.json}.sarif"
                generate_sarif_report "$final_output" "$sarif_file"
                ;;
            all)
                # Generate all formats
                local md_file="${final_output%.json}.md"
                local sarif_file="${final_output%.json}.sarif"
                generate_markdown_report "$final_output" "$md_file"
                generate_sarif_report "$final_output" "$sarif_file"
                echo "✓ JSON report: $final_output" >&2
                ;;
            *)
                echo "Warning: Unknown format: $format" >&2
                ;;
        esac
    done

    echo "" >&2
    echo "=== Security Review Completed ===" >&2
    echo "Results saved to: $OUTPUT_DIR" >&2

    return 0
}

# Execute main function
main "$@"
