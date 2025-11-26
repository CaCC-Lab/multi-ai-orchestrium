#!/bin/bash
set -euo pipefail

#
# backpressure.sh
#
# Backpressure Monitoring for Spec-Driven Development
# Provides queue depth monitoring and throttling mechanisms.
#

# Configuration
BACKPRESSURE_THRESHOLD="${BACKPRESSURE_THRESHOLD:-0.8}"  # 80% threshold
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
THROTTLE_MIN_SLEEP="${THROTTLE_MIN_SLEEP:-1}"  # Minimum sleep seconds
THROTTLE_MAX_SLEEP="${THROTTLE_MAX_SLEEP:-5}"  # Maximum sleep seconds

# Source VibeLogger if available
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    # shellcheck source=../../bin/vibe-logger-lib.sh
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    # Fallback logging
    vibe_log() { echo "[$(date +%FT%T)] $*" >&2; }
fi

#
# get_queue_depth
#
# Retrieves the current queue depth from AsyncThink or a custom queue.
#
# Usage: get_queue_depth [queue_name]
# Args:
#   queue_name - Name of the queue (default: "default")
# Returns: Queue depth (integer)
#
get_queue_depth() {
    local queue_name="${1:-default}"
    local depth=0

    # Check AsyncThink queue if available
    if [[ -d "$PROJECT_ROOT/asyncthink/queues/$queue_name" ]]; then
        depth=$(find "$PROJECT_ROOT/asyncthink/queues/$queue_name" -name "*.json" 2>/dev/null | wc -l)
    fi

    echo "$depth"
}

#
# get_queue_capacity
#
# Retrieves the maximum capacity of a queue.
#
# Usage: get_queue_capacity [queue_name]
# Args:
#   queue_name - Name of the queue (default: "default")
# Returns: Queue capacity (integer)
#
get_queue_capacity() {
    local queue_name="${1:-default}"
    local capacity=100  # Default capacity

    # Read capacity from config if available
    local config_file="$PROJECT_ROOT/asyncthink/config/${queue_name}_queue.json"
    if [[ -f "$config_file" ]] && command -v jq &> /dev/null; then
        capacity=$(jq -r '.capacity // 100' "$config_file")
    fi

    echo "$capacity"
}

#
# calculate_queue_utilization
#
# Calculates queue utilization as a percentage.
#
# Usage: calculate_queue_utilization <depth> <capacity>
# Args:
#   depth - Current queue depth
#   capacity - Maximum queue capacity
# Returns: Utilization percentage (0.0 to 1.0)
#
calculate_queue_utilization() {
    local depth="$1"
    local capacity="$2"

    if (( capacity == 0 )); then
        echo "0.0"
        return 0
    fi

    # Use bc for floating point division if available
    if command -v bc &> /dev/null; then
        local result
        result=$(echo "scale=2; $depth / $capacity" | bc)
        # Format to always show 2 decimal places (bc outputs "0" instead of "0.00")
        printf "%.2f" "$result"
    else
        # Fallback: integer division with 2 decimal places
        local scaled=$((depth * 100 / capacity))
        printf "0.%02d" "$scaled"
    fi
}

#
# check_backpressure
#
# Checks if backpressure should be applied based on queue utilization.
#
# Usage: check_backpressure [queue_name]
# Args:
#   queue_name - Name of the queue (default: "default")
# Returns: 0 if backpressure detected, 1 otherwise
#
check_backpressure() {
    local queue_name="${1:-default}"

    local depth capacity utilization
    depth=$(get_queue_depth "$queue_name")
    capacity=$(get_queue_capacity "$queue_name")
    utilization=$(calculate_queue_utilization "$depth" "$capacity")

    vibe_log "backpressure.check" "evaluated" \
        "{\"queue\": \"$queue_name\", \"depth\": $depth, \"capacity\": $capacity, \"utilization\": $utilization}" \
        "Queue utilization: $utilization (threshold: $BACKPRESSURE_THRESHOLD)"

    # Compare with threshold
    if command -v bc &> /dev/null; then
        if (( $(echo "$utilization >= $BACKPRESSURE_THRESHOLD" | bc -l) )); then
            return 0
        fi
    else
        # Fallback: integer comparison (threshold * 100)
        local threshold_depth=$((capacity * 80 / 100))
        if (( depth >= threshold_depth )); then
            return 0
        fi
    fi

    return 1
}

