#!/usr/bin/env bash
# task-state.sh - JSON形式でタスク状態永続化 (SpecialistAgentシステム用 & 既存システム互換)
# SpecialistAgentシステム: 状態管理システム + 既存システムとの互換性

set -euo pipefail

TASK_STATE_VERSION="1.0.0"

#---------------------------------------------------------------------
# 定数定義
#---------------------------------------------------------------------
# Note: This library assumes PROJECT_ROOT variable is already set by the calling script
TASK_STATE_DIR="${TASK_STATE_DIR:-$PROJECT_ROOT/.task-state}"
TASK_STATE_LOCK_DIR="${TASK_STATE_LOCK_DIR:-/tmp/task-state-locks}"
mkdir -p "$TASK_STATE_DIR" "$TASK_STATE_LOCK_DIR"

# 互換性のための定数
TASK_STATE_DIR_COMPAT="${TASK_STATE_DIR_COMPAT:-$PROJECT_ROOT/.specialist-agent/tasks}"
TASK_STATE_LOCK_DIR_COMPAT="${TASK_STATE_LOCK_DIR:-$PROJECT_ROOT/.specialist-agent/locks}"

#---------------------------------------------------------------------
# 内部ユーティリティ関数 (既存システム互換)
#---------------------------------------------------------------------

_task_state_file() {
  local task_id="$1"
  printf '%s/%s.json' "$TASK_STATE_DIR" "$task_id"
}

_task_state_lock_file() {
  local task_id="$1"
  printf '%s/%s.lock' "$TASK_STATE_LOCK_DIR" "$task_id"
}

task_state_exists() {
  local task_id="$1"
  [[ -f "$(_task_state_file "$task_id")" ]]
}

task_state_read_json() {
  local task_id="$1"
  local file="$(_task_state_file "$task_id")"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    jq -n '{}'
  fi
}

task_state_write_json() {
  local task_id="$1"
  local json_payload="$2"
  local force="${3:-false}"

  local file="$(_task_state_file "$task_id")"
  if [[ -f "$file" && "$force" != "true" ]]; then
    return 0
  fi

  local lock_file="$(_task_state_lock_file "$task_id")"
  mkdir -p "$(dirname "$file")" "$(dirname "$lock_file")"

  (
    flock -w 10 200 || {
      echo "ERROR: Failed to acquire lock for task $task_id" >&2
      exit 1
    }
    umask 0177
    local tmp_file="${file}.tmp.$$"
    printf '%s\n' "$json_payload" | jq '.' >"$tmp_file"
    mv "$tmp_file" "$file"
  ) 200>"$lock_file"
}

