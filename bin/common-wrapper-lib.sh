#!/usr/bin/env bash
# common-wrapper-lib.sh - Common library for AI wrapper scripts
#
# Purpose: Consolidate shared logic across 7 AI wrapper scripts
# Reduces code duplication by ~60% (1513 lines → 650-960 lines)
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/common-wrapper-lib.sh"
#
# Required global variables (set by calling wrapper):
#   AI_NAME       - AI display name (e.g., "Claude", "Gemini")
#   AI_COMMAND    - Array of CLI command (e.g., ("claude") or ("gemini" "--stream-json"))
#   BASE_TIMEOUT  - Default timeout in seconds (e.g., 120)
#
# Optional global variables:
#   SCRIPT_DIR    - Directory containing this library (auto-detected if not set)

# ============================================================================
# Global Variables (set by calling wrapper or library functions)
# ============================================================================

# Set by calling wrapper (required):
AI_NAME="${AI_NAME:-}"
AI_COMMAND=("${AI_COMMAND[@]+"${AI_COMMAND[@]}"}")
BASE_TIMEOUT="${BASE_TIMEOUT:-60}"

# Set by wrapper_load_dependencies():
AGENTS_ENABLED=false

# Set by wrapper_parse_args():
PROMPT=""
NON_INTERACTIVE=false
WORKSPACE=""
RAW=()

# Set by wrapper_handle_stdin():
INPUT=""

# ============================================================================
# 1. wrapper_load_dependencies()
# ============================================================================
# Purpose: Load required dependencies (agents-utils.sh, vibe-logger-lib.sh)
# Args: None
# Returns: 0 on success, 1 on failure
# Side effects: Sets AGENTS_ENABLED global variable

wrapper_load_dependencies() {
  # Resolve SCRIPT_DIR if not already set
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  # Load AGENTS.md task classification utilities
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

  return 0
}

# ============================================================================
# 2. wrapper_generate_help()
# ============================================================================
# Purpose: Generate standardized help text for AI wrapper
# Args:
#   $1 - AI name (e.g., "Claude", "Gemini")
#   $2 - CLI command (e.g., "claude", "gemini")
# Returns: None (outputs to stdout)

wrapper_generate_help() {
  local ai_name="$1"
  local ai_command="$2"

  cat <<USAGE
${ai_command}-wrapper.sh - MCP wrapper for ${ai_name} CLI
Usage:
  ${ai_command}-wrapper.sh --prompt "your task"
  echo "your task" | ${ai_command}-wrapper.sh --stdin
Arguments:
  <task>             : The task text to process

Options:
  --prompt TEXT      : task text (default -> ${ai_command})
  --stdin            : read task from stdin (flag)
  --non-interactive  : skip approval prompts for critical tasks (auto-approve)
  --workspace PATH   : cd before run
  --raw ARGS...      : pass-through to ${ai_command} (expert)

Env:
  ${ai_name^^}_MCP_TIMEOUT : e.g. 600s, customizable timeout
USAGE
}

# ============================================================================
# 3. wrapper_parse_args()
# ============================================================================
# Purpose: Parse command-line arguments
# Args: $@ (all command-line arguments)
# Returns: None
# Side effects: Sets global variables PROMPT, NON_INTERACTIVE, WORKSPACE, RAW

wrapper_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt)          shift; PROMPT="${1:-}";;
      --stdin)           : ;;  # Flag only, no value
      --non-interactive) NON_INTERACTIVE=true;;
      --workspace)       shift; WORKSPACE="${1:-}";;
      --raw)             shift; RAW+=("$@"); break;;
      *)                 RAW+=("$1");;
    esac
    shift || true
  done
}

# ============================================================================
# 4. wrapper_check_approval()
# ============================================================================
# Purpose: Check if user approval is required for critical tasks
# Args:
#   $1 - Task classification (from AGENTS.md)
#   $2 - Prompt text
#   $3 - AI name
#   $4 - Start time (for logging cancellation)
# Returns: 0 to continue, 1 to cancel
# Side effects: May prompt user for input, logs to VibeLogger on cancel

wrapper_check_approval() {
  local classification="$1"
  local prompt="$2"
  local ai_name="$3"
  local start_time="$4"

  # Check if approval is required
  if ! requires_approval "$classification"; then
    return 0
  fi

  echo "⚠️  CRITICAL TASK: Approval recommended before execution" >&2
  echo "Prompt: $prompt" >&2

  # Determine if running in non-interactive mode
  local is_non_interactive=false

  # 1. Environment variable override
  if [[ "${WRAPPER_NON_INTERACTIVE:-}" == "1" ]]; then
    is_non_interactive=true
  fi

  # 2. Check --non-interactive flag
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    is_non_interactive=true
  fi

  if [[ "$is_non_interactive" == "true" ]]; then
    echo "⚠️  Running in non-interactive mode - CRITICAL task auto-approved" >&2
    echo "⚠️  Set WRAPPER_NON_INTERACTIVE=0 to require manual confirmation" >&2
    return 0
  fi

  # Interactive approval prompt
  read -p "Continue? [y/N] " -n 1 -r >&2
  echo >&2
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Execution cancelled by user" >&2

    # VibeLogger: Log user cancellation
    if command -v vibe_wrapper_done >/dev/null 2>&1; then
      local end_time
      end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
      local duration=$((end_time - start_time))
      vibe_wrapper_done "$ai_name" "cancelled" "$duration" "1"
    fi

    return 1
  fi

  return 0
}

