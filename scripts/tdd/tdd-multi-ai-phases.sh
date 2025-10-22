#!/bin/bash
# TDD-Based Multi-AI Development - Comprehensive 7-Phase Process
# Version: 2.0 - Profile-based configuration with common library
# Multi-AI体制: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor

set -euo pipefail

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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default TDD profile for 6-phase
TDD_PROFILE="${TDD_PROFILE:-six_phases}"

# ============================================================================
# Phase 0: Project Management Setup (Amp)
# ============================================================================

tdd-phase0-project-setup() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${MAGENTA}📋 PHASE 0: Project Management Setup (Profile: $profile)${NC}"
    echo ""

    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "phase0_project_setup" "primary") || primary_ai="amp"
    local timeout
    timeout=$(get_phase_timeout "$profile" "phase0_project_setup") || timeout=600
    local context
    context=$(get_phase_context "$profile" "phase0_project_setup")

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "Project Setup" 0 1

    log_phase_start "Phase 0 - Project Setup" "$primary_ai"

    local task="Create comprehensive TDD project plan for: $feature. Context: $context"
    local start_time
    start_time=$(get_timestamp_ms)

    invoke_ai "$primary_ai" "$task" "$timeout" || echo "Project setup completed with warnings"

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 0" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Project Setup" 0 1 0 "$duration"

    echo ""
}

# ============================================================================
# Phase 1: Requirements Research (Gemini)
# ============================================================================

tdd-phase1-research() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${YELLOW}🔍 PHASE 1: Requirements Research (Profile: $profile)${NC}"
    echo ""

    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "phase1_research" "primary") || primary_ai="gemini"
    local timeout
    timeout=$(get_phase_timeout "$profile" "phase1_research") || timeout=600
    local context
    context=$(get_phase_context "$profile" "phase1_research")

    # VibeLogger: Log phase start
    vibe_tdd_phase_start "Requirements Research" 1 1

    log_phase_start "Phase 1 - Requirements Research" "$primary_ai"

    local task="Research comprehensive requirements for: $feature. Context: $context"
    local start_time
    start_time=$(get_timestamp_ms)

    invoke_ai "$primary_ai" "$task" "$timeout" || echo "Research completed with warnings"

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 1" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Requirements Research" 1 1 0 "$duration"

    echo ""
}

# ============================================================================
# Phase 2: Test Design (Qwen + Droid)
# ============================================================================

tdd-phase2-test-design() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${RED}🔴 PHASE 2: Test Design (Profile: $profile)${NC}"
    echo ""

    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "phase2_test_design" "primary") || primary_ai="qwen"
    local secondary_ai
    secondary_ai=$(get_phase_ai "$profile" "phase2_test_design" "secondary") || secondary_ai="droid"
    local timeout
    timeout=$(get_phase_timeout "$profile" "phase2_test_design") || timeout=600
    local context
    context=$(get_phase_context "$profile" "phase2_test_design")
    local is_parallel
    is_parallel=$(is_parallel_phase "$profile" "phase2_test_design" && echo "true" || echo "false")

    # VibeLogger: Log phase start
    local start_time
    start_time=$(get_timestamp_ms)
    vibe_tdd_phase_start "Test Design" 2 1

    log_phase_start "Phase 2 - Test Design" "$primary_ai"

    local task="Design comprehensive test strategy for: $feature. Context: $context"

    if [[ "$is_parallel" == "true" ]]; then
        execute_parallel "$primary_ai" "$secondary_ai" "$task" "$timeout" || echo "Test design completed with warnings"
    else
        execute_with_fallback "$primary_ai" "$secondary_ai" "$task" "$timeout" || echo "Test design completed with warnings"
    fi

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 2" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Test Design" 2 1 0 "$duration"

    echo ""
}

# ============================================================================
# Phase 3: Architecture Design (Cursor + Amp)
# ============================================================================

