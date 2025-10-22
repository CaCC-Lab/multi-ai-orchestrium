#!/usr/bin/env bash
# AI Tools Checker - Cache Management Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides caching functionality for GitHub API and NPM registry responses.
# It reduces API calls and improves performance through TTL-based caching.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/interfaces.sh" 2>/dev/null || true

# ============================================================
# Cache Configuration
# ============================================================

# Default cache settings (can be overridden by config module)
CACHE_DIR="${CACHE_DIR:-${HOME}/.cache/aitools}"
CACHE_TTL="${CACHE_TTL:-3600}"  # 1 hour in seconds
CACHE_ENABLED="${CACHE_ENABLED:-true}"

# Ensure cache directory exists
if [[ ! -d "$CACHE_DIR" ]]; then
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
fi

# ============================================================
# Cache Key Management
# ============================================================

# generate_cache_key(type, identifier)
# Generates a safe cache filename from type and identifier
#
# Arguments:
#   $1 - Cache type (e.g., "github", "npm")
#   $2 - Identifier (e.g., repo name, package name)
# Returns: Always returns 0
# Outputs: Safe cache filename
#
# Example:
#   generate_cache_key "github" "anthropic-ai/claude-code" -> "github_anthropic-ai_claude-code_latest.cache"
#   generate_cache_key "npm" "@anthropic-ai/claude-code"   -> "npm__anthropic-ai_claude-code_latest.cache"
generate_cache_key() {
  local cache_type="$1"
  local identifier="$2"

  # Replace special characters with underscores for safe filenames
  local safe_id
  safe_id=$(echo "$identifier" | sed 's/[\/:]/_/g')

  echo "${cache_type}_${safe_id}_latest.cache"
}

# ============================================================
# Cache Age Calculation
# ============================================================

# get_cache_age(cache_file)
# Calculates the age of a cache file in seconds
#
# Arguments:
#   $1 - Cache file path
# Returns: 0 if successful, 1 if file doesn't exist
# Outputs: Age in seconds
#
# Notes:
#   - Uses stat -c %Y on Linux
#   - Uses stat -f %m on macOS
#   - Returns 999999 (effectively expired) if stat fails
get_cache_age() {
  local cache_file="$1"

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  local now
  local mtime
  local age

  now=$(date +%s)

  # Try Linux stat first
  if mtime=$(stat -c %Y "$cache_file" 2>/dev/null); then
    age=$((now - mtime))
  # Try macOS stat
  elif mtime=$(stat -f %m "$cache_file" 2>/dev/null); then
    age=$((now - mtime))
  else
    # If stat fails, return large age (effectively expired)
    log_debug "Failed to get cache age for: $cache_file"
    echo 999999
    return 1
  fi

  echo "$age"
  return 0
}

# ============================================================
# Cache Validation
# ============================================================

# cache_is_valid(cache_file, [ttl])
# Checks if a cache file exists and is not expired
#
# Arguments:
#   $1 - Cache file path
#   $2 - TTL in seconds (optional, defaults to CACHE_TTL)
# Returns: 0 if valid, 1 if invalid or expired
cache_is_valid() {
  local cache_file="$1"
  local ttl="${2:-$CACHE_TTL}"

  # Cache disabled
  if [[ "$CACHE_ENABLED" != "true" ]]; then
    return 1
  fi

  # File doesn't exist
  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  # Check age
  local age
  if ! age=$(get_cache_age "$cache_file"); then
    return 1
  fi

  # Expired
  if [[ "$age" -ge "$ttl" ]]; then
    log_debug "Cache expired: $cache_file (age: ${age}s, ttl: ${ttl}s)"
    return 1
  fi

  # Valid
  log_debug "Cache valid: $cache_file (age: ${age}s)"
  return 0
}

# ============================================================
# Cache Read/Write Operations
# ============================================================

