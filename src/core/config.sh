#!/usr/bin/env bash
# AI Tools Checker - Configuration Management Module
# Version: 2.1.0
# Date: 2025-01-12

# This module handles configuration loading from multiple sources:
# 1. Configuration file (.aitools.config.json)
# 2. Environment variables
# 3. Default values
#
# Priority order: CLI arguments > Environment variables > Config file > Defaults

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true

# ============================================================
# Configuration File Locations
# ============================================================

# Default configuration file locations (checked in order)
declare -a CONFIG_SEARCH_PATHS=(
  "${HOME}/.aitools.config.json"
  "${HOME}/.config/aitools/config.json"
  "$(pwd)/.aitools.config.json"
  "/etc/aitools/config.json"
)

# Active configuration file (set by config_load)
CONFIG_FILE=""

# ============================================================
# Default Configuration Values
# ============================================================

# Cache defaults
declare -A CONFIG_DEFAULTS=(
  ["cache.enabled"]="true"
  ["cache.ttl"]="3600"
  ["cache.directory"]="${HOME}/.cache/aitools"

  # GitHub API defaults
  ["github.token"]=""
  ["github.rate_limit_threshold"]="10"

  # Output defaults
  ["output.verbose"]="false"
  ["output.color"]="auto"
  ["output.format"]="terminal"

  # Update defaults
  ["update.auto_check"]="true"
  ["update.check_interval"]="86400"

  # Notification defaults
  ["notification.enabled"]="false"
  ["notification.webhook_url"]=""
  ["notification.on_updates"]="false"

  # Install defaults
  ["install.auto_yes"]="false"
  ["install.dry_run"]="false"
  ["install.rollback_on_error"]="true"
)

# ============================================================
# Configuration File Discovery
# ============================================================

# find_config_file()
# Searches for configuration file in standard locations
#
# Returns: 0 if found, 1 if not found
# Outputs: Path to configuration file
find_config_file() {
  for path in "${CONFIG_SEARCH_PATHS[@]}"; do
    # Expand tilde and variables
    local expanded_path
    expanded_path=$(eval echo "$path")

    if [[ -f "$expanded_path" ]]; then
      echo "$expanded_path"
      return 0
    fi
  done

  return 1
}

# ============================================================
# Tool Profile Loading
# ============================================================

# config_load_tool_profiles()
# Loads tool profiles from the YAML configuration file
#
# Returns: 0 on success, 1 on failure
# Side effects: Populates NPM_TOOLS and CLI_TOOLS arrays
config_load_tool_profiles() {
  local profiles_file="${_MODULE_DIR}/../config/multi-ai-profiles.yaml"

  if [[ ! -f "$profiles_file" ]]; then
    log_warn "Tool profiles file not found: $profiles_file"
    return 1
  fi

  # Load NPM tools
  while IFS=: read -r key value; do
    local tool_name
    local package_name
    tool_name=$(trim "$key")
    package_name=$(trim "$value")
    NPM_TOOLS["$tool_name"]="$package_name"
  done < <(parse_yaml "$profiles_file" "npm_tools")

  # Load CLI tools
  while IFS=: read -r key value; do
    local tool_name
    local command_name
    tool_name=$(trim "$key")
    command_name=$(trim "$value")
    CLI_TOOLS["$tool_name"]="$command_name"
  done < <(parse_yaml "$profiles_file" "cli_tools")

  log_info "Tool profiles loaded successfully"
  return 0
}

# ============================================================
# Configuration Loading
# ============================================================

