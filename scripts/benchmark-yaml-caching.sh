#!/usr/bin/env bash
# YAML Caching Performance Benchmark (P1.2.3.1)
# Purpose: Measure performance improvement from YAML caching implementation

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

# Source required libraries
source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh"
source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-config.sh"

# Test configuration
PROFILE="balanced-multi-ai"
WORKFLOW="multi-ai-full-orchestrate"
ITERATIONS=50

echo "=== YAML Caching Performance Benchmark ==="
echo "Profile: $PROFILE"
echo "Workflow: $WORKFLOW"
echo "Iterations: $ITERATIONS"
echo ""

# Benchmark 1: Cold start (no cache)
echo "[1/3] Benchmarking cold start (cache invalidated each time)..."
start_cold=$(date +%s%N)
for ((i=1; i<=ITERATIONS; i++)); do
    invalidate_yaml_cache  # Clear cache
    get_phases "$PROFILE" "$WORKFLOW" >/dev/null 2>&1
    get_phase_info "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_phase_ai "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_phase_role "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_phase_timeout "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_parallel_count "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_parallel_ai "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
    get_parallel_role "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
    get_parallel_timeout "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
    get_parallel_name "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
done
end_cold=$(date +%s%N)
duration_cold=$(( (end_cold - start_cold) / 1000000 ))  # Convert to ms

echo "  ✅ Cold start: ${duration_cold}ms (avg: $((duration_cold / ITERATIONS))ms per iteration)"
echo ""

# Benchmark 2: Warm start (with cache)
echo "[2/3] Benchmarking warm start (cache persists)..."
invalidate_yaml_cache  # Start fresh
start_warm=$(date +%s%N)
for ((i=1; i<=ITERATIONS; i++)); do
    # Same queries, but cache will be used after first iteration
    get_phases "$PROFILE" "$WORKFLOW" >/dev/null 2>&1
    get_phase_info "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_phase_ai "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_phase_role "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_phase_timeout "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_parallel_count "$PROFILE" "$WORKFLOW" 0 >/dev/null 2>&1
    get_parallel_ai "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
    get_parallel_role "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
    get_parallel_timeout "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
    get_parallel_name "$PROFILE" "$WORKFLOW" 0 0 >/dev/null 2>&1
done
end_warm=$(date +%s%N)
duration_warm=$(( (end_warm - start_warm) / 1000000 ))  # Convert to ms

echo "  ✅ Warm start: ${duration_warm}ms (avg: $((duration_warm / ITERATIONS))ms per iteration)"
echo ""

# Benchmark 3: Calculate improvement
echo "[3/3] Performance Analysis..."
improvement=$((duration_cold - duration_warm))
improvement_pct=$(( (improvement * 100) / duration_cold ))

echo "  📊 Results:"
echo "    - Cold start (no cache):   ${duration_cold}ms"
echo "    - Warm start (with cache): ${duration_warm}ms"
echo "    - Improvement:              ${improvement}ms (${improvement_pct}% faster)"
echo ""

if [ "$improvement_pct" -ge 40 ]; then
    echo "  ✅ EXCELLENT: Cache provides >40% speedup!"
elif [ "$improvement_pct" -ge 20 ]; then
    echo "  ✅ GOOD: Cache provides 20-40% speedup"
elif [ "$improvement_pct" -ge 10 ]; then
    echo "  ⚠️  OK: Cache provides 10-20% speedup"
else
    echo "  ❌ POOR: Cache provides <10% speedup"
fi

echo ""
echo "=== Benchmark Complete ==="
