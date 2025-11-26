#!/usr/bin/env bash
# task-executor.sh - SpecialistAgent task orchestration engine

set -euo pipefail

# Note: This library expects SCRIPT_DIR and PROJECT_ROOT to be defined by the calling script
if [[ -z "${SCRIPT_DIR:-}" || -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: SCRIPT_DIR and PROJECT_ROOT must be defined before sourcing task-executor.sh" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for task-executor.sh" >&2
  exit 1
fi

source "$SCRIPT_DIR/lib/task-state.sh"
source "$SCRIPT_DIR/lib/error-recovery.sh"
source "$SCRIPT_DIR/lib/task-router.sh"
source "$SCRIPT_DIR/lib/agent-matcher.sh"
source "$PROJECT_ROOT/scripts/worktree-manager-enhanced.sh"

TASK_EXECUTOR_LOG_DIR="${TASK_EXECUTOR_LOG_DIR:-$PROJECT_ROOT/logs/task-executor}"
TASK_EXECUTOR_DEFAULT_TIMEOUT="${TASK_EXECUTOR_DEFAULT_TIMEOUT:-900}"
TASK_EXECUTOR_DEFAULT_RETRIES="${TASK_EXECUTOR_DEFAULT_RETRIES:-3}"

mkdir -p "$TASK_EXECUTOR_LOG_DIR"

task_executor_slugify() {
  local text="$1"
  text="${text,,}"
  text="${text//[^a-z0-9]+/-}"
  text="${text##-}"
  text="${text%%-}"
  [[ -z "$text" ]] && text="task"
  printf '%s' "$text"
}

task_executor_default_profiles() {
  printf '%s' "$PROJECT_ROOT/config/ai-profiles.yaml"
}

task_executor_generate_prompt() {
  local title="$1"
  local description="$2"
  local priority="$3"
  local section="$4"
  local keywords_line="$5"
  local spec_path="$6"
  local start_line="$7"
  local end_line="$8"

  cat <<EOF
### Task: $title
Priority: ${priority:-Unspecified}
Domain: ${section:-general}
Keywords: ${keywords_line:-n/a}
Source: ${spec_path:-unknown}:${start_line:-?}-${end_line:-?}

$description

Deliverables:
- Execute the task inside the provided Git worktree.
- Produce clean, reviewable changes while respecting repository conventions.
- Update relevant tests or documentation if required by the task.
EOF
}

task_executor_invoke_agent() {
  local ai="$1"
  local task_id="$2"
  local worktree_path="$3"
  local prompt="$4"
  local timeout_secs="$5"
  local dry_run="${6:-false}"

  local log_file="$TASK_EXECUTOR_LOG_DIR/${task_id}_${ai}_$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$TASK_EXECUTOR_LOG_DIR"

  if [[ "$dry_run" == "true" ]]; then
    printf '%s\n' "$log_file"
    return 0
  fi

  local wrapper="$PROJECT_ROOT/bin/${ai}-wrapper.sh"
  if [[ ! -x "$wrapper" ]]; then
    echo "ERROR: wrapper not found: $wrapper" >&2
    printf '%s\n' "$log_file"
    return 127
  fi

  local timeout_arg
  timeout_arg=$(printf '%s' "$timeout_secs" | tr -cd '0-9')
  [[ -z "$timeout_arg" ]] && timeout_arg="${TASK_EXECUTOR_DEFAULT_TIMEOUT}"

  WRAPPER_NON_INTERACTIVE=1 WORKSPACE="$worktree_path" \
    timeout "${timeout_arg}s" "$wrapper" --stdin --non-interactive >"$log_file" 2>&1 <<<"$prompt"
  local exit_code=$?
  printf '%s\n' "$log_file"
  return $exit_code
}

task_executor_rollback_task() {
  local task_id="$1"
  local ai="$2"
  local worktree_path="$3"
  if [[ -d "$worktree_path" ]]; then
    cleanup_worktree "$ai" "$task_id" "true" || true
  fi
}

task_executor_register_task() {
  local spec_file="$1"
  local task_payload="$2"
  local sequence="$3"

  local title
  title=$(printf '%s' "$task_payload" | jq -r --argjson seq "$sequence" '.title // .name // ("Task " + ($seq|tostring))')
  local description
  description=$(printf '%s' "$task_payload" | jq -r '.description // .text // ""')
  local keywords_array
  keywords_array=$(printf '%s' "$task_payload" | jq -c '.keywords // []')
  local keywords_line
  keywords_line=$(printf '%s' "$keywords_array" | jq -r 'join(", ")')
  local keyword_csv
  keyword_csv=$(printf '%s' "$keywords_array" | jq -r 'join(",")')
  local priority
  priority=$(printf '%s' "$task_payload" | jq -r '.priority // "Medium"')
  local section
  section=$(printf '%s' "$task_payload" | jq -r '.section // "general"')
  local start_line
  start_line=$(printf '%s' "$task_payload" | jq '.start_line // 0')
  local end_line
  end_line=$(printf '%s' "$task_payload" | jq '.end_line // 0')
  local slug
  slug=$(printf '%s' "$task_payload" | jq -r '.slug // empty')
  if [[ -z "$slug" || "$slug" == "null" ]]; then
    slug=$(task_executor_slugify "$title")
  fi
  local spec_slug
  spec_slug=$(task_executor_slugify "$(basename "$spec_file")")
  local base_id="${spec_slug:-spec}-${slug}"
  local task_id="$base_id"
  local suffix=1
  while task_state_exists "$task_id"; do
    task_id="${base_id}-${suffix}"
    ((suffix++))
  done

  local match_json
  match_json=$(agent_matcher_match --description "$description" --keywords "$keyword_csv" --category "$section" --format json --include-task --top 3 2>/dev/null || echo '{}')
  local primary_ai
  primary_ai=$(printf '%s' "$match_json" | jq -r '.best_match.agent_id // .matches[0].agent_id // empty')
  if [[ -z "$primary_ai" || "$primary_ai" == "null" ]]; then
    primary_ai=$(printf '%s' "$task_payload" | jq -r '.recommended_ai // .ai_assignment // "qwen"')
  fi
  [[ -z "$primary_ai" || "$primary_ai" == "null" ]] && primary_ai="qwen"

  local fallback_json
  fallback_json=$(printf '%s' "$match_json" | jq -c --arg primary "$primary_ai" '((.matches // []) | map(.agent_id) | map(select(. != $primary)) | unique)')
  if [[ "$fallback_json" == "null" || -z "$fallback_json" ]]; then
    fallback_json=$(jq -n --arg primary "$primary_ai" '["qwen","droid","claude","codex","cursor","amp","gemini"] | map(select(. != $primary))')
  fi

  local prompt
  prompt=$(task_executor_generate_prompt "$title" "$description" "$priority" "$section" "$keywords_line" "$spec_file" "$start_line" "$end_line")

  task_state_init "$task_id" "$primary_ai" "$title" "$priority" "$spec_file"
  task_state_set_fallbacks "$task_id" "$fallback_json"
  task_state_set_candidates "$task_id" "$(printf '%s' "$match_json" | jq -c '.matches // []')"
  task_state_set_json "$task_id" "source_task" "$task_payload"
  task_state_set_json "$task_id" "metadata" "$(jq -n --arg spec "$spec_file" --arg section "$section" --argjson start "$start_line" --argjson end "$end_line" --argjson sequence "$sequence" '{spec_path:$spec, section:$section, start_line:$start, end_line:$end, sequence:$sequence}')"
  task_state_set_json "$task_id" "keywords" "$keywords_array"
  task_state_set "$task_id" "prompt" "$prompt"
  task_state_set "$task_id" "sequence" "$sequence"
  task_state_set "$task_id" "section" "$section"
  task_state_set "$task_id" "spec_file" "$spec_file"

  printf '%s\n' "$task_id"
}

task_executor_plan_spec() {
  local spec_file="$1"
  shift
  local profiles="$(task_executor_default_profiles)"
  local limit=""
  local priority_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profiles)
        profiles="$2"; shift 2 ;;
      --limit)
        limit="$2"; shift 2 ;;
      --priority)
        priority_filter="$2"; shift 2 ;;
      *)
        echo "ERROR: Unknown option for plan: $1" >&2
        return 1 ;;
    esac
  done

  if [[ ! -f "$spec_file" ]]; then
    echo "ERROR: Spec file not found: $spec_file" >&2
    return 1
  fi
  if [[ ! -f "$profiles" ]]; then
    echo "ERROR: Profiles file not found: $profiles" >&2
    return 1
  fi

  local tasks_json
  tasks_json=$(task_router_route "$spec_file" "$profiles")
  if [[ -n "$priority_filter" ]]; then
    tasks_json=$(printf '%s' "$tasks_json" | jq --arg pf "$priority_filter" '[.[] | select((.priority // "") | ascii_downcase == ($pf | ascii_downcase))]')
  fi

  local count=0
  printf '%s' "$tasks_json" | jq -c '.[]' | while read -r task; do
    ((count++))
    if [[ -n "$limit" && $count -gt $limit ]]; then
      break
    fi
    task_executor_register_task "$spec_file" "$task" "$count"
  done
}

