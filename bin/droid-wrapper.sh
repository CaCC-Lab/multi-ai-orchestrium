#!/usr/bin/env bash
set -euo pipefail
# droid-wrapper.sh - MCP wrapper for Droid (Enterprise AI Engineer)
# 既定は安全に `droid exec --auto high "<task>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Droid"

# Droid CLI command (dynamic quality argument handled in run_droid)
AI_COMMAND=("droid" "exec" "--auto")

# AGENTS.md統合: タスク分類により動的調整（軽量: 90s, 標準: 180s, 重要: 540s）
# - デフォルト: 180秒（3分） - エンタープライズ品質実装に最適
# - 根拠: Droid実測平均180秒、AGENTS.md base設定に準拠
# - 上書き: export DROID_MCP_TIMEOUT=600s（10分に延長）
# - 複雑な実装タスクには長めの設定を推奨
BASE_TIMEOUT="${DROID_MCP_TIMEOUT:-180}"

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
droid-wrapper.sh - MCP wrapper for Droid (Enterprise AI Engineer)
Usage:
  droid-wrapper.sh --task "implementation task"
  echo "implementation task" | droid-wrapper.sh --stdin
Arguments:
  <task>              : The implementation task to process

Options:
  --task TEXT         : task text (default -> droid exec --auto high)
  --prompt TEXT       : alias for --task
  --stdin             : read task from stdin (flag)
  --non-interactive   : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH    : cd before run
  --quality LEVEL     : quality level (low|medium|high, default: high)
  --raw ARGS...       : pass-through to droid (expert)

Env:
  DROID_MCP_TIMEOUT   : e.g. 240s (default 180s), customizable timeout

Droid Role:
  - Enterprise AI Engineer
  - Production-grade implementation (180s average)
  - Full type hints, error handling, logging, documentation
  - Security checks and performance optimization
  - Auto-validation and best practices enforcement
USAGE
  exit 0
fi

# ============================================================================
# Argument Parsing (Droid-specific + common)
# ============================================================================

TASK=""
QUALITY="high"

# Parse Droid-specific arguments first
TEMP_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)    shift; TASK="${1:-}"; shift || true; continue;;
    --quality) shift; QUALITY="${1:-high}"; shift || true; continue;;
    *)         TEMP_ARGS+=("$1"); shift || true; continue;;
  esac
done

# Restore arguments for common parser
set -- "${TEMP_ARGS[@]}"

# Use common wrapper_parse_args for remaining arguments
wrapper_parse_args "$@"

# Merge --prompt into TASK if provided (common parser uses PROMPT)
if [[ -n "$PROMPT" ]]; then
  TASK="$PROMPT"
fi

# ============================================================================
# Workspace Setup
# ============================================================================

if [[ -n "$WORKSPACE" ]]; then
    cd "$WORKSPACE"
fi

# ============================================================================
# Droid-Specific Execution Logic
# ============================================================================

run_droid() {
  local task="$1"
  local final_timeout="${BASE_TIMEOUT}s"
  local final_quality="$QUALITY"
  local start_time
  start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "Droid" "$task" "$final_timeout"
  fi

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${DROID_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$task")

    # Get dynamic timeout (base: 180s for Droid)
    final_timeout=$(get_task_timeout "$classification" 180)

    # Adjust quality based on task classification (if not explicitly set by user)
    if [[ "$QUALITY" == "high" ]]; then
      case "$classification" in
        lightweight)
          final_quality="medium"
          ;;
        standard|critical)
          final_quality="high"
          ;;
      esac
    fi

    # VibeLogger: Log quality selection
    if command -v vibe_log >/dev/null 2>&1; then
      vibe_log "wrapper.config" "droid_quality_select" \
        "{\"quality\": \"$final_quality\"}" \
        "Droid品質レベル: $final_quality" \
        "configure_quality,execute_task" \
        "Droid"
    fi

    # Log classification
    local process_label
    process_label=$(get_process_label "$classification")
    echo "[$process_label] Timeout: $final_timeout, Quality: $final_quality" >&2

    # Check approval requirement using common function
    wrapper_check_approval "$classification" "$task" "Droid" "$start_time" || exit 1
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time
  end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "Droid" "success" "$duration" "0"
  fi

  # Build full command with quality argument
  local full_command=("${AI_COMMAND[@]}" "$final_quality" "$task")

  # Apply timeout using common function
  wrapper_apply_timeout "$final_timeout" "${full_command[@]}"
}

# ============================================================================
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to droid)
if wrapper_handle_raw_args; then
    exit 0
fi

# Handle stdin input
if wrapper_handle_stdin; then
    TASK="$INPUT"
fi

# Validate we have a task
if [[ -z "$TASK" ]]; then
    echo "No input provided (stdin empty and no --task)" >&2
    exit 1
fi

# Run Droid with quality-aware logic
run_droid "$TASK"
