#!/usr/bin/env bash
# vibe-logger-lib.sh - Common VibeLogger library for 7AI system
# Version: 1.0.0
# Purpose: Provide AI-Native structured logging for all scripts
# Reference: scripts/orchestrate/orchestrate-7ai.sh (lines 50-225)

set -euo pipefail

# ============================================================================
# Vibe Logger Setup
# ============================================================================

# Detect project root (support various calling contexts)
if [[ -n "${PROJECT_ROOT:-}" ]]; then
    VIBE_PROJECT_ROOT="$PROJECT_ROOT"
elif [[ -f "$(pwd)/CLAUDE.md" ]]; then
    VIBE_PROJECT_ROOT="$(pwd)"
else
    # Traverse up to find project root
    VIBE_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Default log directory (can be overridden)
VIBE_LOG_DIR="${VIBE_LOG_DIR:-$VIBE_PROJECT_ROOT/logs/vibe/$(date +%Y%m%d)}"
mkdir -p "$VIBE_LOG_DIR"

# ============================================================================
# Cross-platform Timestamp Helper
# ============================================================================

# Cross-platform millisecond timestamp (macOS/BSD/GNU compatible)
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
# Core VibeLogger Functions
# ============================================================================

# Core logging function
# Usage: vibe_log <event_type> <action> <metadata_json> <human_note> [ai_todo] [tool_name]
vibe_log() {
    local event_type="$1"
    local action="$2"
    local metadata="$3"
    local human_note="$4"
    local ai_todo="${5:-}"
    local tool_name="${6:-Generic}"

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="${tool_name}_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/${tool_name}_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "$tool_name",
    "integration": "7AI",
    "todo": "$ai_todo"
  }
}
EOF
}

# ============================================================================
# Wrapper Script Helper Functions
# ============================================================================

