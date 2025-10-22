#!/usr/bin/env bash
# AI Tools Checker - Output Formatter Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides formatted output for displaying tool status,
# including headers, status lines, summaries, and tips.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/../core/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../core/version-checker.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true

# ============================================================
# Header Display
# ============================================================

# display_header([title])
# Displays a formatted header with box drawing characters
#
# Arguments:
#   $1 - Optional title (default: "AI Tools Status Checker")
display_header() {
  local title="${1:-AI Tools Status Checker}"
  local width=$(get_terminal_width)

  # Limit width to reasonable size
  if [[ "$width" -gt 80 ]]; then
    width=80
  fi

  # Calculate padding
  local title_length=${#title}
  local padding=$(( (width - title_length - 4) / 2 ))

  # Build padded title
  local padded_title=""
  for ((i=0; i<padding; i++)); do
    padded_title="${padded_title} "
  done
  padded_title="${padded_title}${title}"
  for ((i=0; i<padding; i++)); do
    padded_title="${padded_title} "
  done

  # Build border
  local border="╔"
  for ((i=2; i<width; i++)); do
    border="${border}═"
  done
  border="${border}╗"

  local bottom="╚"
  for ((i=2; i<width; i++)); do
    bottom="${bottom}═"
  done
  bottom="${bottom}╝"

  # Display
  print_cyan "$border"
  print_cyan "║${padded_title}║"
  print_cyan "$bottom"
  echo ""
}

# ============================================================
# Tool Status Line Display
# ============================================================

# format_status_line(name, current, latest, type)
# Formats and displays a single tool's status line
#
# Arguments:
#   $1 - Tool name
#   $2 - Current version
#   $3 - Latest version
#   $4 - Tool type ("npm" or "cli")
# Outputs: Formatted status line
format_status_line() {
  local name="$1"
  local cur="$2"
  local lat="$3"
  local type="$4"

  local status=""
  local status_icon=""
  local latest_display=""

  # Determine status
  if [[ -z "$cur" ]]; then
    status="NOT INSTALLED"
    status_icon="❌"
    latest_display="${lat:-N/A}"
  elif [[ -z "$lat" ]]; then
    if [[ "$type" == "cli" ]]; then
      status="INSTALLED"
      status_icon="✅"
      # Proprietary tools
      case "$name" in
        "Cursor"|"CodeRabbit"|"Amp"|"Droid")
          latest_display="(proprietary)"
          ;;
        *)
          latest_display="N/A"
          ;;
      esac
    else
      status="UNKNOWN"
      status_icon="❓"
      latest_display="N/A"
    fi
  else
    # Compare versions
    local cmp
    if declare -f vercmp &>/dev/null; then
      cmp=$(vercmp "$cur" "$lat")
    else
      # Fallback: string comparison
      if [[ "$cur" == "$lat" ]]; then
        cmp=0
      else
        cmp=-1
      fi
    fi

    case "$cmp" in
      0)
        status="UP TO DATE"
        status_icon="✅"
        ;;
      -1)
        status="UPDATE AVAILABLE"
        status_icon="🔄"
        ;;
      1)
        status="NEWER THAN LATEST"
        status_icon="🚀"
        ;;
    esac
    latest_display="$lat"
  fi

  # Format output
  printf "%s %-20s current: %-15s latest: %-15s %s\n" \
    "$status_icon" "$name" "${cur:-none}" "$latest_display" "$status"
}

# ============================================================
# Section Headers
# ============================================================

# display_section(title)
# Displays a section header
#
# Arguments:
#   $1 - Section title
display_section() {
  local title="$1"
  echo ""
  print_blue "▶ $title"
  echo "────────────────────"
}

# ============================================================
# Summary Display
# ============================================================

# display_summary(npm_detected, npm_total, cli_detected, cli_total)
# Displays a summary of detection results
#
# Arguments:
#   $1 - Number of NPM tools detected
#   $2 - Total NPM tools
#   $3 - Number of CLI tools detected
#   $4 - Total CLI tools
display_summary() {
  local npm_detected="${1:-0}"
  local npm_total="${2:-0}"
  local cli_detected="${3:-0}"
  local cli_total="${4:-0}"

  local total_detected=$((npm_detected + cli_detected))
  local total_tools=$((npm_total + cli_total))

  local width=$(get_terminal_width)
  if [[ "$width" -gt 80 ]]; then
    width=80
  fi

  # Build border
  local border="╔"
  for ((i=2; i<width; i++)); do
    border="${border}═"
  done
  border="${border}╗"

  local bottom="╚"
  for ((i=2; i<width; i++)); do
    bottom="${bottom}═"
  done
  bottom="${bottom}╝"

  echo ""
  print_cyan "$border"

  # Calculate padding for "Summary"
  local title="Summary"
  local title_length=${#title}
  local padding=$(( (width - title_length - 4) / 2 ))
  local padded_title=""
  for ((i=0; i<padding; i++)); do
    padded_title="${padded_title} "
  done
  padded_title="${padded_title}${title}"
  for ((i=0; i<padding; i++)); do
    padded_title="${padded_title} "
  done

  print_cyan "║${padded_title}║"
  print_cyan "$bottom"
  echo ""

  print_yellow "Detection Results:"
  echo "  NPM Tools: $npm_detected/$npm_total detected"
  echo "  CLI Tools: $cli_detected/$cli_total detected"
  echo "  Total:     $total_detected/$total_tools detected"
  echo ""
}

# ============================================================
# Tips Display
# ============================================================

# display_tips()
# Displays helpful tips for users
display_tips() {
  print_yellow "ℹ️  Tips:"
  echo "   • Use --install to install missing tools"
  echo "   • Use --update to update outdated tools"
  echo "   • Use --report html to generate a detailed report"
  echo "   • Use --interactive for guided tool management"
  echo "   • Use --help for full command reference"
  echo ""
}

# display_platform_specific_tips()
# Displays platform-specific tips
display_platform_specific_tips() {
  local platform="${1:-unknown}"

  print_blue "📝 Platform-Specific Tips:"

  case "$platform" in
    macos)
      echo "   • Use Homebrew for system packages: brew install <package>"
      echo "   • Check ~/.zshrc or ~/.bashrc for PATH configuration"
      echo "   • For Apple Silicon, some tools may need Rosetta 2"
      ;;
    wsl)
      echo "   • WSL version: $(cat /proc/version | grep -oP 'WSL\d')"
      echo "   • Use apt or your distro's package manager"
      echo "   • Windows tools may need to be installed separately"
      ;;
    linux)
      echo "   • Use apt, yum, or your distro's package manager"
      echo "   • Check ~/.bashrc for PATH configuration"
      ;;
    *)
      echo "   • Check your system's package manager documentation"
      ;;
  esac
  echo ""
}

