#!/usr/bin/env bash
# Phase 4.3: End-to-End Test Suite
# Purpose: Validate file-based prompt system with real workflows at scale
#
# Test Coverage:
#   1. 10KB prompt with multi-ai-chatdev-develop
#   2. 50KB document with multi-ai-coa-analyze
#   3. 100KB context with multi-ai-5ai-orchestrate
#   4. Concurrent workflow execution (stress test)
#
# Success Criteria:
#   - All workflows complete without errors
#   - Large prompts route through file-based system
#   - No performance regression vs command-line
#   - Concurrent execution handles file conflicts gracefully

set -euo pipefail

# Project root
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export PROJECT_ROOT

# Source required libraries
source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh"
source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-ai-interface.sh"
source "$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh"

# Test configuration
TEST_OUTPUT_DIR="/tmp/phase4-e2e-tests"
TEST_LOG_FILE="$TEST_OUTPUT_DIR/test-execution.log"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Color codes are already defined in multi-ai-core.sh
# RED, GREEN, YELLOW, BLUE, NC are available

# ============================================================================
# Helper Functions
# ============================================================================

setup_test_environment() {
    echo -e "${BLUE}Setting up test environment...${NC}"

    # Create test output directory
    mkdir -p "$TEST_OUTPUT_DIR"

    # Clear previous logs
    > "$TEST_LOG_FILE"

    echo "Test run: $TIMESTAMP" >> "$TEST_LOG_FILE"
    echo "Project root: $PROJECT_ROOT" >> "$TEST_LOG_FILE"
    echo "" >> "$TEST_LOG_FILE"
}

teardown_test_environment() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"

    # Clean up temporary files (keep logs)
    find "$TEST_OUTPUT_DIR" -name "prompt-*" -type f -delete 2>/dev/null || true

    echo "" >> "$TEST_LOG_FILE"
    echo "Test completed: $(date)" >> "$TEST_LOG_FILE"
}

generate_large_prompt() {
    local size_kb=$1
    local output_file=$2
    local template=$3

    # Generate prompt of specified size
    local size_bytes=$((size_kb * 1024))

    # Start with template
    echo "$template" > "$output_file"

    # Pad with realistic content to reach target size
    local current_size=$(wc -c < "$output_file")
    local padding_needed=$((size_bytes - current_size))

    if [ $padding_needed -gt 0 ]; then
        # Generate padding with Lorem Ipsum-like content
        local padding=$(head -c "$padding_needed" /dev/zero | tr '\0' 'A')
        echo "" >> "$output_file"
        echo "=== Additional Context ===" >> "$output_file"
        echo "$padding" >> "$output_file"
    fi

    echo "$output_file"
}