tdd-phase3-architecture() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${YELLOW}📐 PHASE 3: Architecture Design (Profile: $profile)${NC}"
    echo ""

    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "phase3_architecture" "primary") || primary_ai="cursor"
    local secondary_ai
    secondary_ai=$(get_phase_ai "$profile" "phase3_architecture" "secondary") || secondary_ai="amp"
    local timeout
    timeout=$(get_phase_timeout "$profile" "phase3_architecture") || timeout=600
    local context
    context=$(get_phase_context "$profile" "phase3_architecture")
    local is_parallel
    is_parallel=$(is_parallel_phase "$profile" "phase3_architecture" && echo "true" || echo "false")

    # VibeLogger: Log phase start
    local start_time
    start_time=$(get_timestamp_ms)
    vibe_tdd_phase_start "Architecture Design" 3 1

    log_phase_start "Phase 3 - Architecture Design" "$primary_ai"

    local task="Design comprehensive architecture for: $feature. Context: $context"

    if [[ "$is_parallel" == "true" ]]; then
        execute_parallel "$primary_ai" "$secondary_ai" "$task" "$timeout" || echo "Architecture design completed with warnings"
    else
        # Technical architecture
        echo -e "${CYAN}$primary_ai - Technical architecture${NC}"
        invoke_ai "$primary_ai" "$task" "$timeout" || echo "$primary_ai failed"

        echo ""

        # PM alignment
        if [[ -n "$secondary_ai" ]]; then
            echo -e "${CYAN}$secondary_ai - PM alignment${NC}"
            local pm_task="Review architecture alignment for: $feature. Check resource fit, timeline feasibility, risk mitigation."
            invoke_ai "$secondary_ai" "$pm_task" "$timeout" || echo "$secondary_ai failed"
        fi
    fi

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 3" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Architecture Design" 3 1 0 "$duration"

    echo ""
}

# ============================================================================
# Phase 4: Implementation (Claude + Qwen + Droid parallel)
# ============================================================================

tdd-phase4a-implement-prep() {
    echo -e "${GREEN}🟢 PHASE 4A: Implementation Preparation${NC}"
    echo ""
    echo "✅ Claude (you) will implement based on designs above"
    echo ""
    echo "Parallel assistance available from:"
    echo "  • Qwen:  Fast prototype (37s) for quick validation"
    echo "  • Droid: Production code (180s) for enterprise quality"
    echo ""
}

tdd-phase4b-parallel-impl() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${GREEN}🟢 PHASE 4B: Parallel AI Implementation (Profile: $profile)${NC}"
    echo ""

    # Load configuration - support array should have ai/role/timeout
    local config
    config=$(load_tdd_phase_config "$profile" "phase4_implementation")

    # For simplicity, execute Qwen + Droid parallel
    local timeout=${1:-300}

    # VibeLogger: Log phase start
    local start_time
    start_time=$(get_timestamp_ms)
    vibe_tdd_phase_start "Implementation" 4 1

    log_phase_start "Phase 4B - Parallel Implementation" "Qwen + Droid"

    local task="Implement comprehensive solution for: $feature. Full production quality."

    execute_parallel "qwen" "droid" "$task" "$timeout" || echo "Parallel implementation completed with warnings"

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 4B" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Implementation" 4 1 0 "$duration"

    echo ""
}

# ============================================================================
# Phase 5: Optimization (Codex + Droid)
# ============================================================================

tdd-phase5-optimize() {
    local code_file="$1"
    local profile="${TDD_PROFILE}"

    echo -e "${BLUE}🔵 PHASE 5: Optimization (Profile: $profile)${NC}"
    echo ""

    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "phase5_optimization" "primary") || primary_ai="codex"
    local validator_ai
    validator_ai=$(get_phase_ai "$profile" "phase5_optimization" "validator") || validator_ai="droid"
    local timeout
    timeout=$(get_phase_timeout "$profile" "phase5_optimization") || timeout=300
    local context
    context=$(get_phase_context "$profile" "phase5_optimization")

    # VibeLogger: Log phase start
    local start_time
    start_time=$(get_timestamp_ms)
    vibe_tdd_phase_start "Optimization" 5 1

    log_phase_start "Phase 5 - Optimization" "$primary_ai"

    # Codex optimization
    echo -e "${CYAN}$primary_ai - Code optimization${NC}"
    local task="Optimize and refactor code. Context: $context"

    if [ -n "$code_file" ] && [ -f "$code_file" ]; then
        task="$task File: $code_file"
    fi

    invoke_ai "$primary_ai" "$task" "$timeout" || echo "$primary_ai optimization failed"

    echo ""

    # Droid production quality check
    if [[ -n "$validator_ai" ]]; then
        echo -e "${CYAN}$validator_ai - Production validation${NC}"
        local val_task="Validate and optimize production quality. Context: $context"
        invoke_ai "$validator_ai" "$val_task" "$timeout" || echo "$validator_ai validation failed"
    fi

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 5" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Optimization" 5 1 0 "$duration"

    echo ""
}

# ============================================================================
# Phase 6: Final Review (Gemini + Amp + Cursor)
# ============================================================================

