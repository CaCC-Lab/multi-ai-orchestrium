#!/usr/bin/env bash
# quality-review.sh - Code quality-focused review using Claude + Codex fallback
# Version: 1.0.0
# Purpose: Fast code quality review with refactoring suggestions
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.3.2

set -euo pipefail

# ============================================================================
# P1.3.2.1: Script Configuration & Library Loading
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load common review library
REVIEW_LIB="${SCRIPT_DIR}/lib/review-common.sh"
if [[ ! -f "$REVIEW_LIB" ]]; then
    echo "Error: review-common.sh not found at: $REVIEW_LIB" >&2
    exit 1
fi
source "$REVIEW_LIB"

# Load Claude adapter (primary) - Changed from Qwen for better reliability
CLAUDE_ADAPTER="${SCRIPT_DIR}/lib/review-adapters/adapter-claude.sh"
if [[ ! -f "$CLAUDE_ADAPTER" ]]; then
    echo "Error: adapter-claude.sh not found at: $CLAUDE_ADAPTER" >&2
    exit 1
fi
source "$CLAUDE_ADAPTER"

# ============================================================================
# Configuration
# ============================================================================

REVIEW_TYPE="quality"
DEFAULT_COMMIT="HEAD"
DEFAULT_TIMEOUT=1200  # 20 minutes for Claude quality review (increased for parallel execution)
FALLBACK_TIMEOUT=600  # 10 minutes for Codex review
FAST_MODE_TIMEOUT=300  # 5 minutes for fast mode (increased from 120s for Claude)

# Fast mode configuration
FAST_MODE=false
PRIORITY_FILTER=""  # Empty = all priorities, "0,1" = P0-P1 only

# Output formats
OUTPUT_JSON=true
OUTPUT_MARKDOWN=true

# ============================================================================
# P1.3.2.1: Argument Parsing
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Code quality-focused review using Claude AI with Codex fallback

OPTIONS:
    --commit HASH       Commit hash to review (default: HEAD)
    --timeout SECONDS   Primary AI timeout in seconds (default: 600)
    --output-dir PATH   Output directory for reports (default: auto-generated)
    --format FORMAT     Output format: json|markdown|all (default: json,markdown)
    --fast              Enable fast mode (300s timeout, P0-P1 only)
    --priority P0,P1    Filter findings by priority (e.g., "0,1" for P0-P1)
    --no-fallback       Disable fallback to Codex on timeout
    --help              Show this help message

EXAMPLES:
    # Review latest commit
    $0

    # Fast mode review for critical issues only
    $0 --fast

    # Review specific commit with custom timeout
    $0 --commit abc123 --timeout 900

    # Filter P0-P1 findings
    $0 --priority 0,1

ENVIRONMENT VARIABLES:
    Note: Claude via MCP does not require API keys

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
        --fast)
            FAST_MODE=true
            TIMEOUT="$FAST_MODE_TIMEOUT"
            PRIORITY_FILTER="0,1"
            shift
            ;;
        --priority)
            PRIORITY_FILTER="$2"
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

if [[ "$ENABLE_FALLBACK" == "true" ]]; then
    # Note: Codex fallback uses existing codex-review.sh script
    :
fi

# ============================================================================
# Validation & Setup
# ============================================================================

