#!/bin/bash
set -euo pipefail

#
# worker-pool.sh
#
# Dynamic Worker Pool Management for Spec-Driven Development
# Provides CPU-aware worker scaling with queue monitoring.
#

# Configuration
MAX_WORKERS="${MAX_WORKERS:-32}"
SCALE_THRESHOLD="${SCALE_THRESHOLD:-0.8}"  # 80% queue depth triggers scale-up
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source VibeLogger if available
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    # shellcheck source=../../bin/vibe-logger-lib.sh
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    # Fallback logging
    vibe_log() { echo "[$(date +%FT%T)] $*" >&2; }
fi

# Worker pool state (associative arrays)
declare -gA WORKER_POOL_ACTIVE=()
declare -gA WORKER_POOL_IDLE=()
declare -g WORKER_POOL_SIZE=0

#
# get_cpu_cores
#
# Detects the number of available CPU cores using platform-specific commands.
#
# Usage: get_cpu_cores
# Returns: Number of CPU cores (integer)
#
get_cpu_cores() {
    local cores=4  # Fallback default

    if command -v nproc &> /dev/null; then
        cores=$(nproc)
    elif command -v sysctl &> /dev/null && sysctl -n hw.ncpu &> /dev/null; then
        cores=$(sysctl -n hw.ncpu)
    elif [[ -f /proc/cpuinfo ]]; then
        cores=$(grep -c ^processor /proc/cpuinfo)
    fi

    echo "$cores"
}

#
# calculate_optimal_workers
#
# Calculates optimal worker count based on CPU cores.
#
# Usage: calculate_optimal_workers
# Returns: Optimal worker count (min: 2, max: MAX_WORKERS)
#
calculate_optimal_workers() {
    local cores
    cores=$(get_cpu_cores)

    local workers=$((cores * 2))

    # Apply minimum and maximum limits
    if (( workers < 2 )); then
        workers=2
    elif (( workers > MAX_WORKERS )); then
        workers=$MAX_WORKERS
    fi

    echo "$workers"
}

#
# init_worker_pool
#
# Initializes the worker pool with optimal worker count.
#
# Usage: init_worker_pool
# Returns: 0 on success, 1 on failure
#
init_worker_pool() {
    local optimal_workers
    optimal_workers=$(calculate_optimal_workers)

    WORKER_POOL_SIZE=$optimal_workers

    vibe_log "worker_pool.init" "initialized" \
        "{\"size\": $WORKER_POOL_SIZE, \"max\": $MAX_WORKERS}" \
        "Worker pool initialized with $WORKER_POOL_SIZE workers"

    # Initialize all workers as idle
    for ((i=1; i<=WORKER_POOL_SIZE; i++)); do
        WORKER_POOL_IDLE[$i]="idle"
    done

    return 0
}

#
# get_idle_worker
#
# Retrieves an idle worker ID from the pool.
#
# Usage: get_idle_worker
# Returns: Worker ID (integer) or empty string if none available
#
get_idle_worker() {
    for worker_id in "${!WORKER_POOL_IDLE[@]}"; do
        echo "$worker_id"
        return 0
    done

    # No idle workers available
    echo ""
    return 1
}

#
# mark_worker_active
#
# Moves a worker from idle to active state.
#
# Usage: mark_worker_active <worker_id> <task_id>
# Args:
#   worker_id - ID of the worker
#   task_id - ID of the task being executed
# Returns: 0 on success, 1 if worker not found
#
mark_worker_active() {
    local worker_id="$1"
    local task_id="$2"

    if [[ -n "${WORKER_POOL_IDLE[$worker_id]:-}" ]]; then
        unset "WORKER_POOL_IDLE[$worker_id]"
        WORKER_POOL_ACTIVE[$worker_id]="$task_id"

        vibe_log "worker_pool.worker_active" "activated" \
            "{\"worker_id\": $worker_id, \"task_id\": \"$task_id\"}" \
            "Worker $worker_id activated for task $task_id"

        return 0
    fi

    return 1
}

#
# mark_worker_idle
#
# Moves a worker from active to idle state.
#
# Usage: mark_worker_idle <worker_id>
# Args:
#   worker_id - ID of the worker
# Returns: 0 on success, 1 if worker not found
#
mark_worker_idle() {
    local worker_id="$1"

    if [[ -n "${WORKER_POOL_ACTIVE[$worker_id]:-}" ]]; then
        local task_id="${WORKER_POOL_ACTIVE[$worker_id]}"
        unset "WORKER_POOL_ACTIVE[$worker_id]"
        WORKER_POOL_IDLE[$worker_id]="idle"

        vibe_log "worker_pool.worker_idle" "released" \
            "{\"worker_id\": $worker_id, \"task_id\": \"$task_id\"}" \
            "Worker $worker_id released from task $task_id"

        return 0
    fi

    return 1
}

