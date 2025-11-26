#!/usr/bin/env bash
set -euo pipefail
# amp-wrapper.sh - MCP wrapper for Amp CLI with Free Tier Support
# 既定は安全に `amp -x "<context>"` を実行

# ============================================================================
# TIER CONFIGURATION - Ampティア設定
# ============================================================================
# 有料アカウント用のデフォルト設定（バランスがある場合）
# 無料プランを使用する場合: export AMP_MODE=free AMP_TIER=free

# 有料プラン環境変数（デフォルト: 有料アカウント使用）
export AMP_MODE="${AMP_MODE:-pro}"
export AMP_TIER="${AMP_TIER:-paid}"

# リクエスト制限（有料プランは制限なし、無料プランの場合は10に設定）
export AMP_MAX_REQUESTS="${AMP_MAX_REQUESTS:-1000}"  # 有料プランのデフォルト上限

# 方法3: 無料プラン用のAPI URLを使用（もし存在すれば）
# export AMP_URL="${AMP_URL:-https://ampcode.com/free}"

# デバッグ: ティア設定を確認
if [[ "${AMP_DEBUG:-}" == "1" ]]; then
  echo "[DEBUG] Amp Tier Settings:" >&2
  echo "  AMP_MODE=$AMP_MODE" >&2
  echo "  AMP_TIER=$AMP_TIER" >&2
  echo "  AMP_MAX_REQUESTS=$AMP_MAX_REQUESTS" >&2
fi

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Amp"

# Amp CLI command array (with -x flag for context)
AI_COMMAND=("amp" "-x")

# AGENTS.md統合: タスク分類により動的調整（軽量: 30s, 標準: 60s, 重要: 180s）
# - デフォルト: 60秒（1分） - プロジェクト管理に最適
# - 根拠: AGENTS.md標準設定に準拠
# - 上書き: export AMP_MCP_TIMEOUT=600s（10分に延長可能）
BASE_TIMEOUT="${AMP_MCP_TIMEOUT:-60}"

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
amp-wrapper.sh - MCP wrapper for Amp CLI
Usage:
  amp-wrapper.sh --prompt "project context"
  echo "project context" | amp-wrapper.sh --stdin
Arguments:
  <context>          : The project context to process

Options:
  --prompt TEXT      : context text (default -> amp -x)
  --context TEXT     : alias for --prompt
  --stdin            : read context from stdin (flag)
  --non-interactive  : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH   : cd before run
  --raw ARGS...      : pass-through to amp (expert)

Env:
  AMP_MCP_TIMEOUT    : e.g. 600s (default 60s), customizable timeout
  AMP_MODE           : pro (default), free, enterprise - force tier
  AMP_TIER           : paid (default), free - alternative tier setting
  AMP_MAX_REQUESTS   : 1000 (default) - max requests for paid tier
  AMP_DEBUG          : 1 - show debug information including tier settings

Tier Configuration:
  This wrapper uses paid tier by default (suitable for accounts with balance).
  The following settings are applied:
  - AMP_MODE=pro
  - AMP_TIER=paid
  - AMP_MAX_REQUESTS=1000

  To use free tier instead:
    export AMP_MODE=free
    export AMP_TIER=free

Examples:
  # Basic usage (paid tier, default)
  amp-wrapper.sh --prompt "Analyze project structure"

  # Debug mode to verify tier settings
  AMP_DEBUG=1 amp-wrapper.sh --prompt "Quick task"

  # Override to use free tier
  AMP_MODE=free amp-wrapper.sh --prompt "Simple analysis"
USAGE
    exit 0
fi

# ============================================================================
# Argument Parsing (with --context support)
# ============================================================================

# Temporary storage for --context argument
CONTEXT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)          shift; PROMPT="${1:-}";;
    --context)         shift; CONTEXT_ARG="${1:-}";;  # Handle --context
    --stdin)           STDIN_REQUESTED=true;;  # Flag to enable stdin reading
    --non-interactive) NON_INTERACTIVE=true;;
    --workspace)       shift; WORKSPACE="${1:-}";;
    --raw)             shift; RAW+=("$@"); break;;
    *)                 RAW+=("$1");;
  esac
  shift || true
done

# Merge --context into --prompt if provided
if [[ -n "$CONTEXT_ARG" ]]; then
  PROMPT="$CONTEXT_ARG"
fi

# ============================================================================
# Workspace Setup
# ============================================================================

if [[ -n "$WORKSPACE" ]]; then
    cd "$WORKSPACE"
fi

# ============================================================================
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to amp)
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

# Log tier status before execution
echo "[💳 Tier] Mode: $AMP_MODE, Tier: $AMP_TIER" >&2

# Run AI with common wrapper logic
wrapper_run_ai "$AI_NAME" "$PROMPT" "$BASE_TIMEOUT" "${AI_COMMAND[@]}"
