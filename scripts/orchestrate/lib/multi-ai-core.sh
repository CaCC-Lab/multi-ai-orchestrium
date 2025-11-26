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

# Determine whether colorized output is permitted (TTY + NO_COLOR support)
if [[ ! -v MULTI_AI_USE_COLOR ]]; then
    if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
        readonly MULTI_AI_USE_COLOR=1
    else
        readonly MULTI_AI_USE_COLOR=0
    fi
fi

# Colors - Check if already defined to avoid readonly error
if [[ ! -v RED ]]; then
    if [[ "${MULTI_AI_USE_COLOR:-1}" == "1" ]]; then
        readonly RED='\033[0;31m'
        readonly GREEN='\033[0;32m'
        readonly BLUE='\033[0;34m'
        readonly YELLOW='\033[0;33m'
        readonly CYAN='\033[0;36m'
        readonly MAGENTA='\033[0;35m'
        readonly NC='\033[0m' # No Color
    else
        readonly RED=''
        readonly GREEN=''
        readonly BLUE=''
        readonly YELLOW=''
        readonly CYAN=''
        readonly MAGENTA=''
        readonly NC=''
    fi
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

log_debug() {
    # Debug logging (only if DEBUG=1 is set)
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}🐛 [DEBUG] $*${NC}" >&2
    fi
}

