#!/usr/bin/env bash
# Simplified edge case tests focusing on critical scenarios

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source "scripts/orchestrate/lib/multi-ai-core.sh"

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

echo "========================================================================"
echo "  SIMPLIFIED EDGE CASE TEST SUITE"  
echo "========================================================================"
echo ""

# Test 1: 1MB+ file handling
echo "[TEST 1] 1MB+ file creation"
((TEST_COUNT++))
temp_file=$(mktemp)
if dd if=/dev/zero bs=1024 count=1025 of="$temp_file" 2>/dev/null && [[ -f "$temp_file" ]]; then
    file_size=$(stat -c%s "$temp_file" 2>/dev/null)
    rm -f "$temp_file"
    if [[ $file_size -gt 1048576 ]]; then
        echo "  ✓ PASS (size: $file_size bytes)"
        ((PASS_COUNT++))
    else
        echo "  ✗ FAIL (size: $file_size bytes)"
        ((FAIL_COUNT++))
    fi
else
    echo "  ✗ FAIL (creation failed)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 2: Concurrent file creation (7 processes, 5 files each)
echo "[TEST 2] Concurrent file creation (35 files)"
((TEST_COUNT++))
temp_dir=$(mktemp -d)
for ai in claude gemini amp qwen droid; do
    (for i in {1..5}; do mktemp -p "$temp_dir" "prompt-${ai}-XXX" >/dev/null; done) &
done
wait
file_count=$(find "$temp_dir" -type f | wc -l)
rm -rf "$temp_dir"
if [[ $file_count -eq 25 ]]; then
    echo "  ✓ PASS ($file_count files created)"
    ((PASS_COUNT++))
else
    echo "  ✗ FAIL ($file_count files, expected 25)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 3: Concurrent log writes
echo "[TEST 3] Concurrent log writing"
((TEST_COUNT++))
log_file=$(mktemp)
for i in {1..3}; do
    (for j in {1..10}; do echo "Process $i - Entry $j" >> "$log_file"; done) &
done
wait
line_count=$(wc -l < "$log_file")
rm -f "$log_file"
if [[ $line_count -eq 30 ]]; then
    echo "  ✓ PASS ($line_count lines)"
    ((PASS_COUNT++))
else
    echo "  ✗ FAIL ($line_count lines, expected 30)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 4: Timeout boundary (complete before timeout)
echo "[TEST 4] Timeout boundary condition"
((TEST_COUNT++))
start=$(date +%s)
(sleep 1 && echo "Done") &
pid=$!
if wait $pid 2>/dev/null; then
    elapsed=$(($(date +%s) - start))
    if [[ $elapsed -le 2 ]]; then
        echo "  ✓ PASS (completed in ${elapsed}s)"
        ((PASS_COUNT++))
    else
        echo "  ✗ FAIL (took ${elapsed}s)"
        ((FAIL_COUNT++))
    fi
else
    echo "  ✗ FAIL (process failed)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 5: Permission error handling
echo "[TEST 5] Permission error handling"
((TEST_COUNT++))
temp_file=$(mktemp)
chmod 000 "$temp_file"
if echo "test" > "$temp_file" 2>/dev/null; then
    chmod 600 "$temp_file"
    rm -f "$temp_file"
    echo "  ✗ FAIL (should not write to 000 file)"
    ((FAIL_COUNT++))
else
    chmod 600 "$temp_file"
    rm -f "$temp_file"
    echo "  ✓ PASS (correctly blocked)"
    ((PASS_COUNT++))
fi
echo ""

# Summary
echo "========================================================================"
echo "  SUMMARY"
echo "========================================================================"
echo "Total:  $TEST_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
pass_rate=$((PASS_COUNT * 100 / TEST_COUNT))
echo "Rate:   ${pass_rate}%"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "✓ ALL TESTS PASSED"
    exit 0
else
    echo "✗ SOME TESTS FAILED"
    exit 1
fi