test_result() {
    local test_name=$1
    local exit_code=$2

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "[PASS] $test_name" >> "$TEST_LOG_FILE"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $test_name (exit code: $exit_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "[FAIL] $test_name (exit code: $exit_code)" >> "$TEST_LOG_FILE"
        return 1
    fi
}

# ============================================================================
# Test Suite 1: 10KB Prompt with ChatDev
# ============================================================================

test_chatdev_10kb() {
    echo -e "${YELLOW}Test Suite 1: ChatDev with 10KB Prompt${NC}"
    echo "============================================"

    local prompt_file="$TEST_OUTPUT_DIR/chatdev-10kb-spec.txt"

    # Generate 10KB prompt
    local template="PROJECT: E-Commerce Shopping Cart System

FEATURES:
- User authentication (login/logout/register)
- Product catalog with search and filters
- Shopping cart management (add/remove/update quantities)
- Checkout process with payment integration
- Order history and tracking
- Admin panel for product management
- Inventory management system
- Email notifications for orders
- Responsive design (mobile/tablet/desktop)
- Multi-currency support

TECHNICAL REQUIREMENTS:
- Backend: Node.js with Express
- Database: PostgreSQL with Sequelize ORM
- Frontend: React with Redux state management
- Authentication: JWT tokens
- Payment: Stripe integration
- Email: SendGrid API
- Hosting: AWS EC2 with RDS
- CI/CD: GitHub Actions

SECURITY REQUIREMENTS:
- Password hashing with bcrypt
- SQL injection prevention
- XSS protection
- CSRF tokens
- Rate limiting
- Input validation
- Secure session management

PERFORMANCE REQUIREMENTS:
- Page load < 2 seconds
- API response < 500ms
- Support 1000 concurrent users
- Database query optimization
- CDN for static assets
- Caching strategy (Redis)

DELIVERABLES:
- Complete source code
- Database schema and migrations
- API documentation (OpenAPI/Swagger)
- Unit tests (80% coverage)
- Integration tests
- Deployment scripts
- User manual
- Admin guide"

    generate_large_prompt 10 "$prompt_file" "$template" > /dev/null

    local actual_size=$(wc -c < "$prompt_file")
    echo "Generated prompt: ${actual_size} bytes (target: 10KB)"

    # Test 1.1: Verify prompt size
    echo ""
    echo "  [T1.1] Verify 10KB prompt generation"
    if [ $actual_size -ge 10240 ]; then
        test_result "10KB prompt generated" 0
    else
        test_result "10KB prompt generated" 1
    fi

    # Test 1.2: Verify file-based routing
    echo "  [T1.2] Verify file-based routing for 10KB prompt"
    local prompt_content=$(cat "$prompt_file")

    set +e
    local routing_output=$(call_ai_with_context "claude" "$prompt_content" 30 "$TEST_OUTPUT_DIR/chatdev-10kb-output.txt" 2>&1)
    local routing_exit=$?
    set -e

    if echo "$routing_output" | grep -q "Large prompt detected"; then
        test_result "File-based routing detected" 0
    else
        test_result "File-based routing detected" 1
    fi

    # Test 1.3: Verify ChatDev workflow execution (REAL AI CALL)
    echo "  [T1.3] ChatDev workflow with 10KB spec (REAL)"
    echo "    Executing multi-ai-chatdev-develop with 10KB prompt..."
    echo "    This will take 5-10 minutes with real AI calls"

    set +e
    multi-ai-chatdev-develop "$prompt_content" > "$TEST_OUTPUT_DIR/chatdev-10kb-result.log" 2>&1
    local chatdev_exit=$?
    set -e

    test_result "ChatDev workflow execution" $chatdev_exit

    echo ""
}

# ============================================================================
# Test Suite 2: 50KB Document with CoA Analyze
# ============================================================================

test_coa_50kb() {
    echo -e "${YELLOW}Test Suite 2: CoA Analyze with 50KB Document${NC}"
    echo "============================================"

    local document_file="$TEST_OUTPUT_DIR/coa-50kb-document.txt"

    # Generate 50KB document
    local template="DOCUMENT: Multi-AI Orchestration Architecture Specification

EXECUTIVE SUMMARY:
This document describes the architecture, design, and implementation of the Multi-AI Orchestration system, a framework for coordinating multiple AI assistants (Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor) in collaborative software development workflows.

CHAPTER 1: SYSTEM OVERVIEW
The Multi-AI Orchestration system implements a YAML-driven workflow engine that enables complex task distribution across heterogeneous AI assistants. Each AI brings specialized capabilities: Claude for strategic planning, Gemini for research, Qwen for rapid prototyping, Droid for enterprise development, Codex for code review, Cursor for IDE integration, and Amp for project management.

CHAPTER 2: ARCHITECTURE
The system follows a three-tier architecture:
1. Orchestration Layer (orchestrate-multi-ai.sh)
2. AI Interface Layer (multi-ai-ai-interface.sh)
3. Workflow Implementation Layer (multi-ai-workflows.sh)

CHAPTER 3: FILE-BASED PROMPT SYSTEM
Phase 1 implemented a file-based prompt system to handle large inputs (>1KB) that exceed command-line argument limits. The system automatically routes prompts through secure temporary files with chmod 600 permissions and automatic cleanup via trap handlers.

CHAPTER 4: WORKFLOW PATTERNS
The framework supports multiple workflow patterns:
- Sequential execution with fallback
- Parallel execution with aggregation
- Chain-of-Agents (CoA) for divide-and-conquer
- ChatDev-style role-based collaboration
- Hybrid adaptive workflows

CHAPTER 5: PERFORMANCE METRICS
Production metrics show:
- 98% workflow success rate
- 300% development speed improvement
- 85% coding accuracy increase
- 80% error reduction
- 140% faster iteration cycles

CHAPTER 6: SECURITY AND COMPLIANCE
Security measures include input sanitization, command injection prevention, secure file handling, and audit logging through VibeLogger integration.

CHAPTER 7: TESTING AND QUALITY ASSURANCE
The system implements comprehensive testing:
- Phase 1: 65 unit tests (100% pass rate)
- Phase 2: Integration tests (100% pass rate)
- Phase 4: E2E tests (this document)

CHAPTER 8: DEPLOYMENT AND OPERATIONS
Production deployment requires YAML configuration, wrapper script installation, and VibeLogger setup for monitoring."

    generate_large_prompt 50 "$document_file" "$template" > /dev/null

    local actual_size=$(wc -c < "$document_file")
    echo "Generated document: ${actual_size} bytes (target: 50KB)"

    # Test 2.1: Verify document size
    echo ""
    echo "  [T2.1] Verify 50KB document generation"
    if [ $actual_size -ge 51200 ]; then
        test_result "50KB document generated" 0
    else
        test_result "50KB document generated" 1
    fi

    # Test 2.2: Verify file-based routing
    echo "  [T2.2] Verify file-based routing for 50KB document"
    local document_content=$(cat "$document_file")

    set +e
    local routing_output=$(call_ai_with_context "claude" "$document_content" 30 "$TEST_OUTPUT_DIR/coa-50kb-output.txt" 2>&1)
    local routing_exit=$?
    set -e

    if echo "$routing_output" | grep -q "Large prompt detected"; then
        test_result "File-based routing detected" 0
    else
        test_result "File-based routing detected" 1
    fi

    # Test 2.3: Verify CoA workflow execution (REAL AI CALL)
    echo "  [T2.3] CoA analyze workflow with 50KB document (REAL)"
    echo "    Executing multi-ai-coa-analyze with 50KB document..."
    echo "    This will take 10-15 minutes with real AI calls"

    set +e
    multi-ai-coa-analyze "$document_content" > "$TEST_OUTPUT_DIR/coa-50kb-result.log" 2>&1
    local coa_exit=$?
    set -e

    test_result "CoA analyze workflow execution" $coa_exit

    echo ""
}

# ============================================================================
# Test Suite 3: 100KB Context with 5AI Orchestrate
# ============================================================================

test_5ai_100kb() {
    echo -e "${YELLOW}Test Suite 3: 5AI Orchestrate with 100KB Context${NC}"
    echo "============================================"

    local context_file="$TEST_OUTPUT_DIR/5ai-100kb-context.txt"

    # Generate 100KB context
    local template="CONTEXT: Complete Codebase Analysis for Refactoring

PROJECT: Multi-AI Orchestration System
FILES: 87 files across 12 directories
TOTAL LINES: 15,432 lines of code
LANGUAGES: Bash (95%), YAML (3%), Markdown (2%)

FILE STRUCTURE:
- bin/ (7 wrapper scripts)
- scripts/orchestrate/ (4 core orchestration files)
- scripts/orchestrate/lib/ (4 library modules)
- scripts/tdd/ (2 TDD workflow scripts)
- config/ (1 YAML profile)
- tests/ (3 test suites)
- docs/ (5 documentation files)

KEY COMPONENTS:
1. orchestrate-multi-ai.sh (1,952 lines)
   - Main orchestration engine
   - 49 functions
   - YAML workflow execution

2. multi-ai-workflows.sh (726 lines)
   - 13 workflow implementations
   - Phase 2 updated with call_ai_with_context

3. multi-ai-ai-interface.sh (363 lines)
   - AI availability checking
   - Unified AI call wrapper
   - File-based prompt system

4. multi-ai-config.sh (512 lines)
   - YAML parsing
   - Phase execution
   - Configuration management

REFACTORING REQUIREMENTS:
- Improve modularity
- Reduce code duplication
- Enhance error handling
- Add comprehensive logging
- Optimize performance
- Update documentation
- Increase test coverage"

    generate_large_prompt 100 "$context_file" "$template" > /dev/null

    local actual_size=$(wc -c < "$context_file")
    echo "Generated context: ${actual_size} bytes (target: 100KB)"

    # Test 3.1: Verify context size
    echo ""
    echo "  [T3.1] Verify 100KB context generation"
    if [ $actual_size -ge 102400 ]; then
        test_result "100KB context generated" 0
    else
        test_result "100KB context generated" 1
    fi

    # Test 3.2: Verify file-based routing
    echo "  [T3.2] Verify file-based routing for 100KB context"
    local context_content=$(cat "$context_file")

    set +e
    local routing_output=$(call_ai_with_context "claude" "$context_content" 30 "$TEST_OUTPUT_DIR/5ai-100kb-output.txt" 2>&1)
    local routing_exit=$?
    set -e

    if echo "$routing_output" | grep -q "Large prompt detected"; then
        test_result "File-based routing detected" 0
    else
        test_result "File-based routing detected" 1
    fi

    # Test 3.3: Verify 5AI workflow execution (REAL AI CALL)
    echo "  [T3.3] 5AI orchestrate workflow with 100KB context (REAL)"
    echo "    Executing multi-ai-5ai-orchestrate with 100KB context..."
    echo "    This will take 15-20 minutes with real AI calls"

    set +e
    multi-ai-5ai-orchestrate "$context_content" > "$TEST_OUTPUT_DIR/5ai-100kb-result.log" 2>&1
    local fiveai_exit=$?
    set -e

    test_result "5AI orchestrate workflow execution" $fiveai_exit

    echo ""
}

# ============================================================================
# Test Suite 4: Concurrent Workflow Execution (Stress Test)
# ============================================================================

test_concurrent_execution() {
    echo -e "${YELLOW}Test Suite 4: Concurrent Workflow Execution${NC}"
    echo "============================================"

    # Test 4.1: Concurrent file creation
    echo ""
    echo "  [T4.1] Concurrent temporary file creation"

    local pids=()
    local concurrent_count=5

    for i in $(seq 1 $concurrent_count); do
        (
            local prompt="Test concurrent execution $i with large prompt data"
            local size_bytes=$((2048 + i * 100))  # 2KB+ prompts
            local padding=$(head -c "$size_bytes" /dev/zero | tr '\0' "$i")
            local full_prompt="${prompt}${padding}"

            call_ai_with_context "claude" "$full_prompt" 10 "$TEST_OUTPUT_DIR/concurrent-$i.txt" 2>&1 > /dev/null
        ) &
        pids+=($!)
    done

    # Wait for all background jobs
    local all_success=true
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            all_success=false
        fi
    done

    if $all_success; then
        test_result "Concurrent file creation" 0
    else
        test_result "Concurrent file creation" 1
    fi

    # Test 4.2: File cleanup verification
    echo "  [T4.2] Verify temporary file cleanup"

    # Check for leftover temp files
    local leftover_count=$(find /tmp -name "prompt-claude-*" 2>/dev/null | wc -l)

    if [ "$leftover_count" -eq 0 ]; then
        test_result "Temporary file cleanup" 0
    else
        echo "    Warning: $leftover_count temporary files not cleaned up"
        test_result "Temporary file cleanup" 1
    fi

    echo ""
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}Phase 4.3: End-to-End Test Suite${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo "Test run: $TIMESTAMP"
    echo "Output directory: $TEST_OUTPUT_DIR"
    echo ""

    setup_test_environment

    # Run test suites
    test_chatdev_10kb
    test_coa_50kb
    test_5ai_100kb
    test_concurrent_execution

    # Print summary
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Total Tests:  ${BLUE}${TOTAL_TESTS}${NC}"
    echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"
    echo ""

    local pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Pass Rate:    ${BLUE}${pass_rate}%${NC}"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        echo "Logs: $TEST_LOG_FILE"
        teardown_test_environment
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        echo "Logs: $TEST_LOG_FILE"
        teardown_test_environment
        return 1
    fi
}

# Run tests
main "$@"
