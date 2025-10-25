#!/usr/bin/env bash
# AI Tools Checker - Test Suite
# Version: 1.0.0
# Date: 2025-01-12

# This is the main test suite for the AI Tools Checker.
# It includes a simple test framework and tests for various modules.

set -euo pipefail

# ============================================================ 
# Test Framework
# ============================================================ 

# Test counters
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# assert(condition, message)
# Asserts that a condition is true
#
# Arguments:
#   $1 - Condition to check (e.g., "[ \"$result\" == \"expected\" ]")
#   $2 - Test message
assert() {
  local condition="$1"
  local message="$2"

  TEST_COUNT=$((TEST_COUNT + 1))

  if eval "$condition"; then
    echo -e "  \e[32m✓ PASS\e[0m: $message"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "  \e[31m✗ FAIL\e[0m: $message"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# run_suite(suite_name)
# Runs a test suite (a function with tests)
#
# Arguments:
#   $1 - Test suite function name
run_suite() {
  local suite_name="$1"
  echo -e "\n\e[1mRunning suite: $suite_name\e[0m"
  eval "$suite_name"
}

# print_summary()
# Prints the test results summary
print_summary() {
  echo -e "\n\e[1mTest Summary\e[0m"
  echo "------------------"
  echo "Total tests: $TEST_COUNT"
  echo -e "  \e[32mPassed: $PASS_COUNT\e[0m"
  echo -e "  \e[31mFailed: $FAIL_COUNT\e[0m"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
}

# ============================================================ 
# Test Suites
# ============================================================ 

# Source the modules to be tested
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../src/core/version-checker.sh
source "${SCRIPT_DIR}/../src/core/version-checker.sh"

# Test suite for version-checker.sh
version_checker_suite() {
  # Test semver
  assert "[ \"$(semver \"v1.2.3\")\" == \"1.2.3\" ]" "semver: strips \"v\" prefix"
  assert "[ \"$(semver \"2.0.0-alpha.1\")\" == \"2.0.0-alpha.1\" ]" "semver: handles pre-release"

  # Test vercmp
  assert "[ \"$(vercmp \"1.0.0\" \"2.0.0\")\" == \"-1\" ]" "vercmp: 1.0.0 < 2.0.0"
  assert "[ \"$(vercmp \"2.0.0\" \"1.0.0\")\" == \"1\" ]" "vercmp: 2.0.0 > 1.0.0"
  assert "[ \"$(vercmp \"1.0.0\" \"1.0.0\")\" == \"0\" ]" "vercmp: 1.0.0 == 1.0.0"

  # Test check_breaking_changes
  assert "check_breaking_changes \"1.5.3\" \"2.0.0\"" "check_breaking_changes: detects breaking change"
  assert "! check_breaking_changes \"1.5.3\" \"1.6.0\"" "check_breaking_changes: ignores non-breaking change"
}

# ============================================================ 
# Main Execution
# ============================================================ 

main() {
  run_suite "version_checker_suite"
  print_summary
}

main "$@"
