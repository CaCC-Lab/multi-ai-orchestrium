#!/usr/bin/env bash
# setup-wizard.sh - Lite Mode インタラクティブセットアップウィザード
#
# Purpose: ユーザーフレンドリーなセットアップUI
# Version: 1.0.0
# Date: 2025-11-27
#
# Usage:
#   ./scripts/lite-mode/setup-wizard.sh

set -euo pipefail

# ============================================================================
# Constants & Configuration
# ============================================================================

WIZARD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZARD_ROOT_DIR="$(cd "$WIZARD_SCRIPT_DIR/../.." && pwd)"

# Colors (disable if NO_COLOR is set)
if [[ -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[1;37m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' BOLD='' DIM='' RESET=''
fi

# Load checker
source "$WIZARD_SCRIPT_DIR/lite-mode-checker.sh"

# ============================================================================
# UI Helper Functions
# ============================================================================

clear_screen() {
  printf '\033[2J\033[H'
}

print_header() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${RESET}  ${BOLD}🚀 Multi-AI Orchestrium - Setup Wizard${RESET}                      ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  ${DIM}Version 1.0.0${RESET}                                               ${CYAN}║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

print_step() {
  local step="$1"
  local total="$2"
  local title="$3"
  
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${BOLD}Step $step/$total:${RESET} $title"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

print_success() {
  echo -e "  ${GREEN}✓${RESET} $1"
}

print_warning() {
  echo -e "  ${YELLOW}⚠${RESET} $1"
}

print_error() {
  echo -e "  ${RED}✗${RESET} $1"
}

print_info() {
  echo -e "  ${CYAN}ℹ${RESET} $1"
}

prompt_continue() {
  echo ""
  echo -e -n "  ${DIM}Press Enter to continue...${RESET}"
  read -r
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  
  local yn_hint
  if [[ "$default" == "y" ]]; then
    yn_hint="[Y/n]"
  else
    yn_hint="[y/N]"
  fi
  
  echo -e -n "  $prompt $yn_hint: "
  read -r response
  
  response="${response:-$default}"
  [[ "$response" =~ ^[Yy] ]]
}

prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  
  echo "  $prompt"
  echo ""
  
  local i=1
  for opt in "${options[@]}"; do
    echo -e "    ${CYAN}$i)${RESET} $opt"
    ((i++))
  done
  
  echo ""
  echo -e -n "  Enter choice [1-${#options[@]}]: "
  read -r choice
  
  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
    echo "$choice"
  else
    echo "1"
  fi
}

# ============================================================================
# Wizard Steps
# ============================================================================

# Step 1: Welcome & Overview
step_welcome() {
  clear_screen
  print_header
  
  echo -e "  ${BOLD}Welcome to Multi-AI Orchestrium!${RESET}"
  echo ""
  echo "  This wizard will help you set up your AI development environment."
  echo "  Multi-AI Orchestrium can work with different numbers of AI tools:"
  echo ""
  echo -e "    ${DIM}┌─────────────┬────────────────────────────────────────┐${RESET}"
  echo -e "    ${DIM}│${RESET} ${CYAN}Single (1)${RESET}  ${DIM}│${RESET} Basic operations                       ${DIM}│${RESET}"
  echo -e "    ${DIM}│${RESET} ${YELLOW}Basic (2-3)${RESET} ${DIM}│${RESET} Core workflows + fallback              ${DIM}│${RESET}"
  echo -e "    ${DIM}│${RESET} ${MAGENTA}Std (4-5)${RESET}   ${DIM}│${RESET} Parallel execution + TDD               ${DIM}│${RESET}"
  echo -e "    ${DIM}│${RESET} ${GREEN}Full (6-7)${RESET}  ${DIM}│${RESET} Maximum AI collaboration               ${DIM}│${RESET}"
  echo -e "    ${DIM}└─────────────┴────────────────────────────────────────┘${RESET}"
  echo ""
  echo "  Let's check what you have installed..."
  
  prompt_continue
}

# Step 2: Check Current Status
step_check_status() {
  clear_screen
  print_header
  print_step 1 4 "Checking AI Tools"
  
  # Run the checker
  lite_check_all_ais
  
  echo ""
  
  local mode=$(lite_get_available_mode)
  local count=$(lite_get_ai_count)
  
  case "$mode" in
    full)
      echo -e "  ${GREEN}🎉 Excellent! You have $count AIs installed.${RESET}"
      echo "  You can use all features of Multi-AI Orchestrium!"
      ;;
    standard)
      echo -e "  ${MAGENTA}👍 Good! You have $count AIs installed.${RESET}"
      echo "  Most features are available. Consider adding more AIs for full experience."
      ;;
    basic)
      echo -e "  ${YELLOW}📦 You have $count AIs installed.${RESET}"
      echo "  Basic workflows are available. Adding more AIs will unlock more features."
      ;;
    single)
      echo -e "  ${CYAN}🔹 You have 1 AI installed.${RESET}"
      echo "  Basic operations are available. Adding more AIs is highly recommended."
      ;;
    none)
      echo -e "  ${RED}❌ No AI tools detected.${RESET}"
      echo "  Please install at least one AI tool to use Multi-AI Orchestrium."
      ;;
  esac
  
  prompt_continue
}

