#!/usr/bin/env bash
set -euo pipefail
# cursor-wrapper.sh - MCP wrapper for Cursor Agent CLI
# 既定は安全に `cursor-agent --print "<task>"` を実行

# Load AGENTS.md task classification utilities (portable path resolution)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/agents-utils.sh" ]]; then
    source "$SCRIPT_DIR/agents-utils.sh"
    AGENTS_ENABLED=true
else
    AGENTS_ENABLED=false
fi

# Load VibeLogger library
if [[ -f "$SCRIPT_DIR/vibe-logger-lib.sh" ]]; then
    source "$SCRIPT_DIR/vibe-logger-lib.sh"
else
    echo "WARNING: VibeLogger library not found, logging disabled" >&2
fi

# AGENTS.md統合: タスク分類により動的調整（軽量: 30s, 標準: 60s, 重要: 180s）
# - デフォルト: 60秒（1分） - 標準実行に最適
# - 根拠: AGENTS.md標準設定に準拠
# - 上書き: export CURSOR_MCP_TIMEOUT=600s（10分に延長可能）
# - 参照: CURSOR_TIMEOUT_INVESTIGATION_REPORT.md
TIMEOUT="${CURSOR_MCP_TIMEOUT:-60s}"

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
  CURSOR_MCP_TIMEOUT  : e.g. 600s (default 60s), customizable timeout
USAGE
  exit 0
fi

PROMPT=""
NON_INTERACTIVE=false
WORKSPACE=""
RAW=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)          shift; PROMPT="${1:-}";;
    --stdin)           : ;;
    --non-interactive) NON_INTERACTIVE=true;;
    --workspace)       shift; WORKSPACE="${1:-}";;
    --raw)             shift; RAW+=("$@"); break;;
    *)                 RAW+=("$1");;
  esac
  shift || true
done

if [[ -n "$WORKSPACE" ]]; then
  cd "$WORKSPACE"
fi

run_cursor() {
  local prompt="$1"
  local final_timeout="$TIMEOUT"
  local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

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

    # Check approval requirement
    if requires_approval "$classification"; then
      echo "⚠️  CRITICAL TASK: Approval recommended before execution" >&2
      echo "Prompt: $prompt" >&2

      # Determine if running in non-interactive mode
      local is_non_interactive=false

      # 1. Environment variable override
      if [[ "${WRAPPER_NON_INTERACTIVE:-}" == "1" ]]; then
        is_non_interactive=true
      fi

      # 2. Auto-detect CI/MCP environment (no TTY on stdin and stderr)
      # Disabled: Only use explicit settings to allow piped input
      # if [[ ! -t 1 ]] if [[ ! -t 1 ]] && [[ ! -t 2 ]]; thenif [[ ! -t 1 ]] && [[ ! -t 2 ]]; then [[ ! -t 2 ]]; then
      #   is_non_interactive=true
      # fi

      # 3. Check --non-interactive flag
      if [[ "$NON_INTERACTIVE" == "true" ]]; then
        is_non_interactive=true
      fi

      if [[ "$is_non_interactive" == "true" ]]; then
        echo "⚠️  Running in non-interactive mode - CRITICAL task auto-approved" >&2
        echo "⚠️  Set WRAPPER_NON_INTERACTIVE=0 to require manual confirmation" >&2
      else
        read -p "Continue? [y/N] " -n 1 -r >&2
        echo >&2
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "Execution cancelled by user" >&2

          # VibeLogger: Log user cancellation
          if command -v vibe_wrapper_done >/dev/null 2>&1; then
            local end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
            local duration=$((end_time - start_time))
            vibe_wrapper_done "Cursor" "cancelled" "$duration" "1"
          fi

          exit 1
        fi
      fi
    fi
  fi

  # Cursor timeout対策: デフォルトモデル明示的指定（CURSOR_TIMEOUT_INVESTIGATION_REPORT.md参照）
  DEFAULT_MODEL="${CURSOR_DEFAULT_MODEL:-sonnet-4.5}"

  # VibeLogger: Log model selection
  if command -v vibe_log >/dev/null 2>&1; then
    vibe_log "wrapper.config" "cursor_model_select" \
      "{\"model\": \"$DEFAULT_MODEL\"}" \
      "Cursorモデル選択: $DEFAULT_MODEL" \
      "validate_model,execute_request" \
      "Cursor"
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "Cursor" "success" "$duration" "0"
  fi

  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$final_timeout" cursor-agent --model "$DEFAULT_MODEL" --print "$prompt"
  else
    exec cursor-agent --model "$DEFAULT_MODEL" --print "$prompt"
  fi
}

if [[ ${#RAW[@]} -gt 0 ]]; then
  # Cursor timeout対策: デフォルトモデル明示的指定（CURSOR_TIMEOUT_INVESTIGATION_REPORT.md参照）
  DEFAULT_MODEL="${CURSOR_DEFAULT_MODEL:-sonnet-4.5}"
  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$TIMEOUT" cursor-agent --model "$DEFAULT_MODEL" "${RAW[@]}"
  else
    exec cursor-agent --model "$DEFAULT_MODEL" "${RAW[@]}"
  fi
fi

if [[ -n "$PROMPT" ]]; then
  run_cursor "$PROMPT"
fi

read -r -d '' INPUT || true
if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
  echo "No input provided (stdin empty and no --prompt)" >&2
  exit 1
fi
run_cursor "$INPUT"
