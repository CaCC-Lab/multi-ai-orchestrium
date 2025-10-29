#!/bin/bash
# Cursor Developer Experience Review Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Cursor DX-focused review with REVIEW-PROMPT.md guidance
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Specialization: IDE integration, developer experience, code readability, refactoring opportunities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Vibe Logger Setup - MUST be set BEFORE loading vibe-logger-lib.sh
export VIBE_LOG_DIR="$PROJECT_ROOT/logs/vibe/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR"

# Load required libraries
source "$SCRIPT_DIR/lib/sanitize.sh"
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"

CURSOR_REVIEW_TIMEOUT=${CURSOR_REVIEW_TIMEOUT:-600}  # Default: 10 minutes (DX analysis)
OUTPUT_DIR="${OUTPUT_DIR:-logs/cursor-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"
mkdir -p "$OUTPUT_DIR"

# Load REVIEW-PROMPT.md
REVIEW_PROMPT_FILE="$PROJECT_ROOT/REVIEW-PROMPT.md"
if [[ ! -f "$REVIEW_PROMPT_FILE" ]]; then
    echo "❌ REVIEW-PROMPT.md not found: $REVIEW_PROMPT_FILE"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Utility functions
log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Cross-platform millisecond timestamp
get_timestamp_ms() {
    local ts
    ts=$(date +%s%3N 2>/dev/null)
    if [[ "$ts" == *"%"* ]]; then
        echo "$(date +%s)000"
    else
        echo "$ts"
    fi
}

# ======================================
# Vibe Logger Functions
# ======================================

vibe_log() {
    local event_type="$1"
    local action="$2"
    local metadata="$3"
    local human_note="$4"
    local ai_todo="${5:-}"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="cursor_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/cursor_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Cursor",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "IDE Integration, Developer Experience, Code Readability",
    "todo": "$ai_todo"
  }
}
EOF
}

vibe_tool_start() {
    local action="$1"
    local commit_hash="$2"
    local timeout="$3"

    local metadata=$(cat << EOF
{
  "commit": "$commit_hash",
  "timeout_sec": $timeout,
  "execution_mode": "$action",
  "focus": "dx_ide_integration"
}
EOF
)

    vibe_log "tool.start" "$action" "$metadata" \
        "Cursor DX/IDE統合レビュー実行開始: コミット ${commit_hash:0:7}" \
        "analyze_readability,check_ide_friendliness,suggest_refactoring"
}

vibe_tool_done() {
    local action="$1"
    local status="$2"
    local issues_found="${3:-0}"
    local execution_time="${4:-0}"

    local metadata=$(cat << EOF
{
  "status": "$status",
  "issues_found": $issues_found,
  "execution_time_ms": $execution_time
}
EOF
)

    local human_note="Cursor DX/IDE統合レビュー完了: "
    if [[ "$status" == "success" ]]; then
        human_note="${human_note}${issues_found}件のDX/可読性問題を検出"
    else
        human_note="${human_note}実行失敗"
    fi

    vibe_log "tool.done" "$action" "$metadata" "$human_note" \
        "improve_readability,enhance_navigation,optimize_dx"
}

