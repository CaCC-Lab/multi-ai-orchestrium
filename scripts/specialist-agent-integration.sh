#!/usr/bin/env bash
# specialist-agent-integration.sh - SpecialistAgentシステムの統合スクリプト
# TaskRouter/AgentMatcherと統合するSpecialistAgentシステムのメイン統合ポイント

set -euo pipefail

INTEGRATION_VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

#---------------------------------------------------------------------
# 依存スクリプト読込
#---------------------------------------------------------------------
source "$SCRIPT_DIR/lib/task-state.sh" 2>/dev/null || {
  echo "ERROR: Missing task-state.sh library" >&2
  exit 1
}

source "$SCRIPT_DIR/lib/error-recovery.sh" 2>/dev/null || {
  echo "ERROR: Missing error-recovery.sh library" >&2
  exit 1
}

source "$SCRIPT_DIR/lib/task-executor.sh" 2>/dev/null || {
  echo "ERROR: Missing task-executor.sh library" >&2
  exit 1
}

source "$SCRIPT_DIR/lib/agent-matcher.sh" 2>/dev/null || {
  echo "ERROR: Missing agent-matcher.sh library" >&2
  exit 1
}

source "$SCRIPT_DIR/worktree-manager.sh" 2>/dev/null || {
  echo "ERROR: Missing worktree-manager.sh library" >&2
  exit 1
}

source "$SCRIPT_DIR/specialist-agent.sh" 2>/dev/null || {
  echo "ERROR: Missing specialist-agent.sh library" >&2
  exit 1
}

#---------------------------------------------------------------------
# ヘルプ情報
#---------------------------------------------------------------------
_integration_usage() {
  cat <<'EOF'
Usage:
  specialist-agent-integration.sh <command> [options]

Commands:
  execute-full     Execute a complete task through the full SpecialistAgent pipeline
  route-and-run    Route tasks from spec file and execute them
  status           Check status of a task in the SpecialistAgent system
  list             List all tasks in the SpecialistAgent system
  cleanup          Cleanup a task and its resources

Examples:
  specialist-agent-integration.sh execute-full --task-id task-001 --task-desc "Implement login API"
  specialist-agent-integration.sh route-and-run --spec-file spec.md
  specialist-agent-integration.sh status task-001

Exit codes:
  0 on success, non-zero on failure.
EOF
}

# Simple test - just show help
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --help|-h|help)
      _integration_usage
      ;;
    *)
      _integration_usage
      ;;
  esac
fi