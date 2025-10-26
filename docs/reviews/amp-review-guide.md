# Amp Review Script Guide

**Script**: `scripts/amp-review.sh`
**AI**: Amp
**Version**: 1.0.0
**Specialization**: Project Management & Documentation

---

## Table of Contents

- [Overview](#overview)
- [Core Capabilities](#core-capabilities)
- [When to Use Amp Review](#when-to-use-amp-review)
- [Installation & Prerequisites](#installation--prerequisites)
- [Basic Usage](#basic-usage)
- [Command-Line Options](#command-line-options)
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

The Amp review script leverages Amp's **project management perspective** to evaluate **documentation quality**, **stakeholder communication clarity**, **sprint alignment**, and **risk assessment**. It bridges the gap between technical implementation and project success.

### Key Features

- **Documentation Coverage Analysis**: README, API docs, inline comments
- **Stakeholder Communication**: Clear change descriptions, user impact
- **Sprint Planning Alignment**: Story/task tracking, scope verification
- **Risk Assessment**: Impact analysis, rollback planning
- **Technical Debt Tracking**: Quantified debt with prioritization

### Typical Review Scope

- README and documentation updates
- API documentation completeness
- Commit message clarity
- Feature scope alignment
- Change impact on stakeholders

---

## Core Capabilities

### 1. Documentation Quality Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| **Doc Coverage** | % of public APIs documented | 90%+ |
| **Completeness Score** | Required sections present | 100% |
| **Clarity Score** | Readability index | 80+ |
| **Example Quality** | Code examples present/working | 100% |

### 2. Stakeholder Communication

Evaluates:
- **User Impact**: Who is affected by changes?
- **Migration Path**: Clear upgrade/transition steps
- **Breaking Changes**: Explicitly documented
- **Rollback Plan**: Reversion strategy documented

### 3. Sprint Planning Alignment

Checks:
- Feature matches sprint goals
- Story/task references in commits
- Scope creep detection
- Acceptance criteria coverage

### 4. Risk Assessment

Identifies:
- **High-Risk Changes**: Database migrations, API changes
- **Dependency Impact**: Upstream/downstream effects
- **Rollback Complexity**: How easy to revert?
- **Testing Coverage**: Adequate tests for risk level?

---

## When to Use Amp Review

### Ideal Scenarios

1. **Documentation Changes**
   - README updates
   - API documentation
   - User guides, tutorials

2. **Feature Releases**
   - Sprint milestone reviews
   - Release notes validation
   - Stakeholder communication

3. **API Design Reviews**
   - Public API additions
   - Breaking change analysis
   - Migration guide validation

4. **Project Planning**
   - Feature scope verification
   - Risk assessment
   - Technical debt prioritization

### When NOT to Use (Prefer Other AIs)

- **Code Quality**: Use Qwen Review for implementation patterns
- **Security**: Use Gemini Review for vulnerability detection
- **Developer Experience**: Use Cursor Review for IDE integration
- **Compliance**: Use Droid Review for enterprise standards

---

## Installation & Prerequisites

### Prerequisites

1. **Amp Wrapper Script**
   ```bash
   which amp-wrapper.sh
   ```

2. **Git Repository**
3. **REVIEW-PROMPT.md** at project root

### Environment Setup

```bash
export AMP_REVIEW_TIMEOUT=600  # 10 minutes default
export OUTPUT_DIR=logs/my-amp-reviews
```

---

## Basic Usage

### Quick Start

```bash
# Review latest commit for documentation/PM issues
bash scripts/amp-review.sh

# Review with extended timeout
bash scripts/amp-review.sh --timeout 900

# Review specific commit
bash scripts/amp-review.sh --commit abc123
```

### Typical Workflow

```bash
# 1. Update documentation
vim README.md
vim docs/api-guide.md

# 2. Commit changes
git add README.md docs/
git commit -m "docs: Update API guide with new endpoints"

# 3. Run Amp documentation review
bash scripts/amp-review.sh --timeout 600

# 4. Review documentation quality
cat logs/amp-reviews/latest_amp.md
```

---

## Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--timeout` | `-t` | Review timeout in seconds | 600 (10 min) |
| `--commit` | `-c` | Commit hash to review | HEAD |
| `--output` | `-o` | Output directory path | logs/amp-reviews |
| `--focus` | N/A | Focus area (see below) | all |
| `--help` | `-h` | Show help message | N/A |

### Focus Areas

| Focus | Description |
|-------|-------------|
| `docs` | Documentation coverage & quality |
| `communication` | Stakeholder communication clarity |
| `planning` | Sprint alignment & scope |
| `all` | All areas (default) |

**Example**:
```bash
bash scripts/amp-review.sh --focus docs
```

---

## Output Formats

### JSON Report

**Location**: `logs/amp-reviews/{timestamp}_{commit}_amp.json`

**Structure**:
```json
{
  "metadata": {
    "ai": "Amp",
    "specialization": "Project Management & Documentation",
    "timestamp": "2025-10-26T12:00:00Z",
    "commit": "abc123"
  },
  "summary": {
    "pm_score": 85,
    "documentation_coverage": 0.88,
    "communication_clarity": 0.90,
    "sprint_alignment": 0.92,
    "total_findings": 8
  },
  "findings": [
    {
      "id": "AMP-001",
      "title": "Missing migration guide for API v2",
      "severity": "High",
      "category": "Documentation",
      "file": "docs/api-guide.md",
      "description": "Breaking API changes lack migration instructions",
      "stakeholder_impact": "All API consumers",
      "recommendation": "Add migration section with code examples"
    }
  ],
  "metrics": {
    "doc_coverage_pct": 88,
    "clarity_score": 82,
    "risk_level": "Medium"
  }
}
```

### Markdown Report

Sections:
1. **Project Management Summary**
2. **Documentation Findings**
3. **Stakeholder Impact Assessment**
4. **Sprint Alignment Check**
5. **Risk Analysis**

---

## Interpreting Results

### PM Score (0-100)

| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | Excellent | Maintain standards |
| 80-89 | Good | Minor doc improvements |
| 70-79 | Fair | Address communication gaps |
| <70 | Poor | Major documentation needed |

### Documentation Coverage

- **90%+**: Excellent coverage
- **75-89%**: Good, some gaps
- **<75%**: Insufficient documentation

### Communication Clarity

- **85%+**: Clear stakeholder impact
- **70-84%**: Adequate communication
- **<70%**: Unclear impact

---

## Common Use Cases

### Use Case 1: API Documentation Review

```bash
# Scenario: New API endpoints added
git commit -m "feat: Add user management API endpoints"

bash scripts/amp-review.sh --focus docs

# Check documentation coverage
jq '.metrics.doc_coverage_pct' logs/amp-reviews/latest_amp.json
```

### Use Case 2: Release Notes Validation

```bash
# Scenario: Preparing v2.0.0 release
git commit -m "chore: Prepare v2.0.0 release notes"

bash scripts/amp-review.sh --focus communication

# Check stakeholder communication
jq '.summary.communication_clarity' logs/amp-reviews/latest_amp.json
```

### Use Case 3: Sprint Milestone Review

```bash
# Scenario: Sprint completion check
git log --since="2 weeks ago" --pretty=format:"%s" > sprint-commits.txt

bash scripts/amp-review.sh --focus planning

# Verify sprint alignment
jq '.summary.sprint_alignment' logs/amp-reviews/latest_amp.json
```

---

## Workflow Integration

### Integration Pattern 1: Documentation PR Gate

```bash
# Before creating PR for doc changes
git checkout feature/new-docs
git commit -am "docs: Add GraphQL API guide"

bash scripts/amp-review.sh --focus docs

# Check documentation quality
DOC_COVERAGE=$(jq '.metrics.doc_coverage_pct' logs/amp-reviews/latest_amp.json)
if [ "$DOC_COVERAGE" -lt 85 ]; then
  echo "❌ Documentation coverage too low: $DOC_COVERAGE%"
  exit 1
fi

gh pr create --title "Add GraphQL API Guide"
```

### Integration Pattern 2: Release Checklist

```yaml
# .github/workflows/release-checklist.yml
name: Amp Release Checklist

on:
  push:
    tags:
      - 'v*'

jobs:
  release-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Amp Review
        run: bash scripts/amp-review.sh --focus all

      - name: Check Release Readiness
        run: |
          PM_SCORE=$(jq '.summary.pm_score' logs/amp-reviews/latest_amp.json)
          if [ "$PM_SCORE" -lt 85 ]; then
            echo "❌ PM score below release threshold: $PM_SCORE"
            exit 1
          fi
```

---

## Best Practices

### 1. Documentation Coverage Targets

| Component | Target Coverage |
|-----------|----------------|
| Public APIs | 95%+ |
| User Guides | 90%+ |
| Internal Docs | 75%+ |

### 2. Commit Message Clarity

Amp evaluates commit messages for:
```bash
# Good - clear impact
git commit -m "feat: Add GraphQL API (BREAKING: REST v1 deprecated)"

# Bad - unclear
git commit -m "update api"
```

### 3. Stakeholder Communication

Include in documentation:
- **Who is affected**: Users, developers, admins
- **What changed**: Feature additions, breaking changes
- **How to migrate**: Step-by-step instructions
- **When effective**: Release timeline

---

## Troubleshooting

### Problem 1: Low PM Score Despite Good Docs

**Symptom**: PM score 65, but documentation exists

**Possible Causes**:
1. Missing API examples
2. Unclear stakeholder impact
3. No migration guide for breaking changes

**Solutions**:
```bash
# Check specific findings
jq '.findings[] | select(.severity=="High")' logs/amp-reviews/latest_amp.json
```

### Problem 2: False Positive Documentation Gaps

**Symptom**: Amp reports missing docs, but they exist

**Cause**: Non-standard documentation locations

**Solution**: Ensure docs are in standard locations:
- `README.md`
- `docs/` directory
- Inline JSDoc/docstrings

---

## Related Documentation

### Primary Documentation
- **Main Guide**: [FIVE_AI_REVIEW_GUIDE.md](../FIVE_AI_REVIEW_GUIDE.md)
- **CLAUDE.md**: [Project root](../../CLAUDE.md)

### Other AI Review Guides
- [Gemini Review Guide](gemini-review-guide.md) - Security & architecture
- [Qwen Review Guide](qwen-review-guide.md) - Code quality & patterns
- [Cursor Review Guide](cursor-review-guide.md) - IDE integration & DX
- [Droid Review Guide](droid-review-guide.md) - Enterprise standards

### Implementation Details
- **Script Source**: `scripts/amp-review.sh`
- **Test Suite**: `tests/test-amp-review.sh` (26 test cases)

---

## Appendix: Amp vs Other AIs

| Use Case | Amp | Alternative |
|----------|-----|-------------|
| Documentation | ✅ **Best** | N/A |
| Stakeholder comm. | ✅ **Best** | N/A |
| Sprint alignment | ✅ **Best** | N/A |
| Risk assessment | ✅ **Best** | Gemini (security risk) |
| Code quality | ⚠️ Use Qwen | **Qwen** |
| Security | ⚠️ Use Gemini | **Gemini** |
| Developer DX | ⚠️ Use Cursor | **Cursor** |

---

**Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
**License**: MIT
