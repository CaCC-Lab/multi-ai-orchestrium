#!/usr/bin/env bash
# test-job-pool.sh - Integration tests for P0.3 Job Pool and Resource Limiting
# Part of P0.3.3: Parallel Execution Limiting Integration Tests
#
# Tests:
# 1. Job pool initialization
# 2. Parallel execution limiting (max 4 concurrent)
# 3. Job queueing behavior
# 4. Semaphore operations

set -euo pipefail

# ============================================================================
# Setup
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Source libraries
source "scripts/orchestrate/lib/multi-ai-core.sh"

# Test tracking
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Colors already defined in multi-ai-core.sh

# ============================================================================
# Helper Functions
# ============================================================================

log_test_start() {
    local test_name="$1"
    ((TEST_COUNT++))
    echo -e "${BLUE}[TEST $TEST_COUNT]${NC} $test_name"
}

log_test_pass() {
    ((PASS_COUNT++))
    echo -e "  ${GREEN}✓ PASS${NC}"
}

log_test_fail() {
    local reason="$1"
    ((FAIL_COUNT++))
    echo -e "  ${RED}✗ FAIL${NC}: $reason"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="${3:-Values should be equal}"
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        log_test_fail "$description - Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

# ============================================================================
# Test Suite 1: Job Pool API
# ============================================================================

test_job_pool_init() {
    log_test_start "Job pool initialization"

    if init_job_pool 4; then
        if [[ $JOB_POOL_MAX -eq 4 ]] && [[ $JOB_POOL_RUNNING -eq 0 ]]; then
            log_test_pass
        else
            log_test_fail "Pool state incorrect: MAX=$JOB_POOL_MAX, RUNNING=$JOB_POOL_RUNNING"
        fi
    else
        log_test_fail "init_job_pool failed"
    fi
}

test_job_pool_invalid_init() {
    log_test_start "Job pool rejects invalid max_jobs"

    if init_job_pool 0 2>/dev/null; then
        log_test_fail "Should reject max_jobs=0"
    else
        log_test_pass
    fi
}

test_job_pool_concurrent_limit() {
    log_test_start "Job pool enforces max 4 concurrent jobs"

    # Initialize pool
    init_job_pool 4

    # Helper function that runs for 2 seconds
    test_worker() {
        local id="$1"
        sleep 2
        echo "Worker $id done"
    }
    export -f test_worker

    # Submit 7 jobs (should only run 4 at a time)
    local start_time=$(date +%s)

    for i in {1..7}; do
        submit_job test_worker "$i"
    done

    # Cleanup (wait for all)
    cleanup_job_pool

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo "  Duration: ${duration}s"
    echo "  Expected: 4-6s (2 waves: 4 jobs, then 3 jobs)"

    # With 4 concurrent:
    # - Wave 1: Jobs 1-4 run (2s)
    # - Wave 2: Jobs 5-7 run (2s)
    # Total: ~4s (allowing 2s tolerance)
    if [[ $duration -ge 3 ]] && [[ $duration -le 6 ]]; then
        log_test_pass
    else
        log_test_fail "Duration ${duration}s outside expected range 3-6s"
    fi
}

# ============================================================================
# Test Suite 2: Semaphore API
# ============================================================================

test_semaphore_init() {
    log_test_start "Semaphore initialization"

    if sem_init "test-resource" 4; then
        local sem_file="/tmp/multi-ai-sem-$$/test-resource"
        if [[ -f "$sem_file" ]]; then
            local value=$(cat "$sem_file")
            if assert_equals "4" "$value" "Semaphore should initialize to 4"; then
                log_test_pass
            fi
        else
            log_test_fail "Semaphore file not created"
        fi
        sem_cleanup "test-resource"
    else
        log_test_fail "sem_init failed"
    fi
}

test_semaphore_acquire_release() {
    log_test_start "Semaphore acquire/release cycle"

    sem_init "test-resource" 2

    # Acquire
    if sem_acquire "test-resource"; then
        local sem_file="/tmp/multi-ai-sem-$$/test-resource"
        local value=$(cat "$sem_file")
        if assert_equals "1" "$value" "After acquire, should be 1"; then
            # Release
            if sem_release "test-resource"; then
                value=$(cat "$sem_file")
                if assert_equals "2" "$value" "After release, should be 2"; then
                    log_test_pass
                fi
            else
                log_test_fail "sem_release failed"
            fi
        fi
    else
        log_test_fail "sem_acquire failed"
    fi

    sem_cleanup "test-resource"
}

test_semaphore_blocking() {
    log_test_start "Semaphore blocks when full"

    sem_init "test-resource" 2

    # Acquire all slots
    sem_acquire "test-resource"
    sem_acquire "test-resource"

    # Try to acquire with timeout (should fail)
    local start=$(date +%s)
    if sem_acquire "test-resource" 2 2>/dev/null; then
        log_test_fail "Should timeout when semaphore is full"
    else
        local elapsed=$(($(date +%s) - start))
        if [[ $elapsed -ge 1 ]] && [[ $elapsed -le 3 ]]; then
            log_test_pass
        else
            log_test_fail "Timeout timing incorrect: ${elapsed}s"
        fi
    fi

    sem_cleanup "test-resource"
}

# ============================================================================
# Test Suite 3: YAML Configuration
# ============================================================================

test_yaml_config_parsing() {
    log_test_start "YAML max_parallel_jobs configuration"

    if command -v yq &>/dev/null; then
        local config_file="$PROJECT_ROOT/config/multi-ai-profiles.yaml"
        if [[ -f "$config_file" ]]; then
            local max_jobs=$(yq eval ".execution.max_parallel_jobs // 0" "$config_file" 2>/dev/null)
            if assert_equals "4" "$max_jobs" "Should read max_parallel_jobs=4 from YAML"; then
                log_test_pass
            fi
        else
            log_test_fail "Config file not found: $config_file"
        fi
    else
        log_test_fail "yq not installed (required for YAML parsing)"
    fi
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
    echo "============================================================================"
    echo "JOB POOL & RESOURCE LIMITING INTEGRATION TESTS (P0.3.3)"
    echo "============================================================================"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 1: Job Pool API"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_job_pool_init
    test_job_pool_invalid_init
    test_job_pool_concurrent_limit
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 2: Semaphore API"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_semaphore_init
    test_semaphore_acquire_release
    test_semaphore_blocking
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 3: YAML Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_yaml_config_parsing
    echo ""

    # Summary
    echo "============================================================================"
    echo "  Test Summary"
    echo "============================================================================"
    echo "Total Tests:  $TEST_COUNT"
    echo "Passed:       $PASS_COUNT"
    echo "Failed:       $FAIL_COUNT"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        local pass_rate=$((PASS_COUNT * 100 / TEST_COUNT))
        echo ""
        echo -e "${GREEN}✓ ALL TESTS PASSED${NC} (Pass Rate: ${pass_rate}%)"
        exit 0
    else
        local pass_rate=$((PASS_COUNT * 100 / TEST_COUNT))
        echo ""
        echo -e "${RED}✗ TESTS FAILED${NC} (Pass Rate: ${pass_rate}%)"
        echo ""
        echo "Failed tests: $FAIL_COUNT"
        exit 1
    fi
}

# Run tests
main "$@"
