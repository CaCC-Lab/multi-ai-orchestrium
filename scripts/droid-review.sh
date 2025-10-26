#!/bin/bash
# Droid Enterprise Standards Review Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Droid enterprise standards review with REVIEW-PROMPT.md guidance
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Specialization: Enterprise standards, production readiness, comprehensive quality assurance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Vibe Logger Setup - MUST be set BEFORE loading vibe-logger-lib.sh
export VIBE_LOG_DIR="$PROJECT_ROOT/logs/vibe/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR"

# Load required libraries
source "$SCRIPT_DIR/lib/sanitize.sh"
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"

DROID_REVIEW_TIMEOUT=${DROID_REVIEW_TIMEOUT:-900}  # Default: 15 minutes (enterprise analysis)
OUTPUT_DIR="${OUTPUT_DIR:-logs/droid-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"
COMPLIANCE_MODE=false
mkdir -p "$OUTPUT_DIR"

# Load REVIEW-PROMPT.md
REVIEW_PROMPT_FILE="$PROJECT_ROOT/REVIEW-PROMPT.md"
if [[ ! -f "$REVIEW_PROMPT_FILE" ]]; then
    echo "❌ REVIEW-PROMPT.md not found: $REVIEW_PROMPT_FILE"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Utility functions
log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Cross-platform millisecond timestamp
get_timestamp_ms() {
    local ts
    ts=$(date +%s%3N 2>/dev/null)
    if [[ "$ts" == *"%"* ]]; then
        echo "$(date +%s)000"
    else
        echo "$ts"
    fi
}

# ======================================
# Vibe Logger Functions
# ======================================

vibe_log() {
    local event_type="$1"
    local action="$2"
    local metadata="$3"
    local human_note="$4"
    local ai_todo="${5:-}"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="droid_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/droid_review_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Droid",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "Enterprise Standards, Production Readiness, Comprehensive QA",
    "todo": "$ai_todo"
  }
}
EOF
}

vibe_tool_start() {
    local action="$1"
    local commit_hash="$2"
    local timeout="$3"

    local metadata=$(cat << EOF
{
  "commit": "$commit_hash",
  "timeout_sec": $timeout,
  "execution_mode": "$action",
  "focus": "enterprise_standards_compliance",
  "compliance_mode": $COMPLIANCE_MODE
}
EOF
)

    vibe_log "tool.start" "$action" "$metadata" \
        "Droidエンタープライズレビュー実行開始: コミット ${commit_hash:0:7}" \
        "verify_compliance,assess_scalability,check_reliability"
}

vibe_tool_done() {
    local action="$1"
    local status="$2"
    local issues_found="${3:-0}"
    local execution_time="${4:-0}"

    local metadata=$(cat << EOF
{
  "status": "$status",
  "issues_found": $issues_found,
  "execution_time_ms": $execution_time
}
EOF
)

    local human_note="Droidエンタープライズレビュー完了: "
    if [[ "$status" == "success" ]]; then
        human_note="${human_note}${issues_found}件のエンタープライズ基準違反を検出"
    else
        human_note="${human_note}実行失敗"
    fi

    vibe_log "tool.done" "$action" "$metadata" "$human_note" \
        "fix_compliance,improve_scalability,ensure_reliability"
}

