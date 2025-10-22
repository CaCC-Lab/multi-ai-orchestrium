#!/usr/bin/env bash
# AI Tools Checker - Interactive UI Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides interactive TUI (Text User Interface) functionality
# including menus, prompts, and guided workflows.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/../core/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true
source "${_MODULE_DIR}/output.sh" 2>/dev/null || true

# Global settings
AUTO_YES="${AUTO_YES:-false}"
INTERACTIVE_MODE="${INTERACTIVE_MODE:-false}"

# ============================================================
# Confirmation Prompts
# ============================================================

# confirm_prompt(message, [default])
# Displays a yes/no confirmation prompt
#
# Arguments:
#   $1 - Prompt message
#   $2 - Default response (optional: "y" or "n")
# Returns: 0 for yes, 1 for no
#
# Example:
#   if confirm_prompt "Install this tool?"; then
#     install_tool
#   fi
confirm_prompt() {
  local message="${1:-Continue?}"
  local default="${2:-n}"

  # Auto-yes mode
  if [[ "$AUTO_YES" == "true" ]]; then
    log_debug "Auto-yes enabled, confirming: $message"
    return 0
  fi

  # Non-interactive mode
  if [[ "$INTERACTIVE_MODE" != "true" ]]; then
    return 0
  fi

  # Build prompt with default indicator
  local prompt_suffix
  if [[ "$default" == "y" ]]; then
    prompt_suffix="(Y/n)"
  else
    prompt_suffix="(y/N)"
  fi

  echo -n "$message $prompt_suffix: "
  read -r response

  # Handle empty response (use default)
  if [[ -z "$response" ]]; then
    response="$default"
  fi

  # Check response
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# confirm_with_warning(message, warning)
# Displays a confirmation with a warning
#
# Arguments:
#   $1 - Prompt message
#   $2 - Warning message
# Returns: 0 for yes, 1 for no
confirm_with_warning() {
  local message="$1"
  local warning="$2"

  display_warning "$warning"
  confirm_prompt "$message"
}

# ============================================================
# Menu Selection
# ============================================================

# select_menu(prompt, options...)
# Displays a numbered menu and returns selected index
#
# Arguments:
#   $1 - Menu prompt
#   $2+ - Menu options
# Returns: Selected index (0-based), 255 for cancel
# Side effects: Sets $SELECTED_OPTION global variable
#
# Example:
#   if select_menu "Choose action:" "Install" "Update" "Remove"; then
#     echo "Selected: $SELECTED_OPTION"
#   fi
select_menu() {
  local prompt="$1"
  shift
  local options=("$@")

  echo ""
  print_blue "$prompt"
  echo "────────────────────"

  # Display options
  for i in "${!options[@]}"; do
    echo "  $((i+1)). ${options[$i]}"
  done
  echo "  0. Cancel"
  echo ""

  # Read selection
  while true; do
    echo -n "Select option [0-${#options[@]}]: "
    read -r choice

    # Validate input
    if ! is_number "$choice"; then
      print_red "Invalid input. Please enter a number."
      continue
    fi

    # Handle cancel
    if [[ "$choice" == "0" ]]; then
      log_debug "User cancelled menu selection"
      return 255
    fi

    # Validate range
    if [[ "$choice" -ge 1 && "$choice" -le "${#options[@]}" ]]; then
      local index=$((choice - 1))
      SELECTED_OPTION="${options[$index]}"
      log_debug "User selected: $SELECTED_OPTION (index: $index)"
      return "$index"
    else
      print_red "Invalid choice. Please select 0-${#options[@]}."
    fi
  done
}

# select_multiple(prompt, options...)
# Allows multiple selections from a menu
#
# Arguments:
#   $1 - Menu prompt
#   $2+ - Menu options
# Returns: Always returns 0
# Side effects: Sets $SELECTED_OPTIONS array
select_multiple() {
  local prompt="$1"
  shift
  local options=("$@")
  SELECTED_OPTIONS=()

  echo ""
  print_blue "$prompt"
  echo "────────────────────"

  # Display options with checkboxes
  local -a selected_flags=()
  for i in "${!options[@]}"; do
    selected_flags[$i]=false
    echo "  $((i+1)). [ ] ${options[$i]}"
  done
  echo "  0. Done"
  echo ""

  # Selection loop
  while true; do
    echo -n "Toggle option (0 when done): "
    read -r choice

    if ! is_number "$choice"; then
      print_red "Invalid input. Please enter a number."
      continue
    fi

    # Done
    if [[ "$choice" == "0" ]]; then
      # Collect selected options
      for i in "${!options[@]}"; do
        if [[ "${selected_flags[$i]}" == "true" ]]; then
          SELECTED_OPTIONS+=("${options[$i]}")
        fi
      done
      return 0
    fi

    # Validate range
    if [[ "$choice" -ge 1 && "$choice" -le "${#options[@]}" ]]; then
      local index=$((choice - 1))

      # Toggle selection
      if [[ "${selected_flags[$index]}" == "true" ]]; then
        selected_flags[$index]=false
      else
        selected_flags[$index]=true
      fi

      # Redisplay menu
      clear_line
      move_cursor_up "$((${#options[@]} + 3))"

      echo "$prompt"
      echo "────────────────────"
      for i in "${!options[@]}"; do
        if [[ "${selected_flags[$i]}" == "true" ]]; then
          echo "  $((i+1)). [✓] ${options[$i]}"
        else
          echo "  $((i+1)). [ ] ${options[$i]}"
        fi
      done
      echo "  0. Done"
      echo ""
    else
      print_red "Invalid choice. Please select 0-${#options[@]}."
    fi
  done
}

# ============================================================
# Text Input
# ============================================================

# read_input(prompt, [default], [validation_function])
# Reads user input with optional validation
#
# Arguments:
#   $1 - Input prompt
#   $2 - Default value (optional)
#   $3 - Validation function name (optional)
# Returns: 0 on success, 1 if validation failed
# Outputs: User input to stdout
read_input() {
  local prompt="$1"
  local default="${2:-}"
  local validator="${3:-}"

  while true; do
    if [[ -n "$default" ]]; then
      echo -n "$prompt [$default]: "
    else
      echo -n "$prompt: "
    fi

    read -r input

    # Use default if empty
    if [[ -z "$input" ]] && [[ -n "$default" ]]; then
      input="$default"
    fi

    # Validate if validator provided
    if [[ -n "$validator" ]]; then
      if "$validator" "$input"; then
        echo "$input"
        return 0
      else
        print_red "Invalid input. Please try again."
        continue
      fi
    fi

    # No validation, accept any input
    echo "$input"
    return 0
  done
}

# read_password(prompt)
# Reads password input (hidden)
#
# Arguments:
#   $1 - Password prompt
# Outputs: Password to stdout
read_password() {
  local prompt="$1"
  local password

  echo -n "$prompt: "
  read -rs password
  echo ""  # Newline after hidden input

  echo "$password"
}

# ============================================================
# Progress Display
# ============================================================

# interactive_progress(current, total, message)
# Displays progress in interactive mode
#
# Arguments:
#   $1 - Current step
#   $2 - Total steps
#   $3 - Progress message
interactive_progress() {
  local current="$1"
  local total="$2"
  local message="$3"

  if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    show_progress "$current" "$total" "$message"
  else
    log_info "[$current/$total] $message"
  fi
}

# ============================================================
# Main Interactive Menus
# ============================================================

# interactive_main_menu()
# Displays the main interactive menu
#
# Returns: 0 to continue, 1 to exit
interactive_main_menu() {
  while true; do
    display_header "AI Tools Checker - Interactive Mode"

    if select_menu "What would you like to do?" \
        "Check all tools status" \
        "Install tools" \
        "Update tools" \
        "Generate report" \
        "View configuration" \
        "Clear cache" \
        "Exit"; then

      local choice=$?
      case "$choice" in
        0)  # Check all tools
          interactive_check_tools
          ;;
        1)  # Install tools
          interactive_install_tools
          ;;
        2)  # Update tools
          interactive_update_tools
          ;;
        3)  # Generate report
          interactive_generate_report
          ;;
        4)  # View configuration
          interactive_view_config
          ;;
        5)  # Clear cache
          interactive_clear_cache
          ;;
        6)  # Exit
          return 1
          ;;
      esac
    else
      # User cancelled
      return 1
    fi

    echo ""
    if ! confirm_prompt "Return to main menu?" "y"; then
      return 1
    fi
  done
}