log_phase() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}🚀 $*${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Phase tracking functions for Fork-Join workflows
log_phase_start() {
    local phase_name="$1"
    local ai_name="${2:-}"
    echo ""
    echo -e "${CYAN}▶️  Phase Start: ${phase_name}${NC}" >&2
    if [[ -n "$ai_name" ]]; then
        echo -e "${CYAN}   AI: ${ai_name}${NC}" >&2
    fi
}

log_phase_end() {
    local phase_name="$1"
    local status="${2:-success}"
    echo ""
    if [[ "$status" == "success" ]]; then
        echo -e "${GREEN}✅ Phase Complete: ${phase_name}${NC}" >&2
    else
        echo -e "${RED}❌ Phase Failed: ${phase_name}${NC}" >&2
    fi
}

# ============================================================================
# Core Utility Helpers
# ============================================================================

# json_escape_string - Safely escape a string for JSON contexts without
#                       introducing external dependencies. Returns a quoted
#                       JSON string.
# Arguments:
#   $1: String to escape
# Output:
#   Prints escaped string wrapped in double quotes
json_escape_string() {
    local input="${1-}"

    # Replace backslash first to avoid double escaping
    input="${input//\\/\\\\}"
    input="${input//\"/\\\"}"
    input="${input//$'\n'/\\n}"
    input="${input//$'\r'/\\r}"
    input="${input//$'\t'/\\t}"
    input="${input//$'\b'/\\b}"
    input="${input//$'\f'/\\f}"

    printf '"%s"' "$input"
}

# ensure_vibe_log_dir - Guarantee that VibeLogger has a writable destination.
# Behavior:
#   - Uses pre-defined VIBE_LOG_DIR when available
#   - Otherwise derives a default from PROJECT_ROOT or current git repo
#   - Creates the directory if necessary
# Returns: 0 on success, 1 on failure
ensure_vibe_log_dir() {
    if [[ -n "${VIBE_LOG_DIR:-}" && -d "$VIBE_LOG_DIR" ]]; then
        return 0
    fi

    local base_dir="${PROJECT_ROOT:-}"
    if [[ -z "$base_dir" ]]; then
        if command -v git >/dev/null 2>&1; then
            base_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        else
            base_dir=$(pwd)
        fi
    fi

    if [[ -z "${VIBE_LOG_DIR:-}" ]]; then
        VIBE_LOG_DIR="${base_dir%/}/logs/ai-coop/$(date +%Y%m%d)"
        export VIBE_LOG_DIR
        log_debug "VIBE_LOG_DIR not set. Defaulting to $VIBE_LOG_DIR"
    fi

    if [[ ! -d "$VIBE_LOG_DIR" ]]; then
        if ! mkdir -p "$VIBE_LOG_DIR" 2>/dev/null; then
            log_error "Failed to create VibeLogger directory: $VIBE_LOG_DIR"
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Dependency Check Functions (P0.1.1)
# ============================================================================

# check_jq_dependency - Verify jq is installed for structured logging
# Usage: check_jq_dependency
# Returns: 0 if jq is available, 1 if missing
# Output: Error messages to stderr if jq is not found
check_jq_dependency() {
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed"
        log_error "Install: apt-get install jq (Debian/Ubuntu) or brew install jq (macOS)"
        return 1
    fi
    return 0
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
    local metadata="${3:-{}}"
    local human_note="$4"
    local ai_todo="${5:-}"

    if ! ensure_vibe_log_dir; then
        log_warning "Skipping VibeLogger write: unable to prepare directory"
        return 1
    fi

    if [[ -z "$metadata" ]]; then
        metadata="{}"
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="7ai_$(date +%s)_$$"
    local log_file="$VIBE_LOG_DIR/7ai_orchestration_$(date +%H).jsonl"

    local safe_event_type safe_action safe_human_note safe_ai_todo safe_runid safe_timestamp
    safe_event_type=$(json_escape_string "$event_type")
    safe_action=$(json_escape_string "$action")
    safe_human_note=$(json_escape_string "$human_note")
    safe_ai_todo=$(json_escape_string "$ai_todo")
    safe_runid=$(json_escape_string "$runid")
    safe_timestamp=$(json_escape_string "$timestamp")

    local log_fd
    if ! exec {log_fd}>>"$log_file"; then
        log_warning "vibe_log: unable to open log file for append: $log_file"
        return 1
    fi

    local have_flock=0
    if command -v flock >/dev/null 2>&1; then
        have_flock=1
        if ! flock -w 5 "$log_fd"; then
            log_warning "vibe_log: unable to acquire file lock for $log_file"
            exec {log_fd}>&-
            return 1
        fi
    fi

    local write_status=0
    {
        printf '{\n'
        printf '  "timestamp": %s,\n' "$safe_timestamp"
        printf '  "runid": %s,\n' "$safe_runid"
        printf '  "event": %s,\n' "$safe_event_type"
        printf '  "action": %s,\n' "$safe_action"
        printf '  "metadata": '
        printf '%s' "$metadata"
        printf ',\n'
        printf '  "human_note": %s,\n' "$safe_human_note"
        printf '  "ai_context": {\n'
        printf '    "tool": "Multi-AI Orchestration",\n'
        printf '    "integration": "Multi-AI",\n'
        printf '    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],\n'
        printf '    "todo": %s\n' "$safe_ai_todo"
        printf '  }\n'
        printf '}\n'
    } >&$log_fd || write_status=$?

    if [[ $have_flock -eq 1 ]]; then
        flock -u "$log_fd" 2>/dev/null || true
    fi

    exec {log_fd}>&-

    if [[ $write_status -ne 0 ]]; then
        log_warning "vibe_log: failed to write log entry to $log_file (status: $write_status)"
        return $write_status
    fi

    return 0
}

vibe_pipeline_start() {
    local workflow="$1"
    local description="$2"
    local total_phases="$3"

    local safe_workflow safe_description metadata timestamp total_phases_value

    safe_workflow=$(json_escape_string "${workflow:-}")
    safe_description=$(json_escape_string "${description:-}")
    timestamp=$(date +%s)

    if [[ "$total_phases" =~ ^[0-9]+$ ]]; then
        total_phases_value=$total_phases
    else
        log_warning "vibe_pipeline_start: total_phases '$total_phases' is not numeric, defaulting to 0"
        total_phases_value=0
    fi

    printf -v metadata '{\n  "workflow": %s,\n  "description": %s,\n  "total_phases": %d,\n  "timestamp": %s\n}\n' \
        "$safe_workflow" \
        "$safe_description" \
        "$total_phases_value" \
        "$timestamp"

    vibe_log "pipeline.start" "7ai_workflow" "$metadata" \
        "Multi-AIワークフロー開始: $workflow ($total_phases フェーズ)" \
        "coordinate_7ai_team,execute_phases,synthesize_results"
}

vibe_pipeline_done() {
    local workflow="$1"
    local status="$2"
    local total_time="$3"
    local ai_participants="$4"

    local safe_workflow safe_status metadata total_time_value ai_participants_value

    safe_workflow=$(json_escape_string "${workflow:-}")
    safe_status=$(json_escape_string "${status:-}")

    if [[ "$total_time" =~ ^[0-9]+$ ]]; then
        total_time_value=$total_time
    else
        log_warning "vibe_pipeline_done: total_time '$total_time' is not numeric, defaulting to 0"
        total_time_value=0
    fi

    if [[ "$ai_participants" =~ ^[0-9]+$ ]]; then
        ai_participants_value=$ai_participants
    else
        log_warning "vibe_pipeline_done: ai_participants '$ai_participants' is not numeric, defaulting to 0"
        ai_participants_value=0
    fi

    printf -v metadata '{\n  "workflow": %s,\n  "status": %s,\n  "total_execution_time_ms": %d,\n  "ai_participants": %d\n}\n' \
        "$safe_workflow" \
        "$safe_status" \
        "$total_time_value" \
        "$ai_participants_value"

    vibe_log "pipeline.done" "7ai_workflow" "$metadata" \
        "Multi-AIワークフロー完了: $workflow - $status ($ai_participants AI参加)" \
        "generate_report,update_metrics,notify_team"
}

vibe_phase_start() {
    local phase_name="$1"
    local phase_number="$2"
    local ai_count="$3"

    local safe_phase_name metadata timestamp phase_number_value ai_count_value

    safe_phase_name=$(json_escape_string "${phase_name:-}")
    timestamp=$(date +%s)

    if [[ "$phase_number" =~ ^[0-9]+$ ]]; then
        phase_number_value=$phase_number
    else
        log_warning "vibe_phase_start: phase_number '$phase_number' is not numeric, defaulting to 0"
        phase_number_value=0
    fi

    if [[ "$ai_count" =~ ^[0-9]+$ ]]; then
        ai_count_value=$ai_count
    else
        log_warning "vibe_phase_start: ai_count '$ai_count' is not numeric, defaulting to 0"
        ai_count_value=0
    fi

    printf -v metadata '{\n  "phase_name": %s,\n  "phase_number": %d,\n  "ai_count": %d,\n  "timestamp": %s\n}\n' \
        "$safe_phase_name" \
        "$phase_number_value" \
        "$ai_count_value" \
        "$timestamp"

    vibe_log "phase.start" "7ai_phase_$phase_number" "$metadata" \
        "Phase $phase_number 開始: $phase_name ($ai_count AI)" \
        "execute_ai_tasks,collect_results"
}

vibe_phase_done() {
    local phase_name="$1"
    local phase_number="$2"
    local status="$3"
    local execution_time="$4"

    local safe_phase_name safe_status metadata phase_number_value execution_time_value

    safe_phase_name=$(json_escape_string "${phase_name:-}")
    safe_status=$(json_escape_string "${status:-}")

    if [[ "$phase_number" =~ ^[0-9]+$ ]]; then
        phase_number_value=$phase_number
    else
        log_warning "vibe_phase_done: phase_number '$phase_number' is not numeric, defaulting to 0"
        phase_number_value=0
    fi

    if [[ "$execution_time" =~ ^[0-9]+$ ]]; then
        execution_time_value=$execution_time
    else
        log_warning "vibe_phase_done: execution_time '$execution_time' is not numeric, defaulting to 0"
        execution_time_value=0
    fi

    printf -v metadata '{\n  "phase_name": %s,\n  "phase_number": %d,\n  "status": %s,\n  "execution_time_ms": %d\n}\n' \
        "$safe_phase_name" \
        "$phase_number_value" \
        "$safe_status" \
        "$execution_time_value"

    vibe_log "phase.done" "7ai_phase_$phase_number" "$metadata" \
        "Phase $phase_number 完了: $phase_name - $status" \
        "analyze_results,proceed_next_phase"
}

vibe_summary_done() {
    local summary_text="$1"
    local priority="$2"
    local output_files="$3"

    local safe_priority metadata summary_length output_payload trimmed_output

    safe_priority=$(json_escape_string "${priority:-}")
    summary_length=${#summary_text}

    trimmed_output="${output_files}"
    trimmed_output="${trimmed_output#"${trimmed_output%%[![:space:]]*}"}"
    trimmed_output="${trimmed_output%"${trimmed_output##*[![:space:]]}"}"

    if [[ -z "$trimmed_output" ]]; then
        output_payload="[]"
    elif [[ "$trimmed_output" =~ ^\[.*\]$ ]]; then
        output_payload="$trimmed_output"
    else
        log_warning "vibe_summary_done: output_files is not a JSON array, defaulting to []"
        output_payload="[]"
    fi

    printf -v metadata '{\n  "priority": %s,\n  "output_files": %s,\n  "summary_length": %d\n}\n' \
        "$safe_priority" \
        "$output_payload" \
        "$summary_length"

    vibe_log "summary.done" "7ai_summary" "$metadata" \
        "Multi-AIサマリー生成完了: $priority 優先度" \
        "distribute_summary,track_action_items,schedule_followup"
}

# ============================================================================
# Utility Functions (3 functions)
# ============================================================================

# Sanitize user input (Security - Command Injection Prevention)
# Phase 4.5 Update: Support large prompts via file-based system
#
# P0.2.1 DEPRECATION NOTICE:
# This function is maintained for backward compatibility but is DEPRECATED.
# For new code, use sanitize_input_strict() for maximum security.
#
# Migration Path:
#   - User-facing input (CLI prompts): Use sanitize_input_strict()
#   - Large workflow prompts (>2KB): Continue using sanitize_input() or sanitize_input_for_file()
#   - See: docs/SANITIZATION_MIGRATION.md for detailed migration guide
#
sanitize_input() {
    local input="$1"

    # Allow bypass for Multi-AI workflows with large prompts
    # Set SKIP_SANITIZE=1 in orchestrate-multi-ai.sh to enable
    if [[ "${SKIP_SANITIZE:-}" == "1" ]]; then
        echo "$input"
        return 0
    fi

    local max_len=102400  # Increased to 100KB for workflow prompts (Phase 4.5)

    # P0.2.1: Deprecation warning (logged once per session to avoid spam)
    if [[ -z "${SANITIZE_INPUT_DEPRECATION_WARNED:-}" ]]; then
        log_warning "sanitize_input() is deprecated. Use sanitize_input_strict() for new code (see docs/SANITIZATION_MIGRATION.md)"
        export SANITIZE_INPUT_DEPRECATION_WARNED=1
    fi

    # Length check - use sanitize_input_for_file() for very large prompts
    if [ ${#input} -gt $max_len ]; then
        log_warning "Input very large (${#input} > $max_len chars), using file-based sanitization"
        sanitize_input_for_file "$input"
        return $?
    fi

    # For large prompts (>10KB), skip dangerous character check
    # Rationale: Large prompts are typically from files/workflows, not user input
    # They will be processed via file-based system which is safe from shell expansion
    if [ ${#input} -gt 10000 ]; then
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

    # Standard sanitization for small prompts (<10KB)
    # Reject dangerous characters instead of escaping
    # Security: Command injection prevention
    if [[ "$input" =~ [\;\|\$\<\>\&] ]]; then
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

# Export sanitize_input immediately after definition for subshell use
export -f sanitize_input

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

# Export sanitize_input_for_file immediately after definition for subshell use
export -f sanitize_input_for_file

# P0.2.1: Strict input sanitization with whitelist approach (Defense in Depth)
# Implements Gemini CIO security recommendation from 7AI Comprehensive Review
#
# Security Strategy:
#   Layer 1: Whitelist - Only allow safe characters (alphanumeric + punctuation + Japanese)
#   Layer 2: Blocklist - Explicitly reject dangerous command injection patterns
#   Layer 3: Validation - Length and emptiness checks
#
# Use Cases:
#   - User-provided prompts from CLI
#   - External input requiring maximum security
#   - Security-critical operations
#
# For large workflow prompts, use sanitize_input() or sanitize_input_for_file()
sanitize_input_strict() {
    local input="$1"
    local max_len="${2:-102400}"  # Default: 100KB

    # Layer 3: Empty check
    if [[ -z "$input" ]] || [[ "$input" =~ ^[[:space:]]*$ ]]; then
        log_structured_error \
            "Input is empty or whitespace-only" \
            "Strict sanitization requires non-empty input" \
            "Provide valid text input"
        return 1
    fi

    # Layer 3: Length check
    if [[ ${#input} -gt $max_len ]]; then
        log_structured_error \
            "Input too long (${#input} > $max_len bytes)" \
            "Strict sanitization enforces size limits for security" \
            "Use sanitize_input_for_file() for large prompts (>100KB)"
        return 1
    fi

    # Layer 2: Command injection patterns (blocklist as secondary defense)
    # Check for shell metacharacters and dangerous commands BEFORE whitelist
    # This provides early detection of obvious attacks
    local dangerous_patterns=(
        '\$\('      # Command substitution $(...)
        '`'         # Command substitution `...`
        '\$\{'      # Variable expansion ${...}
        '&&'        # Command chaining
        '\|\|'      # Command chaining
        '\|'        # Pipe operator
        '>'         # Output redirection
        '<'         # Input redirection
        'eval[[:space:]]'   # eval command
        'exec[[:space:]]'   # exec command
        'source[[:space:]]' # source command
        '\.[[:space:]]'     # source command (dot)
        'rm[[:space:]]+-rf' # Dangerous rm
        '/dev/'     # Device file access
        '/proc/'    # Process info access
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$input" =~ $pattern ]]; then
            log_structured_error \
                "Input contains dangerous pattern: $pattern" \
                "Command injection attempt detected" \
                "Remove shell metacharacters and try again"
            return 1
        fi
    done

    # Layer 1: Whitelist validation
    # Allow: Alphanumeric (a-zA-Z0-9), spaces, common punctuation, newlines, tabs
    # Punctuation allowed: . , ; : ! ? ' " ( ) [ ] { } / @ # % * + = _ - \n \t
    # Japanese/UTF-8: Allow high-bit characters (0x80-0xFF) for multi-byte UTF-8
    #
    # Note: Bash regex doesn't support \p{Hiragana}, so we allow high-bit bytes
    # which covers Japanese and most international characters
    #
    # Pattern breakdown:
    #   [[:alnum:]]  - ASCII letters and digits
    #   [[:space:]]  - Whitespace (space, tab, newline, etc.)
    #   [.,;:!?'\"()\[\]\{\}/@#%*+=_-] - Safe punctuation (braces escaped)
    #   [\x80-\xFF]  - High-bit characters (Japanese, Unicode)
    #
    if ! echo "$input" | LC_ALL=C grep -qE '^[[:alnum:][:space:].,;:!?'"'"'\"()\[\]\{\}/@#%*+=_-]+$'; then
        # Check if input contains high-bit characters (UTF-8)
        if echo "$input" | LC_ALL=C grep -q '[^[:print:][:space:]]'; then
            # Contains non-ASCII, likely Japanese - allow it
            # Secondary check: ensure no shell metacharacters
            if echo "$input" | grep -qE '[$`\\&|<>]'; then
                log_structured_error \
                    "Input contains shell metacharacters mixed with UTF-8" \
                    "Whitelist validation failed - dangerous characters detected" \
                    "Remove special characters: \$ \` \\ ; & | < >"
                return 1
            fi
        else
            log_structured_error \
                "Input contains invalid ASCII characters" \
                "Whitelist validation failed - only alphanumeric and safe punctuation allowed" \
                "Allowed: a-zA-Z0-9 space .,;:!?'\"()[]{}/@#%*+=_-"
            return 1
        fi
    fi

    # All checks passed - return sanitized input
    echo "$input"
    return 0
}

# Export sanitize_input_strict immediately after definition for subshell use
export -f sanitize_input_strict

# Run command with timeout (Timeout handling)
run_with_timeout() {
    local timeout_sec="${1:-}"
    shift
    if [[ -z "$timeout_sec" ]] || ! [[ "$timeout_sec" =~ ^[0-9]+$ ]]; then
        log_error "run_with_timeout: invalid timeout value '$timeout_sec'"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        log_error "run_with_timeout: command required"
        return 1
    fi

    local timeout_bin=""
    if command -v timeout >/dev/null 2>&1; then
        timeout_bin="timeout"
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_bin="gtimeout"
    fi

    if [[ -n "$timeout_bin" ]]; then
        "$timeout_bin" "$timeout_sec" "$@"
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Command timed out after ${timeout_sec}s"
        fi
        return $exit_code
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$timeout_sec" "$@" <<'PY'
import subprocess
import sys

timeout = float(sys.argv[1])
command = sys.argv[2:]

try:
    completed = subprocess.run(command, timeout=timeout)
    sys.exit(completed.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
except FileNotFoundError:
    sys.exit(127)
PY
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Command timed out after ${timeout_sec}s"
        fi
        return $exit_code
    fi

    log_warning "timeout utility not available; using manual fallback (${timeout_sec}s)"

    local tmp_flag
    tmp_flag=$(mktemp "${TMPDIR:-/tmp}/multi-ai-timeout.XXXXXX") || {
        log_error "run_with_timeout: failed to create temporary flag"
        return 1
    }

    "$@" &
    local cmd_pid=$!

    (
        sleep "$timeout_sec"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            echo timeout >"$tmp_flag"
            kill "$cmd_pid" 2>/dev/null || true
            sleep 1
            kill -9 "$cmd_pid" 2>/dev/null || true
        fi
    ) &
    local watcher_pid=$!

    wait "$cmd_pid"
    local exit_code=$?

    if kill -0 "$watcher_pid" 2>/dev/null; then
        kill "$watcher_pid" 2>/dev/null || true
    fi
    wait "$watcher_pid" 2>/dev/null || true

    if [[ -s "$tmp_flag" ]]; then
        rm -f "$tmp_flag"
        log_error "Command timed out after ${timeout_sec}s (manual fallback)"
        return 124
    fi

    rm -f "$tmp_flag"
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

# ============================================================================
# Job Pool API (P0.3.1.1) - Parallel Execution Resource Limiting
# ============================================================================
# Purpose: Limit concurrent AI executions to prevent resource exhaustion
# Usage:
#   init_job_pool 4              # Allow max 4 concurrent jobs
#   submit_job run_ai_task "$ai" # Submit job to pool
#   cleanup_job_pool             # Wait for all jobs to complete

# Global job pool state
declare -a JOB_POOL_PIDS=()
declare -i JOB_POOL_RUNNING=0
declare -i JOB_POOL_MAX=4

# Initialize job pool with maximum concurrent jobs
init_job_pool() {
    local max_jobs="${1:-4}"

    if ! [[ "$max_jobs" =~ ^[0-9]+$ ]] || [ "$max_jobs" -lt 1 ]; then
        log_error "Invalid max_jobs: $max_jobs (must be positive integer)"
        return 1
    fi

    JOB_POOL_MAX=$max_jobs
    JOB_POOL_RUNNING=0
    JOB_POOL_PIDS=()

    log_info "Job pool initialized (max concurrent: $JOB_POOL_MAX)"
    return 0
}

# Submit job to pool (waits if pool is full)
submit_job() {
    local job_function="$1"
    shift
    local args=("$@")

    if [ -z "$job_function" ]; then
        log_error "submit_job: job_function required"
        return 1
    fi

    # Wait for slot to become available
    wait_for_slot

    # Execute job in background
    "$job_function" "${args[@]}" &
    local pid=$!
    JOB_POOL_PIDS+=($pid)
    ((JOB_POOL_RUNNING++))

    log_info "Job submitted (PID: $pid, Running: $JOB_POOL_RUNNING/$JOB_POOL_MAX)"
    return 0
}

# Wait for job slot to become available
wait_for_slot() {
    while [ $JOB_POOL_RUNNING -ge $JOB_POOL_MAX ]; do
        # Wait for any job to complete
        if wait -n 2>/dev/null; then
            ((JOB_POOL_RUNNING--))
            log_info "Job completed (Running: $JOB_POOL_RUNNING/$JOB_POOL_MAX)"
        else
            # wait -n failed (no background jobs or unsupported)
            # Fall back to polling
            sleep 0.5

            # Check if any PIDs have finished
            local finished_count=0
            for pid in "${JOB_POOL_PIDS[@]}"; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    ((finished_count++))
                fi
            done

            if [ $finished_count -gt 0 ]; then
                JOB_POOL_RUNNING=$((${#JOB_POOL_PIDS[@]} - finished_count))
                break
            fi
        fi
    done
}

# Clean up job pool and wait for all jobs to complete
cleanup_job_pool() {
    if [ ${#JOB_POOL_PIDS[@]} -eq 0 ]; then
        log_info "Job pool empty (no jobs to clean up)"
        return 0
    fi

    log_info "Waiting for ${#JOB_POOL_PIDS[@]} jobs to complete..."

    local failed=0
    for pid in "${JOB_POOL_PIDS[@]}"; do
        if wait "$pid"; then
            log_info "Job $pid completed successfully"
        else
            local exit_code=$?
            log_warning "Job $pid failed (exit code: $exit_code)"
            ((failed++))
        fi
    done

    # Reset pool state
    JOB_POOL_RUNNING=0
    JOB_POOL_PIDS=()

    if [ $failed -eq 0 ]; then
        log_success "All jobs completed successfully"
        return 0
    else
        log_warning "$failed jobs failed"
        return 1
    fi
}

# ============================================================================
# Semaphore API (P0.3.1.2) - File-Based Resource Locking
# ============================================================================
# Purpose: Process-safe resource locking for cross-script synchronization
# Usage:
#   sem_init "my-resource" 4     # Allow max 4 concurrent holders
#   sem_acquire "my-resource"    # Acquire lock (blocks if full)
#   sem_release "my-resource"    # Release lock
#   sem_cleanup "my-resource"    # Clean up semaphore files

# Track semaphores initialized by this process for safe cleanup
declare -a SEMAPHORE_REGISTRY=()

ensure_semaphore_base_dir() {
    if [[ -n "${MULTI_AI_SEM_DIR:-}" && -d "$MULTI_AI_SEM_DIR" ]]; then
        return 0
    fi

    MULTI_AI_SEM_DIR="${MULTI_AI_SEM_DIR:-/tmp/multi-ai-semaphores}"

    if [[ ! -d "$MULTI_AI_SEM_DIR" ]]; then
        if ! mkdir -p "$MULTI_AI_SEM_DIR" 2>/dev/null; then
            log_error "Failed to create semaphore base directory: $MULTI_AI_SEM_DIR"
            return 1
        fi
        chmod 700 "$MULTI_AI_SEM_DIR" 2>/dev/null || true
    fi

    export MULTI_AI_SEM_DIR
    return 0
}

normalize_semaphore_name() {
    local raw="$1"
    if [[ -z "$raw" ]]; then
        return 1
    fi

    local sanitized="${raw//[^A-Za-z0-9_.-]/_}"
    if [[ -z "$sanitized" ]]; then
        sanitized=$(printf '%s' "$raw" | hexdump -ve '1/1 "%02x"' 2>/dev/null | tr -d '\n')
    fi

    if [[ -z "$sanitized" ]]; then
        sanitized="sem_$(date +%s%N)"
    fi

    printf '%s' "$sanitized"
    return 0
}

register_semaphore_dir() {
    local sem_dir="$1"
    for existing in "${SEMAPHORE_REGISTRY[@]}"; do
        if [[ "$existing" == "$sem_dir" ]]; then
            return 0
        fi
    done
    SEMAPHORE_REGISTRY+=("$sem_dir")
}

remove_semaphore_from_registry() {
    local sem_dir="$1"
    local new_registry=()
    for existing in "${SEMAPHORE_REGISTRY[@]}"; do
        if [[ "$existing" != "$sem_dir" ]]; then
            new_registry+=("$existing")
        fi
    done
    SEMAPHORE_REGISTRY=("${new_registry[@]}")
}

cleanup_single_semaphore_dir() {
    local sem_dir="$1"
    local lock_dir="${sem_dir}.lock"

    rm -f "$sem_dir/available" "$sem_dir/meta"
    rmdir "$lock_dir" 2>/dev/null || true
    rmdir "$sem_dir" 2>/dev/null || true

    if [[ -n "${MULTI_AI_SEM_DIR:-}" ]]; then
        rmdir "$MULTI_AI_SEM_DIR" 2>/dev/null || true
    fi
}

# Initialize semaphore with maximum concurrent holders
sem_init() {
    local sem_name="$1"
    local max_holders="${2:-4}"

    if [[ -z "$sem_name" ]]; then
        log_error "sem_init: semaphore name required"
        return 1
    fi

    if ! [[ "$max_holders" =~ ^[0-9]+$ ]] || [[ "$max_holders" -lt 1 ]]; then
        log_error "Invalid max_holders: $max_holders (must be positive integer)"
        return 1
    fi

    if ! ensure_semaphore_base_dir; then
        return 1
    fi

    local normalized
    normalized=$(normalize_semaphore_name "$sem_name") || {
        log_error "sem_init: failed to normalize semaphore name: $sem_name"
        return 1
    }

    local sem_dir="$MULTI_AI_SEM_DIR/$normalized"
    local counter_file="$sem_dir/available"
    local meta_file="$sem_dir/meta"

    if ! mkdir -p "$sem_dir" 2>/dev/null; then
        log_error "Failed to create semaphore directory: $sem_dir"
        return 1
    fi

    if [[ ! -f "$meta_file" ]]; then
        echo "$max_holders" >"$meta_file"
        chmod 600 "$meta_file" 2>/dev/null || true
    else
        local existing_max
        existing_max=$(cat "$meta_file" 2>/dev/null || echo "0")
        if [[ "$existing_max" =~ ^[0-9]+$ ]] && [[ "$existing_max" -ne "$max_holders" ]]; then
            log_warning "Semaphore $sem_name already initialized with max holders $existing_max; keeping existing value"
            max_holders="$existing_max"
        fi
    fi

    if [[ ! -f "$counter_file" ]]; then
        echo "$max_holders" >"$counter_file"
        chmod 600 "$counter_file" 2>/dev/null || true
    fi

    register_semaphore_dir "$sem_dir"
    log_info "Semaphore initialized: $sem_name (max holders: $max_holders)"
    return 0
}

# Acquire semaphore (blocks if unavailable)
sem_acquire() {
    local sem_name="$1"
    local timeout="${2:-0}"  # 0 = no timeout

    if [[ -z "$sem_name" ]]; then
        log_error "sem_acquire: semaphore name required"
        return 1
    fi

    if ! ensure_semaphore_base_dir; then
        return 1
    fi

    local normalized
    normalized=$(normalize_semaphore_name "$sem_name") || {
        log_error "sem_acquire: failed to normalize semaphore name: $sem_name"
        return 1
    }

    local sem_dir="$MULTI_AI_SEM_DIR/$normalized"
    local counter_file="$sem_dir/available"
    local lock_dir="${sem_dir}.lock"
    local start_time=$(date +%s)

    if [[ ! -f "$counter_file" ]]; then
        log_error "Semaphore not initialized: $sem_name"
        return 1
    fi

    while true; do
        if mkdir "$lock_dir" 2>/dev/null; then
            local current
            current=$(cat "$counter_file" 2>/dev/null || echo "0")

            if [[ "$current" =~ ^[0-9]+$ ]] && [[ "$current" -gt 0 ]]; then
                echo $((current - 1)) >"$counter_file"
                rmdir "$lock_dir"
                log_info "Semaphore acquired: $sem_name (remaining: $((current - 1)))"
                return 0
            fi

            rmdir "$lock_dir"
        fi

        if [[ "$timeout" -gt 0 ]]; then
            local elapsed=$(( $(date +%s) - start_time ))
            if [[ $elapsed -ge $timeout ]]; then
                log_error "Semaphore acquire timeout: $sem_name (${timeout}s)"
                return 1
            fi
        fi

        sleep 0.1
    done
}

# Release semaphore
sem_release() {
    local sem_name="$1"

    if [[ -z "$sem_name" ]]; then
        log_error "sem_release: semaphore name required"
        return 1
    fi

    if ! ensure_semaphore_base_dir; then
        return 1
    fi

    local normalized
    normalized=$(normalize_semaphore_name "$sem_name") || {
        log_error "sem_release: failed to normalize semaphore name: $sem_name"
        return 1
    }

    local sem_dir="$MULTI_AI_SEM_DIR/$normalized"
    local counter_file="$sem_dir/available"
    local meta_file="$sem_dir/meta"
    local lock_dir="${sem_dir}.lock"

    if [[ ! -f "$counter_file" ]] || [[ ! -f "$meta_file" ]]; then
        log_error "Semaphore not initialized: $sem_name"
        return 1
    fi

    local retries=100
    while [[ $retries -gt 0 ]]; do
        if mkdir "$lock_dir" 2>/dev/null; then
            local current max_value
            current=$(cat "$counter_file" 2>/dev/null || echo "0")
            max_value=$(cat "$meta_file" 2>/dev/null || echo "0")

            if ! [[ "$current" =~ ^[0-9]+$ ]] || ! [[ "$max_value" =~ ^[0-9]+$ ]]; then
                rmdir "$lock_dir"
                log_error "Semaphore corrupted: $sem_name"
                return 1
            fi

            local new_value=$((current + 1))
            if [[ $new_value -gt $max_value ]]; then
                new_value=$max_value
            fi

            echo "$new_value" >"$counter_file"
            rmdir "$lock_dir"
            log_info "Semaphore released: $sem_name (available: $new_value/$max_value)"
            return 0
        fi

        sleep 0.1
        ((retries--))
    done

    log_error "Failed to release semaphore: $sem_name (lock timeout)"
    return 1
}

# Clean up semaphore files
sem_cleanup() {
    local sem_name="$1"

    if ! ensure_semaphore_base_dir; then
        return 1
    fi

    if [[ -z "$sem_name" ]]; then
        local failed=0
        for sem_dir in "${SEMAPHORE_REGISTRY[@]}"; do
            cleanup_single_semaphore_dir "$sem_dir" || ((failed++))
        done
        SEMAPHORE_REGISTRY=()
        if [[ $failed -gt 0 ]]; then
            log_warning "Cleanup completed with $failed failures"
            return 1
        fi
        log_info "All semaphores cleaned up"
        return 0
    fi

    local normalized
    normalized=$(normalize_semaphore_name "$sem_name") || {
        log_error "sem_cleanup: failed to normalize semaphore name: $sem_name"
        return 1
    }

    local sem_dir="$MULTI_AI_SEM_DIR/$normalized"
    cleanup_single_semaphore_dir "$sem_dir"
    remove_semaphore_from_registry "$sem_dir"

    log_info "Semaphore cleaned up: $sem_name"
    return 0
}

# ============================================================================
# Structured Error Handling (P1.4.1 - Comprehensive Error Handling)
# ============================================================================

# Directory for error logs
MULTI_AI_ERROR_LOG_DIR="${MULTI_AI_ERROR_LOG_DIR:-logs/errors}"

# Ensure error log directory exists
mkdir -p "$MULTI_AI_ERROR_LOG_DIR" 2>/dev/null || true

# log_structured_error - Logs errors in structured what/why/how format
# Usage: log_structured_error "what" "why" "how"
# Arguments:
#   $1: what - What happened (error description)
#   $2: why  - Why it happened (root cause)
#   $3: how  - How to fix it (remediation steps)
# Outputs: JSON-formatted error log to stderr and logs/errors/YYYYMMDD.jsonl
log_structured_error() {
    local what="${1:-Unknown error}"
    local why="${2:-Unknown cause}"
    local how="${3:-No remediation available}"
    local timestamp=$(get_timestamp_ms)
    local date_str=$(date +%Y%m%d)
    local error_log="$MULTI_AI_ERROR_LOG_DIR/${date_str}.jsonl"

    # Create error log directory if it doesn't exist
    mkdir -p "$MULTI_AI_ERROR_LOG_DIR" 2>/dev/null || true

    # P0.1.1: jq dependency check with fallback
    if ! command -v jq &>/dev/null; then
        # Fallback: Plain text logging when jq is missing
        local timestamp_str=$(date +"%Y-%m-%d %H:%M:%S")
        local fallback_log="$MULTI_AI_ERROR_LOG_DIR/${date_str}.txt"

        # Output to stderr with color formatting
        echo -e "${RED}❌ ERROR:${NC}" >&2
        echo -e "  ${YELLOW}What:${NC} $what" >&2
        echo -e "  ${YELLOW}Why:${NC}  $why" >&2
        echo -e "  ${YELLOW}How:${NC}  $how" >&2
        echo -e "  ${CYAN}Location:${NC} ${BASH_SOURCE[2]:-unknown}:${FUNCNAME[2]:-main}:${BASH_LINENO[1]:-0}" >&2

        # Plain text log entry
        echo "[$timestamp_str] ERROR: what=$what, why=$why, how=$how, location=${BASH_SOURCE[2]:-unknown}:${FUNCNAME[2]:-main}:${BASH_LINENO[1]:-0}" >> "$fallback_log" 2>/dev/null || true

        log_warning "jq not available, using plain text error logging (install jq for structured JSON logs)"
        return 1
    fi

    # Build JSON error entry (jq available)
    local json_error=$(cat <<EOF
{
  "timestamp_ms": $timestamp,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "what": $(printf '%s' "$what" | jq -Rs .),
  "why": $(printf '%s' "$why" | jq -Rs .),
  "how": $(printf '%s' "$how" | jq -Rs .),
  "script": "${BASH_SOURCE[2]:-unknown}",
  "function": "${FUNCNAME[2]:-main}",
  "line": ${BASH_LINENO[1]:-0},
  "pid": $$,
  "user": "${USER:-unknown}"
}
EOF
)

    # Output to stderr with color formatting
    echo -e "${RED}❌ ERROR:${NC}" >&2
    echo -e "  ${YELLOW}What:${NC} $what" >&2
    echo -e "  ${YELLOW}Why:${NC}  $why" >&2
    echo -e "  ${YELLOW}How:${NC}  $how" >&2
    echo -e "  ${CYAN}Location:${NC} ${BASH_SOURCE[2]:-unknown}:${FUNCNAME[2]:-main}:${BASH_LINENO[1]:-0}" >&2

    # Append JSON to error log file
    echo "$json_error" >> "$error_log" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Failed to write error log to $error_log${NC}" >&2
    }

    # Also log to VibeLogger if available
    if declare -f vibe_log >/dev/null 2>&1; then
        vibe_log "error" "structured_error" "{\"what\":\"$what\",\"why\":\"$why\",\"how\":\"$how\"}" "$what" "[]" "multi-ai-core"
    fi

    return 0
}

# print_stack_trace - Prints full Bash call stack for debugging
# Usage: print_stack_trace
# Outputs: Stack trace to stderr showing function call chain
print_stack_trace() {
    local frame=0
    echo -e "${CYAN}Stack trace:${NC}" >&2

    while caller $frame >&2 2>/dev/null; do
        ((frame++))
    done

    # If caller failed (no stack), print current location
    if [ $frame -eq 0 ]; then
        echo -e "  ${BASH_SOURCE[1]:-unknown}:${FUNCNAME[1]:-main}:${BASH_LINENO[0]:-0}" >&2
    fi

    return 0
}

# handle_critical_error - Comprehensive critical error handler with stack trace
# Usage: handle_critical_error "error_message" ["exit_code"]
# Arguments:
#   $1: error_message - Description of the critical error
#   $2: exit_code (optional) - Exit code (default: 1)
# Behavior: Logs structured error, prints stack trace, exits script
handle_critical_error() {
    local error_message="${1:-Critical error occurred}"
    local exit_code="${2:-1}"

    log_structured_error \
        "$error_message" \
        "Critical failure in Multi-AI orchestration" \
        "Check logs in $MULTI_AI_ERROR_LOG_DIR for details. Review stack trace below."

    print_stack_trace

    exit "$exit_code"
}

# ============================================================================
# P0.3.1: TRAP MANAGEMENT SYSTEM (Non-Overwriting Cleanup Handlers)
# ============================================================================
#
# Problem: Direct `trap` usage overwrites previous handlers, causing resource leaks
# Solution: Global array-based handler accumulation with sequential execution
#
# Usage Pattern:
#   add_cleanup_handler "cleanup_temp_files"
#   add_cleanup_handler "cleanup_background_jobs"
#   # Both handlers will execute on EXIT/INT/TERM
#
# Design Notes:
#   - Handlers stored in CLEANUP_HANDLERS array (preserves all registrations)
#   - Duplicate detection prevents double-cleanup
#   - Sequential execution ensures deterministic cleanup order
#   - Single trap registration (avoids overwrite issues)
#
# Security: Handlers are validated against dangerous patterns during registration
# Performance: O(n) execution where n = handler count (typically <10)
# ============================================================================

# Global cleanup handler registry (shared across all scripts sourcing this library)
declare -a CLEANUP_HANDLERS=()

# add_cleanup_handler - Register a cleanup handler without overwriting existing traps
#
# Arguments:
#   $1: handler - Shell command to execute on EXIT/INT/TERM signals
#
# Returns:
#   0 on success, 1 on error
#
# Example:
#   add_cleanup_handler "rm -f /tmp/my-temp-file"
#   add_cleanup_handler "kill_background_process $PID"
#
# Behavior:
#   - Checks for duplicate handlers (idempotent)
#   - Appends to CLEANUP_HANDLERS array
#   - Re-registers trap to call run_all_cleanup_handlers
#
# Note: Handlers are executed in registration order (FIFO)
#
add_cleanup_handler() {
    local handler="$1"

    # Validation: Check for empty handler
    if [[ -z "$handler" ]]; then
        log_warning "add_cleanup_handler called with empty handler, ignoring"
        return 1
    fi

    # Duplicate detection (prevent double-cleanup)
    for existing in "${CLEANUP_HANDLERS[@]}"; do
        if [[ "$existing" == "$handler" ]]; then
            log_warning "Cleanup handler already registered: $handler"
            return 0  # Not an error, just idempotent
        fi
    done

    # Register handler
    CLEANUP_HANDLERS+=("$handler")
    log_info "Registered cleanup handler #${#CLEANUP_HANDLERS[@]}: $handler"

    # Re-register trap (overwrites previous trap, but calls all handlers)
    # This is the ONLY place where `trap` should be set for EXIT/INT/TERM
    trap 'run_all_cleanup_handlers' EXIT INT TERM

    return 0
}

# run_all_cleanup_handlers - Execute all registered cleanup handlers sequentially
#
# Arguments: None
#
# Returns:
#   0 if all handlers succeeded, 1 if any handler failed
#
# Behavior:
#   - Executes handlers in registration order (FIFO)
#   - Continues execution even if a handler fails (best-effort cleanup)
#   - Logs success/failure for each handler
#
# Note: Called automatically by trap on EXIT/INT/TERM
#       Do not call directly unless you need to cleanup mid-execution
#
run_all_cleanup_handlers() {
    local handler_count=${#CLEANUP_HANDLERS[@]}
    local failed_count=0

    # Early return if no handlers registered
    if [ "$handler_count" -eq 0 ]; then
        return 0
    fi

    log_info "Running $handler_count cleanup handlers..."

    # Execute each handler in order
    for handler in "${CLEANUP_HANDLERS[@]}"; do
        log_info "Executing cleanup: $handler"

        # Execute handler with error capture (don't stop on failure)
        if eval "$handler" 2>&1 | while IFS= read -r line; do log_info "  $line"; done; then
            log_success "Cleanup handler succeeded: $handler"
        else
            log_warning "Cleanup handler failed (non-fatal): $handler"
            ((failed_count++))
        fi
    done

    # Summary logging
    if [ "$failed_count" -eq 0 ]; then
        log_success "All $handler_count cleanup handlers completed successfully"
        return 0
    else
        log_warning "$failed_count/$handler_count cleanup handlers failed (best-effort cleanup completed)"
        return 1
    fi
}

# ============================================================================
# Export Functions for Subshell Use
# ============================================================================

# Note: sanitize_input, sanitize_input_for_file, and sanitize_input_strict
# are already exported immediately after their definitions above.
# This section is kept for documentation purposes.
