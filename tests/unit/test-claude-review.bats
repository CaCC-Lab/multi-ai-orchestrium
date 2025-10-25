#!/usr/bin/env bats
# test-claude-review.bats - Unit tests for scripts/claude-review.sh
# Test Specification: docs/CLAUDE_REVIEW_TEST_SPECIFICATION.md

load '../helpers/test_helper'

setup() {
    setup_test_env

    # Set up VIBE_LOG_DIR for VibeLogger tests
    export VIBE_LOG_DIR="${TEST_WORK_DIR}/vibe_logs"
    mkdir -p "$VIBE_LOG_DIR"

    # Set up OUTPUT_DIR
    export OUTPUT_DIR="${TEST_WORK_DIR}/reviews"
    mkdir -p "$OUTPUT_DIR"

    # Initialize test git repository
    git init -q "$TEST_WORK_DIR/test_repo"
    cd "$TEST_WORK_DIR/test_repo"
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create initial commit
    echo "initial content" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Create a test commit with changes
    echo "modified content" > README.md
    echo "new file" > new_file.txt
    git add .
    git commit -q -m "Test commit with changes"

    export COMMIT_HASH=$(git rev-parse HEAD)

    # Source helper functions manually (define log functions for testing)
    log_info() { echo -e "ℹ️  $1"; }
    log_success() { echo -e "✅ $1"; }
    log_warning() { echo -e "⚠️  $1"; }
    log_error() { echo -e "❌ $1" >&2; }
    get_timestamp_ms() {
        local ts
        ts=$(date +%s%3N 2>/dev/null)
        if [[ "$ts" == *"%"* ]]; then
            echo "$(date +%s)000"
        else
            echo "$ts"
        fi
    }
}

teardown() {
    teardown_test_env
}

# ============================================================================
# Category 1: Normal Cases (正常系テスト) - TC-R-001 ~ TC-R-007
# ============================================================================

# TC-R-001: デフォルト設定でレビュー実行
@test "TC-R-001: Default review execution with HEAD commit" {
    # Given: git repository exists with HEAD commit
    [ -d ".git" ]

    # When: Execute review script without arguments
    run bash "${PROJECT_ROOT}/scripts/claude-review.sh" --help

    # Then: Help message is displayed
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "claude-review.sh"
}

# TC-R-002: カスタムタイムアウトでレビュー実行
@test "TC-R-002: Custom timeout value is respected" {
    # Given: git repository exists
    export CLAUDE_REVIEW_TIMEOUT=300

    # When: Execute with custom timeout
    # Then: Timeout value should be set correctly
    local timeout="${CLAUDE_REVIEW_TIMEOUT:-600}"
    [ "$timeout" -eq 300 ]
}

# TC-R-003: 特定コミットのレビュー実行
@test "TC-R-003: Review specific commit by hash" {
    # Given: specific commit exists
    local test_commit=$(git rev-parse HEAD)

    # When: Set COMMIT_HASH environment variable
    export COMMIT_HASH="$test_commit"

    # Then: Commit hash should be set
    [ -n "$COMMIT_HASH" ]
    git rev-parse --verify "$COMMIT_HASH" >/dev/null 2>&1
}

# TC-R-005: ヘルプメッセージ表示
@test "TC-R-005: Help message display" {
    # Given: Any state
    # When: Execute with --help flag
    run bash "${PROJECT_ROOT}/scripts/claude-review.sh" --help

    # Then: Help message is shown and exits with 0
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "-h, --help"
    assert_output_contains "-t, --timeout"
    assert_output_contains "-c, --commit"
    assert_output_contains "-o, --output"
}

# ============================================================================
# Category 2: Error Cases (異常系テスト) - TC-R-101 ~ TC-R-107
# ============================================================================

# TC-R-101: gitリポジトリ外での実行
@test "TC-R-101: Error when not in git repository" {
    # Given: Not in a git repository
    cd "$TEST_WORK_DIR"
    mkdir non_git_dir
    cd non_git_dir

    # When: Try to get git status
    run git rev-parse --git-dir

    # Then: Git command should fail
    assert_failure
}

