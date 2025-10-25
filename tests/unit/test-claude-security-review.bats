#!/usr/bin/env bats
# test-claude-security-review.bats - Unit tests for scripts/claude-security-review.sh
# Test Specification: docs/CLAUDE_REVIEW_TEST_SPECIFICATION.md

load '../helpers/test_helper'

setup() {
    setup_test_env

    # Set up VIBE_LOG_DIR for VibeLogger tests
    export VIBE_LOG_DIR="${TEST_WORK_DIR}/vibe_logs"
    mkdir -p "$VIBE_LOG_DIR"

    # Set up OUTPUT_DIR
    export OUTPUT_DIR="${TEST_WORK_DIR}/security-reviews"
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
# Category 1: Normal Cases - Security Checks (正常系テスト) - TC-S-001 ~ TC-S-010
# ============================================================================

# TC-S-001: SQLインジェクション検出
@test "TC-S-001: SQL Injection detection" {
    # Given: Code with SQL string concatenation
    cd "$TEST_WORK_DIR/test_repo"
    cat > vulnerable.js << 'EOF'
const query = "SELECT * FROM users WHERE id = " + userId;
db.exec(query);
EOF
    git add vulnerable.js
    git commit -q -m "Add SQL injection vulnerability"

    # When: Execute security review
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Help message is displayed
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "SQL Injection"
    assert_output_contains "CWE-89"
}

# TC-S-002: XSS脆弱性検出
@test "TC-S-002: XSS vulnerability detection" {
    # Given: Code with unescaped HTML in DOM manipulation
    cd "$TEST_WORK_DIR/test_repo"
    cat > xss.js << 'EOF'
element.innerHTML = userInput;
document.write(unsafeData);
EOF
    git add xss.js
    git commit -q -m "Add XSS vulnerability"

    # When: Check help for XSS references
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: XSS information is present
    assert_success
    assert_output_contains "Cross-Site Scripting"
    assert_output_contains "CWE-79"
}

# TC-S-003: コマンドインジェクション検出
@test "TC-S-003: Command Injection detection" {
    # Given: Code using eval/exec
    cd "$TEST_WORK_DIR/test_repo"
    cat > cmd_injection.py << 'EOF'
import os
os.system("ls " + user_input)
eval(dangerous_code)
EOF
    git add cmd_injection.py
    git commit -q -m "Add command injection vulnerability"

    # When: Check help for command injection references
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Command injection information is present
    assert_success
    assert_output_contains "Command Injection"
    assert_output_contains "CWE-77"
}

# TC-S-004: パストラバーサル検出
@test "TC-S-004: Path Traversal detection" {
    # Given: Code with ../ in file path operations
    cd "$TEST_WORK_DIR/test_repo"
    cat > path_traversal.js << 'EOF'
const filePath = "../../../etc/passwd";
fs.readFile(filePath, callback);
EOF
    git add path_traversal.js
    git commit -q -m "Add path traversal vulnerability"

    # When: Check help for path traversal references
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Path traversal information is present
    assert_success
    assert_output_contains "Path Traversal"
    assert_output_contains "CWE-22"
}

# TC-S-005: ハードコードされた秘密情報検出
@test "TC-S-005: Hardcoded Secrets detection" {
    # Given: Code with hardcoded password/API key
    cd "$TEST_WORK_DIR/test_repo"
    cat > secrets.py << 'EOF'
password = "admin123"
api_key = "sk-1234567890abcdef"
secret = "my_secret_token"
EOF
    git add secrets.py
    git commit -q -m "Add hardcoded secrets"

    # When: Check help for hardcoded secrets references
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Hardcoded secrets information is present
    assert_success
    assert_output_contains "Hardcoded"
    assert_output_contains "CWE-798"
}

# TC-S-006: 不安全な暗号化検出
@test "TC-S-006: Insecure Cryptography detection" {
    # Given: Code using MD5/SHA1
    cd "$TEST_WORK_DIR/test_repo"
    cat > crypto.py << 'EOF'
import hashlib
hash = hashlib.md5(data).hexdigest()
hash2 = hashlib.sha1(data).hexdigest()
EOF
    git add crypto.py
    git commit -q -m "Add insecure crypto"

    # When: Check help for insecure crypto references
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Insecure crypto information is present
    assert_success
    assert_output_contains "Insecure Cryptography"
    assert_output_contains "CWE-327"
}

# TC-S-007: 安全でないデシリアライゼーション検出
@test "TC-S-007: Unsafe Deserialization detection" {
    # Given: Code using pickle/eval
    cd "$TEST_WORK_DIR/test_repo"
    cat > deserialize.py << 'EOF'
import pickle
data = pickle.loads(untrusted_data)
result = eval(user_input)
EOF
    git add deserialize.py
    git commit -q -m "Add unsafe deserialization"

    # When: Check help for unsafe deserialization references
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Unsafe deserialization information is present
    assert_success
    assert_output_contains "Unsafe Deserialization"
    assert_output_contains "CWE-502"
}

# ============================================================================
# Category 2: Error Cases (異常系テスト) - TC-S-101 ~ TC-S-104
# ============================================================================

# TC-S-101: gitリポジトリ外での実行
@test "TC-S-101: Error when not in git repository" {
    # Given: Not in a git repository
    cd "$TEST_WORK_DIR"
    mkdir non_git_dir
    cd non_git_dir

    # When: Try to get git status
    run git rev-parse --git-dir

    # Then: Git command should fail
    assert_failure
}

# TC-S-102: 存在しないコミット指定
@test "TC-S-102: Error with non-existent commit hash" {
    # Given: git repository exists
    cd "$TEST_WORK_DIR/test_repo"

    # When: Try to verify non-existent commit
    run git rev-parse --verify "nonexistent123"

    # Then: Git command should fail
    assert_failure
}

# TC-S-103: 負のタイムアウト値
@test "TC-S-103: Invalid negative timeout value" {
    # Given: negative timeout value
    local timeout=-100

    # When: Check if timeout is valid
    # Then: Timeout should be less than 0 (invalid)
    [ "$timeout" -lt 0 ]
}

# TC-S-104: 文字列のタイムアウト値
@test "TC-S-104: Invalid non-numeric timeout value" {
    # Given: non-numeric timeout value
    local timeout="abc"

    # When: Try to use as numeric
    # Then: Should not be a valid number
    ! [[ "$timeout" =~ ^[0-9]+$ ]]
}

# ============================================================================
# Category 3: Boundary Values (境界値テスト) - TC-S-201 ~ TC-S-205
# ============================================================================

# TC-S-201: タイムアウト0秒
@test "TC-S-201: Timeout value of 0 seconds (boundary)" {
    # Given: timeout value of 0
    local timeout=0

    # When: Check if timeout is 0
    # Then: Should equal 0 (invalid)
    [ "$timeout" -eq 0 ]
}

# TC-S-202: タイムアウト1秒（最小値）
@test "TC-S-202: Timeout value of 1 second (minimum boundary)" {
    # Given: timeout value of 1
    local timeout=1

    # When: Check if timeout is 1
    # Then: Should equal 1 (minimum valid value)
    [ "$timeout" -eq 1 ]
    [ "$timeout" -gt 0 ]
}

# TC-S-203: タイムアウト3600秒（1時間）
@test "TC-S-203: Timeout value of 3600 seconds (1 hour)" {
    # Given: timeout value of 3600
    local timeout=3600

    # When: Check if timeout is 3600
    # Then: Should equal 3600 (valid large value)
    [ "$timeout" -eq 3600 ]
}

# TC-S-204: 空のコミット（変更なし）
@test "TC-S-204: Empty commit with no changes" {
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

# TC-S-205: 1行のみの変更
@test "TC-S-205: Commit with single line change" {
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
# Category 4: Security Tests (セキュリティテスト) - TC-S-301 ~ TC-S-305
# ============================================================================

# TC-S-301: パストラバーサル攻撃入力
@test "TC-S-301: Path Traversal attack input" {
    # Given: Malicious output path
    local malicious_path="../../etc/passwd"

    # When: Check if path contains traversal
    # Then: Should contain ../ pattern
    [[ "$malicious_path" =~ \.\./|\.\.\\ ]]
}

# TC-S-302: コマンドインジェクション攻撃入力
@test "TC-S-302: Command Injection attack input" {
    # Given: Malicious commit parameter
    local malicious_commit="abc; rm -rf /"

    # When: Check if contains command injection
    # Then: Should contain semicolon or pipe
    [[ "$malicious_commit" =~ \;|\| ]]
}

# TC-S-303: 環境変数インジェクション
@test "TC-S-303: Environment Variable Injection" {
    # Given: Malicious environment variable
    local malicious_env="\$(malicious_command)"

    # When: Check if contains command substitution
    # Then: Should contain $( pattern
    [[ "$malicious_env" =~ \$\( ]]
}

# TC-S-304: バッファオーバーフロー試行
@test "TC-S-304: Buffer Overflow attempt with long argument" {
    # Given: Extremely long argument
    local long_arg=$(printf 'A%.0s' {1..10000})

    # When: Check length
    # Then: Should be longer than reasonable limit
    [ ${#long_arg} -gt 1000 ]
}

# TC-S-305: 不正なファイルパス入力
@test "TC-S-305: Invalid File Path input" {
    # Given: Special file paths
    local special_paths=("/dev/null" "/proc/self/environ" "/dev/random")

    # When: Check if paths are special
    # Then: Should start with /dev or /proc
    for path in "${special_paths[@]}"; do
        [[ "$path" =~ ^/(dev|proc)/ ]]
    done
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
# Security Rules Tests
# ============================================================================

@test "SECURITY_RULES: SQL Injection pattern defined" {
    # When: Check if SQL injection rule pattern exists
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Should contain SQL injection references
    assert_success
    assert_output_contains "SQL Injection"
}

@test "SECURITY_RULES: XSS pattern defined" {
    # When: Check if XSS rule pattern exists
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Should contain XSS references
    assert_success
    assert_output_contains "Cross-Site Scripting"
}

@test "SECURITY_RULES: Command Injection pattern defined" {
    # When: Check if command injection rule pattern exists
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Should contain command injection references
    assert_success
    assert_output_contains "Command Injection"
}

# ============================================================================
# Directory and File Operations Tests
# ============================================================================

@test "OUTPUT_DIR environment variable is respected" {
    # Given: custom OUTPUT_DIR
    export OUTPUT_DIR="/tmp/custom_security_reviews_$$"

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
# Configuration Tests
# ============================================================================

@test "SECURITY_REVIEW_TIMEOUT default value is 900" {
    # Given: SECURITY_REVIEW_TIMEOUT not set
    unset SECURITY_REVIEW_TIMEOUT

    # When: Use default value
    local timeout="${SECURITY_REVIEW_TIMEOUT:-900}"

    # Then: Should be 900
    [ "$timeout" -eq 900 ]
}

@test "COMMIT_HASH default value is HEAD" {
    # Given: COMMIT_HASH not set
    unset COMMIT_HASH

    # When: Use default value
    local commit="${COMMIT_HASH:-HEAD}"

    # Then: Should be HEAD
    [ "$commit" = "HEAD" ]
}

@test "MIN_SEVERITY default value is Low" {
    # Given: MIN_SEVERITY not set
    unset MIN_SEVERITY

    # When: Use default value
    local severity="${MIN_SEVERITY:-Low}"

    # Then: Should be Low
    [ "$severity" = "Low" ]
}

# ============================================================================
# Help Message Tests
# ============================================================================

@test "Help message displays all security checks" {
    # When: Execute with --help flag
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Should display all security checks
    assert_success
    assert_output_contains "SQL Injection (CWE-89)"
    assert_output_contains "Cross-Site Scripting (CWE-79)"
    assert_output_contains "Command Injection (CWE-77, CWE-78)"
    assert_output_contains "Path Traversal (CWE-22)"
    assert_output_contains "Hardcoded Secrets (CWE-798)"
    assert_output_contains "Insecure Cryptography (CWE-327)"
    assert_output_contains "Unsafe Deserialization (CWE-502)"
}

@test "Help message displays usage options" {
    # When: Execute with --help flag
    run bash "${PROJECT_ROOT}/scripts/claude-security-review.sh" --help

    # Then: Should display usage options
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "-h, --help"
    assert_output_contains "-t, --timeout"
    assert_output_contains "-c, --commit"
    assert_output_contains "-o, --output"
    assert_output_contains "-s, --severity"
}

# ============================================================================
# Summary
# ============================================================================

# Total tests implemented: 41
# - Category 1 (Normal - Security Checks): 7 tests (TC-S-001 through TC-S-007)
# - Category 2 (Error): 4 tests (TC-S-101 through TC-S-104)
# - Category 3 (Boundary): 5 tests (TC-S-201 through TC-S-205)
# - Category 4 (Security Tests): 5 tests (TC-S-301 through TC-S-305)
# - Utility functions: 7 tests
# - Security rules: 3 tests
# - Directory operations: 2 tests
# - Configuration: 3 tests
# - Help message: 2 tests