# Show help message
show_help() {
    cat <<EOF
Droid Enterprise Standards Review Script v1.0.0 (Multi-AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS    Review timeout in seconds (default: $DROID_REVIEW_TIMEOUT)
  -c, --commit HASH        Commit to review (default: HEAD)
  -o, --output DIR         Output directory (default: $OUTPUT_DIR)
  --compliance             Enable compliance mode (GDPR, SOC2, HIPAA checks)
  -h, --help               Show this help message

Focus Areas:
  - Enterprise standards compliance (GDPR, SOC2, HIPAA)
  - Production readiness assessment
  - Scalability & performance evaluation
  - Reliability & fault tolerance
  - Comprehensive quality assurance

Environment Variables:
  DROID_REVIEW_TIMEOUT    Default timeout in seconds
  OUTPUT_DIR              Default output directory

Examples:
  # Review latest commit for enterprise standards
  $0

  # Review with compliance mode (GDPR/SOC2/HIPAA)
  $0 --compliance

  # Review with extended timeout (20 minutes)
  $0 --timeout 1200

  # Review specific commit
  $0 --commit abc123 --compliance

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--timeout)
                DROID_REVIEW_TIMEOUT="$2"
                shift 2
                ;;
            -c|--commit)
                COMMIT_HASH="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --compliance)
                COMPLIANCE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    # Validate timeout
    if ! [[ "$DROID_REVIEW_TIMEOUT" =~ ^[0-9]+$ ]]; then
        log_error "Timeout must be a positive integer: $DROID_REVIEW_TIMEOUT"
        exit 1
    fi

    if [ "$DROID_REVIEW_TIMEOUT" -le 0 ]; then
        log_error "Timeout must be greater than 0: $DROID_REVIEW_TIMEOUT"
        exit 1
    fi

    # Validate commit hash format (basic check)
    if [ -n "$COMMIT_HASH" ] && [[ ! "$COMMIT_HASH" =~ ^[a-fA-F0-9]{4,40}$|^HEAD$ ]]; then
        # Allow branch/tag names to pass through - git will validate
        true
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Droid wrapper is available
    if [[ -x "$PROJECT_ROOT/bin/droid-wrapper.sh" ]]; then
        log_success "Droid wrapper is available"
    else
        log_error "Droid wrapper not found at $PROJECT_ROOT/bin/droid-wrapper.sh"
        exit 1
    fi

    # Check if in git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    # Verify commit exists
    if ! git rev-parse --verify "$COMMIT_HASH" >/dev/null 2>&1; then
        log_error "Commit not found: $COMMIT_HASH"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Execute Droid enterprise review
execute_droid_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_json="$OUTPUT_DIR/${timestamp}_${commit_short}_droid.json"
    local output_md="$OUTPUT_DIR/${timestamp}_${commit_short}_droid.md"
    local output_compliance="$OUTPUT_DIR/${timestamp}_${commit_short}_droid_compliance.json"
    local start_time=$(get_timestamp_ms)

    vibe_tool_start "droid_enterprise_review" "$COMMIT_HASH" "$DROID_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available")

    # Read REVIEW-PROMPT.md
    local review_guidelines
    review_guidelines=$(cat "$REVIEW_PROMPT_FILE")

    # Compliance mode specific checks
    local compliance_section=""
    if [ "$COMPLIANCE_MODE" = true ]; then
        compliance_section="

## Compliance Mode Activated

Perform additional compliance checks for:

1. **GDPR Compliance**:
   - Personal data handling & processing
   - Data retention policies
   - Right to erasure implementation
   - Data portability support
   - Consent management
   - Privacy by design principles

2. **SOC 2 Compliance**:
   - Access control mechanisms
   - Audit logging & monitoring
   - Change management procedures
   - Incident response readiness
   - Data encryption (at rest & in transit)

3. **HIPAA Compliance** (if healthcare-related):
   - PHI (Protected Health Information) handling
   - Access controls & authentication
   - Audit trails & logging
   - Data encryption requirements
   - Business associate agreements
"
    fi

    # Create comprehensive enterprise-focused prompt
    local review_prompt="# Droid Enterprise Standards-Focused Code Review

You are performing an enterprise standards and production readiness review using the following guidelines:

$review_guidelines

## Commit Information
- **Commit**: $COMMIT_HASH
- **Short**: $commit_short
- **Subject**: $(git show --format="%s" -s "$COMMIT_HASH" 2>/dev/null)
- **Author**: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null)
- **Date**: $(git show --format="%ad" -s "$COMMIT_HASH" 2>/dev/null)