# ============================================================================
# 5. wrapper_apply_timeout()
# ============================================================================
# Purpose: Apply timeout strategy and execute command
# Args:
#   $1 - Timeout value (seconds or "60s" format)
#   $2+ - Command array to execute
# Returns: Does not return (uses exec)

wrapper_apply_timeout() {
  local timeout_value="$1"
  shift
  local command=("$@")

  # Timeout strategy: Use outer timeout when called from workflow, inner timeout for standalone
  if [[ "${WRAPPER_SKIP_TIMEOUT:-}" == "1" ]]; then
    # Called from workflow (multi-ai-ai-interface.sh) - outer timeout manages execution
    # Use exec to replace wrapper process with AI command so timeout works correctly
    exec "${command[@]}"
  else
    # Standalone execution - use wrapper-defined timeout from AGENTS.md classification
    if command -v timeout >/dev/null 2>&1; then
      local timeout_arg="$timeout_value"
      # Convert to seconds format if needed (to_seconds from agents-utils.sh)
      if command -v to_seconds >/dev/null 2>&1; then
        timeout_arg="$(to_seconds "$timeout_value")"
      fi
      exec timeout "$timeout_arg" "${command[@]}"
    else
      exec "${command[@]}"
    fi
  fi
}

# ============================================================================
# 6. wrapper_run_ai()
# ============================================================================
# Purpose: Execute AI CLI command with full wrapper logic
# Args:
#   $1 - AI name (e.g., "Claude")
#   $2 - Prompt text
#   $3 - Base timeout (seconds, e.g., 120)
#   $4+ - AI command array (e.g., "claude" or "gemini" "--stream-json")
# Returns: Exit code from AI execution (via exec - does not return)

wrapper_run_ai() {
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
  if [[ "$AGENTS_ENABLED" == "true" ]]; then
    # Only classify if timeout not manually overridden
    # Check by looking for environment variable (e.g., CLAUDE_MCP_TIMEOUT)
    local timeout_var_name="${ai_name^^}_MCP_TIMEOUT"
    timeout_var_name="${timeout_var_name// /_}"  # Replace spaces with underscores

    if [[ -z "${!timeout_var_name:-}" ]]; then
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
  fi

  # VibeLogger: Wrapper execution done (before exec)
  local end_time
  end_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
  local duration=$((end_time - start_time))

  if command -v vibe_wrapper_done >/dev/null 2>&1; then
    vibe_wrapper_done "$ai_name" "success" "$duration" "0"
  fi

  # Apply timeout and execute AI command
  wrapper_apply_timeout "$final_timeout" "${ai_command[@]}" "$prompt"
}

# ============================================================================
# 7. wrapper_handle_raw_args()
# ============================================================================
# Purpose: Handle --raw arguments (pass-through mode)
# Args: None (uses global RAW, AI_COMMAND, BASE_TIMEOUT)
# Returns:
#   - 0 if RAW args were handled (script should exit after this)
#   - 1 if no RAW args present (continue normal execution)

wrapper_handle_raw_args() {
  # Check if RAW array has content
  if [[ ${#RAW[@]} -eq 0 ]]; then
    return 1  # No raw args, continue normal execution
  fi

  # Verify AI_COMMAND is available
  if [[ ${#AI_COMMAND[@]} -eq 0 ]] || ! command -v "${AI_COMMAND[0]}" >/dev/null 2>&1; then
    echo "${AI_NAME:-AI} CLI not found (expected at '${AI_COMMAND[0]:-<unset>}')." >&2
    exit 127
  fi

  # Build full command
  local full_command=("${AI_COMMAND[@]}" "${RAW[@]}")

  # Convert BASE_TIMEOUT to seconds if needed
  local timeout_arg="$BASE_TIMEOUT"
  if command -v to_seconds >/dev/null 2>&1; then
    timeout_arg="$(to_seconds "$BASE_TIMEOUT")"
  fi

  # Respect WRAPPER_SKIP_TIMEOUT for consistency with other execution paths
  wrapper_apply_timeout "$timeout_arg" "${full_command[@]}"

  # wrapper_apply_timeout uses exec, so we never reach here
  # But return 0 for safety
  return 0
}

# ============================================================================
# 8. wrapper_handle_stdin()
# ============================================================================
# Purpose: Read and validate input from stdin
# Args: None
# Returns: 0 if valid input, 1 if empty
# Side effects: Sets global variable INPUT

wrapper_handle_stdin() {
  read -r -d '' INPUT || true

  # Check if input is empty (whitespace-only)
  if [[ -z "${INPUT//[$'\t\r\n ']/}" ]]; then
    echo "No input provided (stdin empty and no --prompt)" >&2
    return 1
  fi

  return 0
}

# ============================================================================
# Library Initialization Complete
# ============================================================================
# This library is now ready to be sourced by individual AI wrappers
