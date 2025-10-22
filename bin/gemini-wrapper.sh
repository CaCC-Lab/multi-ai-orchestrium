#!/usr/bin/env bash
set -euo pipefail
# gemini-wrapper.sh - MCP wrapper for Gemini CLI
# 既定は安全に `gemini -p "<prompt>"` を実行

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

# AGENTS.md統合: タスク分類により動的調整（軽量: 12s, 標準: 25s, 重要: 75s）
# - デフォルト: 25秒 - Web検索最適化
# - 根拠: AGENTS.md base設定に準拠
# - 上書き: export GEMINI_MCP_TIMEOUT=60s（1分に延長）
TIMEOUT="${GEMINI_MCP_TIMEOUT:-25s}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
gemini-wrapper.sh - MCP wrapper for Gemini CLI
Usage:
  gemini-wrapper.sh --prompt "your prompt"
  echo "your prompt" | gemini-wrapper.sh --stdin
Arguments:
  <prompt>          : The prompt text to process

Options:
  --prompt TEXT     : prompt text (string)
  --stdin           : read prompt from stdin (flag)
  --non-interactive : skip approval prompts for critical tasks (auto-approve)
  --raw ARGS...     : pass-through args to gemini

Env:
  GEMINI_MCP_TIMEOUT : e.g. 25s / 40s (default 25s)
USAGE
  exit 0
fi

PROMPT=""
NON_INTERACTIVE=false
RAW=()
MODE_IN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)         shift; PROMPT="${1:-}";;
    --stdin)          MODE_IN="stdin";;
    --non-interactive) NON_INTERACTIVE=true;;
    --raw)            shift; RAW+=("$@"); break;;
    *)                RAW+=("$1");;
  esac
  shift || true
done

run_gemini() {
  local prompt="$1"
  local final_timeout="$TIMEOUT"
  local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "Gemini" "$prompt" "$final_timeout"
  fi

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${GEMINI_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$prompt")

    # Get dynamic timeout (base: 25s for Gemini)
    final_timeout=$(get_task_timeout "$classification" 25)

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
          exit 1
        fi
      fi
    fi
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "Gemini" "success" "$duration" "0"
  fi

  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$final_timeout" gemini -p "$prompt" -y "${RAW[@]}"
  else
    exec gemini -p "$prompt" -y "${RAW[@]}"
  fi
}

if [[ -n "$PROMPT" ]]; then
  run_gemini "$PROMPT"
elif [[ "$MODE_IN" == "stdin" ]]; then
  read -r -d '' INPUT || true
  if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
    echo "No input provided (stdin empty and no --prompt)" >&2
    exit 1
  fi
  run_gemini "$INPUT"
else
  # Try reading from stdin anyway
  read -r -d '' INPUT || true
  if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
    echo "No input provided (stdin empty and no --prompt)" >&2
    exit 1
  fi
  run_gemini "$INPUT"
fi