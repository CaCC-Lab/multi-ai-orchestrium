#!/usr/bin/env bash
set -euo pipefail
# qwen-wrapper.sh - MCP wrapper for Qwen Code CLI
# 既定は安全に `qwen -p "<prompt>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Qwen"

# Qwen CLI command array (with auto-approve flag)
AI_COMMAND=("qwen" "-y")

# AGENTS.md統合: タスク分類により動的調整（軽量: 30s, 標準: 60s, 重要: 180s）
# - デフォルト: 60秒（1分） - 高速実装に最適
# - 根拠: AGENTS.md標準設定に準拠
# - 上書き: export QWEN_MCP_TIMEOUT=600（10分に延長可能）
BASE_TIMEOUT="${QWEN_MCP_TIMEOUT:-60}"

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
    wrapper_generate_help "$AI_NAME" "qwen"
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
# CLI Binary Detection
# ============================================================================

# Allow overriding Qwen CLI location
QWEN_BIN="${QWEN_BIN:-qwen}"
if ! command -v "$QWEN_BIN" >/dev/null 2>&1; then
    for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin" "/opt/qwen/bin"; do
        if [[ -x "$dir/qwen" ]]; then
            QWEN_BIN="$dir/qwen"
            break
        fi
    done
fi

# Update AI_COMMAND with detected binary (keep -y flag)
AI_COMMAND=("$QWEN_BIN" "-y")

# ============================================================================
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to qwen)
if wrapper_handle_raw_args; then
    exit 0
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

# Run AI with common wrapper logic
# Note: Qwen uses custom command format: qwen -p "prompt" -y
# Override the standard wrapper_run_ai behavior for Qwen-specific format
run_qwen_with_wrapper_logic() {
  local ai_name="$1"
  local prompt="$2"
  local base_timeout="$3"
  shift 3
  local ai_command=("$@")

  local final_timeout="${base_timeout}s"
  local start_time
  start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "$ai_name" "$prompt" "$final_timeout"
  fi

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${QWEN_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$prompt")

    # Get dynamic timeout based on classification
    final_timeout=$(get_task_timeout "$classification" "$base_timeout")

    # Log classification
    local process_label
    process_label=$(get_process_label "$classification")
    echo "[$process_label] Timeout: $final_timeout" >&2

    # Check approval requirement
    wrapper_check_approval "$classification" "$prompt" "$ai_name" "$start_time" || exit 1
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time
  end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "$ai_name" "success" "$duration" "0"
  fi

  # Execute Qwen with -p flag (Qwen-specific format)
  wrapper_apply_timeout "$final_timeout" "${ai_command[@]}" -p "$prompt"
}

run_qwen_with_wrapper_logic "$AI_NAME" "$PROMPT" "$BASE_TIMEOUT" "${AI_COMMAND[@]}"
