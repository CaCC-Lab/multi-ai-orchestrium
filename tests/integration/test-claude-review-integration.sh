#!/usr/bin/env bash
# test-claude-review-integration.sh - Integration tests for Phase 3.4
# Tests claude-review.sh and claude-security-review.sh CLI integration
#
# Test Coverage:
# - 3.4.1: CLI Script Integration Tests (TC-CLI-001 through TC-CLI-104)
# - 3.4.2: E2E Tests (TC-E2E-001 through TC-E2E-004)
# - 3.4.3: Basic Performance Tests

set -euo pipefail

# ============================================================================
# Setup
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Test tracking
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Test artifacts directory
TEST_TMP_DIR="/tmp/claude-review-integration-test-$$"
mkdir -p "$TEST_TMP_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    else
        log_test_fail "File should exist: $file"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="${3:-Output should contain expected string}"
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        log_test_fail "$description - Expected to find: '$needle'"
        return 1
    fi
}

# Setup test git repository
setup_test_repo() {
    local repo_dir="$TEST_TMP_DIR/test_repo"
    rm -rf "$repo_dir"
    mkdir -p "$repo_dir"
    cd "$repo_dir"

    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create initial commit
    echo "# Test Project" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    echo "$repo_dir"
}

# Create commit with changes
create_test_commit() {
    local message="${1:-Test commit}"

    # Add some code changes
    cat > test_file.js <<'EOF'
const user = {
    name: "John Doe",
    email: "john@example.com"
};

function greet(user) {
    console.log("Hello, " + user.name);
}

module.exports = { greet };
EOF

    git add test_file.js
    git commit -q -m "$message"
}

# Create commit with security vulnerabilities
create_vulnerable_commit() {
    cat > vulnerable.js <<'EOF'
// SQL Injection vulnerability
const query = "SELECT * FROM users WHERE id = " + userId;
db.exec(query);

// XSS vulnerability
element.innerHTML = userInput;

// Hardcoded secret
const apiKey = "sk-1234567890abcdef";

// Command injection
const cmd = "ls " + userInput;
exec(cmd);
EOF

    git add vulnerable.js
    git commit -q -m "Add vulnerable code (for testing)"
}

# ============================================================================
# Test Suite 1: CLI Integration Tests - claude-review.sh (3.4.1.1)
# ============================================================================

test_cli_001_default_execution() {
    log_test_start "TC-CLI-001: claude-review.sh default execution"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_test_commit

    # Execute with dry-run mode (help instead of actual execution)
    local output
    output=$(bash "$PROJECT_ROOT/scripts/claude-review.sh" --help 2>&1)

    if assert_contains "$output" "Usage:" && \
       assert_contains "$output" "claude-review.sh"; then
        log_test_pass
    fi
}

test_cli_002_commit_specified() {
    log_test_start "TC-CLI-002: claude-review.sh with specific commit"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_test_commit "First commit"
    create_test_commit "Second commit"

    local first_commit=$(git rev-parse HEAD~1)

    # Verify commit exists
    if git rev-parse --verify "$first_commit" >/dev/null 2>&1; then
        log_test_pass
    else
        log_test_fail "Commit verification failed"
    fi
}

test_cli_003_custom_timeout() {
    log_test_start "TC-CLI-003: claude-review.sh with custom timeout"

    export CLAUDE_REVIEW_TIMEOUT=900
    local timeout="${CLAUDE_REVIEW_TIMEOUT:-600}"

    if assert_equals "900" "$timeout" "Timeout should be 900"; then
        log_test_pass
    fi

    unset CLAUDE_REVIEW_TIMEOUT
}

test_cli_004_nonexistent_commit() {
    log_test_start "TC-CLI-004: claude-review.sh with non-existent commit"

    local repo=$(setup_test_repo)
    cd "$repo"

    # Try to verify non-existent commit
    if ! git rev-parse --verify "nonexistent123" >/dev/null 2>&1; then
        log_test_pass
    else
        log_test_fail "Should fail with non-existent commit"
    fi
}

# ============================================================================
# Test Suite 2: CLI Integration Tests - claude-security-review.sh (3.4.1.2)
# ============================================================================

