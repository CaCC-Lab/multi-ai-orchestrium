#!/usr/bin/env bash

# asyncthink-integration.sh - AsyncThink organiser/worker bridge
# Phase 2-3-3: Background orchestration + progress monitoring

set -euo pipefail

AT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AT_PROJECT_ROOT="$(cd "$AT_LIB_DIR/../.." && pwd)"

AT_API_ENDPOINT="${ASYNCTHINK_API_URL:-http://127.0.0.1:8723}" # default loopback
AT_TIMEOUT_DEFAULT="${ASYNCTHINK_TIMEOUT:-900}"
AT_POLL_INTERVAL="${ASYNCTHINK_POLL_INTERVAL:-5}"

AT_STORAGE_ROOT="${ASYNCTHINK_STORAGE_ROOT:-$AT_PROJECT_ROOT/logs/asyncthink}"
AT_JOBS_DIR="$AT_STORAGE_ROOT/jobs"
AT_LOG_DIR="$AT_STORAGE_ROOT/logs"
AT_TMP_DIR="$AT_STORAGE_ROOT/tmp"

AT_ENV_FILE="${ASYNCTHINK_ENV_FILE:-$AT_PROJECT_ROOT/config/asyncthink.env}"

asyncthink_usage() {
  cat <<'EOF'
AsyncThink Integration

Usage:
  asyncthink-integration.sh submit-spec --spec path.md [--profiles file] [--limit N]
                                         [--priority LEVEL] [--async-mode auto|local|remote]
  asyncthink-integration.sh status <job_id>
  asyncthink-integration.sh list
  asyncthink-integration.sh logs <job_id> [--tail N]
  asyncthink-integration.sh wait <job_id> [--timeout SEC]
  asyncthink-integration.sh cancel <job_id>
  asyncthink-integration.sh ping

Internal commands (not for direct use):
  asyncthink-integration.sh _complete_job <job_id> <exit_code> <log_file>
EOF
}

asyncthink_init_paths() {
  mkdir -p "$AT_JOBS_DIR" "$AT_LOG_DIR" "$AT_TMP_DIR"
}

asyncthink_log() {
  local level="$1"; shift
  local message="$1"; shift || true
  printf '[%s] [AsyncThink] %s\n' "$level" "$message" >&2
}

