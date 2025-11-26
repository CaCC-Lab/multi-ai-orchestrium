#!/usr/bin/env bash
# task-router.sh - Markdown仕様書からタスクを抽出し、AIに割り当て、優先度を判定するライブラリ
# Phase 2-3-1: Task Router (Qwen実装、Droid品質基準)

set -euo pipefail

TASK_ROUTER_VERSION="1.0.0"

#---------------------------------------------------------------------
# 内部ヘルパー
#---------------------------------------------------------------------

_task_router_usage() {
  cat <<'EOF'
Usage: task-router.sh route <spec_file> <ai_profiles_file>

Parses a Markdown specification, extracts tasks, assigns AI agents, and determines priorities.
EOF
}

# Function to extract tasks from Markdown specification using Python
task_router_extract_tasks() {
  local spec_file="$1"
  
  python3 - "$spec_file" <<'PYTHON'
import json
import os
import re
import sys

spec_path = sys.argv[1]

if not os.path.exists(spec_path):
    print(f"ERROR: Spec file not found: {spec_path}", file=sys.stderr)
    sys.exit(1)

with open(spec_path, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

tasks = []
current_task = None
current_lines = []

for line_num, line in enumerate(lines, start=1):
    # Match task headings like "### Task: Task Name" or "### [Some other heading]"
    task_match = re.match(r'^#{2,3}\s+Task:\s*(.+)', line, re.IGNORECASE)
    
    if task_match:
        # Save previous task if exists
        if current_task:
            desc_text = " ".join(current_lines).strip()
            current_task["description"] = desc_text
            tasks.append(current_task)  # Add completed task to the list

        # Start new task
        task_name = task_match.group(1).strip()
        current_task = {
            "name": task_name,
            "line": line_num,
            "description": "",
            "keywords": [],
            "priority": "Medium",
            "ai_assignment": "unknown"
        }

        current_lines = []
        continue
    
    # Look for keywords in various formats including markdown: "- **Keywords**: [key1, key2, key3]" or "- **Keywords**: `[key1, key2, key3]`"
    keyword_match = re.search(r'(?:-\s*\*{2})?(?:Keywords|キーワード)(?:\*{2})?[:：]\s*`*\[([^\]]+)\]`*', line, re.IGNORECASE)
    if keyword_match and current_task:
        keywords_text = keyword_match.group(1)
        keywords = [k.strip().strip('"\'') for k in keywords_text.split(',')]
        current_task["keywords"] = [k for k in keywords if k]  # Remove empty strings
        continue  # Skip adding this line to description

    # Look for priority indicators
    if current_task:
        priority_match = re.search(r'(Priority|優先度)[:：]\s*(High|Medium|Low|High|Medium|Low|P0|P1|P2|P3|critical|should|blocker|must|重要|高|中|低|任意|できれば|nice to have)', line, re.IGNORECASE)
        if priority_match:
            priority_text = priority_match.group(2).lower()
            if priority_text in ['high', 'critical', 'blocker', 'must', '重要', '高', 'p0', 'p1']:
                current_task["priority"] = "High"
            elif priority_text in ['low', '任意', 'できれば', 'nice to have', '低']:
                current_task["priority"] = "Low"
            else:
                current_task["priority"] = "Medium"

        # Add line to current task description if we're in a task
        if line.strip() and not line.startswith('#'):
            current_lines.append(line.strip())

# Save the last task if exists
if current_task:
    desc_text = " ".join(current_lines).strip()
    current_task["description"] = desc_text
    tasks.append(current_task)  # Add completed task to the list

# If no tasks found with "Task:" format, try to find lists that might be tasks
if not tasks:
    current_lines = []
    for line in lines:
        # Match list items that might be tasks
        if re.match(r'^\s*[-*+]\s+', line) or re.match(r'^\s*\d+\.\s+', line):
            task_text = re.sub(r'^\s*[-*+]\s+|\d+\.\s+', '', line).strip()
            if len(task_text) > 10:  # Probably a task if it's more than 10 chars
                tasks.append({
                    "name": task_text[:60] + "..." if len(task_text) > 60 else task_text,
                    "description": task_text,
                    "keywords": [],
                    "priority": "Medium",
                    "ai_assignment": "unknown"
                })
        elif re.match(r'^#{2,4}\s+', line):  # Section headers
            continue
        else:
            continue

# If still no tasks, try to find any sections with descriptions that could be tasks
if not tasks:
    potential_task_sections = []
    current_section = None
    current_content = []
    
    for line in lines:
        header = re.match(r'^#{2,4}\s+(.+)', line)
        if header:
            if current_section and current_content:
                potential_task_sections.append({
                    "section": current_section,
                    "content": " ".join(current_content)
                })
            current_section = header.group(1).strip()
            current_content = []
        elif line.strip():
            current_content.append(line.strip())
    
    if current_section and current_content:
        potential_task_sections.append({
            "section": current_section,
            "content": " ".join(current_content)
        })
    
    # Create tasks from potential sections
    for section in potential_task_sections:
        tasks.append({
            "name": section["section"],
            "description": section["content"][:200] + "..." if len(section["content"]) > 200 else section["content"],
            "keywords": [],
            "priority": "Medium",
            "ai_assignment": "unknown"
        })

print(json.dumps(tasks, ensure_ascii=False, indent=2))
PYTHON
}

# Function to determine priority based on keywords
task_router_determine_priority() {
  local task_description="$1"
  local priority="Medium"
  
  # Check for high priority indicators
  if [[ "$task_description" =~ (high|critical|blocker|must|重要|高|p0|p1|緊急|必須) ]]; then
    priority="High"
  # Check for low priority indicators
  elif [[ "$task_description" =~ (low|任意|できれば|nice\ to\ have|低) ]]; then
    priority="Low"
  fi
  
  echo "$priority"
}

# Main routing function
task_router_route() {
  local spec_file="$1"
  local profiles_file="$2"

  # Extract tasks from the specification file
  local tasks_json
  tasks_json=$(task_router_extract_tasks "$spec_file")

  # Write the extracted tasks to a temporary file
  local temp_tasks=$(mktemp)
  echo "$tasks_json" > "$temp_tasks"

  # Process each task
  python3 - "$temp_tasks" "$profiles_file" <<'PYTHON'
import json
import sys
import subprocess
import os
import yaml
import re

tasks_file = sys.argv[1]
profiles_file = sys.argv[2]

# Read the tasks from the temporary file
with open(tasks_file, 'r', encoding='utf-8') as f:
    tasks = json.load(f)

# Define 42 keywords across categories for reference
keyword_categories = {
    "frontend": ["React", "Vue", "Angular", "JavaScript", "TypeScript", "HTML", "CSS", "UI", "UX"],
    "backend": ["Node.js", "Python", "Go", "Java", "PHP", "API", "REST", "GraphQL", "Microservices", "Serverless"],
    "database": ["SQL", "NoSQL", "PostgreSQL", "MySQL", "MongoDB"],
    "testing": ["UnitTest", "IntegrationTest", "E2ETest", "Jest", "Pytest", "CI/CD"],
    "documentation": ["Markdown", "Swagger", "OpenAPI", "JSDoc"],
    "security": ["Authentication", "Authorization", "XSS", "CSRF", "Encryption"],
    "general": ["Refactoring", "Performance", "Algorithm"]
}

# Function to calculate match score for a task against an AI profile
def calculate_score(task_keywords, agent_specializations, agent_strengths):
    score = 0

    # Convert to lowercase for comparison
    task_lower = " ".join(task_keywords).lower() if task_keywords else ""
    spec_lower = " ".join(agent_specializations).lower() if agent_specializations else ""
    strength_lower = " ".join(agent_strengths).lower() if agent_strengths else ""

    # Calculate score based on keyword matches
    for category, keywords in keyword_categories.items():
        for keyword in keywords:
            keyword_lower = keyword.lower()
            if keyword_lower in task_lower:
                # If the keyword matches specialization or relates to the category, give higher weight
                if keyword_lower in spec_lower or category in [s.lower() for s in agent_specializations]:
                    score += 3
                # If the keyword matches strengths, give medium weight
                elif keyword_lower in strength_lower:
                    score += 2
                # Basic match gives weight of 1
                else:
                    score += 1

    return score

# Load AI profiles from YAML file
with open(profiles_file, 'r', encoding='utf-8') as f:
    profiles_data = yaml.safe_load(f)

agents = profiles_data.get('agents', [])

# For each task, determine priority and assign an AI agent
for task in tasks:
    # Determine priority
    description = task.get("description", "")

    # Check for priority indicators in description
    priority = "Medium"
    desc_lower = description.lower()

    if any(keyword in desc_lower for keyword in ["high", "critical", "blocker", "must", "重要", "高", "p0", "p1", "緊急", "必須"]):
        priority = "High"
    elif any(keyword in desc_lower for keyword in ["low", "任意", "できれば", "nice to have", "低"]):
        priority = "Low"

    task["priority"] = priority

    # Prepare keywords for agent matching
    keywords = task.get("keywords", [])
    if not keywords:
        # If no explicit keywords, try to extract from the description
        # Look for common tech keywords in the description
        possible_keywords = []
        potential_kw = re.findall(r'\b([A-Z][a-z.]*[a-z]|\w+\.js|\w+/\w+)\b', description)
        keywords = [kw for kw in potential_kw if len(kw) > 2][:5]  # Top 5 potential keywords
        task["keywords"] = keywords

    # Find the best matching agent
    best_agent = None
    best_score = -1

    for agent in agents:
        agent_name = agent.get('name', '')
        agent_specializations = agent.get('specializations', [])
        agent_strengths = agent.get('strengths', [])

        score = calculate_score(keywords, agent_specializations, agent_strengths)

        if score > best_score:
            best_score = score
            best_agent = agent_name

    task["ai_assignment"] = best_agent if best_agent else "unknown"
    task["match_score"] = best_score

# Output the processed tasks
print(json.dumps(tasks, ensure_ascii=False, indent=2))

# Clean up the temporary tasks file
import os
os.unlink(sys.argv[1])
PYTHON
}

#---------------------------------------------------------------------
# CLIエントリーポイント
#---------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    _task_router_usage
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
    route)
      if [[ $# -lt 2 ]]; then
        _task_router_usage
        exit 1
      fi
      spec_file="$1"
      profiles_file="$2"
      task_router_route "$spec_file" "$profiles_file"
      ;;
    --help|-h|help)
      _task_router_usage
      ;;
    *)
      echo "ERROR: Unknown command: $command" >&2
      _task_router_usage
      exit 1
      ;;
  esac
fi