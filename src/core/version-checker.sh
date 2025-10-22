#!/usr/bin/env bash
# AI Tools Checker - Version Checker Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides semantic versioning utilities for comparing tool versions.
# It has no external dependencies and consists of pure functions.

# ============================================================
# Semantic Version Extraction
# ============================================================

# semver(version_string)
# Extracts semantic version from a version string
#
# Arguments:
#   $1 - Version string (may include 'v' prefix, metadata, etc.)
# Returns: Always returns 0
# Outputs: Clean semantic version (e.g., "1.0.0")
#
# Examples:
#   semver "v1.2.3"           -> "1.2.3"
#   semver "2.0.0-alpha.1"    -> "2.0.0-alpha.1"
#   semver "version 1.0"      -> "1.0"
#   semver "3.4.5+build.123"  -> "3.4.5"
semver() {
  local input="$1"

  # Extract version pattern: major.minor.patch[-prerelease][+build]
  # Supports:
  # - Simple: 1.0, 1.0.0
  # - Full semver: 1.0.0-alpha.1+build.123
  # - With prefix: v1.0.0, version 1.0.0
  echo "$input" | grep -Eo '[0-9]+(\.[0-9]+)*([-.][0-9A-Za-z.]+)?' | head -n1
}

# ============================================================
# Version Comparison
# ============================================================

# vercmp(version1, version2)
# Compares two semantic versions
#
# Arguments:
#   $1 - First version (e.g., "1.0.0")
#   $2 - Second version (e.g., "2.0.0")
# Returns: Always returns 0
# Outputs: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
#
# Examples:
#   vercmp "1.0.0" "2.0.0"    -> -1
#   vercmp "2.0.0" "1.0.0"    -> 1
#   vercmp "1.0.0" "1.0.0"    -> 0
#   vercmp "1.0.0-alpha" "1.0.0"  -> -1
#
# Notes:
#   - Uses `sort -V` if available (GNU coreutils 7.0+)
#   - Falls back to simple numeric sort for basic versions
#   - Empty versions are considered less than any version
vercmp() {
  local v1="$1"
  local v2="$2"

  # Equal check (fast path)
  if [[ "$v1" == "$v2" ]]; then
    echo 0
    return 0
  fi

  # Handle empty versions
  if [[ -z "$v1" ]]; then
    echo -1
    return 0
  fi
  if [[ -z "$v2" ]]; then
    echo 1
    return 0
  fi

  local sorted

  # Try version-aware sort (available in GNU coreutils 7.0+)
  # This properly handles semver including pre-release versions
  if sort -V </dev/null >/dev/null 2>&1; then
    sorted=$(printf "%s\n%s\n" "$v1" "$v2" | sort -V | head -n1)
  else
    # Fallback: numeric sort on version components
    # This works for simple X.Y.Z versions but not pre-releases
    sorted=$(printf "%s\n%s\n" "$v1" "$v2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)
  fi

  # If the first element after sorting is v1, then v1 < v2
  if [[ "$sorted" == "$v1" ]]; then
    echo -1
  else
    echo 1
  fi

  return 0
}

# ============================================================
# Breaking Changes Detection
# ============================================================

# check_breaking_changes(current_version, latest_version)
# Detects if update contains breaking changes (major version bump)
#
# Arguments:
#   $1 - Current version (e.g., "1.5.3")
#   $2 - Latest version (e.g., "2.0.0")
# Returns: 0 if breaking changes, 1 if not
# Outputs: Nothing
#
# Examples:
#   check_breaking_changes "1.5.3" "2.0.0"  -> 0 (breaking)
#   check_breaking_changes "1.5.3" "1.6.0"  -> 1 (not breaking)
#   check_breaking_changes "2.0.0" "2.0.1"  -> 1 (not breaking)
#
# Notes:
#   - Based on Semantic Versioning 2.0.0 specification
#   - Major version 0 (0.x.y) is for initial development (all changes may break)
#   - First stable release is 1.0.0
check_breaking_changes() {
  local current="$1"
  local latest="$2"

  # Extract major version numbers
  local current_major
  local latest_major

  current_major=$(echo "$current" | cut -d. -f1)
  latest_major=$(echo "$latest" | cut -d. -f1)

  # Remove any non-numeric prefix (like 'v')
  current_major=${current_major#v}
  latest_major=${latest_major#v}

  # If major version increased, breaking changes are present
  if [[ "$latest_major" -gt "$current_major" ]]; then
    return 0  # Breaking changes detected
  else
    return 1  # No breaking changes
  fi
}

# ============================================================
# Version Status Determination
# ============================================================

# determine_version_status(current_version, latest_version)
# Determines the status of a tool based on version comparison
#
# Arguments:
#   $1 - Current version
#   $2 - Latest version
# Returns: Always returns 0
# Outputs: Status string (UP_TO_DATE, UPDATE_AVAILABLE, NEWER_THAN_LATEST, UNKNOWN)
#
# Examples:
#   determine_version_status "1.0.0" "1.0.0"  -> UP_TO_DATE
#   determine_version_status "1.0.0" "2.0.0"  -> UPDATE_AVAILABLE
#   determine_version_status "2.0.0" "1.0.0"  -> NEWER_THAN_LATEST
#   determine_version_status "" "1.0.0"       -> NOT_INSTALLED
#   determine_version_status "1.0.0" ""       -> UNKNOWN
determine_version_status() {
  local current="$1"
  local latest="$2"

  # Not installed
  if [[ -z "$current" ]]; then
    echo "NOT_INSTALLED"
    return 0
  fi

  # Latest version unknown
  if [[ -z "$latest" ]]; then
    echo "UNKNOWN"
    return 0
  fi

  # Compare versions
  local cmp
  cmp=$(vercmp "$current" "$latest")

  case "$cmp" in
    0)
      echo "UP_TO_DATE"
      ;;
    -1)
      echo "UPDATE_AVAILABLE"
      ;;
    1)
      echo "NEWER_THAN_LATEST"
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac

  return 0
}

