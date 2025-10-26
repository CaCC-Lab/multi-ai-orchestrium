# Gemini Review Script Guide

**Script**: `scripts/gemini-review.sh`
**AI**: Gemini 2.5
**Version**: 1.0.0
**Specialization**: Security & Architecture Review

---

## Table of Contents

- [Overview](#overview)
- [Core Capabilities](#core-capabilities)
- [When to Use Gemini Review](#when-to-use-gemini-review)
- [Installation & Prerequisites](#installation--prerequisites)
- [Basic Usage](#basic-usage)
- [Command-Line Options](#command-line-options)
- [Output Formats](#output-formats)
- [Interpreting Results](#interpreting-results)
- [Common Use Cases](#common-use-cases)
- [Workflow Integration](#workflow-integration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

---

## Overview

The Gemini review script leverages Gemini 2.5's capabilities to perform **security-focused code reviews** with an emphasis on **OWASP Top 10 vulnerabilities**, **latest technology best practices**, and **architecture security assessments**.

### Key Features

- **Security Vulnerability Detection**: OWASP Top 10, CWE-based analysis
- **Latest Technology Patterns**: Web search integration for current best practices
- **Architecture Review**: Scalability, security design patterns
- **200M Token Context**: Handles large codebases effectively
- **VibeLogger Integration**: AI-optimized structured logging

### Typical Review Scope

- Authentication & Authorization systems
- API security (REST, GraphQL, gRPC)
- Data handling & encryption
- Input validation & sanitization
- External service integrations
- Infrastructure as Code (IaC) security

---

## Core Capabilities

### 1. OWASP Top 10 Coverage

Gemini Review automatically checks for:

| OWASP Category | Detection Focus |
|---------------|----------------|
| A01 Broken Access Control | Missing authorization checks, IDOR vulnerabilities |
| A02 Cryptographic Failures | Weak encryption, exposed secrets, insecure storage |
| A03 Injection | SQL injection, XSS, command injection, LDAP injection |
| A04 Insecure Design | Missing security controls, flawed architecture |
| A05 Security Misconfiguration | Default credentials, unnecessary services, stack traces |
| A06 Vulnerable Components | Outdated dependencies, known CVEs |
| A07 Authentication Failures | Weak passwords, session management issues |
| A08 Data Integrity Failures | Unverified data, insecure deserialization |
| A09 Logging Failures | Insufficient logging, log injection |
| A10 SSRF | Unvalidated URLs, internal service exposure |

### 2. Architecture Security Assessment

- **Scalability**: Bottleneck identification, resource management
- **Design Patterns**: Secure design pattern validation
- **Microservices**: Service mesh security, inter-service auth
- **Cloud Security**: IAM roles, network policies, encryption at rest/transit

### 3. Latest Best Practices

Gemini's **Web search integration** ensures:
- Current CVE awareness
- Latest framework security features
- Industry-standard compliance (GDPR, PCI-DSS awareness)
- Emerging threat detection

---

## When to Use Gemini Review

### Ideal Scenarios

1. **Security-Critical Changes**
   - Authentication/authorization implementation
   - Payment processing logic
   - User data handling
   - API endpoint additions

2. **External Integration**
   - Third-party API integration
   - Webhook implementations
   - OAuth/SAML implementations
   - Cloud service integrations

3. **Infrastructure Changes**
   - Deployment configuration updates
   - Network policy changes
   - Container security configurations
   - CI/CD pipeline modifications

4. **Pre-Production Gate**
   - Final security review before release
   - Compliance verification
   - Security regression testing

### When NOT to Use (Prefer Other AIs)

- **Code Quality Focus**: Use Qwen Review for implementation patterns
- **Developer Experience**: Use Cursor Review for readability/IDE integration
- **Documentation**: Use Amp Review for doc quality
- **Enterprise Standards**: Use Droid Review for comprehensive compliance

---

## Installation & Prerequisites

### Prerequisites

1. **Gemini Wrapper Script**
   ```bash
   # Check availability
   which gemini-wrapper.sh
   # Expected: /path/to/multi-ai-orchestrium/bin/gemini-wrapper.sh
   ```

2. **Git Repository**
   - Must be run within a Git repository
   - Valid commit history required

3. **REVIEW-PROMPT.md**
   - Located at project root
   - Provides review structure and guidelines

4. **Dependencies**
   - `bash` 4.0+
   - `git` 2.0+
   - `jq` (for JSON parsing)

### Environment Setup

```bash
# Optional: Set default timeout (default: 600 seconds = 10 minutes)
export GEMINI_REVIEW_TIMEOUT=900

# Optional: Set custom output directory
export OUTPUT_DIR=logs/my-gemini-reviews
```

---

## Basic Usage

### Quick Start

```bash
# Review latest commit
bash scripts/gemini-review.sh

# Review with extended timeout (15 minutes)
bash scripts/gemini-review.sh --timeout 900

# Review specific commit
bash scripts/gemini-review.sh --commit abc123

# Custom output directory
bash scripts/gemini-review.sh --output my-reviews/
```

### Typical Workflow

```bash
# 1. Make security-related changes
git add authentication/oauth-handler.ts

# 2. Commit changes
git commit -m "feat: Add OAuth2 authentication handler"

# 3. Run Gemini security review
bash scripts/gemini-review.sh

# 4. Review output
cat logs/gemini-reviews/latest_gemini.md
```

---

## Command-Line Options

### Options Summary

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--timeout` | `-t` | Review timeout in seconds | 600 (10 min) |
| `--commit` | `-c` | Commit hash to review | HEAD |
| `--output` | `-o` | Output directory path | logs/gemini-reviews |
| `--help` | `-h` | Show help message | N/A |

### Detailed Options

#### `--timeout SECONDS` (`-t`)

Controls the maximum execution time for Gemini review.

**Recommended values**:
- **Small commits** (<100 lines): 300s (5 min)
- **Medium commits** (100-500 lines): 600s (10 min) - **DEFAULT**
- **Large commits** (500-1000 lines): 900s (15 min)
- **Complex security changes**: 1200s (20 min)

**Example**:
```bash
# Security review with 15-minute timeout
bash scripts/gemini-review.sh --timeout 900
```

#### `--commit HASH` (`-c`)

Specify which commit to review.

**Formats supported**:
- Full hash: `abc123def456...`
- Short hash: `abc123`
- `HEAD` (default)
- `HEAD~1`, `HEAD~2`, etc.
- Branch names: `main`, `feature/auth`
- Tags: `v1.0.0`

**Example**:
```bash
# Review specific commit
bash scripts/gemini-review.sh --commit abc123

# Review previous commit
bash scripts/gemini-review.sh --commit HEAD~1

# Review entire branch
git diff main...feature/auth > /tmp/diff.txt
bash scripts/gemini-review.sh --commit feature/auth
```

#### `--output DIR` (`-o`)

Custom output directory for review results.

**Default structure**:
```
logs/gemini-reviews/
├── 20251026_210000_abc123_gemini.json   # JSON report
├── 20251026_210000_abc123_gemini.md     # Markdown report
├── latest_gemini.json                   # Symlink to latest JSON
└── latest_gemini.md                     # Symlink to latest Markdown
```

**Example**:
```bash
# Custom output directory
bash scripts/gemini-review.sh --output security-audit/
```

---

## Output Formats

### JSON Report

**Location**: `logs/gemini-reviews/{timestamp}_{commit}_gemini.json`

**Structure**:
```json
{
  "metadata": {
    "ai": "Gemini",
    "version": "2.5",
    "specialization": "Security & Architecture",
    "timestamp": "2025-10-26T12:00:00Z",
    "commit": "abc123",
    "duration_ms": 45000
  },
  "summary": {
    "total_findings": 12,
    "by_severity": {
      "Critical": 2,
      "High": 4,
      "Medium": 5,
      "Low": 1
    },
    "by_category": {
      "Security": 8,
      "Architecture": 3,
      "Performance": 1
    }
  },
  "findings": [
    {
      "id": "GEM-001",
      "title": "SQL Injection vulnerability in user query",
      "severity": "Critical",
      "category": "Security",
      "cwe_id": "CWE-89",
      "owasp": "A03:2021-Injection",
      "file": "src/db/users.ts",
      "line": 42,
      "description": "Direct string concatenation in SQL query allows injection",
      "evidence": "const query = `SELECT * FROM users WHERE id = ${userId}`;",
      "recommendation": "Use parameterized queries or ORM with proper escaping",
      "references": [
        "https://owasp.org/www-community/attacks/SQL_Injection",
        "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"
      ],
      "confidence": 0.95
    }
  ],
  "security_metrics": {
    "owasp_coverage": 0.85,
    "cwe_findings": 8,
    "high_risk_files": ["src/db/users.ts", "src/auth/oauth.ts"]
  }
}
```

### Markdown Report

**Location**: `logs/gemini-reviews/{timestamp}_{commit}_gemini.md`

**Sections**:

1. **Executive Summary**
   - Commit information
   - Overall security status
   - Critical findings count
   - Recommended actions

2. **Security Findings**
   - Grouped by severity (Critical → High → Medium → Low)
   - Each finding includes:
     - CWE/OWASP mapping
     - File and line number
     - Code evidence
     - Remediation steps

3. **Architecture Analysis**
   - Design pattern observations
   - Scalability concerns
   - Security design recommendations

4. **Best Practices Compliance**
   - Framework-specific recommendations
   - Latest technology patterns
   - Industry standards alignment

5. **Action Items**
   - Prioritized list of fixes
   - Quick wins vs. long-term improvements

### VibeLogger Logs

**Location**: `logs/vibe/{YYYYMMDD}/gemini_review_{HH}.jsonl`

**Purpose**: AI-optimized structured logging for debugging and metrics

**Sample Entry**:
```json
{
  "timestamp": "2025-10-26T12:00:00Z",
  "runid": "gemini_review_1729942800_12345",
  "event": "tool_execution",
  "action": "start",
  "metadata": {
    "commit": "abc123",
    "timeout": 600
  },
  "human_note": "Starting Gemini security review for OAuth changes",
  "ai_context": {
    "tool": "Gemini",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "Security, Latest Tech, Architecture",
    "todo": "analyze_security_vulnerabilities"
  }
}
```

---

## Interpreting Results

### Severity Levels

| Severity | Meaning | Action Required |
|----------|---------|----------------|
| **Critical** | Exploitable vulnerability, immediate risk | Fix before merge |
| **High** | Significant security flaw, high exposure | Fix within 1 sprint |
| **Medium** | Potential vulnerability, moderate risk | Fix within 2-3 sprints |
| **Low** | Minor issue, best practice violation | Fix when convenient |

### OWASP Mapping

Findings are mapped to **OWASP Top 10 2021**:

- **A03 (Injection)**: Highest priority - immediate fix required
- **A01 (Broken Access Control)**: Critical for auth systems
- **A02 (Cryptographic Failures)**: Essential for data protection

### CWE (Common Weakness Enumeration)

Each finding includes CWE ID for standardized tracking:

- **CWE-89**: SQL Injection
- **CWE-79**: Cross-Site Scripting (XSS)
- **CWE-78**: OS Command Injection
- **CWE-22**: Path Traversal

### Confidence Score

- **0.9 - 1.0**: High confidence - likely true positive
- **0.7 - 0.9**: Medium confidence - verify manually
- **0.5 - 0.7**: Low confidence - possible false positive

---

## Common Use Cases

### Use Case 1: OAuth Implementation Review

```bash
# Scenario: Added OAuth2 authentication
git commit -m "feat: Add OAuth2 provider integration"

# Run Gemini review
bash scripts/gemini-review.sh --timeout 900

# Focus areas checked:
# - Token storage security
# - State parameter validation
# - Redirect URI validation
# - PKCE implementation
# - Token expiration handling
```

**Expected Findings**:
- Missing state parameter validation → High severity
- Insecure token storage → Critical severity
- Redirect URI whitelist issues → Medium severity

### Use Case 2: API Security Audit

```bash
# Scenario: New REST API endpoints
git commit -m "feat: Add user management API"

bash scripts/gemini-review.sh --timeout 600

# Focus areas:
# - Input validation
# - Rate limiting
# - Authentication checks
# - SQL injection risks
# - Mass assignment vulnerabilities
```

### Use Case 3: Infrastructure as Code (IaC) Review

```bash
# Scenario: Updated Kubernetes manifests
git commit -m "chore: Update K8s deployment configs"

bash scripts/gemini-review.sh --timeout 900

# Focus areas:
# - Pod security policies
# - Network policies
# - Secret management
# - Resource limits
# - RBAC configurations
```

### Use Case 4: Pre-Production Security Gate

```bash
# Scenario: Final security check before v2.0 release
git commit -m "chore: Prepare v2.0.0 release"

# Comprehensive review with extended timeout
bash scripts/gemini-review.sh --timeout 1800 --output pre-prod-audit/

# Manual review of all Critical/High findings
cat pre-prod-audit/latest_gemini.md | grep -A 10 "Critical\|High"
```

---

## Workflow Integration

### Integration Pattern 1: Pre-Commit Security Check

**Not recommended** - Gemini review is too slow for pre-commit hooks (10+ minutes).

**Alternative**: Use Qwen Review (faster, 2-5 minutes) for pre-commit.

### Integration Pattern 2: Pre-PR Review

```bash
# Before creating PR
git checkout feature/new-auth
git commit -am "feat: Implement new auth system"

# Run Gemini security review
bash scripts/gemini-review.sh --timeout 900

# If no Critical findings, create PR
if ! grep -q "\"severity\": \"Critical\"" logs/gemini-reviews/latest_gemini.json; then
  gh pr create --title "New Auth System" --body "Gemini review passed"
fi
```

### Integration Pattern 3: CI/CD Pipeline

**GitHub Actions** (`.github/workflows/security-review.yml`):

```yaml
name: Gemini Security Review

on:
  pull_request:
    branches: [main]
    paths:
      - 'src/auth/**'
      - 'src/api/**'
      - 'infrastructure/**'

jobs:
  security-review:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 2

      - name: Run Gemini Security Review
        run: bash scripts/gemini-review.sh --timeout 900

      - name: Check for Critical Findings
        run: |
          if grep -q "\"severity\": \"Critical\"" logs/gemini-reviews/latest_gemini.json; then
            echo "❌ Critical security findings detected"
            exit 1
          fi

      - name: Upload Review Results
        uses: actions/upload-artifact@v3
        with:
          name: gemini-review
          path: logs/gemini-reviews/latest_gemini.*
```

### Integration Pattern 4: Multi-AI Workflow

```bash
# 1. Code Quality (Qwen) - Fast baseline
bash scripts/qwen-review.sh --focus quality

# 2. Security (Gemini) - Deep security analysis
bash scripts/gemini-review.sh --timeout 900

# 3. Enterprise (Droid) - Compliance check (if needed)
bash scripts/droid-review.sh --compliance-mode

# 4. Unified report
bash scripts/multi-ai-review.sh --type all
```

---

## Best Practices

### 1. Timeout Management

**Rule of thumb**: `timeout = (lines_changed / 10) + 300`

```bash
# Small commit (~50 lines)
bash scripts/gemini-review.sh --timeout 600  # 10 min

# Medium commit (~200 lines)
bash scripts/gemini-review.sh --timeout 900  # 15 min

# Large commit (~500 lines)
bash scripts/gemini-review.sh --timeout 1200 # 20 min
```

### 2. Commit Scope

**Ideal**: Single feature or bug fix per commit

**Avoid**: Multiple unrelated changes in one commit

**Bad Example**:
```bash
git commit -am "feat: Add auth + fix typos + update deps"
# Too many concerns - review will be unfocused
```

**Good Example**:
```bash
git commit -am "feat: Add OAuth2 authentication handler"
# Single, focused change - clearer review results
```

### 3. Security-Focused Commits

Use commit message prefixes to indicate security relevance:

```bash
git commit -m "security: Fix SQL injection in user query"
git commit -m "sec: Add input validation to API endpoints"
git commit -m "vuln: Patch XSS vulnerability in search"
```

### 4. Review Before Merge

**Workflow**:
1. Feature development on feature branch
2. Gemini review on feature branch
3. Address Critical/High findings
4. Re-run Gemini review
5. Merge to main only after clean review

### 5. False Positive Handling

**Strategy**:
- Review findings with confidence < 0.7 manually
- Document false positives in commit messages
- Consider adding exclusion patterns (future feature)

---

## Troubleshooting

### Problem 1: Timeout Errors

**Symptom**:
```
⏱️  Gemini wrapper timed out after 600 seconds
❌ Review failed: timeout
```

**Solutions**:
1. **Increase timeout**:
   ```bash
   bash scripts/gemini-review.sh --timeout 1200
   ```

2. **Reduce commit scope**:
   ```bash
   # Split large commit into smaller ones
   git reset HEAD~1
   git add src/auth/
   git commit -m "feat: Add auth module"
   git add tests/
   git commit -m "test: Add auth tests"
   ```

3. **Check system resources**:
   ```bash
   # Memory usage
   free -h

   # CPU load
   top -bn1 | head -20
   ```

### Problem 2: Gemini Wrapper Not Found

**Symptom**:
```
❌ Gemini wrapper not found: /path/to/bin/gemini-wrapper.sh
```

**Solutions**:
1. **Verify installation**:
   ```bash
   ls -l bin/gemini-wrapper.sh
   ```

2. **Check permissions**:
   ```bash
   chmod +x bin/gemini-wrapper.sh
   ```

3. **Verify PATH**:
   ```bash
   export PATH="$PWD/bin:$PATH"
   ```

### Problem 3: Non-JSON Output

**Symptom**:
```
⚠️  Failed to parse JSON from Gemini, extracting text
```

**Cause**: Gemini returned Markdown instead of JSON

**Impact**: Reduced functionality, but script continues with text extraction

**Solutions**:
1. **Check prompt format**: Ensure REVIEW-PROMPT.md requests JSON output
2. **Retry with longer timeout**: May have been truncated
3. **Manual inspection**: Review raw output in VibeLogger logs

### Problem 4: Large Diff Handling

**Symptom**:
```
⚠️  Commit diff is very large (5000 lines), truncating to 3000 lines
```

**Impact**: Some changes may not be reviewed

**Solutions**:
1. **Split commit**:
   ```bash
   git reset --soft HEAD~1
   # Create multiple smaller commits
   ```

2. **Increase truncation limit** (edit script):
   ```bash
   # In gemini-review.sh, line ~150
   MAX_DIFF_LINES=5000  # Increase as needed
   ```

3. **Use incremental reviews**:
   ```bash
   # Review file by file
   for file in $(git diff --name-only HEAD~1); do
     git show HEAD:$file | bash scripts/gemini-review.sh --commit HEAD
   done
   ```

### Problem 5: Permission Denied on Output Directory

**Symptom**:
```
mkdir: cannot create directory 'logs/gemini-reviews': Permission denied
```

**Solutions**:
1. **Fix permissions**:
   ```bash
   sudo chown -R $USER:$USER logs/
   chmod -R u+w logs/
   ```

2. **Use alternative directory**:
   ```bash
   bash scripts/gemini-review.sh --output ~/my-reviews/
   ```

---

## Related Documentation

### Primary Documentation
- **Main Guide**: [FIVE_AI_REVIEW_GUIDE.md](../FIVE_AI_REVIEW_GUIDE.md) - Complete 5AI review system overview
- **CLAUDE.md**: [Project root](../../CLAUDE.md) - Integration with Multi-AI Orchestrium

### Other AI Review Guides
- [Qwen Review Guide](qwen-review-guide.md) - Code quality & implementation patterns
- [Cursor Review Guide](cursor-review-guide.md) - IDE integration & developer experience
- [Amp Review Guide](amp-review-guide.md) - Project management & documentation
- [Droid Review Guide](droid-review-guide.md) - Enterprise standards & compliance

### External Resources
- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **CWE Database**: https://cwe.mitre.org/
- **REVIEW-PROMPT.md**: Project root - Review structure and guidelines
- **VibeLogger**: https://github.com/fladdict/vibe-logger - AI-native logging

### Implementation Details
- **Script Source**: `scripts/gemini-review.sh`
- **Test Suite**: `tests/test-gemini-review.sh` (26 test cases)
- **Test Observations**: `docs/test-observations/test-gemini-review-observation.md`

---

## Appendix: Gemini vs Other AIs

### When to Choose Gemini

| Use Case | Gemini | Alternative |
|----------|--------|-------------|
| Security vulnerabilities | ✅ **Best** | Droid (compliance) |
| OWASP Top 10 detection | ✅ **Best** | N/A |
| Latest tech patterns | ✅ **Best** (Web search) | Qwen (local patterns) |
| Architecture review | ✅ **Best** | Amp (PM perspective) |
| Code quality | ⚠️ Use Qwen | **Qwen** |
| Documentation | ⚠️ Use Amp | **Amp** |
| IDE integration | ⚠️ Use Cursor | **Cursor** |
| Enterprise compliance | ⚠️ Use Droid | **Droid** |

### Gemini Strengths

- **200M token context window**: Handles extremely large codebases
- **Web search**: Access to latest CVE databases, framework updates
- **Multimodal**: Can analyze architecture diagrams (future feature)
- **Speed**: Faster than Claude for security-specific tasks

### Gemini Limitations

- **Slower than Qwen**: Not suitable for quick quality checks
- **Less code-focused**: Qwen has 93.9% HumanEval accuracy for pure code review
- **No compliance mode**: Use Droid for GDPR/SOC2/HIPAA checks
- **Limited IDE context**: Use Cursor for developer experience issues

---

**Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
**License**: MIT
