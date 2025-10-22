#!/bin/bash
# TDD-Based Multi-AI Development Functions
# Version: 2.0 - Profile-based configuration with common library
# Multi-AI体制: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Only set PROJECT_ROOT if not already defined (for testing flexibility)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Load common library
# shellcheck source=scripts/lib/tdd-multi-ai-common.sh
source "$SCRIPT_DIR/../lib/tdd-multi-ai-common.sh"

# Load VibeLogger library
# shellcheck source=bin/vibe-logger-lib.sh
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"

# Default TDD profile
TDD_PROFILE="${TDD_PROFILE:-balanced}"

# ============================================================================
# Phase 0: Project Planning (Amp)
# ============================================================================

tdd-multi-ai-plan() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${MAGENTA}📋 PLAN Phase (Profile: $profile)${NC}"
    echo "Feature: $feature"
    echo ""

    # Load configuration
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "plan" "primary") || primary_ai="amp"
    local timeout
    timeout=$(get_phase_timeout "$profile" "plan") || timeout=600
    local context
    context=$(get_phase_context "$profile" "plan")

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "PLAN" 0 1

    log_phase_start "PLAN Phase" "$primary_ai"

    local task="Create TDD project plan for: $feature. Context: $context"
    local start_time
    start_time=$(get_timestamp_ms)

    if invoke_ai "$primary_ai" "$task" "$timeout"; then
        local end_time
        end_time=$(get_timestamp_ms)
        local duration
        duration=$(calculate_duration "$start_time" "$end_time")
        local duration_ms
        duration_ms=$((end_time - start_time))

        log_phase_end "PLAN Phase" "success"
        record_metrics "plan" "$duration" "success"

        # VibeLogger: Log phase completion
        vibe_tdd_phase_done "PLAN" 0 1 0 "$duration_ms"
    else
        local end_time
        end_time=$(get_timestamp_ms)
        local duration_ms
        duration_ms=$((end_time - start_time))

        echo -e "${YELLOW}Plan phase completed with warnings${NC}"
        log_phase_end "PLAN Phase" "warning"

        # VibeLogger: Log phase completion with warning
        vibe_tdd_phase_done "PLAN" 0 0 1 "$duration_ms"
    fi
}

# ============================================================================
# Phase 1: RED - Write failing test
# ============================================================================

tdd-multi-ai-red() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${RED}🔴 RED Phase: Writing failing tests (Profile: $profile)${NC}"
    echo ""

    # Load configuration
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "red" "primary") || primary_ai="droid"
    local fallback_ai
    fallback_ai=$(get_phase_ai "$profile" "red" "fallback") || fallback_ai="cursor"
    local timeout
    timeout=$(get_phase_timeout "$profile" "red") || timeout=900
    local context
    context=$(get_phase_context "$profile" "red")

    log_phase_start "RED Phase - Test Design" "$primary_ai"

    local task="Write comprehensive failing tests for: $feature. Context: $context. Include edge cases, error scenarios, and security tests."
    local start_time
    start_time=$(get_timestamp_ms)

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "RED" 1 1

    # Execute with fallback
    if execute_with_fallback "$primary_ai" "$fallback_ai" "$task" "$timeout"; then
        local end_time
        end_time=$(get_timestamp_ms)
        local duration
        duration=$(calculate_duration "$start_time" "$end_time")

        log_phase_end "RED Phase" "success"
        record_metrics "red" "$duration" "success"

        # VibeLogger: Log phase completion (success)
        vibe_tdd_phase_done "RED" 1 1 0 "$duration"

        echo ""
        echo -e "${RED}✓ Failing tests ready (should fail now)${NC}"
    else
        local end_time
        end_time=$(get_timestamp_ms)
        local duration
        duration=$(calculate_duration "$start_time" "$end_time")

        echo -e "${YELLOW}⚠ Red phase failed - manual test writing required${NC}"
        log_phase_end "RED Phase" "warning"

        # VibeLogger: Log phase completion (failure)
        vibe_tdd_phase_done "RED" 1 0 1 "$duration"

        return 1
    fi
}

# ============================================================================
# Phase 2: GREEN - Make test pass
# ============================================================================