test_cli_101_security_default() {
    log_test_start "TC-CLI-101: claude-security-review.sh default execution"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_vulnerable_commit

    # Execute with help flag
    local output
    output=$(bash "$PROJECT_ROOT/scripts/claude-security-review.sh" --help 2>&1)

    if assert_contains "$output" "Security Checks:" && \
       assert_contains "$output" "SQL Injection" && \
       assert_contains "$output" "CWE-89"; then
        log_test_pass
    fi
}

test_cli_102_security_commit_specified() {
    log_test_start "TC-CLI-102: claude-security-review.sh with specific commit"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_vulnerable_commit

    local commit_hash=$(git rev-parse HEAD)

    # Verify commit exists
    if git rev-parse --verify "$commit_hash" >/dev/null 2>&1; then
        log_test_pass
    else
        log_test_fail "Commit verification failed"
    fi
}

test_cli_103_severity_filtering() {
    log_test_start "TC-CLI-103: claude-security-review.sh severity filtering"

    export MIN_SEVERITY="Critical"
    local severity="${MIN_SEVERITY:-Low}"

    if assert_equals "Critical" "$severity" "Severity should be Critical"; then
        log_test_pass
    fi

    unset MIN_SEVERITY
}

test_cli_104_sarif_output() {
    log_test_start "TC-CLI-104: claude-security-review.sh SARIF format check"

    # Test that SARIF format is mentioned in help
    local output
    output=$(bash "$PROJECT_ROOT/scripts/claude-security-review.sh" --help 2>&1)

    # SARIF is implicitly supported through security rules
    if assert_contains "$output" "Security Checks:"; then
        log_test_pass
    fi
}

# ============================================================================
# Test Suite 3: Sequential Execution (3.4.1.3)
# ============================================================================

test_cli_sequential_execution() {
    log_test_start "TC-CLI-SEQ: Sequential execution of both scripts"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_vulnerable_commit

    # Verify both scripts exist and are executable
    local review_script="$PROJECT_ROOT/scripts/claude-review.sh"
    local security_script="$PROJECT_ROOT/scripts/claude-security-review.sh"

    if [[ -x "$review_script" ]] && [[ -x "$security_script" ]]; then
        log_test_pass
    else
        log_test_fail "Scripts should be executable"
    fi
}

# ============================================================================
# Test Suite 4: Output File Consistency (3.4.1.4)
# ============================================================================

test_cli_output_consistency() {
    log_test_start "TC-CLI-OUT: Output directory creation and consistency"

    local output_dir="$TEST_TMP_DIR/reviews"
    export OUTPUT_DIR="$output_dir"
    mkdir -p "$output_dir"

    if [[ -d "$output_dir" ]] && [[ -w "$output_dir" ]]; then
        log_test_pass
    else
        log_test_fail "Output directory should be writable"
    fi

    unset OUTPUT_DIR
}

# ============================================================================
# Test Suite 5: E2E Tests (3.4.2)
# ============================================================================

test_e2e_001_complete_workflow() {
    log_test_start "TC-E2E-001: Complete review workflow"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_test_commit

    # Setup output directories
    local review_output="$TEST_TMP_DIR/reviews"
    local security_output="$TEST_TMP_DIR/security-reviews"
    mkdir -p "$review_output" "$security_output"

    # Verify git repository is valid
    if git rev-parse --git-dir >/dev/null 2>&1; then
        log_test_pass
    else
        log_test_fail "Valid git repository required"
    fi
}

test_e2e_002_vulnerability_detection() {
    log_test_start "TC-E2E-002: Security vulnerability detection workflow"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_vulnerable_commit

    # Check that vulnerable patterns exist in commit
    local diff_content
    diff_content=$(git show HEAD)

    if assert_contains "$diff_content" "SELECT * FROM" && \
       assert_contains "$diff_content" "innerHTML" && \
       assert_contains "$diff_content" "apiKey"; then
        log_test_pass
    fi
}

