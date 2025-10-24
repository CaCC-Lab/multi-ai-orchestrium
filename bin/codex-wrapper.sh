#!/usr/bin/env bash
set -euo pipefail
# codex-wrapper.sh - MCP wrapper for Codex CLI
# 既定は安全に `codex exec "<prompt>"` を実行

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

# AGENTS.md統合: タスク分類により動的調整（軽量: 45s, 標準: 90s, 重要: 270s）
# - デフォルト: 90秒（1.5分） - 深い分析に最適
# - 根拠: AGENTS.md base設定に準拠
# - 上書き: export CODEX_MCP_TIMEOUT=600s（10分に延長可能）
TIMEOUT="${CODEX_MCP_TIMEOUT:-90s}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
codex-wrapper.sh - MCP wrapper for Codex CLI
Usage:
  codex-wrapper.sh --prompt "your task"
  echo "your task" | codex-wrapper.sh --stdin
Arguments:
  <prompt>          : The task text to process

Options:
  --prompt TEXT     : task text (default -> codex exec)
  --stdin           : read task from stdin (flag)
  --non-interactive : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH  : cd before run
  --raw ARGS...     : pass-through to codex (expert)

Env:
  CODEX_MCP_TIMEOUT : e.g. 600s (default 90s), customizable timeout
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

run_codex() {
  local prompt="$1"
  local final_timeout="$TIMEOUT"
  local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "Codex" "$prompt" "$final_timeout"
  fi

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${CODEX_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$prompt")

    # Get dynamic timeout (base: 90s for Codex)
    final_timeout=$(get_task_timeout "$classification" 90)

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
      # if [[ ! -t 1 ]] && [[ ! -t 2 ]]; then
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
            vibe_wrapper_done "Codex" "cancelled" "$duration" "1"
          fi

          exit 1
        fi
      fi
    fi
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "Codex" "success" "$duration" "0"
  fi

  # Timeout strategy: Use outer timeout when called from workflow, inner timeout for standalone execution
  if [[ "${WRAPPER_SKIP_TIMEOUT:-}" == "1" ]]; then
    # Called from workflow (multi-ai-ai-interface.sh) - outer timeout manages execution
    # Use exec to replace wrapper process with AI command so timeout works correctly
    exec codex exec "$prompt"
  else
    # Standalone execution - use wrapper-defined timeout from AGENTS.md classification
    if command -v timeout >/dev/null 2>&1; then
      timeout_arg="$final_timeout"
      if command -v to_seconds >/dev/null 2>&1; then
        timeout_arg="$(to_seconds "$final_timeout")"
      fi
      exec timeout "$timeout_arg" codex exec "$prompt"
    else
      exec codex exec "$prompt"
    fi
  fi
}

if [[ ${#RAW[@]} -gt 0 ]]; then
  # Respect WRAPPER_SKIP_TIMEOUT for consistency with other execution paths
  if [[ "${WRAPPER_SKIP_TIMEOUT:-}" == "1" ]]; then
    # Called from workflow - outer timeout manages execution
    exec codex "${RAW[@]}"
  else
    if command -v timeout >/dev/null 2>&1; then
      timeout_arg="$TIMEOUT"
      if command -v to_seconds >/dev/null 2>&1; then
        timeout_arg="$(to_seconds "$TIMEOUT")"
      fi
      exec timeout "$timeout_arg" codex "${RAW[@]}"
    else
      exec codex "${RAW[@]}"
    fi
  fi
fi

if [[ -n "$PROMPT" ]]; then
  run_codex "$PROMPT"
fi

read -r -d '' INPUT || true
if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
  echo "No input provided (stdin empty and no --prompt)" >&2
  exit 1
fi
run_codex "$INPUT"