task_state_init() {
  local task_id="$1"
  local primary_ai="${2:-}"
  local description="${3:-}"
  local priority="${4:-}"
  local spec_source="${5:-}"
  local status="${6:-pending}"

  local now
  now="$(date -Iseconds)"

  local payload
  payload=$(jq -n \
    --arg id "$task_id" \
    --arg status "$status" \
    --arg ai "$primary_ai" \
    --arg desc "$description" \
    --arg priority "$priority" \
    --arg spec "$spec_source" \
    --arg created "$now" \
    '{
      task_id: $id,
      status: $status,
      primary_ai: ($ai // null),
      current_ai: null,
      description: $desc,
      priority: $priority,
      spec_source: $spec,
      created_at: $created,
      updated_at: $created,
      attempt_count: 0,
      worktree_path: null,
      fallback_agents: [],
      candidates: [],
      last_error: "",
      metadata: {},
      history: []
    }')

  task_state_write_json "$task_id" "$payload" "true"
}

task_state_update() {
  local task_id="$1"
  shift
  local jq_filter="$1"
  shift
  local -a jq_args=()
  if [[ $# -gt 0 ]]; then
    jq_args=($@)
  fi

  local now
  now="$(date -Iseconds)"

  local current
  current="$(task_state_read_json "$task_id")"

  local updated
  updated=$(printf '%s' "$current" | jq "${jq_args[@]}" --arg now "$now" "$jq_filter | .updated_at = \$now")

  task_state_write_json "$task_id" "$updated" "true"
}

task_state_set() {
  local task_id="$1"
  local key="$2"
  local value="$3"
  task_state_update "$task_id" '.[$field] = $value' --arg field "$key" --arg value "$value"
}

task_state_set_json() {
  local task_id="$1"
  local key="$2"
  local json_value="$3"
  task_state_update "$task_id" '.[$field] = $value' --arg field "$key" --argjson value "$json_value"
}

task_state_get() {
  local task_id="$1"
  local key="$2"
  task_state_read_json "$task_id" | jq -r --arg key "$key" '.[$key] // empty'
}

task_state_get_json() {
  local task_id="$1"
  task_state_read_json "$task_id"
}

task_state_update_status() {
  local task_id="$1"
  local new_status="$2"
  local previous
  previous=$(task_state_get "$task_id" "status")

  task_state_update "$task_id" '.status = $status' --arg status "$new_status"
  task_state_append_history "$task_id" "status-change" "{\"from\": \"$previous\", \"to\": \"$new_status\"}"
  if [[ "$new_status" == "completed" ]]; then
    task_state_update "$task_id" '.last_error = ""'
  fi
}

task_state_increment_attempts() {
  local task_id="$1"
  task_state_update "$task_id" '.attempt_count = (.attempt_count // 0) + 1'
}

task_state_set_current_ai() {
  local task_id="$1"
  local ai="$2"
  task_state_update "$task_id" '.current_ai = $ai' --arg ai "$ai"
}

task_state_set_candidates() {
  local task_id="$1"
  local candidates_json="$2"
  task_state_update "$task_id" '.candidates = $candidates' --argjson candidates "$candidates_json"
}

task_state_set_fallbacks() {
  local task_id="$1"
  local fallbacks_json="$2"
  task_state_update "$task_id" '.fallback_agents = $fallbacks' --argjson fallbacks "$fallbacks_json"
}

task_state_append_history() {
  local task_id="$1"
  local event="$2"
  local payload_json="${3:-{}}"
  [[ -z "$payload_json" ]] && payload_json='{}'

  local timestamp
  timestamp="$(date -Iseconds)"

  task_state_update "$task_id" '.history += [{timestamp: $timestamp, event: $event, payload: $payload}]' \
    --arg timestamp "$timestamp" \
    --arg event "$event" \
    --argjson payload "$payload_json"
}

task_state_append_error() {
  local task_id="$1"
  local message="$2"
  local ai="${3:-}"
  task_state_update "$task_id" '.last_error = $msg' --arg msg "$message"
  task_state_append_history "$task_id" "error" "{\"message\": \"$message\", \"ai\": \"$ai\"}"
}

task_state_register_worktree() {
  local task_id="$1"
  local path="$2"
  task_state_update "$task_id" '.worktree_path = $path' --arg path "$path"
}

task_state_remove() {
  local task_id="$1"
  rm -f "$(_task_state_file "$task_id")"
}

task_state_list() {
  if compgen -G "$TASK_STATE_DIR/*.json" >/dev/null; then
    jq -s '.' "$TASK_STATE_DIR"/*.json
  else
    jq -n '[]'
  fi
}

task_state_print() {
  local task_id="$1"
  if ! task_state_exists "$task_id"; then
    echo "Task $task_id not found" >&2
    return 1
  fi
  task_state_read_json "$task_id" | jq '.'
}

export -f task_state_exists
export -f task_state_read_json
export -f task_state_write_json
export -f task_state_init
export -f task_state_update
export -f task_state_set
export -f task_state_set_json
export -f task_state_get
export -f task_state_get_json
export -f task_state_update_status
export -f task_state_increment_attempts
export -f task_state_set_current_ai
export -f task_state_set_candidates
export -f task_state_set_fallbacks
export -f task_state_append_history
export -f task_state_append_error
export -f task_state_register_worktree
export -f task_state_remove
export -f task_state_list
export -f task_state_print