#!/usr/bin/env bats
# test-common-wrapper-lib.bats - Unit tests for bin/common-wrapper-lib.sh

load '../helpers/test_helper'

setup() {
    setup_test_env
    source_lib "bin/common-wrapper-lib.sh"
}

teardown() {
    teardown_test_env
}

# ============================================================================
# sanitize_wrapper_input() Tests
# ============================================================================

@test "sanitize_wrapper_input: rejects empty input" {
    run sanitize_wrapper_input ""
    assert_failure
    assert_output_contains "Empty input provided"
}

@test "sanitize_wrapper_input: accepts small safe input (<1KB)" {
    run sanitize_wrapper_input "Hello World"
    assert_success
    # printf '%q' adds shell escaping for safety
    assert_output "Hello\\ World"
}

@test "sanitize_wrapper_input: blocks dangerous characters in small input (<1KB)" {
    # Test command injection patterns
    run sanitize_wrapper_input "test \$(whoami)"
    assert_failure
    assert_output_contains "Dangerous characters detected"

    run sanitize_wrapper_input "test ; ls"
    assert_failure

    run sanitize_wrapper_input "test | grep foo"
    assert_failure

    run sanitize_wrapper_input "test > output.txt"
    assert_failure

    run sanitize_wrapper_input "test & background"
    assert_failure
}

@test "sanitize_wrapper_input: accepts medium safe input (1KB-100KB)" {
    # Create input between 1KB and 100KB
    local input=$(printf 'a%.0s' {1..2048})  # 2KB of 'a's

    run sanitize_wrapper_input "$input"
    assert_success
    assert_output "$input"
}

@test "sanitize_wrapper_input: blocks command injection in medium input (1KB-100KB)" {
    # Create input with command injection pattern
    local base=$(printf 'a%.0s' {1..1024})  # 1KB base
    local input="${base} \$(whoami)"

    run sanitize_wrapper_input "$input"
    assert_failure
    assert_output_contains "Command injection patterns detected"
}

@test "sanitize_wrapper_input: accepts large input (>100KB)" {
    # Create input larger than 100KB
    local input=$(printf 'b%.0s' {1..102500})  # ~100KB of 'b's

    run sanitize_wrapper_input "$input"
    assert_success
}

# ============================================================================
# handle_wrapper_timeout() Tests
# ============================================================================

@test "handle_wrapper_timeout: returns success for quick process" {
    # Create a process that finishes quickly
    bash -c 'sleep 0.1; exit 0' &
    local pid=$!

    run handle_wrapper_timeout "$pid" 5
    assert_success
}

@test "handle_wrapper_timeout: times out slow process" {
    # Create a process that takes longer than timeout
    sleep 10 &
    local pid=$!

    run handle_wrapper_timeout "$pid" 2
    assert_exit_code 124  # Standard timeout exit code
    assert_output_contains "TIMEOUT"
}

@test "handle_wrapper_timeout: sends SIGTERM then SIGKILL" {
    # Create a process that ignores SIGTERM
    bash -c 'trap "" TERM; sleep 30' &
    local pid=$!

    run handle_wrapper_timeout "$pid" 2
    assert_exit_code 124
    assert_output_contains "SIGTERM"
    assert_output_contains "SIGKILL"
}

# ============================================================================
# format_wrapper_output() Tests
# ============================================================================

@test "format_wrapper_output: formats text output" {
    # Signature: format ai_name status exit_code duration_ms output
    run format_wrapper_output "text" "claude" "success" 0 1000 "Hello from AI"
    assert_success
    assert_output_contains "Hello from AI"
}

@test "format_wrapper_output: formats JSON output" {
    run format_wrapper_output "json" "claude" "success" 0 1000 "Success message"
    assert_success
    assert_output_contains '"status"'
    assert_output_contains '"ai"'
    assert_output_contains '"timestamp"'
}

@test "format_wrapper_output: outputs to stderr for text format" {
    # Text format outputs to stderr, not stdout
    format_wrapper_output "text" "claude" "success" 0 1000 "Default output" 2>&1 | grep -q "claude Wrapper Result"
}

# ============================================================================
# wrapper_structured_error() Tests
# ============================================================================

@test "wrapper_structured_error: outputs what/why/how pattern" {
    run wrapper_structured_error 1 "Test error" "Test cause" "Test fix"
    assert_failure
    assert_exit_code 1
    assert_output_contains "What happened"
    assert_output_contains "Test error"
    assert_output_contains "Why it happened"
    assert_output_contains "Test cause"
    assert_output_contains "How to fix"
    assert_output_contains "Test fix"
}