## Changes
\`\`\`diff
$diff_content
\`\`\`
$compliance_section

## Enterprise Standards Analysis Focus

As Droid (Enterprise QA Engineer), focus on:

1. **Enterprise Standards Compliance**:
   - Code meets organizational coding standards
   - Architecture aligns with enterprise patterns
   - Dependency management policies
   - Licensing compliance (open source, proprietary)
   - Version control best practices
   - Code ownership & maintainability

2. **Production Readiness**:
   - Deployment considerations
   - Configuration management
   - Environment-specific settings
   - Feature flags / toggles
   - Backward compatibility
   - Rollback mechanisms
   - Graceful degradation
   - Circuit breakers / bulkheads

3. **Scalability Assessment**:
   - Horizontal scaling capabilities
   - Vertical scaling limitations
   - Database query efficiency
   - Caching strategies
   - Load balancing considerations
   - Resource utilization (CPU, memory, I/O)
   - Concurrency handling
   - Rate limiting / throttling

4. **Reliability & Fault Tolerance**:
   - Error handling robustness
   - Retry logic & exponential backoff
   - Timeout configurations
   - Dead letter queues
   - Health check endpoints
   - Graceful shutdown procedures
   - Data consistency mechanisms
   - Idempotency guarantees

5. **Maintainability & Observability**:
   - Logging completeness & quality
   - Metrics & monitoring instrumentation
   - Distributed tracing support
   - Alerting thresholds
   - Debugging capabilities
   - Documentation currency
   - Runbook / playbook updates
   - SLA/SLO/SLI definitions

6. **Security & Compliance**:
   - Authentication & authorization
   - Input validation & sanitization
   - SQL injection prevention
   - XSS protection
   - CSRF tokens
   - Secrets management
   - Security headers
   - Dependency vulnerability scanning

## Output Requirements

Return findings in JSON format following REVIEW-PROMPT.md structure:

\`\`\`json
{
  \"findings\": [
    {
      \"title\": \"[P0-P3] <issue title>\",
      \"body\": \"<markdown explanation with file:line references>\",
      \"confidence_score\": <0.0-1.0>,
      \"priority\": <0-3>,
      \"code_location\": {
        \"absolute_file_path\": \"<path>\",
        \"line_range\": {\"start\": <int>, \"end\": <int>}
      }
    }
  ],
  \"overall_correctness\": \"patch is correct\" | \"patch is incorrect\",
  \"overall_explanation\": \"<1-3 sentence justification>\",
  \"overall_confidence_score\": <0.0-1.0>
}
\`\`\`

**Priority Levels**:
- **P0**: Drop everything. Blocks release/production. Universal issues.
- **P1**: Urgent. Address in next cycle.
- **P2**: Normal. Should eventually be fixed.
- **P3**: Low. Nice to have.

**Important**: Focus on NEW issues introduced in this commit, not pre-existing problems."

    # Execute Droid wrapper with timeout
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/droid-review-prompt-XXXXXX.txt")
    chmod 600 "$prompt_file"
    echo "$review_prompt" > "$prompt_file"

    # Set DROID_MCP_TIMEOUT to override wrapper's default timeout
    export DROID_MCP_TIMEOUT="$DROID_REVIEW_TIMEOUT"

    local droid_output
    if droid_output=$(timeout "$DROID_REVIEW_TIMEOUT" "$PROJECT_ROOT/bin/droid-wrapper.sh" --stdin < "$prompt_file" 2>&1); then
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # Remove Markdown code blocks if present
        droid_output=$(echo "$droid_output" | sed '/^```json$/d; /^```$/d' | sed '/^Loaded cached credentials\.$/d')

        # Parse JSON output
        if echo "$droid_output" | jq empty 2>/dev/null; then
            echo "$droid_output" > "$output_json"

            # Count findings
            local findings_count
            findings_count=$(echo "$droid_output" | jq '.findings | length' 2>/dev/null || echo "0")

            # Generate Markdown report
            generate_markdown_report "$droid_output" "$output_md"

            # Generate compliance report if enabled
            if [ "$COMPLIANCE_MODE" = true ]; then
                generate_compliance_report "$droid_output" "$output_compliance"
            fi

            vibe_tool_done "droid_enterprise_review" "success" "$findings_count" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        else
            # Not JSON, treat as text
            echo "$droid_output" > "${output_json%.json}.txt"

            # Generate fallback reports
            generate_fallback_json "$droid_output" "$output_json"
            generate_markdown_report "$(cat "$output_json")" "$output_md"

            local issues_found
            issues_found=$(grep -icE "(compliance|scalability|reliability|enterprise|production)" "$output_json" || echo "0")

            vibe_tool_done "droid_enterprise_review" "success" "$issues_found" "$execution_time"

            rm -f "$prompt_file"
            echo "$output_json:$output_md:0"
        fi
    else
        local exit_code=$?
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        vibe_tool_done "droid_enterprise_review" "failed" "0" "$execution_time"

        rm -f "$prompt_file"
        echo "::$exit_code"
    fi
}

# Generate fallback JSON from text output
generate_fallback_json() {
    local text_output="$1"
    local output_file="$2"

    # Extract key enterprise keywords
    local compliance_count=$(echo "$text_output" | grep -icE "compliance|gdpr|soc2|hipaa" || echo "0")
    local scalability_count=$(echo "$text_output" | grep -icE "scalability|performance" || echo "0")
    local reliability_count=$(echo "$text_output" | grep -icE "reliability|fault.tolerance" || echo "0")

    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$(git rev-parse --short "$COMMIT_HASH")",
  "review_type": "droid_enterprise",
  "compliance_mode": $COMPLIANCE_MODE,
  "findings": [],
  "analysis": {
    "compliance_mentions": $compliance_count,
    "scalability_mentions": $scalability_count,
    "reliability_mentions": $reliability_count
  },
  "overall_correctness": "unknown",
  "overall_explanation": "Droid returned non-JSON output. See raw text file for details.",
  "overall_confidence_score": 0.5,
  "raw_output_file": "${output_file%.json}.txt"
}
EOF
}

# Generate Markdown report from JSON
generate_markdown_report() {
    local json_data="$1"
    local output_file="$2"

    local compliance_badge=""
    if [ "$COMPLIANCE_MODE" = true ]; then
        compliance_badge=" 🛡️ COMPLIANCE MODE"
    fi

    cat > "$output_file" <<EOF
# Droid Enterprise Standards-Focused Code Review Report$compliance_badge

**Commit**: \`$(git rev-parse --short "$COMMIT_HASH")\` (\`$COMMIT_HASH\`)
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Timeout**: ${DROID_REVIEW_TIMEOUT}s
**Review Type**: Enterprise Standards & Production Readiness

## Overview

EOF

    # Extract overall assessment
    local overall_correctness
    overall_correctness=$(echo "$json_data" | jq -r '.overall_correctness // "unknown"')
    local overall_explanation
    overall_explanation=$(echo "$json_data" | jq -r '.overall_explanation // "No explanation provided"')
    local overall_confidence
    overall_confidence=$(echo "$json_data" | jq -r '.overall_confidence_score // 0.5')

    cat >> "$output_file" <<EOF
- **Overall Correctness**: $overall_correctness
- **Confidence Score**: $overall_confidence
- **Explanation**: $overall_explanation

## Enterprise Findings

EOF

    # Extract and categorize findings by priority
    local findings_count
    findings_count=$(echo "$json_data" | jq '.findings | length' 2>/dev/null || echo "0")

    if [ "$findings_count" -eq 0 ]; then
        echo "✅ No enterprise/production issues detected in this commit." >> "$output_file"
    else
        # Group by priority
        for priority in 0 1 2 3; do
            local priority_label
            case $priority in
                0) priority_label="🔴 P0 - Critical (Drop Everything)" ;;
                1) priority_label="🟠 P1 - Urgent (Next Cycle)" ;;
                2) priority_label="🟡 P2 - Normal (Eventually Fix)" ;;
                3) priority_label="🟢 P3 - Low (Nice to Have)" ;;
            esac

            local priority_findings
            priority_findings=$(echo "$json_data" | jq --arg p "$priority" '.findings[] | select(.priority == ($p | tonumber))')

            if [ -n "$priority_findings" ]; then
                echo "" >> "$output_file"
                echo "### $priority_label" >> "$output_file"
                echo "" >> "$output_file"

                echo "$json_data" | jq -r --arg p "$priority" '.findings[] | select(.priority == ($p | tonumber)) |
                    "#### " + .title + "\n\n" +
                    "**File**: `" + .code_location.absolute_file_path + "` (Lines " + (.code_location.line_range.start | tostring) + "-" + (.code_location.line_range.end | tostring) + ")\n" +
                    "**Confidence**: " + (.confidence_score | tostring) + "\n\n" +
                    .body + "\n"' >> "$output_file"
            fi
        done
    fi

    cat >> "$output_file" <<EOF

## Droid Specialization

This review focused on:
- Enterprise standards compliance (GDPR, SOC2, HIPAA)
- Production readiness & deployment considerations
- Scalability & performance evaluation
- Reliability & fault tolerance assessment
- Comprehensive quality assurance & observability

---
*Generated by Multi-AI Orchestrium - Droid Enterprise Review*
EOF
}

# Generate compliance-specific report
generate_compliance_report() {
    local json_data="$1"
    local output_file="$2"

    # Extract compliance-related findings
    local compliance_findings
    compliance_findings=$(echo "$json_data" | jq '[.findings[] | select(.title | test("(?i)gdpr|soc2|hipaa|compliance|privacy|audit"))]')

    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "compliance_mode": true,
  "compliance_findings": $compliance_findings,
  "compliance_summary": {
    "total_findings": $(echo "$compliance_findings" | jq 'length'),
    "critical_count": $(echo "$compliance_findings" | jq '[.[] | select(.priority == 0)] | length'),
    "urgent_count": $(echo "$compliance_findings" | jq '[.[] | select(.priority == 1)] | length')
  }
}
EOF

    log_info "Compliance report generated: $output_file"
}

# Create symlinks to latest review
create_symlinks() {
    local json_file="$1"
    local md_file="$2"

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_droid.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_droid.md"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Droid Enterprise Review v1.0.0        ║"
    echo "║  Multi-AI + VibeLogger + REVIEW-PROMPT ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    validate_args
    check_prerequisites

    if [ "$COMPLIANCE_MODE" = true ]; then
        log_warning "Compliance mode enabled: GDPR/SOC2/HIPAA checks active"
    fi

    local result
    result=$(execute_droid_review)

    local json_file="${result%%:*}"
    local remaining="${result#*:}"
    local md_file="${remaining%%:*}"
    local status="${remaining##*:}"

    if [ -f "$json_file" ] && [ -f "$md_file" ]; then
        create_symlinks "$json_file" "$md_file"

        echo ""
        log_success "Droid enterprise review complete!"
        echo ""
        log_info "Results:"
        echo "  - JSON: $json_file"
        echo "  - Markdown: $md_file"
        if [ "$COMPLIANCE_MODE" = true ] && [ -f "$OUTPUT_DIR/$(basename "${json_file%.json}_compliance.json")" ]; then
            echo "  - Compliance: $OUTPUT_DIR/$(basename "${json_file%.json}_compliance.json")"
        fi

        exit 0
    else
        log_error "Review failed - no output generated"
        exit "$status"
    fi
}

main "$@"
