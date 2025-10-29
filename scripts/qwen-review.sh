#!/bin/bash
# Qwen Code Quality Review Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Qwen code quality review with REVIEW-PROMPT.md guidance
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Specialization: Code quality, design patterns, implementation best practices (HumanEval 93.9%)

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

QWEN_REVIEW_TIMEOUT=${QWEN_REVIEW_TIMEOUT:-600}  # Default: 10 minutes (code quality analysis)
OUTPUT_DIR="${OUTPUT_DIR:-logs/qwen-reviews}"
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
    local runid="qwen_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/qwen_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Qwen",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "Code Quality, Design Patterns, Performance (HumanEval 93.9%)",
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
  "focus": "code_quality_patterns"
}
EOF
)

    vibe_log "tool.start" "$action" "$metadata" \
        "Qwenコード品質レビュー実行開始: コミット ${commit_hash:0:7}" \
        "analyze_patterns,check_quality,optimize_performance"
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

    local human_note="Qwenコード品質レビュー完了: "
    if [[ "$status" == "success" ]]; then
        human_note="${human_note}${issues_found}件のコード品質問題を検出"
    else
        human_note="${human_note}実行失敗"
    fi

    vibe_log "tool.done" "$action" "$metadata" "$human_note" \
        "refactor_code,improve_patterns,optimize_performance"
}

