#!/usr/bin/env bash
# Multi-AI Discussion Workflows Library
# Purpose: Pre/post-implementation discussion workflows (P1.1.1.2)
# Responsibilities:
#   - discuss-before: Pre-implementation multi-perspective discussion
#   - review-after: Post-implementation comprehensive review
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging, utilities)
#   - lib/multi-ai-config.sh (execute_yaml_workflow)
#
# Usage:
#   source scripts/orchestrate/lib/workflows-discussion.sh

set -euo pipefail

# ============================================================================
# Implementation Process Functions (2 functions)
# ============================================================================

# Multi-AI Pre-Implementation Discussion
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-discuss-before() {
    local topic="$*"

    # P1-1: Input sanitization
    topic=$(sanitize_input "$topic") || return 1

    show_multi_ai_banner
    log_info "Topic: $topic"
    log_info "Profile: balanced-multi-ai (discuss-before workflow)"
    log_info "Mode: Multi-perspective analysis before implementation"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-discuss-before" "$topic"
}

# Multi-AI Post-Implementation Review
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-review-after() {
    local implementation="$*"

    # P1-1: Input sanitization
    implementation=$(sanitize_input "$implementation") || return 1

    show_multi_ai_banner
    log_info "Implementation: $implementation"
    log_info "Profile: balanced-multi-ai (review-after workflow)"
    log_info "Mode: Comprehensive post-implementation review"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-review-after" "$implementation"
}