# Resolve commit reference first (handles HEAD, branches, tags, etc.)
# Only if in a git repository
if git rev-parse --git-dir > /dev/null 2>&1; then
    COMMIT=$(git rev-parse "$COMMIT" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to resolve commit reference: $COMMIT" >&2
        exit 1
    fi
fi

# Sanitize and validate the resolved commit hash
COMMIT=$(sanitize_commit_input "$COMMIT")
validate_commit_hash "$COMMIT" || exit 1

# Setup output directories
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR=$(setup_review_dirs "$REVIEW_TYPE")
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# ============================================================================
# P1.3.2.2: Primary AI Execution - Claude Quality Review
# ============================================================================

execute_primary_review() {
    local commit="$1"
    local timeout="$2"
    local output_dir="$3"

    # VibeLogger integration - review start
    vibe_review_start "$REVIEW_TYPE" "claude" "$commit"

    if [[ "$FAST_MODE" == "true" ]]; then
        echo "Fast mode enabled: ${FAST_MODE_TIMEOUT}s timeout, P0-P1 priority filter" >&2
    fi

    # Execute Claude quality review via adapter
    local review_output
    local exit_code=0
    local start_time=$(date +%s%3N)

    review_output=$(execute_claude_quality_review "$commit" "$timeout" "$output_dir") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    # VibeLogger integration - review done
    local status="success"
    if [[ $exit_code -ne 0 ]]; then status="failure"; fi
    vibe_review_done "$REVIEW_TYPE" "claude" "$status" "$duration_ms" "0"

    if [[ $exit_code -ne 0 ]]; then
        vibe_review_error "$REVIEW_TYPE" "claude" "Primary review failed with exit code: $exit_code"
        return $exit_code
    fi

    # Validate review output
    echo "DEBUG: Review output length: ${#review_output} bytes" >&2
    echo "DEBUG: First 200 chars of review_output:" >&2
    echo "$review_output" | head -c 200 >&2
    echo "" >&2

    if ! validate_review_output "$review_output"; then
        echo "DEBUG: Validation failed. Saving output to /tmp/validation-failed.json" >&2
        echo "$review_output" > /tmp/validation-failed.json
        vibe_review_error "$REVIEW_TYPE" "claude" "Review output validation failed"
        return 1
    fi

    echo "DEBUG: Validation succeeded!" >&2

    # Apply priority filter if specified
    if [[ -n "$PRIORITY_FILTER" ]]; then
        review_output=$(filter_by_priority "$review_output" "$PRIORITY_FILTER")
    fi

    # Save output
    echo "$review_output" > "$output_dir/claude-review.json"

    return 0
}

# ============================================================================
# P1.3.2.3: Fallback AI - Codex Review
# ============================================================================

execute_fallback_review() {
    local commit="$1"
    local timeout="$2"
    local output_dir="$3"

    # VibeLogger integration - fallback start
    vibe_review_start "$REVIEW_TYPE" "codex" "$commit"

    echo "Primary AI (Claude) failed or timed out. Falling back to Codex..." >&2

    # Check if codex-review.sh exists
    local codex_script="$PROJECT_ROOT/scripts/codex-review.sh"
    if [[ ! -f "$codex_script" ]]; then
        vibe_review_error "$REVIEW_TYPE" "codex" "Codex review script not found at: $codex_script"
        return 1
    fi

    # Execute Codex review script
    local exit_code=0
    local start_time=$(date +%s%3N)

    # Note: Assuming codex-review.sh outputs JSON to stdout
    local review_output
    review_output=$(bash "$codex_script" --commit "$commit" --timeout "$timeout" --format json 2>/dev/null) || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    # VibeLogger integration - review done
    local fallback_status="success"
    if [[ $exit_code -ne 0 ]]; then fallback_status="failure"; fi
    vibe_review_done "$REVIEW_TYPE" "codex" "$fallback_status" "$duration_ms" "0"

    if [[ $exit_code -ne 0 ]]; then
        vibe_review_error "$REVIEW_TYPE" "codex" "Fallback review failed with exit code: $exit_code"
        return $exit_code
    fi

    # Validate review output
    if ! validate_review_output "$review_output"; then
        vibe_review_error "$REVIEW_TYPE" "codex" "Fallback review output validation failed"
        return 1
    fi

    # Apply priority filter if specified
    if [[ -n "$PRIORITY_FILTER" ]]; then
        review_output=$(filter_by_priority "$review_output" "$PRIORITY_FILTER")
    fi

    # Save output
    echo "$review_output" > "$output_dir/codex-review.json"

    return 0
}

# ============================================================================
# P1.3.2.5: Priority Filtering
# ============================================================================

filter_by_priority() {
    local json_content="$1"
    local priority_list="$2"  # e.g., "0,1" for P0-P1

    # Convert priority list to jq filter
    # "0,1" -> [0, 1]
    local priorities="[${priority_list}]"

    # Filter findings by priority
    echo "$json_content" | jq --argjson prios "$priorities" '
        .findings = [.findings[] | select(.priority as $p | $prios | index($p) != null)]
    '
}

# ============================================================================
# P1.3.2.4: Output Format Unification
# ============================================================================

generate_markdown_report() {
    local json_file="$1"
    local output_file="$2"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Parse JSON and generate Markdown with suggestion blocks
    cat > "$output_file" <<EOF
# Code Quality Review Report

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

    # Add findings with suggestion blocks
    local findings_count
    findings_count=$(jq '.findings | length' "$json_file")

    if [[ "$findings_count" -eq 0 ]]; then
        echo "No code quality issues found." >> "$output_file"
    else
        # Format findings with suggestion blocks preserved
        jq -r '.findings[] |
            "### " + .title + "\n\n" +
            "**Location**: `" + (.code_location.absolute_file_path // "N/A") + ":" +
            ((.code_location.line_range.start // "?") | tostring) + "-" +
            ((.code_location.line_range.end // "?") | tostring) + "`\n" +
            "**Confidence**: " + (((.confidence_score // 0) * 100 | floor) | tostring) + "%\n" +
            "**Priority**: P" + ((.priority // "?") | tostring) + "\n\n" +
            .body + "\n" +
            (if .suggestion then "\n**Suggested Refactoring**:\n\n" + .suggestion + "\n" else "" end)' \
            "$json_file" >> "$output_file"
    fi

    echo "Markdown report generated: $output_file"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local primary_success=false
    local fallback_success=false
    local primary_output=""
    local fallback_output=""

    echo "=== Code Quality Review Starting ===" >&2
    echo "Commit: $COMMIT" >&2
    echo "Output directory: $OUTPUT_DIR" >&2
    if [[ "$FAST_MODE" == "true" ]]; then
        echo "Mode: FAST (P0-P1 only, 120s timeout)" >&2
    fi
    echo "" >&2

    # Execute primary review (Claude)
    if execute_primary_review "$COMMIT" "$TIMEOUT" "$OUTPUT_DIR"; then
        primary_success=true
        primary_output="$OUTPUT_DIR/claude-review.json"
        echo "✓ Primary review (Claude) completed successfully" >&2
    else
        echo "✗ Primary review (Claude) failed" >&2

        # Execute fallback if enabled
        if [[ "$ENABLE_FALLBACK" == "true" ]]; then
            if execute_fallback_review "$COMMIT" "$FALLBACK_TIMEOUT" "$OUTPUT_DIR"; then
                fallback_success=true
                fallback_output="$OUTPUT_DIR/codex-review.json"
                echo "✓ Fallback review (Codex) completed successfully" >&2
            else
                echo "✗ Fallback review (Codex) failed" >&2
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

    # P1.3.2.4: Generate output formats
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
            all)
                # Generate all formats
                local md_file="${final_output%.json}.md"
                generate_markdown_report "$final_output" "$md_file"
                echo "✓ JSON report: $final_output" >&2
                ;;
            *)
                echo "Warning: Unknown format: $format" >&2
                ;;
        esac
    done

    echo "" >&2
    echo "=== Code Quality Review Completed ===" >&2
    echo "Results saved to: $OUTPUT_DIR" >&2

    return 0
}

# Execute main function
main "$@"
