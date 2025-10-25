#!/usr/bin/env bash
# Multi-AI Orchestration Main Entry Point
# Version: 3.0 (Modular Architecture)
# Based on: Qwen vs Droid実証実験により7AI統合決定
# Reference: config/multi-ai-profiles.yaml
#
# This file is now a lightweight loader that sources modular libraries.
# All functionality has been moved to lib/ directory for better maintainability.

set -euo pipefail

# ============================================================================
# Library Detection and Loading
# ============================================================================

# Detect script directory
SCRIPT_DIR_TEMP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$SCRIPT_DIR_TEMP"
LIB_DIR="$SCRIPT_DIR/lib"

# Only set PROJECT_ROOT if not already defined (for testing flexibility)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
export PROJECT_ROOT

# Set PYTHONPATH to include project root
if [ -z "${PYTHONPATH:-}" ]; then
    export PYTHONPATH="$PROJECT_ROOT"
else
    export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"
fi

# ============================================================================
# Global Configuration
# ============================================================================

# Default profile
DEFAULT_PROFILE="balanced-multi-ai"
export DEFAULT_PROFILE

# Multi-AI構成
readonly AI_STRATEGIC="claude gemini amp"
readonly AI_IMPLEMENTATION="qwen droid codex"
readonly AI_INTEGRATION="cursor"
readonly ALL_AIS="claude gemini amp qwen droid codex cursor"
export AI_STRATEGIC AI_IMPLEMENTATION AI_INTEGRATION ALL_AIS

# Vibe Logger Setup
VIBE_LOG_DIR="$PROJECT_ROOT/logs/ai-coop/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR"
export VIBE_LOG_DIR

# ============================================================================
# Library Loading (Order is Important!)
# ============================================================================

# Load sanitization library for input validation
if [[ ! -f "$SCRIPT_DIR/../lib/sanitize.sh" ]]; then
    echo "ERROR: Required library not found: $SCRIPT_DIR/../lib/sanitize.sh" >&2
    exit 1
fi
# shellcheck source=scripts/lib/sanitize.sh
source "$SCRIPT_DIR/../lib/sanitize.sh"

# Load Multi-AI core utilities (logging, timestamps, VibeLogger, utilities)
if [[ ! -f "$LIB_DIR/multi-ai-core.sh" ]]; then
    echo "ERROR: Required library not found: $LIB_DIR/multi-ai-core.sh" >&2
    exit 1
fi
source "$LIB_DIR/multi-ai-core.sh"

# Load Multi-AI AI interface (AI availability, invocation, fallback)
if [[ ! -f "$LIB_DIR/multi-ai-ai-interface.sh" ]]; then
    echo "ERROR: Required library not found: $LIB_DIR/multi-ai-ai-interface.sh" >&2
    exit 1
fi
source "$LIB_DIR/multi-ai-ai-interface.sh"

# Load Multi-AI configuration (YAML profiles, workflow config, phase execution)
if [[ ! -f "$LIB_DIR/multi-ai-config.sh" ]]; then
    echo "ERROR: Required library not found: $LIB_DIR/multi-ai-config.sh" >&2
    exit 1
fi
source "$LIB_DIR/multi-ai-config.sh"

# Load Multi-AI workflows (all workflow implementations)
if [[ ! -f "$LIB_DIR/multi-ai-workflows.sh" ]]; then
    echo "ERROR: Required library not found: $LIB_DIR/multi-ai-workflows.sh" >&2
    exit 1
fi
source "$LIB_DIR/multi-ai-workflows.sh"

# ============================================================================
# AI CLI Version Compatibility Check (P1.3)
# ============================================================================

