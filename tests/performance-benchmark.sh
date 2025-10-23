#!/usr/bin/env bash
# Performance Benchmark for File-Based Prompt System
# Measures ONLY file I/O overhead (not AI execution time)

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export PROJECT_ROOT

source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh"
source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-ai-interface.sh"

BENCHMARK_OUTPUT="/tmp/file-based-prompt-benchmark.txt"
> "$BENCHMARK_OUTPUT"

echo "============================================"
echo "File-Based Prompt System - Performance Benchmark"
echo "============================================"
echo ""
echo "Measuring ONLY file I/O overhead (mktemp, chmod, write, cleanup)"
echo ""

# Benchmark file creation/cleanup overhead for different prompt sizes
benchmark_file_overhead() {
    local size_name=$1
    local size_bytes=$2
    local iterations=10  # Average over multiple runs

    echo "[Benchmark] $size_name prompt ($size_bytes bytes)"

    # Generate test prompt
    local prompt=$(head -c "$size_bytes" /dev/zero | tr '\0' 'A')

    # Warm-up run (to ensure file system caching is realistic)
    local prompt_file
    prompt_file=$(create_secure_prompt_file "test" "$prompt") || {
        echo "  ERROR: Failed to create prompt file"
        return 1
    }
    cleanup_prompt_file "$prompt_file"

    # Measure file operations over multiple iterations
    local total_time=0
    for i in $(seq 1 $iterations); do
        local start=$(date +%s%N)  # Nanosecond precision

        # 1. Create secure temp file
        prompt_file=$(create_secure_prompt_file "test" "$prompt") || {
            echo "  ERROR: Failed to create prompt file on iteration $i"
            continue
        }

        # 2. Cleanup (this is also part of the overhead)
        cleanup_prompt_file "$prompt_file"

        local end=$(date +%s%N)
        local duration=$(( (end - start) / 1000000 ))  # Convert to milliseconds
        total_time=$((total_time + duration))
    done

    # Calculate average
    local avg_time=$((total_time / iterations))

    echo "  File I/O overhead: ${avg_time}ms (avg of $iterations runs)"
    echo "$size_name,$size_bytes,$avg_time" >> "$BENCHMARK_OUTPUT"

    echo ""
}

# Benchmark parallel file creation (concurrent overhead)
benchmark_parallel_overhead() {
    local num_concurrent=$1
    local size_bytes=5000  # 5KB test prompt

    echo "[Benchmark] Parallel execution ($num_concurrent concurrent, 5KB each)"

    # Generate test prompt
    local prompt=$(head -c "$size_bytes" /dev/zero | tr '\0' 'B')

    local start=$(date +%s%N)

    # Launch concurrent file operations
    local pids=()
    for i in $(seq 1 $num_concurrent); do
        (
            # Each subprocess creates and cleans up its own file
            local prompt_file
            prompt_file=$(create_secure_prompt_file "test-$i" "$prompt") || exit 1
            cleanup_prompt_file "$prompt_file"
        ) &
        pids+=($!)
    done

    # Wait for all to complete
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    local end=$(date +%s%N)
    local duration=$(( (end - start) / 1000000 ))  # Convert to milliseconds

    echo "  $num_concurrent concurrent: ${duration}ms"
    echo "parallel_$num_concurrent,$size_bytes,$duration" >> "$BENCHMARK_OUTPUT"

    echo ""
}

# Run benchmarks
echo "Starting benchmarks..."
echo ""

# Test different prompt sizes (matching documented thresholds)
benchmark_file_overhead "100B" 100
benchmark_file_overhead "1KB" 1024
benchmark_file_overhead "1.1KB" 1126      # Just over threshold
benchmark_file_overhead "10KB" 10240
benchmark_file_overhead "100KB" 102400
benchmark_file_overhead "1MB" 1048576

echo "----------------------------------------"
echo ""

# Test parallel execution scalability
benchmark_parallel_overhead 2
benchmark_parallel_overhead 5
benchmark_parallel_overhead 10

echo "============================================"
echo "Benchmark Results Summary"
echo "============================================"
echo ""
cat "$BENCHMARK_OUTPUT"
echo ""
echo "Results saved to: $BENCHMARK_OUTPUT"
echo ""
echo "Note: These measurements represent ONLY file I/O overhead."
echo "Actual AI execution time is separate and varies by AI service."
