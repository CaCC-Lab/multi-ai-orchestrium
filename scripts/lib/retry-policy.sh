#!/bin/bash
set -euo pipefail

#
# retry-policy.sh
#
# Retry Policy with Exponential Backoff and Circuit Breaker
# Provides intelligent retry mechanisms for Spec-Driven Development.
#

# Configuration
RETRY_BASE_DELAY="${RETRY_BASE_DELAY:-1}"        # Base delay in seconds
RETRY_MAX_DELAY="${RETRY_MAX_DELAY:-60}"         # Maximum delay in seconds
RETRY_MULTIPLIER="${RETRY_MULTIPLIER:-2}"        # Backoff multiplier
RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-3}"    # Maximum retry attempts
CIRCUIT_BREAKER_THRESHOLD="${CIRCUIT_BREAKER_THRESHOLD:-0.2}"  # 20% failure rate
CIRCUIT_BREAKER_WINDOW="${CIRCUIT_BREAKER_WINDOW:-300}"        # 5 minute window
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source VibeLogger if available
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    # shellcheck source=../../bin/vibe-logger-lib.sh
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    # Fallback logging
    vibe_log() { echo "[$(date +%FT%T)] $*" >&2; }
fi

# Circuit breaker state
declare -gA CIRCUIT_BREAKER_STATE=()
declare -gA CIRCUIT_BREAKER_FAILURES=()
declare -gA CIRCUIT_BREAKER_TOTAL=()
declare -gA CIRCUIT_BREAKER_LAST_RESET=()

#
# calculate_backoff_delay
#
# Calculates exponential backoff delay for retry attempt.
#
# Usage: calculate_backoff_delay <attempt>
# Args:
#   attempt - Current retry attempt number (1-based)
# Returns: Delay in seconds (capped at RETRY_MAX_DELAY)
#
calculate_backoff_delay() {
    local attempt="$1"
    local delay=$RETRY_BASE_DELAY

    # Calculate exponential delay: base * (multiplier ^ (attempt - 1))
    for ((i=1; i<attempt; i++)); do
        delay=$((delay * RETRY_MULTIPLIER))
    done

    # Cap at maximum delay
    if (( delay > RETRY_MAX_DELAY )); then
        delay=$RETRY_MAX_DELAY
    fi

    echo "$delay"
}

#
# add_jitter
#
# Adds random jitter to prevent thundering herd problem.
#
# Usage: add_jitter <delay>
# Args:
#   delay - Base delay in seconds
# Returns: Delay with jitter added (±25%)
#
add_jitter() {
    local delay="$1"

    # Add ±25% jitter
    local jitter_range=$((delay / 4))
    local jitter=$((RANDOM % (jitter_range * 2 + 1) - jitter_range))
    local final_delay=$((delay + jitter))

    # Ensure delay is at least 1 second
    if (( final_delay < 1 )); then
        final_delay=1
    fi

    echo "$final_delay"
}

#
# wait_with_backoff
#
# Waits for the calculated backoff delay with jitter.
#
# Usage: wait_with_backoff <attempt>
# Args:
#   attempt - Current retry attempt number
# Returns: 0 on success
#
wait_with_backoff() {
    local attempt="$1"

    local base_delay jittered_delay
    base_delay=$(calculate_backoff_delay "$attempt")
    jittered_delay=$(add_jitter "$base_delay")

    vibe_log "retry.backoff" "waiting" \
        "{\"attempt\": $attempt, \"base_delay\": $base_delay, \"jittered_delay\": $jittered_delay}" \
        "Waiting $jittered_delay seconds before retry attempt $attempt"

    sleep "$jittered_delay"
    return 0
}