# Show help message
show_help() {
    cat <<EOF
Qwen Code Quality Review Script v1.0.0 (Multi-AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS    Review timeout in seconds (default: $QWEN_REVIEW_TIMEOUT)
  -c, --commit HASH        Commit to review (default: HEAD)
  -o, --output DIR         Output directory (default: $OUTPUT_DIR)
  -h, --help               Show this help message

Focus Areas:
  - Code quality & maintainability (HumanEval 93.9%)
  - Design pattern detection & best practices
  - Performance optimization opportunities
  - Code complexity & technical debt analysis

Environment Variables:
  QWEN_REVIEW_TIMEOUT      Default timeout in seconds
  OUTPUT_DIR               Default output directory

Examples:
  # Review latest commit for quality issues
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
                QWEN_REVIEW_TIMEOUT="$2"
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
    if ! [[ "$QWEN_REVIEW_TIMEOUT" =~ ^[0-9]+$ ]]; then
        log_error "Timeout must be a positive integer: $QWEN_REVIEW_TIMEOUT"
        exit 1
    fi

    if [ "$QWEN_REVIEW_TIMEOUT" -le 0 ]; then
        log_error "Timeout must be greater than 0: $QWEN_REVIEW_TIMEOUT"
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

    # Check if Qwen wrapper is available
    if [[ -x "$PROJECT_ROOT/bin/qwen-wrapper.sh" ]]; then
        log_success "Qwen wrapper is available"
    else
        log_error "Qwen wrapper not found at $PROJECT_ROOT/bin/qwen-wrapper.sh"
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

# Fallback to Claude quality review (Phase 1.6)
fallback_to_claude_review() {
    local commit_hash="$1"
    local diff_content="$2"
    local output_json="$3"
    local output_md="$4"
    local review_guidelines="$5"

    log_warning "Falling back to Claude for quality review"

    # Create Claude-specific prompt
    local claude_prompt="# Claude Quality-Focused Code Review (Fallback from Qwen)

You are performing a code quality review as a fallback when Qwen failed.

$review_guidelines

## Commit Information
- **Commit**: $commit_hash
- **Short**: $(git rev-parse --short "$commit_hash")
- **Subject**: $(git show --format=\"%s\" -s \"$commit_hash\" 2>/dev/null)

## Changes
\`\`\`diff
$diff_content
\`\`\`

## Quality Analysis Focus
Focus on code quality, patterns, and maintainability:
1. Code readability & clarity
2. Design patterns & best practices
3. Performance optimization opportunities
4. Technical debt & complexity

Return JSON following REVIEW-PROMPT.md format."

    # Execute Claude wrapper with extended timeout
    export CLAUDE_MCP_TIMEOUT="${QWEN_REVIEW_TIMEOUT}"

    local claude_output
    local claude_prompt_file
    claude_prompt_file=$(mktemp "${TMPDIR:-/tmp}/claude-fallback-XXXXXX.txt")
    chmod 600 "$claude_prompt_file"
    echo "$claude_prompt" > "$claude_prompt_file"

    if claude_output=$(timeout "$QWEN_REVIEW_TIMEOUT" "$PROJECT_ROOT/bin/claude-wrapper.sh" --stdin < "$claude_prompt_file" 2>&1); then
        # Clean and parse output
        claude_output=$(echo "$claude_output" | sed '/^```json$/d; /^```$/d')

        if echo "$claude_output" | jq empty 2>/dev/null; then
            # Add metadata indicating fallback
            claude_output=$(echo "$claude_output" | jq '. + {
                "fallback_from": "Qwen",
                "reviewer": "Claude (Fallback)",
                "fallback_reason": "Qwen failed or returned invalid data"
            }')

            echo "$claude_output" > "$output_json"
            generate_markdown_report "$claude_output" "$output_md"

            rm -f "$claude_prompt_file"
            log_success "Claude fallback review completed"
            return 0
        else
            log_error "Claude fallback also returned non-JSON output"
            rm -f "$claude_prompt_file"
            return 1
        fi
    else
        log_error "Claude fallback failed"
        rm -f "$claude_prompt_file"
        return 1
    fi
}

# Execute Qwen quality review
execute_qwen_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_json="$OUTPUT_DIR/${timestamp}_${commit_short}_qwen.json"
    local output_md="$OUTPUT_DIR/${timestamp}_${commit_short}_qwen.md"
    local start_time=$(get_timestamp_ms)

    vibe_tool_start "qwen_quality_review" "$COMMIT_HASH" "$QWEN_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null)

    # VALIDATION: Ensure diff is not empty (Phase 1.3)
    if [[ -z "$diff_content" || "$diff_content" == "No diff available" ]]; then
        log_error "Git diff is empty for commit $COMMIT_HASH"
        vibe_tool_done "qwen_quality_review" "failed" "0" "0"
        return 1
    fi

    # VALIDATION: Extract actual file paths from diff to prevent dummy data
    local actual_files
    actual_files=$(echo "$diff_content" | grep '^diff --git' | sed 's/^diff --git a\///' | sed 's/ b\/.*//' | sort -u)
    if [[ -z "$actual_files" ]]; then
        log_warning "No file changes detected in diff"
    fi

    # Read REVIEW-PROMPT.md
    local review_guidelines
    review_guidelines=$(cat "$REVIEW_PROMPT_FILE")

    # Create comprehensive quality-focused prompt
    local review_prompt="# Qwen Quality-Focused Code Review

You are performing a code quality-focused review using the following guidelines:

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

## Code Quality Analysis Focus

As Qwen (93.9% HumanEval accuracy), focus on:

1. **Code Quality & Maintainability**:
   - Code readability & clarity
   - Naming conventions & consistency
   - Function/method length & complexity
   - DRY principle violations
   - Code duplication detection
   - Magic numbers & hard-coded values
   - Comment quality & documentation

2. **Design Patterns & Best Practices**:
   - Appropriate design pattern usage
   - SOLID principles adherence
   - Separation of concerns
   - Dependency injection opportunities
   - Factory, Strategy, Observer patterns
   - Anti-pattern detection (God Object, Spaghetti Code)

3. **Performance Optimization**:
   - Algorithm efficiency (time/space complexity)
   - Database query optimization
   - Unnecessary loops or computations
   - Memory leak risks
   - Caching opportunities
   - Lazy loading possibilities

4. **Technical Debt & Complexity**:
   - Cyclomatic complexity analysis
   - Code smell detection
   - Refactoring opportunities
   - Test coverage gaps
   - Maintainability index

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
- **P0**: Drop everything. Blocks release/production. Universal issues.
- **P1**: Urgent. Address in next cycle.
- **P2**: Normal. Should eventually be fixed.
- **P3**: Low. Nice to have.

**Important**: Focus on NEW issues introduced in this commit, not pre-existing problems."

    # Execute Qwen wrapper with timeout
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/qwen-review-prompt-XXXXXX.txt")
    chmod 600 "$prompt_file"
    echo "$review_prompt" > "$prompt_file"

    # Set QWEN_MCP_TIMEOUT to override wrapper's default 25s timeout
    export QWEN_MCP_TIMEOUT="$QWEN_REVIEW_TIMEOUT"

    local qwen_output
    if qwen_output=$(timeout "$QWEN_REVIEW_TIMEOUT" "$PROJECT_ROOT/bin/qwen-wrapper.sh" --stdin < "$prompt_file" 2>&1); then
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # Remove Markdown code blocks if present (Qwen often wraps JSON in ```json ... ```)
        qwen_output=$(echo "$qwen_output" | sed '/^```json$/d; /^```$/d' | sed '/^Loaded cached credentials\.$/d')

        # Parse JSON output
        if echo "$qwen_output" | jq empty 2>/dev/null; then
            # VALIDATION: Check for dummy data (Phase 1.4)
            local has_dummy_files
            has_dummy_files=$(echo "$qwen_output" | jq -r '.findings[].code_location.absolute_file_path // "" | select(. != "")' | grep -E '(example\.js|test\.js|dummy\.js|fixture)' || echo "")

            if [[ -n "$has_dummy_files" ]]; then
                log_error "Qwen returned dummy/template data with non-existent files:"
                echo "$has_dummy_files" | head -5 >&2

                # Try Claude fallback (Phase 1.6)
                if fallback_to_claude_review "$COMMIT_HASH" "$diff_content" "$output_json" "$output_md" "$review_guidelines"; then
                    local findings_count
                    findings_count=$(jq '.findings | length' "$output_json" 2>/dev/null || echo "0")
                    vibe_tool_done "qwen_quality_review" "fallback_success" "$findings_count" "$execution_time"
                    rm -f "$prompt_file"
                    echo "$output_json:$output_md:0"
                    return
                else
                    log_warning "Claude fallback failed, using dummy data placeholder"
                    echo "$qwen_output" > "${output_json%.json}.txt"
                    generate_fallback_json "$qwen_output" "$output_json"
                    generate_markdown_report "$(cat "$output_json")" "$output_md"
                    vibe_tool_done "qwen_quality_review" "failed" "0" "$execution_time"
                    rm -f "$prompt_file"
                    echo "$output_json:$output_md:1"
                    return
                fi
            fi

            # VALIDATION: Verify findings reference actual files from diff
            if [[ -n "$actual_files" ]]; then
                local invalid_files
                invalid_files=$(echo "$qwen_output" | jq -r '.findings[].code_location.absolute_file_path // ""' | while read -r file; do
                    if [[ -n "$file" ]]; then
                        local basename_file
                        basename_file=$(basename "$file")
                        if ! echo "$actual_files" | grep -q "$basename_file"; then
                            echo "$file"
                        fi
                    fi
                done)

                if [[ -n "$invalid_files" ]]; then
                    log_warning "Qwen referenced files not in diff:"
                    echo "$invalid_files" | head -3 >&2
                fi
            fi

            echo "$qwen_output" > "$output_json"

            # Count findings
            local findings_count
            findings_count=$(echo "$qwen_output" | jq '.findings | length' 2>/dev/null || echo "0")

            # Generate Markdown report
            generate_markdown_report "$qwen_output" "$output_md"

            vibe_tool_done "qwen_quality_review" "success" "$findings_count" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        else
            # Not JSON, treat as text
            echo "$qwen_output" > "${output_json%.json}.txt"

            # Generate fallback reports
            generate_fallback_json "$qwen_output" "$output_json"
            generate_markdown_report "$(cat "$output_json")" "$output_md"

            local issues_found
            issues_found=$(grep -icE "(quality|pattern|complexity|refactor|performance)" "$output_json" || echo "0")

            vibe_tool_done "qwen_quality_review" "success" "$issues_found" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        fi
    else
        local exit_code=$?
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        log_error "Qwen wrapper failed with exit code $exit_code"

        # Try Claude fallback (Phase 1.6)
        if fallback_to_claude_review "$COMMIT_HASH" "$diff_content" "$output_json" "$output_md" "$review_guidelines"; then
            local findings_count
            findings_count=$(jq '.findings | length' "$output_json" 2>/dev/null || echo "0")
            vibe_tool_done "qwen_quality_review" "fallback_success" "$findings_count" "$execution_time"
            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        else
            vibe_tool_done "qwen_quality_review" "failed" "0" "$execution_time"
            rm -f "$prompt_file"
            echo "::$exit_code"
        fi
    fi
}

# Generate fallback JSON from text output
generate_fallback_json() {
    local text_output="$1"
    local output_file="$2"

    # Extract key code quality keywords
    local pattern_count
    pattern_count=$(echo "$text_output" | grep -icE "pattern|design" 2>/dev/null) || true
    pattern_count=${pattern_count:-0}

    local complexity_count
    complexity_count=$(echo "$text_output" | grep -icE "complexity|refactor" 2>/dev/null) || true
    complexity_count=${complexity_count:-0}

    local performance_count
    performance_count=$(echo "$text_output" | grep -icE "performance|optimi" 2>/dev/null) || true
    performance_count=${performance_count:-0}

    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$(git rev-parse --short "$COMMIT_HASH")",
  "review_type": "qwen_quality",
  "findings": [],
  "analysis": {
    "pattern_mentions": $pattern_count,
    "complexity_mentions": $complexity_count,
    "performance_mentions": $performance_count
  },
  "overall_correctness": "unknown",
  "overall_explanation": "Qwen returned non-JSON output. See raw text file for details.",
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
# Qwen Quality-Focused Code Review Report

**Commit**: \`$(git rev-parse --short "$COMMIT_HASH")\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Timeout**: ${QWEN_REVIEW_TIMEOUT}s
**Review Type**: Code Quality & Patterns

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

## Quality Findings

EOF

    # Extract and categorize findings by priority
    local findings_count
    findings_count=$(echo "$json_data" | jq '.findings | length' 2>/dev/null || echo "0")

    if [ "$findings_count" -eq 0 ]; then
        echo "✅ No quality issues detected in this commit." >> "$output_file"
    else
        # Group by priority
        for priority in 0 1 2 3; do
            local priority_label
            case $priority in
                0) priority_label="🔴 P0 - Critical (Drop Everything)" ;;
                1) priority_label="🟠 P1 - Urgent (Next Cycle)" ;;
                2) priority_label="🟡 P2 - Normal (Eventually Fix)" ;;
                3) priority_label="🟢 P3 - Low (Nice to Have)" ;;
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

## Qwen Specialization

This review focused on:
- Code quality & maintainability analysis (HumanEval 93.9%)
- Design patterns & best practices
- Performance optimization opportunities
- Technical debt & complexity detection

---
*Generated by Multi-AI Orchestrium - Qwen Quality Review*
EOF
}

# Create symlinks to latest review
create_symlinks() {
    local json_file="$1"
    local md_file="$2"

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_qwen.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_qwen.md"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Qwen Code Quality Review v1.0.0       ║"
    echo "║  Multi-AI + VibeLogger + REVIEW-PROMPT ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    validate_args
    check_prerequisites

    local result
    result=$(execute_qwen_review)

    local json_file="${result%%:*}"
    local remaining="${result#*:}"
    local md_file="${remaining%%:*}"
    local status="${remaining##*:}"

    if [ -f "$json_file" ] && [ -f "$md_file" ]; then
        create_symlinks "$json_file" "$md_file"

        echo ""
        log_success "Qwen quality review complete!"
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
