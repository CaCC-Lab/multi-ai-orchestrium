#!/bin/bash
# Claude Security Review Integration Script - Multi-AI対応 VibeLogger統合版
# Version: 1.0.0
# Purpose: Execute Claude security review with OWASP Top 10 and CWE vulnerability detection
# Multi-AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
# Reference: scripts/claude-review.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load sanitization library
source "$SCRIPT_DIR/lib/sanitize.sh"
SECURITY_REVIEW_TIMEOUT=${SECURITY_REVIEW_TIMEOUT:-900}  # Default: 15 minutes
OUTPUT_DIR="${OUTPUT_DIR:-logs/claude-security-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"
MIN_SEVERITY="${MIN_SEVERITY:-Low}"  # Critical/High/Medium/Low

# Vibe Logger Setup
VIBE_LOG_DIR="$PROJECT_ROOT/logs/ai-coop/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR" "$OUTPUT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Security Rules - OWASP Top 10 & CWE mappings
declare -A SECURITY_RULES
SECURITY_RULES[sql_injection]="CWE-89|SQL Injection|exec.*sql|query.*\$|SELECT.*FROM|INSERT.*INTO|UPDATE.*SET|DELETE.*FROM"
SECURITY_RULES[xss]="CWE-79|Cross-Site Scripting|innerHTML|document\.write|eval\(|dangerouslySetInnerHTML"
SECURITY_RULES[command_injection]="CWE-77,CWE-78|Command Injection|exec\(|system\(|popen\(|shell_exec|passthru"
SECURITY_RULES[path_traversal]="CWE-22|Path Traversal|\.\./|\.\.\\\\|readFile.*\$|open.*\$"
SECURITY_RULES[hardcoded_secrets]="CWE-798|Hardcoded Credentials|password\s*=\s*['\"]|api_key\s*=\s*['\"]|secret\s*=\s*['\"]|token\s*=\s*['\"]"
SECURITY_RULES[insecure_crypto]="CWE-327|Insecure Cryptography|MD5|SHA1(?!256)|DES|RC4"
SECURITY_RULES[unsafe_deserialization]="CWE-502|Unsafe Deserialization|unserialize|pickle\.loads|yaml\.load(?!_safe)|eval"

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
    local runid="claude_security_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/claude_security_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "$event_type",
  "action": "$action",
  "metadata": $metadata,
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Claude",
    "type": "security_review",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "todo": "$ai_todo"
  }
}
EOF
}

vibe_security_start() {
    local commit_hash="$1"
    local timeout="$2"

    local metadata=$(cat << EOF
{
  "commit": "$commit_hash",
  "timeout_sec": $timeout,
  "min_severity": "$MIN_SEVERITY",
  "security_rules": $(echo "${!SECURITY_RULES[@]}" | jq -R 'split(" ")')
}
EOF
)

    vibe_log "security.start" "security_scan" "$metadata" \
        "セキュリティレビュー開始: コミット ${commit_hash:0:7}" \
        "scan_vulnerabilities,assess_risk,generate_remediation"
}

vibe_vulnerability_found() {
    local vulnerability_type="$1"
    local severity="$2"
    local cwe_id="$3"
    local count="${4:-1}"

    local metadata=$(cat << EOF
{
  "type": "$vulnerability_type",
  "severity": "$severity",
  "cwe_id": "$cwe_id",
  "count": $count
}
EOF
)

    vibe_log "security.vulnerability" "found" "$metadata" \
        "脆弱性検出: $vulnerability_type ($severity)" \
        "analyze_impact,create_remediation,prioritize_fix"
}

vibe_security_done() {
    local status="$1"
    local total_vulnerabilities="${2:-0}"
    local execution_time="${3:-0}"

    local metadata=$(cat << EOF
{
  "status": "$status",
  "total_vulnerabilities": $total_vulnerabilities,
  "execution_time_ms": $execution_time
}
EOF
)

    vibe_log "security.done" "security_scan" "$metadata" \
        "セキュリティレビュー完了: $total_vulnerabilities 件の脆弱性" \
        "review_findings,schedule_remediation,update_security_posture"
}

