#!/usr/bin/env bash
# AI Tools Checker - Updater Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides tool update functionality including version checking,
# breaking changes detection, backup/restore, and auto-update mode.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/../core/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../core/npm-tools.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../core/cli-tools.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../core/version-checker.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true
source "${_MODULE_DIR}/rollback.sh" 2>/dev/null || true

# Update configuration
UPDATE_DRY_RUN="${UPDATE_DRY_RUN:-false}"
UPDATE_AUTO="${UPDATE_AUTO:-false}"
UPDATE_SKIP_BREAKING="${UPDATE_SKIP_BREAKING:-false}"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/.cache/aitools/backups}"

# Ensure backup directory exists
ensure_directory "$BACKUP_DIR"

# ============================================================
# Version Check Functions
# ============================================================

# check_update_available(package, current_version)
# Checks if an update is available for a package
#
# Arguments:
#   $1 - Package name
#   $2 - Current version
# Returns: 0 if update available, 1 if up-to-date, 2 on fetch failure
# Outputs: Latest version to stdout
check_update_available() {
  local pkg="$1"
  local current="$2"

  log_debug "Checking updates for: $pkg (current: $current)"

  # Get latest version
  local latest
  latest=$(npm_latest_version "$pkg")

  if [[ -z "$latest" ]]; then
    log_warn "Could not fetch latest version for: $pkg"
    return 2
  fi

  # Compare versions
  local cmp
  log_debug "Comparing versions: $current vs $latest"
  cmp=$(vercmp "$current" "$latest")
  log_debug "Version comparison result: $cmp"

  if [[ $cmp -lt 0 ]]; then
    echo "$latest"
    return 0
  fi

  return 1
}

# check_breaking_update(current, latest)
# Checks if the update contains breaking changes (major version bump)
#
# Arguments:
#   $1 - Current version
#   $2 - Latest version
# Returns: 0 if breaking, 1 if not
check_breaking_update() {
  local current="$1"
  local latest="$2"

  if check_breaking_changes "$current" "$latest"; then
    return 0
  fi

  return 1
}

# ============================================================
# Backup Functions
# ============================================================