# config_load([config_file_path])
# Loads configuration from file and environment
#
# Arguments:
#   $1 - Optional path to config file (if not provided, searches standard locations)
# Returns: 0 on success, 1 on failure
# Side effects: Sets global configuration variables
#
# Example:
#   config_load
#   config_load "/custom/path/config.json"
config_load() {
  config_load_tool_profiles

  local custom_path="${1:-}"

  # Find config file
  if [[ -n "$custom_path" ]]; then
    if [[ -f "$custom_path" ]]; then
      CONFIG_FILE="$custom_path"
    else
      log_warn "Custom config file not found: $custom_path"
      return 1
    fi
  else
    if CONFIG_FILE=$(find_config_file); then
      log_debug "Found config file: $CONFIG_FILE"
    else
      log_debug "No config file found, using defaults"
      return 0  # Not an error, will use defaults
    fi
  fi

  # Check if jq is available
  if ! have jq; then
    log_warn "jq not found, cannot parse JSON config file"
    return 1
  fi

  # Validate JSON
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    log_error "Invalid JSON in config file: $CONFIG_FILE"
    return 1
  fi

  # Load cache configuration
  CACHE_ENABLED=$(config_get_from_file "cache.enabled" "true")
  CACHE_TTL=$(config_get_from_file "cache.ttl" "3600")
  CACHE_DIR=$(config_get_from_file "cache.directory" "${HOME}/.cache/aitools")
  CACHE_DIR=$(echo "$CACHE_DIR" | sed "s|~|$HOME|g")  # Expand tilde

  # Load GitHub configuration
  GITHUB_TOKEN=$(config_get_from_file "github.token" "")
  [[ "$GITHUB_TOKEN" == "null" ]] && GITHUB_TOKEN=""

  # Environment variable overrides config file
  GITHUB_TOKEN="${GITHUB_TOKEN:-${GITHUB_TOKEN_ENV:-}}"

  # Load output configuration
  local config_verbose
  config_verbose=$(config_get_from_file "output.verbose" "false")
  if [[ "$config_verbose" == "true" ]]; then
    VERBOSE="${VERBOSE:-true}"
  fi

  OUTPUT_COLOR=$(config_get_from_file "output.color" "auto")
  OUTPUT_FORMAT=$(config_get_from_file "output.format" "terminal")

  # Load update configuration
  AUTO_CHECK_UPDATES=$(config_get_from_file "update.auto_check" "true")
  UPDATE_CHECK_INTERVAL=$(config_get_from_file "update.check_interval" "86400")

  # Load notification configuration
  NOTIFICATION_ENABLED=$(config_get_from_file "notification.enabled" "false")
  WEBHOOK_URL=$(config_get_from_file "notification.webhook_url" "")
  ALERT_ON_UPDATES=$(config_get_from_file "notification.on_updates" "false")

  # Load install configuration
  AUTO_YES=$(config_get_from_file "install.auto_yes" "false")
  DRY_RUN=$(config_get_from_file "install.dry_run" "false")
  ROLLBACK_ON_ERROR=$(config_get_from_file "install.rollback_on_error" "true")

  log_info "Configuration loaded successfully"
  return 0
}

# ============================================================
# Configuration Access
# ============================================================

