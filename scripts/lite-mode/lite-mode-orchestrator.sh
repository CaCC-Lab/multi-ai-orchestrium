#!/usr/bin/env bash
# lite-mode-orchestrator.sh - Lite Mode オーケストレーター
#
# Purpose: 利用可能なAIに基づいてワークフローを動的に調整
# Version: 1.0.0
# Date: 2025-11-27
#
# Usage:
#   source scripts/lite-mode/lite-mode-orchestrator.sh
#   lite_orchestrate "task description"

set -euo pipefail

# ============================================================================
# Dependencies
# ============================================================================

LITE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITE_ROOT_DIR="$(cd "$LITE_SCRIPT_DIR/../.." && pwd)"

# Load checker
source "$LITE_SCRIPT_DIR/lite-mode-checker.sh"

# Load VibeLogger if available
if [[ -f "$LITE_ROOT_DIR/bin/vibe-logger-lib.sh" ]]; then
  source "$LITE_ROOT_DIR/bin/vibe-logger-lib.sh"
fi

# ============================================================================
# Configuration
# ============================================================================

LITE_CONFIG_FILE="$LITE_ROOT_DIR/config/lite-mode-profiles.yaml"
LITE_LOG_DIR="$LITE_ROOT_DIR/logs/lite-mode"
LITE_INITIALIZED=false

# ============================================================================
# Initialization
# ============================================================================

lite_init() {
  if [[ "$LITE_INITIALIZED" == "true" ]]; then
    return 0
  fi
  
  # Create log directory
  mkdir -p "$LITE_LOG_DIR"
  
  # Check AI availability
  lite_check_all_ais
  
  # Display mode banner
  _lite_show_banner
  
  LITE_INITIALIZED=true
}

_lite_show_banner() {
  local mode=$(lite_get_available_mode)
  
  case "$mode" in
    single)
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  🔹 LITE MODE: Single AI                                     ║"
      echo "║  Running with 1 AI - Basic functionality available           ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
      echo "💡 Tip: Install more AIs for enhanced features"
      echo "   Run: $LITE_SCRIPT_DIR/setup-wizard.sh"
      ;;
    basic)
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  🔸 LITE MODE: Basic (2-3 AIs)                               ║"
      echo "║  Core workflows available with fallback support              ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
      ;;
    standard)
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  🔶 STANDARD MODE (4-5 AIs)                                  ║"
      echo "║  Most workflows available including parallel execution       ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
      ;;
    full)
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  ✅ FULL MODE (6-7 AIs)                                      ║"
      echo "║  All features available - Maximum AI collaboration           ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
      ;;
    none)
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  ❌ NO AI AVAILABLE                                          ║"
      echo "║  Please install at least one AI CLI tool                     ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
      lite_show_recommendations
      return 1
      ;;
  esac
}

# ============================================================================
# AI Execution Functions
# ============================================================================

# 単一AIでタスクを実行
# Arguments: $1=AI name, $2=prompt, $3=timeout (optional)
lite_execute_ai() {
  local ai_name="$1"
  local prompt="$2"
  local timeout="${3:-300}"
  
  # AIが利用可能かチェック
  if ! lite_is_ai_available "$ai_name"; then
    echo "❌ Error: $ai_name is not available" >&2
    return 1
  fi
  
  echo "🤖 Executing with $ai_name (timeout: ${timeout}s)..."
  
  local start_time=$(date +%s)
  local output=""
  local exit_code=0
  
  # AIごとの実行コマンド
  case "$ai_name" in
    claude)
      output=$(timeout "${timeout}s" claude -p "$prompt" 2>&1) || exit_code=$?
      ;;
    gemini)
      output=$(timeout "${timeout}s" gemini -p "$prompt" 2>&1) || exit_code=$?
      ;;
    qwen)
      output=$(timeout "${timeout}s" qwen -p "$prompt" 2>&1) || exit_code=$?
      ;;
    droid)
      output=$(timeout "${timeout}s" droid "$prompt" 2>&1) || exit_code=$?
      ;;
    codex)
      output=$(timeout "${timeout}s" codex -p "$prompt" 2>&1) || exit_code=$?
      ;;
    cursor)
      output=$(timeout "${timeout}s" cursor -p "$prompt" 2>&1) || exit_code=$?
      ;;
    amp)
      output=$(timeout "${timeout}s" amp "$prompt" 2>&1) || exit_code=$?
      ;;
    *)
      echo "❌ Unknown AI: $ai_name" >&2
      return 1
      ;;
  esac
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  if [[ $exit_code -eq 0 ]]; then
    echo "✅ $ai_name completed in ${duration}s"
  elif [[ $exit_code -eq 124 ]]; then
    echo "⏰ $ai_name timed out after ${timeout}s" >&2
  else
    echo "⚠️ $ai_name exited with code $exit_code" >&2
  fi
  
  echo "$output"
  return $exit_code
}

