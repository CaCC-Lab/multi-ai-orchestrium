#!/usr/bin/env bash

# collaborative-review.sh - Multi-AI collaborative review aggregation library
# Phase 2-3-3: Consensus + Conflict Resolution (Qwen implementation, Droid QA baseline)

set -euo pipefail

CR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CR_PROJECT_ROOT="$(cd "$CR_LIB_DIR/../.." && pwd)"

CR_OUTPUT_ROOT="${COLLAB_REVIEW_ROOT:-$CR_PROJECT_ROOT/logs/collaborative-reviews}"
CR_TEMP_DIR="${COLLAB_REVIEW_TMP_DIR:-$CR_OUTPUT_ROOT/tmp}"
CR_DEFAULT_INPUT_DIR="${COLLAB_REVIEW_INPUT_DIR:-$CR_PROJECT_ROOT/logs}"

CR_TIMESTAMP_FORMAT="%Y%m%d-%H%M%S"

declare -A CR_TRUST_SCORES=(
  [claude]=0.92
  [gemini]=0.9
  [amp]=0.82
  [qwen]=0.88
  [droid]=0.95
  [codex]=0.87
  [cursor]=0.85
  [coderabbit]=0.8
  [default]=0.8
)

collaborative_review_timestamp() {
  date -u +"${CR_TIMESTAMP_FORMAT}"
}

collaborative_review_init_paths() {
  mkdir -p "$CR_OUTPUT_ROOT" "$CR_TEMP_DIR"
}