# backup_npm_package(package_name, version)
# Creates a backup of package metadata before update
#
# Arguments:
#   $1 - Package name
#   $2 - Current version
# Returns: 0 on success, 1 on failure
# Outputs: Backup file path to stdout
backup_npm_package() {
  local pkg="$1"
  local version="$2"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local safe_pkg
  safe_pkg=$(echo "$pkg" | sed 's/[\/:]/_/g')
  local backup_file="${BACKUP_DIR}/${safe_pkg}_${version}_${timestamp}.backup"

  log_info "Creating backup: $backup_file"

  # Create backup metadata
  cat > "$backup_file" <<BACKUPEOF
{
  "package": "$pkg",
  "version": "$version",
  "timestamp": "$timestamp",
  "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
BACKUPEOF

  if [[ -f "$backup_file" ]]; then
    echo "$backup_file"
    log_debug "Backup created successfully: $backup_file"
    return 0
  else
    log_error "Failed to create backup: $backup_file"
    return 1
  fi
}

# list_backups([package_name])
# Lists all backups, optionally filtered by package name
#
# Arguments:
#   $1 - Optional package name filter
# Returns: 0 on success
list_backups() {
  local filter="${1:-}"
  local safe_filter=""
  if [[ -n "$filter" ]]; then
    safe_filter=$(echo "$filter" | sed 's/[\/:]/_/g')
  fi

  display_section "Available Backups"

  if [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
    echo "No backups found in: $BACKUP_DIR"
    return 0
  fi

  local count=0
  for backup in "$BACKUP_DIR"/*.backup; do
    [[ ! -f "$backup" ]] && continue

    local filename=$(basename "$backup")

    # Filter by package if specified
    if [[ -n "$safe_filter" ]] && [[ ! "$filename" =~ ^${safe_filter}_ ]]; then
      continue
    fi

    count=$((count + 1))
    print_blue "  $count. $filename"

    # Extract metadata
    if have jq && [[ -f "$backup" ]]; then
      local pkg=$(jq -r '.package // empty' "$backup" 2>/dev/null)
      local ver=$(jq -r '.version // empty' "$backup" 2>/dev/null)
      local date=$(jq -r '.backup_date // empty' "$backup" 2>/dev/null)

      if [[ -n "$pkg" ]]; then
        echo "     Package: $pkg"
        echo "     Version: $ver"
        echo "     Date:    $date"
      fi
    fi
    echo ""
  done

  echo "Total backups: $count"
  return 0
}

# ============================================================
# NPM Tool Update Functions
# ============================================================

# update_npm_tool(package_name, [target_version])
# Updates a single NPM package to latest or specified version
#
# Arguments:
#   $1 - NPM package name
#   $2 - Target version (optional, defaults to latest)
# Returns: 0 on success, 1 on failure
update_npm_tool() {
  local pkg="$1"
  local target_version="${2:-latest}"

  log_info "Updating NPM tool: $pkg to $target_version"

  # Get current version
  local current
  current=$(npm_current_version "$pkg")

  if [[ -z "$current" ]]; then
    display_error "$pkg is not installed" "Cannot update"
    return 1
  fi

  # Check if update is available
  local latest
  if [[ "$target_version" == "latest" ]]; then
    latest=$(npm_latest_version "$pkg")
    if [[ -z "$latest" ]]; then
      display_error "Could not fetch latest version for $pkg"
      return 1
    fi

    # Compare versions
    local cmp
    cmp=$(vercmp "$current" "$latest")
    if [[ $cmp -ge 0 ]]; then
      display_success "$pkg is already up-to-date (v$current)"
      return 0
    fi
  else
    latest="$target_version"
  fi

  # Check for breaking changes
  if check_breaking_update "$current" "$latest"; then
    display_warning "Breaking changes detected: $current → $latest"

    if [[ "$UPDATE_SKIP_BREAKING" == "true" ]]; then
      display_warning "Skipping breaking update (UPDATE_SKIP_BREAKING=true)"
      return 1
    fi

    if [[ "$UPDATE_AUTO" != "true" ]]; then
      if ! confirm_prompt "Major version update may contain breaking changes. Continue?" "n"; then
        log_info "User cancelled breaking update"
        return 1
      fi
    fi
  fi

  # Create backup
  local backup_file
  backup_file=$(backup_npm_package "$pkg" "$current")

  if [[ -z "$backup_file" ]]; then
    display_warning "Backup failed, but continuing with update..."
  fi

  # Dry run mode
  if [[ "$UPDATE_DRY_RUN" == "true" ]]; then
    print_blue "  [DRY-RUN] Would update: $pkg from $current to $latest"
    return 0
  fi

  # Execute update
  print_blue "📦 Updating $pkg: $current → $latest"

  if npm install -g "$pkg@$latest" 2>&1 | while IFS= read -r line; do
    echo "    $line"
  done; then
    # Validate update
    local new_version
    new_version=$(npm_current_version "$pkg")

    if [[ "$new_version" == "$latest" ]]; then
      display_success "$pkg updated successfully: $current → $latest"
      log_rollback "npm_install" "$pkg" "Updated from $current to $latest"
      return 0
    else
      display_error "Update validation failed" "Expected $latest, got $new_version"
      return 1
    fi
  else
    display_error "Failed to update $pkg"
    return 1
  fi
}

# update_npm_tools([tool_array])
# Updates multiple NPM tools
#
# Arguments:
#   $@ - Array of package names (optional, uses NPM_TOOLS if not provided)
# Returns: 0 if all succeed, 1 if any fail
update_npm_tools() {
  local tools=("$@")

  display_section "Updating NPM-based AI Tools"

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
  local skip_count=0
  local total=${#tools[@]}

  for name in "${tools[@]}"; do
    local pkg="${NPM_TOOLS[$name]:-$name}"

    # Check if update is available
    local current
    current=$(npm_current_version "$pkg")

    if [[ -z "$current" ]]; then
      print_yellow "  ⊘ $name: Not installed, skipping"
      skip_count=$((skip_count + 1))
      continue
    fi

    local latest=""
    local check_status=0
    if latest=$(check_update_available "$pkg" "$current"); then
      check_status=0
    else
      check_status=$?
    fi

    case "$check_status" in
      0)
        # Update available
        if update_npm_tool "$pkg" "$latest"; then
          success_count=$((success_count + 1))
        else
          fail_count=$((fail_count + 1))
        fi
        ;;
      1)
        print_green "  ✓ $name: Up-to-date (v$current)"
        success_count=$((success_count + 1))
        continue
        ;;
      2)
        display_warning "$name: Could not determine latest version (skipping)"
        fail_count=$((fail_count + 1))
        continue
        ;;
      *)
        display_warning "$name: Unknown update status (skipping)"
        fail_count=$((fail_count + 1))
        continue
        ;;
    esac
  done

  # Summary
  echo ""
  print_blue "NPM Update Summary:"
  echo "  Updated:  $success_count/$total"
  echo "  Failed:   $fail_count/$total"
  echo "  Skipped:  $skip_count/$total"

  [[ $fail_count -eq 0 ]]
}

# ============================================================
# CLI Tool Update Functions
# ============================================================

# update_cli_tool(command_name)
# Handles CLI tool updates (with proprietary tool notifications)
#
# Arguments:
#   $1 - Command name
# Returns: 0 on success, 1 on failure
update_cli_tool() {
  local cmd="$1"
  local name="${2:-$cmd}"

  log_info "Checking update for CLI tool: $name ($cmd)"

  # Check if installed
  if ! cli_tool_exists "$cmd"; then
    display_warning "$name is not installed"
    return 1
  fi

  local current
  current=$(cli_tool_version "$cmd")

  # Check if proprietary
  if is_proprietary_tool "$cmd"; then
    display_info "Proprietary Tool: $name"
    echo "  Current version: $current"
    echo ""
    print_yellow "  ⓘ Proprietary tools must be updated through their official channels:"
    echo ""

    case "$cmd" in
      cursor)
        echo "  • Download from: https://cursor.sh"
        echo "  • Or use built-in updater: Help → Check for Updates"
        ;;
      coderabbit)
        echo "  • CodeRabbit updates automatically"
        echo "  • Check status at: https://coderabbit.ai"
        ;;
      amp)
        echo "  • Download from: https://ampcode.com"
        echo "  • Or run: curl -fsSL https://ampcode.com/install.sh | bash"
        ;;
      droid)
        echo "  • Download from: https://app.factory.ai"
        echo "  • Or run: curl -fsSL https://app.factory.ai/cli | sh"
        ;;
    esac

    echo ""
    return 0
  fi

  # Non-proprietary CLI tool updates (rare, usually NPM-based)
  display_info "CLI tool updates vary by installation method"
  echo "  Tool: $name"
  echo "  Current: $current"
  echo ""
  print_yellow "  Please check the tool's official documentation for update instructions"

  return 0
}

# update_cli_tools([tool_array])
# Updates multiple CLI tools
#
# Arguments:
#   $@ - Array of command names (optional, uses CLI_TOOLS if not provided)
# Returns: 0 on success
update_cli_tools() {
  local tools=("$@")

  display_section "Updating CLI Tools"

  # Use default tools if none provided
  if [[ ${#tools[@]} -eq 0 ]]; then
    tools=("${!CLI_TOOLS[@]}")
  fi

  for name in "${tools[@]}"; do
    local cmd="${CLI_TOOLS[$name]:-$name}"
    update_cli_tool "$cmd" "$name"
  done

  return 0
}

# ============================================================
# Batch Update Functions
# ============================================================

# update_all_tools()
# Updates all registered tools (NPM + CLI notifications)
#
# Returns: 0 if all succeed, 1 if any fail
update_all_tools() {
  display_header "Updating All AI Tools"

  local npm_result=0
  local cli_result=0

  # Update NPM tools
  if ! update_npm_tools; then
    npm_result=1
  fi

  # Update CLI tools (notifications only)
  if ! update_cli_tools; then
    cli_result=1
  fi

  # Overall summary
  echo ""
  display_section "Overall Update Summary"

  if [[ $npm_result -eq 0 ]] && [[ $cli_result -eq 0 ]]; then
    display_success "All tools updated successfully!"
    return 0
  else
    display_warning "Some tools could not be updated"
    return 1
  fi
}

# update_outdated_tools()
# Updates only tools that have updates available
#
# Returns: 0 on success
update_outdated_tools() {
  display_section "Updating Outdated Tools"

  local outdated_npm=()

  # Find outdated NPM tools
  if have npm; then
    log_debug "Starting NPM tools check. NPM_TOOLS has ${#NPM_TOOLS[@]} entries"
    # Convert associative array keys to indexed array to avoid iteration issues
    local tool_names=()
    for name in "${!NPM_TOOLS[@]}"; do
      tool_names+=("$name")
    done
    log_debug "Tool names: ${tool_names[*]}"
    
    # Now iterate over the indexed array
    for name in "${tool_names[@]}"; do
      local pkg="${NPM_TOOLS[$name]}"
      log_debug "Checking tool: $name -> $pkg"
      local current
      current=$(npm_current_version "$pkg" || echo "")

      if [[ -n "$current" ]]; then
        local latest=""
        local check_status=0
        if latest=$(check_update_available "$pkg" "$current"); then
          check_status=0
        else
          check_status=$?
        fi

        case "$check_status" in
          0)
            outdated_npm+=("$name")
            print_blue "  • $name: $current → $latest"
            ;;
          1)
            print_green "  ✓ $name: Up-to-date (v$current)"
            ;;
          2)
            display_warning "$name: Could not determine latest version (excluded from update list)"
            ;;
          *)
            display_warning "$name: Unknown update status (excluded from update list)"
            ;;
        esac
      fi
      log_debug "Finished checking $name"
    done
    log_debug "Finished checking all NPM tools. Found ${#outdated_npm[@]} outdated tools"
  fi

  echo ""
  echo "Outdated NPM tools: ${#outdated_npm[@]}"
  echo ""

  if [[ ${#outdated_npm[@]} -eq 0 ]]; then
    display_success "All tools are up-to-date!"
    return 0
  fi

  # Update outdated tools
  if [[ ${#outdated_npm[@]} -gt 0 ]]; then
    update_npm_tools "${outdated_npm[@]}"
  fi

  return 0
}

# ============================================================
# Auto-Update Mode
# ============================================================

# auto_update_all()
# Automatically updates all tools without prompts (respects UPDATE_SKIP_BREAKING)
#
# Returns: 0 on success
auto_update_all() {
  local old_auto="$UPDATE_AUTO"
  UPDATE_AUTO="true"

  display_header "Auto-Update Mode"

  if [[ "$UPDATE_SKIP_BREAKING" == "true" ]]; then
    display_warning "Breaking changes will be skipped (UPDATE_SKIP_BREAKING=true)"
  fi

  update_outdated_tools

  UPDATE_AUTO="$old_auto"
  return 0
}

# ============================================================
# Module Information
# ============================================================

# updater_module_info()
# Displays module information
updater_module_info() {
  cat <<EOF
AI Tools Checker - Updater Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Version Checking:
    - check_update_available()      Check if update available
    - check_breaking_update()       Detect breaking changes

  Backup:
    - backup_npm_package()          Create pre-update backup
    - list_backups()                List all backups

  NPM Updates:
    - update_npm_tool()             Update single NPM package
    - update_npm_tools()            Update multiple NPM packages

  CLI Updates:
    - update_cli_tool()             CLI tool update (notifications)
    - update_cli_tools()            Multiple CLI tools

  Batch Operations:
    - update_all_tools()            Update all tools
    - update_outdated_tools()       Update only outdated tools
    - auto_update_all()             Auto-update mode

Configuration:
  - UPDATE_DRY_RUN:         $UPDATE_DRY_RUN
  - UPDATE_AUTO:            $UPDATE_AUTO
  - UPDATE_SKIP_BREAKING:   $UPDATE_SKIP_BREAKING
  - BACKUP_DIR:             $BACKUP_DIR

Dependencies:
  - interfaces.sh (log_*)
  - npm-tools.sh (NPM_TOOLS, npm_current_version, npm_latest_version)
  - cli-tools.sh (CLI_TOOLS, cli_tool_exists, is_proprietary_tool)
  - version-checker.sh (vercmp, check_breaking_changes)
  - helpers.sh (display_*, print_*, confirm_prompt)
  - rollback.sh (log_rollback)
EOF
}

# Export functions
declare -fx check_update_available 2>/dev/null || true
declare -fx check_breaking_update 2>/dev/null || true
declare -fx backup_npm_package 2>/dev/null || true
declare -fx list_backups 2>/dev/null || true
declare -fx update_npm_tool 2>/dev/null || true
declare -fx update_npm_tools 2>/dev/null || true
declare -fx update_cli_tool 2>/dev/null || true
declare -fx update_cli_tools 2>/dev/null || true
declare -fx update_all_tools 2>/dev/null || true
declare -fx update_outdated_tools 2>/dev/null || true
declare -fx auto_update_all 2>/dev/null || true
