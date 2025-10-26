# Qwen Review Script Guide

**Script**: `scripts/qwen-review.sh`
**AI**: Qwen3-Coder
**Version**: 1.0.0
**Specialization**: Code Quality & Implementation Patterns

---

## Table of Contents

- [Overview](#overview)
- [Core Capabilities](#core-capabilities)
- [When to Use Qwen Review](#when-to-use-qwen-review)
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

The Qwen review script leverages **Qwen3-Coder's 93.9% HumanEval accuracy** to perform deep **code quality analysis**, **design pattern detection**, and **performance optimization**. It is the **fastest and most code-focused** AI in the Multi-AI system.

### Key Features

- **93.9% HumanEval Accuracy**: Industry-leading code understanding
- **358 Programming Languages**: Comprehensive language support
- **Fast Execution**: 2-5 minute typical review time (5x faster than Gemini)
- **Pattern Recognition**: Detects anti-patterns and suggests best practices
- **Technical Debt Estimation**: Quantifies maintainability metrics
- **Performance Analysis**: Identifies algorithmic bottlenecks

### Typical Review Scope

- Implementation quality & code cleanliness
- Design patterns & architectural patterns
- Algorithm efficiency & data structures
- Code complexity & maintainability
- Best practices for specific frameworks
- Refactoring opportunities

---

## Core Capabilities

### 1. Code Quality Metrics

Qwen calculates industry-standard quality metrics:

| Metric | Description | Target Range |
|--------|-------------|--------------|
| **Maintainability Index** | Overall code health (0-100) | 80-100 (Good) |
| **Cyclomatic Complexity** | Decision path count | 1-10 (Low complexity) |
| **Halstead Metrics** | Program difficulty & volume | Varies by language |
| **Code Duplication** | % of duplicated code blocks | <5% |
| **Comment Ratio** | Comments per 100 LOC | 15-30% |

### 2. Design Pattern Detection

Automatically identifies:

**Creational Patterns**:
- Singleton, Factory, Builder, Prototype, Abstract Factory

**Structural Patterns**:
- Adapter, Decorator, Facade, Proxy, Composite

**Behavioral Patterns**:
- Observer, Strategy, Command, State, Template Method

**Anti-Patterns**:
- God Object, Spaghetti Code, Lava Flow, Golden Hammer

### 3. Performance Optimization

Identifies common performance issues:

- **Algorithm Complexity**: O(n²) → O(n log n) opportunities
- **Memory Leaks**: Unreleased resources, circular references
- **I/O Bottlenecks**: Unnecessary file/network operations
- **Inefficient Data Structures**: Array vs. HashMap opportunities
- **Premature Optimization**: Over-engineered solutions

### 4. Technical Debt Analysis

Quantifies technical debt:

```
Technical Debt = (Actual Complexity - Ideal Complexity) × Cost Factor
```

**Cost Factors**:
- **Trivial**: 1-2 hours to fix
- **Low**: 2-8 hours (1 day)
- **Medium**: 8-40 hours (1 week)
- **High**: 40+ hours (multiple weeks)

---

## When to Use Qwen Review

### Ideal Scenarios

1. **New Feature Implementation**
   - Core business logic
   - Algorithm implementations
   - Data processing pipelines
   - Utility functions

2. **Refactoring Validation**
   - Code cleanup verification
   - Pattern migration validation
   - Performance improvement confirmation

3. **Pre-Commit Quality Check**
   - Fast enough for CI/CD (2-5 minutes)
   - Catches basic quality issues
   - Validates coding standards

4. **Code Review Assistance**
   - Automated first-pass review
   - Pattern violation detection
   - Complexity warnings

### When NOT to Use (Prefer Other AIs)

- **Security Focus**: Use Gemini Review for OWASP/CWE detection
- **Documentation**: Use Amp Review for doc quality
- **Developer Experience**: Use Cursor Review for IDE friendliness
- **Compliance**: Use Droid Review for enterprise standards

---

## Installation & Prerequisites

### Prerequisites

1. **Qwen Wrapper Script**
   ```bash
   # Check availability
   which qwen-wrapper.sh
   # Expected: /path/to/multi-ai-orchestrium/bin/qwen-wrapper.sh
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
export QWEN_REVIEW_TIMEOUT=300  # 5 minutes for fast checks

# Optional: Set custom output directory
export OUTPUT_DIR=logs/my-qwen-reviews
```

---

## Basic Usage

### Quick Start

```bash
# Review latest commit (fast, 2-5 minutes)
bash scripts/qwen-review.sh

# Review with custom timeout
bash scripts/qwen-review.sh --timeout 600

# Review specific commit
bash scripts/qwen-review.sh --commit abc123

# Custom output directory
bash scripts/qwen-review.sh --output code-quality-reports/
```

### Typical Workflow

```bash
# 1. Implement new feature
vim src/services/user-service.ts

# 2. Commit changes
git add src/services/user-service.ts
git commit -m "feat: Add user profile update service"

# 3. Run Qwen quality review
bash scripts/qwen-review.sh --timeout 300

# 4. Review output
cat logs/qwen-reviews/latest_qwen.md
```

---

## Command-Line Options

### Options Summary

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--timeout` | `-t` | Review timeout in seconds | 600 (10 min) |
| `--commit` | `-c` | Commit hash to review | HEAD |
| `--output` | `-o` | Output directory path | logs/qwen-reviews |
| `--focus` | N/A | Focus area (see below) | all |
| `--help` | `-h` | Show help message | N/A |

### Detailed Options

#### `--timeout SECONDS` (`-t`)

**Qwen-specific timeout guidelines**:

- **Tiny commits** (<50 lines): 120s (2 min) - **Fast mode**
- **Small commits** (50-150 lines): 300s (5 min) - **Recommended**
- **Medium commits** (150-500 lines): 600s (10 min) - **Default**
- **Large commits** (500+ lines): 900s (15 min)

**Example**:
```bash
# Fast quality check before commit
bash scripts/qwen-review.sh --timeout 120
```

#### `--focus AREA`

**Qwen-specific focus areas**:

| Focus Area | Description | Use Case |
|-----------|-------------|----------|
| `patterns` | Design pattern analysis | Refactoring, architecture review |
| `quality` | Code quality metrics | Pre-commit checks |
| `performance` | Performance optimization | Algorithm review |
| `all` | All areas (default) | Comprehensive review |

**Example**:
```bash
# Focus on design patterns
bash scripts/qwen-review.sh --focus patterns

# Focus on performance
bash scripts/qwen-review.sh --focus performance
```

---

## Focus Areas

### Focus: Patterns

**What it checks**:
- Design pattern usage & appropriateness
- Anti-pattern detection
- Architectural pattern alignment
- SOLID principles adherence

**Example Output**:
```json
{
  "findings": [
    {
      "title": "Singleton pattern detected in UserService",
      "category": "Pattern",
      "severity": "Medium",
      "description": "Singleton may cause testing difficulties",
      "recommendation": "Consider dependency injection instead",
      "pattern_type": "Creational/Singleton",
      "alternatives": ["Dependency Injection", "Service Locator"]
    }
  ]
}
```

**Use when**:
- Refactoring legacy code
- Reviewing architecture changes
- Validating design decisions

### Focus: Quality

**What it checks**:
- Code complexity (cyclomatic, cognitive)
- Maintainability index
- Code duplication
- Naming conventions
- Comment quality

**Example Output**:
```json
{
  "quality_metrics": {
    "maintainability_index": 65,
    "cyclomatic_complexity": 15,
    "code_duplication_pct": 8.5,
    "comment_ratio": 12
  },
  "findings": [
    {
      "title": "High cyclomatic complexity in processOrder()",
      "severity": "High",
      "complexity": 15,
      "threshold": 10,
      "recommendation": "Split into smaller functions"
    }
  ]
}
```

**Use when**:
- Pre-commit quality gates
- Code review automation
- Technical debt tracking

### Focus: Performance

**What it checks**:
- Algorithm complexity analysis
- Inefficient data structure usage
- Memory allocation patterns
- I/O optimization opportunities
- Database query efficiency

**Example Output**:
```json
{
  "findings": [
    {
      "title": "O(n²) nested loop detected in findDuplicates()",
      "severity": "High",
      "category": "Performance",
      "current_complexity": "O(n²)",
      "suggested_complexity": "O(n)",
      "recommendation": "Use HashSet for O(n) lookup instead of nested array iteration",
      "estimated_speedup": "100x for n=1000"
    }
  ]
}
```

**Use when**:
- Performance-critical code
- Algorithm optimization
- Scalability planning

---

## Output Formats

### JSON Report

**Location**: `logs/qwen-reviews/{timestamp}_{commit}_qwen.json`

**Structure**:
```json
{
  "metadata": {
    "ai": "Qwen",
    "version": "3-Coder",
    "specialization": "Code Quality & Patterns",
    "humaneval_accuracy": 0.939,
    "timestamp": "2025-10-26T12:00:00Z",
    "commit": "abc123",
    "duration_ms": 180000,
    "focus_area": "all"
  },
  "summary": {
    "overall_quality_score": 82,
    "total_findings": 15,
    "by_severity": {
      "Critical": 0,
      "High": 3,
      "Medium": 8,
      "Low": 4
    },
    "by_category": {
      "Quality": 7,
      "Performance": 4,
      "Patterns": 4
    }
  },
  "metrics": {
    "maintainability_index": 78,
    "average_cyclomatic_complexity": 6.5,
    "code_duplication_pct": 4.2,
    "comment_ratio": 18.5,
    "technical_debt_hours": 24
  },
  "findings": [
    {
      "id": "QWN-001",
      "title": "High cyclomatic complexity in authenticateUser()",
      "severity": "High",
      "category": "Quality",
      "file": "src/auth/auth-service.ts",
      "line": 45,
      "function": "authenticateUser",
      "complexity": 15,
      "threshold": 10,
      "description": "Function has 15 decision points, exceeding recommended limit of 10",
      "evidence": "Multiple nested if-else and switch statements",
      "recommendation": "Extract validation logic into separate functions",
      "refactoring_example": "createValidationChain(), validateCredentials(), checkPermissions()",
      "estimated_effort_hours": 4,
      "confidence": 0.92
    }
  ],
  "patterns": {
    "detected": ["Factory", "Observer", "Singleton"],
    "anti_patterns": ["God Object in UserController"],
    "suggestions": ["Consider Strategy pattern for validation"]
  }
}
```

### Markdown Report

**Location**: `logs/qwen-reviews/{timestamp}_{commit}_qwen.md`

**Sections**:

1. **Quality Summary**
   - Overall quality score (0-100)
   - Maintainability index
   - Technical debt estimation

2. **Findings by Severity**
   - Critical/High/Medium/Low grouping
   - File, line number, function name
   - Complexity metrics
   - Refactoring suggestions

3. **Design Pattern Analysis**
   - Detected patterns
   - Anti-patterns found
   - Pattern improvement suggestions

4. **Performance Opportunities**
   - Algorithm complexity improvements
   - Data structure optimizations
   - Estimated performance gains

5. **Code Metrics Dashboard**
   - Complexity distribution
   - Duplication hotspots
   - Comment coverage

---

## Interpreting Results

### Quality Score (0-100)

| Score Range | Rating | Action Required |
|------------|--------|----------------|
| **90-100** | Excellent | Maintain current standards |
| **80-89** | Good | Minor improvements |
| **70-79** | Fair | Address High findings |
| **60-69** | Poor | Refactoring needed |
| **<60** | Critical | Major refactoring required |

### Maintainability Index

**Formula**: `171 - 5.2 × ln(Halstead Volume) - 0.23 × Cyclomatic Complexity - 16.2 × ln(LOC)`

| MI Range | Maintainability | Recommendation |
|----------|-----------------|----------------|
| **80-100** | High | Excellent code quality |
| **60-79** | Moderate | Some refactoring needed |
| **40-59** | Low | Significant refactoring required |
| **<40** | Critical | Consider rewrite |

### Cyclomatic Complexity

**Per Function**:
- **1-5**: Simple, easy to test
- **6-10**: Moderate, acceptable
- **11-20**: Complex, needs simplification
- **>20**: Very complex, refactor immediately

### Technical Debt Estimation

Qwen estimates technical debt in **developer hours**:

```
Low Debt (1-8 hours):     Quick fixes, rename variables
Medium Debt (8-40 hours): Function extraction, pattern refactoring
High Debt (40+ hours):    Module redesign, architecture change
```

---

## Common Use Cases

### Use Case 1: Pre-Commit Quality Gate

```bash
# Fast quality check before committing
git add src/utils/string-helper.ts
git commit -m "feat: Add string manipulation utilities"

# Quick Qwen review (2 minutes)
bash scripts/qwen-review.sh --timeout 120 --focus quality

# Check quality score
SCORE=$(jq '.summary.overall_quality_score' logs/qwen-reviews/latest_qwen.json)
if [ "$SCORE" -lt 75 ]; then
  echo "❌ Quality score too low: $SCORE"
  git reset HEAD~1
fi
```

### Use Case 2: Refactoring Validation

```bash
# Before refactoring - baseline metrics
bash scripts/qwen-review.sh --focus quality --output pre-refactor/

# Perform refactoring
# ... code changes ...

# After refactoring - comparison
bash scripts/qwen-review.sh --focus quality --output post-refactor/

# Compare maintainability index
PRE_MI=$(jq '.metrics.maintainability_index' pre-refactor/latest_qwen.json)
POST_MI=$(jq '.metrics.maintainability_index' post-refactor/latest_qwen.json)

echo "Maintainability: $PRE_MI → $POST_MI (Δ $((POST_MI - PRE_MI)))"
```

### Use Case 3: Design Pattern Review

```bash
# Scenario: Implementing Factory pattern
git commit -m "refactor: Introduce Factory pattern for user creation"

# Review pattern implementation
bash scripts/qwen-review.sh --focus patterns --timeout 300

# Check pattern detection
jq '.patterns.detected[]' logs/qwen-reviews/latest_qwen.json
# Expected output: "Factory"
```

### Use Case 4: Performance Optimization

```bash
# Scenario: Optimizing search algorithm
git commit -m "perf: Optimize user search with binary search"

# Performance-focused review
bash scripts/qwen-review.sh --focus performance --timeout 600

# Check complexity improvements
jq '.findings[] | select(.category=="Performance")' logs/qwen-reviews/latest_qwen.json
```

---

## Workflow Integration

### Integration Pattern 1: Pre-Commit Hook

**Fast enough for pre-commit** (2-5 minutes):

```bash
# .git/hooks/pre-commit
#!/bin/bash
set -e

echo "Running Qwen quality check..."
bash scripts/qwen-review.sh --timeout 120 --focus quality

# Block commit if quality score < 70
SCORE=$(jq '.summary.overall_quality_score' logs/qwen-reviews/latest_qwen.json)
if [ "$SCORE" -lt 70 ]; then
  echo "❌ Quality score too low: $SCORE (minimum: 70)"
  exit 1
fi

echo "✅ Quality check passed: $SCORE"
```

### Integration Pattern 2: CI/CD Pipeline

**GitHub Actions** (`.github/workflows/code-quality.yml`):

```yaml
name: Qwen Code Quality Review

on:
  pull_request:
    branches: [main, develop]

jobs:
  quality-review:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 2

      - name: Run Qwen Quality Review
        run: bash scripts/qwen-review.sh --timeout 600 --focus quality

      - name: Quality Gate Check
        run: |
          SCORE=$(jq '.summary.overall_quality_score' logs/qwen-reviews/latest_qwen.json)
          HIGH_FINDINGS=$(jq '.summary.by_severity.High' logs/qwen-reviews/latest_qwen.json)

          echo "Quality Score: $SCORE"
          echo "High Severity Findings: $HIGH_FINDINGS"

          if [ "$SCORE" -lt 75 ] || [ "$HIGH_FINDINGS" -gt 5 ]; then
            echo "❌ Quality standards not met"
            exit 1
          fi

      - name: Upload Quality Report
        uses: actions/upload-artifact@v3
        with:
          name: qwen-quality-report
          path: logs/qwen-reviews/latest_qwen.*
```

### Integration Pattern 3: Multi-AI Sequential Review

```bash
# 1. Fast quality baseline (Qwen) - 5 minutes
bash scripts/qwen-review.sh --timeout 300 --focus quality

# 2. If quality OK, run security review (Gemini) - 10 minutes
QUALITY_SCORE=$(jq '.summary.overall_quality_score' logs/qwen-reviews/latest_qwen.json)
if [ "$QUALITY_SCORE" -ge 75 ]; then
  bash scripts/gemini-review.sh --timeout 600
fi

# 3. If both OK, run enterprise review (Droid) - 15 minutes
CRITICAL_COUNT=$(jq '.summary.by_severity.Critical' logs/gemini-reviews/latest_gemini.json)
if [ "$CRITICAL_COUNT" -eq 0 ]; then
  bash scripts/droid-review.sh --timeout 900
fi
```

### Integration Pattern 4: TDD Cycle Integration

```bash
# TDD Red-Green-Refactor with Qwen
# RED: Write failing test
npm test  # Test fails

# GREEN: Implement minimal code
vim src/calculator.ts
npm test  # Test passes

# REFACTOR: Use Qwen to validate refactoring
bash scripts/qwen-review.sh --timeout 120 --focus quality
# Check complexity didn't increase
```

---

## Best Practices

### 1. Timeout Optimization

**Qwen is 5x faster than Gemini** - adjust timeouts accordingly:

```bash
# Rule of thumb: timeout = (lines_changed / 50) + 120

# Small commit (50 lines)
bash scripts/qwen-review.sh --timeout 180  # 3 min

# Medium commit (200 lines)
bash scripts/qwen-review.sh --timeout 300  # 5 min

# Large commit (500 lines)
bash scripts/qwen-review.sh --timeout 600  # 10 min
```

### 2. Focus Area Selection

**Choose focus based on change type**:

```bash
# New feature implementation → quality
bash scripts/qwen-review.sh --focus quality

# Refactoring → patterns
bash scripts/qwen-review.sh --focus patterns

# Performance fix → performance
bash scripts/qwen-review.sh --focus performance
```

### 3. Quality Score Targets

**Set context-appropriate thresholds**:

| Code Type | Minimum Score | Target Score |
|-----------|--------------|--------------|
| Production APIs | 80 | 90+ |
| Core business logic | 75 | 85+ |
| Utility functions | 70 | 80+ |
| Test code | 65 | 75+ |
| Prototypes | 60 | N/A |

### 4. Incremental Improvement

**Track quality trends**:

```bash
# Store baseline
bash scripts/qwen-review.sh --output baseline/
BASELINE_SCORE=$(jq '.summary.overall_quality_score' baseline/latest_qwen.json)

# After changes
bash scripts/qwen-review.sh
CURRENT_SCORE=$(jq '.summary.overall_quality_score' logs/qwen-reviews/latest_qwen.json)

# Require improvement
if [ "$CURRENT_SCORE" -lt "$BASELINE_SCORE" ]; then
  echo "❌ Quality regressed: $BASELINE_SCORE → $CURRENT_SCORE"
  exit 1
fi
```

### 5. False Positive Handling

**Qwen's 93.9% accuracy means ~6% false positive rate**:

- Review findings with confidence < 0.8 manually
- Use `--focus` to reduce noise
- Track recurring false positives and report issues

---

## Troubleshooting

### Problem 1: Slow Review Performance

**Symptom**:
```
Qwen review taking 15+ minutes (expected 2-5 minutes)
```

**Causes & Solutions**:

1. **Large commit**:
   ```bash
   # Split into smaller commits
   git reset HEAD~1
   git add src/module-1/
   git commit -m "feat: Add module 1"
   bash scripts/qwen-review.sh --timeout 300
   ```

2. **System resource contention**:
   ```bash
   # Check CPU/memory
   top -bn1 | head -20
   free -h

   # Kill competing processes if needed
   ```

3. **Wrapper timeout issue**:
   ```bash
   # Check wrapper logs
   cat logs/vibe/*/qwen_review_*.jsonl | tail -20
   ```

### Problem 2: Inflated Complexity Metrics

**Symptom**:
```json
{
  "metrics": {
    "average_cyclomatic_complexity": 25
  }
}
```

**But code looks simple**.

**Cause**: Language-specific idioms counted as complexity

**Solutions**:
1. **Check which functions** contribute:
   ```bash
   jq '.findings[] | select(.category=="Quality") | .function' logs/qwen-reviews/latest_qwen.json
   ```

2. **Review those functions manually** - might be false positives

3. **Consider refactoring** if genuinely complex

### Problem 3: Missing Pattern Detection

**Symptom**:
```json
{
  "patterns": {
    "detected": []
  }
}
```

**Expected**: Factory pattern should be detected

**Causes**:
1. **Pattern not explicit enough** - add comments
2. **Non-standard implementation** - follow canonical pattern structure
3. **Language limitation** - Qwen may not recognize patterns in all 358 languages equally

**Solutions**:
```bash
# Use --focus patterns for deeper analysis
bash scripts/qwen-review.sh --focus patterns --timeout 600

# Add explicit pattern comments
// Factory Pattern: Creates user objects based on type
class UserFactory { ... }
```

### Problem 4: Unrealistic Technical Debt

**Symptom**:
```json
{
  "metrics": {
    "technical_debt_hours": 500
  }
}
```

**Cause**: Large codebase accumulated debt over time

**Not a bug** - Qwen is reporting actual estimated debt.

**Solutions**:
1. **Track debt trends** over time
2. **Prioritize high-ROI fixes** (highest severity, lowest effort)
3. **Set incremental reduction goals** (e.g., -10% per quarter)

---

## Related Documentation

### Primary Documentation
- **Main Guide**: [FIVE_AI_REVIEW_GUIDE.md](../FIVE_AI_REVIEW_GUIDE.md) - Complete 5AI review system overview
- **CLAUDE.md**: [Project root](../../CLAUDE.md) - Integration with Multi-AI Orchestrium

### Other AI Review Guides
- [Gemini Review Guide](gemini-review-guide.md) - Security & architecture
- [Cursor Review Guide](cursor-review-guide.md) - IDE integration & developer experience
- [Amp Review Guide](amp-review-guide.md) - Project management & documentation
- [Droid Review Guide](droid-review-guide.md) - Enterprise standards & compliance

### External Resources
- **Qwen3-Coder**: https://qwenlm.github.io/blog/qwen2.5-coder/
- **HumanEval Benchmark**: https://github.com/openai/human-eval
- **REVIEW-PROMPT.md**: Project root - Review structure and guidelines
- **VibeLogger**: https://github.com/fladdict/vibe-logger - AI-native logging

### Implementation Details
- **Script Source**: `scripts/qwen-review.sh`
- **Test Suite**: `tests/test-qwen-review.sh` (26 test cases)
- **Test Observations**: `docs/test-observations/test-qwen-review-observation.md`

---

## Appendix: Qwen vs Other AIs

### When to Choose Qwen

| Use Case | Qwen | Alternative |
|----------|------|-------------|
| Code quality | ✅ **Best** (93.9% HumanEval) | N/A |
| Design patterns | ✅ **Best** | Gemini (architecture) |
| Performance analysis | ✅ **Best** | Gemini (scalability) |
| Fast review (<5 min) | ✅ **Best** | N/A |
| 358 languages | ✅ **Best** | Other AIs (limited langs) |
| Security | ⚠️ Use Gemini | **Gemini** (OWASP) |
| Documentation | ⚠️ Use Amp | **Amp** |
| IDE integration | ⚠️ Use Cursor | **Cursor** |
| Compliance | ⚠️ Use Droid | **Droid** (GDPR/SOC2) |

### Qwen Strengths

- **Speed**: 5x faster than Gemini, 3x faster than Droid
- **Code Accuracy**: 93.9% HumanEval (highest among Multi-AI team)
- **Language Support**: 358 programming languages
- **Pattern Recognition**: Best-in-class design pattern detection
- **Refactoring Suggestions**: Concrete, actionable recommendations

### Qwen Limitations

- **Security**: Basic detection only, use Gemini for OWASP Top 10
- **Compliance**: No GDPR/SOC2 awareness, use Droid
- **Documentation**: Focuses on code, not docs - use Amp
- **Context Window**: Smaller than Gemini's 200M tokens

---

**Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
**License**: MIT