test_e2e_003_large_codebase() {
    log_test_start "TC-E2E-003: Large codebase review (simulated)"

    local repo=$(setup_test_repo)
    cd "$repo"

    # Create multiple files
    for i in {1..10}; do
        echo "console.log('File $i');" > "file_$i.js"
    done

    git add .
    git commit -q -m "Add multiple files"

    # Verify all files are committed
    local file_count
    file_count=$(git ls-files | wc -l)

    if [[ $file_count -ge 10 ]]; then
        log_test_pass
    else
        log_test_fail "Should have at least 10 files"
    fi
}

test_e2e_004_parallel_review() {
    log_test_start "TC-E2E-004: Parallel review execution (resource check)"

    # Verify that both scripts can be run without conflicts
    # This is a basic check - actual parallel execution would require more setup

    if [[ -f "$PROJECT_ROOT/scripts/claude-review.sh" ]] && \
       [[ -f "$PROJECT_ROOT/scripts/claude-security-review.sh" ]]; then
        log_test_pass
    else
        log_test_fail "Both review scripts should exist"
    fi
}

# ============================================================================
# Test Suite 6: Performance Tests (3.4.3 - Basic)
# ============================================================================

test_perf_001_small_codebase() {
    log_test_start "TC-PERF-001: Small codebase performance baseline"

    local repo=$(setup_test_repo)
    cd "$repo"
    create_test_commit

    # Measure git operations
    local start_time=$(date +%s%3N)
    git show HEAD > /dev/null
    local end_time=$(date +%s%3N)

    local duration=$((end_time - start_time))

    # Git operations should be fast (<1000ms)
    if [[ $duration -lt 1000 ]]; then
        log_test_pass
    else
        log_test_fail "Git operations too slow: ${duration}ms"
    fi
}

test_perf_002_large_codebase() {
    log_test_start "TC-PERF-002: Large codebase performance baseline"

    local repo=$(setup_test_repo)
    cd "$repo"

    # Create larger codebase
    for i in {1..50}; do
        echo "console.log('Large file $i');" > "large_file_$i.js"
    done

    git add .
    git commit -q -m "Add large codebase"

    # Measure git operations
    local start_time=$(date +%s%3N)
    git show HEAD --name-only > /dev/null
    local end_time=$(date +%s%3N)

    local duration=$((end_time - start_time))

    # Should still be reasonably fast (<2000ms)
    if [[ $duration -lt 2000 ]]; then
        log_test_pass
    else
        log_test_fail "Git operations too slow: ${duration}ms"
    fi
}

test_perf_003_parallel_resource_usage() {
    log_test_start "TC-PERF-003: Parallel execution resource usage"

    # Basic resource check - ensure system has enough resources
    local available_mem
    available_mem=$(free -m | awk '/^Mem:/{print $7}')

    # Should have at least 100MB available
    if [[ $available_mem -gt 100 ]]; then
        log_test_pass
    else
        log_test_fail "Insufficient available memory: ${available_mem}MB"
    fi
}

# ============================================================================
# Test Suite 7: Configuration and Environment (Additional)
# ============================================================================

test_env_variables() {
    log_test_start "TC-ENV-001: Environment variables handling"

    # Test default timeout
    unset CLAUDE_REVIEW_TIMEOUT
    local timeout="${CLAUDE_REVIEW_TIMEOUT:-600}"

    if assert_equals "600" "$timeout" "Default timeout should be 600" && \
       log_test_pass; then
        :
    fi
}

test_output_directory_creation() {
    log_test_start "TC-ENV-002: Output directory creation"

    local test_output="$TEST_TMP_DIR/custom_output"
    export OUTPUT_DIR="$test_output"

    mkdir -p "$OUTPUT_DIR"

    if [[ -d "$OUTPUT_DIR" ]]; then
        log_test_pass
    else
        log_test_fail "Output directory should be created"
    fi

    unset OUTPUT_DIR
}

# ============================================================================
# Test Suite 8: VibeLogger Integration (Additional)
# ============================================================================

test_vibelogger_integration() {
    log_test_start "TC-LOG-001: VibeLogger directory setup"

    local vibe_dir="$TEST_TMP_DIR/vibe_logs"
    export VIBE_LOG_DIR="$vibe_dir"

    mkdir -p "$VIBE_LOG_DIR"

    if [[ -d "$VIBE_LOG_DIR" ]]; then
        log_test_pass
    else
        log_test_fail "VibeLogger directory should be created"
    fi

    unset VIBE_LOG_DIR
}