# config_get_from_file(key, [default])
# Gets a configuration value from the loaded config file
#
# Arguments:
#   $1 - Configuration key (dot notation, e.g., "cache.enabled")
#   $2 - Default value (optional)
# Returns: Always returns 0
# Outputs: Configuration value to stdout
#
# Example:
#   cache_ttl=$(config_get_from_file "cache.ttl" "3600")
config_get_from_file() {
  local key="$1"
  local default="${2:-}"

  # No config file loaded
  if [[ -z "$CONFIG_FILE" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    echo "$default"
    return 0
  fi

  # jq not available
  if ! have jq; then
    echo "$default"
    return 0
  fi

  # Get value using jq (do not use // operator as it treats false as falsy)
  local value
  value=$(jq -r ".${key}" "$CONFIG_FILE" 2>/dev/null)

  # Handle null or empty
  if [[ "$value" == "null" ]] || [[ -z "$value" ]]; then
    echo "$default"
  else
    echo "$value"
  fi

  return 0
}

# config_get(key, [default])
# Gets a configuration value with priority: env > file > default
#
# Arguments:
#   $1 - Configuration key (dot notation)
#   $2 - Default value (optional)
# Returns: Always returns 0
# Outputs: Configuration value to stdout
#
# Example:
#   cache_dir=$(config_get "cache.directory" "${HOME}/.cache/aitools")
config_get() {
  local key="$1"
  local default="${2:-${CONFIG_DEFAULTS[$key]:-}}"

  # Convert dot notation to env var format (cache.enabled -> AITOOLS_CACHE_ENABLED)
  local env_key
  env_key="AITOOLS_$(echo "$key" | tr '[:lower:].' '[:upper:]_')"

  # Check environment variable first
  if [[ -n "${!env_key:-}" ]]; then
    echo "${!env_key}"
    return 0
  fi

  # Check config file
  local file_value
  file_value=$(config_get_from_file "$key" "")

  if [[ -n "$file_value" ]]; then
    echo "$file_value"
    return 0
  fi

  # Return default
  echo "$default"
  return 0
}

# ============================================================
# Configuration Setting (Runtime)
# ============================================================

# config_set(key, value)
# Sets a configuration value at runtime (does not persist to file)
#
# Arguments:
#   $1 - Configuration key
#   $2 - Value to set
# Returns: Always returns 0
#
# Example:
#   config_set "cache.enabled" "false"
config_set() {
  local key="$1"
  local value="$2"

  # Store in defaults array (runtime only)
  CONFIG_DEFAULTS["$key"]="$value"

  log_debug "Config set: $key = $value"
  return 0
}

# ============================================================
# Configuration Validation
# ============================================================

# config_validate()
# Validates the loaded configuration
#
# Returns: 0 if valid, 1 if invalid
# Outputs: Error messages for invalid settings
config_validate() {
  local errors=0

  # Validate cache.ttl (must be positive integer)
  local cache_ttl
  cache_ttl=$(config_get "cache.ttl")
  if ! [[ "$cache_ttl" =~ ^[0-9]+$ ]]; then
    log_error "Invalid cache.ttl: must be a positive integer"
    errors=$((errors + 1))
  fi

  # Validate cache.directory (must be writable if exists)
  local cache_dir
  cache_dir=$(config_get "cache.directory")
  cache_dir=$(echo "$cache_dir" | sed "s|~|$HOME|g")
  if [[ -d "$cache_dir" ]] && [[ ! -w "$cache_dir" ]]; then
    log_error "Invalid cache.directory: not writable: $cache_dir"
    errors=$((errors + 1))
  fi

  # Validate webhook URL format (if provided)
  local webhook
  webhook=$(config_get "notification.webhook_url")
  if [[ -n "$webhook" ]] && ! [[ "$webhook" =~ ^https?:// ]]; then
    log_error "Invalid notification.webhook_url: must start with http:// or https://"
    errors=$((errors + 1))
  fi

  if [[ $errors -gt 0 ]]; then
    log_error "Configuration validation failed with $errors error(s)"
    return 1
  fi

  log_debug "Configuration validated successfully"
  return 0
}

# ============================================================
# Configuration Display
# ============================================================

# config_show([filter])
# Displays current configuration
#
# Arguments:
#   $1 - Optional filter (e.g., "cache" to show only cache settings)
# Returns: Always returns 0
config_show() {
  local filter="${1:-}"

  cat <<EOF
AI Tools Checker Configuration
==============================

Config File: ${CONFIG_FILE:-"Not found (using defaults)"}

Cache Settings:
  Enabled:    $(config_get "cache.enabled")
  TTL:        $(config_get "cache.ttl") seconds
  Directory:  $(config_get "cache.directory")

GitHub Settings:
  Token:      $([ -n "$(config_get "github.token")" ] && echo "***set***" || echo "not set")

Output Settings:
  Verbose:    $(config_get "output.verbose")
  Color:      $(config_get "output.color")
  Format:     $(config_get "output.format")

Update Settings:
  Auto Check: $(config_get "update.auto_check")
  Interval:   $(config_get "update.check_interval") seconds

Notification Settings:
  Enabled:    $(config_get "notification.enabled")
  Webhook:    $([ -n "$(config_get "notification.webhook_url")" ] && echo "configured" || echo "not configured")
  On Updates: $(config_get "notification.on_updates")

Install Settings:
  Auto Yes:   $(config_get "install.auto_yes")
  Dry Run:    $(config_get "install.dry_run")
  Rollback:   $(config_get "install.rollback_on_error")
EOF

  return 0
}

# ============================================================
# Module Information
# ============================================================

# config_module_info()
# Displays module information
config_module_info() {
  cat <<EOF
AI Tools Checker - Configuration Management Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  - config_load()           Load configuration from file/env
  - config_get()            Get configuration value (env > file > default)
  - config_set()            Set runtime configuration value
  - config_validate()       Validate configuration
  - config_show()           Display current configuration
  - find_config_file()      Search for config file

Configuration Priority:
  1. CLI arguments (highest)
  2. Environment variables (AITOOLS_*)
  3. Configuration file (.aitools.config.json)
  4. Default values (lowest)

Dependencies: interfaces.sh (have, log_*)
EOF
}

# Export functions
declare -fx config_load 2>/dev/null || true
declare -fx config_get 2>/dev/null || true
declare -fx config_set 2>/dev/null || true
declare -fx config_validate 2>/dev/null || true
declare -fx config_show 2>/dev/null || true
declare -fx find_config_file 2>/dev/null || true
