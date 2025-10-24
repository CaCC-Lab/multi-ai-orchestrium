#!/usr/bin/env bash
set -euo pipefail
# qwen-wrapper.sh - MCP wrapper for Qwen Code CLI
# 既定は安全に `qwen -p "<prompt>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Qwen"

# Qwen CLI command array (will be set after binary detection)
AI_COMMAND=()

# AGENTS.md統合: タスク分類により動的調整（軽量: 30s, 標準: 60s, 重要: 180s）
# - デフォルト: 60秒（1分） - 高速実装に最適
# - 根拠: AGENTS.md標準設定に準拠
# - 上書き: export QWEN_MCP_TIMEOUT=600s（10分に延長可能）
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
# CLI Binary Detection
# ============================================================================

# Try to find qwen in PATH or use the specified location
QWEN_BIN="${QWEN_BIN:-qwen}"
if ! command -v "$QWEN_BIN" >/dev/null 2>&1; then
    for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin" "/opt/qwen/bin"; do
        if [[ -x "$dir/qwen" ]]; then
            QWEN_BIN="$dir/qwen"
            break
        fi
    done
fi

# Update AI_COMMAND with detected binary and flags
AI_COMMAND=("$QWEN_BIN" "-p")

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
wrapper_run_ai "$AI_NAME" "$PROMPT" "$BASE_TIMEOUT" "${AI_COMMAND[@]}"
