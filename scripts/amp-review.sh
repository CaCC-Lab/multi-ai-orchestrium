#!/bin/bash
# Amp Project Management Review Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Amp project management review with REVIEW-PROMPT.md guidance
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Specialization: Project management, documentation quality, stakeholder communication

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

AMP_REVIEW_TIMEOUT=${AMP_REVIEW_TIMEOUT:-600}  # Default: 10 minutes (PM analysis)
OUTPUT_DIR="${OUTPUT_DIR:-logs/amp-reviews}"
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
    local runid="amp_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/amp_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Amp",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "Project Management, Documentation Quality, Stakeholder Communication",
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
  "focus": "project_management_docs"
}
EOF
)

    vibe_log "tool.start" "$action" "$metadata" \
        "Ampプロジェクト管理レビュー実行開始: コミット ${commit_hash:0:7}" \
        "analyze_docs,check_communication,assess_risks"
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

    local human_note="Ampプロジェクト管理レビュー完了: "
    if [[ "$status" == "success" ]]; then
        human_note="${human_note}${issues_found}件のPM/ドキュメント問題を検出"
    else
        human_note="${human_note}実行失敗"
    fi

    vibe_log "tool.done" "$action" "$metadata" "$human_note" \
        "update_docs,improve_communication,mitigate_risks"
}

# Show help message
show_help() {
    cat <<EOF
Amp Project Management Review Script v1.0.0 (Multi-AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS    Review timeout in seconds (default: $AMP_REVIEW_TIMEOUT)
  -c, --commit HASH        Commit to review (default: HEAD)
  -o, --output DIR         Output directory (default: $OUTPUT_DIR)
  -h, --help               Show this help message

Focus Areas:
  - Documentation coverage & quality
  - Stakeholder communication clarity
  - Sprint planning alignment
  - Risk assessment & mitigation
  - Technical debt tracking

Environment Variables:
  AMP_REVIEW_TIMEOUT      Default timeout in seconds
  OUTPUT_DIR              Default output directory

Examples:
  # Review latest commit for PM/doc issues
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
                AMP_REVIEW_TIMEOUT="$2"
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
    if ! [[ "$AMP_REVIEW_TIMEOUT" =~ ^[0-9]+$ ]]; then
        log_error "Timeout must be a positive integer: $AMP_REVIEW_TIMEOUT"
        exit 1
    fi

    if [ "$AMP_REVIEW_TIMEOUT" -le 0 ]; then
        log_error "Timeout must be greater than 0: $AMP_REVIEW_TIMEOUT"
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

    # Check if Amp wrapper is available
    if [[ -x "$PROJECT_ROOT/bin/amp-wrapper.sh" ]]; then
        log_success "Amp wrapper is available"
    else
        log_error "Amp wrapper not found at $PROJECT_ROOT/bin/amp-wrapper.sh"
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

# Execute Amp PM review
execute_amp_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_json="$OUTPUT_DIR/${timestamp}_${commit_short}_amp.json"
    local output_md="$OUTPUT_DIR/${timestamp}_${commit_short}_amp.md"
    local start_time=$(get_timestamp_ms)

    vibe_tool_start "amp_pm_review" "$COMMIT_HASH" "$AMP_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available")

    # Read REVIEW-PROMPT.md
    local review_guidelines
    review_guidelines=$(cat "$REVIEW_PROMPT_FILE")

    # Create comprehensive PM-focused prompt
    local review_prompt="# Amp Project Management-Focused Code Review

You are performing a project management and documentation-focused review using the following guidelines:

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

## Project Management Analysis Focus

As Amp (Project Management AI), focus on:

1. **Documentation Coverage & Quality**:
   - README.md completeness & accuracy
   - API documentation presence & clarity
   - Code comment quality (JSDoc, docstrings, etc.)
   - Changelog/release notes updates
   - Architecture decision records (ADRs)
   - Missing documentation for new features
   - Outdated documentation requiring updates
   - User-facing documentation (guides, tutorials)

2. **Stakeholder Communication**:
   - Commit message clarity & context
   - Breaking changes properly documented
   - Migration guides for major changes
   - Impact on external dependencies
   - User communication requirements
   - Release note quality
   - Change notification adequacy

3. **Sprint Planning & Alignment**:
   - Adherence to project roadmap
   - Feature completeness (partial implementations)
   - Dependency on other in-progress features
   - Estimated effort vs actual changes
   - Scope creep indicators
   - Technical debt introduction
   - Alignment with sprint goals

4. **Risk Assessment & Mitigation**:
   - High-risk changes without proper documentation
   - Single points of failure introduced
   - Dependency update risks
   - Configuration change risks
   - Data migration requirements
   - Backward compatibility concerns
   - Deployment risks & rollback plans

5. **Technical Debt Tracking**:
   - TODO/FIXME comments added
   - Temporary workarounds introduced
   - Known limitations documented
   - Future refactoring needs
   - Technical debt estimation
   - Debt repayment plan presence

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

    # Execute Amp wrapper with timeout
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/amp-review-prompt-XXXXXX.txt")
    chmod 600 "$prompt_file"
    echo "$review_prompt" > "$prompt_file"

    # Set AMP_MCP_TIMEOUT to override wrapper's default timeout
    export AMP_MCP_TIMEOUT="$AMP_REVIEW_TIMEOUT"

    local amp_output
    if amp_output=$(timeout "$AMP_REVIEW_TIMEOUT" "$PROJECT_ROOT/bin/amp-wrapper.sh" --stdin < "$prompt_file" 2>&1); then
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # Remove Markdown code blocks if present
        amp_output=$(echo "$amp_output" | sed '/^```json$/d; /^```$/d' | sed '/^Loaded cached credentials\.$/d')

        # Parse JSON output
        if echo "$amp_output" | jq empty 2>/dev/null; then
            echo "$amp_output" > "$output_json"

            # Count findings
            local findings_count
            findings_count=$(echo "$amp_output" | jq '.findings | length' 2>/dev/null || echo "0")

            # Generate Markdown report
            generate_markdown_report "$amp_output" "$output_md"

            vibe_tool_done "amp_pm_review" "success" "$findings_count" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        else
            # Not JSON, treat as text
            echo "$amp_output" > "${output_json%.json}.txt"

            # Generate fallback reports
            generate_fallback_json "$amp_output" "$output_json"
            generate_markdown_report "$(cat "$output_json")" "$output_md"

            local issues_found
            issues_found=$(grep -icE "(documentation|communication|risk|alignment|debt)" "$output_json" || echo "0")

            vibe_tool_done "amp_pm_review" "success" "$issues_found" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        fi
    else
        local exit_code=$?
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        vibe_tool_done "amp_pm_review" "failed" "0" "$execution_time"

        rm -f "$prompt_file"
        echo "::$exit_code"
    fi
}

