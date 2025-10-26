# Droid Review Script Guide

**Script**: `scripts/droid-review.sh`
**AI**: Droid
**Version**: 1.0.0
**Specialization**: Enterprise Standards & Compliance

---

## Table of Contents

- [Overview](#overview)
- [Core Capabilities](#core-capabilities)
- [When to Use Droid Review](#when-to-use-droid-review)
- [Installation & Prerequisites](#installation--prerequisites)
- [Basic Usage](#basic-usage)
- [Command-Line Options](#command-line-options)
- [Compliance Mode](#compliance-mode)
- [Focus Areas](#focus-areas)
- [Output Formats](#output-formats)
- [Interpreting Results](#interpreting-results)
- [Common Use Cases](#common-use-cases)
- [Workflow Integration](#workflow-integration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

---

## Overview

The Droid review script leverages Droid's **enterprise engineering expertise** to perform **comprehensive quality assurance**, **compliance verification** (GDPR, SOC2, HIPAA), and **production readiness assessment**. It is the most thorough, slowest AI in the Multi-AI system.

### Key Features

- **Compliance Verification**: GDPR, SOC2, HIPAA, PCI-DSS
- **Production Readiness**: Deployment checklist, rollback plans
- **Scalability Assessment**: Load handling, bottleneck identification
- **Reliability Analysis**: Fault tolerance, error handling
- **Enterprise Quality**: Industry-standard best practices

### Typical Review Scope

- Production releases
- Regulatory compliance requirements
- Mission-critical systems
- Enterprise customer deployments
- SLA/SLO-bound services

---

## Core Capabilities

### 1. Compliance Standards

Droid checks against major compliance frameworks:

| Framework | Focus Areas | Use Case |
|-----------|-------------|----------|
| **GDPR** | Data privacy, user consent, right to deletion | EU data processing |
| **SOC 2** | Security controls, availability, confidentiality | SaaS platforms |
| **HIPAA** | Healthcare data protection, access controls | Medical applications |
| **PCI-DSS** | Payment card data security | E-commerce |

### 2. Production Readiness Checklist

| Category | Criteria | Critical? |
|----------|----------|-----------|
| **Monitoring** | Metrics, logs, alerts | ✅ Yes |
| **Deployment** | CI/CD, rollback plan | ✅ Yes |
| **Performance** | Load testing, benchmarks | ⚠️ Recommended |
| **Security** | Auth, encryption, secrets | ✅ Yes |
| **Documentation** | Runbooks, architecture docs | ⚠️ Recommended |

### 3. Scalability Metrics

Evaluates:
- **Horizontal Scaling**: Stateless design, load balancing
- **Vertical Scaling**: Resource limits, efficiency
- **Database Scaling**: Query optimization, indexing
- **Cache Strategy**: Redis, CDN, in-memory caching

### 4. Reliability Patterns

Identifies:
- **Circuit Breakers**: Fault isolation
- **Retry Logic**: Transient failure handling
- **Graceful Degradation**: Partial service availability
- **Health Checks**: Liveness, readiness probes

---

## When to Use Droid Review

### Ideal Scenarios

1. **Production Releases**
   - Major version releases (v2.0, v3.0)
   - Customer-facing features
   - Database migrations

2. **Compliance Requirements**
   - GDPR data handling changes
   - SOC 2 audit preparation
   - HIPAA-regulated features

3. **Enterprise Deployments**
   - Fortune 500 customers
   - SLA-bound services (99.9%+)
   - Mission-critical systems

4. **Security-Critical Changes**
   - Authentication systems
   - Payment processing
   - Personal data handling

### When NOT to Use (Prefer Other AIs)

- **Fast Iteration**: Use Qwen Review (5x faster)
- **Documentation Only**: Use Amp Review
- **Code Quality**: Use Qwen Review
- **Developer Experience**: Use Cursor Review

---

## Installation & Prerequisites

### Prerequisites

1. **Droid Wrapper Script**
   ```bash
   which droid-wrapper.sh
   ```

2. **Git Repository**
3. **REVIEW-PROMPT.md** at project root

### Environment Setup

```bash
export DROID_REVIEW_TIMEOUT=900  # 15 minutes default
export OUTPUT_DIR=logs/my-droid-reviews
```

---

## Basic Usage

### Quick Start

```bash
# Review latest commit for enterprise standards
bash scripts/droid-review.sh

# Review with compliance mode (GDPR, SOC2, HIPAA)
bash scripts/droid-review.sh --compliance

# Review with extended timeout (20 minutes)
bash scripts/droid-review.sh --timeout 1200

# Review specific commit with compliance
bash scripts/droid-review.sh --commit abc123 --compliance
```

### Typical Workflow

```bash
# 1. Implement production feature
vim src/payment/stripe-integration.ts

# 2. Commit changes
git add src/payment/
git commit -m "feat: Add Stripe payment integration"

# 3. Run Droid enterprise review with compliance
bash scripts/droid-review.sh --compliance --timeout 1200

# 4. Review production readiness
cat logs/droid-reviews/latest_droid.md
```

---

## Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--timeout` | `-t` | Review timeout in seconds | 900 (15 min) |
| `--commit` | `-c` | Commit hash to review | HEAD |
| `--output` | `-o` | Output directory path | logs/droid-reviews |
| `--compliance` | N/A | Enable compliance mode | disabled |
| `--focus` | N/A | Focus area (see below) | all |
| `--help` | `-h` | Show help message | N/A |

### Compliance Mode

**`--compliance` Flag**:

Enables deep compliance analysis for:
- **GDPR**: Personal data handling, consent, right to erasure
- **SOC 2**: Security controls, access logging, availability
- **HIPAA**: Protected health information (PHI) safeguards

**Example**:
```bash
# Standard review (no compliance checks)
bash scripts/droid-review.sh --timeout 900

# Compliance-focused review (GDPR + SOC2 + HIPAA)
bash scripts/droid-review.sh --compliance --timeout 1200
```

**Output Difference**:
- Standard: `logs/droid-reviews/{timestamp}_{commit}_droid.json`
- Compliance: Adds `logs/droid-reviews/{timestamp}_{commit}_droid_compliance.json`

### Focus Areas

| Focus | Description |
|-------|-------------|
| `compliance` | GDPR/SOC2/HIPAA checks |
| `scalability` | Performance, load handling |
| `reliability` | Fault tolerance, error handling |
| `all` | All areas (default) |

**Example**:
```bash
bash scripts/droid-review.sh --focus scalability
```

---

## Output Formats

### JSON Report

**Location**: `logs/droid-reviews/{timestamp}_{commit}_droid.json`

**Structure**:
```json
{
  "metadata": {
    "ai": "Droid",
    "specialization": "Enterprise Standards",
    "timestamp": "2025-10-26T12:00:00Z",
    "commit": "abc123",
    "compliance_mode": true,
    "duration_ms": 720000
  },
  "summary": {
    "enterprise_score": 88,
    "production_readiness": 0.92,
    "compliance_score": 0.85,
    "total_findings": 15,
    "by_severity": {
      "Critical": 1,
      "High": 3,
      "Medium": 8,
      "Low": 3
    }
  },
  "findings": [
    {
      "id": "DRD-001",
      "title": "GDPR: Missing data deletion endpoint",
      "severity": "Critical",
      "category": "Compliance",
      "regulation": "GDPR Article 17 (Right to Erasure)",
      "file": "src/api/users.ts",
      "description": "User data deletion not implemented",
      "recommendation": "Add DELETE /api/users/:id endpoint with cascading delete",
      "compliance_risk": "High - GDPR violation"
    }
  ],
  "checklist": {
    "production_readiness": {
      "monitoring": true,
      "deployment": true,
      "rollback_plan": true,
      "load_testing": false,
      "documentation": true
    },
    "compliance": {
      "gdpr_compliant": false,
      "soc2_compliant": true,
      "hipaa_compliant": "N/A"
    }
  }
}
```

### Compliance Report

**Location**: `logs/droid-reviews/{timestamp}_{commit}_droid_compliance.json`

**Structure**:
```json
{
  "gdpr": {
    "compliant": false,
    "findings": [
      {
        "article": "Article 17",
        "requirement": "Right to Erasure",
        "status": "Non-Compliant",
        "recommendation": "Implement user data deletion API"
      }
    ]
  },
  "soc2": {
    "compliant": true,
    "trust_service_criteria": {
      "security": "Compliant",
      "availability": "Compliant",
      "confidentiality": "Compliant"
    }
  },
  "hipaa": {
    "applicable": false
  }
}
```

### Markdown Report

Sections:
1. **Enterprise Quality Summary**
2. **Production Readiness Checklist**
3. **Compliance Findings** (if --compliance)
4. **Scalability Assessment**
5. **Reliability Analysis**

---

## Interpreting Results

### Enterprise Score (0-100)

| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | Production-Ready | Deploy with confidence |
| 80-89 | Good | Address High findings |
| 70-79 | Fair | Fix Critical/High before deploy |
| <70 | Not Ready | Major improvements required |

### Production Readiness

- **95%+**: Excellent production readiness
- **85-94%**: Good, minor gaps
- **<85%**: Not production-ready

### Compliance Score

- **100%**: Fully compliant
- **90-99%**: Minor violations
- **<90%**: Significant compliance gaps

---

## Common Use Cases

### Use Case 1: Pre-Production Gate

```bash
# Scenario: Final review before v2.0 release
git checkout release/v2.0.0
git commit -m "chore: Prepare v2.0.0 production release"

# Comprehensive Droid review with compliance
bash scripts/droid-review.sh --compliance --timeout 1200

# Check production readiness
PROD_READY=$(jq '.summary.production_readiness' logs/droid-reviews/latest_droid.json)
if (( $(echo "$PROD_READY < 0.90" | bc -l) )); then
  echo "❌ Not production-ready: $PROD_READY"
  exit 1
fi
```

### Use Case 2: GDPR Compliance Check

```bash
# Scenario: New user data processing feature
git commit -m "feat: Add user analytics tracking"

# GDPR-focused review
bash scripts/droid-review.sh --compliance --focus compliance

# Check GDPR compliance
GDPR_COMPLIANT=$(jq '.checklist.compliance.gdpr_compliant' logs/droid-reviews/latest_droid.json)
if [ "$GDPR_COMPLIANT" = "false" ]; then
  echo "❌ GDPR violations detected"
  cat logs/droid-reviews/latest_droid_compliance.json | jq '.gdpr.findings'
  exit 1
fi
```

### Use Case 3: Scalability Assessment

```bash
# Scenario: High-traffic feature deployment
git commit -m "feat: Add public API endpoints"

# Scalability-focused review
bash scripts/droid-review.sh --focus scalability --timeout 900

# Check scalability metrics
jq '.metrics.scalability' logs/droid-reviews/latest_droid.json
```

---

## Workflow Integration

### Integration Pattern 1: Production Deployment Gate

```bash
# Before deploying to production
git checkout main
git pull origin main

# Run comprehensive Droid review
bash scripts/droid-review.sh --compliance --timeout 1200

# Enforce production standards
ENT_SCORE=$(jq '.summary.enterprise_score' logs/droid-reviews/latest_droid.json)
CRITICAL=$(jq '.summary.by_severity.Critical' logs/droid-reviews/latest_droid.json)

if [ "$ENT_SCORE" -lt 85 ] || [ "$CRITICAL" -gt 0 ]; then
  echo "❌ Production deployment blocked"
  echo "Enterprise Score: $ENT_SCORE (minimum: 85)"
  echo "Critical Findings: $CRITICAL (maximum: 0)"
  exit 1
fi

# Deploy if passed
./deploy-production.sh
```

### Integration Pattern 2: Compliance CI/CD

```yaml
# .github/workflows/compliance-check.yml
name: Droid Compliance Check

on:
  push:
    branches:
      - main
      - release/*

jobs:
  compliance-review:
    runs-on: ubuntu-latest
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v3
      - name: Run Droid Compliance Review
        run: bash scripts/droid-review.sh --compliance --timeout 1200

      - name: Check Compliance Status
        run: |
          GDPR=$(jq '.checklist.compliance.gdpr_compliant' logs/droid-reviews/latest_droid.json)
          SOC2=$(jq '.checklist.compliance.soc2_compliant' logs/droid-reviews/latest_droid.json)

          if [ "$GDPR" = "false" ] || [ "$SOC2" = "false" ]; then
            echo "❌ Compliance violations detected"
            exit 1
          fi

      - name: Upload Compliance Report
        uses: actions/upload-artifact@v3
        with:
          name: compliance-report
          path: logs/droid-reviews/*_compliance.json
```

---

## Best Practices

### 1. Timeout Management

Droid is the **slowest AI** (3x slower than Qwen):

```bash
# Small changes (<100 lines)
bash scripts/droid-review.sh --timeout 900  # 15 min

# Medium changes (100-500 lines)
bash scripts/droid-review.sh --timeout 1200 # 20 min

# Large changes (500+ lines)
bash scripts/droid-review.sh --timeout 1800 # 30 min

# Compliance mode (add +5 minutes)
bash scripts/droid-review.sh --compliance --timeout 1500 # 25 min
```

### 2. Use Strategically

**Don't use for**:
- Every commit (too slow)
- Development branches
- Quick iterations

**Do use for**:
- Production releases
- Compliance audits
- Enterprise deployments

### 3. Compliance Mode Triggers

Enable `--compliance` when:
- Handling personal data (GDPR)
- SaaS platform audit (SOC 2)
- Healthcare application (HIPAA)
- Payment processing (PCI-DSS)

### 4. Production Readiness Checklist

Before deploying, ensure:
```bash
# Run Droid review
bash scripts/droid-review.sh --compliance --timeout 1200

# Verify checklist
jq '.checklist.production_readiness' logs/droid-reviews/latest_droid.json

# Expected output:
# {
#   "monitoring": true,
#   "deployment": true,
#   "rollback_plan": true,
#   "load_testing": true,
#   "documentation": true
# }
```

---

## Troubleshooting

### Problem 1: Timeout on Large Commits

**Symptom**:
```
⏱️  Droid wrapper timed out after 900 seconds
```

**Solutions**:
1. **Increase timeout**:
   ```bash
   bash scripts/droid-review.sh --timeout 1800  # 30 min
   ```

2. **Split commit**:
   ```bash
   git reset --soft HEAD~1
   # Create smaller, focused commits
   ```

3. **Use faster AI first**:
   ```bash
   # Qwen for quick quality check (5 min)
   bash scripts/qwen-review.sh --timeout 300

   # Droid for final enterprise review (15 min)
   bash scripts/droid-review.sh --timeout 900
   ```

### Problem 2: False Positive Compliance Violations

**Symptom**: GDPR violation reported, but implementation is correct

**Cause**: Non-standard implementation pattern

**Solutions**:
1. **Review finding details**:
   ```bash
   jq '.findings[] | select(.regulation | contains("GDPR"))' logs/droid-reviews/latest_droid.json
   ```

2. **Add compliance documentation**:
   ```typescript
   // GDPR Article 17 Compliance: User deletion implemented via soft-delete pattern
   async function deleteUser(userId: string) {
     await markUserDeleted(userId);
     await scheduleDataDeletion(userId, 30days);
   }
   ```

### Problem 3: Production Readiness False Negatives

**Symptom**: Monitoring marked as `false`, but logging exists

**Cause**: Non-standard monitoring setup (e.g., custom Prometheus)

**Solution**: Ensure standard patterns:
- Logging: Winston, Bunyan, or similar
- Metrics: Prometheus, Datadog, CloudWatch
- Alerts: PagerDuty, OpsGenie, Slack

---

## Related Documentation

### Primary Documentation
- **Main Guide**: [FIVE_AI_REVIEW_GUIDE.md](../FIVE_AI_REVIEW_GUIDE.md)
- **CLAUDE.md**: [Project root](../../CLAUDE.md)

### Other AI Review Guides
- [Gemini Review Guide](gemini-review-guide.md) - Security & architecture
- [Qwen Review Guide](qwen-review-guide.md) - Code quality & patterns
- [Cursor Review Guide](cursor-review-guide.md) - IDE integration & DX
- [Amp Review Guide](amp-review-guide.md) - Project management & docs

### Compliance Resources
- **GDPR**: https://gdpr.eu/
- **SOC 2**: https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/sorhome.html
- **HIPAA**: https://www.hhs.gov/hipaa/index.html

### Implementation Details
- **Script Source**: `scripts/droid-review.sh`
- **Test Suite**: `tests/test-droid-review.sh` (26 test cases)

---

## Appendix: Droid vs Other AIs

| Use Case | Droid | Alternative |
|----------|-------|-------------|
| Enterprise standards | ✅ **Best** | N/A |
| Compliance (GDPR/SOC2) | ✅ **Best** | N/A |
| Production readiness | ✅ **Best** | N/A |
| Scalability | ✅ **Best** | Gemini (architecture) |
| Speed (<5 min) | ❌ Use Qwen | **Qwen** (5x faster) |
| Code quality | ⚠️ Use Qwen | **Qwen** (93.9% HumanEval) |
| Security (OWASP) | ⚠️ Use Gemini | **Gemini** |

### Droid Strengths

- **Comprehensive**: Most thorough review in Multi-AI system
- **Compliance**: Only AI with GDPR/SOC2/HIPAA expertise
- **Enterprise**: Understands Fortune 500 requirements
- **Production**: Best production readiness assessment

### Droid Limitations

- **Slowest**: 3x slower than Qwen, 2x slower than Gemini
- **Overkill for dev**: Not suitable for rapid iteration
- **Cost**: Higher resource consumption

---

**Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
**License**: MIT
