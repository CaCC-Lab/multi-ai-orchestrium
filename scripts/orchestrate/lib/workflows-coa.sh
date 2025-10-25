#!/usr/bin/env bash
# Multi-AI Chain-of-Agents Workflows Library
# Purpose: Chain-of-Agents analysis workflow (P1.1.1.3)
# Responsibilities:
#   - coa-analyze: Parallel worker analysis with manager synthesis
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging, utilities)
#   - lib/multi-ai-config.sh (execute_yaml_workflow)
#
# Usage:
#   source scripts/orchestrate/lib/workflows-coa.sh

set -euo pipefail

# ============================================================================
# Chain-of-Agents Functions (1 function)
# ============================================================================

# Multi-AI Chain of Agents Analysis
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-coa-analyze() {
    local document="$*"

    # P1-1: Input sanitization
    document=$(sanitize_input "$document") || return 1

    show_multi_ai_banner
    log_info "Document: $document"
    log_info "Profile: balanced-multi-ai (coa-analyze workflow)"
    log_info "Mode: Parallel worker analysis with manager synthesis"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-coa-analyze" "$document"
}