# Show help message
show_help() {
    cat <<EOF
Claude Security Review Integration Script v1.0.0 (Multi-AI + VibeLogger)

Usage: $0 [OPTIONS]

Options:
  -t, --timeout SECONDS      Review timeout in seconds (default: $SECURITY_REVIEW_TIMEOUT)
  -c, --commit HASH          Commit to review (default: HEAD)
  -o, --output DIR           Output directory (default: $OUTPUT_DIR)
  -s, --severity LEVEL       Minimum severity level: Critical, High, Medium, Low (default: $MIN_SEVERITY)
  -h, --help                 Show this help message

Environment Variables:
  SECURITY_REVIEW_TIMEOUT    Default timeout in seconds
  OUTPUT_DIR                 Default output directory
  MIN_SEVERITY               Minimum severity level

Security Checks:
  - SQL Injection (CWE-89)
  - Cross-Site Scripting (CWE-79)
  - Command Injection (CWE-77, CWE-78)
  - Path Traversal (CWE-22)
  - Hardcoded Secrets (CWE-798)
  - Insecure Cryptography (CWE-327)
  - Unsafe Deserialization (CWE-502)

Examples:
  # Review latest commit with default timeout (15 minutes)
  $0

  # Review with custom timeout (20 minutes) and severity filter
  $0 --timeout 1200 --severity High

  # Review specific commit
  $0 --commit abc123

  # Custom output directory
  $0 --output /tmp/security-reviews

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--timeout)
                SECURITY_REVIEW_TIMEOUT="$2"
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
            -s|--severity)
                MIN_SEVERITY="$2"
                shift 2
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Claude wrapper is available
    if [[ -x "$PROJECT_ROOT/bin/claude-wrapper.sh" ]]; then
        log_success "Claude wrapper is available"
        USE_CLAUDE="true"
    else
        log_warning "Claude wrapper not found, using pattern-based security scan"
        USE_CLAUDE="false"
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

# Create output directory
setup_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    log_success "Output directory: $OUTPUT_DIR"
}

# Security check functions
check_security_patterns() {
    local diff_content="$1"
    local output_file="$2"

    local total_vulnerabilities=0

    echo "## Pattern-Based Security Analysis" >> "$output_file"
    echo "" >> "$output_file"

    for rule_key in "${!SECURITY_RULES[@]}"; do
        local rule_value="${SECURITY_RULES[$rule_key]}"
        IFS='|' read -r cwe_id description pattern <<< "$rule_value"

        local matches=$(echo "$diff_content" | grep -iE "$pattern" 2>/dev/null || true)

        if [[ -n "$matches" ]]; then
            local count=$(echo "$matches" | wc -l)
            total_vulnerabilities=$((total_vulnerabilities + count))

            echo "### 🔴 $description ($cwe_id)" >> "$output_file"
            echo "" >> "$output_file"
            echo "**Matches found**: $count" >> "$output_file"
            echo "" >> "$output_file"
            echo '```' >> "$output_file"
            echo "$matches" | head -10 >> "$output_file"
            echo '```' >> "$output_file"
            echo "" >> "$output_file"

            # Log to VibeLogger
            vibe_vulnerability_found "$description" "Medium" "$cwe_id" "$count"
        fi
    done

    echo "$total_vulnerabilities"
}

# Execute security review using Claude
execute_claude_security_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_security.log"
    local status=0
    local start_time=$(get_timestamp_ms)

    # VibeLogger: security.start
    vibe_security_start "$COMMIT_HASH" "$SECURITY_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available")

    # Create prompt for Claude
    local security_prompt="Please perform a comprehensive security review of the following commit focusing on OWASP Top 10 and CWE vulnerabilities:

Commit: $COMMIT_HASH ($(git show --format="%s" -s "$COMMIT_HASH" 2>/dev/null))
Author: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null)
Date: $(git show --format="%ad" -s "$COMMIT_HASH" 2>/dev/null)

Security Focus Areas:
1. SQL Injection (CWE-89)
2. Cross-Site Scripting (CWE-79)
3. Command Injection (CWE-77, CWE-78)
4. Path Traversal (CWE-22)
5. Hardcoded Secrets (CWE-798)
6. Insecure Cryptography (CWE-327)
7. Unsafe Deserialization (CWE-502)
8. Authentication & Authorization issues
9. Insecure Direct Object References
10. Security Misconfiguration

Changes:
$diff_content

For each vulnerability found, provide:
- Vulnerability type and CWE ID
- Severity level (Critical/High/Medium/Low)
- Specific code location
- Detailed explanation
- Remediation suggestions with code examples
- CVSS v3.1 score if applicable"

    # Security: Use mktemp for secure temporary file creation
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/claude-security-prompt-XXXXXX.txt")
    chmod 600 "$prompt_file"  # Ensure only owner can read/write
    echo "$security_prompt" > "$prompt_file"

    if timeout "$SECURITY_REVIEW_TIMEOUT" bash -c "$PROJECT_ROOT/bin/claude-wrapper.sh --stdin < '$prompt_file'" > "$output_file" 2>&1; then
        status=0
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # Count vulnerabilities
        local vuln_count
        vuln_count=$(grep -icE "(vulnerability|CWE-|CRITICAL|HIGH)" "$output_file" 2>/dev/null || echo "0")

        # VibeLogger: security.done (success)
        vibe_security_done "success" "$vuln_count" "$execution_time"
    else
        local exit_code=$?
        status=$exit_code
        local end_time=$(get_timestamp_ms)
        local execution_time=$((end_time - start_time))

        # VibeLogger: security.done (failed)
        vibe_security_done "failed" "0" "$execution_time"
    fi

    # Clean up
    [ -f "$prompt_file" ] && rm -f "$prompt_file"

    echo "$output_file:$status"
}

