#!/usr/bin/env bash
# AI Tools Checker - Installer Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides tool installation functionality including
# NPM tools, CLI tools, batch installation, and rollback support.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/../core/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../core/npm-tools.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../core/cli-tools.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true
source "${_MODULE_DIR}/rollback.sh" 2>/dev/null || true

# Installation configuration
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
ROLLBACK_ON_ERROR="${ROLLBACK_ON_ERROR:-true}"

# ============================================================
# Core Installation Function
# ============================================================

# execute_install(command, rollback_action, rollback_target)
# Executes an installation command with rollback support
#
# Arguments:
#   $1 - Installation command to execute
#   $2 - Rollback action type (optional)
#   $3 - Rollback target (optional)
# Returns: 0 on success, 1 on failure
execute_install() {
  local cmd="$1"
  local rollback_action="${2:-}"
  local rollback_target="${3:-}"

  # Dry run mode
  if [[ "$DRY_RUN" == "true" ]]; then
    print_blue "  [DRY-RUN] Would execute: $cmd"
    return 0
  fi

  log_debug "Executing: $cmd"

  # Log rollback information
  if [[ -n "$rollback_action" ]] && [[ -n "$rollback_target" ]]; then
    log_rollback "$rollback_action" "$rollback_target"
  fi

  # Execute command
  if eval "$cmd" 2>&1 | while IFS= read -r line; do
    echo "    $line"
  done; then
    log_info "Installation command succeeded"
    return 0
  else
    log_error "Installation command failed: $cmd"

    # Rollback on error
    if [[ "$ROLLBACK_ON_ERROR" == "true" ]]; then
      display_error "Installation failed" "Starting rollback..."
      execute_rollback
    fi
    return 1
  fi
}

# ============================================================
# NPM Tools Installation
# ============================================================

# install_npm_tool(package_name, [tool_name])
# Installs a single NPM package globally
#
# Arguments:
#   $1 - NPM package name
#   $2 - Tool display name (optional)
# Returns: 0 on success, 1 on failure
install_npm_tool() {
  local pkg="$1"
  local name="${2:-$pkg}"

  log_info "Installing NPM tool: $name ($pkg)"

  # Check if already installed (unless force)
  if [[ "$FORCE" != "true" ]]; then
    local cur
    cur=$(npm_current_version "$pkg")
    if [[ -n "$cur" ]]; then
      display_success "$name is already installed (v$cur)"
      return 0
    fi
  fi

  # Install
  print_blue "📦 Installing $name..."
  if execute_install "npm install -g $pkg" "npm_install" "$pkg"; then
    display_success "$name installed successfully"
    return 0
  else
    display_error "Failed to install $name"
    return 1
  fi
}