# フォールバック付きでAI実行
# Arguments: $1=role, $2=prompt, $3=timeout
lite_execute_with_fallback() {
  local role="$1"
  local prompt="$2"
  local timeout="${3:-300}"
  
  # ロールに最適なAIを取得
  local ai=$(lite_get_ai_for_role "$role")
  
  if [[ -z "$ai" ]]; then
    echo "❌ No AI available for role: $role" >&2
    return 1
  fi
  
  echo "📋 Role: $role → Using: $ai"
  
  if lite_execute_ai "$ai" "$prompt" "$timeout"; then
    return 0
  fi
  
  # フォールバック試行
  echo "🔄 Trying fallback for role: $role..."
  
  local fallbacks
  case "$role" in
    strategy) fallbacks="gemini amp droid";;
    research) fallbacks="claude amp";;
    prototype) fallbacks="claude cursor droid";;
    enterprise) fallbacks="claude qwen";;
    review) fallbacks="claude gemini droid";;
    integration) fallbacks="qwen codex claude";;
    pm) fallbacks="claude gemini";;
    *) fallbacks="";;
  esac
  
  for fallback_ai in $fallbacks; do
    if [[ "$fallback_ai" != "$ai" ]] && lite_is_ai_available "$fallback_ai"; then
      echo "🔄 Fallback: Trying $fallback_ai..."
      if lite_execute_ai "$fallback_ai" "$prompt" "$timeout"; then
        return 0
      fi
    fi
  done
  
  echo "❌ All fallbacks failed for role: $role" >&2
  return 1
}

# ============================================================================
# Workflow Execution
# ============================================================================

# メインオーケストレーション関数
# Arguments: $1=task description
lite_orchestrate() {
  local task="$1"
  
  # 初期化
  lite_init || return 1
  
  local mode=$(lite_get_available_mode)
  local workflow=""
  
  # タスクタイプの自動検出
  if [[ "$task" =~ (review|check|audit) ]]; then
    workflow="review"
  elif [[ "$task" =~ (develop|implement|create|build) ]]; then
    workflow="development"
  elif [[ "$task" =~ (tdd|test) ]]; then
    workflow="tdd"
  elif [[ "$task" =~ (plan|design|architect) ]]; then
    workflow="planning"
  else
    workflow="general"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📋 Task: $task"
  echo "  🔧 Mode: $mode | Workflow: $workflow"
  echo "  🤖 Available AIs: $(lite_get_available_ais)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # モードに応じたワークフロー実行
  case "$mode" in
    single)
      _lite_run_single_workflow "$task" "$workflow"
      ;;
    basic)
      _lite_run_basic_workflow "$task" "$workflow"
      ;;
    standard)
      _lite_run_standard_workflow "$task" "$workflow"
      ;;
    full)
      _lite_run_full_workflow "$task" "$workflow"
      ;;
    *)
      echo "❌ Cannot orchestrate: No AIs available" >&2
      return 1
      ;;
  esac
}