# Show help message
show_help() {
    cat <<EOF
Cursor Developer Experience Review Script v1.0.0 (Multi-AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS    Review timeout in seconds (default: $CURSOR_REVIEW_TIMEOUT)
  -c, --commit HASH        Commit to review (default: HEAD)
  -o, --output DIR         Output directory (default: $OUTPUT_DIR)
  -h, --help               Show this help message

Focus Areas:
  - IDE integration & navigation efficiency
  - Code readability & developer experience
  - Autocomplete-friendly patterns
  - Refactoring opportunities & impact analysis

Environment Variables:
  CURSOR_REVIEW_TIMEOUT    Default timeout in seconds
  OUTPUT_DIR               Default output directory

Examples:
  # Review latest commit for DX issues
  $0

  # Review with extended timeout (15 minutes)
  $0 --timeout 900

  # Review specific commit
  $0 --commit abc123

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--timeout)
                CURSOR_REVIEW_TIMEOUT="$2"
                shift 2
                ;;
            -c|--commit)
                COMMIT_HASH="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    # Validate timeout
    if ! [[ "$CURSOR_REVIEW_TIMEOUT" =~ ^[0-9]+$ ]]; then
        log_error "Timeout must be a positive integer: $CURSOR_REVIEW_TIMEOUT"
        exit 1
    fi

    if [ "$CURSOR_REVIEW_TIMEOUT" -le 0 ]; then
        log_error "Timeout must be greater than 0: $CURSOR_REVIEW_TIMEOUT"
        exit 1
    fi

    # Validate commit hash format (basic check)
    if [ -n "$COMMIT_HASH" ] && [[ ! "$COMMIT_HASH" =~ ^[a-fA-F0-9]{4,40}$|^HEAD$ ]]; then
        # Allow branch/tag names to pass through - git will validate
        true
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Cursor wrapper is available
    if [[ -x "$PROJECT_ROOT/bin/cursor-wrapper.sh" ]]; then
        log_success "Cursor wrapper is available"
    else
        log_error "Cursor wrapper not found at $PROJECT_ROOT/bin/cursor-wrapper.sh"
        exit 1
    fi

    # Check if in git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    # Verify commit exists
    if ! git rev-parse --verify "$COMMIT_HASH" >/dev/null 2>&1; then
        log_error "Commit not found: $COMMIT_HASH"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Execute Cursor DX review
execute_cursor_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_json="$OUTPUT_DIR/${timestamp}_${commit_short}_cursor.json"
    local output_md="$OUTPUT_DIR/${timestamp}_${commit_short}_cursor.md"
    local start_time=$(get_timestamp_ms)

    vibe_tool_start "cursor_dx_review" "$COMMIT_HASH" "$CURSOR_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available")

    # Read REVIEW-PROMPT.md
    local review_guidelines
    review_guidelines=$(cat "$REVIEW_PROMPT_FILE")

    # Create comprehensive DX-focused prompt
    local review_prompt="# Cursor DX-Focused Code Review

You are performing a developer experience and IDE integration focused review using the following guidelines:

$review_guidelines

## Commit Information
- **Commit**: $COMMIT_HASH
- **Short**: $commit_short
- **Subject**: $(git show --format="%s" -s "$COMMIT_HASH" 2>/dev/null)
- **Author**: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null)
- **Date**: $(git show --format="%ad" -s "$COMMIT_HASH" 2>/dev/null)

