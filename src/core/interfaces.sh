#!/usr/bin/env bash
# AI Tools Checker - Core Interfaces
# Version: 2.1.0
# Date: 2025-01-12

# This file defines the public interfaces for all core modules.
# All modules must implement these interfaces consistently.

# ============================================================
# NPM Tools Detection Interface
# ============================================================

# detect_npm_tools()
# Detects all NPM-based AI tools and their versions
#
# Arguments: None
# Returns: 0 on success, 1 on failure
# Outputs: JSON array of tool information to stdout
# Format: [{"name":"Tool Name","package":"@org/pkg","current":"1.0.0","latest":"1.0.1","status":"UPDATE_AVAILABLE"}]
# Implementation: npm-tools.sh

# npm_current_version(package_name)
# Gets the currently installed version of an NPM package
#
# Arguments:
#   $1 - Package name (e.g., "@anthropic-ai/claude-code")
# Returns: 0 if found, 1 if not found
# Outputs: Version string to stdout (e.g., "1.0.0")
# Implementation: npm-tools.sh

# npm_latest_version(package_name)
# Gets the latest available version from NPM registry
#
# Arguments:
#   $1 - Package name
# Returns: 0 if found, 1 if not found
# Outputs: Version string to stdout
# Implementation: npm-tools.sh

# ============================================================
# CLI Tools Detection Interface
# ============================================================

# detect_cli_tools()
# Detects all CLI-based AI tools and their versions
#
# Arguments: None
# Returns: 0 on success, 1 on failure
# Outputs: JSON array of tool information to stdout
# Implementation: cli-tools.sh

# cli_tool_exists(command_name)
# Checks if a CLI tool is installed
#
# Arguments:
#   $1 - Command name (e.g., "cursor", "amp")
# Returns: 0 if exists, 1 if not found
# Implementation: cli-tools.sh

# cli_tool_version(command_name)
# Gets the version of a CLI tool
#
# Arguments:
#   $1 - Command name
# Returns: 0 if successful, 1 if failed
# Outputs: Version string to stdout
# Implementation: cli-tools.sh

# ============================================================
# Version Checking Interface
# ============================================================

# vercmp(version1, version2)
# Compares two semantic versions
#
# Arguments:
#   $1 - First version (e.g., "1.0.0")
#   $2 - Second version (e.g., "2.0.0")
# Returns: Always returns 0
# Outputs: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
# Implementation: version-checker.sh

# semver(version_string)
# Extracts semantic version from a version string
#
# Arguments:
#   $1 - Version string (may include 'v' prefix, metadata, etc.)
# Returns: Always returns 0
# Outputs: Clean semantic version (e.g., "1.0.0")
# Implementation: version-checker.sh

# check_breaking_changes(current_version, latest_version)
# Detects if update contains breaking changes (major version bump)
#
# Arguments:
#   $1 - Current version
#   $2 - Latest version
# Returns: 0 if breaking changes, 1 if not
# Implementation: version-checker.sh

# ============================================================
# Cache Management Interface
# ============================================================

# cache_get(key)
# Retrieves a value from cache if not expired
#
# Arguments:
#   $1 - Cache key
# Returns: 0 if cache hit, 1 if cache miss or expired
# Outputs: Cached value to stdout
# Implementation: cache.sh

# cache_set(key, value, [ttl])
# Stores a value in cache
#
# Arguments:
#   $1 - Cache key
#   $2 - Value to cache
#   $3 - TTL in seconds (optional, default from config)
# Returns: 0 on success, 1 on failure
# Implementation: cache.sh

# cache_clear([pattern])
# Clears cache entries
#
# Arguments:
#   $1 - Optional pattern to match keys (default: all)
# Returns: 0 on success
# Implementation: cache.sh

# ============================================================
# Configuration Interface
# ============================================================

# config_load()
# Loads configuration from file and environment
#
# Arguments: None
# Returns: 0 on success, 1 on failure
# Side effects: Sets global configuration variables
# Implementation: config.sh

# config_get(key, [default])
# Gets a configuration value
#
# Arguments:
#   $1 - Configuration key
#   $2 - Default value (optional)
# Returns: Always returns 0
# Outputs: Configuration value to stdout
# Implementation: config.sh

# ============================================================
# Logging Interface
# ============================================================

# log_debug(message)
# Logs a debug message (only in verbose mode)
log_debug() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[DEBUG] $*" >&2
  fi
  return 0
}

# log_info(message)
# Logs an informational message
log_info() {
  echo "[INFO] $*" >&2
}

# log_warn(message)
# Logs a warning message
log_warn() {
  echo "[WARN] $*" >&2
}

# log_error(message)
# Logs an error message
log_error() {
  echo "[ERROR] $*" >&2
}