task_executor_execute_task_state() {
  local task_id="$1"
  shift
  local timeout="$TASK_EXECUTOR_DEFAULT_TIMEOUT"
  local retries="$TASK_EXECUTOR_DEFAULT_RETRIES"
  local base_ref="HEAD"
  local dry_run="false"
  local auto_cleanup="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout)
        timeout="$2"; shift 2 ;;
      --retries)
        retries="$2"; shift 2 ;;
      --base-ref)
        base_ref="$2"; shift 2 ;;
      --dry-run)
        dry_run="true"; shift ;;
      --auto-cleanup)
        auto_cleanup="true"; shift ;;
      *)
        echo "ERROR: Unknown option for execute-task: $1" >&2
        return 1 ;;
    esac
  done

  if ! task_state_exists "$task_id"; then
    echo "ERROR: Task state not found for $task_id" >&2
    return 1
  fi

  local state_json
  state_json=$(task_state_get_json "$task_id")
  local primary_ai
  primary_ai=$(printf '%s' "$state_json" | jq -r '.current_ai // .primary_ai // "qwen"')
  local prompt
  prompt=$(printf '%s' "$state_json" | jq -r '.prompt // ""')
  local fallback_json
  fallback_json=$(printf '%s' "$state_json" | jq -c '.fallback_agents // []')
  local worktree_path
  worktree_path=$(printf '%s' "$state_json" | jq -r '.worktree_path // empty')

  if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
    local description
    description=$(printf '%s' "$state_json" | jq -r '.description // ""')
    worktree_path=$(create_worktree "$primary_ai" "$task_id" "$description" "$base_ref")
    if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
      echo "ERROR: Failed to create worktree for $task_id" >&2
      return 1
    fi
    task_state_register_worktree "$task_id" "$worktree_path"
  fi

  local timeout_secs
  timeout_secs=$(printf '%s' "$timeout" | tr -cd '0-9')
  [[ -z "$timeout_secs" ]] && timeout_secs="$TASK_EXECUTOR_DEFAULT_TIMEOUT"
  local retries_count
  retries_count=$(printf '%s' "$retries" | tr -cd '0-9')
  [[ -z "$retries_count" ]] && retries_count="$TASK_EXECUTOR_DEFAULT_RETRIES"

  if error_recovery_execute_with_fallback "$task_id" "$worktree_path" "$prompt" "$timeout_secs" "$retries_count" "$primary_ai" "$fallback_json" task_executor_invoke_agent task_executor_rollback_task "$dry_run"; then
    if [[ "$auto_cleanup" == "true" && "$dry_run" != "true" ]]; then
      cleanup_worktree "$primary_ai" "$task_id" "true" || true
    fi
    return 0
  else
    return 1
  fi
}