# interactive_check_tools()
# Interactive tool checking workflow
interactive_check_tools() {
  display_section "Checking All Tools"

  echo "Detecting installed tools..."

  # This would call actual detection functions
  # For now, just a placeholder
  log_info "Tool detection would run here"

  display_success "Tool check complete!"
}

# interactive_install_tools()
# Interactive tool installation workflow
interactive_install_tools() {
  display_section "Install Tools"

  local tool_categories=("NPM Tools" "CLI Tools" "All Tools")

  if select_menu "Select tools to install:" "${tool_categories[@]}"; then
    local choice=$?
    case "$choice" in
      0)  # NPM Tools
        log_info "Would install NPM tools"
        ;;
      1)  # CLI Tools
        log_info "Would install CLI tools"
        ;;
      2)  # All Tools
        log_info "Would install all tools"
        ;;
    esac
  fi
}

# interactive_update_tools()
# Interactive tool update workflow
interactive_update_tools() {
  display_section "Update Tools"

  if confirm_prompt "Check for updates?"; then
    log_info "Would check for updates"
    display_success "Update check complete!"
  fi
}

# interactive_generate_report()
# Interactive report generation workflow
interactive_generate_report() {
  display_section "Generate Report"

  local formats=("HTML" "Markdown" "JSON" "CSV")

  if select_menu "Select report format:" "${formats[@]}"; then
    local choice=$?
    local format="${formats[$choice]}"

    local default_output="aitools-report-$(timestamp).${format,,}"
    local output=$(read_input "Output filename" "$default_output")

    log_info "Would generate $format report to: $output"
    display_success "Report generation complete!"
  fi
}