# Single AI Workflow
_lite_run_single_workflow() {
  local task="$1"
  local workflow="$2"
  
  echo "📦 Running Single AI Workflow..."
  echo ""
  
  local ai=$(echo "${LITE_AVAILABLE_AIS[0]}")
  
  case "$workflow" in
    review)
      lite_execute_ai "$ai" "Please review the following and provide feedback: $task" 600
      ;;
    development)
      lite_execute_ai "$ai" "Please implement the following: $task" 900
      ;;
    tdd)
      lite_execute_ai "$ai" "Please write tests and implementation for: $task" 900
      ;;
    planning)
      lite_execute_ai "$ai" "Please create a plan for: $task" 600
      ;;
    *)
      lite_execute_ai "$ai" "$task" 600
      ;;
  esac
}

# Basic 2-3 AI Workflow
_lite_run_basic_workflow() {
  local task="$1"
  local workflow="$2"
  
  echo "📦 Running Basic Workflow (2-3 AIs)..."
  echo ""
  
  case "$workflow" in
    review)
      echo "=== Phase 1: Primary Review ==="
      local review_output=$(lite_execute_with_fallback "review" "Review this code/task: $task" 600)
      
      echo ""
      echo "=== Phase 2: Verification ==="
      lite_execute_with_fallback "strategy" "Verify and add any missing points to this review: $review_output" 300
      ;;
      
    development)
      echo "=== Phase 1: Planning ==="
      local plan_output=$(lite_execute_with_fallback "strategy" "Create a brief implementation plan for: $task" 300)
      
      echo ""
      echo "=== Phase 2: Implementation ==="
      local impl_output=$(lite_execute_with_fallback "prototype" "Based on this plan, implement: $plan_output\n\nTask: $task" 600)
      
      echo ""
      echo "=== Phase 3: Review ==="
      lite_execute_with_fallback "review" "Review this implementation: $impl_output" 300
      ;;
      
    tdd)
      echo "=== Phase 1: Test Design ==="
      local test_output=$(lite_execute_with_fallback "prototype" "Write tests for: $task" 300)
      
      echo ""
      echo "=== Phase 2: Implementation ==="
      local impl_output=$(lite_execute_with_fallback "prototype" "Implement code to pass these tests: $test_output\n\nTask: $task" 600)
      
      echo ""
      echo "=== Phase 3: Review ==="
      lite_execute_with_fallback "review" "Review this TDD implementation:\nTests: $test_output\nImplementation: $impl_output" 300
      ;;
      
    planning)
      echo "=== Phase 1: Initial Plan ==="
      local plan_output=$(lite_execute_with_fallback "strategy" "Create a detailed plan for: $task" 600)
      
      echo ""
      echo "=== Phase 2: Research & Enhancement ==="
      lite_execute_with_fallback "research" "Research best practices and enhance this plan: $plan_output" 300
      ;;
      
    *)
      echo "=== Phase 1: Execute ==="
      local output=$(lite_execute_with_fallback "strategy" "$task" 600)
      
      echo ""
      echo "=== Phase 2: Review ==="
      lite_execute_with_fallback "review" "Review this output: $output" 300
      ;;
  esac
}

# Standard 4-5 AI Workflow
_lite_run_standard_workflow() {
  local task="$1"
  local workflow="$2"
  
  echo "📦 Running Standard Workflow (4-5 AIs)..."
  echo ""
  
  case "$workflow" in
    development)
      echo "=== Phase 1: Research & Planning (Parallel) ==="
      # 簡易並列実行
      local research_output=""
      local plan_output=""
      
      {
        research_output=$(lite_execute_with_fallback "research" "Research best practices for: $task" 300)
      } &
      local pid1=$!
      
      {
        plan_output=$(lite_execute_with_fallback "strategy" "Create architecture plan for: $task" 300)
      } &
      local pid2=$!
      
      wait $pid1 $pid2 2>/dev/null || true
      
      echo ""
      echo "=== Phase 2: Parallel Implementation ==="
      local fast_output=""
      local quality_output=""
      
      {
        fast_output=$(lite_execute_with_fallback "prototype" "Quickly implement: $task\nPlan: $plan_output" 300)
      } &
      pid1=$!
      
      {
        quality_output=$(lite_execute_with_fallback "enterprise" "Implement with enterprise quality: $task\nPlan: $plan_output" 600)
      } &
      pid2=$!
      
      wait $pid1 $pid2 2>/dev/null || true
      
      echo ""
      echo "=== Phase 3: Review & Integration ==="
      lite_execute_with_fallback "review" "Compare and merge these implementations:\n\nFast: $fast_output\n\nQuality: $quality_output" 300
      ;;
      
    *)
      # 他のワークフローはBasicにフォールバック
      _lite_run_basic_workflow "$task" "$workflow"
      ;;
  esac
}

