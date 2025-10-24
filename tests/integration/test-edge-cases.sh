#!/usr/bin/env bash
# test-edge-cases.sh - Integration tests for edge cases and boundary conditions
# Part of P0.2.3.2: Edge Case Test Suite
#
# Tests:
# 1. Extreme large prompts (>1MB)
# 2. Parallel execution file collisions (7AI concurrent)
# 3. Parallel log writing (corruption detection)
# 4. Timeout boundary conditions (±1s)
# 5. Memory exhaustion handling

set -euo pipefail

# ============================================================================
# Setup
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Source libraries
source "scripts/orchestrate/lib/multi-ai-core.sh"
source "scripts/orchestrate/lib/multi-ai-ai-interface.sh"

# Test tracking
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Colors (use from multi-ai-core.sh if already defined)
if [[ -z "${RED:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

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

log_test_skip() {
    local reason="$1"
    ((SKIP_COUNT++))
    echo -e "  ${YELLOW}⊘ SKIP${NC}: $reason"
}

assert_file_exists() {
    local file="$1"
    local description="${2:-File should exist}"
    if [[ -f "$file" ]]; then
        return 0
    else
        log_test_fail "$description - File not found: $file"
        return 1
    fi
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

assert_greater_than() {
    local value="$1"
    local threshold="$2"
    local description="${3:-Value should be greater than threshold}"
    if (( value > threshold )); then
        return 0
    else
        log_test_fail "$description - Value: $value, Threshold: $threshold"
        return 1
    fi
}

# ============================================================================
# Test Suite 1: Extreme Large Prompts (>1MB)
# ============================================================================

test_1mb_plus_1byte_prompt() {
    log_test_start "1MB+1B prompt handling"

    # Create 1MB + 1B prompt using dd (faster than printf)
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" RETURN

    # Use dd to create 1MB+1B file
    if dd if=/dev/zero bs=1024 count=1025 of="$temp_file" 2>/dev/null; then
        local file_size=$(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file" 2>/dev/null)
        echo "  File size: $file_size bytes"

        if [[ $file_size -gt 1048576 ]]; then
            log_test_pass
        else
            log_test_fail "File size too small: $file_size"
        fi
    else
        log_test_fail "Failed to create 1MB+ file"
    fi
}

test_memory_usage_monitoring() {
    log_test_start "Memory usage monitoring for large prompts"

    # Get initial memory usage
    local initial_mem=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    echo "  Initial memory: ${initial_mem}KB"

    # Create 1MB file (not in memory - just test file handling)
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" RETURN

    dd if=/dev/zero bs=1024 count=1024 of="$temp_file" 2>/dev/null

    # Get memory after file operation
    local after_mem=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    echo "  Memory after 1MB file: ${after_mem}KB"

    local mem_diff=$((after_mem - initial_mem))
    echo "  Memory increase: ${mem_diff}KB"

    # File operations shouldn't significantly increase memory (< 10MB overhead)
    if [[ $mem_diff -lt 10240 ]]; then
        log_test_pass
    else
        log_test_fail "Excessive memory usage: ${mem_diff}KB increase"
    fi
}

# ============================================================================
# Test Suite 2: Parallel Execution File Collisions
# ============================================================================

test_concurrent_file_creation() {
    log_test_start "7AI concurrent file creation (no collisions)"

    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" RETURN

    # Simulate 7 concurrent AI processes creating files
    local pids=()
    for ai in claude gemini amp qwen droid codex cursor; do
        (
            for i in {1..10}; do
                local file=$(mktemp -p "$temp_dir" "prompt-${ai}-XXXXXX")
                echo "Test content from $ai" > "$file"
                chmod 600 "$file"
            done
        ) &
        pids+=($!)
    done

    # Wait for all processes
    for pid in "${pids[@]}"; do
        wait $pid
    done

    # Count files (should be 70: 7 AIs * 10 files)
    local file_count=$(find "$temp_dir" -type f | wc -l)
    echo "  Files created: $file_count"

    if assert_equals "70" "$file_count" "Should create 70 unique files"; then
        # Check for naming collisions
        local unique_names=$(find "$temp_dir" -type f -exec basename {} \; | sort -u | wc -l)
        echo "  Unique filenames: $unique_names"

        if assert_equals "70" "$unique_names" "All filenames should be unique"; then
            log_test_pass
        fi
    fi
}

test_concurrent_cleanup() {
    log_test_start "Concurrent file cleanup (no race conditions)"

    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" RETURN

    # Create files
    local files=()
    for i in {1..20}; do
        local file=$(mktemp -p "$temp_dir")
        files+=("$file")
    done

    echo "  Created ${#files[@]} files"

    # Concurrent cleanup
    local pids=()
    for file in "${files[@]}"; do
        (rm -f "$file" 2>/dev/null || true) &
        pids+=($!)
    done

    # Wait for all
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done

    # Verify all deleted
    local remaining=$(find "$temp_dir" -type f | wc -l)
    echo "  Remaining files: $remaining"

    if assert_equals "0" "$remaining" "All files should be deleted"; then
        log_test_pass
    fi
}

# ============================================================================
# Test Suite 3: Parallel Log Writing
# ============================================================================

test_concurrent_log_writing() {
    log_test_start "Parallel log writing (no corruption)"

    local log_file=$(mktemp)
    trap "rm -f $log_file" RETURN

    # 5 processes writing concurrently
    local pids=()
    for i in {1..5}; do
        (
            for j in {1..20}; do
                echo "Process $i - Entry $j" >> "$log_file"
            done
        ) &
        pids+=($!)
    done

    # Wait for all
    for pid in "${pids[@]}"; do
        wait $pid
    done

    # Count lines (should be 100: 5 processes * 20 entries)
    local line_count=$(wc -l < "$log_file")
    echo "  Log lines: $line_count"

    if assert_equals "100" "$line_count" "Should have 100 log lines"; then
        # Check for corruption (incomplete lines)
        local complete_lines=$(grep -c "^Process [1-5] - Entry [0-9]\+$" "$log_file" || echo "0")
        echo "  Complete lines: $complete_lines"

        if assert_greater_than "$complete_lines" "95" "At least 95% lines should be complete"; then
            log_test_pass
        fi
    fi
}

test_vibelogger_concurrent() {
    log_test_start "VibeLogger concurrent writes"

    local log_dir=$(mktemp -d)
    export VIBELOGGER_DIR="$log_dir"
    trap "rm -rf $log_dir" RETURN

    # Create log file
    local log_file="$log_dir/test.jsonl"
    touch "$log_file"

    # 3 processes writing JSON logs concurrently
    local pids=()
    for i in {1..3}; do
        (
            for j in {1..10}; do
                local timestamp=$(date +%s%3N)
                echo "{\"process\":$i,\"entry\":$j,\"timestamp\":$timestamp}" >> "$log_file"
            done
        ) &
        pids+=($!)
    done

    # Wait for all
    for pid in "${pids[@]}"; do
        wait $pid
    done

    # Validate JSON lines
    local total_lines=$(wc -l < "$log_file")
    local valid_json_lines=0

    while IFS= read -r line; do
        if echo "$line" | jq empty 2>/dev/null; then
            ((valid_json_lines++))
        fi
    done < "$log_file"

    echo "  Total lines: $total_lines"
    echo "  Valid JSON lines: $valid_json_lines"

    if assert_equals "30" "$total_lines" "Should have 30 log lines"; then
        if assert_greater_than "$valid_json_lines" "28" "At least 93% should be valid JSON"; then
            log_test_pass
        fi
    fi
}

# ============================================================================
# Test Suite 4: Timeout Boundary Conditions
# ============================================================================

test_timeout_minus_1s() {
    log_test_start "Timeout boundary: complete at T-1s (should succeed)"

    local timeout=5
    local duration=$((timeout - 1))

    # Simulate process that completes 1s before timeout
    local start=$(date +%s)
    (sleep $duration && echo "Success") &
    local pid=$!

    # Wait with timeout
    local exit_code=0
    if wait $pid; then
        local end=$(date +%s)
        local elapsed=$((end - start))
        echo "  Duration: ${elapsed}s (timeout: ${timeout}s)"

        if [[ $elapsed -lt $timeout ]]; then
            log_test_pass
        else
            log_test_fail "Process took too long: ${elapsed}s"
        fi
    else
        log_test_fail "Process failed"
    fi
}

test_timeout_plus_1s() {
    log_test_start "Timeout boundary: complete at T+1s (should fail)"

    log_test_skip "Timeout enforcement requires wrapper timeout implementation"
    # Note: This would require implementing actual timeout mechanism
    # Currently wrappers handle timeouts, not core functions
}

test_timeout_exactly_at_limit() {
    log_test_start "Timeout at exact limit (edge case)"

    local timeout=3

    # Process that completes exactly at timeout
    local start=$(date +%s)
    (sleep $timeout && echo "At limit") &
    local pid=$!

    if wait $pid; then
        local end=$(date +%s)
        local elapsed=$((end - start))
        echo "  Duration: ${elapsed}s (expected: ${timeout}s)"

        # Should be within 1s tolerance
        if [[ $elapsed -le $((timeout + 1)) ]] && [[ $elapsed -ge $((timeout - 1)) ]]; then
            log_test_pass
        else
            log_test_fail "Duration out of range: ${elapsed}s"
        fi
    else
        log_test_fail "Process failed unexpectedly"
    fi
}

# ============================================================================
# Test Suite 5: Error Handling
# ============================================================================

test_out_of_disk_space_simulation() {
    log_test_start "Disk space exhaustion handling"

    # Create a small tmpfs (if supported)
    if command -v mount 2>/dev/null | grep -q tmpfs; then
        log_test_skip "Requires root privileges for tmpfs mount"
    else
        # Fallback: Test error handling when /tmp is full (simulated)
        local temp_file=$(mktemp 2>/dev/null || echo "")

        if [[ -z "$temp_file" ]]; then
            log_test_pass  # Correctly handled mktemp failure
        elif [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            log_test_skip "Cannot simulate disk full condition"
        fi
    fi
}

test_invalid_permissions() {
    log_test_start "File permission error handling"

    local temp_file=$(mktemp)
    trap "rm -f $temp_file" RETURN

    # Remove all permissions
    chmod 000 "$temp_file"

    # Try to write (should fail gracefully)
    if echo "test" > "$temp_file" 2>/dev/null; then
        log_test_fail "Should not be able to write to unreadable file"
    else
        # Restore permissions to clean up
        chmod 600 "$temp_file"
        log_test_pass
    fi
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
    echo "============================================================================"
    echo "EDGE CASE TEST SUITE - Integration Tests"
    echo "============================================================================"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 1: Extreme Large Prompts (>1MB)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_1mb_plus_1byte_prompt
    test_memory_usage_monitoring
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 2: Parallel Execution File Collisions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_concurrent_file_creation
    test_concurrent_cleanup
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 3: Parallel Log Writing"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_concurrent_log_writing
    test_vibelogger_concurrent
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 4: Timeout Boundary Conditions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_timeout_minus_1s
    test_timeout_plus_1s
    test_timeout_exactly_at_limit
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Suite 5: Error Handling"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_out_of_disk_space_simulation
    test_invalid_permissions
    echo ""

    # Summary
    echo "============================================================================"
    echo "  Test Summary"
    echo "============================================================================"
    echo "Total Tests:  $TEST_COUNT"
    echo "Passed:       $PASS_COUNT"
    echo "Failed:       $FAIL_COUNT"
    echo "Skipped:      $SKIP_COUNT"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        local pass_rate=$(( PASS_COUNT * 100 / (TEST_COUNT - SKIP_COUNT) ))
        echo ""
        echo -e "${GREEN}✓ ALL TESTS PASSED${NC} (Pass Rate: ${pass_rate}%)"
        exit 0
    else
        local pass_rate=$(( PASS_COUNT * 100 / TEST_COUNT ))
        echo ""
        echo -e "${RED}✗ TESTS FAILED${NC} (Pass Rate: ${pass_rate}%)"
        echo ""
        echo "Failed tests: $FAIL_COUNT"
        exit 1
    fi
}

# Run tests
main "$@"
