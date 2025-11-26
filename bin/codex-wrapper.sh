#!/usr/bin/env bash
set -euo pipefail
# codex-wrapper.sh - MCP wrapper for Codex CLI
# 既定は安全に `codex exec "<prompt>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Codex"

# Codex CLI command array
# Enable workspace-write mode for file creation/modification
AI_COMMAND=("codex" "exec" "--sandbox" "workspace-write")

# AGENTS.md統合: タスク分類により動的調整（軽量: 45s, 標準: 90s, 重要: 270s）
# - デフォルト: 90秒（1.5分） - 深い分析に最適
# - 根拠: AGENTS.md base設定に準拠
# - 上書き: export CODEX_MCP_TIMEOUT=600s（10分に延長可能）
BASE_TIMEOUT="${CODEX_MCP_TIMEOUT:-90}"

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
    wrapper_generate_help "$AI_NAME" "codex"
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
# Python Version Note (2025-11-20: Python 3.9.19 anaconda works correctly)
# ============================================================================
# Testing revealed that Python 3.9.19 (anaconda) works correctly with pytest,
# while Python 3.10.12 causes pytest to hang indefinitely.
# Therefore, we use the default Python 3.9.19 from anaconda.
# No override needed - anaconda Python works perfectly.

# ============================================================================
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to codex)
if wrapper_handle_raw_args; then
    exit 0
fi

# Handle stdin input
if wrapper_handle_stdin; then
    PROMPT="$INPUT"
fi

# Validate we have a prompt or prompt file
if [[ -z "$PROMPT" ]] && [[ -z "$PROMPT_FILE" ]]; then
    echo "No input provided (stdin empty, no --prompt, and no --prompt-file)" >&2
    exit 1
fi

# Run AI with common wrapper logic
wrapper_run_ai "$AI_NAME" "$PROMPT" "$BASE_TIMEOUT" "${AI_COMMAND[@]}"