task_executor_run_spec() {
  local spec_file="$1"
  shift
  local profiles="$(task_executor_default_profiles)"
  local limit=""
  local priority_filter=""
  local timeout="$TASK_EXECUTOR_DEFAULT_TIMEOUT"
  local retries="$TASK_EXECUTOR_DEFAULT_RETRIES"
  local dry_run="false"
  local auto_cleanup="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profiles)
        profiles="$2"; shift 2 ;;
      --limit)
        limit="$2"; shift 2 ;;
      --priority)
        priority_filter="$2"; shift 2 ;;
      --timeout)
        timeout="$2"; shift 2 ;;
      --retries)
        retries="$2"; shift 2 ;;
      --dry-run)
        dry_run="true"; shift ;;
      --auto-cleanup)
        auto_cleanup="true"; shift ;;
      *)
        echo "ERROR: Unknown option for run: $1" >&2
        return 1 ;;
    esac
  done

  local plan_args=()
  plan_args+=(--profiles "$profiles")
  [[ -n "$limit" ]] && plan_args+=(--limit "$limit")
  [[ -n "$priority_filter" ]] && plan_args+=(--priority "$priority_filter")

  mapfile -t task_ids < <(task_executor_plan_spec "$spec_file" "${plan_args[@]}")

  if [[ ${#task_ids[@]} -eq 0 ]]; then
    echo "INFO: No tasks generated from specification." >&2
    return 0
  fi

  for task_id in "${task_ids[@]}"; do
    task_executor_execute_task_state "$task_id" --timeout "$timeout" --retries "$retries" ${dry_run:+--dry-run} ${auto_cleanup:+--auto-cleanup}
  done
}

_task_executor_usage() {
  cat <<'EOF'
Usage:
  task-executor.sh plan --spec <file> [--profiles path] [--limit N] [--priority LEVEL]
  task-executor.sh run  --spec <file> [options]
  task-executor.sh run-task <task_id> [options]
  task-executor.sh list
  task-executor.sh show <task_id>

Run options:
  --profiles <path>   Path to AI profiles YAML (default: config/ai-profiles.yaml)
  --limit <N>         Limit number of tasks generated from spec
  --priority <level>  Filter tasks by priority label (e.g., P0, High, Medium)
  --timeout <sec>     Override execution timeout (default: 900)
  --retries <N>       Override retry attempts (default: 3)
  --dry-run           Skip agent invocation (state updates only)
  --auto-cleanup      Cleanup worktree after successful execution
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    _task_executor_usage
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
    plan)
      spec=""
      plan_args=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --spec)
            spec="$2"; shift 2 ;;
          --profiles|--limit|--priority)
            plan_args+=("$1" "$2"); shift 2 ;;
          *)
            echo "ERROR: Unknown option for plan: $1" >&2
            exit 1 ;;
        esac
      done
      if [[ -z "$spec" ]]; then
        echo "ERROR: --spec is required" >&2
        exit 1
      fi
      mapfile -t planned_ids < <(task_executor_plan_spec "$spec" "${plan_args[@]}")
      if [[ ${#planned_ids[@]} -eq 0 ]]; then
        echo "No tasks generated."
      else
        printf 'Registered tasks:\n'
        for tid in "${planned_ids[@]}"; do
          state_json=$(task_state_get_json "$tid")
          ai=$(printf '%s' "$state_json" | jq -r '.primary_ai // "n/a"')
          title=$(printf '%s' "$state_json" | jq -r '.description // .title // ""' | cut -c1-80)
          printf '  %-28s -> %-8s %s\n' "$tid" "$ai" "$title"
        done
      fi
      ;;
    run)
      spec=""
      run_args=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --spec)
            spec="$2"; shift 2 ;;
          --profiles|--limit|--priority|--timeout|--retries)
            run_args+=("$1" "$2"); shift 2 ;;
          --dry-run|--auto-cleanup)
            run_args+=("$1"); shift ;;
          *)
            echo "ERROR: Unknown option for run: $1" >&2
            exit 1 ;;
        esac
      done
      if [[ -z "$spec" ]]; then
        echo "ERROR: --spec is required" >&2
        exit 1
      fi
      task_executor_run_spec "$spec" "${run_args[@]}"
      ;;
    run-task)
      if [[ $# -lt 1 ]]; then
        echo "ERROR: run-task requires a task_id" >&2
        exit 1
      fi
      task_id="$1"
      shift
      task_executor_execute_task_state "$task_id" "$@"
      ;;
    list)
      task_state_list
      ;;
    show)
      if [[ $# -lt 1 ]]; then
        echo "ERROR: show requires a task_id" >&2
        exit 1
      fi
      task_state_print "$1"
      ;;
    --help|-h|help)
      _task_executor_usage
      ;;
    *)
      echo "ERROR: Unknown command: $command" >&2
      _task_executor_usage
      exit 1
      ;;
  esac
fi

