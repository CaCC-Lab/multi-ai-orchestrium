#!/usr/bin/env bash
# enterprise-review.sh - Enterprise quality review using Droid + Claude fallback
# Version: 1.0.0
# Purpose: Comprehensive enterprise-grade production readiness review
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.3.3

set -euo pipefail

# ============================================================================
# P1.3.3.1: Script Configuration & Library Loading
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load common review library
REVIEW_LIB="${SCRIPT_DIR}/lib/review-common.sh"
if [[ ! -f "$REVIEW_LIB" ]]; then
    echo "Error: review-common.sh not found at: $REVIEW_LIB" >&2
    exit 1
fi
source "$REVIEW_LIB"

# Load Droid adapter (primary)
DROID_ADAPTER="${SCRIPT_DIR}/lib/review-adapters/adapter-droid.sh"
if [[ ! -f "$DROID_ADAPTER" ]]; then
    echo "Error: adapter-droid.sh not found at: $DROID_ADAPTER" >&2
    exit 1
fi
source "$DROID_ADAPTER"

# Load Claude adapter (fallback) - Use absolute path based on PROJECT_ROOT
CLAUDE_ADAPTER="${PROJECT_ROOT}/scripts/review/lib/review-adapters/adapter-claude.sh"
if [[ ! -f "$CLAUDE_ADAPTER" ]]; then
    echo "Error: adapter-claude.sh not found at: $CLAUDE_ADAPTER" >&2
    exit 1
fi
source "$CLAUDE_ADAPTER"

# ============================================================================
# Configuration
# ============================================================================

REVIEW_TYPE="enterprise"
DEFAULT_COMMIT="HEAD"
DEFAULT_TIMEOUT=1200  # 20 minutes for comprehensive Droid analysis (increased for parallel execution)
FALLBACK_TIMEOUT=600  # 10 minutes for Claude Comprehensive

# Compliance mode configuration
COMPLIANCE_MODE=false
COMPLIANCE_FRAMEWORKS="GDPR,SOC2,HIPAA"
AUDIT_TRAIL_ENABLED=true

# Output formats
OUTPUT_JSON=true
OUTPUT_MARKDOWN=true
OUTPUT_HTML=false  # Optional HTML audit report

# ============================================================================
# P1.3.3.1: Argument Parsing
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Enterprise-grade production readiness review using Droid AI with Claude fallback

OPTIONS:
    --commit HASH          Commit hash to review (default: HEAD)
    --timeout SECONDS      Primary AI timeout in seconds (default: 900)
    --output-dir PATH      Output directory for reports (default: auto-generated)
    --format FORMAT        Output format: json|markdown|html|all (default: json,markdown)
    --compliance           Enable compliance mode (GDPR, SOC2, HIPAA checks)
    --frameworks LIST      Comma-separated compliance frameworks (default: GDPR,SOC2,HIPAA)
    --no-audit             Disable audit trail generation
    --no-fallback          Disable fallback to Claude Comprehensive on timeout
    --help                 Show this help message

EXAMPLES:
    # Review latest commit
    $0

    # Enterprise review with compliance checks
    $0 --compliance

    # Custom compliance frameworks
    $0 --compliance --frameworks "GDPR,PCI-DSS,SOX"

    # Full audit report with HTML output
    $0 --compliance --format all

ENVIRONMENT VARIABLES:
    DROID_API_KEY          Required: Droid API key
    CLAUDE_API_KEY         Required for fallback: Claude API key

COMPLIANCE MODE:
    When --compliance is enabled, the review includes:
    - Regulatory compliance checklist (GDPR, SOC2, HIPAA, etc.)
    - SLA conformance evaluation
    - Audit trail generation
    - Performance and reliability risk assessment

For more information, see: docs/REVIEW_ARCHITECTURE.md
EOF
}

# Parse arguments
COMMIT="$DEFAULT_COMMIT"
TIMEOUT="$DEFAULT_TIMEOUT"
OUTPUT_DIR=""
OUTPUT_FORMATS="json,markdown"
ENABLE_FALLBACK=true

