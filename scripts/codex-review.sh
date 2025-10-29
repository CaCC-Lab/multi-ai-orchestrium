#!/bin/bash
# Codex Review Integration Script - 7AI対応 VibeLogger統合版
# Version: 2.0
# Purpose: Execute Codex code review with fallback to alternative implementation
# 7AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CODEX_REVIEW_TIMEOUT=${CODEX_REVIEW_TIMEOUT:-600}  # Default: 10 minutes
OUTPUT_DIR="${OUTPUT_DIR:-logs/codex-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"

# Review mode: slash | wrapper
# slash: Use native Codex slash command (codex exec /review)
# wrapper: Use legacy codex-wrapper.sh approach
REVIEW_MODE="${REVIEW_MODE:-slash}"

# Save SCRIPT_DIR before sourcing libraries (they may override it)
CODEX_REVIEW_SCRIPT_DIR="$SCRIPT_DIR"

# Load Markdown parser library
MARKDOWN_PARSER_AVAILABLE="false"
if [[ -f "$CODEX_REVIEW_SCRIPT_DIR/lib/markdown-parser.sh" ]]; then
    source "$CODEX_REVIEW_SCRIPT_DIR/lib/markdown-parser.sh"
    MARKDOWN_PARSER_AVAILABLE="true"
else
    echo "⚠️  Warning: markdown-parser.sh not found, JSON conversion disabled" >&2
fi

# Load Codex fallback library (Phase 2.4)
CODEX_FALLBACK_AVAILABLE="false"
if [[ -f "$CODEX_REVIEW_SCRIPT_DIR/lib/codex-fallback.sh" ]]; then
    source "$CODEX_REVIEW_SCRIPT_DIR/lib/codex-fallback.sh"
    CODEX_FALLBACK_AVAILABLE="true"
else
    echo "⚠️  Warning: codex-fallback.sh not found, fallback disabled" >&2
fi

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
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

# Cross-platform millisecond timestamp (P1 fix: macOS/BSD compatibility)
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
    local runid="codex_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/codex_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Codex",
    "integration": "7AI",
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
        "Codexレビュー実行開始: コミット ${commit_hash:0:7}" \
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

    local human_note="Codexレビュー実行完了: "
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
        "Codexレビューサマリー生成: $priority 優先度" \
        "distribute_summary,track_action_items,schedule_followup"
}