## Changes
\`\`\`diff
$diff_content
\`\`\`

## Developer Experience Analysis Focus

As Cursor (IDE integration specialist), focus on:

1. **Code Readability & Clarity**:
   - Variable/function naming quality
   - Self-documenting code patterns
   - Comments necessity & quality
   - Code structure & organization
   - Visual clarity (formatting, whitespace)
   - Cognitive load assessment
   - Mental model alignment

2. **IDE Integration & Navigation**:
   - Jump-to-definition friendliness
   - Symbol search efficiency
   - File organization for quick access
   - Import statement clarity
   - Module/package structure
   - Code folding opportunities
   - Breadcrumb navigation support

3. **Autocomplete & IntelliSense**:
   - Type annotation completeness
   - Interface/contract clarity
   - Generic type usage
   - Parameter naming quality
   - Return type clarity
   - Inline documentation (JSDoc, docstrings)
   - Signature help quality

4. **Refactoring Opportunities**:
   - Extract method candidates
   - Extract variable/constant opportunities
   - Inline refactoring possibilities
   - Rename refactoring impact
   - Move refactoring safety
   - Dead code elimination
   - Code duplication for extraction

5. **Developer Workflow Impact**:
   - Build time implications
   - Hot reload compatibility
   - Debug experience (breakpoints, watches)
   - Test execution speed
   - Linting/formatting integration
   - Version control friendliness
   - Merge conflict likelihood

## Output Requirements

Return findings in JSON format following REVIEW-PROMPT.md structure:

\`\`\`json
{
  \"findings\": [
    {
      \"title\": \"[P0-P3] <issue title>\",
      \"body\": \"<markdown explanation with file:line references>\",
      \"confidence_score\": <0.0-1.0>,
      \"priority\": <0-3>,
      \"code_location\": {
        \"absolute_file_path\": \"<path>\",
        \"line_range\": {\"start\": <int>, \"end\": <int>}
      }
    }
  ],
  \"overall_correctness\": \"patch is correct\" | \"patch is incorrect\",
  \"overall_explanation\": \"<1-3 sentence justification>\",
  \"overall_confidence_score\": <0.0-1.0>
}
\`\`\`

**Priority Levels**:
- **P0**: Drop everything. Severely impacts developer productivity.
- **P1**: Urgent. Significantly hinders DX.
- **P2**: Normal. Moderate DX improvement.
- **P3**: Low. Nice to have DX enhancement.

**Important**: Focus on NEW DX issues introduced in this commit, not pre-existing problems."

    # Execute Cursor wrapper with timeout
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/cursor-review-prompt-XXXXXX.txt")
    chmod 600 "$prompt_file"
    echo "$review_prompt" > "$prompt_file"

    # Set CURSOR_MCP_TIMEOUT to override wrapper's default 25s timeout
    export CURSOR_MCP_TIMEOUT="$CURSOR_REVIEW_TIMEOUT"

    local cursor_output
    if cursor_output=$(timeout "$CURSOR_REVIEW_TIMEOUT" "$PROJECT_ROOT/bin/cursor-wrapper.sh" --stdin < "$prompt_file" 2>&1); then
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # Remove Markdown code blocks if present
        cursor_output=$(echo "$cursor_output" | sed '/^```json$/d; /^```$/d' | sed '/^Loaded cached credentials\.$/d')

        # Parse JSON output
        if echo "$cursor_output" | jq empty 2>/dev/null; then
            echo "$cursor_output" > "$output_json"

            # Count findings
            local findings_count
            findings_count=$(echo "$cursor_output" | jq '.findings | length' 2>/dev/null || echo "0")

            # Generate Markdown report
            generate_markdown_report "$cursor_output" "$output_md"

            vibe_tool_done "cursor_dx_review" "success" "$findings_count" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        else
            # Not JSON, treat as text
            echo "$cursor_output" > "${output_json%.json}.txt"

            # Generate fallback reports
            generate_fallback_json "$cursor_output" "$output_json"
            generate_markdown_report "$(cat "$output_json")" "$output_md"

            local issues_found
            issues_found=$(grep -icE "(readability|refactor|navigation|autocomplete|dx)" "$output_json" || echo "0")

            vibe_tool_done "cursor_dx_review" "success" "$issues_found" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        fi
    else
        local exit_code=$?
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        vibe_tool_done "cursor_dx_review" "failed" "0" "$execution_time"

        rm -f "$prompt_file"
        echo "::$exit_code"
    fi
}

# Generate fallback JSON from text output
generate_fallback_json() {
    local text_output="$1"
    local output_file="$2"

    # Extract key DX keywords
    local readability_count
    readability_count=$(echo "$text_output" | grep -icE "readability|readable|clarity" 2>/dev/null) || true
    readability_count=${readability_count:-0}

    local navigation_count
    navigation_count=$(echo "$text_output" | grep -icE "navigation|navigate|jump" 2>/dev/null) || true
    navigation_count=${navigation_count:-0}

    local refactor_count
    refactor_count=$(echo "$text_output" | grep -icE "refactor|extract|inline" 2>/dev/null) || true
    refactor_count=${refactor_count:-0}

    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$(git rev-parse --short "$COMMIT_HASH")",
  "review_type": "cursor_dx",
  "findings": [],
  "analysis": {
    "readability_mentions": $readability_count,
    "navigation_mentions": $navigation_count,
    "refactor_mentions": $refactor_count
  },
  "overall_correctness": "unknown",
  "overall_explanation": "Cursor returned non-JSON output. See raw text file for details.",
  "overall_confidence_score": 0.5,
  "raw_output_file": "${output_file%.json}.txt"
}
EOF
}

# Generate Markdown report from JSON
generate_markdown_report() {
    local json_data="$1"
    local output_file="$2"

    cat > "$output_file" <<EOF
# Cursor DX-Focused Code Review Report

**Commit**: \`$(git rev-parse --short "$COMMIT_HASH")\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Timeout**: ${CURSOR_REVIEW_TIMEOUT}s
**Review Type**: Developer Experience & IDE Integration

## Overview

EOF

    # Extract overall assessment
    local overall_correctness
    overall_correctness=$(echo "$json_data" | jq -r '.overall_correctness // "unknown"')
    local overall_explanation
    overall_explanation=$(echo "$json_data" | jq -r '.overall_explanation // "No explanation provided"')
    local overall_confidence
    overall_confidence=$(echo "$json_data" | jq -r '.overall_confidence_score // 0.5')

    cat >> "$output_file" <<EOF
- **Overall Correctness**: $overall_correctness
- **Confidence Score**: $overall_confidence
- **Explanation**: $overall_explanation

## DX Findings

EOF

    # Extract and categorize findings by priority
    local findings_count
    findings_count=$(echo "$json_data" | jq '.findings | length' 2>/dev/null || echo "0")

    if [ "$findings_count" -eq 0 ]; then
        echo "✅ No DX issues detected in this commit." >> "$output_file"
    else
        # Group by priority
        for priority in 0 1 2 3; do
            local priority_label
            case $priority in
                0) priority_label="🔴 P0 - Critical (Severe DX Impact)" ;;
                1) priority_label="🟠 P1 - Urgent (Significant DX Hindrance)" ;;
                2) priority_label="🟡 P2 - Normal (Moderate DX Improvement)" ;;
                3) priority_label="🟢 P3 - Low (Nice to Have DX Enhancement)" ;;
            esac

            local priority_findings
            priority_findings=$(echo "$json_data" | jq --arg p "$priority" '.findings[] | select(.priority == ($p | tonumber))')

            if [ -n "$priority_findings" ]; then
                echo "" >> "$output_file"
                echo "### $priority_label" >> "$output_file"
                echo "" >> "$output_file"

                echo "$json_data" | jq -r --arg p "$priority" '.findings[] | select(.priority == ($p | tonumber)) |
                    "#### " + .title + "\n\n" +
                    "**File**: `" + .code_location.absolute_file_path + "` (Lines " + (.code_location.line_range.start | tostring) + "-" + (.code_location.line_range.end | tostring) + ")\n" +
                    "**Confidence**: " + (.confidence_score | tostring) + "\n\n" +
                    .body + "\n"' >> "$output_file"
            fi
        done
    fi

    cat >> "$output_file" <<EOF

## Cursor Specialization

This review focused on:
- IDE integration & navigation efficiency
- Code readability & developer experience
- Autocomplete-friendly patterns & type safety
- Refactoring opportunities & workflow impact

---
*Generated by Multi-AI Orchestrium - Cursor DX Review*
EOF
}

# Create symlinks to latest review
create_symlinks() {
    local json_file="$1"
    local md_file="$2"

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_cursor.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_cursor.md"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Cursor DX Review v1.0.0               ║"
    echo "║  Multi-AI + VibeLogger + REVIEW-PROMPT ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    validate_args
    check_prerequisites

    local result
    result=$(execute_cursor_review)

    local json_file="${result%%:*}"
    local remaining="${result#*:}"
    local md_file="${remaining%%:*}"
    local status="${remaining##*:}"

    if [ -f "$json_file" ] && [ -f "$md_file" ]; then
        create_symlinks "$json_file" "$md_file"

        echo ""
        log_success "Cursor DX review complete!"
        echo ""
        log_info "Results:"
        echo "  - JSON: $json_file"
        echo "  - Markdown: $md_file"

        exit 0
    else
        log_error "Review failed - no output generated"
        exit "$status"
    fi
}

main "$@"
