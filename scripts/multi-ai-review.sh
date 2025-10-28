#!/usr/bin/env bash
# multi-ai-review.sh - Unified interface for multi-AI code reviews
# Version: 2.0.0 - Phase 2.1 Complete (Unified Report Generation)
# Purpose: Route review requests to appropriate specialized review scripts
# Features: Argument parsing, routing logic, unified JSON/HTML report generation
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 2.1

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REVIEW_DIR="${SCRIPT_DIR}/review"

# Load common library for logging
REVIEW_COMMON="${REVIEW_DIR}/lib/review-common.sh"
if [[ -f "$REVIEW_COMMON" ]]; then
    source "$REVIEW_COMMON"
fi

# YAML configuration file
YAML_CONFIG="${PROJECT_ROOT}/config/review-profiles.yaml"

# ============================================================================
# Usage Information
# ============================================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") --type TYPE [OPTIONS]
       $(basename "$0") --profile PROFILE [OPTIONS]

Unified interface for multi-AI code reviews.

REQUIRED ARGUMENTS (choose one):
  --type TYPE           Review type: security | quality | enterprise | all
  --ai AI_NAME          Specific AI reviewer: gemini | qwen | cursor | amp | droid | all
  --profile PROFILE     Use predefined profile from config/review-profiles.yaml
                        Available: security-focused | quality-focused |
                                  enterprise-focused | balanced | fast

COMMON OPTIONS:
  --commit HASH         Commit hash to review (default: HEAD)
  --timeout SECONDS     Timeout in seconds (default: varies by type/profile)
  --output-dir PATH     Output directory for reports (default: logs/multi-ai-reviews)
  --format FORMAT       Output format: json | markdown | sarif | html (default: all)

TYPE-SPECIFIC OPTIONS:
  --fast                (quality only) Fast mode - P0-P1 issues only, 120s timeout
  --compliance          (enterprise only) Enable compliance mode (GDPR, SOC2, etc.)

EXAMPLES:
  # Run security review on latest commit
  $(basename "$0") --type security

  # Run all review types in parallel
  $(basename "$0") --type all --commit abc123

  # Run specific AI reviewer
  $(basename "$0") --ai gemini --commit abc123

  # Run all 5 AI reviewers in parallel
  $(basename "$0") --ai all

  # Use predefined profile
  $(basename "$0") --profile balanced

  # Fast CI/CD profile
  $(basename "$0") --profile fast --commit abc123

  # Fast quality review
  $(basename "$0") --type quality --fast

  # Enterprise review with compliance checks
  $(basename "$0") --type enterprise --compliance

  # Custom output directory and format
  $(basename "$0") --type security --output-dir ./my-reports --format json

EXIT CODES:
  0  - All reviews passed
  1  - Review failed or errors occurred
  2  - Invalid arguments

EOF
    exit "${1:-0}"
}

# ============================================================================
# ============================================================================
# P2.2: YAML Profile Loading
# ============================================================================

# P2.2.1.2: Load and validate YAML profile
load_profile() {
    local profile_name="$1"

    if [[ ! -f "$YAML_CONFIG" ]]; then
        echo "Error: YAML config not found: $YAML_CONFIG" >&2
        return 1
    fi

    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is required for YAML profile loading" >&2
        echo "Install: snap install yq" >&2
        return 1
    fi

    # Validate profile exists (check for non-null result)
    local profile_check=$(yq eval ".profiles.${profile_name}" "$YAML_CONFIG")
    if [[ "$profile_check" == "null" || -z "$profile_check" ]]; then
        echo "Error: Profile '${profile_name}' not found in $YAML_CONFIG" >&2
        echo "Available profiles:" >&2
        yq eval '.profiles | keys | .[]' "$YAML_CONFIG" >&2
        return 1
    fi

    echo "$profile_name"
}

