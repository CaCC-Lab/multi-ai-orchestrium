#!/usr/bin/env bash
# Minimal edge case tests - P0.2.3.2
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0; FAIL=0; TOTAL=5

echo "============================================================================"
echo "  EDGE CASE INTEGRATION TESTS (P0.2.3.2)"
echo "============================================================================"
echo ""

# Test 1
echo "[1/5] Large file creation (>1MB)"
if head -c 1048577 /dev/zero > /tmp/edge-test-1mb 2>/dev/null && [[ -f /tmp/edge-test-1mb ]]; then
    size=$(stat -c%s /tmp/edge-test-1mb 2>/dev/null)
    rm -f /tmp/edge-test-1mb
    if [[ $size -gt 1048576 ]]; then
        echo "  ✓ PASS ($size bytes)"
        ((PASS++))
    else
        echo "  ✗ FAIL (size: $size)"
        ((FAIL++))
    fi
else
    echo "  ✗ FAIL (creation failed)"
    ((FAIL++))
fi

# Test 2
echo "[2/5] Concurrent file creation"
dir=$(mktemp -d)
for i in {1..10}; do (mktemp -p "$dir" >/dev/null) & done
wait
count=$(find "$dir" -type f | wc -l)
rm -rf "$dir"
if [[ $count -eq 10 ]]; then
    echo "  ✓ PASS ($count files)"
    ((PASS++))
else
    echo "  ✗ FAIL ($count files)"
    ((FAIL++))
fi

# Test 3
echo "[3/5] Concurrent log writes"
log=$(mktemp)
for i in {1..5}; do (for j in {1..5}; do echo "P$i-E$j" >> "$log"; done) & done
wait
lines=$(wc -l < "$log")
rm -f "$log"
if [[ $lines -eq 25 ]]; then
    echo "  ✓ PASS ($lines lines)"
    ((PASS++))
else
    echo "  ✗ FAIL ($lines lines)"
    ((FAIL++))
fi

# Test 4
echo "[4/5] Timeout condition"
start=$(date +%s)
(sleep 1) &
wait $! 2>/dev/null
elapsed=$(($(date +%s) - start))
if [[ $elapsed -le 2 ]]; then
    echo "  ✓ PASS (${elapsed}s)"
    ((PASS++))
else
    echo "  ✗ FAIL (${elapsed}s)"
    ((FAIL++))
fi

# Test 5
echo "[5/5] Permission handling"
f=$(mktemp)
chmod 000 "$f"
if echo "test" > "$f" 2>/dev/null; then
    chmod 600 "$f"
    rm -f "$f"
    echo "  ✗ FAIL (wrote to 000 file)"
    ((FAIL++))
else
    chmod 600 "$f"
    rm -f "$f"
    echo "  ✓ PASS"
    ((PASS++))
fi

echo ""
echo "============================================================================"
echo "Results: $PASS/$TOTAL passed ($((PASS*100/TOTAL))%)"
if [[ $FAIL -eq 0 ]]; then
    echo "✓ ALL TESTS PASSED"
    exit 0
else
    echo "✗ $FAIL TESTS FAILED"
    exit 1
fi