# Step 3: Recommendations
step_recommendations() {
  clear_screen
  print_header
  print_step 2 4 "Installation Recommendations"
  
  local mode=$(lite_get_available_mode)
  
  if [[ "$mode" == "full" ]]; then
    echo "  You already have all AI tools installed! 🎉"
    echo ""
    echo "  No additional installations needed."
    prompt_continue
    return
  fi
  
  echo "  Here are the recommended AI tools to install:"
  echo ""
  
  # Core AIs
  echo -e "  ${RED}🔴 Core AIs (highly recommended):${RESET}"
  echo ""
  
  if ! lite_is_ai_available "claude"; then
    echo -e "    ${BOLD}Claude${RESET} - Strategy & Architecture"
    echo -e "    ${DIM}npm install -g @anthropic-ai/claude-code${RESET}"
    echo ""
  fi
  
  if ! lite_is_ai_available "gemini"; then
    echo -e "    ${BOLD}Gemini${RESET} - Research & Security"
    echo -e "    ${DIM}npm install -g @google/gemini-cli${RESET}"
    echo ""
  fi
  
  # Important AIs
  local has_important_missing=false
  if ! lite_is_ai_available "qwen" || ! lite_is_ai_available "droid"; then
    has_important_missing=true
    echo -e "  ${YELLOW}🟡 Important AIs (recommended):${RESET}"
    echo ""
    
    if ! lite_is_ai_available "qwen"; then
      echo -e "    ${BOLD}Qwen${RESET} - Fast Prototyping (37s average)"
      echo -e "    ${DIM}npm install -g @anthropic-ai/qwen-code${RESET}"
      echo ""
    fi
    
    if ! lite_is_ai_available "droid"; then
      echo -e "    ${BOLD}Droid${RESET} - Enterprise Quality"
      echo -e "    ${DIM}https://docs.factory.ai/cli/getting-started/quickstart${RESET}"
      echo ""
    fi
  fi
  
  # Optional AIs
  local has_optional_missing=false
  if ! lite_is_ai_available "codex" || ! lite_is_ai_available "cursor" || ! lite_is_ai_available "amp"; then
    has_optional_missing=true
    echo -e "  ${GREEN}🟢 Optional AIs (for full experience):${RESET}"
    echo ""
    
    if ! lite_is_ai_available "codex"; then
      echo -e "    ${BOLD}Codex${RESET} - Code Review & Optimization"
      echo -e "    ${DIM}npm install -g @openai/codex${RESET}"
      echo ""
    fi
    
    if ! lite_is_ai_available "cursor"; then
      echo -e "    ${BOLD}Cursor${RESET} - IDE Integration"
      echo -e "    ${DIM}https://cursor.com/ja/docs/cli/overview${RESET}"
      echo ""
    fi
    
    if ! lite_is_ai_available "amp"; then
      echo -e "    ${BOLD}Amp${RESET} - Project Management"
      echo -e "    ${DIM}https://ampcode.com/manual${RESET}"
      echo ""
    fi
  fi
  
  prompt_continue
}

# Step 4: Quick Start Guide
step_quickstart() {
  clear_screen
  print_header
  print_step 3 4 "Quick Start Guide"
  
  local mode=$(lite_get_available_mode)
  
  echo "  Now you're ready to use Multi-AI Orchestrium in ${BOLD}$mode${RESET} mode!"
  echo ""
  echo -e "  ${CYAN}━━━ Quick Commands ━━━${RESET}"
  echo ""
  echo "  # Check AI status"
  echo -e "  ${DIM}./scripts/lite-mode/lite-mode-checker.sh${RESET}"
  echo ""
  echo "  # Run orchestrated workflow"
  echo -e "  ${DIM}source scripts/lite-mode/lite-mode-orchestrator.sh${RESET}"
  echo -e "  ${DIM}lite_orchestrate \"implement user authentication\"${RESET}"
  echo ""
  echo "  # Quick review"
  echo -e "  ${DIM}source scripts/lite-mode/lite-mode-orchestrator.sh${RESET}"
  echo -e "  ${DIM}lite_quick_review path/to/file.py${RESET}"
  echo ""
  echo "  # Quick implementation"
  echo -e "  ${DIM}source scripts/lite-mode/lite-mode-orchestrator.sh${RESET}"
  echo -e "  ${DIM}lite_quick_implement \"create a REST API endpoint\"${RESET}"
  echo ""
  
  if [[ "$mode" == "full" ]] || [[ "$mode" == "standard" ]]; then
    echo -e "  ${CYAN}━━━ Full Orchestration (your mode supports this!) ━━━${RESET}"
    echo ""
    echo -e "  ${DIM}source scripts/orchestrate/orchestrate-multi-ai.sh${RESET}"
    echo -e "  ${DIM}multi-ai-full-orchestrate \"your task\"${RESET}"
    echo ""
  fi
  
  prompt_continue
}