while [[ $# -gt 0 ]]; do
    case "$1" in
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
            OUTPUT_FORMATS="$2"
            shift 2
            ;;
        --compliance)
            COMPLIANCE_MODE=true
            shift
            ;;
        --frameworks)
            COMPLIANCE_FRAMEWORKS="$2"
            shift 2
            ;;
        --no-audit)
            AUDIT_TRAIL_ENABLED=false
            shift
            ;;
        --no-fallback)
            ENABLE_FALLBACK=false
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# Note: API keys are not required - AI tools work without them

# ============================================================================
# Validation & Setup
# ============================================================================

# Resolve commit reference first (handles HEAD, branches, tags, etc.)
# Only if in a git repository
if git rev-parse --git-dir > /dev/null 2>&1; then
    COMMIT=$(git rev-parse "$COMMIT" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to resolve commit reference: $COMMIT" >&2
        exit 1
    fi
fi

# Sanitize and validate the resolved commit hash
COMMIT=$(sanitize_commit_input "$COMMIT")
validate_commit_hash "$COMMIT" || exit 1

# Setup output directories
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR=$(setup_review_dirs "$REVIEW_TYPE")
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# ============================================================================
# P1.3.3.4: Audit Trail Functions (MOVED BEFORE USAGE)
# ============================================================================

log_audit() {
    if [[ "$AUDIT_TRAIL_ENABLED" != "true" ]]; then
        return 0
    fi

    local event="$1"
    shift
    local metadata="$@"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] $event | $metadata" >> "$AUDIT_LOG"
}

# P1.3.3.4: Setup audit trail if enabled
AUDIT_LOG=""
if [[ "$AUDIT_TRAIL_ENABLED" == "true" ]]; then
    AUDIT_LOG="$OUTPUT_DIR/audit-trail.log"
    log_audit "Enterprise review started" "commit=$COMMIT" "compliance_mode=$COMPLIANCE_MODE"
fi

# ============================================================================
# P1.3.3.2: Primary AI Execution - Droid Enterprise Review
# ============================================================================

execute_primary_review() {
    local commit="$1"
    local timeout="$2"
    local output_dir="$3"

    # VibeLogger integration - review start
    vibe_review_start "droid" "$commit" "$REVIEW_TYPE"

    log_audit "Primary review (Droid) started" "timeout=${timeout}s"

    if [[ "$COMPLIANCE_MODE" == "true" ]]; then
        echo "Compliance mode enabled: $COMPLIANCE_FRAMEWORKS" >&2
        log_audit "Compliance mode enabled" "frameworks=$COMPLIANCE_FRAMEWORKS"
    fi

    # Get git diff
    local diff_content
    diff_content=$(get_git_diff "$commit") || {
        vibe_review_error "droid" "Failed to get git diff for commit: $commit"
        log_audit "ERROR: Git diff failed" "commit=$commit"
        return 1
    }

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt) || {
        vibe_review_error "droid" "Failed to load REVIEW-PROMPT.md"
        log_audit "ERROR: Review prompt loading failed"
        return 1
    }

    # Construct full prompt with diff
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

# Code Diff to Review

