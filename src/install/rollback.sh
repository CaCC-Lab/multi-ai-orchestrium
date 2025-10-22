#!/usr/bin/env bash
# AI Tools Checker - Rollback Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides rollback functionality for failed installations.
# It logs installation actions and can revert them if errors occur.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/../core/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true

# Rollback configuration
ROLLBACK_LOG="${ROLLBACK_LOG:-/tmp/aitools_rollback_$(date +%s).log}"
ROLLBACK_ENABLED="${ROLLBACK_ENABLED:-true}"

# ============================================================
# Rollback Logging
# ============================================================

# log_rollback(action_type, target, [details])
# Logs an action that can be rolled back
#
# Arguments:
#   $1 - Action type (npm_install, cli_install, file_create, etc.)
#   $2 - Target (package name, file path, etc.)
#   $3 - Optional details
# Returns: 0 on success
#
# Log Format: TIMESTAMP|ACTION|TARGET|DETAILS
log_rollback() {
  local action="$1"
  local target="$2"
  local details="${3:-}"

  if [[ "$ROLLBACK_ENABLED" != "true" ]]; then
    return 0
  fi

  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  # Append to rollback log
  echo "$timestamp|$action|$target|$details" >> "$ROLLBACK_LOG"

  log_debug "Rollback logged: $action $target"
  return 0
}

# ============================================================
# Rollback Execution
# ============================================================

# execute_rollback()
# Executes rollback of all logged actions in reverse order
#
# Returns: 0 on success
execute_rollback() {
  if [[ ! -f "$ROLLBACK_LOG" ]]; then
    log_warn "No rollback log found: $ROLLBACK_LOG"
    return 0
  fi

  display_section "Executing Rollback"

  # Read log in reverse order
  local -a actions=()
  while IFS='|' read -r timestamp action target details; do
    actions=("$timestamp|$action|$target|$details" "${actions[@]}")
  done < "$ROLLBACK_LOG"

  if [[ ${#actions[@]} -eq 0 ]]; then
    log_info "No actions to rollback"
    return 0
  fi

  print_yellow "Rolling back ${#actions[@]} action(s)..."

  # Execute rollback for each action
  local success_count=0
  local fail_count=0

  for entry in "${actions[@]}"; do
    IFS='|' read -r timestamp action target details <<< "$entry"

    print_blue "  Reverting: $action $target"

    case "$action" in
      npm_install)
        # Uninstall NPM package
        if npm uninstall -g "$target" >/dev/null 2>&1; then
          print_green "    ✓ Uninstalled: $target"
          success_count=$((success_count + 1))
        else
          print_red "    ✗ Failed to uninstall: $target"
          fail_count=$((fail_count + 1))
        fi
        ;;

      pip_install)
        # Uninstall pip package
        if pip uninstall -y "$target" >/dev/null 2>&1; then
          print_green "    ✓ Uninstalled: $target"
          success_count=$((success_count + 1))
        else
          print_red "    ✗ Failed to uninstall: $target"
          fail_count=$((fail_count + 1))
        fi
        ;;

      cli_install)
        # CLI tool uninstall (complex, depends on tool)
        print_yellow "    ! CLI tool removal may require manual intervention: $target"
        success_count=$((success_count + 1))
        ;;

      file_create)
        # Remove created file
        if [[ -f "$target" ]]; then
          if rm -f "$target" 2>/dev/null; then
            print_green "    ✓ Removed file: $target"
            success_count=$((success_count + 1))
          else
            print_red "    ✗ Failed to remove file: $target"
            fail_count=$((fail_count + 1))
          fi
        else
          print_green "    ✓ File already removed: $target"
          success_count=$((success_count + 1))
        fi
        ;;

      dir_create)
        # Remove created directory
        if [[ -d "$target" ]]; then
          if rm -rf "$target" 2>/dev/null; then
            print_green "    ✓ Removed directory: $target"
            success_count=$((success_count + 1))
          else
            print_red "    ✗ Failed to remove directory: $target"
            fail_count=$((fail_count + 1))
          fi
        else
          print_green "    ✓ Directory already removed: $target"
          success_count=$((success_count + 1))
        fi
        ;;

      *)
        print_yellow "    ! Unknown action type: $action"
        fail_count=$((fail_count + 1))
        ;;
    esac
  done

  # Summary
  echo ""
  print_blue "Rollback Summary:"
  echo "  Success: $success_count/${#actions[@]}"
  echo "  Failed:  $fail_count/${#actions[@]}"

  # Clear rollback log after execution
  rollback_clear

  if [[ $fail_count -eq 0 ]]; then
    display_success "Rollback completed successfully"
    return 0
  else
    display_warning "Rollback completed with errors"
    return 1
  fi
}

