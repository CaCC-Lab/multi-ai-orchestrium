#!/usr/bin/env bash
# AI Tools Checker - CLI Tools Detection Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides CLI tool detection and version checking functionality.
# It handles proprietary tools like Cursor, CodeRabbit, Amp, and Droid.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/version-checker.sh" 2>/dev/null || true

# ============================================================
# CLI Tools Registry
# ============================================================

# Default CLI tools to check
declare -gA CLI_TOOLS=(
  ["Cursor"]="cursor"
  ["CodeRabbit"]="coderabbit"
  ["Amp"]="amp"
  ["Droid"]="droid"
)

# ============================================================
# CLI Tool Existence Check
# ============================================================

# cli_tool_exists(command_name)
# Checks if a CLI tool is installed
#
# Arguments:
#   $1 - Command name (e.g., "cursor", "amp")
# Returns: 0 if exists, 1 if not found
cli_tool_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# ============================================================
# CLI Tool Version Detection
# ============================================================

# cli_tool_version(command_name)
# Gets the version of a CLI tool
#
# Arguments:
#   $1 - Command name
# Returns: 0 if successful, 1 if failed
# Outputs: Version string to stdout
#
# Strategy:
#   - Tool-specific version extraction
#   - Tries multiple flags: --version, -V, -v, version
#   - Extracts semantic version from output
cli_tool_version() {
  local cmd="$1"

  if ! cli_tool_exists "$cmd"; then
    log_debug "CLI tool not found: $cmd"
    echo ""
    return 1
  fi

  local version=""

  # Tool-specific version detection
  case "$cmd" in
    cursor)
      # Cursor: Try multiple methods
      if command -v cursor &>/dev/null; then
        # Method 1: cursor --version
        version=$(cursor --version 2>/dev/null | head -1 || echo "")
        # Method 2: cursor-agent --version (alternative)
        if [[ -z "$version" ]] && command -v cursor-agent &>/dev/null; then
          version=$(cursor-agent --version 2>/dev/null | head -1 || echo "")
        fi
        # Extract date-based version (e.g., "2024.01.15")
        if [[ -n "$version" ]]; then
          version=$(echo "$version" | grep -Eo '[0-9]{4}\.[0-9]{2}\.[0-9]{2}' | head -1 || echo "$version")
        fi
      fi
      ;;

    coderabbit)
      # CodeRabbit: --version flag
      version=$(coderabbit --version 2>/dev/null | head -1 || echo "")
      # Remove 'v' prefix if present
      version=$(echo "$version" | sed 's/^v//' || echo "")
      ;;

    amp)
      # Amp: Uses -V (uppercase) not -v
      version=$(amp -V 2>/dev/null | head -1 || echo "")
      # Extract version from output (e.g., "0.0.1760256079-gf0b2aa")
      ;;

    droid)
      # Droid: --version flag (may have terminal issues)
      # Using timeout to avoid hanging
      version=$(timeout 2s droid --version 2>/dev/null | head -1 || echo "")
      # Fallback: Try -V
      if [[ -z "$version" ]]; then
        version=$(timeout 2s droid -V 2>/dev/null | head -1 || echo "")
      fi
      ;;

    *)
      # Generic CLI tool: Try common version flags
      # Try --version first (most common)
      version=$($cmd --version 2>/dev/null | head -1 || echo "")

      # Try -v if --version failed
      if [[ -z "$version" ]]; then
        version=$($cmd -v 2>/dev/null | head -1 || echo "")
      fi

      # Try -V if -v failed
      if [[ -z "$version" ]]; then
        version=$($cmd -V 2>/dev/null | head -1 || echo "")
      fi

      # Try version subcommand
      if [[ -z "$version" ]]; then
        version=$($cmd version 2>/dev/null | head -1 || echo "")
      fi
      ;;
  esac

  # Extract semantic version if possible
  if [[ -n "$version" ]] && declare -f semver &>/dev/null; then
    local semver_extracted
    semver_extracted=$(semver "$version")
    if [[ -n "$semver_extracted" ]]; then
      version="$semver_extracted"
    fi
  fi

  # If still no version, mark as "installed"
  if [[ -z "$version" ]]; then
    version="installed"
  fi

  log_debug "CLI tool version: $cmd = $version"
  echo "$version"
  return 0
}

# ============================================================
# Proprietary Tool Detection
# ============================================================

# is_proprietary_tool(command_name)
# Checks if a tool is proprietary (no public latest version)
#
# Arguments:
#   $1 - Command name
# Returns: 0 if proprietary, 1 if not
is_proprietary_tool() {
  local cmd="$1"

  case "$cmd" in
    cursor|coderabbit|amp|droid)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ============================================================
# CLI Latest Version Detection
# ============================================================

# cli_latest_version(command_name)
# Gets the latest version of a CLI tool (if available)
#
# Arguments:
#   $1 - Command name
# Returns: 0 if found, 1 if not available
# Outputs: Version string to stdout, or empty for proprietary tools
#
# Note: Most CLI tools don't have a programmatic way to check latest version
#       Returns empty for proprietary tools
cli_latest_version() {
  local cmd="$1"

  # Proprietary tools: No public latest version
  if is_proprietary_tool "$cmd"; then
    log_debug "CLI tool is proprietary: $cmd"
    echo ""
    return 1
  fi

  # For open source CLI tools, could check GitHub releases
  # (Implementation would depend on specific tool)
  echo ""
  return 1
}