tdd-multi-ai-green() {
    local test_description="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${GREEN}🟢 GREEN Phase: Writing code to pass tests (Profile: $profile)${NC}"
    echo ""

    # Load configuration
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "green" "primary") || primary_ai="qwen"
    local fallback_ai
    fallback_ai=$(get_phase_ai "$profile" "green" "fallback") || fallback_ai="droid"
    local timeout
    timeout=$(get_phase_timeout "$profile" "green") || timeout=300
    local context
    context=$(get_phase_context "$profile" "green")
    local is_parallel
    is_parallel=$(is_parallel_phase "$profile" "green" && echo "true" || echo "false")

    log_phase_start "GREEN Phase - Implementation" "$primary_ai"

    local task="Implement code to make tests pass: $test_description. Context: $context"
    local start_time
    start_time=$(get_timestamp_ms)

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "GREEN" 2 1

    if [[ "$is_parallel" == "true" ]]; then
        echo -e "${CYAN}Parallel implementation: $primary_ai + $fallback_ai${NC}"
        echo ""

        # Parallel execution
        if execute_parallel "$primary_ai" "$fallback_ai" "$task" "$timeout"; then
            local end_time
            end_time=$(get_timestamp_ms)
            local duration
            duration=$(calculate_duration "$start_time" "$end_time")

            log_phase_end "GREEN Phase (Parallel)" "success"
            record_metrics "green_parallel" "$duration" "success"

            # VibeLogger: Log phase completion (success)
            vibe_tdd_phase_done "GREEN" 2 1 0 "$duration"
        else
            local end_time
            end_time=$(get_timestamp_ms)
            local duration
            duration=$(calculate_duration "$start_time" "$end_time")

            echo -e "${YELLOW}⚠ Both implementations failed${NC}"
            log_phase_end "GREEN Phase" "warning"

            # VibeLogger: Log phase completion (failure)
            vibe_tdd_phase_done "GREEN" 2 0 1 "$duration"

            return 1
        fi
    else
        # Sequential with fallback
        if execute_with_fallback "$primary_ai" "$fallback_ai" "$task" "$timeout"; then
            local end_time
            end_time=$(get_timestamp_ms)
            local duration
            duration=$(calculate_duration "$start_time" "$end_time")

            log_phase_end "GREEN Phase" "success"
            record_metrics "green" "$duration" "success"

            # VibeLogger: Log phase completion (success)
            vibe_tdd_phase_done "GREEN" 2 1 0 "$duration"
        else
            local end_time
            end_time=$(get_timestamp_ms)
            local duration
            duration=$(calculate_duration "$start_time" "$end_time")

            echo -e "${YELLOW}⚠ Green phase failed${NC}"
            log_phase_end "GREEN Phase" "warning"

            # VibeLogger: Log phase completion (failure)
            vibe_tdd_phase_done "GREEN" 2 0 1 "$duration"

            return 1
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ Implementation complete${NC}"
}

# ============================================================================
# Phase 3: REFACTOR - Improve code quality
# ============================================================================

tdd-multi-ai-refactor() {
    local code="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${BLUE}🔵 REFACTOR Phase: Optimizing code quality (Profile: $profile)${NC}"
    echo ""

    # Load configuration
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "refactor" "primary") || primary_ai="codex"
    local reviewer_ai
    reviewer_ai=$(get_phase_ai "$profile" "refactor" "reviewer") || reviewer_ai="claude"
    local timeout
    timeout=$(get_phase_timeout "$profile" "refactor") || timeout=300
    local context
    context=$(get_phase_context "$profile" "refactor")

    log_phase_start "REFACTOR Phase - Optimization" "$primary_ai"

    local task="Optimize and refactor: $code. Context: $context"
    local start_time
    start_time=$(get_timestamp_ms)

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "REFACTOR" 3 1

    # Primary AI optimization
    echo -e "${CYAN}Primary optimization: $primary_ai${NC}"
    if invoke_ai "$primary_ai" "$task" "$timeout"; then
        echo ""
        echo -e "${GREEN}✓ $primary_ai optimization complete${NC}"
    else
        echo -e "${YELLOW}⚠ $primary_ai optimization failed${NC}"
    fi

    echo ""

    # Reviewer AI validation
    if [[ -n "$reviewer_ai" ]]; then
        echo -e "${CYAN}Review: $reviewer_ai${NC}"
        local review_task="Review and validate refactored code for: $code. Check architecture, maintainability, and best practices."

        if invoke_ai "$reviewer_ai" "$review_task" "$timeout"; then
            echo ""
            echo -e "${GREEN}✓ $reviewer_ai review complete${NC}"
        else
            echo -e "${YELLOW}⚠ $reviewer_ai review failed${NC}"
        fi
    fi

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$(calculate_duration "$start_time" "$end_time")

    log_phase_end "REFACTOR Phase" "success"
    record_metrics "refactor" "$duration" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "REFACTOR" 3 1 0 "$duration"

    echo ""
    echo -e "${BLUE}✓ Refactoring complete${NC}"
}

# ============================================================================
# Phase 4: REVIEW - Comprehensive review
# ============================================================================