\`\`\`diff
$diff_content
\`\`\`

# Enterprise Production Readiness Review

Please perform a comprehensive enterprise-grade review with the following priorities:

## 1. SLA Conformance
- Evaluate availability, performance, and reliability SLAs
- Identify single points of failure
- Check error handling and recovery mechanisms
- Assess monitoring and observability

## 2. Audit Logging Sufficiency
- Verify comprehensive audit trail generation
- Check log retention and compliance
- Evaluate log security and integrity
- Assess log analysis capabilities

## 3. Security Standards Compliance
- Verify TLS/SSL configuration (minimum TLS 1.2)
- Check encryption standards (AES-256 or equivalent)
- Evaluate authentication and authorization
- Assess secrets management

## 4. Performance & Scalability
- Identify performance bottlenecks
- Evaluate horizontal/vertical scaling readiness
- Check resource utilization efficiency
- Assess database query optimization

## 5. Maintainability & Operations
- Evaluate code maintainability
- Check deployment readiness
- Assess rollback capabilities
- Verify documentation quality

EOF
)

    # P1.3.3.4: Add compliance-specific requirements
    if [[ "$COMPLIANCE_MODE" == "true" ]]; then
        full_prompt+=$(cat <<EOF

## 6. Regulatory Compliance ($COMPLIANCE_FRAMEWORKS)

For each applicable framework, evaluate:

EOF
)

        # Parse frameworks and add specific requirements
        IFS=',' read -ra frameworks <<< "$COMPLIANCE_FRAMEWORKS"
        for framework in "${frameworks[@]}"; do
            case "$framework" in
                GDPR)
                    full_prompt+=$(cat <<EOF
### GDPR (General Data Protection Regulation)
- Data minimization and purpose limitation
- Right to erasure (data deletion)
- Data portability
- Privacy by design and by default
- Data breach notification (72-hour requirement)

EOF
)
                    ;;
                SOC2)
                    full_prompt+=$(cat <<EOF
### SOC 2 (Service Organization Control 2)
- Security controls (access control, encryption)
- Availability controls (uptime, redundancy)
- Processing integrity (accuracy, completeness)
- Confidentiality (data protection)
- Privacy controls (collection, use, retention)

EOF
)
                    ;;
                HIPAA)
                    full_prompt+=$(cat <<EOF
### HIPAA (Health Insurance Portability and Accountability Act)
- PHI (Protected Health Information) handling
- Access controls and audit logging
- Encryption at rest and in transit
- Data integrity and confidentiality
- Breach notification

EOF
)
                    ;;
                PCI-DSS)
                    full_prompt+=$(cat <<EOF
### PCI-DSS (Payment Card Industry Data Security Standard)
- Cardholder data protection
- Encryption of transmission over public networks
- Access control measures
- Regular security testing
- Vulnerability management

EOF
)
                    ;;
            esac
        done
    fi

    full_prompt+=$(cat <<EOF

Provide output in the JSON format specified in the prompt above.
Include enterprise-specific metadata: SLA metrics, compliance status, risk assessment.
EOF
)

    # Execute Droid review with timeout
    local review_output
    local exit_code=0
    local start_time=$(date +%s%3N)

    review_output=$(call_droid_review "$full_prompt" "$timeout") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    # VibeLogger integration - review done
    vibe_review_done "droid" "$REVIEW_TYPE" "$duration_ms" "$exit_code"

    log_audit "Primary review (Droid) completed" "duration=${duration_ms}ms" "exit_code=$exit_code"

    if [[ $exit_code -ne 0 ]]; then
        vibe_review_error "droid" "Primary review failed with exit code: $exit_code"
        log_audit "ERROR: Primary review failed" "exit_code=$exit_code"
        return $exit_code
    fi

    # Validate review output
    if ! validate_review_output "$review_output"; then
        vibe_review_error "droid" "Review output validation failed"
        log_audit "ERROR: Output validation failed"
        return 1
    fi

    # Save output
    echo "$review_output" > "$output_dir/droid-review.json"
    log_audit "Review output saved" "file=droid-review.json"

    # P1.3.3.4: Generate compliance checklist if in compliance mode
    if [[ "$COMPLIANCE_MODE" == "true" ]]; then
        generate_compliance_checklist "$diff_content" > "$output_dir/compliance-checklist.json"
        log_audit "Compliance checklist generated" "file=compliance-checklist.json"
    fi

    return 0
}

# ============================================================================
# P1.3.3.3: Fallback AI - Claude Comprehensive
# ============================================================================

execute_fallback_review() {
    local commit="$1"
    local timeout="$2"
    local output_dir="$3"

    # VibeLogger integration - fallback start
    vibe_review_start "claude" "$commit" "$REVIEW_TYPE"

    echo "Primary AI (Droid) failed or timed out. Falling back to Claude Comprehensive..." >&2
    log_audit "Fallback review (Claude) started" "timeout=${timeout}s"

    # Get git diff (same as primary review)
    local diff_content
    diff_content=$(get_git_diff "$commit") || {
        vibe_review_error "claude" "Failed to get git diff for commit: $commit"
        log_audit "ERROR: Git diff failed" "commit=$commit"
        return 1
    }

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt) || {
        vibe_review_error "claude" "Failed to load REVIEW-PROMPT.md"
        log_audit "ERROR: Review prompt loading failed"
        return 1
    }

    # Construct full prompt with diff (comprehensive review)
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

# Code Diff to Review

\`\`\`diff
$diff_content
\`\`\`

# Comprehensive Quality Review

Please perform a comprehensive code quality review focusing on:
- Code correctness and logic errors
- Best practices and design patterns
- Performance considerations
- Maintainability and readability
- Test coverage adequacy
EOF
)

    # Execute Claude review using adapter
    local exit_code=0
    local start_time=$(date +%s%3N)

    # Use adapter-claude.sh instead of calling script directly
    local review_output
    review_output=$(call_claude_review "$full_prompt" "$timeout") || exit_code=$?

    local end_time=$(date +%s%3N)
    local duration_ms=$((end_time - start_time))

    # VibeLogger integration - review done
    vibe_review_done "claude" "$REVIEW_TYPE" "$duration_ms" "$exit_code"

    log_audit "Fallback review (Claude) completed" "duration=${duration_ms}ms" "exit_code=$exit_code"

    if [[ $exit_code -ne 0 ]]; then
        vibe_review_error "claude" "Fallback review failed with exit code: $exit_code"
        log_audit "ERROR: Fallback review failed" "exit_code=$exit_code"
        return $exit_code
    fi

    # Validate review output
    if ! validate_review_output "$review_output"; then
        vibe_review_error "claude" "Fallback review output validation failed"
        log_audit "ERROR: Fallback output validation failed"
        return 1
    fi

    # Save output
    echo "$review_output" > "$output_dir/claude-review.json"
    log_audit "Fallback review output saved" "file=claude-review.json"

    return 0
}

# ============================================================================
# P1.3.3.5: Output Format Unification
# ============================================================================

generate_markdown_report() {
    local json_file="$1"
    local output_file="$2"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Parse JSON and generate Markdown
    cat > "$output_file" <<EOF
# Enterprise Production Readiness Review Report

**Commit**: $COMMIT
**Reviewer**: $(jq -r '.metadata.ai_reviewer // "unknown"' "$json_file")
**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Duration**: $(jq -r '.metadata.review_duration_ms // 0' "$json_file" | awk '{printf "%.2fs", $1/1000}')
**Compliance Mode**: $(if [[ "$COMPLIANCE_MODE" == "true" ]]; then echo "Enabled ($COMPLIANCE_FRAMEWORKS)"; else echo "Disabled"; fi)

## Overall Assessment

**Status**: $(jq -r '.overall_correctness' "$json_file")
**Confidence**: $(jq -r '.overall_confidence_score // 0' "$json_file" | awk '{printf "%.0f%%", $1*100}')

**Explanation**: $(jq -r '.overall_explanation // "N/A"' "$json_file")

## Findings

EOF

    # Add findings
    local findings_count
    findings_count=$(jq '.findings | length' "$json_file")

    if [[ "$findings_count" -eq 0 ]]; then
        echo "No enterprise readiness issues found." >> "$output_file"
    else
        jq -r '.findings[] |
            "### " + .title + "\n\n" +
            "**Location**: `" + (.code_location.absolute_file_path // "N/A") + ":" +
            ((.code_location.line_range.start // "?") | tostring) + "-" +
            ((.code_location.line_range.end // "?") | tostring) + "`\n" +
            "**Confidence**: " + (((.confidence_score // 0) * 100 | floor) | tostring) + "%\n" +
            "**Priority**: P" + ((.priority // "?") | tostring) + "\n\n" +
            .body + "\n"' \
            "$json_file" >> "$output_file"
    fi

    # Add compliance checklist if available
    if [[ -f "$OUTPUT_DIR/compliance-checklist.json" ]]; then
        cat >> "$output_file" <<EOF

## Compliance Checklist

EOF
        jq -r '.[] |
            "- [" + .status + "] **" + .framework + "**: " + .requirement' \
            "$OUTPUT_DIR/compliance-checklist.json" >> "$output_file"
    fi

    echo "Markdown report generated: $output_file"
}

generate_html_audit_report() {
    local json_file="$1"
    local output_file="$2"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Generate HTML audit report for enterprise stakeholders
    cat > "$output_file" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Production Readiness Audit</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .metadata { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .finding { border-left: 4px solid #e74c3c; padding: 15px; margin: 15px 0; background: #fdf3f3; }
        .finding.p0 { border-left-color: #c0392b; }
        .finding.p1 { border-left-color: #e74c3c; }
        .finding.p2 { border-left-color: #f39c12; }
        .finding.p3 { border-left-color: #95a5a6; }
        .status { font-weight: bold; padding: 5px 10px; border-radius: 3px; }
        .status.correct { background: #2ecc71; color: white; }
        .status.incorrect { background: #e74c3c; color: white; }
        .status.unsure { background: #f39c12; color: white; }
        .compliance-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .compliance-table th, .compliance-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .compliance-table th { background: #34495e; color: white; }
        .badge { display: inline-block; padding: 3px 8px; border-radius: 3px; font-size: 0.85em; margin-left: 5px; }
        .badge.priority { background: #e74c3c; color: white; }
        .badge.confidence { background: #3498db; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Enterprise Production Readiness Audit</h1>

        <div class="metadata">
            <p><strong>Commit:</strong> COMMIT_HASH</p>
            <p><strong>Reviewer:</strong> REVIEWER_NAME</p>
            <p><strong>Date:</strong> REVIEW_DATE</p>
            <p><strong>Duration:</strong> REVIEW_DURATION</p>
            <p><strong>Compliance Mode:</strong> COMPLIANCE_STATUS</p>
        </div>

        <h2>Overall Assessment</h2>
        <p><span class="status STATUS_CLASS">STATUS_TEXT</span></p>
        <p><strong>Confidence:</strong> CONFIDENCE_SCORE</p>
        <p>OVERALL_EXPLANATION</p>

        <h2>Findings (FINDINGS_COUNT)</h2>
        <div id="findings">
            <!-- Findings will be inserted here -->
        </div>

        <h2>Compliance Checklist</h2>
        <table class="compliance-table">
            <thead>
                <tr>
                    <th>Framework</th>
                    <th>Requirement</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody id="compliance">
                <!-- Compliance items will be inserted here -->
            </tbody>
        </table>
    </div>
</body>
</html>
EOF

    # Replace placeholders with actual data
    # Use pipe (|) as delimiter to avoid conflicts with forward slashes in content
    sed -i "s|COMMIT_HASH|$COMMIT|g" "$output_file"
    sed -i "s|REVIEWER_NAME|$(jq -r '.metadata.ai_reviewer // "unknown"' "$json_file")|g" "$output_file"
    sed -i "s|REVIEW_DATE|$(date -u +"%Y-%m-%d %H:%M:%S UTC")|g" "$output_file"
    sed -i "s|REVIEW_DURATION|$(jq -r '.metadata.review_duration_ms // 0' "$json_file" | awk '{printf "%.2fs", $1/1000}')|g" "$output_file"
    sed -i "s|COMPLIANCE_STATUS|$(if [[ "$COMPLIANCE_MODE" == "true" ]]; then echo "Enabled ($COMPLIANCE_FRAMEWORKS)"; else echo "Disabled"; fi)|g" "$output_file"

    local status=$(jq -r '.overall_correctness' "$json_file")
    local status_class=""
    case "$status" in
        "patch is correct") status_class="correct" ;;
        "patch is incorrect") status_class="incorrect" ;;
        *) status_class="unsure" ;;
    esac
    sed -i "s|STATUS_CLASS|$status_class|g" "$output_file"
    sed -i "s|STATUS_TEXT|$status|g" "$output_file"
    sed -i "s|CONFIDENCE_SCORE|$(jq -r '.overall_confidence_score // 0' "$json_file" | awk '{printf "%.0f%%", $1*100}')|g" "$output_file"
    # Escape special sed characters in the explanation: &, \, and newlines
    local explanation=$(jq -r '.overall_explanation // "N/A"' "$json_file" | sed 's/[&\]/\\&/g')
    sed -i "s|OVERALL_EXPLANATION|$explanation|g" "$output_file"
    sed -i "s|FINDINGS_COUNT|$(jq '.findings | length' "$json_file")|g" "$output_file"

    echo "HTML audit report generated: $output_file"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local primary_success=false
    local fallback_success=false
    local primary_output=""
    local fallback_output=""

    echo "=== Enterprise Production Readiness Review Starting ===" >&2
    echo "Commit: $COMMIT" >&2
    echo "Output directory: $OUTPUT_DIR" >&2
    if [[ "$COMPLIANCE_MODE" == "true" ]]; then
        echo "Compliance mode: ENABLED ($COMPLIANCE_FRAMEWORKS)" >&2
    fi
    echo "" >&2

    # Execute primary review (Droid)
    if execute_primary_review "$COMMIT" "$TIMEOUT" "$OUTPUT_DIR"; then
        primary_success=true
        primary_output="$OUTPUT_DIR/droid-review.json"
        echo "✓ Primary review (Droid) completed successfully" >&2
    else
        echo "✗ Primary review (Droid) failed" >&2

        # Execute fallback if enabled
        if [[ "$ENABLE_FALLBACK" == "true" ]]; then
            if execute_fallback_review "$COMMIT" "$FALLBACK_TIMEOUT" "$OUTPUT_DIR"; then
                fallback_success=true
                fallback_output="$OUTPUT_DIR/claude-review.json"
                echo "✓ Fallback review (Claude) completed successfully" >&2
            else
                echo "✗ Fallback review (Claude) failed" >&2
            fi
        fi
    fi

    # Determine which output to use for report generation
    local final_output=""
    if [[ "$primary_success" == "true" ]]; then
        final_output="$primary_output"
    elif [[ "$fallback_success" == "true" ]]; then
        final_output="$fallback_output"
    else
        echo "Error: Both primary and fallback reviews failed" >&2
        log_audit "ERROR: All reviews failed"
        return 1
    fi

    # P1.3.3.5: Generate output formats
    echo "" >&2
    echo "=== Generating Reports ===" >&2

    # Parse output formats
    IFS=',' read -ra FORMATS <<< "$OUTPUT_FORMATS"

    # P0.2.4.2: Fix JSON escape sequences and convert paths to relative before generating other formats
    if [[ -f "$final_output" ]]; then
        echo "Fixing JSON escape sequences..." >&2
        if fix_json_escape_sequences "$final_output"; then
            echo "✓ JSON escape sequences fixed" >&2
        else
            echo "Warning: Could not fix all JSON escape sequences" >&2
        fi

        echo "Converting file paths to relative..." >&2
        if convert_json_to_relative_paths "$final_output"; then
            echo "✓ File paths converted to relative" >&2
        else
            echo "Warning: Could not convert all file paths to relative" >&2
        fi
    fi

    for format in "${FORMATS[@]}"; do
        case "$format" in
            json)
                # JSON already saved and converted
                echo "✓ JSON report: $final_output" >&2
                log_audit "JSON report generated" "file=$final_output"
                ;;
            markdown|md)
                local md_file="${final_output%.json}.md"
                generate_markdown_report "$final_output" "$md_file"
                log_audit "Markdown report generated" "file=$md_file"
                ;;
            html)
                local html_file="${final_output%.json}.html"
                generate_html_audit_report "$final_output" "$html_file"
                log_audit "HTML audit report generated" "file=$html_file"
                ;;
            all)
                # Generate all formats
                local md_file="${final_output%.json}.md"
                local html_file="${final_output%.json}.html"
                generate_markdown_report "$final_output" "$md_file"
                generate_html_audit_report "$final_output" "$html_file"
                echo "✓ JSON report: $final_output" >&2
                log_audit "All reports generated" "json,markdown,html"
                ;;
            *)
                echo "Warning: Unknown format: $format" >&2
                ;;
        esac
    done

    echo "" >&2
    echo "=== Enterprise Production Readiness Review Completed ===" >&2
    echo "Results saved to: $OUTPUT_DIR" >&2

    if [[ "$AUDIT_TRAIL_ENABLED" == "true" ]]; then
        echo "Audit trail: $AUDIT_LOG" >&2
        log_audit "Enterprise review completed successfully"
    fi

    return 0
}

# Execute main function
main "$@"