#
# apply_throttle
#
# Applies throttling by sleeping for a random duration.
#
# Usage: apply_throttle [jitter]
# Args:
#   jitter - Enable random jitter (default: true)
# Returns: 0 on success
#
apply_throttle() {
    local jitter="${1:-true}"
    local sleep_duration=$THROTTLE_MIN_SLEEP

    if [[ "$jitter" == "true" ]]; then
        # Random sleep between min and max
        local range=$((THROTTLE_MAX_SLEEP - THROTTLE_MIN_SLEEP))
        sleep_duration=$((THROTTLE_MIN_SLEEP + RANDOM % (range + 1)))
    fi

    vibe_log "backpressure.throttle" "applied" \
        "{\"sleep_duration\": $sleep_duration, \"jitter\": \"$jitter\"}" \
        "Throttling: sleeping for $sleep_duration seconds"

    sleep "$sleep_duration"
    return 0
}

#
# wait_for_capacity
#
# Waits until queue has available capacity.
#
# Usage: wait_for_capacity [queue_name] [max_wait_seconds]
# Args:
#   queue_name - Name of the queue (default: "default")
#   max_wait_seconds - Maximum wait time (default: 60)
# Returns: 0 if capacity available, 1 if timed out
#
wait_for_capacity() {
    local queue_name="${1:-default}"
    local max_wait="${2:-60}"
    local elapsed=0

    vibe_log "backpressure.wait" "started" \
        "{\"queue\": \"$queue_name\", \"max_wait\": $max_wait}" \
        "Waiting for queue capacity"

    while check_backpressure "$queue_name"; do
        if (( elapsed >= max_wait )); then
            vibe_log "backpressure.wait" "timeout" \
                "{\"queue\": \"$queue_name\", \"elapsed\": $elapsed}" \
                "Timeout waiting for queue capacity"
            return 1
        fi

        apply_throttle true
        elapsed=$((elapsed + THROTTLE_MIN_SLEEP))
    done

    vibe_log "backpressure.wait" "capacity_available" \
        "{\"queue\": \"$queue_name\", \"elapsed\": $elapsed}" \
        "Queue capacity available after $elapsed seconds"

    return 0
}

#
# get_backpressure_metrics
#
# Returns current backpressure metrics as JSON.
#
# Usage: get_backpressure_metrics [queue_name]
# Args:
#   queue_name - Name of the queue (default: "default")
# Returns: JSON string with backpressure metrics
#
get_backpressure_metrics() {
    local queue_name="${1:-default}"

    local depth capacity utilization backpressure_active
    depth=$(get_queue_depth "$queue_name")
    capacity=$(get_queue_capacity "$queue_name")
    utilization=$(calculate_queue_utilization "$depth" "$capacity")

    if check_backpressure "$queue_name"; then
        backpressure_active="true"
    else
        backpressure_active="false"
    fi

    cat <<EOF
{
  "queue_name": "$queue_name",
  "depth": $depth,
  "capacity": $capacity,
  "utilization": $utilization,
  "threshold": $BACKPRESSURE_THRESHOLD,
  "backpressure_active": $backpressure_active
}
EOF
}

#
# monitor_backpressure
#
# Continuously monitors backpressure and logs metrics.
#
# Usage: monitor_backpressure [queue_name] [interval_seconds]
# Args:
#   queue_name - Name of the queue (default: "default")
#   interval_seconds - Monitoring interval (default: 5)
# Returns: Never returns (runs indefinitely)
#
monitor_backpressure() {
    local queue_name="${1:-default}"
    local interval="${2:-5}"

    vibe_log "backpressure.monitor" "started" \
        "{\"queue\": \"$queue_name\", \"interval\": $interval}" \
        "Backpressure monitoring started"

    while true; do
        local metrics
        metrics=$(get_backpressure_metrics "$queue_name")

        vibe_log "backpressure.monitor" "metrics" \
            "$metrics" \
            "Backpressure metrics for queue $queue_name"

        sleep "$interval"
    done
}

# Export functions for use in other scripts
export -f get_queue_depth
export -f get_queue_capacity
export -f calculate_queue_utilization
export -f check_backpressure
export -f apply_throttle
export -f wait_for_capacity
export -f get_backpressure_metrics
export -f monitor_backpressure
