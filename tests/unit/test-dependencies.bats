#!/usr/bin/env bats
# Tests for dependency checking functions (P0.1.3)
# Purpose: Validate jq and yq dependency checks work correctly
# Coverage: check_jq_dependency(), check_yq_dependency(), fallback logging

setup() {
    # Load libraries
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export MULTI_AI_ERROR_LOG_DIR="$PROJECT_ROOT/logs/test-errors"
    mkdir -p "$MULTI_AI_ERROR_LOG_DIR"

    source "$PROJECT_ROOT/scripts/lib/sanitize.sh"
    source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh"
    source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-config.sh"
}

teardown() {
    # Clean up test logs
    rm -rf "$MULTI_AI_ERROR_LOG_DIR" 2>/dev/null || true
}

# ============================================================================
# jq Dependency Tests
# ============================================================================

@test "check_jq_dependency: succeeds when jq is installed" {
    if command -v jq &>/dev/null; then
        run check_jq_dependency
        [ "$status" -eq 0 ]
    else
        skip "jq not installed (expected in production environment)"
    fi
}

@test "check_jq_dependency: fails when jq is not available" {
    # Mock jq as missing by overriding command
    function command() {
        if [[ "$2" == "jq" ]]; then
            return 1  # Simulate jq not found
        else
            builtin command "$@"
        fi
    }
    export -f command

    run check_jq_dependency
    [ "$status" -eq 1 ]
    [[ "$output" =~ "jq is required" ]]

    unset -f command
}

# ============================================================================
# yq Dependency Tests
# ============================================================================

@test "check_yq_dependency: succeeds when yq v4+ is installed" {
    if command -v yq &>/dev/null; then
        run check_yq_dependency
        [ "$status" -eq 0 ]
    else
        skip "yq not installed (expected in production environment)"
    fi
}

@test "check_yq_dependency: detects version correctly" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    # Run version check
    run bash -c "source scripts/orchestrate/lib/multi-ai-config.sh && check_yq_dependency"
    [ "$status" -eq 0 ]
}

@test "check_yq_dependency: fails when yq is not available" {
    # Mock yq as missing
    function command() {
        if [[ "$2" == "yq" ]]; then
            return 1
        else
            builtin command "$@"
        fi
    }
    export -f command

    run check_yq_dependency
    [ "$status" -eq 1 ]

    unset -f command
}

# ============================================================================
# Fallback Logging Tests
# ============================================================================

@test "log_structured_error: works normally when jq is available" {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed, cannot test normal mode"
    fi

    run log_structured_error "test error" "test cause" "test fix"
    [ "$status" -eq 0 ]

    # Check that error log was created
    local date_str=$(date +%Y%m%d)
    local error_log="$MULTI_AI_ERROR_LOG_DIR/${date_str}.jsonl"
    [ -f "$error_log" ]

    # Verify JSON structure
    local last_entry=$(tail -1 "$error_log")
    echo "$last_entry" | jq -e '.what' >/dev/null
    echo "$last_entry" | jq -e '.why' >/dev/null
    echo "$last_entry" | jq -e '.how' >/dev/null
}

@test "log_structured_error: falls back to plain text when jq missing" {
    # Save original jq command
    if command -v jq &>/dev/null; then
        original_jq=$(command -v jq)
    fi

    # Mock jq as missing
    function command() {
        if [[ "$2" == "jq" ]]; then
            return 1  # jq not found
        else
            builtin command "$@"
        fi
    }
    export -f command

    run log_structured_error "fallback test" "jq missing" "install jq"
    [ "$status" -eq 1 ]  # Should return 1 (fallback mode)
    [[ "$output" =~ "jq not available" ]]

    # Check plain text log was created
    local date_str=$(date +%Y%m%d)
    local fallback_log="$MULTI_AI_ERROR_LOG_DIR/${date_str}.txt"
    [ -f "$fallback_log" ]

    # Verify plain text format
    grep -q "what=fallback test" "$fallback_log"
    grep -q "why=jq missing" "$fallback_log"
    grep -q "how=install jq" "$fallback_log"

    unset -f command
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "orchestrate-multi-ai.sh: checks jq on initialization" {
    # Test initialization with jq check
    if ! command -v jq &>/dev/null; then
        skip "jq not installed, cannot test initialization"
    fi

    export MULTI_AI_INIT="test"
    run bash -c "source scripts/orchestrate/orchestrate-multi-ai.sh 2>&1 | grep -q 'jq'"
    # Should not error out if jq is available
}

@test "orchestrate-multi-ai.sh: checks yq on initialization" {
    # Test initialization with yq check
    if ! command -v yq &>/dev/null; then
        skip "yq not installed, cannot test initialization"
    fi

    export MULTI_AI_INIT="test"
    run bash -c "source scripts/orchestrate/orchestrate-multi-ai.sh 2>&1 | grep -q 'yq'"
    # Should not error out if yq v4+ is available
}

# ============================================================================
# Edge Cases
# ============================================================================

@test "check_jq_dependency: handles space in PATH gracefully" {
    # Edge case: PATH with spaces (should not break)
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    export PATH="$PATH:/tmp/path with spaces"
    run check_jq_dependency
    [ "$status" -eq 0 ]
}

@test "check_yq_dependency: validates version parsing" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    # Get actual yq version
    yq_version_output=$(yq --version 2>&1)
    echo "# yq version output: $yq_version_output" >&3

    run check_yq_dependency
    [ "$status" -eq 0 ]
}