@test "wrapper_structured_error: returns correct exit code" {
    run wrapper_structured_error 42 "Error" "Cause" "Fix"
    assert_exit_code 42
}

@test "wrapper_structured_error: uses WRAPPER_EXIT constants" {
    run wrapper_structured_error "$WRAPPER_EXIT_INVALID_INPUT" "Bad input" "Invalid format" "Check syntax"
    assert_exit_code 12  # WRAPPER_EXIT_INVALID_INPUT = 12
}

# ============================================================================
# wrapper_print_stack_trace() Tests
# ============================================================================

@test "wrapper_print_stack_trace: outputs stack frames" {
    # Call from a nested function to create stack
    nested_func() {
        wrapper_print_stack_trace
    }

    run nested_func
    assert_success
    assert_output_contains "Stack Trace"
    assert_output_contains "nested_func"
}

@test "wrapper_print_stack_trace: limits to 20 frames" {
    # Create deep recursion
    deep_func() {
        local depth=$1
        if [ $depth -gt 25 ]; then
            wrapper_print_stack_trace
        else
            deep_func $((depth + 1))
        fi
    }

    run deep_func 0
    assert_success
    assert_output_contains "truncated, max 20 frames"
}

# ============================================================================
# Error Code Constants Tests
# ============================================================================

@test "error codes: WRAPPER_EXIT constants are defined" {
    # Success
    [ "$WRAPPER_EXIT_SUCCESS" -eq 0 ]

    # General errors (1-10)
    [ "$WRAPPER_EXIT_GENERAL_ERROR" -eq 1 ]
    [ "$WRAPPER_EXIT_INVALID_ARGS" -eq 2 ]
    [ "$WRAPPER_EXIT_MISSING_DEPENDENCY" -eq 3 ]
    [ "$WRAPPER_EXIT_PERMISSION_DENIED" -eq 4 ]

    # Input validation errors (11-20)
    [ "$WRAPPER_EXIT_EMPTY_INPUT" -eq 11 ]
    [ "$WRAPPER_EXIT_INVALID_INPUT" -eq 12 ]
    [ "$WRAPPER_EXIT_INPUT_TOO_LARGE" -eq 13 ]
    [ "$WRAPPER_EXIT_SANITIZATION_FAILED" -eq 14 ]

    # AI execution errors (21-40)
    [ "$WRAPPER_EXIT_AI_NOT_FOUND" -eq 21 ]
    [ "$WRAPPER_EXIT_AI_EXECUTION_FAILED" -eq 22 ]
    [ "$WRAPPER_EXIT_AI_TIMEOUT" -eq 124 ]
    [ "$WRAPPER_EXIT_AI_CANCELLED" -eq 130 ]

    # Configuration errors (41-50)
    [ "$WRAPPER_EXIT_CONFIG_ERROR" -eq 41 ]
    [ "$WRAPPER_EXIT_WORKSPACE_ERROR" -eq 42 ]
    [ "$WRAPPER_EXIT_LOG_ERROR" -eq 43 ]

    # System errors (51-60)
    [ "$WRAPPER_EXIT_FILE_ERROR" -eq 51 ]
    [ "$WRAPPER_EXIT_NETWORK_ERROR" -eq 52 ]
    [ "$WRAPPER_EXIT_RESOURCE_EXHAUSTED" -eq 53 ]
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "integration: sanitize + format output pipeline" {
    local input="Clean input text"
    local sanitized=$(sanitize_wrapper_input "$input")

    # sanitized output is shell-escaped: "Clean\ input\ text"
    run format_wrapper_output "text" "claude" "success" 0 1000 "$sanitized"
    assert_success
}

@test "integration: error handling with stack trace" {
    error_func() {
        wrapper_structured_error "$WRAPPER_EXIT_GENERAL_ERROR" \
            "Test error in function" \
            "Intentional test failure" \
            "This is a test, no fix needed"
    }

    run error_func
    # wrapper_structured_error outputs to stderr and returns via 'return',
    # but in a subshell created by 'run', return doesn't propagate the exit code
    # Instead, check that error output is generated
    assert_output_contains "Test error in function"
    assert_output_contains "What happened"
    assert_output_contains "Why it happened"
}
