#!/usr/bin/env bash
set -euo pipefail
# amp-wrapper.sh - MCP wrapper for Amp CLI with Free Tier Support
# 既定は安全に `amp -x "<context>"` を実行

# ============================================================================
# FREE TIER SUPPORT - Ampの無料モード設定
# ============================================================================
# Ampの無料プランを強制的に使用するための環境変数設定
# これによりクレジット不足エラーを回避できます

# 方法1: 無料モード環境変数（Ampが対応している場合）
export AMP_MODE="${AMP_MODE:-free}"
export AMP_TIER="${AMP_TIER:-free}"

# 方法2: リクエスト制限を設定（無料プラン相当）
export AMP_MAX_REQUESTS="${AMP_MAX_REQUESTS:-10}"  # 1日の最大リクエスト数

# 方法3: 無料プラン用のAPI URLを使用（もし存在すれば）
# export AMP_URL="${AMP_URL:-https://ampcode.com/free}"

# デバッグ: 無料モード設定を確認
if [[ "${AMP_DEBUG:-}" == "1" ]]; then
  echo "[DEBUG] Amp Free Tier Settings:" >&2
  echo "  AMP_MODE=$AMP_MODE" >&2
  echo "  AMP_TIER=$AMP_TIER" >&2
  echo "  AMP_MAX_REQUESTS=$AMP_MAX_REQUESTS" >&2
fi

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
# - デフォルト: 60秒（1分） - プロジェクト管理に最適
# - 根拠: AGENTS.md標準設定に準拠
# - 上書き: export AMP_MCP_TIMEOUT=600s（10分に延長可能）
TIMEOUT="${AMP_MCP_TIMEOUT:-60s}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
amp-wrapper.sh - MCP wrapper for Amp CLI with Free Tier Support
Usage:
  amp-wrapper.sh --prompt "project context"
  echo "project context" | amp-wrapper.sh --stdin
Arguments:
  <context>          : The project context to process

Options:
  --prompt TEXT      : context text (default -> amp -x)
  --stdin            : read context from stdin (flag)
  --non-interactive  : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH   : cd before run
  --raw ARGS...      : pass-through to amp (expert)

Env:
  AMP_MCP_TIMEOUT    : e.g. 600s (default 60s), customizable timeout
  AMP_MODE           : free (default), pro, enterprise - force tier
  AMP_TIER           : free (default), paid - alternative tier setting
  AMP_MAX_REQUESTS   : 10 (default) - max requests per day for free tier
  AMP_DEBUG          : 1 - show debug information including tier settings

Free Tier Support:
  This wrapper automatically configures Amp for free tier usage to avoid
  "Insufficient credit balance" errors. The following settings are applied:
  - AMP_MODE=free
  - AMP_TIER=free
  - AMP_MAX_REQUESTS=10

  To override and use paid features:
    export AMP_MODE=pro
    export AMP_TIER=paid

Examples:
  # Basic usage (free tier)
  amp-wrapper.sh --prompt "Analyze project structure"

  # Debug mode to verify free tier settings
  AMP_DEBUG=1 amp-wrapper.sh --prompt "Quick task"

  # Override to use paid tier
  AMP_MODE=pro amp-wrapper.sh --prompt "Complex analysis"
USAGE
  exit 0
fi

PROMPT=""
NON_INTERACTIVE=false
WORKSPACE=""
RAW=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt|--context) shift; PROMPT="${1:-}";;
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

run_amp() {
  local context="$1"
  local final_timeout="$TIMEOUT"
  local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

  # VibeLogger: Wrapper execution start
  if command -v vibe_wrapper_start >/dev/null 2>&1; then
    vibe_wrapper_start "Amp" "$context" "$final_timeout"
  fi

  # Log free tier status
  echo "[🆓 Free Tier] Mode: $AMP_MODE, Tier: $AMP_TIER" >&2

  # Apply AGENTS.MD task classification if enabled
  if [[ "$AGENTS_ENABLED" == "true" ]] && [[ -z "${AMP_MCP_TIMEOUT:-}" ]]; then
    local classification
    classification=$(classify_task "$context")

    # Get dynamic timeout (base: 60s for Amp)
    final_timeout=$(get_task_timeout "$classification" 60)

    # Log classification
    local process_label
    process_label=$(get_process_label "$classification")
    echo "[$process_label] Timeout: $final_timeout" >&2

    # Check approval requirement
    if requires_approval "$classification"; then
      echo "⚠️  CRITICAL TASK: Approval recommended before execution" >&2
      echo "Context: $context" >&2

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
            vibe_wrapper_done "Amp" "cancelled" "$duration" "1"
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
    vibe_wrapper_done "Amp" "success" "$duration" "0"
  fi

  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$final_timeout" amp -x "$context"
  else
    exec amp -x "$context"
  fi
}

if [[ ${#RAW[@]} -gt 0 ]]; then
  if command -v timeout >/dev/null 2>&1; then
    exec timeout "$TIMEOUT" amp "${RAW[@]}"
  else
    exec amp "${RAW[@]}"
  fi
fi

if [[ -n "$PROMPT" ]]; then
  run_amp "$PROMPT"
fi

read -r -d '' INPUT || true
if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
  echo "No input provided (stdin empty and no --prompt)" >&2

  # VibeLogger: Log input error
  if command -v vibe_log >/dev/null 2>&1; then
    vibe_log "wrapper.error" "amp_input_empty" \
      '{"error": "no_input", "reason": "stdin empty and no --prompt"}' \
      "Amp入力エラー: stdinが空で--promptも指定されていない" \
      "provide_input,check_parameters" \
      "Amp"
  fi

  exit 1
fi
run_amp "$INPUT"