collaborative_review_usage() {
  cat <<'EOF'
Collaborative Review Aggregator

Usage:
  collaborative-review.sh run --spec <spec.md> [--inputs file1.json,file2.md]
                               [--output-dir path] [--label name]
  collaborative-review.sh normalize <review-file>
  collaborative-review.sh --help

Commands:
  run         Aggregate multiple AI review outputs into a unified report
  normalize   Convert a single review file into canonical JSON (debug helper)

Options:
  --spec <path>         Specification file associated with the review batch
  --inputs <list>       Comma-separated review files (JSON/Markdown). If omitted
                        scans logs/*-reviews/latest_*.json by default.
  --output-dir <path>   Destination directory for generated artifacts
  --label <name>        Custom label for output folders
  --format <json|md|all>  Additional output formats when using normalize
EOF
}

collaborative_review_log() {
  local level="$1"; shift
  local message="$1"; shift || true
  printf '[%s] [collab-review] %s\n' "$level" "$message" >&2
}

collaborative_review_trust_score() {
  local ai="$1"
  if [[ -n "${CR_TRUST_SCORES[$ai]:-}" ]]; then
    printf '%s' "${CR_TRUST_SCORES[$ai]}"
  else
    printf '%s' "${CR_TRUST_SCORES[default]}"
  fi
}

collaborative_review_require_markdown_parser() {
  if [[ -z "${CR_MARKDOWN_PARSER_LOADED:-}" ]]; then
    # shellcheck source=/dev/null
    source "$CR_LIB_DIR/markdown-parser.sh"
    CR_MARKDOWN_PARSER_LOADED=1
  fi
}

collaborative_review_resolve_default_inputs() {
  local -a files=()
  while IFS= read -r -d '' path; do
    files+=("$path")
  done < <(find "$CR_DEFAULT_INPUT_DIR" -maxdepth 2 -type l -name 'latest_*.json' -print0 2>/dev/null || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    while IFS= read -r -d '' path; do
      files+=("$path")
    done < <(find "$CR_DEFAULT_INPUT_DIR" -maxdepth 2 -type f -name '*-review.json' -print0 2>/dev/null || true)
  fi

  printf '%s\n' "${files[@]}"
}

collaborative_review_normalize_file() {
  local input_path="$1"
  local spec_hint="${2:-}"
  local tmp_json=""

  if [[ ! -f "$input_path" ]]; then
    collaborative_review_log "WARN" "Review file not found: $input_path"
    return 1
  fi

  local lower_ext="$(printf '%s' "$input_path" | awk -F'.' '{print tolower($NF)}')"
  local json_source="$input_path"

  if [[ "$lower_ext" == "md" ]]; then
    collaborative_review_require_markdown_parser
    tmp_json="$(mktemp "$CR_TEMP_DIR/review-md-XXXXXX.json")"
    parse_markdown_review "$input_path" "$tmp_json"
    json_source="$tmp_json"
  fi

  local trust_payload
  trust_payload=$(python3 - "$json_source" "$input_path" "$spec_hint" <<'PYTHON'
import json
import os
import sys
from datetime import datetime
from pathlib import Path
import re

json_path = Path(sys.argv[1])
original_path = Path(sys.argv[2])
spec_hint = sys.argv[3] if len(sys.argv) > 3 else ""

TRUST_MAP = {
    "claude": 0.92,
    "gemini": 0.90,
    "amp": 0.82,
    "qwen": 0.88,
    "droid": 0.95,
    "codex": 0.87,
    "cursor": 0.85,
    "coderabbit": 0.80,
    "default": 0.80,
}

PRIORITY_MAP = {
    "critical": 0,
    "p0": 0,
    "blocker": 0,
    "high": 1,
    "p1": 1,
    "medium": 2,
    "p2": 2,
    "low": 3,
    "p3": 3,
    "info": 3,
}

def clamp_priority(value):
    try:
        num = int(value)
        if num < 0:
            return 0
        if num > 3:
            return 3
        return num
    except Exception:
        text = str(value).strip().lower()
        return PRIORITY_MAP.get(text, 2)

def normalize_confidence(value):
    try:
        num = float(value)
        if num > 1.0:
            num = num / 100.0
        if num < 0:
            num = 0.0
        if num > 1:
            num = 1.0
        return round(num, 4)
    except Exception:
        return 0.8

def determine_ai(data, path):
    meta = data.get("metadata", {})
    for key in ("ai", "agent", "tool", "reviewer", "review_tool"):
        if isinstance(meta.get(key), str) and meta[key].strip():
            return meta[key].strip().lower()
    filename = path.name.lower()
    match = re.match(r"([a-z0-9]+)[-_]review", filename)
    if match:
        return match.group(1)
    if "claude" in filename:
        return "claude"
    if "gemini" in filename:
        return "gemini"
    if "qwen" in filename:
        return "qwen"
    if "droid" in filename:
        return "droid"
    if "codex" in filename:
        return "codex"
    if "cursor" in filename:
        return "cursor"
    if "coderabbit" in filename:
        return "coderabbit"
    return "unknown"

def determine_review_type(data, path):
    meta = data.get("metadata", {})
    for key in ("review_type", "type", "category", "profile"):
        value = meta.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip().lower()
    name = path.name.lower()
    if "security" in name:
        return "security"
    if "quality" in name:
        return "quality"
    if "review" in name:
        return "review"
    return "general"

def gather_findings(data):
    findings = []
    if isinstance(data.get("findings"), list) and data["findings"]:
        findings = data["findings"]
    elif isinstance(data.get("issues"), list) and data["issues"]:
        findings = data["issues"]
    elif isinstance(data.get("analysis"), list) and data["analysis"]:
        findings = data["analysis"]
    elif isinstance(data.get("entries"), list) and data["entries"]:
        findings = data["entries"]
    return findings

def normalize_location(raw):
    if not isinstance(raw, dict):
        return {}
    file_path = raw.get("absolute_file_path") or raw.get("file") or raw.get("path")
    if not file_path and isinstance(raw.get("relative_path"), str):
        file_path = raw["relative_path"]
    line_start = None
    line_end = None
    if isinstance(raw.get("line_range"), dict):
        line_start = raw["line_range"].get("start")
        line_end = raw["line_range"].get("end")
    else:
        line_start = raw.get("start_line") or raw.get("line" )
        line_end = raw.get("end_line") or line_start
    location = {}
    if file_path:
        location["file"] = file_path
    if line_start is not None:
        try:
            location["start"] = int(line_start)
        except Exception:
            pass
    if line_end is not None:
        try:
            location["end"] = int(line_end)
        except Exception:
            pass
    snippet = raw.get("snippet") or raw.get("code") or raw.get("excerpt")
    if snippet:
        location["snippet"] = snippet
    return location

def severity_to_label(priority):
    mapping = {0: "P0/Critical", 1: "P1/High", 2: "P2/Medium", 3: "P3/Low"}
    return mapping.get(priority, "P2/Medium")

with json_path.open("r", encoding="utf-8") as handle:
    payload = json.load(handle)

ai_id = determine_ai(payload, original_path)
review_type = determine_review_type(payload, original_path)
trust_score = TRUST_MAP.get(ai_id, TRUST_MAP["default"])

overall = payload.get("overall") or payload
overall_correctness = overall.get("overall_correctness") or overall.get("correctness") or overall.get("verdict")
overall_explanation = overall.get("overall_explanation") or overall.get("summary") or overall.get("explanation") or ""
overall_confidence = overall.get("overall_confidence_score") or overall.get("confidence_score") or overall.get("confidence")
overall_confidence = normalize_confidence(overall_confidence)

findings_raw = gather_findings(payload)
normalized_findings = []

for idx, finding in enumerate(findings_raw):
    if not isinstance(finding, dict):
        continue
    title = finding.get("title") or finding.get("heading") or finding.get("summary") or finding.get("name")
    body = finding.get("body") or finding.get("description") or finding.get("details") or ""
    priority_value = finding.get("priority") or finding.get("severity") or finding.get("level") or finding.get("impact")
    priority = clamp_priority(priority_value)
    confidence_value = finding.get("confidence_score") or finding.get("confidence") or overall_confidence
    confidence = normalize_confidence(confidence_value)
    weight = round(trust_score * (1.15 - 0.22 * priority), 5)
    if weight < 0:
        weight = round(trust_score * 0.5, 5)
    location = {}
    if finding.get("code_location"):
        location = normalize_location(finding["code_location"])
    elif finding.get("location"):
        location = normalize_location(finding["location"])
    security_meta = finding.get("security_metadata") or {}
    tags = []
    for key in ("category", "owasp_category", "cwe_id", "type"):
        value = security_meta.get(key) or finding.get(key)
        if isinstance(value, str) and value.strip():
            tags.append(value.strip())
    normalized_findings.append({
        "id": f"{ai_id}-f{idx+1}",
        "title": title or "Untitled Finding",
        "body": body,
        "priority": priority,
        "priority_label": severity_to_label(priority),
        "confidence": confidence,
        "weight": weight,
        "location": location,
        "tags": tags,
        "raw": finding,
    })

result = {
    "source_path": str(original_path),
    "source_basename": original_path.name,
    "spec_hint": spec_hint,
    "ai_id": ai_id,
    "review_type": review_type,
    "trust_score": trust_score,
    "generated_at": datetime.utcfromtimestamp(original_path.stat().st_mtime).isoformat() + "Z",
    "overall": {
        "correctness": overall_correctness or "unknown",
        "explanation": overall_explanation,
        "confidence": overall_confidence,
        "finding_count": len(normalized_findings),
    },
    "findings": normalized_findings,
}

print(json.dumps(result, ensure_ascii=False))
PYTHON
  )

  if [[ -n "$tmp_json" && -f "$tmp_json" ]]; then
    rm -f "$tmp_json"
  fi

  printf '%s\n' "$trust_payload"
}

collaborative_review_collect() {
  local output_json="$1"; shift
  local spec_hint="${1:-}"; shift || true
  local temp_file
  temp_file="$(mktemp "$CR_TEMP_DIR/normalized-XXXXXX.jsonl")"
  : >"$temp_file"

  local processed=0
  for review_path in "$@"; do
    if normalized=$(collaborative_review_normalize_file "$review_path" "$spec_hint" 2>/dev/null); then
      printf '%s\n' "$normalized" >>"$temp_file"
      ((processed++))
    fi
  done

  if [[ $processed -eq 0 ]]; then
    rm -f "$temp_file"
    return 1
  fi

  jq -s '.' "$temp_file" >"$output_json"
  rm -f "$temp_file"
}

collaborative_review_aggregate_json() {
  local normalized_json="$1"
  local output_json="$2"

  python3 - "$normalized_json" <<'PYTHON' >"$output_json"
import json
import math
import sys
from collections import defaultdict
from datetime import datetime
import hashlib

normalized_path = sys.argv[1]
with open(normalized_path, "r", encoding="utf-8") as handle:
    entries = json.load(handle)

total_reviews = len(entries)
total_findings = sum(len(item.get("findings", [])) for item in entries)
total_trust = sum(item.get("trust_score", 0.0) for item in entries)
if total_trust == 0:
    total_trust = 1.0

overall_correctness = defaultdict(float)
for entry in entries:
    correctness = entry.get("overall", {}).get("correctness", "unknown")
    overall_correctness[correctness] += entry.get("trust_score", 0.0)

group_map = defaultdict(list)

def build_key(finding):
    location = finding.get("location", {})
    file_path = location.get("file", "<global>")
    start = location.get("start", 0)
    end = location.get("end", start)
    basis = finding.get("title") or finding.get("body") or "untitled"
    norm = " ".join(basis.lower().split())
    digest = hashlib.sha1(norm.encode("utf-8")).hexdigest()[:12]
    return f"{file_path}:{start}:{end}:{digest}"

for entry in entries:
    for finding in entry.get("findings", []):
        key = build_key(finding)
        payload = {
            "ai_id": entry.get("ai_id", "unknown"),
            "review_type": entry.get("review_type", "general"),
            "priority": finding.get("priority", 2),
            "priority_label": finding.get("priority_label", "P2/Medium"),
            "weight": finding.get("weight", entry.get("trust_score", 0.8)),
            "confidence": finding.get("confidence", 0.8),
            "location": finding.get("location", {}),
            "title": finding.get("title", "Untitled Finding"),
            "body": finding.get("body", ""),
            "tags": finding.get("tags", []),
        }
        group_map[key].append(payload)

consensus_list = []
unique_list = []
conflict_list = []

for key, items in group_map.items():
    support = len(items)
    weights = [item["weight"] for item in items]
    weight_sum = sum(weights)
    min_priority = min(item["priority"] for item in items)
    max_priority = max(item["priority"] for item in items)
    support_ratio = support / total_reviews if total_reviews else 0.0
    weighted_priority = sum(item["priority"] * item["weight"] for item in items) / (weight_sum or 1)
    weighted_confidence = sum(item["confidence"] * item["weight"] for item in items) / (weight_sum or 1)

    exemplar = items[0]
    aggregate_entry = {
        "key": key,
        "title": exemplar["title"],
        "summary": exemplar["body"],
        "location": exemplar.get("location", {}),
        "support": support,
        "support_ratio": round(support_ratio, 3),
        "weighted_priority": round(weighted_priority, 3),
        "priority_label": exemplar["priority_label"],
        "weighted_confidence": round(min(1.0, max(0.0, weighted_confidence)), 3),
        "contributors": [
            {
                "ai_id": item["ai_id"],
                "priority": item["priority"],
                "priority_label": item["priority_label"],
                "weight": round(item["weight"], 3),
                "confidence": round(item["confidence"], 3),
                "review_type": item["review_type"],
            }
            for item in items
        ],
        "tags": sorted({tag for item in items for tag in item.get("tags", []) if tag}),
    }

    if support >= 2 and max_priority - min_priority >= 2:
        resolution = sorted(items, key=lambda value: (value["priority"], -value["weight"]))[0]
        aggregate_entry["resolution"] = {
            "ai_id": resolution["ai_id"],
            "priority": resolution["priority"],
            "priority_label": resolution["priority_label"],
            "confidence": round(resolution["confidence"], 3),
            "weight": round(resolution["weight"], 3),
        }
        conflict_list.append(aggregate_entry)
    elif support >= 2:
        consensus_list.append(aggregate_entry)
    else:
        unique_list.append(aggregate_entry)

consensus_list.sort(key=lambda item: (item["weighted_priority"], -item["support_ratio"]))
unique_list.sort(key=lambda item: (item["weighted_priority"], -item["weighted_confidence"]))
conflict_list.sort(key=lambda item: item["weighted_priority"])

overall_summary = {
    "generated_at": datetime.utcnow().isoformat() + "Z",
    "total_reviews": total_reviews,
    "total_findings": total_findings,
    "consensus_count": len(consensus_list),
    "unique_count": len(unique_list),
    "conflict_count": len(conflict_list),
    "trust_total": round(total_trust, 3),
    "correctness_breakdown": {
        key: round(value, 3) for key, value in overall_correctness.items()
    },
}

def build_markdown(summary, consensus, conflicts, unique):
    lines = []
    lines.append("# Collaborative Review Report")
    lines.append("")
    lines.append(f"- Generated: {summary['generated_at']}")
    lines.append(f"- Reviews processed: {summary['total_reviews']}")
    lines.append(f"- Findings analysed: {summary['total_findings']}")
    lines.append(f"- Consensus findings: {summary['consensus_count']}")
    lines.append(f"- Conflicts detected: {summary['conflict_count']}")
    correctness = summary.get('correctness_breakdown', {})
    if correctness:
        lines.append("- Overall correctness weighting: " + ", ".join(f"{label}={weight:.2f}" for label, weight in correctness.items()))
    lines.append("")

    if consensus:
        lines.append("## High Consensus Findings")
        lines.append("")
        lines.append("| Priority | Finding | Support | Confidence | Contributing AIs |")
        lines.append("| --- | --- | --- | --- | --- |")
        for item in consensus:
            contributors = ", ".join(f"{c['ai_id']} (P{c['priority']})" for c in item['contributors'])
            lines.append(f"| {item['priority_label']} | {item['title']} | {item['support']} ({item['support_ratio']:.2f}) | {item['weighted_confidence']:.2f} | {contributors} |")
        lines.append("")

    if conflicts:
        lines.append("## Conflicting Recommendations")
        lines.append("")
        for item in conflicts:
            lines.append(f"### {item['title']}")
            lines.append("")
            lines.append(f"- Location: {item['location'].get('file', '<global>')}:{item['location'].get('start', 0)}")
            lines.append("- Contributors:")
            for contributor in item['contributors']:
                lines.append(f"  - {contributor['ai_id']} → {contributor['priority_label']} (confidence {contributor['confidence']:.2f}, weight {contributor['weight']:.2f})")
            resolution = item.get('resolution')
            if resolution:
                lines.append(f"- Recommended resolution: adopt {resolution['ai_id']}'s assessment ({resolution['priority_label']}, confidence {resolution['confidence']:.2f})")
            lines.append("")

    if unique:
        lines.append("## Unique Findings")
        lines.append("")
        for item in unique[:15]:
            contributor = item['contributors'][0]
            lines.append(f"- **{item['title']}** (reported by {contributor['ai_id']} as {contributor['priority_label']}, confidence {item['weighted_confidence']:.2f})")
        if len(unique) > 15:
            lines.append("")
            lines.append(f"_(+{len(unique)-15} more unique findings omitted for brevity)_")

    lines.append("")
    lines.append("## Next Steps")
    lines.append("1. Address high consensus findings in order of severity.")
    if conflicts:
        lines.append("2. Review conflicts with designated owners to confirm resolution.")
        lines.append("3. Escalate any unresolved P0/P1 conflicts to human reviewer.")
    else:
        lines.append("2. No blocking conflicts detected. Proceed with remediation plan.")
    lines.append("3. Re-run collaborative review after fixes to validate improvements.")

    return "\n".join(lines)

report_markdown = build_markdown(overall_summary, consensus_list, conflict_list, unique_list)

result = {
    "summary": overall_summary,
    "consensus_findings": consensus_list,
    "conflicts": conflict_list,
    "unique_findings": unique_list,
    "report_markdown": report_markdown,
}

print(json.dumps(result, ensure_ascii=False))
PYTHON
}

collaborative_review_run() {
  local spec_path=""
  local inputs_arg=""
  local output_dir=""
  local label=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --spec)
        spec_path="$2"; shift 2 ;;
      --inputs)
        inputs_arg="$2"; shift 2 ;;
      --output-dir)
        output_dir="$2"; shift 2 ;;
      --label)
        label="$2"; shift 2 ;;
      --help|-h)
        collaborative_review_usage
        return 0 ;;
      *)
        collaborative_review_log "WARN" "Unknown option: $1"
        return 1 ;;
    esac
  done

  if [[ -z "$spec_path" ]]; then
    collaborative_review_log "ERROR" "--spec is required"
    return 1
  fi

  if [[ ! -f "$spec_path" ]]; then
    collaborative_review_log "ERROR" "Specification not found: $spec_path"
    return 1
  fi

  local -a review_inputs=()
  if [[ -n "$inputs_arg" ]]; then
    IFS=',' read -r -a review_inputs <<<"$inputs_arg"
  else
    mapfile -t review_inputs < <(collaborative_review_resolve_default_inputs)
  fi

  if [[ ${#review_inputs[@]} -eq 0 ]]; then
    collaborative_review_log "ERROR" "No review files provided or discovered"
    return 1
  fi

  collaborative_review_log "INFO" "Processing ${#review_inputs[@]} review artifacts"

  local timestamp
  timestamp="$(collaborative_review_timestamp)"
  local spec_label
  spec_label="$(basename "$spec_path" | sed 's/[^A-Za-z0-9_-]/-/g')"
  local folder_label="$timestamp-${label:-$spec_label}"
  local target_dir="${output_dir:-$CR_OUTPUT_ROOT}/$folder_label"
  mkdir -p "$target_dir"

  local normalized_json="$target_dir/normalized.json"
  if ! collaborative_review_collect "$normalized_json" "$spec_path" "${review_inputs[@]}"; then
    collaborative_review_log "ERROR" "Failed to normalize review inputs"
    return 1
  fi

  local aggregate_json="$target_dir/summary.json"
  collaborative_review_aggregate_json "$normalized_json" "$aggregate_json"

  local markdown_report="$target_dir/report.md"
  jq -r '.report_markdown' "$aggregate_json" >"$markdown_report"

  collaborative_review_log "INFO" "Unified report generated at $markdown_report"
  printf '%s\n' "$markdown_report"
}

collaborative_review_normalize_cli() {
  local review_file=""
  local format="json"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        format="$2"; shift 2 ;;
      --help|-h)
        collaborative_review_usage
        return 0 ;;
      *)
        review_file="$1"; shift ;;
    esac
  done

  if [[ -z "$review_file" ]]; then
    collaborative_review_log "ERROR" "normalize command requires a review file"
    return 1
  fi

  local normalized
  normalized=$(collaborative_review_normalize_file "$review_file") || return 1

  case "$format" in
    json)
      printf '%s\n' "$normalized" ;;
    md|markdown)
      local tmp="$(mktemp "$CR_TEMP_DIR/normalize-XXXXXX.json")"
      printf '%s\n' "$normalized" >"$tmp"
      collaborative_review_aggregate_json "$tmp" "$tmp.summary"
      jq -r '.report_markdown' "$tmp.summary"
      rm -f "$tmp" "$tmp.summary" ;;
    all)
      printf '%s\n' "$normalized"
      local tmp="$(mktemp "$CR_TEMP_DIR/normalize-XXXXXX.json")"
      printf '%s\n' "$normalized" >"$tmp"
      collaborative_review_aggregate_json "$tmp" "$tmp.summary"
      printf '\n---\n\n'
      jq -r '.report_markdown' "$tmp.summary"
      rm -f "$tmp" "$tmp.summary" ;;
    *)
      collaborative_review_log "WARN" "Unknown format: $format"
      printf '%s\n' "$normalized" ;;
  esac
}

collaborative_review_main() {
  collaborative_review_init_paths

  if [[ $# -eq 0 ]]; then
    collaborative_review_usage
    return 0
  fi

  local command="$1"; shift || true
  case "$command" in
    run)
      collaborative_review_run "$@" ;;
    normalize)
      collaborative_review_normalize_cli "$@" ;;
    --help|-h|help)
      collaborative_review_usage ;;
    *)
      collaborative_review_log "ERROR" "Unknown command: $command"
      collaborative_review_usage
      return 1 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  collaborative_review_main "$@"
fi