# P2.2.2.1: Apply profile settings to variables
apply_profile_settings() {
    local profile_name="$1"

    # Extract profile settings using yq
    local profile_timeout=$(yq eval ".profiles.${profile_name}.timeout // 600" "$YAML_CONFIG")
    local profile_type=$(yq eval ".profiles.${profile_name}.workflows[0].type // \"security\"" "$YAML_CONFIG")

    # Apply timeout if not explicitly set
    if [[ -z "$TIMEOUT" ]]; then
        TIMEOUT="$profile_timeout"
        echo "✓ Profile timeout: ${TIMEOUT}s" >&2
    fi

    # For multi-workflow profiles (like 'balanced'), set TYPE to 'all'
    local workflow_count=$(yq eval ".profiles.${profile_name}.workflows | length" "$YAML_CONFIG")
    if [[ "$workflow_count" -gt 1 ]]; then
        TYPE="all"
        echo "✓ Profile mode: multi-review (all types)" >&2
    elif [[ -n "$profile_type" && "$profile_type" != "null" ]]; then
        TYPE="$profile_type"
        echo "✓ Profile type: ${TYPE}" >&2
    fi

    # Extract features (for future use)
    local features=$(yq eval ".profiles.${profile_name}.features | join(\", \")" "$YAML_CONFIG" 2>/dev/null)
    if [[ -n "$features" && "$features" != "null" ]]; then
        echo "✓ Profile features: ${features}" >&2
    fi
}

# ============================================================================
# P2.1.1: Argument Parsing
# ============================================================================

# Default values
TYPE=""
AI_NAME=""
COMMIT="HEAD"
TIMEOUT=""
OUTPUT_DIR="${PROJECT_ROOT}/logs/multi-ai-reviews"
FORMAT="all"
FAST_MODE=false
COMPLIANCE_MODE=false
PROFILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)
            TYPE="$2"
            shift 2
            ;;
        --ai)
            AI_NAME="$2"
            shift 2
            ;;
        --commit)
            COMMIT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --fast)
            FAST_MODE=true
            shift
            ;;
        --compliance)
            COMPLIANCE_MODE=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --help|-h)
            usage 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage 2
            ;;
    esac
done

# P2.2.2.1: Load profile if specified
if [[ -n "$PROFILE" ]]; then
    echo "Loading profile: $PROFILE" >&2
    if load_profile "$PROFILE" > /dev/null; then
        apply_profile_settings "$PROFILE"
    else
        echo "Error: Failed to load profile '$PROFILE'" >&2
        exit 2
    fi
fi

# Validate required arguments (--type, --ai, or --profile required)
if [[ -z "$TYPE" && -z "$AI_NAME" && -z "$PROFILE" ]]; then
    echo "Error: One of --type, --ai, or --profile is required" >&2
    usage 2
fi

# If --ai is specified, it takes precedence over --type
if [[ -n "$AI_NAME" ]]; then
    # Validate AI name
    case "$AI_NAME" in
        gemini|qwen|cursor|amp|droid|all)
            # Valid AI names
            ;;
        *)
            echo "Error: Invalid AI name '$AI_NAME'. Use: gemini|qwen|cursor|amp|droid|all" >&2
            usage 2
            ;;
    esac
fi

# If profile is used but TYPE and AI_NAME are still empty, it means the profile didn't set it
if [[ -n "$PROFILE" && -z "$TYPE" && -z "$AI_NAME" ]]; then
    echo "Error: Profile '$PROFILE' did not specify a valid review type" >&2
    exit 2
fi

# Validate type (only if --ai is not specified)
if [[ -n "$TYPE" && -z "$AI_NAME" ]]; then
    case "$TYPE" in
        security|quality|enterprise|all)
            # Valid types
            ;;
        *)
            echo "Error: Invalid type '$TYPE'. Use: security|quality|enterprise|all" >&2
            usage 2
            ;;
    esac
fi

# Validate type-specific options
if [[ "$FAST_MODE" == "true" && "$TYPE" != "quality" && "$TYPE" != "all" ]]; then
    echo "Error: --fast is only valid for --type quality" >&2
    exit 2
fi

if [[ "$COMPLIANCE_MODE" == "true" && "$TYPE" != "enterprise" && "$TYPE" != "all" ]]; then
    echo "Error: --compliance is only valid for --type enterprise" >&2
    exit 2
fi

# ============================================================================
# P2.1.2: Routing Logic
# ============================================================================

# Build common arguments for review scripts
build_common_args() {
    local args=()

    args+=("--commit" "$COMMIT")

    if [[ -n "$TIMEOUT" ]]; then
        args+=("--timeout" "$TIMEOUT")
    fi

    if [[ -n "$OUTPUT_DIR" ]]; then
        args+=("--output-dir" "$OUTPUT_DIR")
    fi

    if [[ -n "$FORMAT" ]]; then
        args+=("--format" "$FORMAT")
    fi

    echo "${args[@]}"
}