#
# check_circuit_breaker
#
# Checks if circuit breaker is open for a service.
#
# Usage: check_circuit_breaker <service_name>
# Args:
#   service_name - Name of the service
# Returns: 0 if circuit is closed (can proceed), 1 if open (should fail fast)
#
check_circuit_breaker() {
    local service="$1"
    local current_time
    current_time=$(date +%s)

    # Initialize if not exists
    if [[ -z "${CIRCUIT_BREAKER_LAST_RESET[$service]:-}" ]]; then
        CIRCUIT_BREAKER_LAST_RESET[$service]=$current_time
        CIRCUIT_BREAKER_FAILURES[$service]=0
        CIRCUIT_BREAKER_TOTAL[$service]=0
        CIRCUIT_BREAKER_STATE[$service]="closed"
    fi

    # Reset window if expired
    local last_reset="${CIRCUIT_BREAKER_LAST_RESET[$service]}"
    if (( current_time - last_reset >= CIRCUIT_BREAKER_WINDOW )); then
        CIRCUIT_BREAKER_LAST_RESET[$service]=$current_time
        CIRCUIT_BREAKER_FAILURES[$service]=0
        CIRCUIT_BREAKER_TOTAL[$service]=0
        CIRCUIT_BREAKER_STATE[$service]="closed"
    fi

    # Check state
    if [[ "${CIRCUIT_BREAKER_STATE[$service]}" == "open" ]]; then
        vibe_log "retry.circuit_breaker" "open" \
            "{\"service\": \"$service\", \"state\": \"open\"}" \
            "Circuit breaker is open for service $service"
        return 1
    fi

    # Calculate failure rate
    local failures="${CIRCUIT_BREAKER_FAILURES[$service]}"
    local total="${CIRCUIT_BREAKER_TOTAL[$service]}"

    if (( total > 0 )); then
        local failure_rate
        if command -v bc &> /dev/null; then
            failure_rate=$(echo "scale=2; $failures / $total" | bc)
            if (( $(echo "$failure_rate >= $CIRCUIT_BREAKER_THRESHOLD" | bc -l) )); then
                CIRCUIT_BREAKER_STATE[$service]="open"

                vibe_log "retry.circuit_breaker" "opened" \
                    "{\"service\": \"$service\", \"failure_rate\": $failure_rate, \"failures\": $failures, \"total\": $total}" \
                    "Circuit breaker opened for service $service (failure rate: $failure_rate)"

                return 1
            fi
        else
            # Fallback: integer comparison (threshold * 100)
            local threshold_count=$((total * 20 / 100))
            if (( failures >= threshold_count )); then
                CIRCUIT_BREAKER_STATE[$service]="open"

                vibe_log "retry.circuit_breaker" "opened" \
                    "{\"service\": \"$service\", \"failures\": $failures, \"total\": $total}" \
                    "Circuit breaker opened for service $service"

                return 1
            fi
        fi
    fi

    return 0
}

#
# record_success
#
# Records a successful operation for circuit breaker tracking.
#
# Usage: record_success <service_name>
# Args:
#   service_name - Name of the service
# Returns: 0 on success
#
record_success() {
    local service="$1"

    # Initialize if not exists (initialize ALL circuit breaker state)
    if [[ -z "${CIRCUIT_BREAKER_TOTAL[$service]:-}" ]]; then
        local current_time
        current_time=$(date +%s)
        CIRCUIT_BREAKER_LAST_RESET[$service]=$current_time
        CIRCUIT_BREAKER_TOTAL[$service]=0
        CIRCUIT_BREAKER_FAILURES[$service]=0
        CIRCUIT_BREAKER_STATE[$service]="closed"
    fi

    CIRCUIT_BREAKER_TOTAL[$service]=$((CIRCUIT_BREAKER_TOTAL[$service] + 1))

    vibe_log "retry.circuit_breaker" "success_recorded" \
        "{\"service\": \"$service\", \"total\": ${CIRCUIT_BREAKER_TOTAL[$service]}}" \
        "Success recorded for service $service"

    return 0
}

#
# record_failure
#
# Records a failed operation for circuit breaker tracking.
#
# Usage: record_failure <service_name>
# Args:
#   service_name - Name of the service
# Returns: 0 on success
#
record_failure() {
    local service="$1"

    # Initialize if not exists (initialize ALL circuit breaker state)
    if [[ -z "${CIRCUIT_BREAKER_TOTAL[$service]:-}" ]]; then
        local current_time
        current_time=$(date +%s)
        CIRCUIT_BREAKER_LAST_RESET[$service]=$current_time
        CIRCUIT_BREAKER_TOTAL[$service]=0
        CIRCUIT_BREAKER_FAILURES[$service]=0
        CIRCUIT_BREAKER_STATE[$service]="closed"
    fi

    CIRCUIT_BREAKER_TOTAL[$service]=$((CIRCUIT_BREAKER_TOTAL[$service] + 1))
    CIRCUIT_BREAKER_FAILURES[$service]=$((CIRCUIT_BREAKER_FAILURES[$service] + 1))

    vibe_log "retry.circuit_breaker" "failure_recorded" \
        "{\"service\": \"$service\", \"failures\": ${CIRCUIT_BREAKER_FAILURES[$service]}, \"total\": ${CIRCUIT_BREAKER_TOTAL[$service]}}" \
        "Failure recorded for service $service"

    return 0
}

