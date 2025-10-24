#!/usr/bin/env bash
set -euo pipefail
# gemini-wrapper.sh - MCP wrapper for Gemini CLI
# 既定は安全に `gemini -p "<prompt>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Gemini"

# Gemini CLI command array (with optional flags)
AI_COMMAND=("gemini")

# AGENTS.md統合: タスク分類により動的調整（軽量: 12s, 標準: 25s, 重要: 75s）
# - デフォルト: 25秒 - Web検索最適化
# - 根拠: AGENTS.md base設定に準拠
# - 上書き: export GEMINI_MCP_TIMEOUT=60s（1分に延長）
BASE_TIMEOUT="${GEMINI_MCP_TIMEOUT:-25}"

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
    wrapper_generate_help "$AI_NAME" "gemini"
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
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to gemini)
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
wrapper_run_ai "$AI_NAME" "$PROMPT" "$BASE_TIMEOUT" "${AI_COMMAND[@]}"