# ============================================================
# Rollback Management
# ============================================================

# rollback_list()
# Lists all actions in the rollback log
#
# Returns: 0 on success
rollback_list() {
  if [[ ! -f "$ROLLBACK_LOG" ]]; then
    echo "No rollback log found"
    return 0
  fi

  display_section "Rollback Log"

  echo "Log file: $ROLLBACK_LOG"
  echo ""

  local count=0
  while IFS='|' read -r timestamp action target details; do
    count=$((count + 1))
    printf "%3d. [%s] %s: %s\n" "$count" "$timestamp" "$action" "$target"
    if [[ -n "$details" ]]; then
      echo "     Details: $details"
    fi
  done < "$ROLLBACK_LOG"

  echo ""
  echo "Total actions logged: $count"
  return 0
}

# rollback_clear()
# Clears the rollback log
#
# Returns: 0 on success
rollback_clear() {
  if [[ -f "$ROLLBACK_LOG" ]]; then
    rm -f "$ROLLBACK_LOG"
    log_debug "Rollback log cleared: $ROLLBACK_LOG"
  fi
  return 0
}

# rollback_status()
# Displays rollback status
#
# Returns: 0 on success
rollback_status() {
  echo "Rollback Status"
  echo "───────────────"
  echo "Enabled:  $ROLLBACK_ENABLED"
  echo "Log file: $ROLLBACK_LOG"

  if [[ -f "$ROLLBACK_LOG" ]]; then
    local count
    count=$(wc -l < "$ROLLBACK_LOG")
    echo "Actions:  $count logged"
  else
    echo "Actions:  No log file"
  fi

  return 0
}

# ============================================================
# Rollback Hooks
# ============================================================

# rollback_on_exit()
# Trap function to execute rollback on script exit with error
rollback_on_exit() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]] && [[ "$ROLLBACK_ENABLED" == "true" ]]; then
    if [[ -f "$ROLLBACK_LOG" ]]; then
      display_warning "Script exited with error (code: $exit_code)"
      if confirm_prompt "Execute rollback?"; then
        execute_rollback
      fi
    fi
  fi
}

# rollback_register_trap()
# Registers rollback trap for error handling
#
# Call this at the start of installation operations
rollback_register_trap() {
  trap rollback_on_exit EXIT
  log_debug "Rollback trap registered"
}

# rollback_unregister_trap()
# Unregisters rollback trap
rollback_unregister_trap() {
  trap - EXIT
  log_debug "Rollback trap unregistered"
}

# ============================================================
# Module Information
# ============================================================

# rollback_module_info()
# Displays module information
rollback_module_info() {
  cat <<EOF
AI Tools Checker - Rollback Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Logging:
    - log_rollback()            Log rollback action

  Execution:
    - execute_rollback()        Execute rollback in reverse

  Management:
    - rollback_list()           List logged actions
    - rollback_clear()          Clear rollback log
    - rollback_status()         Display status

  Hooks:
    - rollback_on_exit()        Exit trap handler
    - rollback_register_trap()  Register trap
    - rollback_unregister_trap() Unregister trap

Supported Actions:
  - npm_install               NPM package installation
  - pip_install               Pip package installation
  - cli_install               CLI tool installation
  - file_create               File creation
  - dir_create                Directory creation

Configuration:
  - ROLLBACK_ENABLED:  $ROLLBACK_ENABLED
  - ROLLBACK_LOG:      $ROLLBACK_LOG

Dependencies:
  - interfaces.sh (log_*)
  - helpers.sh (display_*, print_*)
EOF
}

# Export functions
declare -fx log_rollback 2>/dev/null || true
declare -fx execute_rollback 2>/dev/null || true
declare -fx rollback_list 2>/dev/null || true
declare -fx rollback_clear 2>/dev/null || true
declare -fx rollback_status 2>/dev/null || true
declare -fx rollback_register_trap 2>/dev/null || true
declare -fx rollback_unregister_trap 2>/dev/null || true