# Log wrapper execution start
# Usage: vibe_wrapper_start <wrapper_name> <prompt> <timeout>
vibe_wrapper_start() {
    local wrapper_name="$1"
    local prompt="$2"
    local timeout="$3"

    local metadata
    metadata=$(cat << EOF
{
  "wrapper": "$wrapper_name",
  "prompt_length": ${#prompt},
  "timeout": "$timeout",
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "wrapper.start" "${wrapper_name}_execution" "$metadata" \
        "${wrapper_name} 実行開始: タイムアウト $timeout" \
        "execute_cli,capture_output,handle_errors" \
        "$wrapper_name"
}

# Log wrapper execution completion
# Usage: vibe_wrapper_done <wrapper_name> <status> <execution_time_ms> <exit_code>
vibe_wrapper_done() {
    local wrapper_name="$1"
    local status="$2"
    local execution_time="$3"
    local exit_code="$4"

    local metadata
    metadata=$(cat << EOF
{
  "wrapper": "$wrapper_name",
  "status": "$status",
  "execution_time_ms": $execution_time,
  "exit_code": $exit_code
}
EOF
)

    vibe_log "wrapper.done" "${wrapper_name}_execution" "$metadata" \
        "${wrapper_name} 実行完了: $status (exit: $exit_code)" \
        "analyze_output,update_metrics,handle_errors" \
        "$wrapper_name"
}

# Log wrapper configuration change
# Usage: vibe_wrapper_config <wrapper_name> <config_key> <config_value> <note>
vibe_wrapper_config() {
    local wrapper_name="$1"
    local config_key="$2"
    local config_value="$3"
    local note="$4"

    local metadata
    metadata=$(cat << EOF
{
  "config_key": "$config_key",
  "config_value": "$config_value"
}
EOF
)

    vibe_log "wrapper.config" "${wrapper_name}_config" "$metadata" \
        "$note" \
        "validate_config,apply_settings" \
        "$wrapper_name"
}

# ============================================================================
# TDD Script Helper Functions
# ============================================================================

# Log TDD phase start
# Usage: vibe_tdd_phase_start <phase_name> <phase_number> <test_count>
vibe_tdd_phase_start() {
    local phase_name="$1"
    local phase_number="$2"
    local test_count="$3"

    local metadata
    metadata=$(cat << EOF
{
  "phase_name": "$phase_name",
  "phase_number": $phase_number,
  "test_count": $test_count,
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "tdd.phase.start" "tdd_phase_$phase_number" "$metadata" \
        "TDD Phase $phase_number 開始: $phase_name ($test_count テスト)" \
        "run_tests,analyze_failures,implement_fixes" \
        "TDD-7AI"
}

# Log TDD phase completion
# Usage: vibe_tdd_phase_done <phase_name> <phase_number> <passed> <failed> <execution_time_ms>
vibe_tdd_phase_done() {
    local phase_name="$1"
    local phase_number="$2"
    local passed="$3"
    local failed="$4"
    local execution_time="$5"

    local metadata
    metadata=$(cat << EOF
{
  "phase_name": "$phase_name",
  "phase_number": $phase_number,
  "passed": $passed,
  "failed": $failed,
  "execution_time_ms": $execution_time
}
EOF
)

    vibe_log "tdd.phase.done" "tdd_phase_$phase_number" "$metadata" \
        "TDD Phase $phase_number 完了: $passed 成功, $failed 失敗" \
        "review_results,proceed_next_phase,report_metrics" \
        "TDD-7AI"
}

# Log individual test result
# Usage: vibe_tdd_test_result <test_name> <result> <duration_ms> [error_msg]
vibe_tdd_test_result() {
    local test_name="$1"
    local result="$2"  # pass/fail
    local duration="$3"
    local error_msg="${4:-}"

    # Escape quotes in error message
    error_msg="${error_msg//\"/\\\"}"

    local metadata
    metadata=$(cat << EOF
{
  "test_name": "$test_name",
  "result": "$result",
  "duration_ms": $duration,
  "error": "$error_msg"
}
EOF
)

    vibe_log "tdd.test.result" "test_execution" "$metadata" \
        "テスト '$test_name': $result" \
        "analyze_failure,fix_code,rerun_test" \
        "TDD-7AI"
}

# Log TDD cycle start (entire workflow)
# Usage: vibe_tdd_cycle_start <cycle_name> <total_phases>
vibe_tdd_cycle_start() {
    local cycle_name="$1"
    local total_phases="$2"

    local metadata
    metadata=$(cat << EOF
{
  "cycle_name": "$cycle_name",
  "total_phases": $total_phases,
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "tdd.cycle.start" "tdd_workflow" "$metadata" \
        "TDD サイクル開始: $cycle_name ($total_phases フェーズ)" \
        "initialize_tests,setup_environment,begin_phases" \
        "TDD-7AI"
}

# Log TDD cycle completion
# Usage: vibe_tdd_cycle_done <cycle_name> <status> <total_time_ms> <total_tests> <passed> <failed>
vibe_tdd_cycle_done() {
    local cycle_name="$1"
    local status="$2"
    local total_time="$3"
    local total_tests="$4"
    local passed="$5"
    local failed="$6"

    # Calculate success rate with division by zero protection and guaranteed 2 decimal places
    local success_rate="0.00"
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(echo "scale=2; $passed * 100 / $total_tests" | bc)
        # Ensure exactly 2 decimal places (bc may omit trailing zeros)
        success_rate=$(printf "%.2f" "$success_rate")
    fi

    local metadata
    metadata=$(cat << EOF
{
  "cycle_name": "$cycle_name",
  "status": "$status",
  "total_execution_time_ms": $total_time,
  "total_tests": $total_tests,
  "passed": $passed,
  "failed": $failed,
  "success_rate": "$success_rate"
}
EOF
)

    vibe_log "tdd.cycle.done" "tdd_workflow" "$metadata" \
        "TDD サイクル完了: $cycle_name - $status ($passed/$total_tests 成功)" \
        "generate_report,archive_results,cleanup" \
        "TDD-7AI"
}

# ============================================================================
# Pipeline/Orchestration Helper Functions
# ============================================================================

# Log pipeline start (for orchestration scripts)
# Usage: vibe_pipeline_start <workflow_name> <description> <total_phases>
vibe_pipeline_start() {
    local workflow="$1"
    local description="$2"
    local total_phases="$3"

    local metadata
    metadata=$(cat << EOF
{
  "workflow": "$workflow",
  "description": "$description",
  "total_phases": $total_phases,
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "pipeline.start" "7ai_workflow" "$metadata" \
        "7AIワークフロー開始: $workflow ($total_phases フェーズ)" \
        "coordinate_7ai_team,execute_phases,synthesize_results" \
        "7AI-Orchestration"
}

# Log pipeline completion
# Usage: vibe_pipeline_done <workflow_name> <status> <total_time_ms> <ai_participants>
vibe_pipeline_done() {
    local workflow="$1"
    local status="$2"
    local total_time="$3"
    local ai_participants="$4"

    local metadata
    metadata=$(cat << EOF
{
  "workflow": "$workflow",
  "status": "$status",
  "total_execution_time_ms": $total_time,
  "ai_participants": $ai_participants
}
EOF
)

    vibe_log "pipeline.done" "7ai_workflow" "$metadata" \
        "7AIワークフロー完了: $workflow - $status ($ai_participants AI参加)" \
        "generate_report,update_metrics,notify_team" \
        "7AI-Orchestration"
}

# ============================================================================
# File-Based Prompt System Helper Functions (Phase 4.4)
# ============================================================================

# Log file-based prompt routing decision
# Usage: vibe_file_prompt_start <ai_name> <prompt_size> <threshold> <mode>
vibe_file_prompt_start() {
    local ai_name="$1"
    local prompt_size="$2"
    local threshold="$3"
    local mode="$4"  # "file" | "command-line"

    local metadata
    metadata=$(cat << EOF
{
  "ai_name": "$ai_name",
  "prompt_size": $prompt_size,
  "threshold": $threshold,
  "routing_mode": "$mode",
  "timestamp": "$(date +%s)"
}
EOF
)

    vibe_log "file_prompt.start" "prompt_routing" "$metadata" \
        "ファイルベースプロンプト開始: $ai_name ($prompt_size bytes, mode: $mode)" \
        "create_temp_file,set_permissions,route_input" \
        "File-Prompt-System"
}

# Log file-based prompt completion
# Usage: vibe_file_prompt_done <ai_name> <prompt_size> <mode> <duration_ms> <exit_code>
vibe_file_prompt_done() {
    local ai_name="$1"
    local prompt_size="$2"
    local mode="$3"
    local duration="$4"
    local exit_code="$5"

    local metadata
    metadata=$(cat << EOF
{
  "ai_name": "$ai_name",
  "prompt_size": $prompt_size,
  "routing_mode": "$mode",
  "duration_ms": $duration,
  "exit_code": $exit_code
}
EOF
)

    vibe_log "file_prompt.done" "prompt_routing" "$metadata" \
        "ファイルベースプロンプト完了: $ai_name ($prompt_size bytes, exit: $exit_code)" \
        "cleanup_temp_file,analyze_performance,log_metrics" \
        "File-Prompt-System"
}

# Log file creation event
# Usage: vibe_file_created <ai_name> <file_path> <file_size>
vibe_file_created() {
    local ai_name="$1"
    local file_path="$2"
    local file_size="$3"

    local metadata
    metadata=$(cat << EOF
{
  "ai_name": "$ai_name",
  "file_path": "$file_path",
  "file_size": $file_size,
  "permissions": "600"
}
EOF
)

    vibe_log "file_prompt.created" "temp_file_creation" "$metadata" \
        "一時ファイル作成: $file_path ($file_size bytes)" \
        "validate_permissions,track_file,schedule_cleanup" \
        "File-Prompt-System"
}

# Log file cleanup event
# Usage: vibe_file_cleanup <ai_name> <file_path> <success>
vibe_file_cleanup() {
    local ai_name="$1"
    local file_path="$2"
    local success="$3"  # "success" | "failed"

    local metadata
    metadata=$(cat << EOF
{
  "ai_name": "$ai_name",
  "file_path": "$file_path",
  "cleanup_status": "$success"
}
EOF
)

    vibe_log "file_prompt.cleanup" "temp_file_cleanup" "$metadata" \
        "一時ファイルクリーンアップ: $file_path ($success)" \
        "verify_deletion,update_metrics" \
        "File-Prompt-System"
}

# Log prompt size threshold analysis
# Usage: vibe_prompt_size_analysis <ai_name> <prompt_size> <threshold> <decision>
vibe_prompt_size_analysis() {
    local ai_name="$1"
    local prompt_size="$2"
    local threshold="$3"
    local decision="$4"  # "use_file" | "use_command_line"

    local metadata
    metadata=$(cat << EOF
{
  "ai_name": "$ai_name",
  "prompt_size": $prompt_size,
  "threshold": $threshold,
  "decision": "$decision",
  "size_ratio": $(echo "scale=2; $prompt_size / $threshold" | bc)
}
EOF
)

    vibe_log "file_prompt.size_analysis" "routing_decision" "$metadata" \
        "プロンプトサイズ分析: $ai_name ($prompt_size bytes, 閾値: $threshold bytes)" \
        "analyze_size,make_routing_decision,optimize_performance" \
        "File-Prompt-System"
}

# ============================================================================
# Library Initialization Check
# ============================================================================

# Export functions for use in sourcing scripts
export -f get_timestamp_ms
export -f vibe_log
export -f vibe_wrapper_start
export -f vibe_wrapper_done
export -f vibe_wrapper_config
export -f vibe_tdd_phase_start
export -f vibe_tdd_phase_done
export -f vibe_tdd_test_result
export -f vibe_tdd_cycle_start
export -f vibe_tdd_cycle_done
export -f vibe_pipeline_start
export -f vibe_pipeline_done
export -f vibe_file_prompt_start
export -f vibe_file_prompt_done
export -f vibe_file_created
export -f vibe_file_cleanup
export -f vibe_prompt_size_analysis

# Mark library as loaded
export VIBELOGGER_LIB_LOADED=1

# Log library initialization (optional, for debugging)
if [[ "${VIBELOGGER_DEBUG:-0}" == "1" ]]; then
    echo "[VibeLogger] Library loaded: $VIBE_LOG_DIR" >&2
fi
