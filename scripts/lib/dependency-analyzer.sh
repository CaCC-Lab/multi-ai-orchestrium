#!/bin/bash
set -euo pipefail

#
# dependency-analyzer.sh
#
# Dependency Analysis and Topological Sorting for Spec-Driven Development
# Implements Kahn's algorithm for DAG construction and cycle detection.
#

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source VibeLogger if available
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    # shellcheck source=../../bin/vibe-logger-lib.sh
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    # Fallback logging
    vibe_log() { echo "[$(date +%FT%T)] $*" >&2; }
fi

#
# parse_dependencies
#
# Parses dependency declarations from task specification JSON.
#
# Usage: parse_dependencies <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: JSON with adjacency list and in-degrees
#
parse_dependencies() {
    local tasks_file="$1"

    if [[ ! -f "$tasks_file" ]] || ! command -v jq &> /dev/null; then
        echo "{}"
        return 1
    fi

    # Extract dependencies (require: and after: keywords)
    local dependencies
    dependencies=$(jq -r '.tasks[] | select(.dependencies) | {id: .id, deps: .dependencies}' "$tasks_file" 2>/dev/null || echo "{}")

    echo "$dependencies"
}

#
# build_adjacency_list
#
# Builds adjacency list representation of task dependencies.
#
# Usage: build_adjacency_list <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: Adjacency list as JSON
#
build_adjacency_list() {
    local tasks_file="$1"

    if ! command -v jq &> /dev/null; then
        vibe_log "dependency.build" "jq_missing" \
            "{}" \
            "jq is required for dependency analysis"
        echo "{}"
        return 1
    fi

    # Build adjacency list from task dependencies
    jq -r '
        .tasks | map({key: .id, value: (.dependencies // [])}) | from_entries
    ' "$tasks_file" 2>/dev/null || echo "{}"
}

#
# topological_sort
#
# Performs topological sort using Kahn's algorithm.
#
# Usage: topological_sort <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: JSON array of task IDs in topological order, or error if cycle detected
#
topological_sort() {
    local tasks_file="$1"

    if ! command -v jq &> /dev/null; then
        echo "[]"
        return 1
    fi

    # Implementation: Kahn's algorithm
    # 1. Calculate in-degrees for all nodes
    # 2. Add nodes with in-degree 0 to queue
    # 3. Process queue: remove node, decrease in-degrees of neighbors
    # 4. If all nodes processed, return sorted list; otherwise, cycle exists

    local sorted_tasks
    sorted_tasks=$(jq -r '
        .tasks as $tasks |

        # Calculate correct in-degrees (number of dependencies each task has)
        (reduce ($tasks | .[]) as $task (
            {};
            .[$task.id] = ($task.dependencies | length)
        )) as $in_degrees_init |

        # Build reverse adjacency list (if A depends on B, create edge B -> A)
        (reduce ($tasks | .[]) as $task (
            ($tasks | map(.id) | map({key: ., value: []}) | from_entries);
            if ($task.dependencies | length) > 0 then
                reduce ($task.dependencies | .[]) as $dep (
                    .;
                    .[$dep] = (.[$dep] + [$task.id])
                )
            else
                .
            end
        )) as $adj |

        # Kahn algorithm: start with nodes that have in-degree 0
        ([$tasks | .[] | select($in_degrees_init[.id] == 0) | .id]) as $queue_init |

        # Iteratively process queue
        {queue: $queue_init, sorted: [], in_degrees: $in_degrees_init, adj: $adj} |
        until(.queue | length == 0;
            .queue[0] as $node |
            . as $state |
            {
                queue: (
                    $state.queue[1:] +
                    ($state.adj[$node] | map(
                        . as $neighbor |
                        ($state.in_degrees[$neighbor] - 1) as $new_degree |
                        if $new_degree == 0 then $neighbor else empty end
                    ))
                ),
                sorted: ($state.sorted + [$node]),
                in_degrees: (
                    reduce ($state.adj[$node] | .[]) as $neighbor (
                        $state.in_degrees;
                        .[$neighbor] -= 1
                    )
                ),
                adj: $state.adj
            }
        ) |

        # Check if all tasks processed (no cycle)
        if (.sorted | length) == ($tasks | length) then
            .sorted
        else
            error("Circular dependency detected")
        end
    ' "$tasks_file" 2>/dev/null)

    if [[ $? -eq 0 && -n "$sorted_tasks" ]]; then
        echo "$sorted_tasks"
        return 0
    else
        vibe_log "dependency.sort" "cycle_detected" \
            "{\"tasks_file\": \"$tasks_file\"}" \
            "Circular dependency detected in task graph"
        echo "[]"
        return 1
    fi
}

#
# detect_cycles
#
# Detects circular dependencies by attempting topological sort.
# If topological sort fails, there is a cycle.
#
# Usage: detect_cycles <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: 0 if no cycles, 1 if cycles detected
#
detect_cycles() {
    local tasks_file="$1"

    if ! command -v jq &> /dev/null; then
        return 1
    fi

    # Use topological_sort to detect cycles
    # If topological sort fails, there is a cycle
    local sorted_tasks
    sorted_tasks=$(topological_sort "$tasks_file" 2>/dev/null)
    local sort_exit=$?

    if [[ $sort_exit -ne 0 ]]; then
        # Topological sort failed, meaning there is a cycle
        vibe_log "dependency.cycles" "detected" \
            "{\"tasks_file\": \"$tasks_file\"}" \
            "Circular dependencies detected"
        return 1
    fi

    # No cycle detected
    return 0
}

#
# get_execution_order
#
# Returns tasks in execution order (topologically sorted).
#
# Usage: get_execution_order <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: JSON array of task IDs in execution order
#
get_execution_order() {
    local tasks_file="$1"

    local sorted_tasks
    sorted_tasks=$(topological_sort "$tasks_file")

    if [[ $? -eq 0 ]]; then
        vibe_log "dependency.order" "computed" \
            "{\"task_count\": $(echo "$sorted_tasks" | jq 'length')}" \
            "Task execution order computed"

        echo "$sorted_tasks"
        return 0
    fi

    echo "[]"
    return 1
}

#
# get_dependency_stats
#
# Returns dependency statistics.
#
# Usage: get_dependency_stats <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: JSON with dependency statistics
#
get_dependency_stats() {
    local tasks_file="$1"

    if ! command -v jq &> /dev/null; then
        echo "{}"
        return 1
    fi

    jq -r '
        .tasks as $tasks |
        {
            total_tasks: ($tasks | length),
            tasks_with_dependencies: ($tasks | map(select(.dependencies and (.dependencies | length) > 0)) | length),
            total_dependencies: ($tasks | map(.dependencies // [] | length) | add),
            max_dependency_depth: 0,
            has_cycles: false
        }
    ' "$tasks_file" 2>/dev/null || echo "{}"
}

# Export functions for use in other scripts
export -f parse_dependencies
export -f build_adjacency_list
export -f topological_sort
export -f detect_cycles
export -f get_execution_order
export -f get_dependency_stats
