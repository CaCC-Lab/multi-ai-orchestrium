#!/usr/bin/env bash
# agent-matcher.sh - AIエージェントとタスクを照合するライブラリ
# Phase 2-3-1 Task 3-5 (Qwen実装、Droid品質基準)

set -euo pipefail

AGENT_MATCHER_VERSION="2.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_PROFILES_FILE="${PROJECT_ROOT}/config/ai-profiles.yaml"

#---------------------------------------------------------------------
# ヘルプ / CLI
#---------------------------------------------------------------------

_agent_matcher_usage() {
  cat <<'EOF'
Usage:
  agent-matcher.sh match [OPTIONS]

Options:
  --description <text>        Task description or summary text
  --keywords <comma list>     Comma-separated keywords (optional)
  --category <name>           Category hint (Frontend, Backend, ...)
  --profiles <path>           Path to ai-profiles.yaml (default: config/ai-profiles.yaml)
  --top <n>                   Return top N matches (default: 1)
  --format <json|ndjson|text> Output format (default: json)
  --include-task              Include task metadata in JSON output
  --help                      Show this help and exit

Examples:
  agent-matcher.sh match --description "Implement login API" --keywords "Authentication,API"
  agent-matcher.sh match --description "Create design spec" --format text

Exit codes:
  0 on success, non-zero on failure.
EOF
}

#---------------------------------------------------------------------
# 内部処理
#---------------------------------------------------------------------