# Execute pattern-based security review (fallback)
execute_pattern_security_review() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_security_pattern.log"
    local status=0
    local start_time=$(get_timestamp_ms)

    # VibeLogger: security.start
    vibe_security_start "$COMMIT_HASH" "$SECURITY_REVIEW_TIMEOUT"

    # Get the diff for the commit
    local diff_content
    diff_content=$(git show --no-color "$COMMIT_HASH" 2>/dev/null || echo "No diff available")

    # Create header
    {
        echo "# Pattern-Based Security Review Report"
        echo ""
        echo "## Commit Information"
        echo "- Commit: $COMMIT_HASH ($commit_short)"
        echo "- Date: $(date)"
        echo "- Author: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null)"
        echo ""
    } > "$output_file"

    # Run pattern-based checks
    local total_vulnerabilities
    total_vulnerabilities=$(check_security_patterns "$diff_content" "$output_file")

    # Add summary
    {
        echo "## Summary"
        echo ""
        echo "- **Total Vulnerabilities Found**: $total_vulnerabilities"
        echo "- **Scan Type**: Pattern-Based (Regex)"
        echo "- **Minimum Severity**: $MIN_SEVERITY"
        echo ""
        echo "## Recommendations"
        echo ""
        echo "1. Review all detected vulnerabilities"
        echo "2. Apply security best practices"
        echo "3. Consider using static analysis tools (e.g., Semgrep, SonarQube)"
        echo "4. Implement security testing in CI/CD pipeline"
        echo "5. Follow OWASP guidelines for secure coding"
        echo ""
    } >> "$output_file"

    local end_time=$(get_timestamp_ms)
    local execution_time=$((end_time - start_time))

    # VibeLogger: security.done
    vibe_security_done "success" "$total_vulnerabilities" "$execution_time"

    echo "$output_file:$status"
}

# Generate security report (JSON, Markdown, SARIF)
generate_security_report() {
    local log_file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH")

    # JSON report
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_security.json"
    local vuln_count=$(grep -icE "(CWE-|vulnerability)" "$log_file" 2>/dev/null || echo "0")

    cat > "$json_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$COMMIT_HASH",
  "commit_short": "$commit_short",
  "scan_type": "security",
  "min_severity": "$MIN_SEVERITY",
  "total_vulnerabilities": $vuln_count,
  "log_file": "$log_file"
}
EOF

    # Markdown report
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_security.md"
    head -500 "$log_file" > "$md_file"

    # SARIF report (basic structure)
    local sarif_file="$OUTPUT_DIR/${timestamp}_${commit_short}_security.sarif"
    cat > "$sarif_file" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Claude Security Review",
          "version": "1.0.0",
          "informationUri": "https://claude.com"
        }
      },
      "results": []
    }
  ]
}
EOF

    echo "$json_file:$md_file:$sarif_file"
}

# Create symlinks to latest review
create_symlinks() {
    local json_file="$1"
    local md_file="$2"
    local sarif_file="$3"

    ln -sf "$(basename "$json_file")" "$OUTPUT_DIR/latest_security.json"
    ln -sf "$(basename "$md_file")" "$OUTPUT_DIR/latest_security.md"
    ln -sf "$(basename "$sarif_file")" "$OUTPUT_DIR/latest_security.sarif"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║  Claude Security Review Integration v1.0.0     ║"
    echo "║  OWASP Top 10 + CWE + VibeLogger              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    check_prerequisites
    setup_output_dir

    local result
    local log_file
    local status

    if [[ "$USE_CLAUDE" == "true" ]]; then
        # Execute Claude security review
        result=$(execute_claude_security_review 2>/dev/null || echo "")
        log_file="${result%%:*}"
        status="${result##*:}"

        if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
            log_warning "Claude review failed, falling back to pattern-based scan"
            result=$(execute_pattern_security_review)
            log_file="${result%%:*}"
            status="${result##*:}"
        fi
    else
        # Execute pattern-based security review
        result=$(execute_pattern_security_review)
        log_file="${result%%:*}"
        status="${result##*:}"
    fi

    # Generate reports
    local reports
    reports=$(generate_security_report "$log_file")
    IFS=':' read -r json_file md_file sarif_file <<< "$reports"

    create_symlinks "$json_file" "$md_file" "$sarif_file"

    echo ""
    log_success "Security review complete!"
    echo ""
    log_info "Results:"
    echo "  - JSON: $json_file"
    echo "  - Markdown: $md_file"
    echo "  - SARIF: $sarif_file"
    echo "  - Log: $log_file"

    exit $status
}

main "$@"