tdd-multi-ai-review() {
    local implementation="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${YELLOW}🔍 REVIEW Phase: Comprehensive evaluation (Profile: $profile)${NC}"
    echo ""

    # Load configuration
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "review" "primary") || primary_ai="gemini"
    local secondary_ai
    secondary_ai=$(get_phase_ai "$profile" "review" "secondary") || secondary_ai="amp"
    local timeout
    timeout=$(get_phase_timeout "$profile" "review") || timeout=600
    local context
    context=$(get_phase_context "$profile" "review")

    log_phase_start "REVIEW Phase" "$primary_ai"

    local start_time
    start_time=$(get_timestamp_ms)

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "REVIEW" 4 1

    # Primary review
    echo -e "${CYAN}Technical review: $primary_ai${NC}"
    local task="Review TDD implementation: $implementation. Context: $context. Check test coverage, design patterns, security, performance, and best practices."

    if invoke_ai "$primary_ai" "$task" "$timeout"; then
        echo ""
        echo -e "${GREEN}✓ $primary_ai review complete${NC}"
    else
        echo -e "${YELLOW}⚠ $primary_ai review failed${NC}"
    fi

    echo ""

    # Secondary review
    if [[ -n "$secondary_ai" ]]; then
        echo -e "${CYAN}Project management review: $secondary_ai${NC}"
        local pm_task="Review TDD cycle completion: $implementation. Check requirements met, timeline adherence, documentation completeness, and next steps."

        if invoke_ai "$secondary_ai" "$pm_task" "$timeout"; then
            echo ""
            echo -e "${GREEN}✓ $secondary_ai review complete${NC}"
        else
            echo -e "${YELLOW}⚠ $secondary_ai review failed${NC}"
        fi
    fi

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$(calculate_duration "$start_time" "$end_time")

    log_phase_end "REVIEW Phase" "success"
    record_metrics "review" "$duration" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "REVIEW" 4 1 0 "$duration"

    echo ""
    echo -e "${YELLOW}✓ Review complete${NC}"
}

# ============================================================================
# Complete Multi-AI TDD Cycle
# ============================================================================

tdd-multi-ai-cycle() {
    local feature="$1"
    local profile="${2:-$TDD_PROFILE}"

    # Update profile for this cycle
    TDD_PROFILE="$profile"

    # Validate profile
    if ! validate_tdd_profile "$profile"; then
        echo -e "${RED}Error: Invalid TDD profile '$profile'${NC}" >&2
        echo "Available profiles:" >&2
        list_tdd_profiles >&2
        return 1
    fi

    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║        Multi-AI TDD Cycle - Profile: $profile                  ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Feature: $feature"
    echo ""

    local cycle_start
    cycle_start=$(get_timestamp_ms)

    # Phase 0: Planning
    echo -e "${MAGENTA}[0/4] PLAN Phase${NC}"
    tdd-multi-ai-plan "$feature" || echo "Plan phase completed with warnings"
    echo ""

    read -p "Press Enter to continue to RED phase..." -r

    # Phase 1: Red
    echo -e "${RED}[1/4] RED Phase${NC}"
    tdd-multi-ai-red "$feature" || { echo "Red phase failed"; return 1; }
    echo ""

    read -p "Press Enter to continue to GREEN phase..." -r

    # Phase 2: Green
    echo -e "${GREEN}[2/4] GREEN Phase${NC}"
    tdd-multi-ai-green "$feature" || { echo "Green phase failed"; return 1; }
    echo ""

    read -p "Press Enter to continue to REFACTOR phase..." -r

    # Phase 3: Refactor
    echo -e "${BLUE}[3/4] REFACTOR Phase${NC}"
    tdd-multi-ai-refactor "Optimize the previous implementation" || echo "Refactor phase completed with warnings"
    echo ""

    read -p "Press Enter to continue to REVIEW phase..." -r

    # Phase 4: Review
    echo -e "${YELLOW}[4/4] REVIEW Phase${NC}"
    tdd-multi-ai-review "$feature implementation" || echo "Review phase completed with warnings"
    echo ""

    local cycle_end
    cycle_end=$(get_timestamp_ms)
    local total_duration
    total_duration=$(calculate_duration "$cycle_start" "$cycle_end")

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            Multi-AI TDD Cycle Complete! 🎉                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Profile: $profile"
    echo "Total time: ${total_duration}s"
    echo ""
    echo "Multi-AI Contributions (Profile-based):"
    echo "  • Plan:     $(get_phase_ai "$profile" "plan" "primary" || echo "amp")"
    echo "  • Red:      $(get_phase_ai "$profile" "red" "primary" || echo "droid")"
    echo "  • Green:    $(get_phase_ai "$profile" "green" "primary" || echo "qwen")"
    echo "  • Refactor: $(get_phase_ai "$profile" "refactor" "primary" || echo "codex")"
    echo "  • Review:   $(get_phase_ai "$profile" "review" "primary" || echo "gemini")"
    echo ""
}

