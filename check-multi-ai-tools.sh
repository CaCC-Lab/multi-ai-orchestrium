#!/usr/bin/env bash
# AI Tools Checker - Modular Entry Point
# Version: 2.1.0
# Date: 2025-01-12
#
# This is the main entry point for the modularized version of AI Tools Checker.
# It loads all necessary modules and orchestrates the tool detection workflow.

set -euo pipefail

# ============================================================
# Version & Metadata
# ============================================================

VERSION="2.1.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# Global Configuration Defaults
# ============================================================

# Initialize configuration before loading modules
VERBOSE="${VERBOSE:-false}"
DEBUG="${DEBUG:-false}"
QUIET="${QUIET:-false}"
NO_COLOR="${NO_COLOR:-false}"
UPDATE_MODE="${UPDATE_MODE:-false}"
INSTALL_MODE="${INSTALL_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"
REPORT_FORMAT="${REPORT_FORMAT:-html}"
INTERACTIVE_MODE="${INTERACTIVE_MODE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SHOW_DIFF="${SHOW_DIFF:-false}"

# ============================================================
# Module Loading
# ============================================================

# Load order is critical - respecting dependency graph
load_module() {
  local module="$1"
  local module_path="${SCRIPT_DIR}/${module}"

  if [[ ! -f "$module_path" ]]; then
    echo "ERROR: Required module not found: $module" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$module_path" || {
    echo "ERROR: Failed to load module: $module" >&2
    return 1
  }
}

# Level 0 dependencies (no dependencies)
load_module "src/core/interfaces.sh"
load_module "src/core/version-checker.sh"

# Level 1 dependencies (depend on Level 0)
load_module "src/utils/helpers.sh"
load_module "src/core/cache.sh"
load_module "src/core/config.sh"

# Level 2 dependencies (depend on Level 0-1)
load_module "src/core/npm-tools.sh"
load_module "src/core/cli-tools.sh"
load_module "src/ui/output.sh"

# Level 3 dependencies (depend on Level 0-2)
load_module "src/ui/interactive.sh"
load_module "src/ui/reports.sh"
load_module "src/install/rollback.sh"

# Level 4 dependencies (depend on Level 0-3)
load_module "src/install/installer.sh"
load_module "src/install/updater.sh"
load_module "src/install/notifier.sh"

log_debug "All modules loaded successfully"

# Load configuration from file and environment
config_load || {
  echo "ERROR: Failed to load configuration" >&2
  exit 1
}

log_debug "Configuration loaded"

# ============================================================
# Command Line Argument Parsing
# ============================================================

show_help() {
  cat <<HELPEOF
AI Tools Checker v${VERSION}

USAGE:
  $SCRIPT_NAME [OPTIONS]

DESCRIPTION:
  Checks the installation status and versions of AI coding tools,
  including NPM-based tools (Claude Code, Gemini CLI, etc.) and
  CLI tools (Cursor, CodeRabbit, Amp, Droid).

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output
  -q, --quiet             Suppress non-essential output
  -d, --debug             Enable debug logging
  --version               Show version information
  --no-color              Disable colored output

  -u, --update            Update outdated tools
  -i, --install           Install missing tools
  --dry-run               Show what would be done without executing

  -r, --report [FORMAT]   Generate report (html, json, markdown, csv)
  --diff                  Show diff from previous check

  --interactive           Launch interactive TUI mode
  --test-notify           Test notification channels

EXAMPLES:
  # Check all tools
  $SCRIPT_NAME

  # Verbose output with colors
  $SCRIPT_NAME --verbose

  # Update all outdated tools
  $SCRIPT_NAME --update

  # Generate HTML report
  $SCRIPT_NAME --report html

  # Interactive mode
  $SCRIPT_NAME --interactive

  # Dry run mode (no actual changes)
  $SCRIPT_NAME --update --dry-run

CONFIGURATION:
  Configuration file: ~/.config/aitools/config.json
  Cache directory:    ~/.cache/aitools/
  Report directory:   ~/.cache/aitools/reports/

  Environment variables:
    AITOOLS_VERBOSE=true        Enable verbose mode
    AITOOLS_NO_COLOR=true       Disable colors
    AITOOLS_GITHUB_TOKEN=xxx    GitHub API token
    NOTIFY_ENABLED=true         Enable notifications
    SLACK_WEBHOOK=xxx           Slack webhook URL

SUPPORTED TOOLS:
  NPM-based:
    • Claude Code          (@anthropic-ai/claude-code)
    • Gemini CLI           (@google/gemini-cli)
    • OpenAI Codex         (@openai/codex)
    • Qwen Code            (@qwen-code/qwen-code)

  CLI Tools:
    • Cursor               (https://cursor.sh)
    • CodeRabbit           (@coderabbitai/cli)
    • Amp                  (https://ampcode.com)
    • Droid                (https://app.factory.ai)

For more information, visit:
  https://github.com/CaCC-Lab/check-ai-tools

HELPEOF
}

show_version() {
  echo "AI Tools Checker v${VERSION}"
  echo "Modular architecture with comprehensive module system"
  echo ""
  echo "Modules loaded:"
  echo "  • Core: interfaces, version-checker, npm-tools, cli-tools"
  echo "  • Utils: helpers, cache, config"
  echo "  • UI: output, interactive, reports"
  echo "  • Install: installer, updater, notifier, rollback"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      --version)
        show_version
        exit 0
        ;;
      -v|--verbose)
        VERBOSE="true"
        shift
        ;;
      -q|--quiet)
        QUIET="true"
        shift
        ;;
      -d|--debug)
        DEBUG="true"
        VERBOSE="true"
        shift
        ;;
      --no-color)
        NO_COLOR="true"
        shift
        ;;
      -u|--update)
        UPDATE_MODE="true"
        shift
        ;;
      -i|--install)
        INSTALL_MODE="true"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      -r|--report)
        REPORT_MODE="true"
        if [[ $# -gt 1 ]] && [[ ! "$2" =~ ^- ]]; then
          REPORT_FORMAT="$2"
          shift
        fi
        shift
        ;;
      --diff)
        SHOW_DIFF="true"
        shift
        ;;
      --interactive)
        INTERACTIVE_MODE="true"
        shift
        ;;
      --test-notify)
        test_notifications
        exit $?
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        echo "Run '$SCRIPT_NAME --help' for usage information" >&2
        exit 1
        ;;
    esac
  done
}