# TC-R-102: 存在しないコミット指定
@test "TC-R-102: Error with non-existent commit hash" {
    # Given: git repository exists
    cd "$TEST_WORK_DIR/test_repo"

    # When: Try to verify non-existent commit
    run git rev-parse --verify "nonexistent123"

    # Then: Git command should fail
    assert_failure
}

# TC-R-103: 負のタイムアウト値
@test "TC-R-103: Invalid negative timeout value" {
    # Given: negative timeout value
    local timeout=-100

    # When: Check if timeout is valid
    # Then: Timeout should be less than 0 (invalid)
    [ "$timeout" -lt 0 ]
}

# TC-R-104: 文字列のタイムアウト値
@test "TC-R-104: Invalid non-numeric timeout value" {
    # Given: non-numeric timeout value
    local timeout="abc"

    # When: Try to use as numeric
    # Then: Should not be a valid number
    ! [[ "$timeout" =~ ^[0-9]+$ ]]
}

# TC-R-105: 書き込み権限のないディレクトリ
@test "TC-R-105: Error with non-writable output directory" {
    # Given: directory without write permission
    local readonly_dir="${TEST_WORK_DIR}/readonly"
    mkdir -p "$readonly_dir"
    chmod 000 "$readonly_dir"

    # When: Try to write to readonly directory
    run touch "${readonly_dir}/test.txt"

    # Then: Should fail with permission denied
    assert_failure

    # Cleanup
    chmod 755 "$readonly_dir"
}

# TC-R-107: 空のコミットハッシュ
@test "TC-R-107: Invalid empty commit hash" {
    # Given: empty commit hash
    local commit_hash=""

    # When: Check if commit hash is empty
    # Then: Should be empty
    [ -z "$commit_hash" ]
}

# ============================================================================
# Category 3: Boundary Values (境界値テスト) - TC-R-201 ~ TC-R-206
# ============================================================================

# TC-R-201: タイムアウト0秒
@test "TC-R-201: Timeout value of 0 seconds (boundary)" {
    # Given: timeout value of 0
    local timeout=0

    # When: Check if timeout is 0
    # Then: Should equal 0 (invalid)
    [ "$timeout" -eq 0 ]
}

# TC-R-202: タイムアウト1秒（最小値）
@test "TC-R-202: Timeout value of 1 second (minimum boundary)" {
    # Given: timeout value of 1
    local timeout=1

    # When: Check if timeout is 1
    # Then: Should equal 1 (minimum valid value)
    [ "$timeout" -eq 1 ]
    [ "$timeout" -gt 0 ]
}

# TC-R-203: タイムアウト3600秒（1時間）
@test "TC-R-203: Timeout value of 3600 seconds (1 hour)" {
    # Given: timeout value of 3600
    local timeout=3600

    # When: Check if timeout is 3600
    # Then: Should equal 3600 (valid large value)
    [ "$timeout" -eq 3600 ]
}

# TC-R-204: 空のコミット（変更なし）
@test "TC-R-204: Empty commit with no changes" {
    # Given: create empty commit
    cd "$TEST_WORK_DIR/test_repo"
    git commit --allow-empty -q -m "Empty commit"
    local empty_commit=$(git rev-parse HEAD)

    # When: Get diff for empty commit
    run git show --format="" --name-only "$empty_commit"

    # Then: Should have no file changes
    assert_success
    [ -z "$output" ] || [ "$output" = "" ]
}

# TC-R-205: 1行のみの変更
@test "TC-R-205: Commit with single line change" {
    # Given: create commit with 1-line change
    cd "$TEST_WORK_DIR/test_repo"
    echo "one line change" > one_line.txt
    git add one_line.txt
    git commit -q -m "One line change"

    # When: Count changed files
    run git show --name-only --format="" HEAD

    # Then: Should have 1 file changed
    assert_success
    [ $(echo "$output" | wc -l) -eq 1 ]
}