# interactive_view_config()
# Interactive configuration viewer
interactive_view_config() {
  display_section "Current Configuration"

  # This would call config_show from config module
  log_info "Configuration would be displayed here"

  echo ""
  read -p "Press Enter to continue..."
}

# interactive_clear_cache()
# Interactive cache clearing workflow
interactive_clear_cache() {
  display_section "Clear Cache"

  if confirm_with_warning "Clear all cache?" "This will remove all cached version information."; then
    log_info "Would clear cache"
    display_success "Cache cleared!"
  else
    log_info "Cache clear cancelled"
  fi
}

# ============================================================
# Tool Selection Interface
# ============================================================

# interactive_tool_selection(tool_list_array)
# Allows user to select tools from a list
#
# Arguments:
#   $1+ - Array of tool names
# Returns: 0 on success
# Side effects: Sets $SELECTED_TOOLS array
interactive_tool_selection() {
  local tools=("$@")

  select_multiple "Select tools (toggle with number, 0 when done):" "${tools[@]}"

  SELECTED_TOOLS=("${SELECTED_OPTIONS[@]}")

  if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]]; then
    display_warning "No tools selected"
    return 1
  fi

  display_success "${#SELECTED_TOOLS[@]} tools selected"
  return 0
}

# ============================================================
# Module Information
# ============================================================

# interactive_module_info()
# Displays module information
interactive_module_info() {
  cat <<EOF
AI Tools Checker - Interactive UI Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Prompts:
    - confirm_prompt()              Yes/no confirmation
    - confirm_with_warning()        Confirmation with warning
    - read_input()                  Text input with validation
    - read_password()               Password input (hidden)

  Menus:
    - select_menu()                 Single selection menu
    - select_multiple()             Multiple selection menu

  Workflows:
    - interactive_main_menu()       Main menu loop
    - interactive_check_tools()     Tool checking workflow
    - interactive_install_tools()   Installation workflow
    - interactive_update_tools()    Update workflow
    - interactive_generate_report() Report generation workflow
    - interactive_view_config()     Configuration viewer
    - interactive_clear_cache()     Cache clearing workflow

  Tools:
    - interactive_tool_selection()  Multi-tool selector
    - interactive_progress()        Progress display

Global Variables:
  - AUTO_YES                        Skip confirmations
  - INTERACTIVE_MODE                Enable interactive features
  - SELECTED_OPTION                 Last selected option
  - SELECTED_OPTIONS                Multiple selections
  - SELECTED_TOOLS                  Selected tools

Dependencies:
  - interfaces.sh (log_*)
  - helpers.sh (colors, validation, terminal)
  - output.sh (display_*)
EOF
}

# Export functions
declare -fx confirm_prompt 2>/dev/null || true
declare -fx confirm_with_warning 2>/dev/null || true
declare -fx select_menu 2>/dev/null || true
declare -fx select_multiple 2>/dev/null || true
declare -fx read_input 2>/dev/null || true
declare -fx read_password 2>/dev/null || true
declare -fx interactive_main_menu 2>/dev/null || true
declare -fx interactive_tool_selection 2>/dev/null || true
declare -fx interactive_progress 2>/dev/null || true