# ============================================================
# 5AI Collaboration Status Display
# ============================================================

# display_5ai_status()
# Displays 5AI collaboration status
display_5ai_status() {
  display_section "5AI Collaboration Status"

  # Claude
  print_green "✅ Claude: Active (API/Web)"

  # Gemini
  if have gemini; then
    local gemini_ver=$(gemini --version 2>/dev/null | head -1 || echo "installed")
    print_green "✅ Gemini CLI: $gemini_ver"
  else
    print_yellow "⚠️  Gemini CLI: Not installed"
  fi

  # Qwen (via Ollama)
  if have ollama; then
    local qwen_models=$(ollama list 2>/dev/null | grep -i qwen || true)
    if [[ -n "$qwen_models" ]]; then
      print_green "✅ Qwen: $(echo "$qwen_models" | head -1 | awk '{print $1}')"
    else
      print_yellow "⚠️  Qwen: Ollama installed but Qwen model not available"
      echo "     Run: ollama pull qwen2.5-coder"
    fi
  else
    print_yellow "⚠️  Qwen: Requires Ollama"
  fi

  # OpenAI
  if have openai; then
    local openai_ver=$(openai --version 2>/dev/null || echo "installed")
    print_green "✅ OpenAI CLI: $openai_ver"
  else
    print_yellow "⚠️  OpenAI CLI: Not installed"
  fi

  # Cursor
  if have cursor; then
    print_green "✅ Cursor: Installed"
  else
    print_yellow "⚠️  Cursor: Not installed"
  fi

  echo ""
}

# ============================================================
# Error Display
# ============================================================

# display_error(message, [details])
# Displays an error message
#
# Arguments:
#   $1 - Error message
#   $2 - Optional details
display_error() {
  local message="$1"
  local details="${2:-}"

  print_red "❌ ERROR: $message"
  if [[ -n "$details" ]]; then
    echo "   Details: $details"
  fi
  echo ""
}

# display_warning(message)
# Displays a warning message
#
# Arguments:
#   $1 - Warning message
display_warning() {
  local message="$1"
  print_yellow "⚠️  WARNING: $message"
  echo ""
}

# display_success(message)
# Displays a success message
#
# Arguments:
#   $1 - Success message
display_success() {
  local message="$1"
  print_green "✅ $message"
  echo ""
}

# ============================================================
# Table Display
# ============================================================

# display_table_header(col1, col2, col3, col4)
# Displays a table header
#
# Arguments:
#   $1-$4 - Column headers
display_table_header() {
  local col1="${1:-Name}"
  local col2="${2:-Current}"
  local col3="${3:-Latest}"
  local col4="${4:-Status}"

  printf "%-20s %-15s %-15s %s\n" "$col1" "$col2" "$col3" "$col4"
  printf "%s\n" "────────────────────────────────────────────────────────────────────"
}

# ============================================================
# Module Information
# ============================================================

# output_module_info()
# Displays module information
output_module_info() {
  cat <<EOF
AI Tools Checker - Output Formatter Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Header Display:
    - display_header()              Formatted header with box drawing
    - display_section()             Section headers

  Status Display:
    - format_status_line()          Tool status line
    - display_table_header()        Table headers

  Summary:
    - display_summary()             Detection summary
    - display_5ai_status()          5AI collaboration status
    - display_tips()                Helpful tips
    - display_platform_specific_tips()

  Messages:
    - display_error()               Error messages
    - display_warning()             Warning messages
    - display_success()             Success messages

Dependencies:
  - interfaces.sh (log_*)
  - version-checker.sh (vercmp)
  - helpers.sh (color output, terminal width)
EOF
}

# Export functions
declare -fx display_header 2>/dev/null || true
declare -fx format_status_line 2>/dev/null || true
declare -fx display_section 2>/dev/null || true
declare -fx display_summary 2>/dev/null || true
declare -fx display_tips 2>/dev/null || true
declare -fx display_5ai_status 2>/dev/null || true
declare -fx display_error 2>/dev/null || true
declare -fx display_warning 2>/dev/null || true
declare -fx display_success 2>/dev/null || true
