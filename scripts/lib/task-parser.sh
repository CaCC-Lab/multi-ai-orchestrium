#!/usr/bin/env bash
# task-parser.sh - Markdown仕様書からタスクを抽出するライブラリ
# Phase 2-3-1: Task Parser (Qwen実装、Droid品質基準)

set -euo pipefail

TASK_PARSER_VERSION="1.0.0"

#---------------------------------------------------------------------
# 内部ヘルパー
#---------------------------------------------------------------------

_task_parser_usage() {
  cat <<'EOF'
Usage: task-parser.sh parse <spec_file> [--format ndjson|json] [--output <path>] [--section front,end,...]

Outputs machine-readable tasks derived from a specification Markdown file.
Default format is Newline Delimited JSON (NDJSON).
EOF
}

_task_parser_python() {
  local spec_file="$1"
  local output_format="$2"
  local section_filter="$3"

  python3 - "$spec_file" "$output_format" "$section_filter" <<'PYTHON'
import json
import os
import re
import sys
import hashlib
from collections import defaultdict

spec_path = sys.argv[1]
output_format = sys.argv[2]
section_filter = sys.argv[3]

if not os.path.exists(spec_path):
    print(f"ERROR: Spec file not found: {spec_path}", file=sys.stderr)
    sys.exit(1)

if output_format not in {"ndjson", "json"}:
    print(f"ERROR: Unsupported output format: {output_format}", file=sys.stderr)
    sys.exit(1)

SECTION_ALIASES = {
    "frontend": {"frontend", "ui", "user interface", "フロントエンド"},
    "backend": {"backend", "api", "server", "バックエンド"},
    "database": {"database", "db", "データベース"},
    "testing": {"testing", "qa", "quality", "テスト"},
    "documentation": {"documentation", "docs", "ドキュメント"},
    "security": {"security", "セキュリティ"},
}

ROLE_TO_AI = {
    "frontend": "cursor",
    "backend": "claude",
    "database": "claude",
    "testing": "qwen",
    "security": "gemini",
    "documentation": "amp",
    "compliance": "droid",
    "performance": "codex",
    "infra": "droid",
}

KEYWORD_GROUPS = {
    "frontend": ["ui", "ux", "component", "screen", "layout", "css", "html", "react", "vue", "tailwind", "accessibility", "aria", "design", "tooltip"],
    "backend": ["api", "endpoint", "controller", "service", "authentication", "authorization", "jwt", "session", "graphql", "rest", "queue", "worker", "business logic"],
    "database": ["database", "db", "schema", "migration", "table", "index", "query", "orm", "transaction", "normalization"],
    "testing": ["test", "testing", "unit", "integration", "e2e", "coverage", "mock", "fixture", "bats", "pytest", "boundary", "regression"],
    "security": ["security", "xss", "csrf", "cwe", "owasp", "encryption", "vulnerability", "threat", "validation", "sanitization"],
    "documentation": ["doc", "documentation", "readme", "guide", "tutorial", "api reference", "comment", "how-to"],
    "compliance": ["gdpr", "soc2", "hipaa", "audit", "retention", "policy", "governance", "compliance", "slo", "sla"],
    "performance": ["performance", "latency", "throughput", "optimization", "profiling", "benchmark", "cache", "load"],
    "infra": ["infra", "infrastructure", "deployment", "worktree", "pipeline", "ci", "cd", "observability", "monitoring", "logging"],
}

PRIORITY_RULES = [
    (re.compile(r"\b(p0|critical|blocker|must|必須)\b", re.IGNORECASE), "P0"),
    (re.compile(r"\b(p1|should|重要|high)\b", re.IGNORECASE), "P1"),
]

SECTION_FILTER = None
if section_filter:
    SECTION_FILTER = {s.strip().lower() for s in section_filter.split(',') if s.strip()}

with open(spec_path, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

def normalize_section(header: str) -> str:
    header = header.strip().lower()
    header = re.sub(r"[^a-z0-9ぁ-んァ-ヶ一-龯\s]", "", header)
    for canonical, aliases in SECTION_ALIASES.items():
        if header in aliases or any(alias in header for alias in aliases):
            return canonical
    return header.split()[0] if header else "general"

def slugify(text: str, default: str = "task") -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip('-')
    return slug or default

def first_sentence(text: str) -> str:
    for sep in ("。", ".", "!", "?", "\n"):
        if sep in text:
            return text.split(sep)[0].strip()
    return text.strip()

tasks = []
current_section = None
current_task = None
current_lines = []
current_start = None
line_iter = enumerate(lines, start=1)

def flush_task(end_line):
    global current_task, current_lines, current_start, current_section
    if current_task is None:
        return
    text = " ".join(current_lines).strip()
    if text:
        tasks.append({
            "section": current_section or "general",
            "text": text,
            "start": current_start,
            "end": end_line,
        })
    current_task = None
    current_lines = []
    current_start = None

for current_line, raw_line in line_iter:
    heading = re.match(r"^##\s+(.*)", raw_line)
    if heading:
        flush_task(current_line - 1)
        current_section = normalize_section(heading.group(1))
        continue

    if current_section is None:
        continue

    bullet = re.match(r"^\s*(?:[-*+]\s+|\d+\.\s+)(.+)", raw_line)
    if bullet:
        flush_task(current_line - 1)
        current_task = bullet.group(1).strip()
        current_lines = [current_task]
        current_start = current_line
        continue

    if current_task is not None:
        if raw_line.strip() == "":
            current_lines.append("")
        else:
            continuation = raw_line.strip()
            current_lines.append(continuation)

flush_task(len(lines))

if SECTION_FILTER is not None:
    tasks = [t for t in tasks if t["section"] in SECTION_FILTER]

section_counters = defaultdict(int)
result = []

def detect_keywords(text: str):
    lowered = text.lower()
    matched = set()
    for category, keywords in KEYWORD_GROUPS.items():
        for keyword in keywords:
            kw = keyword.lower()
            if " " in kw or "-" in kw:
                pattern = re.escape(kw)
            else:
                pattern = r"\b" + re.escape(kw) + r"\b"
            if re.search(pattern, lowered):
                matched.add(category)
                break
    return sorted(matched)

def recommend_role(section: str, keywords):
    scores = defaultdict(int)
    if section:
        scores[section] += 3
    for keyword in keywords:
        scores[keyword] += 2
    if not scores:
        return "backend"
    return max(scores, key=lambda k: scores[k])

def derive_priority(text: str):
    for regex, label in PRIORITY_RULES:
        if regex.search(text):
            return label
    word_count = len(text.split())
    if word_count > 80:
        return "P1"
    if word_count > 40:
        return "P2"
    return "P3"

def estimate_effort(text: str):
    word_count = len(text.split())
    if word_count > 120:
        return "large"
    if word_count > 60:
        return "medium"
    return "small"

for task in tasks:
    section = task["section"]
    section_counters[section] += 1
    text = task["text"].strip()
    task_index = section_counters[section]

    keywords = detect_keywords(text)
    primary_role = recommend_role(section, keywords)
    ai = ROLE_TO_AI.get(primary_role, ROLE_TO_AI.get(section, "claude"))

    title = first_sentence(text)
    if len(title) > 120:
        title = title[:117] + "..."

    task_id = f"{section}-{task_index:02d}"
    slug = slugify(title, default=task_id)

    priority = derive_priority(text)
    effort = estimate_effort(text)

    result.append({
        "id": task_id,
        "slug": slug,
        "section": section,
        "title": title,
        "description": text,
        "start_line": task["start"],
        "end_line": task["end"],
        "keywords": keywords,
        "primary_role": primary_role,
        "recommended_ai": ai,
        "priority": priority,
        "effort": effort,
        "source": os.path.abspath(spec_path),
        "content_hash": hashlib.sha1(text.encode("utf-8")).hexdigest(),
    })

if output_format == "ndjson":
    for item in result:
        print(json.dumps(item, ensure_ascii=False))
else:
    print(json.dumps(result, ensure_ascii=False, indent=2))
PYTHON
}

task_parser_parse() {
  local spec_file="$1"
  local format="${2:-ndjson}"
  local output_path="${3:-}" 
  local section_filter="${4:-}" 

  local tmp_output
  tmp_output="$(_task_parser_python "$spec_file" "$format" "$section_filter")"

  if [[ -n "$output_path" ]]; then
    printf '%s\n' "$tmp_output" >"$output_path"
  else
    printf '%s\n' "$tmp_output"
  fi
}

#---------------------------------------------------------------------
# CLIエントリーポイント
#---------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    _task_parser_usage
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
    parse)
      if [[ $# -lt 1 ]]; then
        _task_parser_usage
        exit 1
      fi
      spec_file="$1"; shift
      format="ndjson"
      output=""
      sections=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --format)
            format="$2"; shift 2;
            ;;
          --output)
            output="$2"; shift 2;
            ;;
          --section)
            sections="$2"; shift 2;
            ;;
          --help)
            _task_parser_usage
            exit 0
            ;;
          *)
            echo "ERROR: Unknown option $1" >&2
            _task_parser_usage
            exit 1
            ;;
        esac
      done
      task_parser_parse "$spec_file" "$format" "$output" "$sections"
      ;;
    --help|-h|help)
      _task_parser_usage
      ;;
    *)
      echo "ERROR: Unknown command: $command" >&2
      _task_parser_usage
      exit 1
      ;;
  esac
fi
