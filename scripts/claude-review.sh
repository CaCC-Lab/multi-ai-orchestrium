#!/bin/bash
# Claude Code Review Integration Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Claude Code review with fallback to alternative implementation
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Reference: scripts/codex-review.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load sanitization library
source "$SCRIPT_DIR/lib/sanitize.sh"
CLAUDE_REVIEW_TIMEOUT=${CLAUDE_REVIEW_TIMEOUT:-600}  # Default: 10 minutes
OUTPUT_DIR="${OUTPUT_DIR:-logs/claude-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"

# Vibe Logger Setup
VIBE_LOG_DIR="$PROJECT_ROOT/logs/ai-coop/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR" "$OUTPUT_DIR"

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

# Cross-platform millisecond timestamp (macOS/BSD compatibility)
get_timestamp_ms() {
    local ts
    ts=$(date +%s%3N 2>/dev/null)
    # Check if %N is supported (GNU date) by seeing if output contains literal %
    if [[ "$ts" == *"%"* ]]; then
        # %N not supported (macOS/BSD), fallback to seconds + 000
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
    local runid="claude_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/claude_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Claude",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
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
  "execution_mode": "$action"
}
EOF
)

    vibe_log "tool.start" "$action" "$metadata" \
        "Claudeレビュー実行開始: コミット ${commit_hash:0:7}" \
        "analyze_code,detect_issues,suggest_improvements"
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

    local human_note="Claudeレビュー実行完了: "
    if [[ "$status" == "success" ]]; then
        human_note="${human_note}${issues_found}件の問題を検出"
    else
        human_note="${human_note}実行失敗またはフォールバック"
    fi

    vibe_log "tool.done" "$action" "$metadata" "$human_note" \
        "review_findings,apply_suggestions,update_code"
}

vibe_summary_done() {
    local summary_text="$1"
    local priority="$2"
    local output_files="$3"

    local metadata=$(cat << EOF
{
  "priority": "$priority",
  "output_files": $output_files,
  "summary_length": ${#summary_text}
}
EOF
)

    vibe_log "summary.done" "review_summary" "$metadata" \
        "Claudeレビューサマリー生成: $priority 優先度" \
        "distribute_summary,track_action_items,schedule_followup"
}

# Show help message
show_help() {
    cat <<EOF
Claude Code Review Integration Script v1.0.0 (Multi-AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS    Review timeout in seconds (default: $CLAUDE_REVIEW_TIMEOUT)
  -c, --commit HASH        Commit to review (default: HEAD)
  -o, --output DIR         Output directory (default: $OUTPUT_DIR)
  -h, --help               Show this help message

Environment Variables:
  CLAUDE_REVIEW_TIMEOUT    Default timeout in seconds
  OUTPUT_DIR               Default output directory

Examples:
  # Review latest commit with default timeout (10 minutes)
  $0

  # Review with custom timeout (15 minutes)
  $0 --timeout 900

  # Review specific commit
  $0 --commit abc123

  # Custom output directory
  $0 --output /tmp/reviews

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--timeout)
                CLAUDE_REVIEW_TIMEOUT="$2"
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Claude wrapper is available (bin/claude-wrapper.sh)
    if [[ -x "$PROJECT_ROOT/bin/claude-wrapper.sh" ]]; then
        log_success "Claude wrapper is available"
        USE_CLAUDE="true"
    else
        log_warning "Claude wrapper not found, using alternative implementation"
        USE_CLAUDE="false"
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

# Create output directory
setup_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    log_success "Output directory: $OUTPUT_DIR"
}

# Execute Claude review
execute_claude_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_claude.log"
    local status=0
    local start_time=$(get_timestamp_ms)

    # VibeLogger: tool.start
    vibe_tool_start "claude_review" "$COMMIT_HASH" "$CLAUDE_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available for commit $COMMIT_HASH")

    # Create prompt for Claude
    local review_prompt="Please perform a comprehensive code review of the following commit:

Commit: $COMMIT_HASH ($(git show --format="%s" -s "$COMMIT_HASH" 2>/dev/null))
Author: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null)
Date: $(git show --format="%ad" -s "$COMMIT_HASH" 2>/dev/null)

Changes:
$diff_content

Please analyze:
1. Code quality and best practices
2. Potential bugs or issues
3. Security vulnerabilities
4. Performance implications
5. Maintainability concerns
6. Testing suggestions

Provide specific, actionable feedback with line numbers where applicable."

    # Execute Claude wrapper with timeout
    # Security: Use mktemp for secure temporary file creation
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/claude-review-prompt-XXXXXX.txt")
    chmod 600 "$prompt_file"  # Ensure only owner can read/write
    echo "$review_prompt" > "$prompt_file"

    if timeout "$CLAUDE_REVIEW_TIMEOUT" bash -c 'claude /review' > "$output_file" 2>&1; then
        status=0
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # Count issues detected
        local issues_found
        issues_found=$(grep -icE "(CRITICAL|WARNING|issue|problem|vulnerability)" "$output_file" 2>/dev/null || echo "0")

        # VibeLogger: tool.done (success)
        vibe_tool_done "claude_review" "success" "$issues_found" "$execution_time"
    else
        local exit_code=$?
        status=$exit_code
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # VibeLogger: tool.done (failed)
        vibe_tool_done "claude_review" "failed" "0" "$execution_time"
    fi

    # Clean up
    [ -f "$prompt_file" ] && rm -f "$prompt_file"

    echo "$output_file:$status"
}

# Execute Alternative review (when Claude is not available)
execute_alternative_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.log"
    local status=0
    local start_time=$(get_timestamp_ms)

    # VibeLogger: tool.start (alternative mode)
    vibe_tool_start "alternative_review" "$COMMIT_HASH" "$CLAUDE_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color --pretty=format:"" "$COMMIT_HASH" 2>/dev/null || echo "No diff available for commit $COMMIT_HASH")

    # Create a basic review file
    {
        echo "# Alternative Code Review Report"
        echo ""
        echo "## Commit Information"
        echo "- Commit: $COMMIT_HASH ($commit_short)"
        echo "- Date: $(date)"
        echo "- Author: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null)"
        echo ""
        echo "## Code Changes"
        echo "$diff_content"
        echo ""
        echo "## Basic Analysis"
        echo ""
        echo "### Potential Issues Detected:"
    } > "$output_file"

    # Analyze the diff content for potential issues
    local additions=""
    local deletions=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^\+ ]]; then
            additions="$additions$line"$'\n'
        elif [[ "$line" =~ ^\- ]]; then
            deletions="$deletions$line"$'\n'
        fi
    done <<< "$diff_content"

    # Count additions and deletions
    local additions_count=$(echo "$additions" | grep -c "^+" 2>/dev/null || echo "0")
    local deletions_count=$(echo "$deletions" | grep -c "^-" 2>/dev/null || echo "0")

    # Check for specific issues
    if echo "$additions" | grep -E "exec\(|eval\(|importlib\.|os\.system|subprocess" >/dev/null; then
        echo "- ⚠️  Potential security issue: Dynamic code execution found" >> "$output_file"
    fi

    if echo "$additions" | grep -E "password|secret|token|key" | grep -v -E "hash|encrypt|obfuscate" >/dev/null; then
        echo "- ⚠️  Potential security issue: Sensitive information in code" >> "$output_file"
    fi

    if echo "$additions" | grep -E "TODO|FIXME|HACK|XXX" >/dev/null; then
        echo "- 📝 TODO/FIXME comments found that should be addressed" >> "$output_file"
    fi

    if echo "$additions" | grep -E "print\(|console\.log|debug|pdb" >/dev/null; then
        echo "- 🚨 Debug statements found that should be removed" >> "$output_file"
    fi

    echo "- Added: $additions_count lines" >> "$output_file"
    echo "- Removed: $deletions_count lines" >> "$output_file"

    # Add quality suggestions
    {
        echo ""
        echo "### Code Quality Suggestions:"
        echo "- Review all security-related changes"
        echo "- Ensure proper error handling is implemented"
        echo "- Verify all TODO/FIXME comments are addressed before merging"
        echo "- Consider adding unit tests for new functionality"
        echo "- Follow project-specific style guidelines"
        echo ""
    } >> "$output_file"

    # Try to use an available AI for enhanced analysis
    local available_ai=""
    for ai_tool in gemini qwen codex cursor; do
        if [[ -x "$PROJECT_ROOT/bin/${ai_tool}-wrapper.sh" ]]; then
            available_ai="$ai_tool"
            break
        fi
    done

    if [[ -n "$available_ai" ]]; then
        local ai_analysis_file="$OUTPUT_DIR/${timestamp}_${commit_short}_ai_analysis.log"
        local ai_prompt="Please analyze the following code changes for potential issues, best practices, and code quality. Focus on security vulnerabilities, performance implications, and maintainability concerns:

$(git show --no-color --pretty=format:"" "$COMMIT_HASH" | head -200)

Provide a structured review with specific recommendations."

        # Security: Use mktemp for secure temporary file creation
        local prompt_file
        prompt_file=$(mktemp "${TMPDIR:-/tmp}/claude-alt-review-prompt-XXXXXX.txt")
        chmod 600 "$prompt_file"  # Ensure only owner can read/write
        echo "$ai_prompt" > "$prompt_file"

        if timeout "$CLAUDE_REVIEW_TIMEOUT" bash -c "$PROJECT_ROOT/bin/${available_ai}-wrapper.sh --stdin < '$prompt_file'" > "$ai_analysis_file" 2>&1; then
            echo -e "\n## AI Analysis (${available_ai^})\n" >> "$output_file"
            cat "$ai_analysis_file" >> "$output_file"
        fi

        # Clean up
        [ -f "$prompt_file" ] && rm -f "$prompt_file"
        [ -f "$ai_analysis_file" ] && rm -f "$ai_analysis_file"
    fi

    # VibeLogger: tool.done (alternative review)
    local end_time=$(get_timestamp_ms)
    local execution_time=$((end_time - start_time))
    local issues_found
    issues_found=$(grep -c "⚠️\|🚨\|💡\|📝" "$output_file" 2>/dev/null || echo "0")
    vibe_tool_done "alternative_review" "success" "$issues_found" "$execution_time"

    echo "$output_file:$status"
}

# Parse Claude output
parse_claude_output() {
    local log_file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_claude.json"
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_claude.md"

    # Detect issues by keywords
    local critical_count
    critical_count=$(grep -iE "(CRITICAL|major problem|high-severity)" "$log_file" 2>/dev/null | wc -l)
    if ! [[ "$critical_count" =~ ^[0-9]+$ ]]; then
        critical_count=0
    fi

    local warning_count
    warning_count=$(grep -iE "(WARNING|potential issue|注意)" "$log_file" 2>/dev/null | wc -l)
    if ! [[ "$warning_count" =~ ^[0-9]+$ ]]; then
        warning_count=0
    fi

    # Generate JSON report
    cat > "$json_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$commit_short",
  "review_duration_sec": 0,
  "status": "completed",
  "analysis": {
    "critical_issues": $critical_count,
    "warnings": $warning_count
  },
  "log_file": "$log_file"
}
EOF

    # Generate Markdown report
    cat > "$md_file" <<EOF
# Claude Code Review Report