_agent_matcher_python() {
  local profiles_path="$1"
  local top_n="$2"
  local output_format="$3"
  local include_task="$4"
  local description_b64="$5"
  local keywords_b64="$6"
  local category_hint="$7"

  python3 - "$profiles_path" "$top_n" "$output_format" "$include_task" "$description_b64" "$keywords_b64" "$category_hint" <<'PYTHON'
import base64
import json
import os
import re
import sys
from typing import Dict, List, Tuple

try:
    import yaml  # type: ignore
except ImportError as exc:  # pragma: no cover
    print(f"ERROR: PyYAML is required but not installed: {exc}", file=sys.stderr)
    sys.exit(2)

profiles_path, top_n, output_format, include_task, description_b64, keywords_b64, category_hint = sys.argv[1:8]

try:
    top_n_int = max(1, int(top_n))
except ValueError:
    print(f"ERROR: Invalid top value: {top_n}", file=sys.stderr)
    sys.exit(2)

def decode_b64(value: str) -> str:
    if not value:
        return ""
    padding = '=' * (-len(value) % 4)
    raw = value + padding
    return base64.b64decode(raw.encode('utf-8')).decode('utf-8')

description = decode_b64(description_b64)
keywords_raw = decode_b64(keywords_b64)

explicit_keywords = [
    kw.strip()
    for chunk in re.split(r"[\n,;|]", keywords_raw)
    for kw in [chunk]
    if kw.strip()
]

category_hint = category_hint.strip()

KEYWORD_CATEGORIES: Dict[str, List[str]] = {
    "Frontend": ["React", "Vue", "Angular", "JavaScript", "TypeScript", "HTML", "CSS", "UI", "UX"],
    "Backend": ["Node.js", "Python", "Go", "Java", "PHP", "API", "REST", "GraphQL", "Microservices", "Serverless"],
    "Database": ["SQL", "NoSQL", "PostgreSQL", "MySQL", "MongoDB"],
    "Testing": ["UnitTest", "IntegrationTest", "E2E Test", "Jest", "Pytest", "CI/CD"],
    "Documentation": ["Markdown", "Swagger", "OpenAPI", "JSDoc"],
    "Security": ["Authentication", "Authorization", "XSS", "CSRF", "Encryption"],
    "General": ["Refactoring", "Performance", "Algorithm"],
}

KEYWORD_LOOKUP: Dict[str, str] = {}
for category, words in KEYWORD_CATEGORIES.items():
    for word in words:
        KEYWORD_LOOKUP[word.lower()] = category

def normalize_words(text: str) -> Tuple[str, str]:
    lowered = text.lower()
    stripped = re.sub(r"[^a-z0-9]+", " ", lowered)
    collapsed = re.sub(r"\s+", " ", stripped).strip()
    squeezed = re.sub(r"[^a-z0-9]+", "", lowered)
    return collapsed, squeezed

def keyword_matches(text_collapsed: str, text_squeezed: str, keyword: str) -> bool:
    kw_lower = keyword.lower()
    kw_collapsed, kw_squeezed = normalize_words(keyword)
    if not kw_collapsed and not kw_squeezed:
        return False
    if kw_collapsed and f" {kw_collapsed} " in f" {text_collapsed} ":
        return True
    if kw_squeezed and kw_squeezed in text_squeezed:
        return True
    return False

def analyze_task(description: str, explicit_keywords: List[str]):
    combined = " ".join(filter(None, [description] + explicit_keywords))
    collapsed, squeezed = normalize_words(combined)
    matches: List[Dict[str, str]] = []
    categories = set()

    seen = set()
    for keyword, category in KEYWORD_LOOKUP.items():
        if keyword in seen:
            continue
        if keyword_matches(collapsed, squeezed, keyword):
            matches.append({"keyword": keyword, "category": category})
            categories.add(category)
            seen.add(keyword)

    for kw in explicit_keywords:
        normalized = kw.strip().lower()
        if not normalized:
            continue
        catalogue_category = KEYWORD_LOOKUP.get(normalized)
        matches.append({
            "keyword": normalized,
            "category": catalogue_category or "Explicit",
            "source": "explicit",
        })
        if catalogue_category:
            categories.add(catalogue_category)

    return matches, sorted(categories)

def load_profiles(path: str) -> List[dict]:
    if not os.path.exists(path):
        print(f"ERROR: AI profiles file not found: {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    agents = data.get("agents")
    if not isinstance(agents, list) or not agents:
        print(f"ERROR: No agents defined in {path}", file=sys.stderr)
        sys.exit(1)
    return agents

TASK_MATCHES, TASK_CATEGORIES = analyze_task(description, explicit_keywords)

AGENTS = load_profiles(profiles_path)

def score_agent(agent: dict) -> Tuple[int, dict]:
    agent_id = agent.get("id") or re.sub(r"[^a-z0-9]+", "-", agent.get("name", "").lower()).strip("-")
    name = agent.get("name", agent_id)
    specializations = [s.lower() for s in agent.get("specializations", [])]
    strengths = [s.lower() for s in agent.get("strengths", [])]

    weights = agent.get("weights", {})
    base_weight = int(weights.get("base", 1))
    specialization_weight = int(weights.get("specialization", 3))
    strength_weight = int(weights.get("strength", 2))
    category_bonus = int(weights.get("category_bonus", 2))
    hint_bonus = int(weights.get("hint_bonus", 2))

    score = 0
    detail_matches: List[dict] = []
    categories_hit = set()
    strengths_hit = set()

    for match in TASK_MATCHES:
        keyword = match.get("keyword", "")
        category = (match.get("category") or "").lower()
        increment = base_weight
        specialization_hit = False
        strength_hit = False

        if category and any(category == spec.lower() for spec in specializations):
            increment += specialization_weight
            specialization_hit = True
            categories_hit.add(category)

        if keyword and any(keyword == strength for strength in strengths):
            increment += strength_weight
            strength_hit = True
            strengths_hit.add(keyword)

        if category and category in {c.lower() for c in TASK_CATEGORIES}:
            increment += category_bonus

        detail_matches.append({
            "keyword": keyword,
            "category": category or "",
            "increment": increment,
            "specialization_hit": specialization_hit,
            "strength_hit": strength_hit,
        })

        score += increment

    if category_hint:
        hint_lower = category_hint.lower()
        if any(hint_lower == spec for spec in specializations):
            score += hint_bonus

    return score, {
        "agent_id": agent_id,
        "agent_name": name,
        "score": score,
        "specializations": agent.get("specializations", []),
        "strengths": agent.get("strengths", []),
        "file_creation_capability": bool(agent.get("file_creation_capability", False)),
        "description": agent.get("description", ""),
        "matches": detail_matches,
        "categories_hit": sorted({c.title() for c in categories_hit}),
        "strengths_hit": sorted(strengths_hit),
    }

match_results = []
for agent in AGENTS:
    score, payload = score_agent(agent)
    payload["score"] = score
    match_results.append(payload)

match_results.sort(key=lambda item: (-item["score"], item["agent_name"]))

top_matches = match_results[:top_n_int]
best_match = top_matches[0] if top_matches else None

task_payload = {
    "description": description,
    "category_hint": category_hint or None,
    "keywords": explicit_keywords,
    "detected_keywords": TASK_MATCHES,
    "detected_categories": TASK_CATEGORIES,
}

if output_format == "text":
    if best_match:
        print(best_match["agent_id"])
    else:
        print("unknown")
    sys.exit(0)

if output_format == "ndjson":
    for item in top_matches:
        record = {
            "agent_id": item["agent_id"],
            "agent_name": item["agent_name"],
            "score": item["score"],
            "matches": item["matches"],
            "categories_hit": item["categories_hit"],
            "strengths_hit": item["strengths_hit"],
        }
        if include_task == "true":
            record["task"] = task_payload
        print(json.dumps(record, ensure_ascii=False))
    sys.exit(0)

output = {
    "best_match": best_match,
    "matches": top_matches,
}
if include_task == "true":
    output["task"] = task_payload

print(json.dumps(output, ensure_ascii=False, indent=2))
PYTHON
}

agent_matcher_match() {
  local description=""
  local keywords=""
  local category=""
  local profiles="$DEFAULT_PROFILES_FILE"
  local top="1"
  local format="json"
  local include_task="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --description)
        shift
        description="${1:-}"
        ;;
      --keywords)
        shift
        keywords="${1:-}"
        ;;
      --category)
        shift
        category="${1:-}"
        ;;
      --profiles)
        shift
        profiles="${1:-}"
        ;;
      --top)
        shift
        top="${1:-1}"
        ;;
      --format)
        shift
        format="${1:-json}"
        ;;
      --include-task)
        include_task="true"
        ;;
      --help)
        _agent_matcher_usage
        return 0
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        _agent_matcher_usage >&2
        return 1
        ;;
    esac
    shift || true
  done

  if [[ -z "$description" && -z "$keywords" ]]; then
    echo "ERROR: Provide --description and/or --keywords" >&2
    return 1
  fi

  if [[ ! -f "$profiles" ]]; then
    echo "ERROR: AI profiles file not found: $profiles" >&2
    return 1
  fi

  local description_b64 keywords_b64
  description_b64="$(printf '%s' "$description" | base64 | tr -d '\n')"
  keywords_b64="$(printf '%s' "$keywords" | base64 | tr -d '\n')"

  _agent_matcher_python "$profiles" "$top" "$format" "$include_task" "$description_b64" "$keywords_b64" "$category"
}

#---------------------------------------------------------------------
# 公開関数
#---------------------------------------------------------------------

agent_matcher_best_agent() {
  local description="$1"
  local keywords="${2:-}"
  local category="${3:-}"
  local profiles="${4:-$DEFAULT_PROFILES_FILE}"

  agent_matcher_match --description "$description" --keywords "$keywords" --category "$category" --profiles "$profiles" --format text
}

#---------------------------------------------------------------------
# CLIエントリーポイント
#---------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    _agent_matcher_usage
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
    match)
      agent_matcher_match "$@"
      ;;
    --help|-h|help)
      _agent_matcher_usage
      ;;
    --version)
      echo "agent-matcher.sh v${AGENT_MATCHER_VERSION}"
      ;;
    *)
      echo "ERROR: Unknown command: $command" >&2
      _agent_matcher_usage >&2
      exit 1
      ;;
  esac
fi