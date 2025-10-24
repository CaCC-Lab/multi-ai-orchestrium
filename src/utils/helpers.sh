#!/usr/bin/env bash
# AI Tools Checker - Helper Functions Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides utility helper functions used throughout the application.
# It includes command checking, color output, progress display, and string/file operations.

# ============================================================
# Command Existence Check
# ============================================================

# have(command_name)
# Checks if a command is available in the system
#
# Arguments:
#   $1 - Command name to check
# Returns: 0 if command exists, 1 if not found
#
# Example:
#   if have jq; then
#     echo "jq is available"
#   fi
have() {
  command -v "$1" >/dev/null 2>&1
}

# ============================================================
# Color Output Functions
# ============================================================

# Color codes
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m'  # No Color

# Color output enabled/disabled (can be controlled by config)
COLOR_OUTPUT="${COLOR_OUTPUT:-auto}"

# should_use_color()
# Determines if color output should be used
#
# Returns: 0 if colors should be used, 1 if not
should_use_color() {
  case "$COLOR_OUTPUT" in
    always)
      return 0
      ;;
    never)
      return 1
      ;;
    auto|*)
      # Check if output is a terminal
      if [[ -t 1 ]]; then
        return 0
      else
        return 1
      fi
      ;;
  esac
}

# color_print(color_code, message)
# Prints a message in color if colors are enabled
#
# Arguments:
#   $1 - Color code (e.g., $COLOR_RED)
#   $2+ - Message to print
color_print() {
  local color="$1"
  shift
  local message="$*"

  if should_use_color; then
    echo -e "${color}${message}${COLOR_NC}"
  else
    echo "$message"
  fi
}

# Convenience color functions
print_red() { color_print "$COLOR_RED" "$@"; }
print_green() { color_print "$COLOR_GREEN" "$@"; }
print_yellow() { color_print "$COLOR_YELLOW" "$@"; }
print_blue() { color_print "$COLOR_BLUE" "$@"; }
print_magenta() { color_print "$COLOR_MAGENTA" "$@"; }
print_cyan() { color_print "$COLOR_CYAN" "$@"; }

# ============================================================
# Status Icon Functions
# ============================================================

# Icon definitions
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_UPDATE="🔄"
ICON_AHEAD="🚀"
ICON_UNKNOWN="❓"

# print_status_icon(status)
# Prints an appropriate icon for a given status
#
# Arguments:
#   $1 - Status string (UP_TO_DATE, UPDATE_AVAILABLE, etc.)
# Outputs: Status icon
print_status_icon() {
  local status="$1"

  case "$status" in
    UP_TO_DATE|INSTALLED|OK)
      echo "$ICON_SUCCESS"
      ;;
    UPDATE_AVAILABLE)
      echo "$ICON_UPDATE"
      ;;
    NEWER_THAN_LATEST|AHEAD)
      echo "$ICON_AHEAD"
      ;;
    NOT_INSTALLED|ERROR|FAILED)
      echo "$ICON_ERROR"
      ;;
    UNKNOWN)
      echo "$ICON_UNKNOWN"
      ;;
    WARNING)
      echo "$ICON_WARNING"
      ;;
    *)
      echo "$ICON_INFO"
      ;;
  esac
}

# ============================================================
# Progress Bar Display
# ============================================================

# show_progress(current, total, [prefix])
# Displays a progress bar
#
# Arguments:
#   $1 - Current progress (number)
#   $2 - Total items (number)
#   $3 - Optional prefix message
#
# Example:
#   show_progress 3 10 "Checking tools"
show_progress() {
  local current="$1"
  local total="$2"
  local prefix="${3:-Progress}"

  # Calculate percentage
  local percent=0
  if [[ "$total" -gt 0 ]]; then
    percent=$((current * 100 / total))
  fi

  # Progress bar length
  local bar_length=50
  local filled=$((percent * bar_length / 100))
  local empty=$((bar_length - filled))

  # Build progress bar
  local bar=""
  for ((i=0; i<filled; i++)); do
    bar="${bar}█"
  done
  for ((i=0; i<empty; i++)); do
    bar="${bar}░"
  done

  # Print progress (with carriage return to overwrite)
  printf "\r%s: [%s] %3d%% (%d/%d)" "$prefix" "$bar" "$percent" "$current" "$total"

  # Newline if complete
  if [[ "$current" -eq "$total" ]]; then
    echo ""
  fi
}

