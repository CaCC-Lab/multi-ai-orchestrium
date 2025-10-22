#!/usr/bin/env bash
# AI Tools Checker - NPM Tools Detection Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides NPM package detection and version checking functionality.
# It includes 4-stage fallback detection and NPM registry integration.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/cache.sh" 2>/dev/null || true

# ============================================================
# NPM Tools Registry
# ============================================================

# Default NPM tools to check
declare -gA NPM_TOOLS=(
  ["Claude Code"]="@anthropic-ai/claude-code"
  ["Gemini CLI"]="@google/gemini-cli"
  ["OpenAI Codex"]="@openai/codex"
  ["Qwen Code"]="@qwen-code/qwen-code"
)

# ============================================================
# NPM Current Version Detection (4-stage fallback)
# ============================================================

# npm_current_version(package_name)
# Gets the currently installed version of an NPM package
#
# Arguments:
#   $1 - Package name (e.g., "@anthropic-ai/claude-code")
# Returns: 0 if found, 1 if not found
# Outputs: Version string to stdout (e.g., "1.0.0")
#
# Detection Strategy (4-stage fallback):
#   1. npm ls -g with grep parsing
#   2. npm ls -g --json with jq parsing
#   3. Direct package.json read from node_modules
#   4. npm list --depth=0 alternative format
npm_current_version() {
  local pkg="$1"

  # Check if npm is available
  if ! have npm; then
    log_debug "npm not available"
    echo ""
    return 1
  fi

  local version=""

  # Stage 1: npm ls -g with grep (fastest, most reliable)
  log_debug "NPM Stage 1: npm ls -g for $pkg"
  version=$(timeout 5s npm ls -g "$pkg" --depth=0 2>/dev/null | grep "$pkg@" | head -1 | sed 's/.*@//' | sed 's/ .*//' || echo "")

  if [[ -n "$version" ]]; then
    log_debug "NPM Stage 1 success: $version"
    echo "$version"
    return 0
  fi

  # Stage 2: npm ls -g --json with jq (slower but handles complex cases)
  if have jq; then
    log_debug "NPM Stage 2: npm ls -g --json for $pkg"
    version=$(timeout 5s npm ls -g "$pkg" --json 2>/dev/null | jq -r ".dependencies[\"$pkg\"].version // empty" 2>/dev/null || echo "")

    if [[ -n "$version" ]]; then
      log_debug "NPM Stage 2 success: $version"
      echo "$version"
      return 0
    fi
  fi

  # Stage 3: Direct package.json read from node_modules
  log_debug "NPM Stage 3: Direct package.json read for $pkg"
  local npm_prefix
  npm_prefix=$(npm config get prefix 2>/dev/null || echo "/usr/local")
  local pkg_json="${npm_prefix}/lib/node_modules/${pkg}/package.json"

  if [[ -f "$pkg_json" ]]; then
    if have jq; then
      version=$(jq -r '.version // empty' "$pkg_json" 2>/dev/null || echo "")
    else
      # Fallback: grep for version without jq
      version=$(grep '"version"' "$pkg_json" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "")
    fi

    if [[ -n "$version" ]]; then
      log_debug "NPM Stage 3 success: $version"
      echo "$version"
      return 0
    fi
  fi

  # Stage 4: npm list --depth=0 (alternative format)
  log_debug "NPM Stage 4: npm list --depth=0 for $pkg"
  version=$(timeout 5s npm list -g --depth=0 2>/dev/null | grep "$pkg@" | sed 's/.*@//' | sed 's/ .*//' || echo "")

  if [[ -n "$version" ]]; then
    log_debug "NPM Stage 4 success: $version"
    echo "$version"
    return 0
  fi

  # All stages failed
  log_debug "NPM detection failed for $pkg (all 4 stages)"
  echo ""
  return 1
}

# ============================================================
# NPM Latest Version Detection (with cache)
# ============================================================

# npm_latest_version(package_name)
# Gets the latest available version from NPM registry
#
# Arguments:
#   $1 - Package name
# Returns: 0 if found, 1 if not found
# Outputs: Version string to stdout
#
# Features:
#   - Cache support (TTL-based)
#   - Timeout protection (5 seconds)
#   - Registry API fallback
npm_latest_version() {
  local pkg="$1"

  # Check if npm is available
  if ! have npm; then
    log_debug "npm not available"
    echo ""
    return 1
  fi

  # Generate cache key
  local cache_key
  cache_key=$(generate_cache_key "npm" "$pkg")

  # Try cache first
  local version
  if version=$(cache_get "$cache_key"); then
    echo "$version"
    return 0
  fi

  # Cache miss - fetch from registry
  log_debug "Fetching latest version from NPM registry: $pkg"
  version=$(timeout 5s npm view "$pkg" version 2>/dev/null || echo "")

  # Fallback: Direct registry API call
  if [[ -z "$version" ]] && have curl; then
    log_debug "Fallback: Direct NPM registry API"
    local safe_pkg
    safe_pkg=$(echo "$pkg" | sed 's/@/%40/g' | sed 's/\//%2F/g')
    version=$(timeout 5s curl -s "https://registry.npmjs.org/$pkg/latest" 2>/dev/null | grep '"version"' | cut -d'"' -f4 || echo "")
  fi

  # Cache the result
  if [[ -n "$version" ]]; then
    cache_set "$cache_key" "$version"
    log_debug "NPM latest version cached: $pkg = $version"
  else
    log_warn "Failed to fetch latest version for: $pkg"
  fi

  echo "$version"
  return 0
}

# ============================================================
# NPM Package Existence Check
# ============================================================

