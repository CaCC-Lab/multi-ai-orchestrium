#!/bin/bash
set -euo pipefail

#
# dependency-visualizer.sh
#
# Dependency Visualization for Spec-Driven Development
# Generates Graphviz DOT format and integrates with Grafana.
#

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source dependency analyzer
if [[ -f "$PROJECT_ROOT/scripts/lib/dependency-analyzer.sh" ]]; then
    # shellcheck source=dependency-analyzer.sh
    source "$PROJECT_ROOT/scripts/lib/dependency-analyzer.sh"
fi

# Source VibeLogger if available
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    # shellcheck source=../../bin/vibe-logger-lib.sh
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    # Fallback logging
    vibe_log() { echo "[$(date +%FT%T)] $*" >&2; }
fi

#
# generate_dot_graph
#
# Generates Graphviz DOT format for task dependencies.
#
# Usage: generate_dot_graph <tasks_json_file> [output_dot_file]
# Args:
#   tasks_json_file - Path to tasks JSON file
#   output_dot_file - Optional output file path
# Returns: DOT format string (stdout) and 0 on success
#
generate_dot_graph() {
    local tasks_file="$1"
    local output_file="${2:-}"

    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required" >&2
        return 1
    fi

    # Generate DOT format
    local dot_content
    dot_content=$(cat <<'EOF'
digraph TaskDependencies {
    rankdir=LR;
    node [shape=box, style=rounded];

EOF
)

    # Add nodes
    local nodes
    nodes=$(jq -r '.tasks[] |
        "    \"\(.id)\" [label=\"\(.id)\\n\(.title // "")\"" +
        (if .priority then
            ", color=\"" + (if .priority == "High" then "red"
                           elif .priority == "Medium" then "orange"
                           else "green" end) + "\""
        else "" end) + "];"
    ' "$tasks_file" 2>/dev/null)

    dot_content+="$nodes"$'\n\n'

    # Add edges
    local edges
    edges=$(jq -r '.tasks[] | select(.dependencies and (.dependencies | length) > 0) |
        .id as $task | .dependencies[] | "    \"\(.)\" -> \"\($task)\";"' "$tasks_file" 2>/dev/null)

    dot_content+="$edges"$'\n'
    dot_content+="}"$'\n'

    # Output to file or stdout
    if [[ -n "$output_file" ]]; then
        echo "$dot_content" > "$output_file"
        vibe_log "dependency.visualize" "dot_generated" \
            "{\"output_file\": \"$output_file\"}" \
            "DOT graph generated: $output_file"
    else
        echo "$dot_content"
    fi

    return 0
}

#
# render_graph_image
#
# Renders DOT graph to image format (PNG/SVG).
#
# Usage: render_graph_image <dot_file> <output_image> [format]
# Args:
#   dot_file - Path to DOT file
#   output_image - Output image file path
#   format - Image format (png|svg, default: png)
# Returns: 0 on success, 1 on failure
#
render_graph_image() {
    local dot_file="$1"
    local output_image="$2"
    local format="${3:-png}"

    if ! command -v dot &> /dev/null; then
        vibe_log "dependency.render" "graphviz_missing" \
            "{}" \
            "Graphviz (dot) is required for rendering"
        return 1
    fi

    if [[ ! -f "$dot_file" ]]; then
        vibe_log "dependency.render" "dot_file_missing" \
            "{\"dot_file\": \"$dot_file\"}" \
            "DOT file not found"
        return 1
    fi

    # Render graph
    if dot -T"$format" "$dot_file" -o "$output_image"; then
        vibe_log "dependency.render" "rendered" \
            "{\"output_image\": \"$output_image\", \"format\": \"$format\"}" \
            "Graph rendered: $output_image"
        return 0
    fi

    return 1
}

#
# generate_grafana_annotation
#
# Generates Grafana annotation JSON for dependency events.
#
# Usage: generate_grafana_annotation <tasks_json_file>
# Args:
#   tasks_json_file - Path to tasks JSON file
# Returns: JSON array of Grafana annotations
#
generate_grafana_annotation() {
    local tasks_file="$1"

    if ! command -v jq &> /dev/null; then
        echo "[]"
        return 1
    fi

    # Generate annotations from tasks with dependencies
    jq -r '
        .tasks | map(
            select(.dependencies and (.dependencies | length) > 0) |
            {
                time: (now * 1000 | floor),
                timeEnd: (now * 1000 | floor),
                tags: ["spec-driven", "dependency", .id],
                text: "Task \(.id) depends on: \(.dependencies | join(", "))"
            }
        )
    ' "$tasks_file" 2>/dev/null || echo "[]"
}

#
# visualize_dependencies
#
# Complete workflow: generate DOT, render image, create Grafana annotations.
#
# Usage: visualize_dependencies <tasks_json_file> [output_dir]
# Args:
#   tasks_json_file - Path to tasks JSON file
#   output_dir - Output directory (default: current directory)
# Returns: 0 on success, 1 on failure
#
visualize_dependencies() {
    local tasks_file="$1"
    local output_dir="${2:-.}"

    if [[ ! -f "$tasks_file" ]]; then
        vibe_log "dependency.visualize" "tasks_file_missing" \
            "{\"tasks_file\": \"$tasks_file\"}" \
            "Tasks file not found"
        return 1
    fi

    mkdir -p "$output_dir"

    local base_name
    base_name=$(basename "$tasks_file" .json)

    local dot_file="$output_dir/${base_name}_dependencies.dot"
    local png_file="$output_dir/${base_name}_dependencies.png"
    local svg_file="$output_dir/${base_name}_dependencies.svg"
    local annotation_file="$output_dir/${base_name}_grafana_annotations.json"

    # Generate DOT
    if ! generate_dot_graph "$tasks_file" "$dot_file"; then
        return 1
    fi

    # Render PNG (if Graphviz available)
    if command -v dot &> /dev/null; then
        render_graph_image "$dot_file" "$png_file" "png"
        render_graph_image "$dot_file" "$svg_file" "svg"
    else
        vibe_log "dependency.visualize" "skip_render" \
            "{}" \
            "Graphviz not available, skipping image rendering"
    fi

    # Generate Grafana annotations
    generate_grafana_annotation "$tasks_file" > "$annotation_file"

    vibe_log "dependency.visualize" "completed" \
        "{\"dot\": \"$dot_file\", \"png\": \"$png_file\", \"svg\": \"$svg_file\", \"annotations\": \"$annotation_file\"}" \
        "Dependency visualization completed"

    return 0
}

#
# get_visualization_status
#
# Returns visualization status and file locations.
#
# Usage: get_visualization_status <tasks_json_file> [output_dir]
# Args:
#   tasks_json_file - Path to tasks JSON file
#   output_dir - Output directory
# Returns: JSON with visualization status
#
get_visualization_status() {
    local tasks_file="$1"
    local output_dir="${2:-.}"

    local base_name
    base_name=$(basename "$tasks_file" .json)

    local dot_file="$output_dir/${base_name}_dependencies.dot"
    local png_file="$output_dir/${base_name}_dependencies.png"
    local svg_file="$output_dir/${base_name}_dependencies.svg"
    local annotation_file="$output_dir/${base_name}_grafana_annotations.json"

    cat <<EOF
{
  "dot_file": "$dot_file",
  "dot_exists": $([ -f "$dot_file" ] && echo "true" || echo "false"),
  "png_file": "$png_file",
  "png_exists": $([ -f "$png_file" ] && echo "true" || echo "false"),
  "svg_file": "$svg_file",
  "svg_exists": $([ -f "$svg_file" ] && echo "true" || echo "false"),
  "annotation_file": "$annotation_file",
  "annotation_exists": $([ -f "$annotation_file" ] && echo "true" || echo "false"),
  "graphviz_available": $(command -v dot &> /dev/null && echo "true" || echo "false")
}
EOF
}

# Export functions for use in other scripts
export -f generate_dot_graph
export -f render_graph_image
export -f generate_grafana_annotation
export -f visualize_dependencies
export -f get_visualization_status