# P0.2.1.1: Execute review using subprocess (NOT source)
# This prevents namespace pollution and ensures clean execution
execute_review() {
    local review_type="$1"
    shift
    local args=("$@")

    local script_path="${REVIEW_DIR}/${review_type}-review.sh"

    if [[ ! -f "$script_path" ]]; then
        echo "Error: Review script not found: $script_path" >&2
        return 1
    fi

    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path"
    fi

    # Execute as subprocess (safer than sourcing)
    bash "$script_path" "${args[@]}"
}

# Execute AI-specific review
execute_ai_review() {
    local ai_name="$1"
    shift
    local args=("$@")

    local script_path="${SCRIPT_DIR}/${ai_name}-review.sh"

    if [[ ! -f "$script_path" ]]; then
        echo "Error: AI review script not found: $script_path" >&2
        return 1
    fi

    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path"
    fi

    # Execute as subprocess (safer than sourcing)
    bash "$script_path" "${args[@]}"
}

# ============================================================================
# P2.1.3: Unified Report Generation
# ============================================================================

# P2.1.3.2: Merge JSON reports from multiple review types
merge_json_reports() {
    local output_dir="$1"
    local unified_file="$2"

    local security_json="${output_dir}/gemini-review.json"
    local quality_json="${output_dir}/qwen-review.json"
    local enterprise_json="${output_dir}/droid-review.json"

    # Check which reports exist
    local available_reports=()
    [[ -f "$security_json" ]] && available_reports+=("$security_json")
    [[ -f "$quality_json" ]] && available_reports+=("$quality_json")
    [[ -f "$enterprise_json" ]] && available_reports+=("$enterprise_json")

    if [[ ${#available_reports[@]} -eq 0 ]]; then
        echo "Error: No review reports found in $output_dir" >&2
        return 1
    fi

    # Merge findings from all reports
    # Priority: P0 > P1 > P2 > P3
    # Remove duplicates based on title + file_path + line_range
    jq -s '
    {
        findings: (
            map(.findings // []) |
            add |
            unique_by(.title + (.code_location.file_path // "") + (.code_location.line_range.start // 0 | tostring)) |
            sort_by(.priority // 999)
        ),
        overall_correctness: (
            if (map(.overall_correctness) | any(. == "patch is incorrect")) then
                "patch is incorrect"
            elif (map(.overall_correctness) | any(. == "needs review")) then
                "needs review"
            else
                "patch is correct"
            end
        ),
        overall_explanation: (
            "Combined review results from " + (length | tostring) + " review types: " +
            (map(.metadata.ai_reviewer // "unknown") | join(", "))
        ),
        overall_confidence_score: (
            map(.overall_confidence_score // 0) | add / length
        ),
        metadata: {
            unified_review: true,
            review_types: (map(.metadata.ai_reviewer // "unknown")),
            total_findings: (map(.findings // []) | map(length) | add),
            review_timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }
    }
    ' "${available_reports[@]}" > "$unified_file"

    echo "✓ Unified JSON report generated: $unified_file" >&2
}

# P2.1.3.3: Generate unified HTML report with tabs
generate_unified_html_report() {
    local output_dir="$1"
    local unified_json="$2"
    local html_file="$3"

    if [[ ! -f "$unified_json" ]]; then
        echo "Error: Unified JSON not found: $unified_json" >&2
        return 1
    fi

    # Extract data using jq
    local total_findings=$(jq '.findings | length' "$unified_json")
    local review_types=$(jq -r '.metadata.review_types | join(", ")' "$unified_json")
    local confidence=$(jq -r '.overall_confidence_score' "$unified_json" | awk '{printf "%.0f%%", $1*100}')
    local status=$(jq -r '.overall_correctness' "$unified_json")

    # Generate HTML with tabs for each review type
    cat > "$html_file" <<'HTML_HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Multi-AI Code Review Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .summary-card { padding: 15px; border-radius: 5px; border-left: 4px solid #4CAF50; background: #f9f9f9; }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 24px; font-weight: bold; color: #333; }
        .tabs { display: flex; border-bottom: 2px solid #ddd; margin: 20px 0; }
        .tab { padding: 10px 20px; cursor: pointer; background: #f0f0f0; border: none; margin-right: 5px; border-radius: 5px 5px 0 0; }
        .tab.active { background: #4CAF50; color: white; }
        .tab-content { display: none; padding: 20px 0; }
        .tab-content.active { display: block; }
        .finding { border-left: 4px solid #ff9800; padding: 15px; margin: 10px 0; background: #fff9f0; border-radius: 4px; }
        .finding.P0 { border-left-color: #f44336; background: #ffebee; }
        .finding.P1 { border-left-color: #ff9800; background: #fff3e0; }
        .finding.P2 { border-left-color: #ffc107; background: #fffde7; }
        .finding .title { font-weight: bold; color: #333; margin-bottom: 8px; }
        .finding .body { color: #666; margin: 8px 0; white-space: pre-wrap; }
        .finding .location { color: #999; font-size: 12px; font-family: monospace; }
        .status-correct { color: #4CAF50; }
        .status-incorrect { color: #f44336; }
        .status-review { color: #ff9800; }
    </style>
</head>
<body>
<div class="container">
HTML_HEADER

    # Add summary section
    cat >> "$html_file" <<EOF
    <h1>Multi-AI Code Review Report</h1>

    <div class="summary">
        <div class="summary-card">
            <h3>Review Types</h3>
            <div class="value">${review_types}</div>
        </div>
        <div class="summary-card">
            <h3>Total Findings</h3>
            <div class="value">${total_findings}</div>
        </div>
        <div class="summary-card">
            <h3>Confidence</h3>
            <div class="value">${confidence}</div>
        </div>
        <div class="summary-card">
            <h3>Overall Status</h3>
            <div class="value status-${status// /-}">${status}</div>
        </div>
    </div>

    <div class="tabs">
        <button class="tab active" onclick="showTab('unified')">Unified View</button>
        <button class="tab" onclick="showTab('security')">Security</button>
        <button class="tab" onclick="showTab('quality')">Quality</button>
        <button class="tab" onclick="showTab('enterprise')">Enterprise</button>
    </div>

    <div id="unified" class="tab-content active">
        <h2>All Findings (Priority Sorted)</h2>
EOF

    # Add unified findings
    jq -r '.findings[] |
        "<div class=\"finding P" + (.priority // 3 | tostring) + "\">" +
        "<div class=\"title\">" + .title + "</div>" +
        "<div class=\"body\">" + .body + "</div>" +
        "<div class=\"location\">📁 " + (.code_location.file_path // "N/A") +
        " (Line " + ((.code_location.line_range.start // 0) | tostring) + "-" +
        ((.code_location.line_range.end // 0) | tostring) + ")</div>" +
        "</div>"
    ' "$unified_json" >> "$html_file"

    # Add individual review tabs (if JSON files exist)
    for review_type in security quality enterprise; do
        local json_file=""
        case "$review_type" in
            security) json_file="${output_dir}/gemini-review.json" ;;
            quality) json_file="${output_dir}/qwen-review.json" ;;
            enterprise) json_file="${output_dir}/droid-review.json" ;;
        esac

        if [[ -f "$json_file" ]]; then
            cat >> "$html_file" <<EOF
    </div>
    <div id="${review_type}" class="tab-content">
        <h2>${review_type^} Review Results</h2>
EOF
            jq -r '.findings[] |
                "<div class=\"finding P" + (.priority // 3 | tostring) + "\">" +
                "<div class=\"title\">" + .title + "</div>" +
                "<div class=\"body\">" + .body + "</div>" +
                "<div class=\"location\">📁 " + (.code_location.file_path // "N/A") +
                " (Line " + ((.code_location.line_range.start // 0) | tostring) + "-" +
                ((.code_location.line_range.end // 0) | tostring) + ")</div>" +
                "</div>"
            ' "$json_file" >> "$html_file"
        fi
    done

    # Close HTML
    cat >> "$html_file" <<'HTML_FOOTER'
    </div>
</div>

<script>
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));

    // Show selected tab
    document.getElementById(tabName).classList.add('active');
    event.target.classList.add('active');
}
</script>
</body>
</html>
HTML_FOOTER

    echo "✓ Unified HTML report generated: $html_file" >&2
}

# ============================================================================
# P2.1.3: Main Execution Logic
# ============================================================================

# Get common arguments - Build TWO versions for different script types
# AI scripts (gemini, qwen, etc.) use --output
# Type scripts (security-review, quality-review, etc.) use --output-dir

# For AI scripts
COMMON_ARGS_AI=()
COMMON_ARGS_AI+=("--commit" "$COMMIT")
if [[ -n "$TIMEOUT" ]]; then
    COMMON_ARGS_AI+=("--timeout" "$TIMEOUT")
fi
if [[ -n "$OUTPUT_DIR" ]]; then
    COMMON_ARGS_AI+=("--output" "$OUTPUT_DIR")
fi
if [[ -n "$FORMAT" ]]; then
    COMMON_ARGS_AI+=("--format" "$FORMAT")
fi

# For Type scripts
COMMON_ARGS_TYPE=()
COMMON_ARGS_TYPE+=("--commit" "$COMMIT")
if [[ -n "$TIMEOUT" ]]; then
    COMMON_ARGS_TYPE+=("--timeout" "$TIMEOUT")
fi
if [[ -n "$OUTPUT_DIR" ]]; then
    COMMON_ARGS_TYPE+=("--output-dir" "$OUTPUT_DIR")
fi
if [[ -n "$FORMAT" ]]; then
    COMMON_ARGS_TYPE+=("--format" "$FORMAT")
fi

# Default to AI version for backward compatibility
COMMON_ARGS=("${COMMON_ARGS_AI[@]}")

# ============================================================================
# Priority: Handle --ai option if specified
# ============================================================================

if [[ -n "$AI_NAME" ]]; then
    case "$AI_NAME" in
        all)
            echo "Running all 5 AI reviewers in parallel..." >&2

            # Array to track background job PIDs
            declare -a AI_PIDS
            declare -a AI_RESULTS
            declare -a AI_NAMES=("gemini" "qwen" "cursor" "amp" "droid")

            # Launch all AI reviews in parallel
            for i in "${!AI_NAMES[@]}"; do
                execute_ai_review "${AI_NAMES[$i]}" "${COMMON_ARGS[@]}" &
                AI_PIDS[$i]=$!
            done

            # Wait for all jobs and collect exit codes
            for i in "${!AI_NAMES[@]}"; do
                AI_RESULTS[$i]=0
                wait ${AI_PIDS[$i]} || AI_RESULTS[$i]=$?
            done

            # Report results
            echo "" >&2
            echo "=== 5AI Review Results ===" >&2
            for i in "${!AI_NAMES[@]}"; do
                ai_name="${AI_NAMES[$i]}"
                status=$([ ${AI_RESULTS[$i]} -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED (exit ${AI_RESULTS[$i]})")
                printf "%-15s %s\n" "${ai_name^} Review:" "$status" >&2
            done
            echo "" >&2

            # Generate unified 5AI report
            echo "=== Generating Unified 5AI Reports ===" >&2
            unified_json="${OUTPUT_DIR}/unified-5ai-review.json"
            unified_html="${OUTPUT_DIR}/unified-5ai-review.html"

            # Merge JSON reports from all 5 AIs
            all_reports=()
            for ai_name in "${AI_NAMES[@]}"; do
                json_file="${OUTPUT_DIR}/${ai_name}-review.json"
                [[ -f "$json_file" ]] && all_reports+=("$json_file")
            done

            if [[ ${#all_reports[@]} -gt 0 ]]; then
                # Merge 5AI findings
                jq -s '
                {
                    findings: (
                        map(.findings // []) |
                        add |
                        unique_by(.title + (.code_location.file_path // "") + (.code_location.line_range.start // 0 | tostring)) |
                        sort_by(.priority // 999)
                    ),
                    overall_correctness: (
                        if (map(.overall_correctness) | any(. == "patch is incorrect")) then
                            "patch is incorrect"
                        elif (map(.overall_correctness) | any(. == "needs review")) then
                            "needs review"
                        else
                            "patch is correct"
                        end
                    ),
                    overall_explanation: (
                        "Combined review results from 5 AI reviewers: " +
                        (map(.metadata.ai_reviewer // "unknown") | join(", "))
                    ),
                    overall_confidence_score: (
                        map(.overall_confidence_score // 0) | add / length
                    ),
                    metadata: {
                        unified_review: true,
                        review_mode: "5AI",
                        ai_reviewers: (map(.metadata.ai_reviewer // "unknown")),
                        total_findings: (map(.findings // []) | map(length) | add),
                        review_timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
                    }
                }
                ' "${all_reports[@]}" > "$unified_json"

                echo "✓ Unified 5AI JSON report generated: $unified_json" >&2
                echo "JSON: $unified_json" >&2
                echo "" >&2
            fi

            # Exit with failure if any review failed
            local any_failed=false
            for i in "${!AI_RESULTS[@]}"; do
                if [[ ${AI_RESULTS[$i]} -ne 0 ]]; then
                    any_failed=true
                    break
                fi
            done

            if [[ "$any_failed" == "true" ]]; then
                exit 1
            fi

            exit 0
            ;;

        gemini|qwen|cursor|amp|droid)
            # Execute specific AI review
            echo "Running ${AI_NAME^} review..." >&2
            execute_ai_review "$AI_NAME" "${COMMON_ARGS[@]}"
            exit $?
            ;;

        *)
            echo "Error: Invalid AI name '$AI_NAME'" >&2
            exit 2
            ;;
    esac
fi

# ============================================================================
# Handle --type option (original logic)
# ============================================================================

# P0.2.2.1: Handle --type all (parallel execution)
case "$TYPE" in
    all)
        echo "Running all review types in parallel..." >&2

        # Array to track background job PIDs
        declare -a PIDS
        declare -a RESULTS

        # Launch security review
        execute_review "security" "${COMMON_ARGS_TYPE[@]}" &
        PIDS[0]=$!

        # Launch quality review (with --fast if requested)
        if [[ "$FAST_MODE" == "true" ]]; then
            execute_review "quality" "${COMMON_ARGS_TYPE[@]}" --fast &
        else
            execute_review "quality" "${COMMON_ARGS_TYPE[@]}" &
        fi
        PIDS[1]=$!

        # Launch enterprise review (with --compliance if requested)
        if [[ "$COMPLIANCE_MODE" == "true" ]]; then
            execute_review "enterprise" "${COMMON_ARGS_TYPE[@]}" --compliance &
        else
            execute_review "enterprise" "${COMMON_ARGS_TYPE[@]}" &
        fi
        PIDS[2]=$!

        # Wait for all jobs and collect exit codes
        RESULTS[0]=0
        RESULTS[1]=0
        RESULTS[2]=0

        wait ${PIDS[0]} || RESULTS[0]=$?
        wait ${PIDS[1]} || RESULTS[1]=$?
        wait ${PIDS[2]} || RESULTS[2]=$?

        # Report results
        echo "" >&2
        echo "=== Review Results ===" >&2
        echo "Security Review:    $([ ${RESULTS[0]} -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED (exit ${RESULTS[0]})")" >&2
        echo "Quality Review:     $([ ${RESULTS[1]} -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED (exit ${RESULTS[1]})")" >&2
        echo "Enterprise Review:  $([ ${RESULTS[2]} -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED (exit ${RESULTS[2]})")" >&2
        echo "" >&2

        # P2.1.3.2 & P2.1.3.3: Generate unified reports
        echo "=== Generating Unified Reports ===" >&2
        unified_json="${OUTPUT_DIR}/unified-review.json"
        unified_html="${OUTPUT_DIR}/unified-review.html"

        if merge_json_reports "$OUTPUT_DIR" "$unified_json"; then
            # Generate HTML report from unified JSON
            if generate_unified_html_report "$OUTPUT_DIR" "$unified_json" "$unified_html"; then
                echo "" >&2
                echo "=== Unified Reports Generated ===" >&2
                echo "JSON: $unified_json" >&2
                echo "HTML: $unified_html" >&2
                echo "" >&2
            else
                echo "Warning: Failed to generate unified HTML report" >&2
            fi
        else
            echo "Warning: Failed to merge JSON reports" >&2
        fi

        # Exit with failure if any review failed
        if [[ ${RESULTS[0]} -ne 0 || ${RESULTS[1]} -ne 0 || ${RESULTS[2]} -ne 0 ]]; then
            exit 1
        fi

        exit 0
        ;;

    security)
        execute_review "security" "${COMMON_ARGS_TYPE[@]}"
        ;;

    quality)
        if [[ "$FAST_MODE" == "true" ]]; then
            execute_review "quality" "${COMMON_ARGS_TYPE[@]}" --fast
        else
            execute_review "quality" "${COMMON_ARGS_TYPE[@]}"
        fi
        ;;

    enterprise)
        if [[ "$COMPLIANCE_MODE" == "true" ]]; then
            execute_review "enterprise" "${COMMON_ARGS_TYPE[@]}" --compliance
        else
            execute_review "enterprise" "${COMMON_ARGS_TYPE[@]}"
        fi
        ;;

    *)
        echo "Error: Invalid type '$TYPE'. Use: security|quality|enterprise|all" >&2
        exit 2
        ;;
esac

# ============================================================================
# Exit
# ============================================================================

# If we get here, single review completed successfully
exit 0