# Step 5: Finish
step_finish() {
  clear_screen
  print_header
  print_step 4 4 "Setup Complete!"
  
  local mode=$(lite_get_available_mode)
  local count=$(lite_get_ai_count)
  
  echo -e "  ${GREEN}✅ Setup wizard completed successfully!${RESET}"
  echo ""
  echo -e "  ${BOLD}Your Configuration:${RESET}"
  echo -e "    • Mode: ${CYAN}$mode${RESET}"
  echo -e "    • AIs Available: ${CYAN}$count${RESET}"
  echo -e "    • Available AIs: ${CYAN}$(lite_get_available_ais)${RESET}"
  echo ""
  echo -e "  ${BOLD}Next Steps:${RESET}"
  echo "    1. Try a quick review: lite_quick_review <file>"
  echo "    2. Run an orchestrated task: lite_orchestrate \"your task\""
  echo "    3. Install more AIs for enhanced features"
  echo ""
  echo -e "  ${BOLD}Documentation:${RESET}"
  echo "    • README: $WIZARD_ROOT_DIR/README.md"
  echo "    • Lite Mode: $WIZARD_ROOT_DIR/docs/LITE_MODE_GUIDE.md"
  echo ""
  echo -e "  ${DIM}Thank you for using Multi-AI Orchestrium!${RESET}"
  echo ""
}

# ============================================================================
# Interactive Menu
# ============================================================================

show_main_menu() {
  clear_screen
  print_header
  
  echo "  What would you like to do?"
  echo ""
  echo -e "    ${CYAN}1)${RESET} Run Setup Wizard (recommended for first time)"
  echo -e "    ${CYAN}2)${RESET} Check AI Tools Status"
  echo -e "    ${CYAN}3)${RESET} Show Installation Commands"
  echo -e "    ${CYAN}4)${RESET} Quick Start Guide"
  echo -e "    ${CYAN}5)${RESET} Exit"
  echo ""
  echo -e -n "  Enter choice [1-5]: "
  read -r choice
  
  case "$choice" in
    1)
      run_wizard
      ;;
    2)
      clear_screen
      print_header
      lite_check_all_ais
      lite_show_recommendations
      prompt_continue
      show_main_menu
      ;;
    3)
      show_install_commands
      ;;
    4)
      step_quickstart
      show_main_menu
      ;;
    5)
      echo ""
      echo "  Goodbye! 👋"
      echo ""
      exit 0
      ;;
    *)
      show_main_menu
      ;;
  esac
}

show_install_commands() {
  clear_screen
  print_header
  
  echo -e "  ${BOLD}AI Installation Commands${RESET}"
  echo ""
  echo -e "  ${CYAN}NPM-based tools:${RESET}"
  echo "    npm install -g @anthropic-ai/claude-code     # Claude"
  echo "    npm install -g @google/gemini-cli            # Gemini"
  echo "    npm install -g @anthropic-ai/qwen-code       # Qwen"
  echo "    npm install -g @openai/codex                 # Codex"
  echo ""
  echo -e "  ${CYAN}Standalone tools:${RESET}"
  echo "    # Cursor - https://cursor.com/ja/docs/cli/overview"
  echo "    # Amp    - https://ampcode.com/manual"
  echo "    # Droid  - https://docs.factory.ai/cli/getting-started/quickstart"
  echo ""
  
  prompt_continue
  show_main_menu
}

run_wizard() {
  step_welcome
  step_check_status
  step_recommendations
  step_quickstart
  step_finish
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
  # Check for --help
  if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Multi-AI Orchestrium Setup Wizard"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --wizard       Run the setup wizard directly"
    echo "  --check        Check AI tools status only"
    echo "  --menu         Show interactive menu"
    echo ""
    exit 0
  fi
  
  # Check for flags
  case "${1:-menu}" in
    --wizard)
      run_wizard
      ;;
    --check)
      lite_check_all_ais
      lite_show_recommendations
      ;;
    --menu|*)
      show_main_menu
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