# ============================================================
# Version Formatting Utilities
# ============================================================

# format_version_with_prefix(version)
# Adds 'v' prefix to version if not present
#
# Arguments:
#   $1 - Version string
# Returns: Always returns 0
# Outputs: Version with 'v' prefix
#
# Example:
#   format_version_with_prefix "1.0.0"  -> "v1.0.0"
#   format_version_with_prefix "v1.0.0" -> "v1.0.0"
format_version_with_prefix() {
  local version="$1"

  if [[ "$version" =~ ^v ]]; then
    echo "$version"
  else
    echo "v$version"
  fi
}

# strip_version_prefix(version)
# Removes 'v' prefix from version if present
#
# Arguments:
#   $1 - Version string
# Returns: Always returns 0
# Outputs: Version without 'v' prefix
#
# Example:
#   strip_version_prefix "v1.0.0" -> "1.0.0"
#   strip_version_prefix "1.0.0"  -> "1.0.0"
strip_version_prefix() {
  local version="$1"
  echo "${version#v}"
}

# ============================================================
# Module Information
# ============================================================

# version_checker_info()
# Displays module information
version_checker_info() {
  cat <<EOF
AI Tools Checker - Version Checker Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  - semver()                      Extract semantic version
  - vercmp()                      Compare two versions
  - check_breaking_changes()      Detect breaking changes
  - determine_version_status()    Determine update status
  - format_version_with_prefix()  Add 'v' prefix
  - strip_version_prefix()        Remove 'v' prefix

Dependencies: None (pure functions)
EOF
}

# Export functions (optional, for explicit sourcing)
# Note: Bash doesn't require exports for sourced functions,
# but this documents the public API
declare -fx semver 2>/dev/null || true
declare -fx vercmp 2>/dev/null || true
declare -fx check_breaking_changes 2>/dev/null || true
declare -fx determine_version_status 2>/dev/null || true
declare -fx format_version_with_prefix 2>/dev/null || true
declare -fx strip_version_prefix 2>/dev/null || true