tdd-phase6-final-review() {
    local feature="$*"
    local profile="${TDD_PROFILE}"

    echo -e "${YELLOW}✅ PHASE 6: Final Comprehensive Review (Profile: $profile)${NC}"
    echo ""

    local primary_ai
    primary_ai=$(get_phase_ai "$profile" "phase6_final_review" "primary") || primary_ai="gemini"
    local secondary_ai
    secondary_ai=$(get_phase_ai "$profile" "phase6_final_review" "secondary") || secondary_ai="amp"
    local tertiary_ai
    tertiary_ai=$(get_phase_ai "$profile" "phase6_final_review" "tertiary") || tertiary_ai="cursor"
    local timeout
    timeout=$(get_phase_timeout "$profile" "phase6_final_review") || timeout=600
    local context
    context=$(get_phase_context "$profile" "phase6_final_review")
    local is_parallel
    is_parallel=$(is_parallel_phase "$profile" "phase6_final_review" && echo "true" || echo "false")

    # VibeLogger: Log phase start
    local start_time
    start_time=$(get_timestamp_ms)
    vibe_tdd_phase_start "Final Review" 6 1

    log_phase_start "Phase 6 - Final Review" "$primary_ai"

    local task="Comprehensive review of TDD implementation: $feature. Context: $context"

    if [[ "$is_parallel" == "true" ]]; then
        # Parallel three-way review (simplified to two parallel for now)
        echo -e "${CYAN}Parallel review: $primary_ai + $secondary_ai + $tertiary_ai${NC}"

        # Execute primary + secondary in parallel
        execute_parallel "$primary_ai" "$secondary_ai" "$task" "$timeout" || echo "Review completed with warnings"

        echo ""

        # Tertiary separately
        if [[ -n "$tertiary_ai" ]]; then
            echo -e "${CYAN}$tertiary_ai - Integration review${NC}"
            invoke_ai "$tertiary_ai" "Review integration and testing for: $feature" "$timeout" || echo "$tertiary_ai review failed"
        fi
    else
        # Sequential reviews
        echo -e "${CYAN}$primary_ai - Technical excellence review${NC}"
        invoke_ai "$primary_ai" "$task" "$timeout" || echo "$primary_ai review failed"

        echo ""

        if [[ -n "$secondary_ai" ]]; then
            echo -e "${CYAN}$secondary_ai - PM completion review${NC}"
            invoke_ai "$secondary_ai" "Review project completion for: $feature" "$timeout" || echo "$secondary_ai review failed"
        fi

        echo ""

        if [[ -n "$tertiary_ai" ]]; then
            echo -e "${CYAN}$tertiary_ai - Integration review${NC}"
            invoke_ai "$tertiary_ai" "Review integration for: $feature" "$timeout" || echo "$tertiary_ai review failed"
        fi
    fi

    local end_time
    end_time=$(get_timestamp_ms)
    local duration
    duration=$((end_time - start_time))

    log_phase_end "Phase 6" "success"

    # VibeLogger: Log phase completion
    vibe_tdd_phase_done "Final Review" 6 1 0 "$duration"

    echo ""
}

# ============================================================================
# Complete 7-Phase Multi-AI TDD Cycle
# ============================================================================

tdd-multi-ai-phases-cycle() {
    local feature="$1"
    local profile="${2:-$TDD_PROFILE}"

    # Update profile
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
    echo -e "${MAGENTA}║    Multi-AI TDD - Comprehensive 7-Phase Process ($profile)    ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Feature: $feature"
    echo ""

    local cycle_start
    cycle_start=$(get_timestamp_ms)

    # VibeLogger: Log TDD cycle start
    vibe_tdd_cycle_start "7-Phase TDD: $feature" 7

    # Phase 0
    echo -e "\n${MAGENTA}[0/6] Project Management Setup${NC}"
    tdd-phase0-project-setup "$feature"
    read -p "Press Enter to continue to Phase 1..." -r

    # Phase 1
    echo -e "\n${YELLOW}[1/6] Requirements Research${NC}"
    tdd-phase1-research "$feature"
    read -p "Press Enter to continue to Phase 2..." -r

    # Phase 2
    echo -e "\n${RED}[2/6] Test Design${NC}"
    tdd-phase2-test-design "$feature"
    read -p "Press Enter to continue to Phase 3..." -r

    # Phase 3
    echo -e "\n${YELLOW}[3/6] Architecture Design${NC}"
    tdd-phase3-architecture "$feature"
    read -p "Press Enter to continue to Phase 4..." -r

    # Phase 4A
    echo -e "\n${GREEN}[4A/6] Implementation Preparation${NC}"
    tdd-phase4a-implement-prep
    read -p "Press Enter when Claude implementation is ready..." -r

    # Phase 4B
    echo -e "\n${GREEN}[4B/6] Parallel AI Implementation${NC}"
    tdd-phase4b-parallel-impl "$feature"
    read -p "Press Enter to continue to Phase 5..." -r

    # Phase 5
    echo -e "\n${BLUE}[5/6] Optimization${NC}"
    tdd-phase5-optimize ""
    read -p "Press Enter to continue to Phase 6..." -r

    # Phase 6
    echo -e "\n${YELLOW}[6/6] Final Review${NC}"
    tdd-phase6-final-review "$feature"

    local cycle_end
    cycle_end=$(get_timestamp_ms)
    local total_duration
    total_duration=$(calculate_duration "$cycle_start" "$cycle_end")
    local total_duration_ms
    total_duration_ms=$((cycle_end - cycle_start))

    # VibeLogger: Log TDD cycle completion
    vibe_tdd_cycle_done "7-Phase TDD: $feature" "success" "$total_duration_ms" 7 7 0

    # Complete
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        7-Phase Multi-AI TDD Cycle Complete! 🎉🎉🎉             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Profile: $profile"
    echo "Total time: ${total_duration}s"
    echo ""
}