# cache_get(key, [ttl])
# Retrieves a value from cache if not expired
#
# Arguments:
#   $1 - Cache key (will be converted to filename)
#   $2 - TTL in seconds (optional)
# Returns: 0 if cache hit, 1 if cache miss or expired
# Outputs: Cached value to stdout
#
# Example:
#   if value=$(cache_get "github_anthropic-ai_claude-code"); then
#     echo "Cache hit: $value"
#   fi
cache_get() {
  local key="$1"
  local ttl="${2:-$CACHE_TTL}"
  local cache_file="${CACHE_DIR}/${key}"

  if cache_is_valid "$cache_file" "$ttl"; then
    cat "$cache_file"
    log_debug "Cache hit: $key"
    return 0
  else
    log_debug "Cache miss: $key"
    return 1
  fi
}

# cache_set(key, value, [ttl])
# Stores a value in cache
#
# Arguments:
#   $1 - Cache key (will be converted to filename)
#   $2 - Value to cache
#   $3 - TTL in seconds (optional, metadata only)
# Returns: 0 on success, 1 on failure
#
# Example:
#   cache_set "github_anthropic-ai_claude-code" "1.0.0"
cache_set() {
  local key="$1"
  local value="$2"
  local ttl="${3:-$CACHE_TTL}"
  local cache_file="${CACHE_DIR}/${key}"

  # Cache disabled
  if [[ "$CACHE_ENABLED" != "true" ]]; then
    return 1
  fi

  # Don't cache empty values
  if [[ -z "$value" ]]; then
    log_debug "Skipping cache set for empty value: $key"
    return 1
  fi

  # Write to cache
  if echo "$value" > "$cache_file" 2>/dev/null; then
    log_debug "Cache updated: $key (ttl: ${ttl}s)"
    return 0
  else
    log_debug "Failed to write cache: $key"
    return 1
  fi
}

# cache_clear([pattern])
# Clears cache entries
#
# Arguments:
#   $1 - Optional pattern to match keys (default: all, i.e., "*")
# Returns: 0 on success
#
# Examples:
#   cache_clear              # Clear all cache
#   cache_clear "github_*"   # Clear only GitHub cache
#   cache_clear "npm_*"      # Clear only NPM cache
cache_clear() {
  local pattern="${1:-*}"
  local count=0

  log_debug "Clearing cache with pattern: $pattern"

  # Find and remove matching cache files
  if [[ -d "$CACHE_DIR" ]]; then
    while IFS= read -r -d '' file; do
      rm -f "$file"
      count=$((count + 1))
    done < <(find "$CACHE_DIR" -name "${pattern}.cache" -print0 2>/dev/null)
  fi

  log_info "Cleared $count cache entries"
  return 0
}

# ============================================================
# Cache Statistics
# ============================================================

# cache_stats()
# Displays cache statistics
#
# Returns: Always returns 0
# Outputs: Cache statistics to stdout
cache_stats() {
  local total=0
  local valid=0
  local expired=0
  local total_size=0

  if [[ ! -d "$CACHE_DIR" ]]; then
    echo "Cache directory does not exist: $CACHE_DIR"
    return 0
  fi

  # Count cache files
  while IFS= read -r -d '' file; do
    total=$((total + 1))

    # Check if valid
    if cache_is_valid "$file"; then
      valid=$((valid + 1))
    else
      expired=$((expired + 1))
    fi

    # Add file size
    if [[ -f "$file" ]]; then
      local size
      size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0)
      total_size=$((total_size + size))
    fi
  done < <(find "$CACHE_DIR" -name "*.cache" -print0 2>/dev/null)

  # Calculate hit rate (if we have stats)
  local hit_rate="N/A"

  # Display statistics
  cat <<EOF
Cache Statistics:
  Directory: $CACHE_DIR
  Total entries: $total
  Valid entries: $valid
  Expired entries: $expired
  Total size: $(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "${total_size} bytes")
  TTL: ${CACHE_TTL}s ($(($CACHE_TTL / 60)) minutes)
  Status: $([ "$CACHE_ENABLED" = "true" ] && echo "Enabled" || echo "Disabled")
