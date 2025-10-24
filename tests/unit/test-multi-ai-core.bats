#!/usr/bin/env bats
# test-multi-ai-core.bats - Unit tests for scripts/orchestrate/lib/multi-ai-core.sh

load '../helpers/test_helper'

setup() {
    setup_test_env

    # Set up VIBE_LOG_DIR for VibeLogger tests
    export VIBE_LOG_DIR="${TEST_WORK_DIR}/vibe_logs"
    mkdir -p "$VIBE_LOG_DIR"

    source_lib "scripts/orchestrate/lib/multi-ai-core.sh"
}

teardown() {
    teardown_test_env
}

# ============================================================================
# Logging Functions Tests
# ============================================================================

@test "log_info: outputs info message with icon" {
    run log_info "Test info message"
    assert_success
    assert_output_contains "ℹ️"
    assert_output_contains "Test info message"
}

@test "log_success: outputs success message with icon" {
    run log_success "Test success message"
    assert_success
    assert_output_contains "✅"
    assert_output_contains "Test success message"
}

@test "log_warning: outputs warning message with icon" {
    run log_warning "Test warning message"
    assert_success
    assert_output_contains "⚠️"
    assert_output_contains "Test warning message"
}

@test "log_error: outputs error message with icon" {
    run log_error "Test error message"
    assert_success
    assert_output_contains "❌"
    assert_output_contains "Test error message"
}

@test "log_phase: outputs phase separator with icon" {
    run log_phase "Test Phase"
    assert_success
    assert_output_contains "🚀"
    assert_output_contains "Test Phase"
    assert_output_contains "━"
}

# ============================================================================
# get_timestamp_ms() Tests
# ============================================================================

