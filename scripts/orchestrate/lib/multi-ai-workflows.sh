#!/usr/bin/env bash
# Multi-AI Workflows Loader (P1.1.1 - Modularized)
# Purpose: Load all workflow modules for Multi-AI orchestration system
# Architecture:
#   - workflows-core.sh: Core workflows (full-orchestrate, speed-prototype, enterprise-quality, hybrid-development, consensus-review, chatdev-develop)
#   - workflows-discussion.sh: Discussion workflows (discuss-before, review-after)
#   - workflows-coa.sh: Chain-of-Agents workflow (coa-analyze)
#   - workflows-review.sh: Code review workflows (code-review, coderabbit-review, full-review, dual-review)
#
# Migration: v3.2 → v3.3 (P1.1.1)
#   - Before: 1952 lines monolithic file
#   - After: 4 modular files (~400-500 lines each)
#   - Benefits: Better maintainability, faster load times, clear organization
#
# Dependencies:
#   - lib/multi-ai-core.sh (must be sourced before this file)
#   - lib/multi-ai-ai-interface.sh (must be sourced before this file)
#   - lib/multi-ai-config.sh (must be sourced before this file)
#
# Usage:
#   source scripts/orchestrate/lib/multi-ai-workflows.sh

set -euo pipefail

# Get the directory of this script
WORKFLOWS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load workflow modules in dependency order
# Note: All modules depend on multi-ai-core.sh, multi-ai-ai-interface.sh, and multi-ai-config.sh
# which should already be sourced by orchestrate-multi-ai.sh

# Core Workflows (6 functions)
source "$WORKFLOWS_LIB_DIR/workflows-core.sh"

# Discussion Workflows (2 functions)
source "$WORKFLOWS_LIB_DIR/workflows-discussion.sh"

# Chain-of-Agents Workflow (1 function)
source "$WORKFLOWS_LIB_DIR/workflows-coa.sh"

# Code Review Workflows (4 functions)
source "$WORKFLOWS_LIB_DIR/workflows-review.sh"

# Quad Review Workflow (1 function)
source "$WORKFLOWS_LIB_DIR/workflows-review-quad.sh"

# Export all workflow functions (16 total)
# Core Workflows
export -f multi-ai-full-orchestrate
export -f multi-ai-speed-prototype
export -f multi-ai-enterprise-quality
export -f multi-ai-hybrid-development
export -f multi-ai-consensus-review
export -f multi-ai-chatdev-develop
export -f multi-ai-collaborative-planning
export -f multi-ai-collaborative-testing
export -f multi-ai-simple-fork-join

# Discussion Workflows
export -f multi-ai-discuss-before
export -f multi-ai-review-after

# Chain-of-Agents
export -f multi-ai-coa-analyze

# Code Review Workflows
export -f multi-ai-code-review
export -f multi-ai-coderabbit-review
export -f multi-ai-full-review
export -f multi-ai-dual-review

# Quad Review Workflow
export -f multi-ai-quad-review