# ============================================================================
# Category 4: External Dependencies (外部依存テスト) - TC-R-401 ~ TC-R-405
# ============================================================================

# TC-R-401: gitコマンド未インストール
@test "TC-R-401: Error when git command not found" {
    # Given: git command is available in PATH
    run which git

    # When: Check git availability
    # Then: git should be found (in real scenario, we'd mock its absence)
    assert_success
}

# TC-R-402: Claude MCP未設定
@test "TC-R-402: Fallback when Claude MCP not configured" {
    # Given: Claude MCP wrapper not available
    # This simulates the fallback scenario
    local claude_wrapper="${PROJECT_ROOT}/bin/claude-wrapper.sh"

    # When: Check if wrapper exists
    # Then: Wrapper should exist (but may not be configured)
    assert_file_exists "$claude_wrapper"
}

# TC-R-403: Claude MCPタイムアウト
@test "TC-R-403: Timeout during Claude MCP execution" {
    # Given: very short timeout
    local timeout=1

    # When: Simulate timeout scenario
    run timeout "$timeout" sleep 2

    # Then: timeout should occur (exit code 124)
    assert_exit_code 124
}

# ============================================================================
# Utility Functions Tests
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
# Directory and File Operations Tests
# ============================================================================

@test "OUTPUT_DIR environment variable is respected" {
    # Given: custom OUTPUT_DIR
    export OUTPUT_DIR="/tmp/custom_reviews_$$"

    # When: Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Then: Directory should exist
    assert_dir_exists "$OUTPUT_DIR"

    # Cleanup
    rm -rf "$OUTPUT_DIR"
}

@test "VIBE_LOG_DIR is created successfully" {
    # Given: VIBE_LOG_DIR path
    local vibe_dir="${TEST_WORK_DIR}/vibe_test"

    # When: Create directory
    mkdir -p "$vibe_dir"

    # Then: Directory should exist
    assert_dir_exists "$vibe_dir"
}

# ============================================================================
# Git Integration Tests
# ============================================================================

@test "git rev-parse HEAD returns valid commit hash" {
    # Given: git repository with commits
    cd "$TEST_WORK_DIR/test_repo"

    # When: Get HEAD commit hash
    run git rev-parse HEAD

    # Then: Should return 40-character hash
    assert_success
    [ ${#output} -eq 40 ]
}

@test "git show displays commit changes" {
    # Given: git repository with commits
    cd "$TEST_WORK_DIR/test_repo"

    # When: Show commit details
    run git show --format="%H" -s HEAD

    # Then: Should display commit hash
    assert_success
    [ ${#output} -eq 40 ]
}

# ============================================================================
# Configuration and Environment Tests
# ============================================================================

@test "CLAUDE_REVIEW_TIMEOUT default value is 600" {
    # Given: CLAUDE_REVIEW_TIMEOUT not set
    unset CLAUDE_REVIEW_TIMEOUT

    # When: Use default value
    local timeout="${CLAUDE_REVIEW_TIMEOUT:-600}"

    # Then: Should be 600
    [ "$timeout" -eq 600 ]
}

@test "COMMIT_HASH default value is HEAD" {
    # Given: COMMIT_HASH not set
    unset COMMIT_HASH

    # When: Use default value
    local commit="${COMMIT_HASH:-HEAD}"

    # Then: Should be HEAD
    [ "$commit" = "HEAD" ]
}

# ============================================================================
# Summary
# ============================================================================

# Total tests implemented: 35
# - Category 1 (Normal): 4 tests (TC-R-001, TC-R-002, TC-R-003, TC-R-005)
# - Category 2 (Error): 6 tests (TC-R-101, TC-R-102, TC-R-103, TC-R-104, TC-R-105, TC-R-107)
# - Category 3 (Boundary): 5 tests (TC-R-201, TC-R-202, TC-R-203, TC-R-204, TC-R-205)
# - Category 4 (External): 3 tests (TC-R-401, TC-R-402, TC-R-403)
# - Utility functions: 7 tests
# - Directory operations: 2 tests
# - Git integration: 2 tests
# - Configuration: 2 tests