@test "get_timestamp_ms: returns numeric timestamp" {
    run get_timestamp_ms
    assert_success
    # Check if output is numeric
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "get_timestamp_ms: returns millisecond precision (13 digits)" {
    local ts=$(get_timestamp_ms)
    # Unix timestamp with milliseconds should be 13 digits
    [ ${#ts} -eq 13 ]
}

@test "get_timestamp_ms: increases over time" {
    local ts1=$(get_timestamp_ms)
    sleep 0.01
    local ts2=$(get_timestamp_ms)
    [ "$ts2" -gt "$ts1" ]
}

# ============================================================================
# sanitize_input() Tests
# ============================================================================

@test "sanitize_input: accepts clean input" {
    run sanitize_input "Clean test input"
    assert_success
    assert_output "Clean test input"
}

@test "sanitize_input: rejects semicolon" {
    run sanitize_input "test; rm -rf /"
    assert_failure
    assert_output_contains "Invalid characters"
}

@test "sanitize_input: rejects pipe" {
    run sanitize_input "test | grep foo"
    assert_failure
    assert_output_contains "Invalid characters"
}

@test "sanitize_input: rejects dollar sign" {
    run sanitize_input "test \$(whoami)"
    assert_failure
    assert_output_contains "Invalid characters"
}

@test "sanitize_input: rejects redirect operators" {
    run sanitize_input "test > output.txt"
    assert_failure
    assert_output_contains "Invalid characters"

    run sanitize_input "test < input.txt"
    assert_failure
}

@test "sanitize_input: rejects ampersand" {
    run sanitize_input "test & background"
    assert_failure
}

@test "sanitize_input: rejects exclamation mark" {
    run sanitize_input "test ! logic"
    assert_failure
}

@test "sanitize_input: accepts large input (>2KB) with relaxed validation" {
    # Create input larger than 2KB
    local large_input=$(printf 'a%.0s' {1..2100})

    run sanitize_input "$large_input"
    assert_success
}

@test "sanitize_input: large input (>2KB) allows spaces and newlines" {
    # Large prompts should allow more characters
    local large_input=$(printf 'Line %d\n' {1..100})

    run sanitize_input "$large_input"
    assert_success
}

@test "sanitize_input: rejects empty input" {
    run sanitize_input ""
    assert_failure
    assert_output_contains "cannot be empty"
}

@test "sanitize_input: rejects only whitespace" {
    run sanitize_input $'   \n\t   '
    assert_failure
    assert_output_contains "cannot be empty"
}

# ============================================================================
# VibeLogger Integration Tests
# ============================================================================

@test "vibe_log: creates log file" {
    run vibe_log "test.event" "test_action" '{"key":"value"}' "Test note" "test_todo"
    assert_success

    # Check if log file was created
    local log_file=$(ls "$VIBE_LOG_DIR"/7ai_orchestration_*.jsonl 2>/dev/null | head -1)
    assert_file_exists "$log_file"
}

@test "vibe_log: writes JSON format" {
    vibe_log "test.event" "test_action" '{"key":"value"}' "Test note" "test_todo"

    # Get the log file
    local log_file=$(ls "$VIBE_LOG_DIR"/7ai_orchestration_*.jsonl 2>/dev/null | head -1)

    # Check if valid JSON
    local log_content=$(cat "$log_file")
    echo "$log_content" | grep -q "timestamp"
    echo "$log_content" | grep -q "event"
    echo "$log_content" | grep -q "test.event"
}

@test "vibe_pipeline_start: logs pipeline start" {
    run vibe_pipeline_start "test-workflow" "Test description" 3
    assert_success
}

@test "vibe_pipeline_done: logs pipeline completion" {
    run vibe_pipeline_done "test-workflow" "success" 5000 7
    assert_success
}

@test "vibe_phase_start: logs phase start" {
    run vibe_phase_start "Test Phase" 1 3
    assert_success
}

@test "vibe_phase_done: logs phase completion" {
    run vibe_phase_done "Test Phase" 1 "success" 1000
    assert_success
}

@test "vibe_summary_done: logs summary generation" {
    run vibe_summary_done "Test summary text" "high" 5
    assert_success
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "integration: log functions with sanitize_input" {
    local input="Test integration message"
    local sanitized=$(sanitize_input "$input")

    run log_info "$sanitized"
    assert_success
    assert_output_contains "Test integration message"
}

@test "integration: timestamp generation and logging" {
    local ts=$(get_timestamp_ms)

    run log_success "Operation completed at timestamp: $ts"
    assert_success
    assert_output_contains "$ts"
}

@test "integration: VibeLogger pipeline workflow" {
    # Simulate a full pipeline workflow
    vibe_pipeline_start "test-workflow" "Integration test" 2

    vibe_phase_start "Phase 1" 1 2
    vibe_phase_done "Phase 1" 1 "success" 1000

    vibe_phase_start "Phase 2" 2 3
    vibe_phase_done "Phase 2" 2 "success" 2000

    vibe_pipeline_done "test-workflow" "success" 3000 5

    # Verify log file contains all events
    local log_file=$(ls "$VIBE_LOG_DIR"/7ai_orchestration_*.jsonl 2>/dev/null | head -1)
    assert_file_exists "$log_file"

    local log_content=$(cat "$log_file")
    echo "$log_content" | grep -q "pipeline.start"
    echo "$log_content" | grep -q "phase.start"
    echo "$log_content" | grep -q "phase.done"
    echo "$log_content" | grep -q "pipeline.done"
}

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

@test "sanitize_input: handles special characters in large input" {
    # Large input (>2KB) should allow special characters
    local large=$(printf 'Line with special: @#$%%^&*() %.0s' {1..100})

    run sanitize_input "$large"
    assert_success
}

@test "get_timestamp_ms: works across multiple calls" {
    local timestamps=()
    for i in {1..5}; do
        timestamps+=("$(get_timestamp_ms)")
        sleep 0.01
    done

    # Verify all timestamps are unique and increasing
    for ((i=1; i<5; i++)); do
        [ "${timestamps[$i]}" -gt "${timestamps[$((i-1))]}" ]
    done
}

@test "vibe_log: handles special characters in metadata" {
    run vibe_log "test" "action" '{"message":"Test with \"quotes\" and newlines\n"}' "Note" ""
    assert_success
}

@test "log functions: handle empty messages" {
    run log_info ""
    assert_success

    run log_success ""
    assert_success

    run log_warning ""
    assert_success

    run log_error ""
    assert_success
}