#
# get_active_worker_count
#
# Returns the number of currently active workers.
#
# Usage: get_active_worker_count
# Returns: Count of active workers (integer)
#
get_active_worker_count() {
    echo "${#WORKER_POOL_ACTIVE[@]}"
}

#
# get_idle_worker_count
#
# Returns the number of currently idle workers.
#
# Usage: get_idle_worker_count
# Returns: Count of idle workers (integer)
#
get_idle_worker_count() {
    echo "${#WORKER_POOL_IDLE[@]}"
}

#
# get_worker_utilization
#
# Calculates worker pool utilization as a percentage.
#
# Usage: get_worker_utilization
# Returns: Utilization percentage (0.0 to 1.0)
#
get_worker_utilization() {
    if (( WORKER_POOL_SIZE == 0 )); then
        echo "0.0"
        return 0
    fi

    local active_count
    active_count=$(get_active_worker_count)

    # Use bc for floating point division if available
    if command -v bc &> /dev/null; then
        echo "scale=2; $active_count / $WORKER_POOL_SIZE" | bc
    else
        # Fallback: integer division with 2 decimal places
        local scaled=$((active_count * 100 / WORKER_POOL_SIZE))
        echo "0.$scaled"
    fi
}

#
# should_scale_up
#
# Determines if worker pool should be scaled up based on queue depth.
#
# Usage: should_scale_up <queue_depth> <queue_capacity>
# Args:
#   queue_depth - Current queue depth
#   queue_capacity - Maximum queue capacity
# Returns: 0 if should scale up, 1 otherwise
#
should_scale_up() {
    local queue_depth="$1"
    local queue_capacity="$2"

    if (( queue_capacity == 0 )); then
        return 1
    fi

    # Calculate queue utilization
    local utilization
    if command -v bc &> /dev/null; then
        utilization=$(echo "scale=2; $queue_depth / $queue_capacity" | bc)

        # Compare with threshold
        if (( $(echo "$utilization >= $SCALE_THRESHOLD" | bc -l) )); then
            return 0
        fi
    else
        # Fallback: integer comparison
        local threshold_depth=$((queue_capacity * 80 / 100))
        if (( queue_depth >= threshold_depth )); then
            return 0
        fi
    fi

    return 1
}

#
# scale_up_workers
#
# Increases worker pool size if below maximum.
#
# Usage: scale_up_workers [count]
# Args:
#   count - Number of workers to add (default: 1)
# Returns: 0 on success, 1 if already at maximum
#
scale_up_workers() {
    local count="${1:-1}"

    if (( WORKER_POOL_SIZE >= MAX_WORKERS )); then
        vibe_log "worker_pool.scale_up" "limit_reached" \
            "{\"current\": $WORKER_POOL_SIZE, \"max\": $MAX_WORKERS}" \
            "Cannot scale up: already at maximum ($MAX_WORKERS workers)"
        return 1
    fi

    local old_size=$WORKER_POOL_SIZE
    local new_size=$((WORKER_POOL_SIZE + count))

    if (( new_size > MAX_WORKERS )); then
        new_size=$MAX_WORKERS
    fi

    # Add new idle workers
    for ((i=WORKER_POOL_SIZE+1; i<=new_size; i++)); do
        WORKER_POOL_IDLE[$i]="idle"
    done

    WORKER_POOL_SIZE=$new_size

    vibe_log "worker_pool.scale_up" "scaled" \
        "{\"old_size\": $old_size, \"new_size\": $new_size}" \
        "Worker pool scaled up from $old_size to $new_size workers"

    return 0
}

#
# get_worker_pool_status
#
# Returns current worker pool status as JSON.
#
# Usage: get_worker_pool_status
# Returns: JSON string with pool status
#
get_worker_pool_status() {
    local active_count idle_count utilization
    active_count=$(get_active_worker_count)
    idle_count=$(get_idle_worker_count)
    utilization=$(get_worker_utilization)

    cat <<EOF
{
  "total_workers": $WORKER_POOL_SIZE,
  "active_workers": $active_count,
  "idle_workers": $idle_count,
  "utilization": $utilization,
  "max_workers": $MAX_WORKERS
}
EOF
}

# Export functions for use in other scripts
export -f get_cpu_cores
export -f calculate_optimal_workers
export -f init_worker_pool
export -f get_idle_worker
export -f mark_worker_active
export -f mark_worker_idle
export -f get_active_worker_count
export -f get_idle_worker_count
export -f get_worker_utilization
export -f should_scale_up
export -f scale_up_workers
export -f get_worker_pool_status
