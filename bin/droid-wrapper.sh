#!/usr/bin/env bash
set -euo pipefail
# droid-wrapper.sh - MCP wrapper for Droid (Enterprise AI Engineer)
# 既定は安全に `droid exec --auto high "<task>"` を実行

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

# AGENTS.md統合: タスク分類により動的調整（軽量: 90s, 標準: 180s, 重要: 540s）
# - デフォルト: 180秒（3分） - エンタープライズ品質実装に最適
# - 根拠: Droid実測平均180秒、AGENTS.md base設定に準拠
# - 上書き: export DROID_MCP_TIMEOUT=600s（10分に延長）
# - 複雑な実装タスクには長めの設定を推奨
TIMEOUT="${DROID_MCP_TIMEOUT:-180s}"

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
  --stdin             : read task from stdin (flag)
  --non-interactive   : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH    : cd before run
  --quality LEVEL     : quality level (low|medium|high, default: high)
  --raw ARGS...       : pass-through to droid (expert)
  --prompt TEXT       : alias for --task

Env:
  DROID_MCP_TIMEOUT   : e.g. 240s (default), customizable timeout

Droid Role:
  - Enterprise AI Engineer
  - Production-grade implementation (180s average)
  - Full type hints, error handling, logging, documentation
  - Security checks and performance optimization
  - Auto-validation and best practices enforcement
USAGE
  exit 0
fi

TASK=""
NON_INTERACTIVE=false
WORKSPACE=""
QUALITY="high"
RAW=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task|--prompt)  shift; TASK="${1:-}";;
    --stdin)          : ;;
    --non-interactive) NON_INTERACTIVE=true;;
    --workspace)      shift; WORKSPACE="${1:-}";;
    --quality)        shift; QUALITY="${1:-high}";;
    --raw)            shift; RAW+=("$@"); break;;
    *)                RAW+=("$1");;
  esac
  shift || true
done

if [[ -n "$WORKSPACE" ]]; then
  cd "$WORKSPACE"
fi

run_droid () {
  local task="$1"
  local final_timeout="$TIMEOUT"
  local final_quality="$QUALITY"
  local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

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

    # Adjust quality based on task classification (if not explicitly set)
    if [[ "$QUALITY" == "high" ]]; then
      case "$classification" in
        lightweight)
          final_quality="medium"
          ;;
        standard)
          final_quality="high"
          ;;
        critical)
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

    # Check approval requirement
    if requires_approval "$classification"; then
      echo "⚠️  CRITICAL TASK: Approval recommended before execution" >&2
      echo "Prompt: $task" >&2

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
            vibe_wrapper_done "Droid" "cancelled" "$duration" "1"
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
    vibe_wrapper_done "Droid" "success" "$duration" "0"
  fi

  # Timeout strategy: Use outer timeout when called from workflow, inner timeout for standalone execution
  if [[ "${WRAPPER_SKIP_TIMEOUT:-}" == "1" ]]; then
    # Called from workflow (multi-ai-ai-interface.sh) - outer timeout manages execution
    # Use exec to replace wrapper process with AI command so timeout works correctly
    exec droid exec --auto "$final_quality" "$task"
  else
    # Standalone execution - use wrapper-defined timeout from AGENTS.md classification
    if command -v timeout >/dev/null 2>&1; then
      timeout_arg="$final_timeout"
      if command -v to_seconds >/dev/null 2>&1; then
        timeout_arg="$(to_seconds "$final_timeout")"
      fi
      exec timeout "$timeout_arg" droid exec --auto "$final_quality" "$task"
    else
      exec droid exec --auto "$final_quality" "$task"
    fi
  fi
}

if [[ ${#RAW[@]} -gt 0 ]]; then
  # Respect WRAPPER_SKIP_TIMEOUT for consistency with other execution paths
  if [[ "${WRAPPER_SKIP_TIMEOUT:-}" == "1" ]]; then
    # Called from workflow - outer timeout manages execution
    exec droid "${RAW[@]}"
  else
    if command -v timeout >/dev/null 2>&1; then
      timeout_arg="$TIMEOUT"
      if command -v to_seconds >/dev/null 2>&1; then
        timeout_arg="$(to_seconds "$TIMEOUT")"
      fi
      exec timeout "$timeout_arg" droid "${RAW[@]}"
    else
      exec droid "${RAW[@]}"
    fi
  fi
fi

if [[ -n "$TASK" ]]; then
  run_droid "$TASK"
fi

read -r -d '' INPUT || true
if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
  echo "No input provided (stdin empty and no --task)" >&2
  exit 1
fi
run_droid "$INPUT"
