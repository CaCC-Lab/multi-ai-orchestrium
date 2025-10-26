# 5AI Review Scripts Architecture

**Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Script Structure](#script-structure)
4. [Component Details](#component-details)
5. [Data Flow](#data-flow)
6. [Integration Points](#integration-points)
7. [Extension Points](#extension-points)
8. [Security Considerations](#security-considerations)

---

## Overview

5AI Review Scriptsは、Multi-AI Orchestriumの一部として、5つの異なるAI（Gemini, Qwen, Cursor, Amp, Droid）を活用した専門特化型コードレビューシステムです。各スクリプトは共通のアーキテクチャパターンに従いつつ、AI固有の最適化を実装しています。

### Design Principles

1. **Consistency**: 全スクリプトが同一のインターフェースと構造を共有
2. **Specialization**: 各AIの強みに特化したプロンプトとメトリクス
3. **Observability**: VibeLoggerによるAI最適化構造化ロギング
4. **Security**: 入力検証、安全な一時ファイル処理、自動クリーンアップ
5. **Extensibility**: 新しいAIレビュースクリプトの追加が容易

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     User / CI/CD Pipeline                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Review Script (Entry Point)                   │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐ │
│  │ gemini-review│ qwen-review  │ cursor-review│ amp-review   │ │
│  │              │              │              │ droid-review │ │
│  └──────────────┴──────────────┴──────────────┴──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ Input         │   │ Prompt        │   │ Libraries     │
│ Validation    │   │ Generation    │   │ - sanitize.sh │
│ (sanitize.sh) │   │ (REVIEW-      │   │ - vibe-logger │
│               │   │  PROMPT.md)   │   │               │
└───────────────┘   └───────────────┘   └───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI Wrapper Layer                           │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐ │
│  │ gemini-      │ qwen-        │ cursor-      │ amp-         │ │
│  │ wrapper.sh   │ wrapper.sh   │ wrapper.sh   │ wrapper.sh   │ │
│  │              │              │              │ droid-       │ │
│  │              │              │              │ wrapper.sh   │ │
│  └──────────────┴──────────────┴──────────────┴──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI Services                                │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐ │
│  │ Gemini 2.5   │ Qwen3-Coder  │ Cursor       │ Amp          │ │
│  │ (Security &  │ (Code Quality│ (IDE & DX)   │ (PM & Docs)  │ │
│  │ Architecture)│ & Patterns)  │              │ Droid        │ │
│  │              │              │              │ (Enterprise) │ │
│  └──────────────┴──────────────┴──────────────┴──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ Output        │   │ VibeLogger    │   │ Report        │
│ Parsing       │   │ Events        │   │ Generation    │
│               │   │ (JSONL)       │   │ (JSON/MD)     │
└───────────────┘   └───────────────┘   └───────────────┘
```

### Component Layers

#### 1. **User Interface Layer**
- CLI argument parsing (`--timeout`, `--commit`, `--output`, `--focus`, etc.)
- Help messages and usage documentation
- User feedback (colored output, progress indicators)

#### 2. **Validation Layer**
- Input sanitization (`scripts/lib/sanitize.sh`)
- Prerequisites checking (wrapper availability, git repository, commit existence)
- Security validation (path traversal, command injection prevention)

#### 3. **Orchestration Layer**
- Review script main logic
- AI wrapper execution
- Timeout management
- Error handling and fallback mechanisms

#### 4. **Integration Layer**
- AI wrapper scripts (`bin/*-wrapper.sh`)
- Task classification based on `AGENTS.md`
- Dynamic timeout adjustment
- Approval prompts for critical tasks

#### 5. **Output Layer**
- JSON report generation (machine-readable)
- Markdown report generation (human-readable)
- VibeLogger event logging (AI-optimized structured logging)
- Symlink creation for latest results

---

## Script Structure

All 5 review scripts follow a consistent structure:

```bash
#!/bin/bash
# [AI] Code Quality Review Script
# Version: 1.0.0
# Purpose: Execute [AI] code quality review with REVIEW-PROMPT.md guidance

set -euo pipefail

# ======================================
# 1. Configuration
# ======================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Vibe Logger Setup
export VIBE_LOG_DIR="$PROJECT_ROOT/logs/vibe/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR"

# Load libraries
source "$SCRIPT_DIR/lib/sanitize.sh"
source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"

# ======================================
# 2. Default Configuration
# ======================================
[AI]_REVIEW_TIMEOUT=${[AI]_REVIEW_TIMEOUT:-600}
OUTPUT_DIR="${OUTPUT_DIR:-logs/[ai]-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"

# ======================================
# 3. Utility Functions
# ======================================
log_error() { ... }
log_success() { ... }
log_warning() { ... }
log_info() { ... }
get_timestamp_ms() { ... }

# ======================================
# 4. VibeLogger Functions
# ======================================
vibe_log() { ... }
vibe_tool_start() { ... }
vibe_tool_done() { ... }
vibe_[ai]_analysis() { ... }  # AI-specific custom function

# ======================================
# 5. Help Message
# ======================================
show_help() { ... }

# ======================================
# 6. CLI Argument Parsing
# ======================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --commit) COMMIT_HASH="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --focus) FOCUS_AREA="$2"; shift 2 ;;  # AI-specific
        --help) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# ======================================
# 7. Prerequisites Check
# ======================================
# Check wrapper availability
# Check git repository
# Verify commit existence
# Check REVIEW-PROMPT.md

# ======================================
# 8. Review Prompt Generation
# ======================================
# Load REVIEW-PROMPT.md
# Extract commit diff
# Create AI-specific analysis prompt
# Add focus area customization

# ======================================
# 9. AI Wrapper Execution
# ======================================
# Create secure temp file (chmod 600)
# Execute wrapper with timeout
# Capture stdout/stderr
# Handle JSON/text output

# ======================================
# 10. Output Parsing and Generation
# ======================================
# Parse JSON findings
# Extract AI-specific metrics
# Generate JSON report
# Generate Markdown report
# Create symlinks (latest_[ai].json/md)

# ======================================
# 11. Cleanup and Exit
# ======================================
# Cleanup temp files (trap EXIT)
# Log completion event
# Exit with appropriate status code
```

---

## Component Details

### 1. Configuration Management

#### Environment Variables

All scripts respect the following environment variables:

```bash
# Timeout configuration (AI-specific defaults)
GEMINI_REVIEW_TIMEOUT=900      # 15 minutes (security analysis)
QWEN_REVIEW_TIMEOUT=600        # 10 minutes (code quality)
CURSOR_REVIEW_TIMEOUT=600      # 10 minutes (DX analysis)
AMP_REVIEW_TIMEOUT=600         # 10 minutes (PM analysis)
DROID_REVIEW_TIMEOUT=900       # 15 minutes (enterprise analysis)

# Output directory
OUTPUT_DIR="logs/[ai]-reviews"

# Commit to review
COMMIT_HASH="HEAD"

# VibeLogger directory
VIBE_LOG_DIR="logs/vibe/$(date +%Y%m%d)"
```

#### Configuration Files

- **REVIEW-PROMPT.md**: Base review guidelines (shared across all AIs)
- **AGENTS.md**: Task classification for wrapper scripts
- **config/multi-ai-profiles.yaml**: AI capabilities and timeouts (orchestration)

### 2. Input Validation (`sanitize.sh`)

All user inputs pass through `sanitize_input()`:

```bash
sanitize_input() {
    local input="$1"
    local max_length="${2:-100000}"  # Default 100KB

    # Length validation
    if [[ ${#input} -gt $max_length ]]; then
        echo "[ERROR] Input exceeds maximum length ($max_length)" >&2
        return 1
    fi

    # Command injection prevention
    # Path traversal prevention
    # Special character handling
    # ...

    echo "$sanitized"
}
```

**Key Security Features**:
- Length limits (100KB default, 1MB for file-based prompts)
- Command injection prevention (backticks, $(...), etc.)
- Path traversal prevention (../, absolute paths)
- Special character escaping

### 3. VibeLogger Integration

#### Log Structure

VibeLogger produces AI-optimized JSONL logs:

```json
{
  "timestamp": "2025-10-26T12:00:00Z",
  "runid": "qwen_review_1729944000_12345",
  "event": "tool_execution",
  "action": "start",
  "metadata": {
    "commit": "abc123",
    "timeout": 600,
    "focus_area": "patterns"
  },
  "human_note": "Starting Qwen code quality review for commit abc123",
  "ai_context": {
    "tool": "Qwen",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "specialization": "Code Quality, Design Patterns, Performance (HumanEval 93.9%)",
    "todo": "analyze code quality, detect patterns, evaluate performance"
  }
}
```

#### Key VibeLogger Functions

1. **`vibe_log()`**: Generic event logging
2. **`vibe_tool_start()`**: Tool execution start
3. **`vibe_tool_done()`**: Tool execution completion
4. **`vibe_[ai]_analysis()`**: AI-specific custom events
   - `vibe_security_analysis()` (Gemini)
   - `vibe_code_quality_analysis()` (Qwen)
   - `vibe_dx_analysis()` (Cursor)
   - `vibe_pm_analysis()` (Amp)
   - `vibe_enterprise_analysis()` (Droid)

#### Log File Organization

```
logs/vibe/
└── YYYYMMDD/
    ├── gemini_review_00.jsonl
    ├── gemini_review_01.jsonl
    ├── qwen_review_00.jsonl
    ├── cursor_review_12.jsonl
    └── ...
```

Files are organized by:
- **Date**: `YYYYMMDD` directory
- **AI**: `[ai]_review_` prefix
- **Hour**: `HH.jsonl` suffix

### 4. REVIEW-PROMPT.md Usage

#### Prompt Structure

All scripts use REVIEW-PROMPT.md as the base template:

```markdown
# Review Guidelines

You are functioning as a code reviewer for changes proposed by another engineer.

[... guidelines from REVIEW-PROMPT.md ...]

---

# AI-Specific Context

AI: [Gemini/Qwen/Cursor/Amp/Droid]
Specialization: [AI-specific focus areas]
Focus Area: [User-specified focus, if any]

# Commit Diff

[Git diff output]

# Review Instructions

[AI-specific custom instructions]
```

#### AI-Specific Customizations

Each script adds custom instructions after REVIEW-PROMPT.md:

- **Gemini**: OWASP Top 10, CWE references, architecture patterns
- **Qwen**: Design patterns, code complexity metrics, maintainability index
- **Cursor**: IDE navigation, autocomplete friendliness, refactoring opportunities
- **Amp**: Documentation coverage, stakeholder communication, sprint alignment
- **Droid**: Enterprise checklist, compliance requirements (GDPR, SOC2, HIPAA)

### 5. AI Wrapper Execution

#### Wrapper Script Architecture

```bash
# bin/[ai]-wrapper.sh

# 1. Task Classification (AGENTS.md)
classify_task "$prompt" → lightweight | standard | critical

# 2. Dynamic Timeout Adjustment
if [[ "$task_type" == "critical" ]]; then
    timeout="${timeout:-900}"  # 15 minutes
elif [[ "$task_type" == "standard" ]]; then
    timeout="${timeout:-600}"  # 10 minutes
else
    timeout="${timeout:-300}"  # 5 minutes
fi

# 3. Approval Prompt (Critical Tasks)
if [[ "$task_type" == "critical" && "$NON_INTERACTIVE" != "true" ]]; then
    prompt_user_approval "$prompt"
fi

# 4. AI Service Execution
[ai]-cli exec --prompt "$prompt" --timeout "$timeout"

# 5. VibeLogger Event Logging
vibe_wrapper_start "[AI]" "$prompt" "$timeout"
vibe_wrapper_done "[AI]" "$status" "$duration_ms" "$exit_code"
```

#### Secure Temp File Handling

```bash
# Create secure temp file
TEMP_PROMPT_FILE=$(mktemp -t prompt-[ai]-XXXXXX)
chmod 600 "$TEMP_PROMPT_FILE"  # Owner read/write only

# Write prompt
echo "$full_prompt" > "$TEMP_PROMPT_FILE"

# Execute with stdin redirect
./bin/[ai]-wrapper.sh < "$TEMP_PROMPT_FILE"

# Cleanup (trap EXIT)
trap "rm -f '$TEMP_PROMPT_FILE'" EXIT INT TERM
```

### 6. Output Format Specifications

#### JSON Report Schema

```json
{
  "review_metadata": {
    "ai": "qwen",
    "version": "1.0.0",
    "timestamp": "2025-10-26T12:00:00Z",
    "commit": "abc123",
    "timeout": 600,
    "focus_area": "patterns",
    "duration_ms": 45000
  },
  "summary": {
    "total_findings": 5,
    "critical": 1,
    "high": 2,
    "medium": 1,
    "low": 1,
    "confidence_score": 0.92
  },
  "findings": [
    {
      "id": "QW-001",
      "title": "Inefficient algorithm in data processing",
      "severity": "High",
      "priority": "P1",
      "confidence": 0.95,
      "file": "src/processor.ts",
      "line": 42,
      "category": "Performance",
      "description": "The current O(n^2) algorithm can be optimized to O(n log n) using a sorted map approach.",
      "recommendation": "Replace the nested loop with a Map-based lookup.",
      "code_snippet": "for (let i = 0; i < data.length; i++) {\n  for (let j = i + 1; j < data.length; j++) {\n    ...\n  }\n}",
      "tags": ["performance", "algorithm", "optimization"]
    }
  ],
  "metrics": {
    "code_quality_score": 78,
    "maintainability_index": 65,
    "cyclomatic_complexity": 12,
    "technical_debt_hours": 4.5
  },
  "recommendations": [
    {
      "priority": "P0",
      "action": "Refactor nested loops in processor module",
      "impact": "High performance improvement (5x faster)",
      "effort": "Medium (2-3 hours)"
    }
  ]
}
```

#### Markdown Report Structure

```markdown
# [AI] Code Review Report

**Commit**: abc123
**Date**: 2025-10-26 12:00:00 UTC
**Reviewer**: [AI Name] ([Specialization])
**Duration**: 45 seconds
**Focus Area**: [User-specified or default]

---

## Executive Summary

- **Total Findings**: 5
- **Critical**: 1 | **High**: 2 | **Medium**: 1 | **Low**: 1
- **Confidence Score**: 92%
- **Overall Assessment**: [Pass/Fail/Conditional]

---

## Key Findings

### 🔴 Critical (P0)

#### [Finding Title]
**File**: `src/file.ts:42`
**Category**: Performance
**Confidence**: 95%

[Description]

**Recommendation**: [Action to take]

**Code**:
```typescript
[Code snippet]
```

---

### 🟠 High (P1)

[...]

---

## Metrics

- **Code Quality Score**: 78/100
- **Maintainability Index**: 65/100
- **Cyclomatic Complexity**: 12 (Moderate)
- **Technical Debt**: 4.5 hours

---

## Recommendations

1. **[Priority]** [Action] → [Impact] (Effort: [Low/Medium/High])
2. ...

---

## Review Details

- **AI**: [AI Name]
- **Version**: 1.0.0
- **Timeout**: 600s
- **Exit Code**: 0
```

---

## Data Flow

### End-to-End Review Flow

```
1. User invokes review script
   └─> bash scripts/qwen-review.sh --commit abc123 --focus patterns

2. CLI argument parsing
   └─> Timeout: 600s, Commit: abc123, Focus: patterns

3. Prerequisites check
   ├─> qwen-wrapper.sh available? ✓
   ├─> Git repository? ✓
   ├─> Commit abc123 exists? ✓
   └─> REVIEW-PROMPT.md exists? ✓

4. Review prompt generation
   ├─> Load REVIEW-PROMPT.md (base guidelines)
   ├─> Extract git diff for abc123
   ├─> Add Qwen-specific instructions (patterns focus)
   └─> Create full prompt (~5KB)

5. Input sanitization
   ├─> Sanitize commit hash (alphanumeric validation)
   ├─> Sanitize focus area (enum validation)
   └─> Sanitize prompt (length check, injection prevention)

6. Secure temp file creation
   ├─> mktemp -t prompt-qwen-XXXXXX
   ├─> chmod 600 (owner-only)
   └─> Write full prompt to file

7. VibeLogger event: tool_start
   └─> Log to logs/vibe/20251026/qwen_review_12.jsonl

8. AI wrapper execution
   ├─> ./bin/qwen-wrapper.sh < /tmp/prompt-qwen-ABC123
   ├─> Task classification: standard (600s timeout)
   ├─> Execute: qwen exec --timeout 600s
   └─> Capture stdout (JSON response)

9. Output parsing
   ├─> Detect JSON vs plain text
   ├─> Extract findings array
   ├─> Calculate metrics (quality score, complexity, etc.)
   └─> Validate schema

10. Report generation
    ├─> Generate JSON report → logs/qwen-reviews/20251026_120000_abc123_qwen.json
    ├─> Generate Markdown report → logs/qwen-reviews/20251026_120000_abc123_qwen.md
    └─> Create symlinks → logs/qwen-reviews/latest_qwen.{json,md}

11. VibeLogger event: tool_done
    └─> Log completion with duration_ms, exit_code

12. Cleanup
    ├─> Remove temp file (trap EXIT)
    └─> Exit with status code (0 = success, 1 = error)
```

---

## Integration Points

### 1. Git Integration

All scripts require a valid Git repository:

```bash
# Verify git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not a git repository"
    exit 1
fi

# Verify commit existence
if ! git rev-parse --verify "$COMMIT_HASH" > /dev/null 2>&1; then
    log_error "Commit $COMMIT_HASH not found"
    exit 1
fi

# Extract commit diff
git show "$COMMIT_HASH" --format=fuller --stat --patch
```

### 2. Multi-AI Orchestration

Scripts integrate with `multi-ai-review.sh`:

```bash
# scripts/multi-ai-review.sh

# Run specific AI review
bash scripts/qwen-review.sh --commit "$COMMIT" --timeout "$TIMEOUT"

# Run all AI reviews in parallel
bash scripts/gemini-review.sh --commit "$COMMIT" &
bash scripts/qwen-review.sh --commit "$COMMIT" &
bash scripts/cursor-review.sh --commit "$COMMIT" &
bash scripts/amp-review.sh --commit "$COMMIT" &
bash scripts/droid-review.sh --commit "$COMMIT" &
wait

# Generate unified report
generate_unified_report logs/*-reviews/latest_*.json
```

### 3. CI/CD Integration

Example GitHub Actions workflow:

```yaml
# .github/workflows/5ai-review.yml

name: 5AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run 5AI Review
        run: |
          bash scripts/multi-ai-review.sh --type all --commit ${{ github.event.pull_request.head.sha }}

      - name: Comment PR
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('logs/multi-ai-reviews/latest_unified.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: report
            });
```

### 4. IDE Integration

Example VS Code task:

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Qwen Review (Current Commit)",
      "type": "shell",
      "command": "bash scripts/qwen-review.sh",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    }
  ]
}
```

---

## Extension Points

### Adding a New AI Review Script

To add a new AI (e.g., `codex-review.sh`):

1. **Create wrapper script** (`bin/codex-wrapper.sh`)
   - Follow existing wrapper pattern
   - Add to AGENTS.md task classification

2. **Create review script** (`scripts/codex-review.sh`)
   ```bash
   # Use template from existing scripts
   cp scripts/qwen-review.sh scripts/codex-review.sh

   # Customize:
   # - CODEX_REVIEW_TIMEOUT
   # - vibe_codex_analysis() function
   # - AI-specific prompt customization
   # - Focus areas (--focus option values)
   # - Metrics calculation
   ```

3. **Create test suite** (`tests/test-codex-review.sh`)
   - Copy from existing test files
   - Update test cases for Codex-specific features

4. **Update documentation**
   - Add to CLAUDE.md
   - Add to FIVE_AI_REVIEW_GUIDE.md
   - Create `docs/reviews/codex-review-guide.md`

5. **Update multi-ai-review.sh**
   ```bash
   # Add Codex option
   case "$TYPE" in
       codex)
           bash scripts/codex-review.sh --commit "$COMMIT" --timeout "$TIMEOUT"
           ;;
       all)
           # Add to parallel execution
           bash scripts/codex-review.sh --commit "$COMMIT" &
           ;;
   esac
   ```

### Custom Focus Areas

Each AI can define custom focus areas:

```bash
# scripts/qwen-review.sh

FOCUS_AREA="${FOCUS_AREA:-quality}"  # Default focus

case "$FOCUS_AREA" in
    patterns)
        FOCUS_INSTRUCTIONS="Focus on design patterns, anti-patterns, and architectural decisions."
        ;;
    quality)
        FOCUS_INSTRUCTIONS="Focus on code quality metrics, complexity, and maintainability."
        ;;
    performance)
        FOCUS_INSTRUCTIONS="Focus on performance optimization, algorithm efficiency, and resource usage."
        ;;
    *)
        log_error "Invalid focus area: $FOCUS_AREA"
        exit 1
        ;;
esac
```

### Custom Metrics

AI-specific metrics can be added:

```bash
# scripts/qwen-review.sh

calculate_qwen_metrics() {
    local findings="$1"

    # Extract metrics from findings JSON
    local complexity=$(jq -r '.metrics.cyclomatic_complexity' <<< "$findings")
    local maintainability=$(jq -r '.metrics.maintainability_index' <<< "$findings")
    local debt_hours=$(jq -r '.metrics.technical_debt_hours' <<< "$findings")

    # Calculate custom scores
    local quality_score=$(( (100 - complexity) * maintainability / 100 ))

    echo "{\"quality_score\": $quality_score, \"complexity\": $complexity, \"maintainability\": $maintainability, \"debt_hours\": $debt_hours}"
}
```

---

## Security Considerations

### 1. Input Validation

**Threats**:
- Command injection via unsanitized inputs
- Path traversal in file operations
- Resource exhaustion (large inputs)

**Mitigations**:
- All inputs pass through `sanitize_input()`
- Whitelist validation for enums (focus areas, commit hashes)
- Length limits enforced (100KB default, 1MB max)
- Timeout enforcement (prevent infinite execution)

### 2. Temporary File Security

**Threats**:
- Sensitive data leakage via world-readable temp files
- Race conditions in temp file creation
- Orphaned temp files after crashes

**Mitigations**:
- `chmod 600` immediately after creation (owner-only)
- `mktemp` ensures unique filenames (prevents race conditions)
- `trap EXIT INT TERM` ensures cleanup on all exit scenarios

### 3. Subprocess Execution

**Threats**:
- Shell injection via unsanitized command arguments
- Privilege escalation
- Runaway processes (infinite loops)

**Mitigations**:
- No user input directly in command substitution
- Timeout enforcement for all AI wrapper calls
- Error handling for non-zero exit codes

### 4. Output Sanitization

**Threats**:
- XSS in generated HTML reports (future feature)
- Log injection in VibeLogger output
- Sensitive data exposure in reports

**Mitigations**:
- Markdown output is safe (plain text)
- JSON output is schema-validated
- Commit diffs may contain sensitive data (document this risk)

---

## Performance Considerations

### Optimization Strategies

1. **Parallel Execution**: Multiple AI reviews can run concurrently
2. **Caching**: Wrapper scripts cache task classifications
3. **Incremental Analysis**: Only analyze changed files (not full codebase)
4. **Timeout Tuning**: AI-specific timeouts based on average execution time

### Bottlenecks

- **Git Diff Extraction**: Large commits (>1000 files) may be slow
  - Mitigation: Truncate diff to reasonable size, summarize large changes

- **AI Service Latency**: Network calls to external AI services
  - Mitigation: Configurable timeouts, fallback mechanisms

- **JSON Parsing**: Large responses (>10MB) may be slow
  - Mitigation: Stream parsing for large responses (future enhancement)

### Benchmarks

Typical execution times (on 100-line commit):

| AI | Review Type | Avg Time | P95 Time |
|----|-------------|----------|----------|
| Gemini | Security | 45s | 90s |
| Qwen | Code Quality | 35s | 60s |
| Cursor | DX Analysis | 30s | 50s |
| Amp | PM Analysis | 40s | 70s |
| Droid | Enterprise | 60s | 120s |

---

## Future Enhancements

### Planned Features (Phase 4)

1. **Review Dispatcher**: Automatic AI selection based on commit type
2. **Unified Report**: Combine all 5 AI reviews into single dashboard
3. **Incremental Reviews**: Only review changed functions, not full files
4. **ML-Based Severity**: Train model to classify finding severity
5. **Interactive Mode**: Allow user to approve/reject findings interactively

### Potential Improvements

- **Streaming Output**: Real-time progress updates during long reviews
- **Distributed Execution**: Run AI reviews on multiple machines
- **Result Caching**: Cache review results for unchanged commits
- **Custom Rules**: Allow users to define project-specific review rules

---

## Appendix

### A. File Locations

```
multi-ai-orchestrium/
├── scripts/
│   ├── gemini-review.sh          # Gemini security review
│   ├── qwen-review.sh            # Qwen code quality review
│   ├── cursor-review.sh          # Cursor DX review
│   ├── amp-review.sh             # Amp PM review
│   ├── droid-review.sh           # Droid enterprise review
│   ├── multi-ai-review.sh        # Unified interface
│   └── lib/
│       └── sanitize.sh           # Input validation library
├── bin/
│   ├── gemini-wrapper.sh         # Gemini AI wrapper
│   ├── qwen-wrapper.sh           # Qwen AI wrapper
│   ├── cursor-wrapper.sh         # Cursor AI wrapper
│   ├── amp-wrapper.sh            # Amp AI wrapper
│   ├── droid-wrapper.sh          # Droid AI wrapper
│   └── vibe-logger-lib.sh        # VibeLogger library
├── logs/
│   ├── gemini-reviews/           # Gemini review outputs
│   ├── qwen-reviews/             # Qwen review outputs
│   ├── cursor-reviews/           # Cursor review outputs
│   ├── amp-reviews/              # Amp review outputs
│   ├── droid-reviews/            # Droid review outputs
│   └── vibe/                     # VibeLogger JSONL logs
│       └── YYYYMMDD/
│           ├── gemini_review_HH.jsonl
│           ├── qwen_review_HH.jsonl
│           └── ...
├── tests/
│   ├── test-gemini-review.sh     # Gemini review tests
│   ├── test-qwen-review.sh       # Qwen review tests
│   ├── test-cursor-review.sh     # Cursor review tests
│   ├── test-amp-review.sh        # Amp review tests
│   ├── test-droid-review.sh      # Droid review tests
│   ├── run-all-review-tests.sh   # Test runner
│   └── lib/
│       └── test-helpers.sh       # Test utilities
└── docs/
    ├── ARCHITECTURE.md           # This document
    ├── FIVE_AI_REVIEW_GUIDE.md   # User guide
    └── reviews/
        ├── gemini-review-guide.md
        ├── qwen-review-guide.md
        ├── cursor-review-guide.md
        ├── amp-review-guide.md
        └── droid-review-guide.md
```

### B. Key Dependencies

- **Git**: Version control (diff extraction, commit verification)
- **Bash**: 4.0+ (associative arrays, process substitution)
- **jq**: JSON parsing and generation
- **mktemp**: Secure temporary file creation
- **AI CLIs**: gemini, qwen, cursor, amp, droid command-line tools

### C. Error Codes

| Code | Meaning |
|------|---------|
| 0 | Success (review completed) |
| 1 | General error (invalid arguments, prerequisites failed) |
| 2 | Timeout (AI wrapper exceeded timeout) |
| 3 | AI service error (non-zero exit code from wrapper) |
| 4 | Output parsing error (invalid JSON response) |
| 5 | Validation error (input sanitization failed) |

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-26
**Maintainer**: Multi-AI Orchestrium Team
**Related**: [FIVE_AI_REVIEW_GUIDE.md](FIVE_AI_REVIEW_GUIDE.md), [CONTRIBUTING.md](CONTRIBUTING.md)
