# Cursor Review Script Guide

**Script**: `scripts/cursor-review.sh`
**AI**: Cursor
**Version**: 1.0.0
**Specialization**: IDE Integration & Developer Experience

---

## Table of Contents

- [Overview](#overview)
- [Core Capabilities](#core-capabilities)
- [When to Use Cursor Review](#when-to-use-cursor-review)
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

The Cursor review script leverages Cursor's unique **IDE integration** and **real-time coding experience** to evaluate **code readability**, **navigation efficiency**, and **developer experience (DX)** factors that impact daily development productivity.

### Key Features

- **IDE Navigation Analysis**: Symbol jumping, definition lookup efficiency
- **Code Readability Scoring**: Cognitive load, naming clarity
- **Autocomplete-Friendly Patterns**: IntelliSense/Copilot compatibility
- **Refactoring Impact Assessment**: Safe refactoring opportunities
- **Developer Experience Metrics**: Time-to-understand, debugging ease

### Typical Review Scope

- UI/UX implementation code
- Developer-facing APIs and libraries
- Shared utility functions
- Team coding standards compliance
- IDE workflow optimization

---

## Core Capabilities

### 1. Code Readability Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| **Cognitive Complexity** | Mental effort to understand | <15 |
| **Naming Clarity** | Self-documenting names | 90%+ |
| **Visual Nesting** | Indentation depth | <4 levels |
| **Line Length** | Characters per line | <100 |
| **Function Length** | Lines per function | <50 |

### 2. IDE Navigation Efficiency

- **Symbol Resolution**: How quickly IDE finds definitions
- **Reference Lookup**: Cross-reference count and clarity
- **Type Inference**: TypeScript/type hint quality
- **Go-to-Definition**: Symbol linking effectiveness

### 3. Autocomplete Coverage

Evaluates patterns that enhance IDE autocomplete:
- Method chaining fluency
- Parameter naming hints
- Type annotation completeness
- JSDoc/docstring quality

### 4. Refactoring Safety

Identifies safe refactoring opportunities:
- Rename variable/function (low risk)
- Extract method (medium risk)
- Move class (high risk)
- Change signature (high risk)

---

## When to Use Cursor Review

### Ideal Scenarios

1. **Developer Libraries**
   - npm packages, gems, pip packages
   - Internal utility libraries
   - Framework extensions

2. **UI/UX Code**
   - React/Vue components
   - CSS/styling implementations
   - Frontend state management

3. **Team Onboarding**
   - New developer readability checks
   - Coding standard validation
   - Documentation gaps identification

4. **API Design Review**
   - RESTful endpoint design
   - GraphQL schema review
   - SDK method signatures

### When NOT to Use (Prefer Other AIs)

- **Security**: Use Gemini Review for vulnerability detection
- **Code Quality Metrics**: Use Qwen Review for complexity analysis
- **Documentation Content**: Use Amp Review for doc quality
- **Enterprise Compliance**: Use Droid Review for standards

---

## Installation & Prerequisites

### Prerequisites

1. **Cursor Wrapper Script**
   ```bash
   which cursor-wrapper.sh
   # Expected: /path/to/multi-ai-orchestrium/bin/cursor-wrapper.sh
   ```

2. **Git Repository**
3. **REVIEW-PROMPT.md** at project root

### Environment Setup

```bash
export CURSOR_REVIEW_TIMEOUT=600  # 10 minutes default
export OUTPUT_DIR=logs/my-cursor-reviews
```

---

## Basic Usage

### Quick Start

```bash
# Review latest commit for developer experience
bash scripts/cursor-review.sh

# Review with extended timeout
bash scripts/cursor-review.sh --timeout 900

# Review specific commit
bash scripts/cursor-review.sh --commit abc123
```

### Typical Workflow

```bash
# 1. Implement UI component
vim src/components/UserProfile.tsx

# 2. Commit changes
git add src/components/UserProfile.tsx
git commit -m "feat: Add UserProfile component"

# 3. Run Cursor DX review
bash scripts/cursor-review.sh --timeout 600

# 4. Review readability issues
cat logs/cursor-reviews/latest_cursor.md
```

---

## Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--timeout` | `-t` | Review timeout in seconds | 600 (10 min) |
| `--commit` | `-c` | Commit hash to review | HEAD |
| `--output` | `-o` | Output directory path | logs/cursor-reviews |
| `--focus` | N/A | Focus area (see below) | all |
| `--help` | `-h` | Show help message | N/A |

### Focus Areas

| Focus | Description |
|-------|-------------|
| `readability` | Code clarity, naming, structure |
| `ide-friendliness` | Navigation, autocomplete, IntelliSense |
| `completion` | Copilot/autocomplete compatibility |
| `all` | All areas (default) |

**Example**:
```bash
bash scripts/cursor-review.sh --focus readability
```

---

## Output Formats

### JSON Report

**Location**: `logs/cursor-reviews/{timestamp}_{commit}_cursor.json`

**Structure**:
```json
{
  "metadata": {
    "ai": "Cursor",
    "specialization": "IDE Integration & Developer Experience",
    "timestamp": "2025-10-26T12:00:00Z",
    "commit": "abc123",
    "focus_area": "all"
  },
  "summary": {
    "dx_score": 78,
    "readability_score": 82,
    "autocomplete_coverage": 0.75,
    "total_findings": 12
  },
  "findings": [
    {
      "id": "CUR-001",
      "title": "Long function reduces readability",
      "severity": "Medium",
      "category": "Readability",
      "file": "src/components/UserProfile.tsx",
      "line": 45,
      "function": "renderUserDetails",
      "cognitive_complexity": 18,
      "recommendation": "Extract sub-rendering logic into separate components",
      "refactoring_safety": "low_risk",
      "estimated_time_saved_per_dev_day": "5 minutes"
    }
  ],
  "metrics": {
    "average_cognitive_complexity": 8.5,
    "average_function_length": 28,
    "naming_clarity_pct": 85,
    "type_annotation_coverage": 0.92
  }
}
```

### Markdown Report

Sections:
1. **Developer Experience Summary**
2. **Readability Findings**
3. **IDE Navigation Issues**
4. **Autocomplete Recommendations**
5. **Refactoring Opportunities**

---

## Interpreting Results

### DX Score (0-100)

| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | Excellent | Maintain standards |
| 80-89 | Good | Minor improvements |
| 70-79 | Fair | Address Medium findings |
| <70 | Poor | Major refactoring needed |

### Readability Score

- **High (80+)**: Easy for new developers to understand
- **Medium (60-79)**: Requires familiarity with codebase
- **Low (<60)**: Difficult to read, needs refactoring

### Autocomplete Coverage

- **90%+**: Excellent IDE support
- **70-89%**: Good, some gaps
- **<70%**: Poor autocomplete experience

---

## Common Use Cases

### Use Case 1: Component Library Review

```bash
# Scenario: New React component library
git commit -m "feat: Add Button component library"

bash scripts/cursor-review.sh --focus readability --timeout 600

# Check readability score
jq '.summary.readability_score' logs/cursor-reviews/latest_cursor.json
```

### Use Case 2: API Client Review

```bash
# Scenario: REST API client implementation
git commit -m "feat: Add UserAPI client"

bash scripts/cursor-review.sh --focus ide-friendliness

# Check autocomplete coverage
jq '.metrics.type_annotation_coverage' logs/cursor-reviews/latest_cursor.json
```

### Use Case 3: Refactoring Safety Check

```bash
# Before refactoring
bash scripts/cursor-review.sh --focus all --output pre-refactor/

# After refactoring
bash scripts/cursor-review.sh --focus all --output post-refactor/

# Compare DX scores
PRE=$(jq '.summary.dx_score' pre-refactor/latest_cursor.json)
POST=$(jq '.summary.dx_score' post-refactor/latest_cursor.json)
echo "DX Score: $PRE → $POST"
```

---

## Workflow Integration

### Integration Pattern 1: Pre-PR Review

```bash
# Before creating PR for UI changes
git checkout feature/new-ui
git commit -am "feat: Redesign user dashboard"

bash scripts/cursor-review.sh --focus readability

# Check DX score threshold
DX_SCORE=$(jq '.summary.dx_score' logs/cursor-reviews/latest_cursor.json)
if [ "$DX_SCORE" -lt 75 ]; then
  echo "❌ DX score too low: $DX_SCORE"
  exit 1
fi

gh pr create --title "Redesign User Dashboard"
```

### Integration Pattern 2: Component Library CI

```yaml
# .github/workflows/dx-review.yml
name: Cursor DX Review

on:
  pull_request:
    paths:
      - 'src/components/**'
      - 'src/ui/**'

jobs:
  dx-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Cursor Review
        run: bash scripts/cursor-review.sh --focus readability

      - name: Check DX Standards
        run: |
          DX_SCORE=$(jq '.summary.dx_score' logs/cursor-reviews/latest_cursor.json)
          if [ "$DX_SCORE" -lt 80 ]; then
            echo "❌ DX score below 80: $DX_SCORE"
            exit 1
          fi
```

---

## Best Practices

### 1. UI/UX Code Focus

Cursor review is most valuable for:
- React/Vue/Angular components
- CSS/styled-components
- Frontend state management
- User-facing APIs

### 2. Readability Targets

| Code Type | Target Readability Score |
|-----------|-------------------------|
| Components | 85+ |
| Utilities | 80+ |
| APIs | 85+ |
| Internal logic | 75+ |

### 3. Naming Conventions

Cursor evaluates naming clarity:
```typescript
// Good - clear intent
function calculateUserSubscriptionCost(userId: string): number

// Bad - unclear abbreviations
function calcUsrSubCst(uid: string): number
```

### 4. Type Annotation Coverage

Aim for 90%+ type coverage for best autocomplete:
```typescript
// Good - fully typed
interface UserProfile {
  id: string;
  name: string;
  email: string;
}

function updateProfile(profile: UserProfile): Promise<void>

// Bad - missing types
function updateProfile(profile) {
  // ...
}
```

---

## Troubleshooting

### Problem 1: Low DX Score Despite Good Code

**Symptom**: DX score 60, but code seems fine

**Possible Causes**:
1. Missing type annotations
2. Long function names
3. Deep nesting (>4 levels)
4. Unclear variable names

**Solutions**:
```bash
# Check specific findings
jq '.findings[] | select(.severity=="High")' logs/cursor-reviews/latest_cursor.json

# Focus on readability
bash scripts/cursor-review.sh --focus readability
```

### Problem 2: False Positive Refactoring Warnings

**Symptom**: Cursor suggests extracting 5-line functions

**Cause**: Overly aggressive refactoring detection

**Solution**: Ignore Low severity refactoring suggestions, focus on High/Medium

---

## Related Documentation

### Primary Documentation
- **Main Guide**: [FIVE_AI_REVIEW_GUIDE.md](../FIVE_AI_REVIEW_GUIDE.md)
- **CLAUDE.md**: [Project root](../../CLAUDE.md)

### Other AI Review Guides
- [Gemini Review Guide](gemini-review-guide.md) - Security & architecture
- [Qwen Review Guide](qwen-review-guide.md) - Code quality & patterns
- [Amp Review Guide](amp-review-guide.md) - Project management & docs
- [Droid Review Guide](droid-review-guide.md) - Enterprise standards

### Implementation Details
- **Script Source**: `scripts/cursor-review.sh`
- **Test Suite**: `tests/test-cursor-review.sh` (26 test cases)

---

## Appendix: Cursor vs Other AIs

| Use Case | Cursor | Alternative |
|----------|--------|-------------|
| Code readability | ✅ **Best** | Qwen (complexity) |
| IDE navigation | ✅ **Best** | N/A |
| Autocomplete | ✅ **Best** | N/A |
| DX optimization | ✅ **Best** | N/A |
| Security | ⚠️ Use Gemini | **Gemini** |
| Code quality | ⚠️ Use Qwen | **Qwen** |
| Documentation | ⚠️ Use Amp | **Amp** |

---

**Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
**License**: MIT