# npm_package_exists(package_name)
# Checks if an NPM package exists in the registry
#
# Arguments:
#   $1 - Package name
# Returns: 0 if exists, 1 if not found
npm_package_exists() {
  local pkg="$1"

  if ! have npm; then
    return 1
  fi

  # Try npm view
  if timeout 3s npm view "$pkg" name &>/dev/null; then
    return 0
  fi

  # Fallback: Registry API
  if have curl; then
    local safe_pkg
    safe_pkg=$(echo "$pkg" | sed 's/@/%40/g' | sed 's/\//%2F/g')
    if timeout 3s curl -sf "https://registry.npmjs.org/$pkg" &>/dev/null; then
      return 0
    fi
  fi

  return 1
}

# ============================================================
# NPM Tools Detection (Main Function)
# ============================================================

# detect_npm_tools()
# Detects all NPM-based AI tools and their versions
#
# Arguments: None
# Returns: 0 on success, 1 on failure
# Outputs: JSON array of tool information to stdout
# Format: [{"name":"Tool Name","package":"@org/pkg","current":"1.0.0","latest":"1.0.1","status":"UPDATE_AVAILABLE"}]
detect_npm_tools() {
  echo "[TRACE-FUNC] detect_npm_tools started" >&2
  echo "[TRACE-FUNC] NPM_TOOLS array size: ${#NPM_TOOLS[@]}" >&2

  if ! have npm; then
    log_warn "npm not available, skipping NPM tools detection"
    echo "[]"
    return 1
  fi

  log_info "Detecting NPM-based AI tools..."

  local results=()
  local tool_count=0
  local detected_count=0

  echo "[TRACE-FUNC] About to iterate NPM_TOOLS" >&2
  for name in "${!NPM_TOOLS[@]}"; do
    echo "[TRACE-FUNC] Processing: $name" >&2
    local pkg="${NPM_TOOLS[$name]}"
    tool_count=$((tool_count + 1))

    log_debug "Checking NPM tool: $name ($pkg)"

    # Get versions
    local current
    local latest
    current=$(npm_current_version "$pkg")
    latest=$(npm_latest_version "$pkg")

    # Determine status
    local status
    if [[ -z "$current" ]]; then
      status="NOT_INSTALLED"
    elif [[ -z "$latest" ]]; then
      status="UNKNOWN"
    else
      # Use version-checker module if available
      if declare -f determine_version_status &>/dev/null; then
        status=$(determine_version_status "$current" "$latest")
      else
        # Fallback: simple comparison
        if [[ "$current" == "$latest" ]]; then
          status="UP_TO_DATE"
        else
          status="UPDATE_AVAILABLE"
        fi
      fi
    fi

    # Count detected tools
    if [[ -n "$current" ]]; then
      detected_count=$((detected_count + 1))
    fi

    # Build JSON object
    local json_obj
    json_obj=$(cat <<EOF
{
  "name": "$name",
  "package": "$pkg",
  "current": "${current:-null}",
  "latest": "${latest:-null}",
  "status": "$status",
  "type": "npm"
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

  log_info "NPM tools detection complete: $detected_count/$tool_count detected"
  return 0
}

# ============================================================
# NPM Tools List Management
# ============================================================

# npm_add_tool(name, package)
# Adds a tool to the NPM tools registry
#
# Arguments:
#   $1 - Tool display name
#   $2 - NPM package name
# Returns: Always returns 0
npm_add_tool() {
  local name="$1"
  local package="$2"

  NPM_TOOLS["$name"]="$package"
  log_debug "Added NPM tool: $name ($package)"
  return 0
}

# npm_remove_tool(name)
# Removes a tool from the NPM tools registry
#
# Arguments:
#   $1 - Tool display name
# Returns: Always returns 0
npm_remove_tool() {
  local name="$1"

  unset 'NPM_TOOLS[$name]'
  log_debug "Removed NPM tool: $name"
  return 0
}

# npm_list_tools()
# Lists all registered NPM tools
#
# Returns: Always returns 0
# Outputs: Tool names and packages
npm_list_tools() {
  echo "Registered NPM Tools:"
  echo "===================="
  for name in "${!NPM_TOOLS[@]}"; do
    printf "  %-20s %s\n" "$name" "${NPM_TOOLS[$name]}"
  done
  return 0
}

# ============================================================
# Module Information
# ============================================================

# npm_tools_module_info()
# Displays module information
npm_tools_module_info() {
  cat <<EOF
AI Tools Checker - NPM Tools Detection Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  - npm_current_version()    Get installed version (4-stage fallback)
  - npm_latest_version()     Get latest version from registry (cached)
  - npm_package_exists()     Check if package exists
  - detect_npm_tools()       Detect all registered NPM tools
  - npm_add_tool()           Add tool to registry
  - npm_remove_tool()        Remove tool from registry
  - npm_list_tools()         List registered tools

Detection Strategy:
  1. npm ls -g (fastest)
  2. npm ls -g --json (complex cases)
  3. Direct package.json read (fallback)
  4. npm list --depth=0 (alternative)

Default Tools:
  - Claude Code (@anthropic-ai/claude-code)
  - Gemini CLI (@google/gemini-cli)
  - OpenAI Codex (@openai/codex)
  - Qwen Code (@qwen-code/qwen-code)

Dependencies: interfaces.sh (have, log_*), cache.sh (cache_*)
EOF
}

# Export functions
declare -fx npm_current_version 2>/dev/null || true
declare -fx npm_latest_version 2>/dev/null || true
declare -fx npm_package_exists 2>/dev/null || true
declare -fx detect_npm_tools 2>/dev/null || true
declare -fx npm_add_tool 2>/dev/null || true
declare -fx npm_remove_tool 2>/dev/null || true
declare -fx npm_list_tools 2>/dev/null || true
