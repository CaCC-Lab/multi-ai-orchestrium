# Contributing to 5AI Review Scripts

**Version**: 1.0.0
**Last Updated**: 2025-10-26

Thank you for your interest in contributing to Multi-AI Orchestrium's 5AI Review Scripts! This document provides guidelines for adding new AI review scripts, improving existing ones, and contributing to the testing and documentation infrastructure.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Adding a New AI Review Script](#adding-a-new-ai-review-script)
3. [Code Style Guidelines](#code-style-guidelines)
4. [Testing Guidelines](#testing-guidelines)
5. [Documentation Requirements](#documentation-requirements)
6. [Pull Request Process](#pull-request-process)
7. [Common Pitfalls](#common-pitfalls)

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

1. **Git**: Version 2.0 or higher
2. **Bash**: Version 4.0 or higher
3. **jq**: JSON parsing tool
4. **AI CLI Tools**: At least one AI CLI installed (gemini, qwen, cursor, amp, droid)
5. **Development Environment**: Linux, macOS, or WSL2

### Repository Setup

```bash
# Clone the repository
git clone https://github.com/your-org/multi-ai-orchestrium.git
cd multi-ai-orchestrium

# Create a feature branch
git checkout -b feature/add-codex-review

# Ensure all dependencies are available
bash check-multi-ai-tools.sh
```

### Familiarize Yourself with the Architecture

Read the following documents before starting:

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture and design patterns
- [FIVE_AI_REVIEW_GUIDE.md](FIVE_AI_REVIEW_GUIDE.md) - User-facing guide
- [CLAUDE.md](../CLAUDE.md) - Project-specific Claude Code guidance
- Existing review scripts (e.g., `scripts/qwen-review.sh`)

---

## Adding a New AI Review Script

This section provides a step-by-step guide to adding a new AI review script (e.g., `codex-review.sh`).

### Step 1: Create AI Wrapper Script

**File**: `bin/codex-wrapper.sh`

```bash
#!/bin/bash
# Codex AI Wrapper for Multi-AI Orchestrium
# Version: 1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load libraries
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
source "$PROJECT_ROOT/bin/agents-utils.sh"  # AGENTS.md task classification

# Configuration
CODEX_CLI="${CODEX_CLI:-codex}"
CODEX_TIMEOUT="${CODEX_TIMEOUT:-600}"
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

# Parse arguments
PROMPT=""
TIMEOUT="$CODEX_TIMEOUT"

while [[ $# -gt 0 ]]; do
    case $1 in
        --prompt) PROMPT="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --stdin) PROMPT=$(cat); shift ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Task classification (AGENTS.md)
TASK_TYPE=$(classify_task_from_agents_md "$PROMPT" "Codex")

# Dynamic timeout adjustment
case "$TASK_TYPE" in
    critical)
        TIMEOUT="${TIMEOUT:-900}"  # 15 minutes
        ;;
    standard)
        TIMEOUT="${TIMEOUT:-600}"  # 10 minutes
        ;;
    lightweight)
        TIMEOUT="${TIMEOUT:-300}"  # 5 minutes
        ;;
esac

# Approval prompt for critical tasks
if [[ "$TASK_TYPE" == "critical" && "$NON_INTERACTIVE" != "true" ]]; then
    echo "⚠️  This is a critical task that may take up to 15 minutes."
    echo "Prompt: ${PROMPT:0:100}..."
    read -p "Proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled by user."
        exit 1
    fi
fi

# VibeLogger: Wrapper start
START_MS=$(get_timestamp_ms)
vibe_wrapper_start "Codex" "$PROMPT" "$TIMEOUT"

# Execute Codex CLI
TEMP_OUTPUT=$(mktemp -t codex-output-XXXXXX)
trap "rm -f '$TEMP_OUTPUT'" EXIT INT TERM

EXIT_CODE=0
timeout "${TIMEOUT}s" "$CODEX_CLI" exec --prompt "$PROMPT" > "$TEMP_OUTPUT" 2>&1 || EXIT_CODE=$?

# VibeLogger: Wrapper done
END_MS=$(get_timestamp_ms)
DURATION_MS=$((END_MS - START_MS))
vibe_wrapper_done "Codex" "$([[ $EXIT_CODE -eq 0 ]] && echo 'success' || echo 'failure')" "$DURATION_MS" "$EXIT_CODE"

# Output result
cat "$TEMP_OUTPUT"
exit $EXIT_CODE
```

**Key Components**:
- Task classification using `AGENTS.md`
- Dynamic timeout adjustment
- Approval prompts for critical tasks
- VibeLogger integration
- Secure temp file handling

### Step 2: Update AGENTS.md

**File**: `AGENTS.md` (add Codex section)

```markdown
## Codex

**Specialization**: Complex problem solving, debugging, error reduction
**Strengths**: Algorithm optimization, bug detection, code correctness
**HumanEval Score**: 89.2% (high accuracy)

**Task Classification**:

### Critical Tasks (900s timeout, approval required)
- Large-scale refactoring (>500 lines)
- Production bug fixes (security, data loss, performance)
- Mission-critical algorithm optimization

### Standard Tasks (600s timeout)
- Code review and optimization suggestions
- Bug detection and diagnosis
- Algorithm correctness verification
- Unit test generation

### Lightweight Tasks (300s timeout)
- Simple bug fixes (<50 lines)
- Code formatting and style checks
- Documentation typo fixes
```

### Step 3: Create Review Script

**File**: `scripts/codex-review.sh`

**Template**:

```bash
#!/bin/bash
# Codex Code Review Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Codex code review with REVIEW-PROMPT.md guidance
# Specialization: Complex problem solving, debugging, error reduction (HumanEval 89.2%)

set -euo pipefail

# ======================================
# 1. Configuration
# ======================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Vibe Logger Setup
export VIBE_LOG_DIR="$PROJECT_ROOT/logs/vibe/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR"

# Load libraries
source "$SCRIPT_DIR/lib/sanitize.sh"
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"

# Default configuration
CODEX_REVIEW_TIMEOUT=${CODEX_REVIEW_TIMEOUT:-600}  # 10 minutes
OUTPUT_DIR="${OUTPUT_DIR:-logs/codex-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"
FOCUS_AREA="${FOCUS_AREA:-debugging}"  # debugging | optimization | correctness
mkdir -p "$OUTPUT_DIR"

# Load REVIEW-PROMPT.md
REVIEW_PROMPT_FILE="$PROJECT_ROOT/REVIEW-PROMPT.md"
if [[ ! -f "$REVIEW_PROMPT_FILE" ]]; then
    echo "❌ REVIEW-PROMPT.md not found: $REVIEW_PROMPT_FILE"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ======================================
# 2. Utility Functions
# ======================================

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

get_timestamp_ms() {
    local ts
    ts=$(date +%s%3N 2>/dev/null)
    if [[ "$ts" == *"%"* ]]; then
        echo "$(date +%s)000"
    else
        echo "$ts"
    fi
}

# ======================================
# 3. VibeLogger Functions
# ======================================

vibe_log() {
    local event_type="$1"
    local action="$2"
    local metadata="$3"
    local human_note="$4"
    local ai_todo="${5:-}"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="codex_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/codex_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Codex",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "Complex Problem Solving, Debugging, Error Reduction (HumanEval 89.2%)",
    "todo": "$ai_todo"
  }
}
EOF
}

vibe_tool_start() {
    local tool="$1"
    local commit="$2"
    local timeout="$3"
    local focus="$4"

    vibe_log "tool_execution" "start" \
        "{\"tool\": \"$tool\", \"commit\": \"$commit\", \"timeout\": $timeout, \"focus_area\": \"$focus\"}" \
        "Starting $tool code review for commit $commit with focus on $focus" \
        "analyze code, detect bugs, optimize algorithms"
}

vibe_tool_done() {
    local tool="$1"
    local status="$2"
    local duration_ms="$3"
    local exit_code="$4"
    local findings_count="${5:-0}"

    vibe_log "tool_execution" "done" \
        "{\"tool\": \"$tool\", \"status\": \"$status\", \"duration_ms\": $duration_ms, \"exit_code\": $exit_code, \"findings_count\": $findings_count}" \
        "$tool review completed with status $status ($findings_count findings)" \
        ""
}

# Custom Codex-specific function
vibe_debugging_analysis() {
    local commit="$1"
    local bug_count="$2"
    local complexity="$3"

    vibe_log "codex_debugging" "analysis" \
        "{\"commit\": \"$commit\", \"bug_count\": $bug_count, \"complexity\": $complexity}" \
        "Codex detected $bug_count potential bugs with average complexity $complexity" \
        "review bugs, prioritize fixes, verify correctness"
}

# ======================================
# 4. Help Message
# ======================================

show_help() {
    cat << EOF
Codex Code Review Script - Multi-AI対応 VibeLogger統合版

USAGE:
    bash $0 [OPTIONS]

OPTIONS:
    --timeout SECONDS     Review timeout in seconds (default: 600)
    --commit HASH         Git commit hash to review (default: HEAD)
    --output PATH         Output directory (default: logs/codex-reviews)
    --focus AREA          Focus area (debugging | optimization | correctness)
    --help                Show this help message

FOCUS AREAS:
    debugging             Focus on bug detection and diagnosis (default)
    optimization          Focus on algorithm optimization and performance
    correctness           Focus on code correctness and logical errors

EXAMPLES:
    # Review latest commit with default settings
    bash $0

    # Review specific commit with debugging focus
    bash $0 --commit abc123 --focus debugging

    # Long timeout for complex analysis
    bash $0 --timeout 900 --focus optimization

SPECIALIZATION:
    Codex specializes in complex problem solving, debugging, and error reduction.
    HumanEval Score: 89.2% (high accuracy)

OUTPUT:
    - JSON report: logs/codex-reviews/{timestamp}_{commit}_codex.json
    - Markdown report: logs/codex-reviews/{timestamp}_{commit}_codex.md
    - VibeLogger logs: logs/vibe/{YYYYMMDD}/codex_review_{HH}.jsonl
    - Symlinks: logs/codex-reviews/latest_codex.{json,md}

EOF
}

# ======================================
# 5. CLI Argument Parsing
# ======================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            CODEX_REVIEW_TIMEOUT="$2"
            shift 2
            ;;
        --commit)
            COMMIT_HASH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --focus)
            FOCUS_AREA="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ======================================
# 6. Prerequisites Check
# ======================================

log_info "Checking prerequisites..."

# Check codex-wrapper.sh
if [[ ! -x "$PROJECT_ROOT/bin/codex-wrapper.sh" ]]; then
    log_error "codex-wrapper.sh not found or not executable: $PROJECT_ROOT/bin/codex-wrapper.sh"
    exit 1
fi

# Check git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not a git repository"
    exit 1
fi

# Verify commit existence
if ! git rev-parse --verify "$COMMIT_HASH" > /dev/null 2>&1; then
    log_error "Commit $COMMIT_HASH not found"
    exit 1
fi

# Validate focus area
case "$FOCUS_AREA" in
    debugging|optimization|correctness)
        ;;
    *)
        log_error "Invalid focus area: $FOCUS_AREA (must be: debugging, optimization, correctness)"
        exit 1
        ;;
esac

log_success "Prerequisites check passed"

# ======================================
# 7. Review Prompt Generation
# ======================================

log_info "Generating review prompt for commit $COMMIT_HASH (focus: $FOCUS_AREA)..."

# Load base prompt
BASE_PROMPT=$(cat "$REVIEW_PROMPT_FILE")

# Extract commit diff
COMMIT_DIFF=$(git show "$COMMIT_HASH" --format=fuller --stat --patch)

# Sanitize inputs
SANITIZED_COMMIT=$(sanitize_input "$COMMIT_HASH" 40)
SANITIZED_FOCUS=$(sanitize_input "$FOCUS_AREA" 50)

# Focus-specific instructions
case "$FOCUS_AREA" in
    debugging)
        FOCUS_INSTRUCTIONS="Focus on detecting bugs, logical errors, edge cases, and potential runtime failures. Prioritize correctness over style."
        ;;
    optimization)
        FOCUS_INSTRUCTIONS="Focus on algorithm efficiency, performance bottlenecks, and optimization opportunities. Suggest faster alternatives where applicable."
        ;;
    correctness)
        FOCUS_INSTRUCTIONS="Focus on code correctness, logical consistency, and adherence to specifications. Verify that the implementation matches intended behavior."
        ;;
esac

# Create full prompt
FULL_PROMPT=$(cat << EOF
$BASE_PROMPT

---

# AI-Specific Context

**AI**: Codex
**Specialization**: Complex Problem Solving, Debugging, Error Reduction (HumanEval 89.2%)
**Focus Area**: $FOCUS_AREA

$FOCUS_INSTRUCTIONS

# Commit Diff

$COMMIT_DIFF

# Review Instructions

Please review the above commit diff and provide:

1. **Bug Detection**: Identify potential bugs, logical errors, and edge cases
2. **Algorithm Analysis**: Evaluate algorithm correctness and efficiency
3. **Error Handling**: Check for missing error handling and exception cases
4. **Code Correctness**: Verify that code matches intended behavior

For each finding, provide:
- **ID**: Unique identifier (e.g., CX-001)
- **Title**: Brief summary of the issue
- **Severity**: Critical | High | Medium | Low
- **Priority**: P0 | P1 | P2 | P3
- **Confidence**: 0.0-1.0 (how confident are you this is an issue?)
- **Category**: Bug | Performance | Correctness | Error Handling
- **Description**: Detailed explanation
- **Recommendation**: Specific action to resolve the issue
- **Code Snippet**: Relevant code excerpt (if applicable)

Output format: JSON

{
  "findings": [
    {
      "id": "CX-001",
      "title": "...",
      "severity": "High",
      "priority": "P1",
      "confidence": 0.95,
      "file": "src/file.ts",
      "line": 42,
      "category": "Bug",
      "description": "...",
      "recommendation": "...",
      "code_snippet": "...",
      "tags": ["bug", "edge-case"]
    }
  ],
  "metrics": {
    "bug_count": 3,
    "average_complexity": 8,
    "correctness_score": 85
  }
}
EOF
)

# ======================================
# 8. AI Wrapper Execution
# ======================================

log_info "Executing Codex wrapper (timeout: ${CODEX_REVIEW_TIMEOUT}s)..."

# Create secure temp file
TEMP_PROMPT_FILE=$(mktemp -t prompt-codex-XXXXXX)
chmod 600 "$TEMP_PROMPT_FILE"
echo "$FULL_PROMPT" > "$TEMP_PROMPT_FILE"

# Cleanup trap
trap "rm -f '$TEMP_PROMPT_FILE'" EXIT INT TERM

# VibeLogger: Tool start
START_MS=$(get_timestamp_ms)
vibe_tool_start "Codex" "$SANITIZED_COMMIT" "$CODEX_REVIEW_TIMEOUT" "$SANITIZED_FOCUS"

# Execute wrapper
TEMP_OUTPUT=$(mktemp -t codex-output-XXXXXX)
EXIT_CODE=0
"$PROJECT_ROOT/bin/codex-wrapper.sh" --timeout "$CODEX_REVIEW_TIMEOUT" < "$TEMP_PROMPT_FILE" > "$TEMP_OUTPUT" 2>&1 || EXIT_CODE=$?

# Calculate duration
END_MS=$(get_timestamp_ms)
DURATION_MS=$((END_MS - START_MS))

# ======================================
# 9. Output Parsing and Generation
# ======================================

log_info "Parsing Codex output..."

CODEX_OUTPUT=$(cat "$TEMP_OUTPUT")

# Detect JSON vs plain text
if echo "$CODEX_OUTPUT" | jq empty 2>/dev/null; then
    log_success "Valid JSON output detected"
    FINDINGS_JSON="$CODEX_OUTPUT"
else
    log_warning "Non-JSON output detected, wrapping in JSON structure"
    FINDINGS_JSON=$(cat << EOF
{
  "findings": [],
  "metrics": {
    "bug_count": 0,
    "average_complexity": 0,
    "correctness_score": 0
  },
  "raw_output": $(echo "$CODEX_OUTPUT" | jq -Rs .)
}
EOF
)
fi

# Extract metrics
FINDINGS_COUNT=$(echo "$FINDINGS_JSON" | jq '.findings | length' 2>/dev/null || echo "0")
BUG_COUNT=$(echo "$FINDINGS_JSON" | jq -r '.metrics.bug_count // 0' 2>/dev/null || echo "0")
AVG_COMPLEXITY=$(echo "$FINDINGS_JSON" | jq -r '.metrics.average_complexity // 0' 2>/dev/null || echo "0")
CORRECTNESS_SCORE=$(echo "$FINDINGS_JSON" | jq -r '.metrics.correctness_score // 0' 2>/dev/null || echo "0")

# VibeLogger: Tool done
vibe_tool_done "Codex" "$([[ $EXIT_CODE -eq 0 ]] && echo 'success' || echo 'failure')" "$DURATION_MS" "$EXIT_CODE" "$FINDINGS_COUNT"

# VibeLogger: Custom debugging analysis
vibe_debugging_analysis "$SANITIZED_COMMIT" "$BUG_COUNT" "$AVG_COMPLEXITY"

# Generate output files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JSON_OUTPUT="$OUTPUT_DIR/${TIMESTAMP}_${SANITIZED_COMMIT}_codex.json"
MD_OUTPUT="$OUTPUT_DIR/${TIMESTAMP}_${SANITIZED_COMMIT}_codex.md"

# Create JSON report
cat > "$JSON_OUTPUT" << EOF
{
  "review_metadata": {
    "ai": "codex",
    "version": "1.0.0",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "commit": "$SANITIZED_COMMIT",
    "timeout": $CODEX_REVIEW_TIMEOUT,
    "focus_area": "$SANITIZED_FOCUS",
    "duration_ms": $DURATION_MS,
    "exit_code": $EXIT_CODE
  },
  "summary": {
    "total_findings": $FINDINGS_COUNT,
    "bug_count": $BUG_COUNT,
    "average_complexity": $AVG_COMPLEXITY,
    "correctness_score": $CORRECTNESS_SCORE
  },
  "findings": $(echo "$FINDINGS_JSON" | jq '.findings // []')
}
EOF

# Create Markdown report
cat > "$MD_OUTPUT" << 'MARKDOWN_EOF'
# Codex Code Review Report

**Commit**: {COMMIT}
**Date**: {DATE}
**Reviewer**: Codex (Complex Problem Solving, Debugging, Error Reduction - HumanEval 89.2%)
**Duration**: {DURATION}s
**Focus Area**: {FOCUS_AREA}

---

## Executive Summary

- **Total Findings**: {FINDINGS_COUNT}
- **Bug Count**: {BUG_COUNT}
- **Average Complexity**: {AVG_COMPLEXITY}
- **Correctness Score**: {CORRECTNESS_SCORE}/100
- **Exit Code**: {EXIT_CODE}

---

## Findings

{FINDINGS_MARKDOWN}

---

## Metrics

- **Bug Count**: {BUG_COUNT}
- **Average Complexity**: {AVG_COMPLEXITY} (0=Simple, 10=Complex)
- **Correctness Score**: {CORRECTNESS_SCORE}/100

---

## Review Details

- **AI**: Codex
- **Version**: 1.0.0
- **Timeout**: {TIMEOUT}s
- **Exit Code**: {EXIT_CODE}

MARKDOWN_EOF

# Replace placeholders in Markdown
sed -i "s/{COMMIT}/$SANITIZED_COMMIT/g" "$MD_OUTPUT"
sed -i "s/{DATE}/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" "$MD_OUTPUT"
sed -i "s/{DURATION}/$((DURATION_MS / 1000))/g" "$MD_OUTPUT"
sed -i "s/{FOCUS_AREA}/$SANITIZED_FOCUS/g" "$MD_OUTPUT"
sed -i "s/{FINDINGS_COUNT}/$FINDINGS_COUNT/g" "$MD_OUTPUT"
sed -i "s/{BUG_COUNT}/$BUG_COUNT/g" "$MD_OUTPUT"
sed -i "s/{AVG_COMPLEXITY}/$AVG_COMPLEXITY/g" "$MD_OUTPUT"
sed -i "s/{CORRECTNESS_SCORE}/$CORRECTNESS_SCORE/g" "$MD_OUTPUT"
sed -i "s/{TIMEOUT}/$CODEX_REVIEW_TIMEOUT/g" "$MD_OUTPUT"
sed -i "s/{EXIT_CODE}/$EXIT_CODE/g" "$MD_OUTPUT"

# Generate findings markdown
FINDINGS_MD=""
if [[ "$FINDINGS_COUNT" -gt 0 ]]; then
    FINDINGS_MD=$(echo "$FINDINGS_JSON" | jq -r '.findings[] | "### \(.severity) - \(.title)\n\n**File**: `\(.file):\(.line)`\n**Category**: \(.category)\n**Confidence**: \(.confidence)\n\n\(.description)\n\n**Recommendation**: \(.recommendation)\n\n```\n\(.code_snippet // "N/A")\n```\n\n---\n"')
else
    FINDINGS_MD="No findings detected."
fi

sed -i "s#{FINDINGS_MARKDOWN}#$FINDINGS_MD#g" "$MD_OUTPUT"

# Create symlinks
ln -sf "$JSON_OUTPUT" "$OUTPUT_DIR/latest_codex.json"
ln -sf "$MD_OUTPUT" "$OUTPUT_DIR/latest_codex.md"

# ======================================
# 10. Cleanup and Exit
# ======================================

log_success "Codex review completed"
log_info "JSON report: $JSON_OUTPUT"
log_info "Markdown report: $MD_OUTPUT"
log_info "VibeLogger logs: $VIBE_LOG_DIR/codex_review_$(date +%H).jsonl"

exit $EXIT_CODE
```

**Key Customizations**:
- `FOCUS_AREA`: debugging | optimization | correctness
- `vibe_debugging_analysis()`: Custom Codex-specific VibeLogger function
- Focus-specific prompt instructions
- Codex-specific metrics (bug_count, average_complexity, correctness_score)

### Step 4: Create Test Suite

**File**: `tests/test-codex-review.sh`

Follow the pattern from `tests/test-qwen-review.sh`:

```bash
#!/bin/bash
# Test Suite for codex-review.sh
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load test helpers
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Test counter
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# ======================================
# Test Cases
# ======================================

# 1. Normal Cases (Happy Path)
test_codex_review_default_commit() {
    log_test "codex-review.sh with default commit (HEAD)"

    # Given: Default configuration
    # When: Execute with no arguments
    local output=$(bash "$PROJECT_ROOT/scripts/codex-review.sh" --timeout 60 2>&1)
    local exit_code=$?

    # Then: Should succeed (or timeout gracefully)
    if [[ $exit_code -eq 0 || $exit_code -eq 2 ]]; then
        pass "Default commit review executed"
    else
        fail "Default commit review failed with exit code $exit_code"
    fi
}

# ... (26 total test cases following the pattern from test-qwen-review.sh)

# ======================================
# Run Tests
# ======================================

run_all_tests() {
    log_section "Running Codex Review Tests"

    # Normal cases
    test_codex_review_default_commit
    test_codex_review_specific_commit
    test_codex_review_focus_debugging
    test_codex_review_focus_optimization
    test_codex_review_focus_correctness

    # Abnormal cases
    test_codex_review_invalid_focus
    test_codex_review_wrapper_not_found
    test_codex_review_timeout

    # Boundary values
    test_codex_review_minimum_timeout
    test_codex_review_empty_commit

    # Invalid inputs
    test_codex_review_nonexistent_commit
    test_codex_review_invalid_timeout

    # ... (more test cases)

    # Summary
    log_section "Test Summary"
    echo "Total: $TEST_COUNT | Pass: $PASS_COUNT | Fail: $FAIL_COUNT"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

run_all_tests
```

### Step 5: Create Documentation

**File**: `docs/reviews/codex-review-guide.md`

Follow the pattern from `docs/reviews/qwen-review-guide.md`:

```markdown
# Codex Review Guide

**AI**: Codex
**Specialization**: Complex Problem Solving, Debugging, Error Reduction
**HumanEval Score**: 89.2%

## Overview

[... follow the structure from qwen-review-guide.md ...]

## Core Capabilities

- Bug detection and diagnosis
- Algorithm correctness verification
- Error handling analysis
- Edge case identification

## When to Use

- Production bug fixes
- Complex algorithm implementation
- Mission-critical code review
- Error reduction initiatives

[... continue with remaining sections ...]
```

### Step 6: Update Integration Scripts

**File**: `scripts/multi-ai-review.sh`

```bash
# Add Codex option
case "$TYPE" in
    codex)
        log_info "Running Codex review..."
        bash "$SCRIPT_DIR/codex-review.sh" --commit "$COMMIT" --timeout "$TIMEOUT"
        ;;
    all)
        log_info "Running all AI reviews in parallel..."
        bash "$SCRIPT_DIR/gemini-review.sh" --commit "$COMMIT" &
        bash "$SCRIPT_DIR/qwen-review.sh" --commit "$COMMIT" &
        bash "$SCRIPT_DIR/cursor-review.sh" --commit "$COMMIT" &
        bash "$SCRIPT_DIR/amp-review.sh" --commit "$COMMIT" &
        bash "$SCRIPT_DIR/droid-review.sh" --commit "$COMMIT" &
        bash "$SCRIPT_DIR/codex-review.sh" --commit "$COMMIT" &  # NEW
        wait
        ;;
esac
```

### Step 7: Update Documentation

Update the following files:

1. **CLAUDE.md**: Add Codex to the 5AI review scripts section
2. **FIVE_AI_REVIEW_GUIDE.md**: Add Codex to the AI comparison table
3. **Implementation Plan**: Add Task 1.6 for codex-review.sh

---

## Code Style Guidelines

### Bash Scripting Standards

#### 1. Shebang and Safety Flags

```bash
#!/bin/bash
set -euo pipefail
```

- **`set -e`**: Exit on error
- **`set -u`**: Exit on undefined variable
- **`set -o pipefail`**: Propagate pipeline errors

#### 2. Variable Naming

```bash
# Constants: UPPER_SNAKE_CASE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEFAULT_TIMEOUT=600

# Variables: lower_snake_case
commit_hash="abc123"
findings_count=5
output_file="report.json"

# Environment variables: UPPER_SNAKE_CASE (with prefix)
QWEN_REVIEW_TIMEOUT=${QWEN_REVIEW_TIMEOUT:-600}
```

#### 3. Function Naming

```bash
# Utility functions: snake_case
log_error() { ... }
get_timestamp_ms() { ... }
sanitize_input() { ... }

# VibeLogger functions: vibe_* prefix
vibe_log() { ... }
vibe_tool_start() { ... }
vibe_code_quality_analysis() { ... }  # AI-specific
```

#### 4. Quoting

```bash
# Always quote variables
echo "$variable"

# Quote command substitution
commit=$(git rev-parse HEAD)
echo "$commit"

# Quote file paths
source "$SCRIPT_DIR/lib/sanitize.sh"
```

#### 5. Conditional Expressions

```bash
# Use [[ ]] for conditions (not [ ])
if [[ "$variable" == "value" ]]; then
    ...
fi

# Prefer -z/-n for string checks
if [[ -z "$string" ]]; then  # Empty string
    ...
fi

if [[ -n "$string" ]]; then  # Non-empty string
    ...
fi

# Use (( )) for arithmetic
if (( count > 0 )); then
    ...
fi
```

#### 6. Error Handling

```bash
# Check command success
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not a git repository"
    exit 1
fi

# Use trap for cleanup
TEMP_FILE=$(mktemp)
trap "rm -f '$TEMP_FILE'" EXIT INT TERM

# Capture exit codes
EXIT_CODE=0
some_command || EXIT_CODE=$?
```

#### 7. Comments

```bash
# ======================================
# Section Header (80 chars with =)
# ======================================

# Single-line comment for brief explanations
some_command  # Inline comment

# Multi-line comment for complex logic:
# This function performs X by doing Y.
# It handles edge cases A, B, and C.
# Returns 0 on success, 1 on failure.
function_name() {
    ...
}
```

#### 8. Function Documentation

For complex or public functions, use structured documentation:

```bash
# ------------------------------------------------------------------------------
# Function: sanitize_input
# Description: Sanitizes user input to prevent command injection and validate format
#
# Arguments:
#   $1 - input: The raw user input string
#   $2 - max_length: Maximum allowed length (default: 100000)
#
# Returns:
#   0 on success (outputs sanitized string to stdout)
#   1 on failure (outputs error message to stderr)
#
# Security:
#   - Prevents command injection (backticks, $(...), etc.)
#   - Blocks path traversal (../, absolute paths)
#   - Enforces length limits
#
# Examples:
#   sanitized=$(sanitize_input "$user_input" 1000)
#   sanitize_input "$commit_hash" 40 || exit 1
# ------------------------------------------------------------------------------
sanitize_input() {
    local input="$1"
    local max_length="${2:-100000}"

    # Validation logic...
}

# ------------------------------------------------------------------------------
# Function: vibe_code_quality_analysis
# Description: Logs Qwen code quality analysis events to VibeLogger
#
# Arguments:
#   $1 - commit: Git commit hash being analyzed
#   $2 - quality_score: Code quality score (0-100)
#   $3 - pattern_count: Number of design patterns detected
#
# Returns:
#   None (logs to VibeLogger JSONL file)
#
# Output:
#   Appends JSONL event to logs/vibe/YYYYMMDD/qwen_review_HH.jsonl
#
# Examples:
#   vibe_code_quality_analysis "$commit" 85 12
# ------------------------------------------------------------------------------
vibe_code_quality_analysis() {
    local commit="$1"
    local quality_score="$2"
    local pattern_count="$3"

    vibe_log "qwen_analysis" "code_quality" \
        "{\"commit\": \"$commit\", \"quality_score\": $quality_score, \"pattern_count\": $pattern_count}" \
        "Qwen detected $pattern_count design patterns with quality score $quality_score" \
        "review patterns, refactor code, improve quality"
}
```

**When to Add Function Documentation**:
- Complex algorithms or logic
- Public API functions (used by other scripts)
- VibeLogger custom functions (AI-specific)
- Security-sensitive functions
- Functions with non-obvious behavior

**When NOT to Add Function Documentation**:
- Simple utility functions (self-explanatory)
- Private/internal helper functions
- One-line wrapper functions

#### 8. Heredocs

```bash
# Use heredocs for multi-line strings
cat << EOF
Line 1
Line 2
Line 3
EOF

# Quote delimiter to prevent variable expansion
cat << 'EOF'
$variable will not be expanded
EOF

# Indent heredoc content
cat << EOF
    Indented line 1
    Indented line 2
EOF
```

### JSON/Markdown Generation

#### JSON

```bash
# Use jq for JSON generation when possible
jq -n --arg commit "$COMMIT" --argjson count "$COUNT" '{
  commit: $commit,
  findings_count: $count
}'

# For complex structures, use cat with heredoc
cat > output.json << EOF
{
  "key": "value",
  "nested": {
    "array": [1, 2, 3]
  }
}
EOF
```

#### Markdown

```bash
# Use cat with heredoc for Markdown generation
cat > report.md << 'EOF'
# Title

## Section

- List item 1
- List item 2

EOF

# Replace placeholders with sed
sed -i "s/{PLACEHOLDER}/$value/g" report.md
```

---

## Testing Guidelines

### Test Organization

Every test file must follow this structure:

```bash
#!/bin/bash
# Test Suite for [script-name].sh
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load test helpers
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Test counter
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# ======================================
# Test Cases
# ======================================

# 1. Normal Cases (20% of tests)
test_normal_case_1() { ... }
test_normal_case_2() { ... }

# 2. Abnormal Cases (40% of tests)
test_abnormal_case_1() { ... }
test_abnormal_case_2() { ... }

# 3. Boundary Values (20% of tests)
test_boundary_case_1() { ... }
test_boundary_case_2() { ... }

# 4. Invalid Inputs (10% of tests)
test_invalid_input_1() { ... }
test_invalid_input_2() { ... }

# 5. External Dependencies (10% of tests)
test_wrapper_failure() { ... }
test_timeout() { ... }

# ======================================
# Run Tests
# ======================================

run_all_tests() {
    log_section "Running [AI] Review Tests"

    # Run all test functions
    test_normal_case_1
    test_normal_case_2
    # ...

    # Summary
    log_section "Test Summary"
    echo "Total: $TEST_COUNT | Pass: $PASS_COUNT | Fail: $FAIL_COUNT"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

run_all_tests
```

### Test Case Structure

Every test must use Given/When/Then:

```bash
test_function_name() {
    log_test "Description of what this test verifies"

    # Given: Initial state
    local commit="abc123"
    local timeout=600

    # When: Action performed
    local result=$(execute_review "$commit" "$timeout")
    local exit_code=$?

    # Then: Expected outcome
    if [[ $exit_code -eq 0 ]]; then
        pass "Review succeeded as expected"
    else
        fail "Review failed with exit code $exit_code"
    fi
}
```

### Test Coverage Requirements

- **Minimum Coverage**: 70% branch coverage (production-ready)
- **Target Coverage**: 100% branch coverage (ideal)
- **Priority 0/P1**: 100% coverage required
- **Priority 2/P3**: 70% coverage acceptable

### Running Tests

```bash
# Run all tests for all review scripts
bash tests/run-all-review-tests.sh

# Run tests for specific script
bash tests/test-codex-review.sh

# Run with verbose output
bash tests/run-all-review-tests.sh --verbose

# Generate coverage report (basic)
bash tests/run-all-review-tests.sh --coverage
```

---

## Documentation Requirements

### User Documentation

For each new AI review script, create:

1. **Individual Guide** (`docs/reviews/[ai]-review-guide.md`)
   - Overview
   - Core Capabilities
   - When to Use
   - Installation & Prerequisites
   - Basic Usage
   - Command-Line Options
   - Focus Areas (if applicable)
   - Output Formats
   - Interpreting Results
   - Common Use Cases
   - Workflow Integration
   - Best Practices
   - Troubleshooting
   - Related Documentation
   - Appendix (AI comparison, strengths/weaknesses)

2. **Update Existing Guides**
   - CLAUDE.md: Add to 5AI review scripts section
   - FIVE_AI_REVIEW_GUIDE.md: Add to AI comparison table and usage examples

### Developer Documentation

Update the following:

1. **ARCHITECTURE.md**: Add AI to component diagrams and data flow
2. **CONTRIBUTING.md**: Add AI-specific customization examples (this file)
3. **Implementation Plan**: Add task for the new AI script

### Inline Code Documentation

Add comments for:

- Complex logic or algorithms
- Non-obvious variable names
- Security-sensitive code sections
- VibeLogger custom functions
- Focus area customizations

Example:

```bash
# Calculate maintainability index using Halstead complexity
# Formula: MI = MAX(0, (171 - 5.2 * ln(V) - 0.23 * G - 16.2 * ln(LOC)) * 100 / 171)
# Where V = Halstead volume, G = cyclomatic complexity, LOC = lines of code
calculate_maintainability_index() {
    local halstead_volume="$1"
    local cyclomatic_complexity="$2"
    local loc="$3"

    # ... implementation ...
}
```

---

## Pull Request Process

### Before Submitting

1. **Run all tests**: Ensure 100% of tests pass
   ```bash
   bash tests/run-all-review-tests.sh
   ```

2. **Verify code style**: Follow Bash scripting standards
   ```bash
   shellcheck scripts/[ai]-review.sh
   ```

3. **Test manually**: Run the script with real commits
   ```bash
   bash scripts/[ai]-review.sh --commit HEAD
   ```

4. **Update documentation**: Ensure all docs are up-to-date

5. **Review checklist**:
   - [ ] Wrapper script created (`bin/[ai]-wrapper.sh`)
   - [ ] Review script created (`scripts/[ai]-review.sh`)
   - [ ] Test suite created (`tests/test-[ai]-review.sh`)
   - [ ] Individual guide created (`docs/reviews/[ai]-review-guide.md`)
   - [ ] CLAUDE.md updated
   - [ ] FIVE_AI_REVIEW_GUIDE.md updated
   - [ ] ARCHITECTURE.md updated
   - [ ] Implementation plan updated
   - [ ] All tests pass (70%+ coverage)
   - [ ] Manual testing completed

### PR Title Format

```
[AI] Add [AI Name] review script with [feature]
```

Examples:
- `[AI] Add Codex review script with debugging focus`
- `[DOCS] Update ARCHITECTURE.md with Codex integration`
- `[TEST] Improve test coverage for qwen-review.sh`

### PR Description Template

```markdown
## Summary

Brief description of changes (1-2 sentences).

## Motivation

Why is this change needed? What problem does it solve?

## Changes

- [x] Created wrapper script (`bin/codex-wrapper.sh`)
- [x] Created review script (`scripts/codex-review.sh`)
- [x] Created test suite (26 tests, 75% coverage)
- [x] Updated documentation (CLAUDE.md, FIVE_AI_REVIEW_GUIDE.md, etc.)
- [x] Manual testing completed

## Test Results

```
Total: 26 | Pass: 19 | Fail: 0 | Skip: 7
Branch Coverage: 75% (target: 70%)
```

## Checklist

- [x] Code follows Bash style guidelines
- [x] All tests pass
- [x] Documentation is up-to-date
- [x] Manual testing completed
- [x] No breaking changes

## Related Issues

Closes #123
```

### Review Process

1. **Automated Checks**: CI/CD runs tests and linters
2. **Code Review**: At least 1 approval required
3. **Manual Testing**: Reviewer tests the script manually
4. **Documentation Review**: Ensure docs are clear and accurate
5. **Merge**: Squash and merge to main

---

## Common Pitfalls

### 1. Unquoted Variables

**Problem**:
```bash
# BAD: Unquoted variable
echo $variable
```

**Solution**:
```bash
# GOOD: Quoted variable
echo "$variable"
```

### 2. Missing Error Handling

**Problem**:
```bash
# BAD: No error check
git show "$commit"
```

**Solution**:
```bash
# GOOD: Error check with clear message
if ! git rev-parse --verify "$commit" > /dev/null 2>&1; then
    log_error "Commit $commit not found"
    exit 1
fi
```

### 3. Temp File Cleanup

**Problem**:
```bash
# BAD: No cleanup on error
TEMP_FILE=$(mktemp)
do_something > "$TEMP_FILE"
```

**Solution**:
```bash
# GOOD: Cleanup with trap
TEMP_FILE=$(mktemp)
trap "rm -f '$TEMP_FILE'" EXIT INT TERM
do_something > "$TEMP_FILE"
```

### 4. Command Injection

**Problem**:
```bash
# BAD: Unsanitized input in command
eval "$user_input"
```

**Solution**:
```bash
# GOOD: Sanitize input before use
sanitized_input=$(sanitize_input "$user_input")
# Use in safe context (no eval)
```

### 5. JSON Parsing Errors

**Problem**:
```bash
# BAD: No error handling for jq
value=$(echo "$json" | jq -r '.key')
```

**Solution**:
```bash
# GOOD: Error handling with default value
value=$(echo "$json" | jq -r '.key // "default"' 2>/dev/null || echo "default")
```

### 6. Inconsistent VibeLogger Usage

**Problem**:
```bash
# BAD: Inconsistent event names
vibe_log "event1" "start" ...
vibe_log "tool_start" "action" ...  # Different naming
```

**Solution**:
```bash
# GOOD: Consistent event names
vibe_log "tool_execution" "start" ...
vibe_log "tool_execution" "done" ...
```

### 7. Missing Prerequisites Check

**Problem**:
```bash
# BAD: Assume wrapper exists
./bin/codex-wrapper.sh ...
```

**Solution**:
```bash
# GOOD: Check wrapper availability
if [[ ! -x "$PROJECT_ROOT/bin/codex-wrapper.sh" ]]; then
    log_error "codex-wrapper.sh not found or not executable"
    exit 1
fi
```

---

## Questions?

If you have questions or need help:

1. **Read existing code**: Check `scripts/qwen-review.sh` for reference
2. **Check documentation**: [ARCHITECTURE.md](ARCHITECTURE.md), [FIVE_AI_REVIEW_GUIDE.md](FIVE_AI_REVIEW_GUIDE.md)
3. **Open an issue**: Describe your question or problem
4. **Ask in PR**: Tag maintainers for guidance

---

**Thank you for contributing to Multi-AI Orchestrium!**

**Document Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