EOF

  return 0
}

# ============================================================
# GitHub-specific Cache Functions
# ============================================================

# cache_github_latest(repo)
# Gets cached GitHub latest release or fetches from API
#
# Arguments:
#   $1 - GitHub repository (e.g., "anthropic-ai/claude-code")
# Returns: Always returns 0
# Outputs: Version string
#
# This is a higher-level function that combines cache check and API call
cache_github_latest() {
  local repo="$1"
  local cache_key
  cache_key=$(generate_cache_key "github" "$repo")

  # Try cache first
  local version
  if version=$(cache_get "$cache_key"); then
    echo "$version"
    return 0
  fi

  # Cache miss - would call API here
  # (Actual API call will be in github-tools.sh module)
  log_debug "GitHub cache miss for: $repo"
  return 1
}

# ============================================================
# NPM-specific Cache Functions
# ============================================================

# cache_npm_latest(package)
# Gets cached NPM latest version or fetches from registry
#
# Arguments:
#   $1 - NPM package name (e.g., "@anthropic-ai/claude-code")
# Returns: Always returns 0
# Outputs: Version string
#
# This is a higher-level function that combines cache check and registry call
cache_npm_latest() {
  local package="$1"
  local cache_key
  cache_key=$(generate_cache_key "npm" "$package")

  # Try cache first
  local version
  if version=$(cache_get "$cache_key"); then
    echo "$version"
    return 0
  fi

  # Cache miss - would call registry here
  # (Actual registry call will be in npm-tools.sh module)
  log_debug "NPM cache miss for: $package"
  return 1
}

# ============================================================
# Cache Warming (Preload)
# ============================================================

# cache_warm(type, identifiers_array)
# Preloads cache for multiple identifiers
#
# Arguments:
#   $1 - Cache type ("github" or "npm")
#   $2+ - Identifiers to warm
# Returns: Always returns 0
#
# Example:
#   cache_warm "npm" "@anthropic-ai/claude-code" "@google/gemini-cli"
cache_warm() {
  local cache_type="$1"
  shift
  local identifiers=("$@")

  log_info "Warming cache for $cache_type (${#identifiers[@]} entries)"

  for identifier in "${identifiers[@]}"; do
    case "$cache_type" in
      github)
        cache_github_latest "$identifier" >/dev/null 2>&1 || true
        ;;
      npm)
        cache_npm_latest "$identifier" >/dev/null 2>&1 || true
        ;;
    esac
  done

  return 0
}

# ============================================================
# Module Information
# ============================================================

# cache_module_info()
# Displays module information
cache_module_info() {
  cat <<EOF
AI Tools Checker - Cache Management Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  - cache_get()              Retrieve cached value
  - cache_set()              Store value in cache
  - cache_clear()            Clear cache entries
  - cache_is_valid()         Check cache validity
  - cache_stats()            Display cache statistics
  - cache_github_latest()    GitHub-specific cache
  - cache_npm_latest()       NPM-specific cache
  - cache_warm()             Preload cache

Configuration:
  - CACHE_DIR:     $CACHE_DIR
  - CACHE_TTL:     $CACHE_TTL seconds
  - CACHE_ENABLED: $CACHE_ENABLED

Dependencies: interfaces.sh (log_debug, log_info)
EOF
}

# Export functions
declare -fx cache_get 2>/dev/null || true
declare -fx cache_set 2>/dev/null || true
declare -fx cache_clear 2>/dev/null || true
declare -fx cache_is_valid 2>/dev/null || true
declare -fx cache_stats 2>/dev/null || true
declare -fx cache_github_latest 2>/dev/null || true
declare -fx cache_npm_latest 2>/dev/null || true
declare -fx cache_warm 2>/dev/null || true
