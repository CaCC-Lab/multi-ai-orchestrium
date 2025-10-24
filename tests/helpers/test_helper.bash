#!/usr/bin/env bash
# test_helper.bash - Common setup for all bats unit tests

# Load bats-support and bats-assert libraries
BATS_SUPPORT_PATH="${BATS_SUPPORT_PATH:-$HOME/.nvm/versions/node/v22.18.0/lib/node_modules/bats-support}"
BATS_ASSERT_PATH="${BATS_ASSERT_PATH:-$HOME/.nvm/versions/node/v22.18.0/lib/node_modules/bats-assert}"

load "$BATS_SUPPORT_PATH/load"
load "$BATS_ASSERT_PATH/load"

# Project root directory
export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

# Test fixtures directory
export TEST_FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"

# Temporary directory for test artifacts
export TEST_TEMP="${BATS_TEST_TMPDIR}"

# Common setup function
setup_test_env() {
    # Create temporary test directory
    export TEST_WORK_DIR="${TEST_TEMP}/work_$$_${BATS_TEST_NUMBER}"
    mkdir -p "$TEST_WORK_DIR"
    cd "$TEST_WORK_DIR" || exit 1
}

# Common teardown function
teardown_test_env() {
    # Clean up temporary test directory
    if [ -d "$TEST_WORK_DIR" ]; then
        rm -rf "$TEST_WORK_DIR"
    fi
}

# Mock command helper
mock_command() {
    local cmd_name="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"

    # Create mock script in PATH
    local mock_path="${TEST_WORK_DIR}/bin"
    mkdir -p "$mock_path"

    cat > "${mock_path}/${cmd_name}" <<MOCK_SCRIPT
#!/bin/bash
echo "$mock_output"
exit $mock_exit_code
MOCK_SCRIPT

    chmod +x "${mock_path}/${cmd_name}"
    export PATH="${mock_path}:${PATH}"
}

# Source library under test helper
source_lib() {
    local lib_path="$1"

    # Disable errexit for sourcing (some libs have intentional errors in tests)
    set +e
    source "${PROJECT_ROOT}/${lib_path}"
    set -e
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    [ -f "$file" ] || fail "Expected file '$file' to exist"
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    [ -d "$dir" ] || fail "Expected directory '$dir' to exist"
}

# Assert output contains substring
assert_output_contains() {
    local substring="$1"
    [[ "$output" == *"$substring"* ]] || fail "Expected output to contain '$substring', got: $output"
}

# Assert exit code
assert_exit_code() {
    local expected="$1"
    [ "$status" -eq "$expected" ] || fail "Expected exit code $expected, got: $status"
}