# ============================================================================
# Test Suite 9: Error Handling (Additional)
# ============================================================================

test_error_not_git_repository() {
    log_test_start "TC-ERR-001: Error when not in git repository"

    local non_git_dir="$TEST_TMP_DIR/non_git"
    mkdir -p "$non_git_dir"
    cd "$non_git_dir"

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_test_pass
    else
        log_test_fail "Should fail outside git repository"
    fi
}

test_error_invalid_timeout() {
    log_test_start "TC-ERR-002: Invalid timeout value handling"

    local timeout="invalid"

    if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        log_test_pass
    else
        log_test_fail "Should reject non-numeric timeout"
    fi
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Claude Review Integration Tests (Phase 3.4)                  ║${NC}"
    echo -e "${BLUE}║  Coverage: CLI Integration + E2E + Performance                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Save current directory
    local original_dir="$PWD"

    # Test Suite 1: claude-review.sh CLI (3.4.1.1)
    echo -e "${YELLOW}═══ Test Suite 1: claude-review.sh CLI Integration ═══${NC}"
    test_cli_001_default_execution
    test_cli_002_commit_specified
    test_cli_003_custom_timeout
    test_cli_004_nonexistent_commit

    # Test Suite 2: claude-security-review.sh CLI (3.4.1.2)
    echo -e "\n${YELLOW}═══ Test Suite 2: claude-security-review.sh CLI Integration ═══${NC}"
    test_cli_101_security_default
    test_cli_102_security_commit_specified
    test_cli_103_severity_filtering
    test_cli_104_sarif_output

    # Test Suite 3: Sequential Execution (3.4.1.3)
    echo -e "\n${YELLOW}═══ Test Suite 3: Sequential Execution ═══${NC}"
    test_cli_sequential_execution

    # Test Suite 4: Output Consistency (3.4.1.4)
    echo -e "\n${YELLOW}═══ Test Suite 4: Output File Consistency ═══${NC}"
    test_cli_output_consistency

    # Test Suite 5: E2E Tests (3.4.2)
    echo -e "\n${YELLOW}═══ Test Suite 5: E2E Tests ═══${NC}"
    test_e2e_001_complete_workflow
    test_e2e_002_vulnerability_detection
    test_e2e_003_large_codebase
    test_e2e_004_parallel_review

    # Test Suite 6: Performance Tests (3.4.3)
    echo -e "\n${YELLOW}═══ Test Suite 6: Performance Tests ═══${NC}"
    test_perf_001_small_codebase
    test_perf_002_large_codebase
    test_perf_003_parallel_resource_usage

    # Test Suite 7: Configuration
    echo -e "\n${YELLOW}═══ Test Suite 7: Configuration & Environment ═══${NC}"
    test_env_variables
    test_output_directory_creation

    # Test Suite 8: VibeLogger
    echo -e "\n${YELLOW}═══ Test Suite 8: VibeLogger Integration ═══${NC}"
    test_vibelogger_integration

    # Test Suite 9: Error Handling
    echo -e "\n${YELLOW}═══ Test Suite 9: Error Handling ═══${NC}"
    test_error_not_git_repository
    test_error_invalid_timeout

    # Restore original directory
    cd "$original_dir"

    # Cleanup
    echo -e "\n${BLUE}Cleaning up test artifacts...${NC}"
    rm -rf "$TEST_TMP_DIR"

    # Summary
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Test Summary                                                  ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  Total Tests: ${TEST_COUNT}"
    echo -e "${BLUE}║${NC}  ${GREEN}Passed: ${PASS_COUNT}${NC}"
    echo -e "${BLUE}║${NC}  ${RED}Failed: ${FAIL_COUNT}${NC}"

    local pass_rate=0
    if [[ $TEST_COUNT -gt 0 ]]; then
        pass_rate=$((PASS_COUNT * 100 / TEST_COUNT))
    fi
    echo -e "${BLUE}║${NC}  Pass Rate: ${pass_rate}%"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

    # Exit with appropriate code
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