asyncthink_load_env() {
  if [[ -f "$AT_ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$AT_ENV_FILE"
  fi
}

asyncthink_job_path() {
  printf '%s/%s.json' "$AT_JOBS_DIR" "$1"
}

asyncthink_job_lock() {
  printf '%s/%s.lock' "$AT_JOBS_DIR" "$1"
}

asyncthink_generate_job_id() {
  local stamp rand
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  rand=$(openssl rand -hex 3 2>/dev/null || printf '%06x' $RANDOM)
  printf 'at-%s-%s' "$stamp" "$rand"
}

asyncthink_merge_job() {
  local job_id="$1"
  local patch_json="$2"
  local job_file
  job_file="$(asyncthink_job_path "$job_id")"
  local lock_file
  lock_file="$(asyncthink_job_lock "$job_id")"

  (
    flock -w 10 200 || {
      asyncthink_log "ERROR" "Failed to acquire lock for job $job_id"
      exit 1
    }
    python3 - "$job_file" "$patch_json" <<'PY'
import json
import sys
from datetime import datetime

job_path = sys.argv[1]
patch = json.loads(sys.argv[2])

try:
    with open(job_path, 'r', encoding='utf-8') as handle:
        data = json.load(handle)
except FileNotFoundError:
    data = {}

def merge(base, update):
    for key, value in update.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value
    return base

merge(data, patch)
data.setdefault('history', [])
event = {
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "summary": patch.get('status_update', patch.get('status'))
}
if event['summary']:
    data['history'].append(event)
data['updated_at'] = datetime.utcnow().isoformat() + 'Z'

with open(job_path, 'w', encoding='utf-8') as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
PY
  ) 200>"$lock_file"
}

asyncthink_ping() {
  if ! command -v curl >/dev/null 2>&1; then
    asyncthink_log "WARN" "curl not available; skipping API ping"
    return 1
  fi
  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$AT_API_ENDPOINT/ping" || true)
  if [[ "$response" == "200" ]]; then
    asyncthink_log "INFO" "AsyncThink API reachable at $AT_API_ENDPOINT"
    return 0
  fi
  asyncthink_log "WARN" "AsyncThink API not reachable (HTTP $response)"
  return 1
}

asyncthink_collect_command_json() {
  local -a cmd=("$@")
  python3 - <<'PY'
import json, os, sys
cmd = sys.argv[1:]
print(json.dumps(cmd, ensure_ascii=False))
PY
}

asyncthink_create_job_record() {
  local job_id="$1"
  local status="$2"
  local mode="$3"
  local spec="$4"
  local log_file="$5"
  local command_json="$6"
  local extra_patch="${7:-{}}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local base_patch
  base_patch=$(jq -n --arg job_id "$job_id" \
                     --arg status "$status" \
                     --arg mode "$mode" \
                     --arg spec "$spec" \
                     --arg log "$log_file" \
                     --argjson command "$command_json" \
                     --arg created "$now" '{job_id:$job_id,status:$status,mode:$mode,spec:$spec,log_file:$log,command:$command,created_at:$created,updated_at:$created,status_update:$status}')

  local merge_patch
  merge_patch=$(jq -n --argjson base "$base_patch" --argjson extra "$extra_patch" '$base * $extra')
  asyncthink_merge_job "$job_id" "$merge_patch"
}

asyncthink_update_job_status() {
  local job_id="$1"
  local status="$2"
  local extra_patch="${3:-{}}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local patch
  patch=$(jq -n --arg status "$status" --arg now "$now" --arg status_update "$status" '{status:$status,status_update:$status_update,finished_at:$now} * (. // {} )')
  local merged
  merged=$(jq -n --argjson base "$patch" --argjson extra "$extra_patch" '$base * $extra')
  asyncthink_merge_job "$job_id" "$merged"
}

asyncthink_submit_local_spec() {
  local spec_path="$1"; shift
  local profiles=""
  local limit=""
  local priority_filter=""
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profiles)
        profiles="$2"; shift 2 ;;
      --limit)
        limit="$2"; shift 2 ;;
      --priority)
        priority_filter="$2"; shift 2 ;;
      --dry-run)
        dry_run="true"; shift ;;
      *)
        break ;;
    esac
  done

  local job_id
  job_id="$(asyncthink_generate_job_id)"
  local log_file="$AT_LOG_DIR/${job_id}.log"
  local runner_script="$AT_TMP_DIR/${job_id}.runner.sh"

  local -a command=("$AT_PROJECT_ROOT/scripts/lib/task-executor.sh" run --spec "$spec_path")
  [[ -n "$profiles" ]] && command+=(--profiles "$profiles")
  [[ -n "$limit" ]] && command+=(--limit "$limit")
  [[ -n "$priority_filter" ]] && command+=(--priority "$priority_filter")
  [[ "$dry_run" == "true" ]] && command+=(--dry-run)

  local command_json
  command_json=$(asyncthink_collect_command_json "${command[@]}")

  asyncthink_create_job_record "$job_id" "running" "local" "$spec_path" "$log_file" "$command_json"

  {
    echo '#!/usr/bin/env bash'
    echo 'set -euo pipefail'
    echo "LOG_FILE='$log_file'"
    echo "JOB_ID='$job_id'"
    echo "cd '$AT_PROJECT_ROOT'"
    printf 'COMMAND=( '
    for arg in "${command[@]}"; do
      printf '%q ' "$arg"
    done
    echo ')'
    echo '"${COMMAND[@]}" >>"$LOG_FILE" 2>&1'
    echo 'exit_code=$?'
    echo "\"$AT_LIB_DIR/asyncthink-integration.sh\" _complete_job \"$job_id\" \"\$exit_code\" \"$log_file\" \"$AT_PROJECT_ROOT\" \"$AT_LIB_DIR\" \"$AT_TIMEOUT_DEFAULT\" \"$AT_POLL_INTERVAL\" \"$AT_STORAGE_ROOT\" \"$AT_API_ENDPOINT\""
    echo 'exit "$exit_code"'
  } >"$runner_script"
  
  chmod +x "$runner_script"
  asyncthink_log "INFO" "Job $job_id submitted (local mode)"
  echo "$job_id"
}