# ============================================================================
# Fast Multi-AI TDD (No pauses)
# ============================================================================

tdd-multi-ai-fast() {
    local feature="$1"
    local profile="${2:-speed_first}"

    # Update profile for fast mode
    TDD_PROFILE="$profile"

    # Validate profile
    if ! validate_tdd_profile "$profile"; then
        echo -e "${RED}Error: Invalid TDD profile '$profile'${NC}" >&2
        return 1
    fi

    echo -e "${CYAN}⚡ Fast Multi-AI TDD Cycle (Profile: $profile, no pauses)${NC}"
    echo "Feature: $feature"
    echo ""

    local cycle_start
    cycle_start=$(get_timestamp_ms)

    tdd-multi-ai-plan "$feature"
    tdd-multi-ai-red "$feature"
    tdd-multi-ai-green "$feature"
    tdd-multi-ai-refactor "Quick refactoring"
    tdd-multi-ai-review "$feature"

    local cycle_end
    cycle_end=$(get_timestamp_ms)
    local total_duration
    total_duration=$(calculate_duration "$cycle_start" "$cycle_end")

    echo ""
    echo -e "${GREEN}✓ Fast Multi-AI TDD Complete (${total_duration}s)${NC}"
}

# ============================================================================
# Pair Programming Mode: Driver-Navigator (Multi-AI)
# ============================================================================

pair-multi-ai-driver() {
    local task="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${CYAN}🚗 DRIVER Mode (Profile: $profile)${NC}"

    # Get driver AIs from green phase config
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "green" "primary") || primary_ai="qwen"
    local fallback_ai
    fallback_ai=$(get_phase_ai "$profile" "green" "fallback") || fallback_ai="droid"

    echo "Fast driver: $primary_ai"
    invoke_ai "$primary_ai" "Quick prototype for: $task" 120

    echo ""
    echo "Production driver: $fallback_ai"
    invoke_ai "$fallback_ai" "Production implementation for: $task" 600
}

pair-multi-ai-navigator() {
    local code="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${CYAN}🧭 NAVIGATOR Mode (Profile: $profile)${NC}"

    # Get navigator AIs from review phase config
    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "review" "primary") || primary_ai="gemini"
    local secondary_ai
    secondary_ai=$(get_phase_ai "$profile" "review" "secondary") || secondary_ai="amp"

    echo "Technical navigator: $primary_ai"
    invoke_ai "$primary_ai" "As navigator, review and guide: $code" 300

    echo ""
    echo "PM navigator: $secondary_ai"
    invoke_ai "$secondary_ai" "As navigator, review and suggest improvements: $code. Suggest next steps." 300
}

# ============================================================================
# Help & Banner
# ============================================================================

# Only show banner in interactive mode (not when sourced for testing)
if [[ -z "${TDD_Multi-AI_QUIET:-}" ]]; then
    echo "==================================="
    echo "  TDD Multi-AI v2.0 - Profile-Based"
    echo "==================================="
    echo ""
    echo "🎯 Current Profile: $TDD_PROFILE"
    echo ""
    echo "Available Profiles (use TDD_PROFILE=<name>):"
    list_tdd_profiles 2>/dev/null || echo "  (yq not installed - using default)"
    echo ""
    echo "📋→🔴→🟢→🔵→🔍 Complete Multi-AI TDD Cycle"
    echo ""
    echo "Commands:"
    echo "  tdd-multi-ai-cycle 'feature' [profile]   # 🚀 Complete cycle (with pauses)"
    echo "  tdd-multi-ai-fast 'feature' [profile]    # ⚡ Fast cycle (no pauses)"
    echo "  tdd-multi-ai-plan 'feature'              # 📋 Planning"
    echo "  tdd-multi-ai-red 'feature'               # 🔴 Tests"
    echo "  tdd-multi-ai-green 'test'                # 🟢 Code"
    echo "  tdd-multi-ai-refactor 'code'             # 🔵 Optimize"
    echo "  tdd-multi-ai-review 'impl'               # 🔍 Review"
    echo ""
    echo "Pair Programming:"
    echo "  pair-multi-ai-driver 'task'              # 🚗 Driver mode"
    echo "  pair-multi-ai-navigator 'code'           # 🧭 Navigator mode"
    echo ""
    echo "Example: TDD_PROFILE=speed_first tdd-multi-ai-cycle 'JWT auth'"
    echo ""
fi