**Commit**: \`$commit_short\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Timeout**: ${CLAUDE_REVIEW_TIMEOUT}s

## Summary

- **Critical Issues**: $critical_count
- **Warnings**: $warning_count

## Analysis

EOF

    # Append critical issues
    if [ "$critical_count" -gt 0 ]; then
        echo "### 🔴 Critical Issues" >> "$md_file"
        echo "" >> "$md_file"
        grep -iE "(CRITICAL|major problem|high-severity)" "$log_file" 2>/dev/null | head -20 >> "$md_file" || true
        echo "" >> "$md_file"
    fi

    # Append warnings
    if [ "$warning_count" -gt 0 ]; then
        echo "### ⚠️ Warnings" >> "$md_file"
        echo "" >> "$md_file"
        grep -iE "(WARNING|potential issue|注意)" "$log_file" 2>/dev/null | head -20 >> "$md_file" || true
        echo "" >> "$md_file"
    fi

    # Append full log reference
    echo "## Full Log" >> "$md_file"
    echo "" >> "$md_file"
    echo "See: \`$log_file\`" >> "$md_file"

    echo "$json_file:$md_file"
}

# Parse alternative output
parse_alternative_output() {
    local log_file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.json"
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.md"

    # Extract basic metrics
    local additions_count=$(grep -c "Added:" "$log_file" 2>/dev/null || echo "0")
    local deletions_count=$(grep -c "Removed:" "$log_file" 2>/dev/null || echo "0")
    local issue_count=$(grep -c "⚠️\|🚨\|💡\|📝" "$log_file" 2>/dev/null || echo "0")

    # Generate JSON report
    cat > "$json_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$commit_short",
  "review_duration_sec": 0,
  "status": "completed",
  "analysis": {
    "lines_added": $additions_count,
    "lines_removed": $deletions_count,
    "issues_detected": $issue_count,
    "ai_analysis_performed": $(grep -q "AI Analysis" "$log_file" && echo "true" || echo "false")
  },
  "log_file": "$log_file"
}
EOF

    # Generate Markdown report
    head -500 "$log_file" > "$md_file"

    echo "$json_file:$md_file"
}

# Create symlinks to latest review
create_symlinks() {
    local json_file="$1"
    local md_file="$2"
    local suffix="${3:-claude}"  # claude or alt

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_${suffix}.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_${suffix}.md"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Claude Code Review Integration v1.0.0 ║"
    echo "║  Multi-AI + VibeLogger                 ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    check_prerequisites
    setup_output_dir

    local result
    local log_file
    local status
    local parse_result
    local json_file
    local md_file
    local review_type

    if [[ "$USE_CLAUDE" == "true" ]]; then
        # Execute Claude review
        result=$(execute_claude_review 2>/dev/null || echo "")
        log_file="${result%%:*}"
        status="${result##*:}"

        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            parse_result=$(parse_claude_output "$log_file")
            json_file="${parse_result%%:*}"
            md_file="${parse_result##*:}"
            review_type="claude"
            log_info "Claude review completed successfully"
        else
            log_warning "Claude review failed or returned empty results, falling back to alternative implementation"
            result=$(execute_alternative_review)
            log_file="${result%%:*}"
            status="${result##*:}"
            review_type="alt"
            parse_result=$(parse_alternative_output "$log_file")
            json_file="${parse_result%%:*}"
            md_file="${parse_result##*:}"
        fi
    else
        # Execute alternative review
        result=$(execute_alternative_review)
        log_file="${result%%:*}"
        status="${result##*:}"
        review_type="alt"

        if [ -f "$log_file" ]; then
            parse_result=$(parse_alternative_output "$log_file")
            json_file="${parse_result%%:*}"
            md_file="${parse_result##*:}"
        else
            log_error "Review failed - no output generated"
            exit 1
        fi
    fi

    create_symlinks "$json_file" "$md_file" "$review_type"

    echo ""
    if [[ "$review_type" == "claude" ]]; then
        log_success "Claude Code review complete!"
    else
        log_success "Alternative code review complete!"
    fi
    echo ""
    log_info "Results:"
    echo "  - JSON: $json_file"
    echo "  - Markdown: $md_file"
    echo "  - Log: $log_file"

    # VibeLogger: summary.done
    local summary_text="Review complete for commit ${COMMIT_HASH:0:7}"
    local output_files="[\"$json_file\", \"$md_file\", \"$log_file\"]"
    vibe_summary_done "$summary_text" "high" "$output_files"

    exit $status
}

main "$@"
