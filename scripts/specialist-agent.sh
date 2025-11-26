#!/usr/bin/env bash
# specialist-agent.sh - 7AI（Claude/Gemini/Amp/Qwen/Droid/Codex/Cursor）用統一インターフェース
# SpecialistAgentシステム: エージェントラッパー (TaskRouter/AgentMatcherと統合)

set -euo pipefail

SPECIALIST_AGENT_VERSION="1.0.0"

# Note: This library expects SCRIPT_DIR and PROJECT_ROOT to be defined by the calling script
if [[ -z "${SCRIPT_DIR:-}" || -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: SCRIPT_DIR and PROJECT_ROOT must be defined before sourcing specialist-agent.sh" >&2
  exit 1
fi

#---------------------------------------------------------------------
# 依存スクリプト読込
#---------------------------------------------------------------------
source "$SCRIPT_DIR/lib/task-state.sh" 2>/dev/null || {
  echo "ERROR: Missing task-state.sh library" >&2
  exit 1
}

source "$PROJECT_ROOT/config/ai-env.sh" 2>/dev/null || true

#---------------------------------------------------------------------
# 定数定義
#---------------------------------------------------------------------
SUPPORTED_AGENTS=("claude" "gemini" "amp" "qwen" "droid" "codex" "cursor")
TASK_STATUS_PENDING="pending"
TASK_STATUS_RUNNING="running"
TASK_STATUS_COMPLETED="completed"
TASK_STATUS_FAILED="failed"

#---------------------------------------------------------------------
# ヘルプ情報
#---------------------------------------------------------------------
_specialist_agent_usage() {
  cat <<'EOF'
Usage:
  specialist-agent.sh execute <agent_name> <task_id> [options]

Commands:
  execute     Execute a task with a specific AI agent
  status      Check the status of a task
  list        List all active tasks
  cleanup     Cleanup task resources

Options:
  --task-desc <description>   Task description
  --worktree-path <path>      Worktree directory path
  --timeout <seconds>         Timeout for execution (default: 1800)
  --retry <count>             Retry count (default: 0)
  --help                      Show this help

Examples:
  specialist-agent.sh execute qwen task-001 --task-desc "Implement login API"
  specialist-agent.sh status task-001

Exit codes:
  0 on success, non-zero on failure.
EOF
}

#---------------------------------------------------------------------
# 内部ユーティリティ関数
#---------------------------------------------------------------------

# パストラバーサル防止
validate_input() {
  local input="$1"
  if [[ "$input" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected: $input" >&2
    return 1
  fi
  # シェルインジェクション防止
  if [[ "$input" =~ [\$\<\>\&\|\`] ]] || [[ "$input" == *";"* ]]; then
    echo "ERROR: Invalid characters detected: $input" >&2
    return 1
  fi
  echo "$input" | tr -cd '[:alnum:]-_./'
}

# AI名のバリデーション
validate_agent_name() {
  local agent_name="$1"
  for supported_agent in "${SUPPORTED_AGENTS[@]}"; do
    if [[ "$agent_name" == "$supported_agent" ]]; then
      return 0
    fi
  done
  echo "ERROR: Unsupported agent name: $agent_name" >&2
  echo "Supported agents: ${SUPPORTED_AGENTS[*]}" >&2
  return 1
}

# タスク状態の初期化
initialize_task_state() {
  local task_id="$1"
  local agent_name="$2"
  local task_desc="$3"
  
  task_state_set "$task_id" "agent" "$agent_name"
  task_state_set "$task_id" "description" "$task_desc"
  task_state_set "$task_id" "status" "$TASK_STATUS_PENDING"
  task_state_set "$task_id" "created_at" "$(date -Iseconds)"
  task_state_set "$task_id" "attempts" "0"
  task_state_set "$task_id" "last_error" ""
}

#---------------------------------------------------------------------
# AI実行ラッパー関数
#---------------------------------------------------------------------

# Claude実行
execute_claude() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/claude-review.sh" ]]; then
    echo "ERROR: claude-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/claude-review.sh" "$task_desc"
}

# Gemini実行
execute_gemini() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/gemini-review.sh" ]]; then
    echo "ERROR: gemini-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/gemini-review.sh" "$task_desc"
}

# Amp実行
execute_amp() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/amp-review.sh" ]]; then
    echo "ERROR: amp-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/amp-review.sh" "$task_desc"
}

# Qwen実行
execute_qwen() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/qwen-review.sh" ]]; then
    echo "ERROR: qwen-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/qwen-review.sh" "$task_desc"
}

# Droid実行
execute_droid() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/droid-review.sh" ]]; then
    echo "ERROR: droid-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/droid-review.sh" "$task_desc"
}

# Codex実行
execute_codex() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/codex-review.sh" ]]; then
    echo "ERROR: codex-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/codex-review.sh" "$task_desc"
}

# Cursor実行
execute_cursor() {
  local worktree_path="$1"
  local task_desc="$2"
  
  if [[ ! -f "$SCRIPT_DIR/cursor-review.sh" ]]; then
    echo "ERROR: cursor-review.sh script not found" >&2
    return 1
  fi
  
  cd "$worktree_path"
  "$SCRIPT_DIR/cursor-review.sh" "$task_desc"
}

# 一括実行ディスパッチャー
execute_agent() {
  local agent_name="$1"
  local worktree_path="$2"
  local task_desc="$3"
  
  case "$agent_name" in
    claude)
      execute_claude "$worktree_path" "$task_desc"
      ;;
    gemini)
      execute_gemini "$worktree_path" "$task_desc"
      ;;
    amp)
      execute_amp "$worktree_path" "$task_desc"
      ;;
    qwen)
      execute_qwen "$worktree_path" "$task_desc"
      ;;
    droid)
      execute_droid "$worktree_path" "$task_desc"
      ;;
    codex)
      execute_codex "$worktree_path" "$task_desc"
      ;;
    cursor)
      execute_cursor "$worktree_path" "$task_desc"
      ;;
    *)
      echo "ERROR: Unknown agent: $agent_name" >&2
      return 1
      ;;
  esac
}

#---------------------------------------------------------------------
# メイン実行関数
#---------------------------------------------------------------------

# タスク実行
specialist_agent_execute() {
  local agent_name="$1"
  local task_id="$2"
  local task_desc=""
  local worktree_path=""
  local timeout=1800
  local retry_count=0

  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-desc)
        task_desc="$2"; shift 2
        ;;
      --worktree-path)
        worktree_path="$2"; shift 2
        ;;
      --timeout)
        timeout="$2"; shift 2
        ;;
      --retry)
        retry_count="$2"; shift 2
        ;;
      --help)
        _specialist_agent_usage
        return 0
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        _specialist_agent_usage >&2
        return 1
        ;;
    esac
  done

  # 入力バリデーション
  if [[ -z "$agent_name" || -z "$task_id" || -z "$worktree_path" ]]; then
    echo "ERROR: agent_name, task_id, and worktree_path are required" >&2
    return 1
  fi

  agent_name=$(validate_input "$agent_name")
  task_id=$(validate_input "$task_id")
  worktree_path=$(validate_input "$worktree_path")

  if ! validate_agent_name "$agent_name"; then
    return 1
  fi

  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: Worktree path does not exist: $worktree_path" >&2
    return 1
  fi

  # タスク状態の初期化
  initialize_task_state "$task_id" "$agent_name" "$task_desc"

  # タスク実行開始
  task_state_set "$task_id" "status" "$TASK_STATUS_RUNNING"
  task_state_set "$task_id" "started_at" "$(date -Iseconds)"
  
  echo "INFO: Starting execution for task $task_id using $agent_name in $worktree_path"
  
  # 実行をサブシェルでタイムアウト制御
  local execution_result=0
  local attempt=0
  local error_msg=""
  
  while [[ $attempt -le $retry_count ]]; do
    ((attempt++))
    
    # リトライの場合は状態をリセット
    if [[ $attempt -gt 1 ]]; then
      echo "INFO: Attempt $attempt of $((retry_count + 1)) for task $task_id"
    fi
    
    # 時間制限付きで実行
    if timeout "$timeout" bash -c "
      cd '$worktree_path' || exit 1
      execute_agent '$agent_name' '$worktree_path' '$task_desc'
    " 2>&1; then
      execution_result=0
      break
    else
      execution_result=$?
      error_msg="Execution failed with exit code $execution_result"
      echo "WARNING: Attempt $attempt failed for task $task_id: $error_msg" >&2
      
      if [[ $attempt -lt $((retry_count + 1)) ]]; then
        sleep 5  # リトライ前に少し待機
      fi
    fi
  done
  
  # アトtempts数を更新
  task_state_set "$task_id" "attempts" "$attempt"
  
  if [[ $execution_result -eq 0 ]]; then
    # 成功
    task_state_set "$task_id" "status" "$TASK_STATUS_COMPLETED"
    task_state_set "$task_id" "completed_at" "$(date -Iseconds)"
    task_state_set "$task_id" "last_error" ""
    echo "INFO: Task $task_id completed successfully"
  else
    # 失敗
    task_state_set "$task_id" "status" "$TASK_STATUS_FAILED"
    task_state_set "$task_id" "completed_at" "$(date -Iseconds)"
    task_state_set "$task_id" "last_error" "$error_msg"
    echo "ERROR: Task $task_id failed after $attempt attempt(s): $error_msg" >&2
  fi
  
  return $execution_result
}

# タスク状態確認
specialist_agent_status() {
  local task_id="$1"
  
  task_id=$(validate_input "$task_id")
  
  local status
  status=$(task_state_get "$task_id" "status" 2>/dev/null || echo "unknown")
  
  if [[ "$status" == "unknown" ]]; then
    echo "Task $task_id not found"
    return 1
  fi
  
  echo "Task $task_id status: $status"
  task_state_print "$task_id"
}

# アクティブタスクリスト
specialist_agent_list() {
  task_state_list
}

# タスククリーンアップ
specialist_agent_cleanup() {
  local task_id="$1"
  
  task_id=$(validate_input "$task_id")
  
  if task_state_exists "$task_id"; then
    task_state_remove "$task_id"
    echo "Task $task_id cleaned up"
  else
    echo "Task $task_id not found"
    return 1
  fi
}

#---------------------------------------------------------------------
# CLIエントリーポイント
#---------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    _specialist_agent_usage
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
    execute)
      if [[ $# -lt 2 ]]; then
        _specialist_agent_usage
        exit 1
      fi
      agent_name="$1"
      task_id="$2"
      shift 2
      specialist_agent_execute "$agent_name" "$task_id" "$@"
      ;;
    status)
      if [[ $# -lt 1 ]]; then
        _specialist_agent_usage
        exit 1
      fi
      task_id="$1"
      specialist_agent_status "$task_id"
      ;;
    list)
      specialist_agent_list
      ;;
    cleanup)
      if [[ $# -lt 1 ]]; then
        _specialist_agent_usage
        exit 1
      fi
      task_id="$1"
      specialist_agent_cleanup "$task_id"
      ;;
    --help|-h|help)
      _specialist_agent_usage
      ;;
    --version)
      echo "specialist-agent.sh v${SPECIALIST_AGENT_VERSION}"
      ;;
    *)
      echo "ERROR: Unknown command: $command" >&2
      _specialist_agent_usage >&2
      exit 1
      ;;
  esac
fi