#
# retry_with_policy
#
# Executes a command with retry policy and circuit breaker.
#
# Usage: retry_with_policy <service_name> <command> [args...]
# Args:
#   service_name - Name of the service (for circuit breaker)
#   command - Command to execute
#   args - Arguments to pass to the command
# Returns: Exit code of the command (0 on success, non-zero on failure)
#
retry_with_policy() {
    local service="$1"
    shift
    local command=("$@")

    # Check circuit breaker
    if ! check_circuit_breaker "$service"; then
        vibe_log "retry.execute" "circuit_open" \
            "{\"service\": \"$service\"}" \
            "Circuit breaker is open, failing fast for service $service"
        return 1
    fi

    local attempt=1
    while (( attempt <= RETRY_MAX_ATTEMPTS )); do
        vibe_log "retry.execute" "attempt" \
            "{\"service\": \"$service\", \"attempt\": $attempt, \"max_attempts\": $RETRY_MAX_ATTEMPTS}" \
            "Executing attempt $attempt/$RETRY_MAX_ATTEMPTS for service $service"

        # Execute command
        if "${command[@]}"; then
            vibe_log "retry.execute" "success" \
                "{\"service\": \"$service\", \"attempt\": $attempt}" \
                "Command succeeded on attempt $attempt for service $service"

            record_success "$service"
            return 0
        fi

        local exit_code=$?
        vibe_log "retry.execute" "failure" \
            "{\"service\": \"$service\", \"attempt\": $attempt, \"exit_code\": $exit_code}" \
            "Command failed with exit code $exit_code on attempt $attempt"

        record_failure "$service"

        # Check if we should retry
        if (( attempt >= RETRY_MAX_ATTEMPTS )); then
            vibe_log "retry.execute" "max_attempts_reached" \
                "{\"service\": \"$service\", \"attempts\": $attempt}" \
                "Maximum retry attempts reached for service $service"
            return "$exit_code"
        fi

        # Wait with backoff before next attempt
        wait_with_backoff "$attempt"
        attempt=$((attempt + 1))

        # Re-check circuit breaker before next attempt
        if ! check_circuit_breaker "$service"; then
            vibe_log "retry.execute" "circuit_opened" \
                "{\"service\": \"$service\", \"attempt\": $attempt}" \
                "Circuit breaker opened during retries for service $service"
            return 1
        fi
    done

    return 1
}

#
# reset_circuit_breaker
#
# Manually resets the circuit breaker for a service.
#
# Usage: reset_circuit_breaker <service_name>
# Args:
#   service_name - Name of the service
# Returns: 0 on success
#
reset_circuit_breaker() {
    local service="$1"
    local current_time
    current_time=$(date +%s)

    CIRCUIT_BREAKER_LAST_RESET[$service]=$current_time
    CIRCUIT_BREAKER_FAILURES[$service]=0
    CIRCUIT_BREAKER_TOTAL[$service]=0
    CIRCUIT_BREAKER_STATE[$service]="closed"

    vibe_log "retry.circuit_breaker" "reset" \
        "{\"service\": \"$service\"}" \
        "Circuit breaker manually reset for service $service"

    return 0
}

#
# get_retry_metrics
#
# Returns retry and circuit breaker metrics as JSON.
#
# Usage: get_retry_metrics <service_name>
# Args:
#   service_name - Name of the service
# Returns: JSON string with retry metrics
#
get_retry_metrics() {
    local service="$1"

    local state failures total failure_rate
    state="${CIRCUIT_BREAKER_STATE[$service]:-closed}"
    failures="${CIRCUIT_BREAKER_FAILURES[$service]:-0}"
    total="${CIRCUIT_BREAKER_TOTAL[$service]:-0}"

    if (( total > 0 )) && command -v bc &> /dev/null; then
        failure_rate=$(echo "scale=2; $failures / $total" | bc)
    else
        failure_rate="0.00"
    fi

    cat <<EOF
{
  "service": "$service",
  "circuit_breaker_state": "$state",
  "failures": $failures,
  "total_attempts": $total,
  "failure_rate": $failure_rate,
  "threshold": $CIRCUIT_BREAKER_THRESHOLD,
  "max_retry_attempts": $RETRY_MAX_ATTEMPTS,
  "base_delay": $RETRY_BASE_DELAY,
  "max_delay": $RETRY_MAX_DELAY
}
EOF
}

# Export functions for use in other scripts
export -f calculate_backoff_delay
export -f add_jitter
export -f wait_with_backoff
export -f check_circuit_breaker
export -f record_success
export -f record_failure
export -f retry_with_policy
export -f reset_circuit_breaker
export -f get_retry_metrics
