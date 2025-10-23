#!/usr/bin/env bash
# Multi-AI Core Utilities Library
# Purpose: Logging, timestamps, VibeLogger integration, and common utilities
# Responsibilities:
#   - Color-coded logging functions (log_info, log_success, log_warning, log_error, log_phase)
#   - Cross-platform timestamp generation (get_timestamp_ms)
#   - VibeLogger integration (vibe_log, vibe_pipeline_*, vibe_phase_*, vibe_summary_*)
#   - Input sanitization (sanitize_input)
#   - Timeout handling (run_with_timeout)
#   - Multi-AI banner display (show_multi_ai_banner)

set -euo pipefail

# ============================================================================
# Color Definitions
# ============================================================================

# Colors - Check if already defined to avoid readonly error
if [[ ! -v RED ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly YELLOW='\033[0;33m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly NC='\033[0m' # No Color
fi

# ============================================================================
# Logging Functions (5 functions)
# ============================================================================

log_info() {
    echo -e "${CYAN}ℹ️  $*${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

log_phase() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}🚀 $*${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ============================================================================
# Timestamp Function (1 function)
# ============================================================================

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

# ============================================================================
# VibeLogger Integration Functions (6 functions)
# ============================================================================

vibe_log() {
    local event_type="$1"
    local action="$2"
    local metadata="$3"
    local human_note="$4"
    local ai_todo="${5:-}"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="7ai_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/7ai_orchestration_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Multi-AI Orchestration",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "todo": "$ai_todo"
  }
}
EOF
}

vibe_pipeline_start() {
    local workflow="$1"
    local description="$2"
    local total_phases="$3"

    local metadata=$(cat << EOF
{
  "workflow": "$workflow",
  "description": "$description",
  "total_phases": $total_phases,
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "pipeline.start" "7ai_workflow" "$metadata" \
        "Multi-AIワークフロー開始: $workflow ($total_phases フェーズ)" \
        "coordinate_7ai_team,execute_phases,synthesize_results"
}

vibe_pipeline_done() {
    local workflow="$1"
    local status="$2"
    local total_time="$3"
    local ai_participants="$4"

    local metadata=$(cat << EOF
{
  "workflow": "$workflow",
  "status": "$status",
  "total_execution_time_ms": $total_time,
  "ai_participants": $ai_participants
}
EOF
)

    vibe_log "pipeline.done" "7ai_workflow" "$metadata" \
        "Multi-AIワークフロー完了: $workflow - $status ($ai_participants AI参加)" \
        "generate_report,update_metrics,notify_team"
}

vibe_phase_start() {
    local phase_name="$1"
    local phase_number="$2"
    local ai_count="$3"

    local metadata=$(cat << EOF
{
  "phase_name": "$phase_name",
  "phase_number": $phase_number,
  "ai_count": $ai_count,
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "phase.start" "7ai_phase_$phase_number" "$metadata" \
        "Phase $phase_number 開始: $phase_name ($ai_count AI)" \
        "execute_ai_tasks,collect_results"
}

vibe_phase_done() {
    local phase_name="$1"
    local phase_number="$2"
    local status="$3"
    local execution_time="$4"

    local metadata=$(cat << EOF
{
  "phase_name": "$phase_name",
  "phase_number": $phase_number,
  "status": "$status",
  "execution_time_ms": $execution_time
}
EOF
)

    vibe_log "phase.done" "7ai_phase_$phase_number" "$metadata" \
        "Phase $phase_number 完了: $phase_name - $status" \
        "analyze_results,proceed_next_phase"
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

    vibe_log "summary.done" "7ai_summary" "$metadata" \
        "Multi-AIサマリー生成完了: $priority 優先度" \
        "distribute_summary,track_action_items,schedule_followup"
}

# ============================================================================
# Utility Functions (3 functions)
# ============================================================================

# Sanitize user input (Security - Command Injection Prevention)
# Phase 4.5 Update: Support large prompts via file-based system
sanitize_input() {
    local input="$1"
    local max_len=102400  # Increased to 100KB for workflow prompts (Phase 4.5)

    # Length check - use sanitize_input_for_file() for very large prompts
    if [ ${#input} -gt $max_len ]; then
        log_warning "Input very large (${#input} > $max_len chars), using file-based sanitization"
        sanitize_input_for_file "$input"
        return $?
    fi

    # For large prompts (>2KB), skip dangerous character check
    # Rationale: Large prompts are typically from files/workflows, not user input
    # They will be processed via file-based system which is safe from shell expansion
    if [ ${#input} -gt 2000 ]; then
        log_info "Large prompt detected (${#input} chars), relaxing character restrictions"

        # Only check for empty input
        local trimmed="${input#"${input%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        if [ -z "$trimmed" ]; then
            log_error "Input cannot be empty"
            return 1
        fi

        # Return as-is for file-based processing
        echo "$input"
        return 0
    fi

    # Standard sanitization for small prompts (<2KB)
    # Reject dangerous characters instead of escaping
    # Security: Command injection prevention
    if [[ "$input" =~ [\;\|\$\<\>\&\!] ]]; then
        log_error "Invalid characters detected in input"
        return 1  # Reject instead of escape
    fi

    # Check for null/empty after whitespace trim
    local trimmed="${input#"${input%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [ -z "$trimmed" ]; then
        log_error "Input cannot be empty"
        return 1
    fi

    # Remove control characters (newlines, carriage returns, etc.) only for small prompts
    input="${input//$'\n'/ }"      # Newline to space
    input="${input//$'\r'/ }"      # Carriage return to space
    input="${input//$'\t'/ }"      # Tab to space

    echo "$input"
}

# Sanitize input for file-based prompts (Relaxed for Markdown content)
# Phase 1.2 Addition: File-based prompts are safe from shell expansion
sanitize_input_for_file() {
    local input="$1"

    # No length limit - files handle large content safely

    # Only block truly dangerous patterns:
    # - Null bytes (file system attacks) - NOTE: Bash cannot preserve null bytes in strings
    #   They are automatically truncated, so explicit checking is unnecessary
    # - Path traversal patterns
    # Null byte check removed: Bash strings cannot contain null bytes - they're truncated
    # at the first \0, so if the string reached this function, it doesn't have embedded nulls

    if [[ "$input" =~ \.\./\.\. ]] || [[ "$input" =~ /etc/passwd ]] || [[ "$input" =~ /bin/sh ]]; then
        log_error "Path traversal pattern detected in input"
        return 1
    fi

    # Check for empty after whitespace trim
    local trimmed="${input#"${input%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [ -z "$trimmed" ]; then
        log_error "Input cannot be empty"
        return 1
    fi

    # Allow all special characters including backticks - safe in file context
    # Markdown code blocks, shell snippets, JSON, etc. are all permitted
    echo "$input"
}

# Run command with timeout (Timeout handling)
run_with_timeout() {
    local timeout_sec=$1
    shift
    local cmd="$*"

    timeout "$timeout_sec" bash -c "$cmd" &
    local pid=$!

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 124 ]; then
        log_error "Command timed out after ${timeout_sec}s"
        return 124
    fi

    return $exit_code
}

# Show Multi-AI banner (Display function)
show_multi_ai_banner() {
    local workflow_name="${1:-Multi-AI Orchestration}"

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}║  ${CYAN}███╗   ███╗██╗   ██╗██╗  ████████╗██╗      █████╗ ██╗${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${CYAN}████╗ ████║██║   ██║██║  ╚══██╔══╝██║     ██╔══██╗██║${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${CYAN}██╔████╔██║██║   ██║██║     ██║   ██║     ███████║██║${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${CYAN}██║╚██╔╝██║██║   ██║██║     ██║   ██║     ██╔══██║██║${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${CYAN}██║ ╚═╝ ██║╚██████╔╝███████╗██║   ██║     ██║  ██║██║${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${CYAN}╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝     ╚═╝  ╚═╝╚═╝${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}║  ${MAGENTA}🤖 7-AI Orchestration Platform${NC}                         ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${GREEN}✨ ${workflow_name}${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Strategic Layer:${NC}  Claude (CTO) • Gemini (CIO) • Amp (PM)"
    echo -e "${YELLOW}Implement Layer:${NC}  Qwen (Rapid) • Droid (Enterprise) • Codex (Review)"
    echo -e "${GREEN}Integration:${NC}     Cursor (IDE)"
    echo ""
}
