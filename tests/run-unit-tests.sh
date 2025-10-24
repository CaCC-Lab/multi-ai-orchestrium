#!/usr/bin/env bash
# run-unit-tests.sh - Run all bats unit tests with reporting

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="${PROJECT_ROOT}/tests"
UNIT_TESTS_DIR="${TESTS_DIR}/unit"
REPORTS_DIR="${TESTS_DIR}/reports"

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Timestamp for report files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORTS_DIR}/unit-test-report_${TIMESTAMP}.txt"
TAP_FILE="${REPORTS_DIR}/unit-test-tap_${TIMESTAMP}.tap"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Multi-AI Orchestrium - Unit Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo -e "${RED}ERROR: bats is not installed${NC}"
    echo "Install bats: npm install -g bats"
    exit 1
fi

echo -e "${GREEN}✓${NC} bats-core found: $(bats --version)"

# Check for bats-support and bats-assert
BATS_SUPPORT_PATH="${BATS_SUPPORT_PATH:-$HOME/.nvm/versions/node/v22.18.0/lib/node_modules/bats-support}"
BATS_ASSERT_PATH="${BATS_ASSERT_PATH:-$HOME/.nvm/versions/node/v22.18.0/lib/node_modules/bats-assert}"

if [ ! -d "$BATS_SUPPORT_PATH" ]; then
    echo -e "${RED}ERROR: bats-support not found at $BATS_SUPPORT_PATH${NC}"
    echo "Install: npm install -g bats-support"
    exit 1
fi

if [ ! -d "$BATS_ASSERT_PATH" ]; then
    echo -e "${RED}ERROR: bats-assert not found at $BATS_ASSERT_PATH${NC}"
    echo "Install: npm install -g bats-assert"
    exit 1
fi

echo -e "${GREEN}✓${NC} bats-support found"
echo -e "${GREEN}✓${NC} bats-assert found"
echo ""

# Find all .bats test files
TEST_FILES=()
while IFS= read -r -d '' file; do
    TEST_FILES+=("$file")
done < <(find "$UNIT_TESTS_DIR" -name "*.bats" -print0 2>/dev/null)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}WARNING: No .bats test files found in $UNIT_TESTS_DIR${NC}"
    exit 0
fi

echo "Found ${#TEST_FILES[@]} test file(s):"
for file in "${TEST_FILES[@]}"; do
    echo "  - $(basename "$file")"
done
echo ""

# Run tests with TAP output
echo "Running tests..."
echo ""

# Run bats with TAP output and capture to file
if bats --tap "${TEST_FILES[@]}" | tee "$TAP_FILE"; then
    TEST_RESULT=0
else
    TEST_RESULT=$?
fi

# Generate summary report
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse TAP output for summary
TOTAL_TESTS=$(grep -c "^ok\|^not ok" "$TAP_FILE" || echo "0")
PASSED_TESTS=$(grep -c "^ok" "$TAP_FILE" || echo "0")
FAILED_TESTS=$(grep -c "^not ok" "$TAP_FILE" || echo "0")

echo "Total Tests:  $TOTAL_TESTS"
echo "Passed:       $PASSED_TESTS"
echo "Failed:       $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    FINAL_RESULT=0
else
    echo -e "${RED}✗ TESTS FAILED${NC}"
    echo ""
    echo "Failed tests:"
    grep "^not ok" "$TAP_FILE" | sed 's/^not ok /  - /'
    FINAL_RESULT=1
fi

echo ""
echo "Reports saved:"
echo "  - TAP output: $TAP_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $FINAL_RESULT