# Show help message
show_help() {
    cat <<EOF
Codex Review Integration Script v2.0 (7AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS    Review timeout in seconds (default: $CODEX_REVIEW_TIMEOUT)
  -c, --commit HASH        Commit to review (default: HEAD)
  -o, --output DIR         Output directory (default: $OUTPUT_DIR)
  -h, --help               Show this help message

Environment Variables:
  CODEX_REVIEW_TIMEOUT     Default timeout in seconds
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
                CODEX_REVIEW_TIMEOUT="$2"
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

    # Check if codex is installed
    if command -v codex >/dev/null 2>&1; then
        log_success "Codex CLI is available"
        USE_CODEX="true"
    else
        log_warning "Codex CLI is not installed, using alternative implementation"
        USE_CODEX="false"
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

# Clean Codex-specific output (remove thinking blocks, exec logs)
clean_codex_output() {
    local raw_output="$1"
    local clean_output="$2"

    # Remove thinking blocks and exec logs
    # Pattern 1: Remove lines starting with "thinking" followed by content until next block
    # Pattern 2: Remove lines starting with "exec" followed by command output
    # Pattern 3: Extract only pure Markdown content

    local in_thinking=false
    local in_exec=false

    while IFS= read -r line; do
        # Detect thinking block start
        if [[ "$line" == "thinking" ]]; then
            in_thinking=true
            continue
        fi

        # Detect exec block start
        if [[ "$line" == "exec" ]]; then
            in_exec=true
            continue
        fi

        # Detect block end (empty line or new block start)
        if [[ -z "$line" ]] || [[ "$line" =~ ^(thinking|exec|#)$ ]]; then
            in_thinking=false
            in_exec=false
        fi

        # Write line if not in thinking/exec block
        if [[ "$in_thinking" == false && "$in_exec" == false ]]; then
            echo "$line"
        fi
    done < "$raw_output" > "$clean_output"

    log_info "Cleaned Codex output (removed thinking/exec blocks)"
}

# Generate Markdown from JSON (Phase 2.4)
generate_markdown_from_json() {
    local json_file="$1"
    local md_file="$2"

    if [[ ! -f "$json_file" ]]; then
        log_error "JSON file not found: $json_file"
        return 1
    fi

    # Extract metadata
    local overall_correctness
    overall_correctness=$(jq -r '.overall_correctness // "unknown"' "$json_file")
    local overall_explanation
    overall_explanation=$(jq -r '.overall_explanation // "No explanation provided"' "$json_file")
    local overall_confidence
    overall_confidence=$(jq -r '.overall_confidence_score // 0.5' "$json_file")
    local findings_count
    findings_count=$(jq '.findings | length' "$json_file")

    # Check if this is a fallback review
    local is_fallback
    is_fallback=$(jq 'has("fallback_metadata")' "$json_file")

    cat > "$md_file" <<EOF
# Codex Code Review Report

**Commit**: \`$(git rev-parse --short "$COMMIT_HASH")\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Review Type**: $(if [[ "$is_fallback" == "true" ]]; then echo "Fallback (ESLint + Complexity + Claude LLM)"; else echo "Codex Native"; fi)

## Overview

- **Overall Correctness**: $overall_correctness
- **Confidence Score**: $overall_confidence
- **Total Findings**: $findings_count

**Explanation**: $overall_explanation

EOF

    if [[ "$is_fallback" == "true" ]]; then
        local eslint_count=$(jq -r '.fallback_metadata.eslint_findings // 0' "$json_file")
        local complexity_count=$(jq -r '.fallback_metadata.complexity_findings // 0' "$json_file")
        local llm_count=$(jq -r '.fallback_metadata.llm_findings // 0' "$json_file")

        cat >> "$md_file" <<EOF
### Fallback Review Sources

- **ESLint**: $eslint_count findings
- **Complexity Analysis**: $complexity_count findings
- **Claude LLM**: $llm_count findings

EOF
    fi

    cat >> "$md_file" <<EOF
## Findings

EOF

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
        priority_findings=$(jq --arg p "$priority" '.findings[] | select(.priority == ($p | tonumber))' "$json_file")

        if [[ -n "$priority_findings" ]]; then
            echo "" >> "$md_file"
            echo "### $priority_label" >> "$md_file"
            echo "" >> "$md_file"

            jq -r --arg p "$priority" '.findings[] | select(.priority == ($p | tonumber)) |
                "#### " + .title + "\n\n" +
                "**File**: `" + .code_location.absolute_file_path + "` (Lines " + (.code_location.line_range.start | tostring) + "-" + (.code_location.line_range.end | tostring) + ")\n" +
                "**Confidence**: " + (.confidence_score | tostring) + "\n\n" +
                .body + "\n"' "$json_file" >> "$md_file"
        fi
    done

    cat >> "$md_file" <<EOF

---
*Generated by Multi-AI Orchestrium - Codex Review (with fallback)*
EOF

    log_success "Markdown report generated: $md_file"
}

# Execute Codex review (slash command + wrapper support)
execute_codex_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_codex.md"
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_codex.json"
    local status=0
    local start_time=$(get_timestamp_ms)

    # VibeLogger: tool.start
    vibe_tool_start "codex_review" "$COMMIT_HASH" "$CODEX_REVIEW_TIMEOUT"

    # Check review mode
    if [[ "$REVIEW_MODE" == "slash" ]]; then
        log_info "Using Codex /review slash command..."

        # Phase 2.2.2: Working directory control (Codex requirement)
        # Save current directory
        local original_dir="$PWD"

        # Convert OUTPUT_DIR to absolute path if it's relative
        local abs_output_dir
        if [[ "$OUTPUT_DIR" = /* ]]; then
            abs_output_dir="$OUTPUT_DIR"
        else
            abs_output_dir="$original_dir/$OUTPUT_DIR"
        fi

        # Update file paths to use absolute paths
        md_file="$abs_output_dir/${timestamp}_${commit_short}_codex.md"
        json_file="$abs_output_dir/${timestamp}_${commit_short}_codex.json"

        # Change to repository root (Codex requirement)
        cd "$PROJECT_ROOT" || {
            log_error "Failed to change directory to $PROJECT_ROOT"
            cd "$original_dir"
            echo "::$status"
            return 1
        }

        # Execute codex exec /review slash command
        # Pipe git show output to codex exec /review
        local raw_md_file="${md_file}.raw"
        if git show --no-color "$COMMIT_HASH" | timeout "$CODEX_REVIEW_TIMEOUT" codex exec /review > "$raw_md_file" 2>&1; then
            status=0
            local end_time=$(get_timestamp_ms)
            local execution_time=$((end_time - start_time))

            # Phase 2.2.3: Clean Codex-specific output (remove thinking/exec blocks)
            clean_codex_output "$raw_md_file" "$md_file"
            rm -f "$raw_md_file"

            # Convert Markdown to JSON using markdown-parser.sh
            if [[ "$MARKDOWN_PARSER_AVAILABLE" == "true" ]]; then
                log_info "Converting Markdown review to JSON..."
                if parse_markdown_review "$md_file" "$json_file"; then
                    log_success "Markdown → JSON conversion successful"
                else
                    log_warning "Markdown → JSON conversion failed, Markdown output preserved"
                    status=1
                fi
            else
                log_warning "Markdown parser not available, JSON output skipped"
                status=1
            fi

            # Count issues detected
            local issues_found
            if [[ -f "$json_file" ]]; then
                issues_found=$(jq -r '.findings | length' "$json_file" 2>/dev/null || echo "0")
            else
                issues_found=$(grep -icE "(CRITICAL|WARNING|issue|problem)" "$md_file" 2>/dev/null || echo "0")
            fi

            # VibeLogger: tool.done (success)
            vibe_tool_done "codex_review" "success" "$issues_found" "$execution_time"
        else
            local exit_code=$?
            status=$exit_code
            local end_time=$(get_timestamp_ms)
            local execution_time=$((end_time - start_time))

            log_error "Codex /review command failed (exit code: $exit_code)"

            # Phase 2.4: Try Codex fallback (ESLint + Complexity + Claude LLM)
            if [[ "$CODEX_FALLBACK_AVAILABLE" == "true" ]]; then
                log_warning "Attempting Codex fallback review (ESLint + Complexity + Claude)..."

                # Get diff content
                local diff_content
                diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null)

                # Get changed files
                local changed_files
                changed_files=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_HASH" 2>/dev/null | tr '\n' ' ')

                # Execute fallback
                # Save paths before calling fallback (variables may get corrupted due to sourcing)
                local expected_json="$json_file"
                local expected_md="$md_file"

                if codex_fallback_full_review "$changed_files" "$diff_content" "$expected_json"; then
                    # Restore paths after fallback (in case they were corrupted)
                    json_file="$expected_json"
                    md_file="$expected_md"

                    log_success "Codex fallback review succeeded"

                    # Generate Markdown from JSON
                    if [[ -f "$json_file" ]]; then
                        if generate_markdown_from_json "$json_file" "$md_file" 2>/dev/null; then
                            log_success "Markdown generated from fallback JSON"
                        else
                            log_warning "Failed to generate Markdown, but JSON is available"
                        fi
                    else
                        log_error "Fallback JSON file not found: $json_file"
                        cd "$original_dir" || true
                        return 1
                    fi

                    # Verify MD file was created
                    if [[ ! -f "$md_file" ]] || [[ ! -s "$md_file" ]]; then
                        log_error "Markdown file was not created or is empty: $md_file"
                        cd "$original_dir" || true
                        return 1
                    fi

                    # Count findings
                    local issues_found
                    issues_found=$(jq -r '.findings | length' "$json_file" 2>/dev/null || echo "0")

                    # VibeLogger: tool.done (fallback_success)
                    vibe_tool_done "codex_review" "fallback_success" "$issues_found" "$execution_time"

                    # Return to original directory and output result
                    cd "$original_dir" || true
                    echo "$md_file:$json_file:0"
                    return 0
                else
                    log_error "Codex fallback also failed"
                    # VibeLogger: tool.done (failed)
                    vibe_tool_done "codex_review" "failed" "0" "$execution_time"
                fi
            else
                log_warning "Codex fallback not available"
                # VibeLogger: tool.done (failed)
                vibe_tool_done "codex_review" "failed" "0" "$execution_time"
            fi
        fi

        # Return to original directory
        cd "$original_dir" || {
            log_error "Failed to return to original directory"
        }
    else
        # REVIEW_MODE=wrapper - Use old wrapper implementation
        log_info "Using Codex wrapper (legacy mode)..."

        # Get the diff for the commit
        local diff_content
        diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available for commit $COMMIT_HASH")

        # Create prompt for Codex
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

        # Execute Codex wrapper with timeout
        # Security: Use mktemp for secure temporary file creation
        local prompt_file
        prompt_file=$(mktemp "${TMPDIR:-/tmp}/codex-review-prompt-XXXXXX.txt")
        chmod 600 "$prompt_file"  # Ensure only owner can read/write
        echo "$review_prompt" > "$prompt_file"

        if timeout "$CODEX_REVIEW_TIMEOUT" bash "$PROJECT_ROOT/bin/codex-wrapper.sh" --stdin --non-interactive < "$prompt_file" > "$md_file" 2>&1; then
            status=0
            local end_time=$(get_timestamp_ms)
            local execution_time=$((end_time - start_time))

            # Count issues detected
            local issues_found
            issues_found=$(grep -icE "(CRITICAL|WARNING|issue|problem)" "$md_file" 2>/dev/null || echo "0")

            # VibeLogger: tool.done (success)
            vibe_tool_done "codex_review" "success" "$issues_found" "$execution_time"
        else
            local exit_code=$?
            status=$exit_code
            local end_time=$(get_timestamp_ms)
            local execution_time=$((end_time - start_time))

            # VibeLogger: tool.done (failed)
            vibe_tool_done "codex_review" "failed" "0" "$execution_time"
        fi

        # Cleanup prompt file
        rm -f "$prompt_file"
    fi

    # Return output file paths and status
    # Format: md_file:json_file:status
    echo "$md_file:$json_file:$status"
}

# Execute Alternative review (when Codex is not available)
execute_alternative_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.log"
    local status=0
    local start_time=$(get_timestamp_ms)

    # VibeLogger: tool.start (alternative mode)
    vibe_tool_start "alternative_review" "$COMMIT_HASH" "$CODEX_REVIEW_TIMEOUT"

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

    # Analyze the diff content for potential issues and append to the file
    # Using a simplified approach to avoid awk regex escaping issues
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
    
    # Check for specific issues using simpler grep
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
    
    if echo "$additions" | grep -E "\.to_string\(\)" | grep -i "rust" >/dev/null; then
        echo "- 💡 Rust best practice: Consider using Display trait instead of to_string()" >> "$output_file"
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

    # Try to use an available AI for enhanced analysis if possible
    local available_ai=""
    for ai_tool in claude qwen cursor gemini; do
        if command -v "$ai_tool" >/dev/null 2>&1 || [[ "$ai_tool" == "claude" ]]; then
            available_ai="$ai_tool"
            break
        fi
    done

    if [[ -n "$available_ai" ]]; then
        # Create an AI-enhanced analysis
        local ai_analysis_file="$OUTPUT_DIR/${timestamp}_${commit_short}_ai_analysis.log"
        local ai_prompt="Please analyze the following code changes for potential issues, best practices, and code quality. Focus on security vulnerabilities, performance implications, and maintainability concerns:

$(git show --no-color --pretty=format:"" "$COMMIT_HASH" | head -200)

Provide a structured review with specific recommendations."

        # Create temporary file for prompt
        local prompt_file="/tmp/7ai-review-prompt-$$-$RANDOM.txt"
        echo "$ai_prompt" > "$prompt_file"

        # Call the AI tool if available
        case $available_ai in
            gemini)
                if timeout "$CODEX_REVIEW_TIMEOUT" bash -c "gemini -p \"\$(cat '$prompt_file')\" -y" > "$ai_analysis_file" 2>&1; then
                    # Append AI analysis to main output
                    echo -e "\n## AI Analysis (Gemini)\n" >> "$output_file"
                    cat "$ai_analysis_file" >> "$output_file"
                fi
                ;;
            qwen)
                if timeout "$CODEX_REVIEW_TIMEOUT" bash -c "qwen -p \"\$(cat '$prompt_file')\" -y" > "$ai_analysis_file" 2>&1; then
                    # Append AI analysis to main output
                    echo -e "\n## AI Analysis (Qwen)\n" >> "$output_file"
                    cat "$ai_analysis_file" >> "$output_file"
                fi
                ;;
            cursor)
                if timeout "$CODEX_REVIEW_TIMEOUT" bash -c "cursor-agent -p \"\$(cat '$prompt_file')\" --print" > "$ai_analysis_file" 2>&1; then
                    # Append AI analysis to main output
                    echo -e "\n## AI Analysis (Cursor)\n" >> "$output_file"
                    cat "$ai_analysis_file" >> "$output_file"
                fi
                ;;
            claude)
                # For Claude, just add a note to the output
                echo -e "\n## AI Analysis (Claude)\n" >> "$output_file"
                echo "Note: Claude analysis would be provided interactively in Claude Code." >> "$output_file"
                echo "For comprehensive review, paste the code changes into Claude Code with this prompt:" >> "$output_file"
                echo "$ai_prompt" >> "$output_file"
                ;;
        esac
        
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

# Parse Codex output (original method)
parse_codex_output() {
    local log_file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_codex.json"
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_codex.md"

    # Extract thinking blocks
    local thinking_count=$(grep -c "^thinking$" "$log_file" 2>/dev/null || echo "0")

    # Extract exec blocks
    local exec_count=$(grep -c "^exec$" "$log_file" 2>/dev/null || echo "0")

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
    "thinking_blocks": $thinking_count,
    "exec_blocks": $exec_count,
    "critical_issues": $critical_count,
    "warnings": $warning_count
  },
  "log_file": "$log_file"
}
EOF

    # Generate Markdown report
    cat > "$md_file" <<EOF
# Codex Review Report

**Commit**: \`$commit_short\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Timeout**: ${CODEX_REVIEW_TIMEOUT}s

## Summary

- **Thinking Blocks**: $thinking_count
- **Exec Blocks**: $exec_count
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
    local additions_count=$(grep -c "^+" "$log_file" 2>/dev/null || echo "0")
    local deletions_count=$(grep -c "^-" "$log_file" 2>/dev/null || echo "0")
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
    local suffix="${3:-codex}"  # codex or alt

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_${suffix}.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_${suffix}.md"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Codex Review Integration v2.0         ║"
    echo "║  7AI + VibeLogger + Slash Commands     ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    check_prerequisites
    setup_output_dir

    local result
    local md_file
    local json_file
    local log_file
    local status
    local parse_result
    local review_type

    if [[ "$USE_CODEX" == "true" ]]; then
        # Execute Codex review (slash or wrapper mode)
        result=$(execute_codex_review || echo "")

        # Parse output format: md_file:json_file:status
        md_file="${result%%:*}"
        local temp="${result#*:}"
        json_file="${temp%%:*}"
        status="${temp##*:}"
        log_file="$md_file"  # In slash mode, md_file is the primary output

        if [ -f "$md_file" ] && [ -s "$md_file" ]; then
            review_type="codex"
            log_info "Codex review completed successfully"

            # If JSON file doesn't exist but MD does, and we're not in slash mode, parse it
            if [ ! -f "$json_file" ] && [[ "$REVIEW_MODE" != "slash" ]]; then
                parse_result=$(parse_codex_output "$md_file")
                json_file="${parse_result%%:*}"
                # md_file already set from parse_result if needed
            fi
        else
            log_warning "Codex review failed or returned empty results, falling back to alternative implementation"
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
    if [[ "$review_type" == "codex" ]]; then
        log_success "Codex review complete!"
    else
        log_success "Alternative code review complete!"
    fi
    echo ""
    log_info "Results:"
    if [[ "$REVIEW_MODE" == "slash" && "$review_type" == "codex" ]]; then
        echo "  - Markdown: $md_file"
        echo "  - JSON: $json_file"
    else
        echo "  - JSON: $json_file"
        echo "  - Markdown: $md_file"
        echo "  - Log: $log_file"
    fi

    # VibeLogger: summary.done
    local summary_text="Review complete for commit ${COMMIT_HASH:0:7}"
    local output_files
    if [[ -n "$json_file" && -n "$md_file" ]]; then
        output_files="[\"$json_file\", \"$md_file\"]"
    else
        output_files="[\"$log_file\"]"
    fi
    vibe_summary_done "$summary_text" "high" "$output_files"

    exit $status
}

main "$@"