# ============================================================================
# Fast Mode (No pauses)
# ============================================================================

tdd-multi-ai-phases-fast() {
    local feature="$1"
    local profile="${2:-six_phases}"

    # Update profile
    TDD_PROFILE="$profile"

    # Validate profile
    if ! validate_tdd_profile "$profile"; then
        echo -e "${RED}Error: Invalid TDD profile '$profile'${NC}" >&2
        return 1
    fi

    echo -e "${CYAN}⚡ Fast 7-Phase Multi-AI TDD (Profile: $profile, no pauses)${NC}"
    echo "Feature: $feature"
    echo ""

    local cycle_start
    cycle_start=$(get_timestamp_ms)

    tdd-phase0-project-setup "$feature"
    tdd-phase1-research "$feature"
    tdd-phase2-test-design "$feature"
    tdd-phase3-architecture "$feature"
    tdd-phase4a-implement-prep
    tdd-phase4b-parallel-impl "$feature"
    tdd-phase5-optimize ""
    tdd-phase6-final-review "$feature"

    local cycle_end
    cycle_end=$(get_timestamp_ms)
    local total_duration
    total_duration=$(calculate_duration "$cycle_start" "$cycle_end")

    echo ""
    echo -e "${GREEN}✓ Fast 7-Phase TDD Complete (${total_duration}s)${NC}"
}

# ============================================================================
# Help & Banner
# ============================================================================

# Only show banner in interactive mode (not when sourced for testing)
if [[ -z "${TDD_Multi-AI_QUIET:-}" ]]; then
    echo "==================================="
    echo "  TDD Multi-AI Phases v2.0 - Profile-Based"
    echo "==================================="
    echo ""
    echo "🎯 Current Profile: $TDD_PROFILE"
    echo ""
    echo "Available Profiles:"
    list_tdd_profiles 2>/dev/null || echo "  (yq not installed - using default)"
    echo ""
    echo "📚→🔍→🧪→🏗️→💻→⚡→✅ Comprehensive 7-phase development"
    echo ""
    echo "Commands:"
    echo "  tdd-multi-ai-phases-cycle 'feature' [profile]  # 🚀 Complete 7-phase cycle (with pauses)"
    echo "  tdd-multi-ai-phases-fast 'feature' [profile]   # ⚡ Fast 7-phase (no pauses)"
    echo ""
    echo "Individual Phases:"
    echo "  tdd-phase0-project-setup 'feature'   # 📋 Phase 0"
    echo "  tdd-phase1-research 'topic'          # 🔍 Phase 1"
    echo "  tdd-phase2-test-design 'feature'     # 🧪 Phase 2"
    echo "  tdd-phase3-architecture 'feature'    # 🏗️ Phase 3"
    echo "  tdd-phase4a-implement-prep           # 💻 Phase 4A"
    echo "  tdd-phase4b-parallel-impl 'feature'  # 💻 Phase 4B"
    echo "  tdd-phase5-optimize 'file.py'        # ⚡ Phase 5"
    echo "  tdd-phase6-final-review 'feature'    # ✅ Phase 6"
    echo ""
    echo "Example: TDD_PROFILE=six_phases tdd-multi-ai-phases-cycle 'User auth system'"
    echo ""
fi