# ============================================================
# CLI Tools Detection (Main Function)
# ============================================================

# detect_cli_tools()
# Detects all CLI-based AI tools and their versions
#
# Arguments: None
# Returns: 0 on success, 1 on failure
# Outputs: JSON array of tool information to stdout
detect_cli_tools() {
  log_info "Detecting CLI-based AI tools..."

  local results=()
  local tool_count=0
  local detected_count=0

  for name in "${!CLI_TOOLS[@]}"; do
    local cmd="${CLI_TOOLS[$name]}"
    tool_count=$((tool_count + 1))

    log_debug "Checking CLI tool: $name ($cmd)"

    # Get versions
    local current
    local latest
    current=$(cli_tool_version "$cmd")
    latest=$(cli_latest_version "$cmd")

    # Determine status
    local status
    if [[ -z "$current" ]] || [[ "$current" == "not found" ]]; then
      status="NOT_INSTALLED"
    elif is_proprietary_tool "$cmd"; then
      status="INSTALLED"  # Proprietary tools: just show installed
    elif [[ -z "$latest" ]]; then
      status="UNKNOWN"
    else
      # Use version-checker module if available
      if declare -f determine_version_status &>/dev/null; then
        status=$(determine_version_status "$current" "$latest")
      else
        status="INSTALLED"
      fi
    fi

    # Count detected tools
    if [[ -n "$current" ]] && [[ "$current" != "not found" ]]; then
      detected_count=$((detected_count + 1))
    fi

    # Build JSON object
    local latest_display
    if is_proprietary_tool "$cmd"; then
      latest_display="proprietary"
    else
      latest_display="${latest:-null}"
    fi

    local json_obj
    json_obj=$(cat <<EOF
{
  "name": "$name",
  "command": "$cmd",
  "current": "${current:-null}",
  "latest": "$latest_display",
  "status": "$status",
  "type": "cli",
  "proprietary": $(is_proprietary_tool "$cmd" && echo "true" || echo "false")
}
EOF
)

    results+=("$json_obj")
  done

  # Output JSON array
  echo "["
  local first=true
  for result in "${results[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo ","
    fi
    echo "$result"
  done
  echo "]"

  log_info "CLI tools detection complete: $detected_count/$tool_count detected"
  return 0
}

# ============================================================
# CLI Tools List Management
# ============================================================

# cli_add_tool(name, command)
# Adds a tool to the CLI tools registry
#
# Arguments:
#   $1 - Tool display name
#   $2 - Command name
# Returns: Always returns 0
cli_add_tool() {
  local name="$1"
  local command="$2"

  CLI_TOOLS["$name"]="$command"
  log_debug "Added CLI tool: $name ($command)"
  return 0
}

# cli_remove_tool(name)
# Removes a tool from the CLI tools registry
#
# Arguments:
#   $1 - Tool display name
# Returns: Always returns 0
cli_remove_tool() {
  local name="$1"

  unset 'CLI_TOOLS[$name]'
  log_debug "Removed CLI tool: $name"
  return 0
}

# cli_list_tools()
# Lists all registered CLI tools
#
# Returns: Always returns 0
# Outputs: Tool names and commands
cli_list_tools() {
  echo "Registered CLI Tools:"
  echo "===================="
  for name in "${!CLI_TOOLS[@]}"; do
    local cmd="${CLI_TOOLS[$name]}"
    local proprietary=""
    if is_proprietary_tool "$cmd"; then
      proprietary=" (proprietary)"
    fi
    printf "  %-20s %-20s%s\n" "$name" "$cmd" "$proprietary"
  done
  return 0
}

# ============================================================
# Module Information
# ============================================================

# cli_tools_module_info()
# Displays module information
cli_tools_module_info() {
  cat <<EOF
AI Tools Checker - CLI Tools Detection Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  - cli_tool_exists()        Check if CLI tool is installed
  - cli_tool_version()       Get version of CLI tool
  - cli_latest_version()     Get latest version (limited support)
  - is_proprietary_tool()    Check if tool is proprietary
  - detect_cli_tools()       Detect all registered CLI tools
  - cli_add_tool()           Add tool to registry
  - cli_remove_tool()        Remove tool from registry
  - cli_list_tools()         List registered tools

Version Detection:
  - Cursor:     --version, cursor-agent fallback
  - CodeRabbit: --version
  - Amp:        -V (uppercase)
  - Droid:      --version with timeout
  - Generic:    --version, -v, -V, version subcommand

Default Tools:
  - Cursor (proprietary)
  - CodeRabbit (proprietary)
  - Amp (proprietary)
  - Droid (proprietary)

Dependencies: interfaces.sh (have, log_*), version-checker.sh (semver)
EOF
}

# Export functions
declare -fx cli_tool_exists 2>/dev/null || true
declare -fx cli_tool_version 2>/dev/null || true
declare -fx cli_latest_version 2>/dev/null || true
declare -fx is_proprietary_tool 2>/dev/null || true
declare -fx detect_cli_tools 2>/dev/null || true
declare -fx cli_add_tool 2>/dev/null || true
declare -fx cli_remove_tool 2>/dev/null || true
declare -fx cli_list_tools 2>/dev/null || true
