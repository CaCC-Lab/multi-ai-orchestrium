#!/usr/bin/env bash
# Phase 1 Integration Test - Simplified version for quick verification
# This tests the actual implementation without complex test framework

set +e  # Allow test failures without exiting script
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Setup
PROJECT_ROOT="/home/ryu/projects/multi-ai-orchestrium"
TEST_TMP_DIR=$(mktemp -d /tmp/phase1-integration-XXXXXX)
export TMPDIR="$TEST_TMP_DIR"

# Source implementation
cd "$PROJECT_ROOT"
source scripts/orchestrate/lib/multi-ai-core.sh
source scripts/orchestrate/lib/multi-ai-ai-interface.sh

# Reset error handling after sourcing (sourced scripts have set -euo pipefail)
set +e
set +u
set -o pipefail

# Mock functions
log_info() { echo "INFO: $*" >&2; }  # Output to stderr so tests can capture it
log_success() { :; }
log_warning() { echo "WARN: $*" >&2; }
log_error() { echo "ERROR: $*" >&2; }
check_ai_with_details() {
    case "$1" in
        claude|gemini|qwen|codex|cursor|amp|droid) return 0 ;;
        *) return 1 ;;
    esac
}

# Test counter
PASS=0
FAIL=0

# Test helper
test_case() {
    local name="$1"
    echo -n "  Testing: $name ... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
}

fail() {
    local msg="${1:-}"
    echo -e "${RED}FAIL${NC}"
    if [ -n "$msg" ]; then
        echo "    Error: $msg"
    fi
    ((FAIL++))
}

echo "================================"
echo "Phase 1 Integration Test"
echo "================================"
echo ""

# Test 1: supports_file_input()
test_case "supports_file_input(claude)"
if supports_file_input "claude"; then
    pass
else
    fail "claude should support file input"
fi

test_case "supports_file_input(qwen)"
if ! supports_file_input "qwen"; then
    pass
else
    fail "qwen should NOT support file input"
fi

test_case "supports_file_input(unknown)"
if ! supports_file_input "unknown_ai"; then
    pass
else
    fail "unknown_ai should NOT support file input"
fi

# Test 2: create_secure_prompt_file()
test_case "create_secure_prompt_file(basic)"
prompt_file=$(create_secure_prompt_file "claude" "test prompt")
if [ -f "$prompt_file" ] && [ "$(cat "$prompt_file")" = "test prompt" ]; then
    pass
    rm -f "$prompt_file"
else
    fail "file not created or content mismatch"
fi

test_case "create_secure_prompt_file(permissions)"
prompt_file=$(create_secure_prompt_file "gemini" "secure test")
perm=$(stat -c %a "$prompt_file" 2>/dev/null || stat -f %A "$prompt_file" 2>/dev/null)
if [ "$perm" = "600" ]; then
    pass
    rm -f "$prompt_file"
else
    fail "permissions are $perm, expected 600"
    rm -f "$prompt_file"
fi

test_case "create_secure_prompt_file(markdown with backticks)"
markdown_content='```bash
echo "test"
```'
prompt_file=$(create_secure_prompt_file "qwen" "$markdown_content")
if [ -f "$prompt_file" ] && grep -q '```bash' "$prompt_file"; then
    pass
    rm -f "$prompt_file"
else
    fail "markdown backticks not preserved"
    rm -f "$prompt_file" 2>/dev/null || true
fi

# Test 3: cleanup_prompt_file()
test_case "cleanup_prompt_file(existing)"
temp_file="$TEST_TMP_DIR/test_cleanup.txt"
echo "test" > "$temp_file"
cleanup_prompt_file "$temp_file"
if [ ! -f "$temp_file" ]; then
    pass
else
    fail "file not deleted"
fi

test_case "cleanup_prompt_file(nonexistent)"
if cleanup_prompt_file "/tmp/nonexistent_file_xyz.txt"; then
    pass
else
    fail "should be idempotent"
fi

test_case "cleanup_prompt_file(empty string)"
if cleanup_prompt_file ""; then
    pass
else
    fail "should handle empty string"
fi

# Test 4: sanitize_input()
test_case "sanitize_input(normal string)"
result=$(sanitize_input "hello world")
if [ "$result" = "hello world" ]; then
    pass
else
    fail "normal string should pass"
fi

test_case "sanitize_input(backticks)"
result=$(sanitize_input '`code`')
if [ "$?" -eq 0 ] && echo "$result" | grep -q '`'; then
    pass
else
    fail "backticks should be allowed after Phase 1.2"
fi

test_case "sanitize_input(semicolon)"
if ! sanitize_input "cmd;rm" >/dev/null 2>&1; then
    pass
else
    fail "semicolon should be rejected"
fi

test_case "sanitize_input(pipe)"
if ! sanitize_input "cmd|grep" >/dev/null 2>&1; then
    pass
else
    fail "pipe should be rejected"
fi

test_case "sanitize_input(2000 chars)"
long_input=$(head -c 2000 /dev/zero | tr '\0' 'x')
if sanitize_input "$long_input" >/dev/null 2>&1; then
    pass
else
    fail "2000 chars should be accepted"
fi

test_case "sanitize_input(2001 chars)"
too_long=$(head -c 2001 /dev/zero | tr '\0' 'y')
if ! sanitize_input "$too_long" >/dev/null 2>&1; then
    pass
else
    fail "2001 chars should be rejected"
fi

# Test 5: sanitize_input_for_file()
test_case "sanitize_input_for_file(normal)"
result=$(sanitize_input_for_file "hello world")
if [ "$result" = "hello world" ]; then
    pass
else
    fail "normal string should pass"
fi

test_case "sanitize_input_for_file(metacharacters)"
meta='$;|&!<>'
result=$(sanitize_input_for_file "$meta")
if [ "$result" = "$meta" ]; then
    pass
else
    fail "metacharacters should be allowed in files"
fi

test_case "sanitize_input_for_file(path traversal)"
if ! sanitize_input_for_file "../../etc/passwd" >/dev/null 2>&1; then
    pass
else
    fail "path traversal should be rejected"
fi

test_case "sanitize_input_for_file(/bin/sh)"
if ! sanitize_input_for_file "/bin/sh content" >/dev/null 2>&1; then
    pass
else
    fail "/bin/sh pattern should be rejected"
fi

# Test 6: call_ai_with_context() size routing
test_case "call_ai_with_context(small prompt routing)"
small_prompt=$(head -c 500 /dev/zero | tr '\0' 'a')
# Mock call_ai
call_ai() {
    echo "small_path"
    return 0
}
output=$(call_ai_with_context "claude" "$small_prompt" 300 "" 2>&1)
if echo "$output" | grep -q "Small prompt"; then
    pass
else
    fail "should route to small prompt path"
fi
unset -f call_ai

test_case "call_ai_with_context(large prompt routing)"
large_prompt=$(head -c 2000 /dev/zero | tr '\0' 'b')
output=$(call_ai_with_context "claude" "$large_prompt" 300 "" 2>&1)
if echo "$output" | grep -q "Large prompt detected"; then
    pass
else
    fail "should route to large prompt (file-based) path"
fi

# Cleanup
rm -rf "$TEST_TMP_DIR"

echo ""
echo "================================"
echo "Test Summary"
echo "================================"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