# check_ai_cli_versions()
# Validates that installed AI CLI versions meet minimum requirements
#
# Behavior:
#   - Loads minimum versions from config/ai-cli-versions.yaml
#   - Checks each AI CLI version using check_ai_version() from version-checker.sh
#   - Compares against minimum requirements using validate_version()
#   - Warns if incompatible versions detected (unless SKIP_VERSION_CHECK=1)
#
# Returns: 0 (always continues, warnings only)
check_ai_cli_versions() {
    # Check if version check should be skipped
    if [[ "${SKIP_VERSION_CHECK:-}" == "1" ]]; then
        log_info "Version check bypassed (SKIP_VERSION_CHECK=1)"
        return 0
    fi

    local version_yaml="$PROJECT_ROOT/config/ai-cli-versions.yaml"

    # Check if YAML file exists
    if [[ ! -f "$version_yaml" ]]; then
        log_warning "Version check skipped: $version_yaml not found"
        return 0
    fi

    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        log_warning "Version check skipped: yq not installed"
        return 0
    fi

    # Load version-checker module if not already loaded
    local version_checker="$PROJECT_ROOT/src/core/version-checker.sh"
    if [[ -f "$version_checker" ]]; then
        # shellcheck source=src/core/version-checker.sh
        source "$version_checker"
    else
        log_warning "Version check skipped: version-checker.sh not found"
        return 0
    fi

    local all_compatible=true
    local incompatible_count=0
    local checked_count=0

    # Check each AI tool version
    for ai in $ALL_AIS; do
        ((checked_count++))

        # Get minimum version from YAML
        local min_version
        min_version=$(yq eval ".minimum_versions.$ai" "$version_yaml" 2>/dev/null)

        # Skip if no minimum version defined
        if [[ -z "$min_version" ]] || [[ "$min_version" == "null" ]]; then
            continue
        fi

        # Get installed version
        local current_version
        if current_version=$(check_ai_version "$ai" 2>/dev/null); then
            # Validate version compatibility
            if validate_version "$ai" "$current_version" "$min_version"; then
                log_info "✅ $ai: $current_version (>= $min_version)"
            else
                log_warning "⚠️  $ai: $current_version < minimum $min_version"
                all_compatible=false
                ((incompatible_count++))
            fi
        else
            log_warning "⚠️  $ai: not installed (minimum $min_version required)"
            all_compatible=false
            ((incompatible_count++))
        fi
    done

    # Display summary
    if [[ "$all_compatible" == "true" ]]; then
        log_success "All $checked_count AI CLIs meet minimum version requirements"
    else
        log_warning "$incompatible_count/$checked_count AI CLIs have version issues"
        log_warning "Run: bash check-multi-ai-tools.sh for details"
        log_warning "To bypass: SKIP_VERSION_CHECK=1 source scripts/orchestrate/orchestrate-multi-ai.sh"
    fi

    return 0
}

# Execute version check on script load (not when sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${MULTI_AI_INIT:-}" != "test" ]]; then
    check_ai_cli_versions
fi

# ============================================================================
# Initialization Complete
# ============================================================================

# All functions are now loaded from modular libraries.
# Available functions:
#
# From multi-ai-core.sh (15 functions):
#   - log_info, log_success, log_warning, log_error, log_phase
#   - get_timestamp_ms
#   - vibe_log, vibe_pipeline_start, vibe_pipeline_done
#   - vibe_phase_start, vibe_phase_done, vibe_summary_done
#   - sanitize_input, run_with_timeout, show_multi_ai_banner
#
# From multi-ai-ai-interface.sh (5 functions):
#   - check_ai_available, check_ai_with_details
#   - call_ai, call_ai_with_fallback
#   - check-multi-ai-tools
#
# From multi-ai-config.sh (16 functions):
#   - load_multi_ai_profile, get_workflow_config
#   - get_phases, get_phase_info, get_phase_ai, get_phase_role, get_phase_timeout
#   - get_parallel_count, get_parallel_ai, get_parallel_role
#   - get_parallel_timeout, get_parallel_name, get_parallel_blocking
#   - execute_phase, execute_sequential_phase, execute_parallel_phase
#   - execute_yaml_workflow
#
# From multi-ai-workflows.sh (13 functions):
#   - multi-ai-full-orchestrate, multi-ai-speed-prototype, multi-ai-enterprise-quality
#   - multi-ai-hybrid-development, multi-ai-consensus-review
#   - multi-ai-chatdev-develop
#   - multi-ai-discuss-before, multi-ai-review-after
#   - multi-ai-coa-analyze
#   - multi-ai-code-review, multi-ai-coderabbit-review
#   - multi-ai-full-review, multi-ai-dual-review
#
# Total: 49 functions (reduced from 50 by consolidating duplicate show_multi_ai_banner)
