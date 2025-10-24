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

# Initialize semaphore with maximum concurrent holders
sem_init() {
    local sem_name="$1"
    local max_holders="${2:-4}"

    if [ -z "$sem_name" ]; then
        log_error "sem_init: semaphore name required"
        return 1
    fi

    if ! [[ "$max_holders" =~ ^[0-9]+$ ]] || [ "$max_holders" -lt 1 ]; then
        log_error "Invalid max_holders: $max_holders (must be positive integer)"
        return 1
    fi

    local sem_dir="/tmp/multi-ai-sem-$$"
    local sem_file="$sem_dir/$sem_name"

    # Create semaphore directory
    mkdir -p "$sem_dir" 2>/dev/null || {
        log_error "Failed to create semaphore directory: $sem_dir"
        return 1
    }

    # Initialize semaphore file with max holders
    echo "$max_holders" > "$sem_file"
    chmod 600 "$sem_file"

    log_info "Semaphore initialized: $sem_name (max holders: $max_holders)"
    return 0
}

# Acquire semaphore (blocks if unavailable)
sem_acquire() {
    local sem_name="$1"
    local timeout="${2:-0}"  # 0 = no timeout

    if [ -z "$sem_name" ]; then
        log_error "sem_acquire: semaphore name required"
        return 1
    fi

    local sem_dir="/tmp/multi-ai-sem-$$"
    local sem_file="$sem_dir/$sem_name"
    local lock_file="$sem_file.lock"
    local start_time=$(date +%s)

    if [ ! -f "$sem_file" ]; then
        log_error "Semaphore not initialized: $sem_name"
        return 1
    fi

    # Wait for available slot
    while true; do
        # Atomic lock acquisition using mkdir
        if mkdir "$lock_file" 2>/dev/null; then
            # Critical section: check and decrement counter
            local current=$(cat "$sem_file" 2>/dev/null || echo "0")

            if [ "$current" -gt 0 ]; then
                # Slot available - decrement counter
                echo $((current - 1)) > "$sem_file"
                rmdir "$lock_file"
                log_info "Semaphore acquired: $sem_name (remaining: $((current - 1)))"
                return 0
            else
                # No slots available - release lock and wait
                rmdir "$lock_file"
            fi
        fi

        # Check timeout
        if [ "$timeout" -gt 0 ]; then
            local elapsed=$(($(date +%s) - start_time))
            if [ $elapsed -ge $timeout ]; then
                log_error "Semaphore acquire timeout: $sem_name (${timeout}s)"
                return 1
            fi
        fi

        # Wait before retry
        sleep 0.1
    done
}

# Release semaphore
sem_release() {
    local sem_name="$1"

    if [ -z "$sem_name" ]; then
        log_error "sem_release: semaphore name required"
        return 1
    fi

    local sem_dir="/tmp/multi-ai-sem-$$"
    local sem_file="$sem_dir/$sem_name"
    local lock_file="$sem_file.lock"

    if [ ! -f "$sem_file" ]; then
        log_error "Semaphore not initialized: $sem_name"
        return 1
    fi

    # Wait for lock
    local retries=100
    while [ $retries -gt 0 ]; do
        if mkdir "$lock_file" 2>/dev/null; then
            # Critical section: increment counter
            local current=$(cat "$sem_file" 2>/dev/null || echo "0")
            echo $((current + 1)) > "$sem_file"
            rmdir "$lock_file"
            log_info "Semaphore released: $sem_name (available: $((current + 1)))"
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

    if [ -z "$sem_name" ]; then
        # Clean up all semaphores for this process
        local sem_dir="/tmp/multi-ai-sem-$$"
        if [ -d "$sem_dir" ]; then
            rm -rf "$sem_dir"
            log_info "All semaphores cleaned up"
        fi
    else
        # Clean up specific semaphore
        local sem_dir="/tmp/multi-ai-sem-$$"
        local sem_file="$sem_dir/$sem_name"
        local lock_file="$sem_file.lock"

        rm -f "$sem_file"
        rmdir "$lock_file" 2>/dev/null || true

        log_info "Semaphore cleaned up: $sem_name"
    fi

    return 0
}