# Generate fallback JSON from text output
generate_fallback_json() {
    local text_output="$1"
    local output_file="$2"

    # Extract key PM keywords
    local doc_count
    doc_count=$(echo "$text_output" | grep -icE "documentation|readme|doc" 2>/dev/null) || true
    doc_count=${doc_count:-0}

    local comm_count
    comm_count=$(echo "$text_output" | grep -icE "communication|stakeholder" 2>/dev/null) || true
    comm_count=${comm_count:-0}

    local risk_count
    risk_count=$(echo "$text_output" | grep -icE "risk|concern" 2>/dev/null) || true
    risk_count=${risk_count:-0}

    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$(git rev-parse --short "$COMMIT_HASH")",
  "review_type": "amp_pm",
  "findings": [],
  "analysis": {
    "documentation_mentions": $doc_count,
    "communication_mentions": $comm_count,
    "risk_mentions": $risk_count
  },
  "overall_correctness": "unknown",
  "overall_explanation": "Amp returned non-JSON output. See raw text file for details.",
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
# Amp Project Management-Focused Code Review Report

**Commit**: \`$(git rev-parse --short "$COMMIT_HASH")\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Timeout**: ${AMP_REVIEW_TIMEOUT}s
**Review Type**: Project Management & Documentation

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

## PM Findings

EOF

    # Extract and categorize findings by priority
    local findings_count
    findings_count=$(echo "$json_data" | jq '.findings | length' 2>/dev/null || echo "0")

    if [ "$findings_count" -eq 0 ]; then
        echo "✅ No PM/documentation issues detected in this commit." >> "$output_file"
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

## Amp Specialization

This review focused on:
- Documentation coverage & quality assessment
- Stakeholder communication clarity
- Sprint planning alignment verification
- Risk assessment & mitigation strategies
- Technical debt tracking & management

---
*Generated by Multi-AI Orchestrium - Amp PM Review*
EOF
}

# Create symlinks to latest review
create_symlinks() {
    local json_file="$1"
    local md_file="$2"

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_amp.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_amp.md"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Amp PM Review v1.0.0                  ║"
    echo "║  Multi-AI + VibeLogger + REVIEW-PROMPT ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    validate_args
    check_prerequisites

    local result
    result=$(execute_amp_review)

    local json_file="${result%%:*}"
    local remaining="${result#*:}"
    local md_file="${remaining%%:*}"
    local status="${remaining##*:}"

    if [ -f "$json_file" ] && [ -f "$md_file" ]; then
        create_symlinks "$json_file" "$md_file"

        echo ""
        log_success "Amp PM review complete!"
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
