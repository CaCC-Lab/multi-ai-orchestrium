#!/usr/bin/env bash
set -euo pipefail
# claude-wrapper.sh - MCP wrapper for Claude Code CLI
# 既定は安全に `claude -p "<prompt>"` を実行

# ============================================================================
# AI-Specific Configuration
# ============================================================================

# AI name for logging and classification
AI_NAME="Claude"

# Claude CLI command array
AI_COMMAND=("claude")

# AGENTS.md統合: タスク分類により動的調整（軽量: 60s, 標準: 120s, 重要: 360s）
# - デフォルト: 120秒（2分） - 戦略/アーキテクチャ検討に最適
# - 根拠: Claude (CTO) の平均所要時間、AGENTS.md base設定に準拠
# - 上書き: export CLAUDE_MCP_TIMEOUT=600s（10分に延長可能）
BASE_TIMEOUT="${CLAUDE_MCP_TIMEOUT:-120}"

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
    wrapper_generate_help "$AI_NAME" "claude"
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

# Allow overriding Claude CLI location
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
    for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin" "/opt/claude/bin"; do
        if [[ -x "$dir/claude" ]]; then
            CLAUDE_BIN="$dir/claude"
            break
        fi
    done
fi

# Update AI_COMMAND with detected binary
AI_COMMAND=("$CLAUDE_BIN")

# ============================================================================
# Main Execution
# ============================================================================

# Handle --raw arguments (pass-through to claude)
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
