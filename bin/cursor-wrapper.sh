#!/usr/bin/env bash
set -euo pipefail
# cursor-wrapper.sh - MCP wrapper for Cursor Agent CLI
# 既定は安全に `cursor-agent --print "<task>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Cursor"

# Cursor CLI command (dynamic model argument handled in run_cursor)
AI_COMMAND=("cursor-agent" "--print")

# AGENTS.md統合: タスク分類により動的調整（軽量: 30s, 標準: 60s, 重要: 180s）
# - デフォルト: 60秒（1分） - 標準実行に最適
# - 根拠: AGENTS.md標準設定に準拠
# - 上書き: export CURSOR_MCP_TIMEOUT=600s（10分に延長可能）
# - 参照: CURSOR_TIMEOUT_INVESTIGATION_REPORT.md
BASE_TIMEOUT="${CURSOR_MCP_TIMEOUT:-60}"

# ============================================================================
# Load Common Wrapper Library
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/common-wrapper-lib.sh" ]]; then
    echo "ERROR: common-wrapper-lib.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

source "$SCRIPT_DIR/common-wrapper-lib.sh"

# ============================================================================
# Initialize Dependencies
# ============================================================================

wrapper_load_dependencies

# ============================================================================
# Help Text
# ============================================================================

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
cursor-wrapper.sh - MCP wrapper for Cursor Agent CLI
Usage:
  cursor-wrapper.sh --prompt "your task"
  echo "your task" | cursor-wrapper.sh --stdin
Arguments:
  <task>              : The task text to process

Options:
  --prompt TEXT       : task text (default -> cursor-agent --print)
  --stdin             : read task from stdin (flag)
  --non-interactive   : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH    : cd before run
  --raw ARGS...       : pass-through to cursor-agent (expert)

Env:
  CURSOR_MCP_TIMEOUT      : e.g. 600s (default 60s), customizable timeout
  CURSOR_DEFAULT_MODEL    : e.g. sonnet-4.5 (default), model selection
USAGE
  exit 0
fi

# ============================================================================
# Argument Parsing
# ============================================================================

wrapper_parse_args "$@"

# ============================================================================
# Workspace Setup
# ============================================================================

if [[ -n "$WORKSPACE" ]]; then
    cd "$WORKSPACE"
fi

# ============================================================================
# Cursor-Specific Execution Logic
# ============================================================================

run_cursor() {
  local prompt="$1"
  local final_timeout="${BASE_TIMEOUT}s"
  local start_time
  start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "Cursor" "$prompt" "$final_timeout"
  fi

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${CURSOR_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$prompt")

    # Get dynamic timeout (base: 60s for Cursor)
    final_timeout=$(get_task_timeout "$classification" 60)

    # Log classification
    local process_label
    process_label=$(get_process_label "$classification")
    echo "[$process_label] Timeout: $final_timeout" >&2

    # Check approval requirement using common function
    wrapper_check_approval "$classification" "$prompt" "Cursor" "$start_time" || exit 1
  fi

  # Cursor timeout対策: デフォルトモデル明示的指定（CURSOR_TIMEOUT_INVESTIGATION_REPORT.md参照）
  local default_model="${CURSOR_DEFAULT_MODEL:-sonnet-4.5}"

  # VibeLogger: Log model selection
  if command -v vibe_log >/dev/null 2>&1; then
    vibe_log "wrapper.config" "cursor_model_select" \
      "{\"model\": \"$default_model\"}" \
      "Cursorモデル選択: $default_model" \
      "validate_model,execute_request" \
      "Cursor"
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time
  end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "Cursor" "success" "$duration" "0"
  fi

  # Build full command with model argument
  local full_command=("cursor-agent" "--model" "$default_model" "--print" "$prompt")

  # Apply timeout using common function
  wrapper_apply_timeout "$final_timeout" "${full_command[@]}"
}

# ============================================================================
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to cursor-agent with default model)
if [[ ${#RAW[@]} -gt 0 ]]; then
    # Cursor timeout対策: デフォルトモデル明示的指定
    DEFAULT_MODEL="${CURSOR_DEFAULT_MODEL:-sonnet-4.5}"

    # Update AI_COMMAND with model
    AI_COMMAND=("cursor-agent" "--model" "$DEFAULT_MODEL")

    if wrapper_handle_raw_args; then
        exit 0
    fi
fi

# Handle stdin input
if wrapper_handle_stdin; then
    PROMPT="$INPUT"
fi

# Validate we have a prompt
if [[ -z "$PROMPT" ]]; then
    echo "No input provided (stdin empty and no --prompt)" >&2
    exit 1
fi

# Run Cursor with model-aware logic
run_cursor "$PROMPT"