# Full 6-7 AI Workflow
_lite_run_full_workflow() {
  local task="$1"
  local workflow="$2"
  
  echo "📦 Running Full Workflow (6-7 AIs)..."
  echo ""
  echo "ℹ️  For full workflows, consider using the standard orchestrator:"
  echo "   source scripts/orchestrate/orchestrate-multi-ai.sh"
  echo "   multi-ai-full-orchestrate \"$task\""
  echo ""
  
  # Full modeでも動作するようにStandardワークフローを実行
  _lite_run_standard_workflow "$task" "$workflow"
}

# ============================================================================
# Convenience Functions
# ============================================================================

# クイックレビュー
lite_quick_review() {
  local target="${1:-}"
  
  lite_init || return 1
  
  local ai=$(lite_get_ai_for_role "review")
  if [[ -z "$ai" ]]; then
    ai=$(echo "${LITE_AVAILABLE_AIS[0]}")
  fi
  
  if [[ -z "$target" ]]; then
    echo "Usage: lite_quick_review <file_or_description>"
    return 1
  fi
  
  echo "🔍 Quick Review with $ai..."
  
  if [[ -f "$target" ]]; then
    local content=$(cat "$target")
    lite_execute_ai "$ai" "Please review this file ($target):\n\n$content" 300
  else
    lite_execute_ai "$ai" "Please review: $target" 300
  fi
}

# クイック実装
lite_quick_implement() {
  local task="$1"
  
  lite_init || return 1
  
  local ai=$(lite_get_ai_for_role "prototype")
  if [[ -z "$ai" ]]; then
    ai=$(echo "${LITE_AVAILABLE_AIS[0]}")
  fi
  
  echo "🚀 Quick Implementation with $ai..."
  lite_execute_ai "$ai" "Please implement: $task" 600
}

# ステータス表示
lite_status() {
  lite_check_all_ais
  lite_show_recommendations
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Available Commands:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  lite_orchestrate \"task\"   - Run full orchestration"
  echo "  lite_quick_review <file>  - Quick code review"
  echo "  lite_quick_implement \"task\" - Quick implementation"
  echo "  lite_status               - Show this status"
  echo ""
}

# ============================================================================
# Export Functions
# ============================================================================

export -f lite_init 2>/dev/null || true
export -f lite_orchestrate 2>/dev/null || true
export -f lite_execute_ai 2>/dev/null || true
export -f lite_execute_with_fallback 2>/dev/null || true
export -f lite_quick_review 2>/dev/null || true
export -f lite_quick_implement 2>/dev/null || true
export -f lite_status 2>/dev/null || true

# ============================================================================
# Main Entry Point (if run directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-status}" in
    status)
      lite_status
      ;;
    orchestrate)
      shift
      lite_orchestrate "$*"
      ;;
    review)
      shift
      lite_quick_review "$@"
      ;;
    implement)
      shift
      lite_quick_implement "$*"
      ;;
    *)
      echo "Lite Mode Orchestrator"
      echo ""
      echo "Usage: $0 {status|orchestrate|review|implement}"
      echo ""
      echo "Commands:"
      echo "  status              - Show AI availability and status"
      echo "  orchestrate <task>  - Run orchestrated workflow"
      echo "  review <file>       - Quick code review"
      echo "  implement <task>    - Quick implementation"
      echo ""
      echo "Or source this file and use functions directly:"
      echo "  source $0"
      echo "  lite_orchestrate \"your task\""
      ;;
  esac
fi
