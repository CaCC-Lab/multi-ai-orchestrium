#!/usr/bin/env bash
# error-recovery.sh - Error Recovery Orchestrator
# Phase 4 Tier 2 Task 6: Error Recovery Granularity Improvement
#
# Integrates all error recovery components:
# - Error Classification System
# - Dynamic Retry Policy Engine
# - Partial Result Acceptance Layer
# - Graceful Degradation Controller

set -uo pipefail  # Remove -e to allow graceful error handling

# Note: This library expects SCRIPT_DIR and PROJECT_ROOT to be defined by the calling script
if [[ -z "${SCRIPT_DIR:-}" || -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: SCRIPT_DIR and PROJECT_ROOT must be defined before sourcing error-recovery.sh" >&2
  return 1 2>/dev/null || exit 1
fi

source "$SCRIPT_DIR/lib/task-state.sh" 2>/dev/null || {
  # task-state.sh is optional, continue without it
  :
}

# Phase 4 Tier 2 Task 6: Load new error recovery components
if [[ -f "$SCRIPT_DIR/lib/error-classifier.sh" ]]; then
  source "$SCRIPT_DIR/lib/error-classifier.sh"
fi

if [[ -f "$SCRIPT_DIR/lib/retry-policy.sh" ]]; then
  source "$SCRIPT_DIR/lib/retry-policy.sh"
fi

if [[ -f "$SCRIPT_DIR/lib/partial-result-handler.sh" ]]; then
  source "$SCRIPT_DIR/lib/partial-result-handler.sh"
fi

if [[ -f "$SCRIPT_DIR/lib/graceful-degradation.sh" ]]; then
  source "$SCRIPT_DIR/lib/graceful-degradation.sh"
fi

ERROR_RECOVERY_LOG_DIR="${ERROR_RECOVERY_LOG_DIR:-$PROJECT_ROOT/logs/error-recovery}"
mkdir -p "$ERROR_RECOVERY_LOG_DIR"

ERROR_RECOVERY_DEFAULT_TIMEOUT="${ERROR_RECOVERY_DEFAULT_TIMEOUT:-900}"
ERROR_RECOVERY_MAX_RETRIES="${ERROR_RECOVERY_MAX_RETRIES:-3}"
ERROR_RECOVERY_RETRY_DELAY="${ERROR_RECOVERY_RETRY_DELAY:-5}"

_error_recovery_log() {
  local task_id="$1"
  local event="$2"
  local payload_json="${3:-{}}"
  local timestamp
  timestamp="$(date -Iseconds)"
  local log_file="$ERROR_RECOVERY_LOG_DIR/${task_id}.jsonl"
  jq -n --arg ts "$timestamp" --arg event "$event" --argjson payload "$payload_json" '{timestamp: $ts, event: $event, payload: $payload}' >>"$log_file"
  task_state_append_history "$task_id" "$event" "$payload_json"
}

# Phase 4 Tier 2 Task 6: Enhanced error recovery with classification and retry policy
error_recovery_execute_with_fallback() {
  local task_id="$1"
  local worktree_path="$2"
  local prompt="$3"
  local timeout="${4:-$ERROR_RECOVERY_DEFAULT_TIMEOUT}"
  local max_retries="${5:-$ERROR_RECOVERY_MAX_RETRIES}"
  local primary_ai="$6"
  local fallback_json="${7:-[]}" 
  local run_fn="${8:-}"
  local rollback_fn="${9:-}"
  local dry_run="${10:-false}"

  if [[ -z "$run_fn" ]]; then
    echo "ERROR: error_recovery_execute_with_fallback requires a run function" >&2
    return 1
  fi

  # Phase 4 Tier 2 Task 6: Initialize graceful degradation state
  if declare -f reset_degradation_state >/dev/null 2>&1; then
    reset_degradation_state
  fi

  local ai_candidates=()
  ai_candidates+=("$primary_ai")
  if [[ -n "$fallback_json" ]]; then
    local parsed
    if ! parsed=$(printf '%s' "$fallback_json" | jq -rc '. // []' 2>/dev/null); then
      parsed='[]'
    fi
    while IFS= read -r candidate; do
      [[ -z "$candidate" ]] && continue
      local already=false
      for existing in "${ai_candidates[@]}"; do
        if [[ "$existing" == "$candidate" ]]; then
          already=true; break
        fi
      done
      if [[ "$already" == false ]]; then
        ai_candidates+=("$candidate")
      fi
    done < <(printf '%s\n' "$parsed" | jq -r '.[]?')
  fi

  task_state_update_status "$task_id" "running"

  local total_attempts=0
  local success=false
  local last_error=""
  local last_log=""
  local failure_count=0
  local current_timeout="$timeout"

  for ai in "${ai_candidates[@]}"; do
    [[ -z "$ai" ]] && continue
    task_state_set_current_ai "$task_id" "$ai"

    # Phase 4 Tier 2 Task 6: Adjust timeout based on retry count
    if declare -f adjust_timeout >/dev/null 2>&1; then
      current_timeout=$(adjust_timeout "$timeout" "$failure_count")
    fi

    for ((attempt=1; attempt<=max_retries; attempt++)); do
      ((total_attempts++))
      task_state_increment_attempts "$task_id"

      local attempt_payload
      attempt_payload=$(jq -n --arg ai "$ai" --argjson attempt "$attempt" --argjson sequence "$total_attempts" --argjson timeout "$current_timeout" '{ai:$ai, attempt:$attempt, sequence:$sequence, timeout:$timeout}')
      _error_recovery_log "$task_id" "attempt-start" "$attempt_payload"

      if [[ "$dry_run" == "true" ]]; then
        success=true
        last_error=""
        last_log="dry-run"
        break 2
      fi

      local run_output=""
      local stderr_file="${ERROR_RECOVERY_LOG_DIR}/${task_id}.stderr"
      
      # Phase 4 Tier 2 Task 6: Execute with retry policy if available
      if declare -f retry_with_policy >/dev/null 2>&1; then
        # Use retry policy for intelligent retry
        if run_output=$(retry_with_policy "$ai" "$run_fn" "$ai" "$task_id" "$worktree_path" "$prompt" "$current_timeout" "false" 2>"$stderr_file"); then
          success=true
          last_log="$run_output"
          local success_payload
          success_payload=$(jq -n --arg ai "$ai" --argjson attempt "$attempt" --arg log "$run_output" '{ai:$ai, attempt:$attempt, log:$log}')
          _error_recovery_log "$task_id" "attempt-success" "$success_payload"
          break 2
        else
          local exit_code=$?
          last_error="exit_code=$exit_code"
          last_log="$run_output"
          
          # Phase 4 Tier 2 Task 6: Classify error type
          local error_type="UNKNOWN"
          if declare -f classify_error >/dev/null 2>&1 && [[ -f "$stderr_file" ]]; then
            local error_message
            error_message=$(cat "$stderr_file" 2>/dev/null || echo "")
            error_type=$(classify_error "$error_message" "$exit_code")
          fi
          
          local failure_reason="failure"
          if [[ $exit_code -eq 124 ]]; then
            failure_reason="timeout"
          fi
          
          local fail_payload
          fail_payload=$(jq -n --arg ai "$ai" --argjson attempt "$attempt" --argjson exit "$exit_code" --arg reason "$failure_reason" --arg error_type "$error_type" --arg log "$run_output" '{ai:$ai, attempt:$attempt, exit_code:$exit|tonumber, reason:$reason, error_type:$error_type, log:$log}')
          _error_recovery_log "$task_id" "attempt-failure" "$fail_payload"
          
          # Phase 4 Tier 2 Task 6: Check if we should continue based on error type
          case "$error_type" in
            "FATAL"|"CONFIGURATION")
              # Fatal or configuration errors - no retry
              failure_count=$((failure_count + 1))
              break
              ;;
            "TRANSIENT"|"PERSISTENT")
              # Transient or persistent errors - continue retry
              failure_count=$((failure_count + 1))
              sleep "$ERROR_RECOVERY_RETRY_DELAY"
              ;;
            *)
              # Unknown errors - default retry behavior
              failure_count=$((failure_count + 1))
              sleep "$ERROR_RECOVERY_RETRY_DELAY"
              ;;
          esac
        fi
      else
        # Fallback to original retry logic
        if run_output=$("$run_fn" "$ai" "$task_id" "$worktree_path" "$prompt" "$current_timeout" "false" 2>&1); then
          success=true
          last_log="$run_output"
          local success_payload
          success_payload=$(jq -n --arg ai "$ai" --argjson attempt "$attempt" --arg log "$run_output" '{ai:$ai, attempt:$attempt, log:$log}')
          _error_recovery_log "$task_id" "attempt-success" "$success_payload"
          break 2
        else
          local exit_code=$?
          last_error="exit_code=$exit_code"
          last_log="$run_output"
          local failure_reason="failure"
          if [[ $exit_code -eq 124 ]]; then
            failure_reason="timeout"
          fi
          local fail_payload
          # FIXED: Use $log instead of $run_output in jq template
          # The variable is passed as --arg log "$run_output", so it must be referenced as $log in jq
          fail_payload=$(jq -n --arg ai "$ai" --argjson attempt "$attempt" --argjson exit "$exit_code" --arg reason "$failure_reason" --arg log "$run_output" '{ai:$ai, attempt:$attempt, exit_code:$exit|tonumber, reason:$reason, log:$log}')
          _error_recovery_log "$task_id" "attempt-failure" "$fail_payload"
          failure_count=$((failure_count + 1))
          sleep "$ERROR_RECOVERY_RETRY_DELAY"
        fi
      fi
    done
    
    # Phase 4 Tier 2 Task 6: Switch execution mode based on failure count
    if declare -f switch_execution_mode >/dev/null 2>&1; then
      switch_execution_mode "${CURRENT_MODE:-parallel}" "$failure_count" >/dev/null
    fi
  done

  # Phase 4 Tier 2 Task 6: Check for partial results if all attempts failed
  if [[ "$success" != true ]] && declare -f extract_partial_results >/dev/null 2>&1; then
    local output_file="${ERROR_RECOVERY_LOG_DIR}/${task_id}.output"
    if [[ -f "$output_file" ]]; then
      local completion_rate
      completion_rate=$(extract_partial_results "$output_file" 1)
      
      if [[ "$completion_rate" -ge 50 ]]; then
        # Partial result accepted
        local critical_success=false
        if declare -f check_critical_ai_success >/dev/null 2>&1; then
          local ai_results_json
          ai_results_json=$(jq -n --arg ai "$primary_ai" --argjson success false '[{ai:$ai, success:$success}]')
          critical_success=$(check_critical_ai_success "$ai_results_json")
        fi
        
        if accept_partial_workflow_result "${#ai_candidates[@]}" "1" "$critical_success"; then
          if declare -f save_partial_result >/dev/null 2>&1; then
            save_partial_result "$task_id" "$output_file" "$completion_rate"
          fi
          task_state_update_status "$task_id" "partial"
          return 0
        fi
      fi
    fi
  fi

  if [[ "$success" == true ]]; then
    task_state_update_status "$task_id" "completed"
    task_state_append_error "$task_id" "" "$primary_ai"
    return 0
  fi

  task_state_update_status "$task_id" "failed"
  if [[ -n "$last_error" ]]; then
    task_state_append_error "$task_id" "$last_error" "$primary_ai"
  fi
  local final_payload
  final_payload=$(jq -n --arg error "$last_error" --arg log "$last_log" '{error:$error, log:$last_log}')
  _error_recovery_log "$task_id" "task-failed" "$final_payload"

  if [[ -n "$rollback_fn" ]]; then
    "$rollback_fn" "$task_id" "$primary_ai" "$worktree_path" || true
  fi

  return 1
}

export -f error_recovery_execute_with_fallback

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --help|-h|help)
      cat <<'EOF'
Error Recovery Helper

Exposed function when sourced:
  error_recovery_execute_with_fallback TASK_ID WORKTREE PROMPT [TIMEOUT] [RETRIES] PRIMARY_AI FALLBACK_JSON RUN_FN [ROLLBACK_FN] [DRY_RUN]

The run function must accept: <ai> <task_id> <worktree> <prompt> <timeout> <dry_run>
and return 0 on success while printing a log path (or summary) to stdout.
EOF
      ;;
    *)
      echo "Use --help for usage information." >&2
      ;;
  esac
fi