# ============================================================
# Main Tool Detection Logic
# ============================================================

detect_all_tools() {
  display_header "AI Tools Checker v${VERSION}"

  # Detect NPM tools
  local npm_json npm_detected=0 npm_total=0
  npm_json=$(detect_npm_tools 2>/dev/null)
  if have jq && [[ -n "$npm_json" ]]; then
    npm_total=$(echo "$npm_json" | jq 'length' 2>/dev/null || echo 0)
    npm_detected=$(echo "$npm_json" | jq '[.[] | select(.current != "null" and .current != "")] | length' 2>/dev/null || echo 0)

    echo ""
    display_section "NPM-based AI Tools"
    if [[ $npm_total -gt 0 ]]; then
      echo "$npm_json" | jq -r '.[] | "  " + (if .status == "UP_TO_DATE" then "✅" elif .status == "UPDATE_AVAILABLE" then "🔄" elif .status == "NOT_INSTALLED" then "❌" else "❓" end) + " " + .name + " (current: " + .current + ", latest: " + .latest + ")"' 2>/dev/null
    else
      echo "  No NPM tools detected"
    fi
  else
    echo ""
    display_section "NPM-based AI Tools"
    echo "  No NPM tools detected"
  fi

  # Detect CLI tools
  local cli_json cli_detected=0 cli_total=0
  cli_json=$(detect_cli_tools 2>/dev/null)
  if have jq && [[ -n "$cli_json" ]]; then
    cli_total=$(echo "$cli_json" | jq 'length' 2>/dev/null || echo 0)
    cli_detected=$(echo "$cli_json" | jq '[.[] | select(.current != "null" and .current != "")] | length' 2>/dev/null || echo 0)

    echo ""
    display_section "CLI-based AI Tools"
    if [[ $cli_total -gt 0 ]]; then
      echo "$cli_json" | jq -r '.[] | "  " + (if .status == "INSTALLED" then "✅" elif .status == "NOT_INSTALLED" then "❌" else "❓" end) + " " + .name + " (" + .current + ")"' 2>/dev/null
    else
      echo "  No CLI tools detected"
    fi
  else
    echo ""
    display_section "CLI-based AI Tools"
    echo "  No CLI tools detected"
  fi

  # Display summary
  echo ""
  display_summary "$npm_detected" "$npm_total" "$cli_detected" "$cli_total"

  # Display tips
  display_tips

  return 0
}

# ============================================================
# Main Execution Flow
# ============================================================

main() {
  # Parse command line arguments
  parse_arguments "$@"

  # Register rollback trap if in install/update mode
  if [[ "$INSTALL_MODE" == "true" ]] || [[ "$UPDATE_MODE" == "true" ]]; then
    rollback_register_trap
  fi

  # Execute based on mode
  if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    # Launch interactive TUI
    log_info "Launching interactive mode..."
    interactive_main_menu
    exit_code=$?

  elif [[ "$INSTALL_MODE" == "true" ]]; then
    # Install mode
    log_info "Install mode activated"
    install_missing_tools
    exit_code=$?

  elif [[ "$UPDATE_MODE" == "true" ]]; then
    # Update mode
    log_info "Update mode activated"
    update_outdated_tools
    exit_code=$?

  elif [[ "$REPORT_MODE" == "true" ]]; then
    # Report generation mode
    log_info "Generating report in $REPORT_FORMAT format..."
    detect_all_tools
    generate_report "$REPORT_FORMAT"
    exit_code=$?

  else
    # Default mode: detection only
    detect_all_tools
    exit_code=$?

    # Show diff if requested
    if [[ "$SHOW_DIFF" == "true" ]]; then
      log_info "Showing diff from previous check..."
      # Diff functionality would be called here
    fi
  fi

  # Unregister rollback trap
  if [[ "$INSTALL_MODE" == "true" ]] || [[ "$UPDATE_MODE" == "true" ]]; then
    rollback_unregister_trap
  fi

  # Display footer
  if [[ "$QUIET" != "true" ]]; then
    echo ""
    display_section "Tool Status Summary"
    echo "For more information, run: $SCRIPT_NAME --help"
  fi

  exit "$exit_code"
}

# ============================================================
# Error Handling
# ============================================================

# Trap errors and provide helpful messages
trap 'error_handler $? $LINENO' ERR

error_handler() {
  local exit_code=$1
  local line_number=$2

  if [[ "$DEBUG" == "true" ]]; then
    echo "ERROR: Command failed with exit code $exit_code at line $line_number" >&2
    echo "Stack trace:" >&2
    local frame=0
    while caller $frame; do
      ((frame++))
    done
  fi

  # Cleanup on error
  if [[ "$INSTALL_MODE" == "true" ]] || [[ "$UPDATE_MODE" == "true" ]]; then
    if confirm_prompt "An error occurred. Execute rollback?" "n"; then
      execute_rollback
    fi
  fi
}

# ============================================================
# Entry Point
# ============================================================

# Only execute main if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