# show_spinner(pid, [message])
# Shows a spinner while a process is running
#
# Arguments:
#   $1 - Process ID to monitor
#   $2 - Optional message to display
#
# Example:
#   long_running_command &
#   show_spinner $! "Processing"
show_spinner() {
  local pid="$1"
  local message="${2:-Working}"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % ${#spin} ))
    printf "\r%s %s " "$message" "${spin:$i:1}"
    sleep 0.1
  done
  printf "\r%s... Done!   \n" "$message"
}

# ============================================================
# String Operations
# ============================================================

# trim(string)
# Removes leading and trailing whitespace
#
# Arguments:
#   $1 - String to trim
# Outputs: Trimmed string
trim() {
  local string="$1"
  # Remove leading whitespace
  string="${string#"${string%%[![:space:]]*}"}"
  # Remove trailing whitespace
  string="${string%"${string##*[![:space:]]}"}"
  echo "$string"
}

# to_lower(string)
# Converts string to lowercase
#
# Arguments:
#   $1 - String to convert
# Outputs: Lowercase string
to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# to_upper(string)
# Converts string to uppercase
#
# Arguments:
#   $1 - String to convert
# Outputs: Uppercase string
to_upper() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# string_contains(haystack, needle)
# Checks if string contains substring
#
# Arguments:
#   $1 - String to search in
#   $2 - Substring to find
# Returns: 0 if found, 1 if not found
string_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    return 1
  fi
}

# string_starts_with(string, prefix)
# Checks if string starts with prefix
#
# Arguments:
#   $1 - String to check
#   $2 - Prefix to match
# Returns: 0 if matches, 1 if not
string_starts_with() {
  local string="$1"
  local prefix="$2"

  if [[ "$string" == "$prefix"* ]]; then
    return 0
  else
    return 1
  fi
}

# string_ends_with(string, suffix)
# Checks if string ends with suffix
#
# Arguments:
#   $1 - String to check
#   $2 - Suffix to match
# Returns: 0 if matches, 1 if not
string_ends_with() {
  local string="$1"
  local suffix="$2"

  if [[ "$string" == *"$suffix" ]]; then
    return 0
  else
    return 1
  fi
}

# ============================================================
# File Operations
# ============================================================

# file_exists(file_path)
# Checks if file exists
#
# Arguments:
#   $1 - File path
# Returns: 0 if exists, 1 if not
file_exists() {
  [[ -f "$1" ]]
}

# dir_exists(directory_path)
# Checks if directory exists
#
# Arguments:
#   $1 - Directory path
# Returns: 0 if exists, 1 if not
dir_exists() {
  [[ -d "$1" ]]
}

# is_writable(path)
# Checks if path is writable
#
# Arguments:
#   $1 - File or directory path
# Returns: 0 if writable, 1 if not
is_writable() {
  [[ -w "$1" ]]
}

# ensure_directory(directory_path)
# Creates directory if it doesn't exist
#
# Arguments:
#   $1 - Directory path
# Returns: 0 on success, 1 on failure
ensure_directory() {
  local dir="$1"

  if [[ -d "$dir" ]]; then
    return 0
  fi

  if mkdir -p "$dir" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# file_size(file_path)
# Gets file size in bytes
#
# Arguments:
#   $1 - File path
# Returns: 0 if successful, 1 if not
# Outputs: File size in bytes
file_size() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Try Linux stat
  if stat -c %s "$file" 2>/dev/null; then
    return 0
  # Try macOS stat
  elif stat -f %z "$file" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# ============================================================
# Date/Time Helpers
# ============================================================

# timestamp()
# Returns current timestamp in YYYY-MM-DD_HH-MM-SS format
#
# Outputs: Timestamp string
timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

# unix_timestamp()
# Returns current Unix timestamp (seconds since epoch)
#
# Outputs: Unix timestamp
unix_timestamp() {
  date +%s
}

# format_duration(seconds)
# Formats duration in human-readable format
#
# Arguments:
#   $1 - Duration in seconds
# Outputs: Formatted duration (e.g., "2h 30m 15s")
format_duration() {
  local seconds="$1"
  local hours=$((seconds / 3600))
  local minutes=$(( (seconds % 3600) / 60 ))
  local secs=$((seconds % 60))

  if [[ "$hours" -gt 0 ]]; then
    echo "${hours}h ${minutes}m ${secs}s"
  elif [[ "$minutes" -gt 0 ]]; then
    echo "${minutes}m ${secs}s"
  else
    echo "${secs}s"
  fi
}

# ============================================================
# Terminal Helpers
# ============================================================

# get_terminal_width()
# Gets terminal width in columns
#
# Outputs: Terminal width (default: 80)
get_terminal_width() {
  if have tput; then
    tput cols 2>/dev/null || echo 80
  else
    echo 80
  fi
}

# clear_line()
# Clears current terminal line
clear_line() {
  printf "\r\033[K"
}

# move_cursor_up(lines)
# Moves cursor up N lines
#
# Arguments:
#   $1 - Number of lines to move up
move_cursor_up() {
  local lines="${1:-1}"
  printf "\033[%dA" "$lines"
}

# ============================================================
# Validation Helpers
# ============================================================

# is_number(value)
# Checks if value is a number
#
# Arguments:
#   $1 - Value to check
# Returns: 0 if number, 1 if not
is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

# is_positive_number(value)
# Checks if value is a positive number
#
# Arguments:
#   $1 - Value to check
# Returns: 0 if positive number, 1 if not
is_positive_number() {
  is_number "$1" && [[ "$1" -gt 0 ]]
}

# is_url(value)
# Checks if value is a valid URL
#
# Arguments:
#   $1 - Value to check
# Returns: 0 if URL, 1 if not
is_url() {
  [[ "$1" =~ ^https?:// ]]
}

# parse_yaml(file_path, section)
# Parses a simple YAML file and returns key-value pairs for a given section
#
# Arguments:
#   $1 - YAML file path
#   $2 - Section name (e.g., "npm_tools")
# Outputs: Key-value pairs, one per line (e.g., "key: value")
parse_yaml() {
  local file="$1"
  local section="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Extract section content, excluding both section headers and next section start
  sed -n "/^${section}:/,/^[a-zA-Z_][a-zA-Z0-9_]*:/{/^${section}:/d;/^[a-zA-Z_][a-zA-Z0-9_]*:/d;p}" "$file" | \
    grep -v "^$" | \
    sed 's/^[[:space:]]*//'
}

# ============================================================
# Module Information
# ============================================================

# helpers_module_info()
# Displays module information
helpers_module_info() {
  cat <<EOF
AI Tools Checker - Helper Functions Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Command Check:
    - have()                    Check command existence

  Color Output:
    - color_print()             Print in color
    - print_red/green/yellow/blue/magenta/cyan()
    - print_status_icon()       Print status icon

  Progress Display:
    - show_progress()           Progress bar
    - show_spinner()            Spinner animation

  String Operations:
    - trim()                    Remove whitespace
    - to_lower/upper()          Case conversion
    - string_contains()         Substring check
    - string_starts/ends_with() Prefix/suffix check

  File Operations:
    - file_exists/dir_exists()  Existence checks
    - is_writable()             Write permission check
    - ensure_directory()        Create directory
    - file_size()               Get file size

  Date/Time:
    - timestamp()               Current timestamp
    - unix_timestamp()          Unix timestamp
    - format_duration()         Human-readable duration

  Terminal:
    - get_terminal_width()      Terminal width
    - clear_line()              Clear line
    - move_cursor_up()          Move cursor

  Validation:
    - is_number()               Number check
    - is_positive_number()      Positive number check
    - is_url()                  URL check

Dependencies: None (pure utility functions)
EOF
}

# Export functions
declare -fx have 2>/dev/null || true
declare -fx color_print 2>/dev/null || true
declare -fx print_status_icon 2>/dev/null || true
declare -fx show_progress 2>/dev/null || true
declare -fx show_spinner 2>/dev/null || true
declare -fx trim 2>/dev/null || true
declare -fx to_lower 2>/dev/null || true
declare -fx to_upper 2>/dev/null || true
declare -fx string_contains 2>/dev/null || true
declare -fx file_exists 2>/dev/null || true
declare -fx dir_exists 2>/dev/null || true
declare -fx ensure_directory 2>/dev/null || true
declare -fx timestamp 2>/dev/null || true
declare -fx unix_timestamp 2>/dev/null || true
declare -fx format_duration 2>/dev/null || true
declare -fx get_terminal_width 2>/dev/null || true
declare -fx is_number 2>/dev/null || true
declare -fx is_url 2>/dev/null || true