# install_npm_tools([tool_array])
# Installs multiple NPM tools
#
# Arguments:
#   $@ - Array of package names (optional, uses NPM_TOOLS if not provided)
# Returns: 0 if all succeed, 1 if any fail
install_npm_tools() {
  local tools=("$@")

  display_section "Installing NPM-based AI Tools"

  # Check npm availability
  if ! have npm; then
    display_error "npm is not installed" "Please install Node.js and npm first"
    return 1
  fi

  # Use default tools if none provided
  if [[ ${#tools[@]} -eq 0 ]]; then
    tools=("${!NPM_TOOLS[@]}")
  fi

  local success_count=0
  local fail_count=0
  local total=${#tools[@]}

  for name in "${tools[@]}"; do
    local pkg="${NPM_TOOLS[$name]:-$name}"

    if install_npm_tool "$pkg" "$name"; then
      success_count=$((success_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done

  # Summary
  echo ""
  print_blue "NPM Installation Summary:"
  echo "  Success: $success_count/$total"
  echo "  Failed:  $fail_count/$total"

  [[ $fail_count -eq 0 ]]
}

# ============================================================
# CLI Tools Installation
# ============================================================

# install_cli_tool(command_name, [tool_name])
# Installs a single CLI tool
#
# Arguments:
#   $1 - Command name
#   $2 - Tool display name (optional)
# Returns: 0 on success, 1 on failure
install_cli_tool() {
  local cmd="$1"
  local name="${2:-$cmd}"

  log_info "Installing CLI tool: $name ($cmd)"

  # Check if already installed (unless force)
  if [[ "$FORCE" != "true" ]]; then
    if cli_tool_exists "$cmd"; then
      local ver
      ver=$(cli_tool_version "$cmd")
      display_success "$name is already installed ($ver)"
      return 0
    fi
  fi

  # Tool-specific installation
  print_blue "📦 Installing $name..."

  case "$cmd" in
    cursor)
      # Cursor installation
      if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        display_warning "WSL detected: Install Cursor on Windows"
        echo "  Download from: https://cursor.sh"
        return 1
      else
        execute_install "curl -fsSL https://cursor.sh/install.sh | sh" "cli_install" "cursor"
      fi
      ;;

    coderabbit)
      # CodeRabbit via npm
      if have npm; then
        execute_install "npm install -g @coderabbitai/cli" "npm_install" "@coderabbitai/cli"
      else
        display_error "npm required for CodeRabbit installation"
        return 1
      fi
      ;;

    amp)
      # Amp installation
      execute_install "curl -fsSL https://ampcode.com/install.sh | bash" "cli_install" "amp"
      ;;

    droid)
      # Droid installation
      execute_install "curl -fsSL https://app.factory.ai/cli | sh" "cli_install" "droid"
      ;;

    *)
      display_error "Unknown CLI tool: $cmd" "No installation method configured"
      return 1
      ;;
  esac

  local result=$?
  if [[ $result -eq 0 ]]; then
    display_success "$name installed successfully"
  else
    display_error "Failed to install $name"
  fi

  return $result
}

# install_cli_tools([tool_array])
# Installs multiple CLI tools
#
# Arguments:
#   $@ - Array of command names (optional, uses CLI_TOOLS if not provided)
# Returns: 0 if all succeed, 1 if any fail
install_cli_tools() {
  local tools=("$@")

  display_section "Installing CLI Tools"

  # Use default tools if none provided
  if [[ ${#tools[@]} -eq 0 ]]; then
    tools=("${!CLI_TOOLS[@]}")
  fi

  local success_count=0
  local fail_count=0
  local total=${#tools[@]}

  for name in "${tools[@]}"; do
    local cmd="${CLI_TOOLS[$name]:-$name}"

    if install_cli_tool "$cmd" "$name"; then
      success_count=$((success_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done

  # Summary
  echo ""
  print_blue "CLI Installation Summary:"
  echo "  Success: $success_count/$total"
  echo "  Failed:  $fail_count/$total"

  [[ $fail_count -eq 0 ]]
}

# ============================================================
# Batch Installation
# ============================================================

# install_all_tools()
# Installs all registered tools (NPM + CLI)
#
# Returns: 0 if all succeed, 1 if any fail
install_all_tools() {
  display_header "Installing All AI Tools"

  local npm_result=0
  local cli_result=0

  # Install NPM tools
  if ! install_npm_tools; then
    npm_result=1
  fi

  # Install CLI tools
  if ! install_cli_tools; then
    cli_result=1
  fi

  # Overall summary
  echo ""
  display_section "Overall Installation Summary"

  if [[ $npm_result -eq 0 ]] && [[ $cli_result -eq 0 ]]; then
    display_success "All tools installed successfully!"
    return 0
  else
    display_warning "Some tools failed to install"
    return 1
  fi
}

# ============================================================
# Missing Tools Installation
# ============================================================

# install_missing_tools()
# Installs only tools that are not currently installed
#
# Returns: 0 on success
install_missing_tools() {
  display_section "Installing Missing Tools"

  local missing_npm=()
  local missing_cli=()

  # Find missing NPM tools
  if have npm; then
    for name in "${!NPM_TOOLS[@]}"; do
      local pkg="${NPM_TOOLS[$name]}"
      local cur
      cur=$(npm_current_version "$pkg")
      if [[ -z "$cur" ]]; then
        missing_npm+=("$name")
      fi
    done
  fi

  # Find missing CLI tools
  for name in "${!CLI_TOOLS[@]}"; do
    local cmd="${CLI_TOOLS[$name]}"
    if ! cli_tool_exists "$cmd"; then
      missing_cli+=("$name")
    fi
  done

  # Report findings
  echo "Missing NPM tools: ${#missing_npm[@]}"
  echo "Missing CLI tools: ${#missing_cli[@]}"
  echo ""

  if [[ ${#missing_npm[@]} -eq 0 ]] && [[ ${#missing_cli[@]} -eq 0 ]]; then
    display_success "All tools are already installed!"
    return 0
  fi

  # Install missing tools
  local success=true

  if [[ ${#missing_npm[@]} -gt 0 ]]; then
    if ! install_npm_tools "${missing_npm[@]}"; then
      success=false
    fi
  fi

  if [[ ${#missing_cli[@]} -gt 0 ]]; then
    if ! install_cli_tools "${missing_cli[@]}"; then
      success=false
    fi
  fi

  $success
}

# ============================================================
# Extra Tools Installation
# ============================================================

# install_extras()
# Installs additional useful tools (OpenAI CLI, etc.)
#
# Returns: 0 on success
install_extras() {
  display_section "Installing Extra Tools"

  local extras=(
    "openai:OpenAI CLI"
    "anthropic:Anthropic CLI"
  )

  for extra in "${extras[@]}"; do
    local pkg="${extra%%:*}"
    local name="${extra##*:}"

    print_blue "📦 Installing $name..."
    if execute_install "pip install -U $pkg" "pip_install" "$pkg"; then
      display_success "$name installed"
    else
      display_warning "Failed to install $name (pip may not be available)"
    fi
  done

  return 0
}

# ============================================================
# Module Information
# ============================================================

# installer_module_info()
# Displays module information
installer_module_info() {
  cat <<EOF
AI Tools Checker - Installer Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Core:
    - execute_install()         Execute with rollback support

  NPM Installation:
    - install_npm_tool()        Install single NPM package
    - install_npm_tools()       Install multiple NPM packages

  CLI Installation:
    - install_cli_tool()        Install single CLI tool
    - install_cli_tools()       Install multiple CLI tools

  Batch Operations:
    - install_all_tools()       Install all tools
    - install_missing_tools()   Install only missing tools
    - install_extras()          Install extra tools

Configuration:
  - DRY_RUN:            $DRY_RUN
  - FORCE:              $FORCE
  - ROLLBACK_ON_ERROR:  $ROLLBACK_ON_ERROR

Supported Tools:
  NPM: Claude Code, Gemini CLI, OpenAI Codex, Qwen Code
  CLI: Cursor, CodeRabbit, Amp, Droid

Dependencies:
  - interfaces.sh (log_*)
  - npm-tools.sh (NPM_TOOLS, npm_current_version)
  - cli-tools.sh (CLI_TOOLS, cli_tool_exists)
  - helpers.sh (display_*, print_*)
  - rollback.sh (log_rollback, execute_rollback)
EOF
}

# Export functions
declare -fx execute_install 2>/dev/null || true
declare -fx install_npm_tool 2>/dev/null || true
declare -fx install_npm_tools 2>/dev/null || true
declare -fx install_cli_tool 2>/dev/null || true
declare -fx install_cli_tools 2>/dev/null || true
declare -fx install_all_tools 2>/dev/null || true
declare -fx install_missing_tools 2>/dev/null || true
declare -fx install_extras 2>/dev/null || true