# Internal function: Complete a job
_complete_job() {
  local job_id="$1"
  local exit_code="$2"
  local log_file="$3"
  shift 3
  
  local status="completed"
  if [[ "$exit_code" != "0" ]]; then
    status="failed"
  fi
  
  asyncthink_update_job_status "$job_id" "$status" "{\"exit_code\":$exit_code}"
  asyncthink_log "INFO" "Job $job_id $status (exit_code=$exit_code)"
}

# Main execution
main() {
  asyncthink_init_paths
  asyncthink_load_env
  
  case "${1:-}" in
    submit-spec)
      shift
      asyncthink_submit_local_spec "$@"
      ;;
    status)
      if [[ -z "${2:-}" ]]; then
        asyncthink_log "ERROR" "Usage: status <job_id>"
        exit 1
      fi
      local job_file
      job_file="$(asyncthink_job_path "$2")"
      if [[ -f "$job_file" ]]; then
        cat "$job_file"
      else
        asyncthink_log "ERROR" "Job $2 not found"
        exit 1
      fi
      ;;
    list)
      for job_file in "$AT_JOBS_DIR"/*.json; do
        [[ -f "$job_file" ]] || continue
        basename "$job_file" .json
      done
      ;;
    logs)
      if [[ -z "${2:-}" ]]; then
        asyncthink_log "ERROR" "Usage: logs <job_id> [--tail N]"
        exit 1
      fi
      local log_file="$AT_LOG_DIR/${2}.log"
      if [[ -f "$log_file" ]]; then
        if [[ "${3:-}" == "--tail" ]] && [[ -n "${4:-}" ]]; then
          tail -n "${4}" "$log_file"
        else
          cat "$log_file"
        fi
      else
        asyncthink_log "ERROR" "Log file for job $2 not found"
        exit 1
      fi
      ;;
    wait)
      if [[ -z "${2:-}" ]]; then
        asyncthink_log "ERROR" "Usage: wait <job_id> [--timeout SEC]"
        exit 1
      fi
      local timeout="${4:-3600}"
      local elapsed=0
      while [[ $elapsed -lt $timeout ]]; do
        local job_file
        job_file="$(asyncthink_job_path "$2")"
        if [[ ! -f "$job_file" ]]; then
          asyncthink_log "ERROR" "Job $2 not found"
          exit 1
        fi
        local status
        status=$(jq -r '.status // "unknown"' "$job_file" 2>/dev/null || echo "unknown")
        if [[ "$status" == "completed" ]] || [[ "$status" == "failed" ]]; then
          echo "$status"
          exit 0
        fi
        sleep "$AT_POLL_INTERVAL"
        elapsed=$((elapsed + AT_POLL_INTERVAL))
      done
      asyncthink_log "ERROR" "Timeout waiting for job $2"
      exit 1
      ;;
    cancel)
      if [[ -z "${2:-}" ]]; then
        asyncthink_log "ERROR" "Usage: cancel <job_id>"
        exit 1
      fi
      asyncthink_update_job_status "$2" "cancelled"
      asyncthink_log "INFO" "Job $2 cancelled"
      ;;
    ping)
      asyncthink_ping
      ;;
    _complete_job)
      shift
      _complete_job "$@"
      ;;
    *)
      asyncthink_usage
      exit 1
      ;;
  esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
