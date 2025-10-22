#!/usr/bin/env bash
set -euo pipefail
# claude-wrapper.sh - MCP wrapper for Claude Code CLI
# 既定は安全に `claude -p "<prompt>"` を実行

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

# AGENTS.md統合: タスク分類により動的調整（軽量: 60s, 標準: 120s, 重要: 360s）
# - デフォルト: 120秒（2分） - 戦略/アーキテクチャ検討に最適
# - 根拠: Claude (CTO) の平均所要時間、AGENTS.md base設定に準拠
# - 上書き: export CLAUDE_MCP_TIMEOUT=600s（10分に延長可能）
TIMEOUT="${CLAUDE_MCP_TIMEOUT:-120s}"

# Allow overriding Claude CLI location
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin" "/opt/claude/bin"; do
    if [[ -x "$dir/claude" ]]; then
      CLAUDE_BIN="$dir/claude"
      break
    fi
  done
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
claude-wrapper.sh - MCP wrapper for Claude Code CLI
Usage:
  claude-wrapper.sh --prompt "your task"
  echo "your task" | claude-wrapper.sh --stdin
Arguments:
  <task>             : The task text to process

Options:
  --prompt TEXT      : task text (default -> claude -p)
  --stdin            : read task from stdin (flag)
  --non-interactive  : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH   : cd before run
  --raw ARGS...      : pass-through to claude (expert)

Env:
  CLAUDE_MCP_TIMEOUT : e.g. 600s (default 120s), customizable timeout
  CLAUDE_BIN         : path to Claude CLI binary (default: claude in PATH)
USAGE
  exit 0
fi

PROMPT=""
NON_INTERACTIVE=false
WORKSPACE=""
RAW=()
MODE_IN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)          shift; PROMPT="${1:-}";;
    --stdin)           MODE_IN="stdin";;
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

run_claude() {
  local prompt="$1"
  local final_timeout="$TIMEOUT"
  local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "Claude" "$prompt" "$final_timeout"
  fi

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${CLAUDE_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$prompt")

    # Get dynamic timeout (base: 120s for Claude)
    final_timeout=$(get_task_timeout "$classification" 120)

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
            vibe_wrapper_done "Claude" "cancelled" "$duration" "1"
          fi

          exit 1
        fi
      fi
    fi
  fi

  # VibeLogger: Log CLI detection
  if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
    if command -v vibe_log >/dev/null 2>&1; then
      vibe_log "wrapper.validation" "claude_cli_check" \
        "{\"cli_found\": true, \"path\": \"$CLAUDE_BIN\"}" \
        "Claude CLI検出: $CLAUDE_BIN" \
        "validate_cli,execute_command" \
        "Claude"
    fi
  else
    echo "Claude CLI not found (expected at '$CLAUDE_BIN'). Install @anthropic-ai/claude-code and run 'claude login'." >&2

    # VibeLogger: Log CLI not found error
    if command -v vibe_log >/dev/null 2>&1; then
      vibe_log "wrapper.error" "claude_cli_not_found" \
        "{\"cli_found\": false, \"path\": \"$CLAUDE_BIN\"}" \
        "Claude CLI未検出: $CLAUDE_BIN" \
        "install_cli,check_path,retry" \
        "Claude"
    fi

    return 127
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "Claude" "success" "$duration" "0"
  fi

  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$final_timeout" "$CLAUDE_BIN" -p "$prompt"
  else
    exec "$CLAUDE_BIN" -p "$prompt"
  fi
}

if [[ ${#RAW[@]} -gt 0 ]]; then
  if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
    echo "Claude CLI not found (expected at '$CLAUDE_BIN')." >&2
    exit 127
  fi

  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$TIMEOUT" "$CLAUDE_BIN" "${RAW[@]}"
  else
    exec "$CLAUDE_BIN" "${RAW[@]}"
  fi
fi

if [[ -n "$PROMPT" ]]; then
  run_claude "$PROMPT"
elif [[ "$MODE_IN" == "stdin" ]]; then
  read -r -d '' INPUT || true
  if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
    echo "No input provided (stdin empty and no --prompt)" >&2
    exit 1
  fi
  run_claude "$INPUT"
else
  # Try reading from stdin anyway
  read -r -d '' INPUT || true
  if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
    echo "No input provided (stdin empty and no --prompt)" >&2
    exit 1
  fi
  run_claude "$INPUT"
fi
