#!/bin/bash
# JSON IR to YAML Converter for AsyncThink Integration
# Version: 1.0
# Phase 1 週5-6: YAML動的生成機構
# 担当: Qwen + Claude

set -euo pipefail

# ============================================================================
# グローバル変数
# ============================================================================

IR_TO_YAML_VERSION="1.0"

# ============================================================================
# ユーティリティ関数
# ============================================================================

# ロギング関数
log_ir_to_yaml() {
    local level="$1"
    local message="$2"
    local metadata="${3:-{}}"

    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [ir-to-yaml] [$level] $message | metadata=$metadata" >&2
}

# ============================================================================
# JSON IR → YAML 変換
# ============================================================================

# JSON IRファイルをYAML形式に変換
convert_ir_to_yaml() {
    local ir_file="$1"
    local output_yaml="${2:-/tmp/generated-workflow.yaml}"

    log_ir_to_yaml "INFO" "Converting JSON IR to YAML" "{\"ir_file\": \"$ir_file\", \"output\": \"$output_yaml\"}"

    # jqで必要
    if ! command -v jq &> /dev/null; then
        log_ir_to_yaml "ERROR" "jq command not found" "{}"
        return 1
    fi

    # JSON IRを読み込み
    if [[ ! -f "$ir_file" ]]; then
        log_ir_to_yaml "ERROR" "IR file not found" "{\"file\": \"$ir_file\"}"
        return 1
    fi

    local ir_content
    ir_content=$(cat "$ir_file")

    # IR versionを検証
    local ir_version
    ir_version=$(echo "$ir_content" | jq -r '.version')

    if [[ "$ir_version" != "1.0" ]]; then
        log_ir_to_yaml "ERROR" "Unsupported IR version" "{\"version\": \"$ir_version\"}"
        return 1
    fi

    # YAMLヘッダーを生成
    generate_yaml_header "$ir_content" > "$output_yaml"

    # Fork-Join操作をYAMLに変換
    generate_fork_join_operations "$ir_content" >> "$output_yaml"

    log_ir_to_yaml "INFO" "YAML generated successfully" "{\"output\": \"$output_yaml\"}"
}

# YAMLヘッダーを生成
generate_yaml_header() {
    local ir_content="$1"

    local workflow_id organizer
    workflow_id=$(echo "$ir_content" | jq -r '.workflow_id')
    organizer=$(echo "$ir_content" | jq -r '.organizer // "claude"')

    cat <<EOF
# Generated YAML Workflow from JSON IR
# Workflow ID: $workflow_id
# Organizer: $organizer
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

version: "4.0"
profiles:
  ${workflow_id}:
    name: "Auto-generated workflow - $workflow_id"
    description: "Dynamically generated from JSON IR"
    workflows:
      ${workflow_id}:
        phases:
          - name: "Dynamic Fork-Join Execution"
            fork_join_enabled: true
            organizer: $organizer
EOF
}

# Fork-Join操作をYAML形式で生成
generate_fork_join_operations() {
    local ir_content="$1"

    # Agent Pool設定
    local capacity
    capacity=$(echo "$ir_content" | jq -r '.agent_pool.capacity // 4')

    echo "            agent_pool:"
    echo "              capacity: $capacity"

    # Workers配列
    echo "              workers:"
    echo "$ir_content" | jq -r '.agent_pool.workers[]?' | while read -r worker; do
        echo "                - $worker"
    done

    echo ""
    echo "            fork_join_operations:"

    # ノードをトポロジカルソート順に処理
    local nodes
    nodes=$(echo "$ir_content" | jq -c '.task_graph.nodes[]')

    while IFS= read -r node; do
        local node_type
        node_type=$(echo "$node" | jq -r '.type')

        case "$node_type" in
            "fork")
                generate_fork_node_yaml "$node"
                ;;
            "join")
                generate_join_node_yaml "$node"
                ;;
            "think")
                generate_think_node_yaml "$node"
                ;;
            "answer")
                generate_answer_node_yaml "$node"
                ;;
            *)
                log_ir_to_yaml "WARN" "Unknown node type" "{\"type\": \"$node_type\"}"
                ;;
        esac
    done <<< "$nodes"
}

# FORKノードをYAMLに変換
generate_fork_node_yaml() {
    local node="$1"

    local id worker task timeout blocking role depends_on
    id=$(echo "$node" | jq -r '.id' | sed 's/fork-//')
    worker=$(echo "$node" | jq -r '.worker')
    task=$(echo "$node" | jq -r '.task')
    timeout=$(echo "$node" | jq -r '.timeout // 300')
    blocking=$(echo "$node" | jq -r '.blocking // false')
    role=$(echo "$node" | jq -r '.role // "default"')
    depends_on=$(echo "$node" | jq -r '.depends_on[]?' 2>/dev/null)

    cat <<EOF
              - fork:
                  id: $id
                  worker: $worker
                  role: $role
                  task: "$task"
                  timeout: $timeout
                  blocking: $blocking
EOF

    if [[ -n "$depends_on" ]]; then
        echo "                  depends_on:"
        echo "$depends_on" | while read -r dep; do
            echo "                    - $dep"
        done
    fi
}

# JOINノードをYAMLに変換
generate_join_node_yaml() {
    local node="$1"

    local id blocking
    id=$(echo "$node" | jq -r '.id' | sed 's/join-//')
    blocking=$(echo "$node" | jq -r '.blocking // true')

    cat <<EOF
              - join:
                  id: $id
                  blocking: $blocking
EOF
}

# THINKノードをYAMLに変換（Phase 3機能）
generate_think_node_yaml() {
    local node="$1"

    local content
    content=$(echo "$node" | jq -r '.content // "Organizer thinking"')

    cat <<EOF
              - think:
                  content: "$content"
EOF
}

# ANSWERノードをYAMLに変換（Phase 3機能）
generate_answer_node_yaml() {
    local node="$1"

    local result quality_score
    result=$(echo "$node" | jq -r '.result // "Workflow completed"')
    quality_score=$(echo "$node" | jq -r '.quality_score // 1.0')

    cat <<EOF
              - answer:
                  result: "$result"
                  quality_score: $quality_score
EOF
}

# ============================================================================
# Organizer AI プロンプト設計
# ============================================================================

# Organizerプロンプトを生成
generate_organizer_prompt() {
    local goal="$1"
    local available_workers="$2"  # カンマ区切り: "qwen,droid,codex,cursor"
    local constraints="${3:-max_parallel:4,total_timeout:1800}"

    log_ir_to_yaml "INFO" "Generating Organizer prompt" "{\"goal\": \"$goal\"}"

    cat <<EOF
# Organizer AI Prompt for AsyncThink Integration

## Role
You are an Organizer AI responsible for planning and structuring a multi-AI workflow using the Fork-Join paradigm.

## Goal
$goal

## Available Workers
$(echo "$available_workers" | tr ',' '\n' | sed 's/^/- /')

## Constraints
$(echo "$constraints" | tr ',' '\n' | sed 's/:/: /g' | sed 's/^/- /')

## Task
Generate a JSON Intermediate Representation (JSON IR) following this schema:

\`\`\`json
{
  "version": "1.0",
  "workflow_id": "organizer-generated-workflow",
  "organizer": "claude",
  "task_graph": {
    "nodes": [
      {
        "id": "fork-1",
        "type": "fork",
        "worker": "qwen",
        "task": "Describe the task for Worker",
        "timeout": 300,
        "blocking": false,
        "role": "fast-prototype"
      },
      {
        "id": "join-1",
        "type": "join",
        "blocking": true
      }
    ],
    "edges": [
      {"from": "fork-1", "to": "join-1", "weight": 300}
    ]
  },
  "agent_pool": {
    "capacity": 4,
    "workers": $(echo "$available_workers" | jq -R 'split(",")'),
    "allocation_policy": "dynamic"
  }
}
\`\`\`

## Instructions

1. **Analyze the goal** and decompose it into subtasks suitable for parallel execution.
2. **Plan Fork-Join operations**:
   - Use \`<FORK-i>\` to assign subtasks to Workers in parallel.
   - Use \`<JOIN-i>\` to synchronize Worker results.
   - Consider Critical-Path latency: place fast Workers early, minimize blocking JOINs.
3. **Optimize for latency**:
   - Non-blocking JOINs (\`blocking: false\`) allow Organizer to proceed before all Workers finish.
   - Chain dependencies using \`depends_on\` field.
4. **Generate valid JSON IR** conforming to the schema above.

## Output
Return ONLY the JSON IR, no additional text.
EOF
}

# OrganizerにJSON IRを生成させる
invoke_organizer_ai() {
    local goal="$1"
    local available_workers="${2:-qwen,droid,codex,cursor}"
    local organizer_ai="${3:-claude}"
    local output_ir="${4:-/tmp/organizer-generated-ir.json}"

    log_ir_to_yaml "INFO" "Invoking Organizer AI" "{\"organizer\": \"$organizer_ai\", \"goal\": \"$goal\"}"

    # Organizerプロンプトを生成
    local prompt
    prompt=$(generate_organizer_prompt "$goal" "$available_workers")

    # Organizer AIを呼び出し（実際のAI統合は週5-6で実装）
    # ここではダミーJSON IRを生成
    log_ir_to_yaml "WARN" "Using dummy JSON IR (actual Organizer invocation in week 5-6)" "{}"

    cat > "$output_ir" <<'EOF'
{
  "version": "1.0",
  "workflow_id": "organizer-generated-workflow",
  "organizer": "claude",
  "task_graph": {
    "nodes": [
      {
        "id": "fork-1",
        "type": "fork",
        "worker": "qwen",
        "task": "Fast prototyping of core feature",
        "timeout": 300,
        "blocking": false,
        "role": "fast-prototype"
      },
      {
        "id": "fork-2",
        "type": "fork",
        "worker": "droid",
        "task": "Enterprise-grade implementation",
        "timeout": 900,
        "blocking": false,
        "role": "enterprise-implementation"
      },
      {
        "id": "join-1",
        "type": "join",
        "blocking": false
      },
      {
        "id": "join-2",
        "type": "join",
        "blocking": true
      },
      {
        "id": "fork-3",
        "type": "fork",
        "worker": "codex",
        "task": "Code review and optimization",
        "timeout": 300,
        "blocking": false,
        "role": "review-optimization",
        "depends_on": [1, 2]
      },
      {
        "id": "join-3",
        "type": "join",
        "blocking": true
      }
    ],
    "edges": [
      {"from": "fork-1", "to": "join-1", "weight": 300},
      {"from": "fork-2", "to": "join-2", "weight": 900},
      {"from": "join-1", "to": "fork-3", "weight": 0},
      {"from": "join-2", "to": "fork-3", "weight": 0},
      {"from": "fork-3", "to": "join-3", "weight": 300}
    ]
  },
  "agent_pool": {
    "capacity": 4,
    "workers": ["qwen", "droid", "codex", "cursor"],
    "allocation_policy": "dynamic"
  },
  "metadata": {
    "created_at": "2025-11-06T00:00:00Z",
    "created_by": "claude-organizer",
    "description": "Auto-generated workflow"
  }
}
EOF

    log_ir_to_yaml "INFO" "Organizer AI response saved" "{\"output\": \"$output_ir\"}"
}

# ============================================================================
# 動的ワークフロー生成パイプライン
# ============================================================================

# ゴール記述からワークフローYAMLを生成
generate_workflow_from_goal() {
    local goal="$1"
    local organizer_ai="${2:-claude}"
    local available_workers="${3:-qwen,droid,codex,cursor}"
    local output_yaml="${4:-/tmp/generated-workflow.yaml}"

    log_ir_to_yaml "INFO" "Starting dynamic workflow generation" "{\"goal\": \"$goal\", \"organizer\": \"$organizer_ai\"}"

    # 1. Organizer AIにJSON IR生成を依頼
    local ir_file="/tmp/organizer-ir-$$.json"
    invoke_organizer_ai "$goal" "$available_workers" "$organizer_ai" "$ir_file"

    # 2. JSON IRをYAMLに変換
    convert_ir_to_yaml "$ir_file" "$output_yaml"

    # 3. YAMLを検証
    validate_generated_yaml "$output_yaml"

    log_ir_to_yaml "INFO" "Workflow generation completed" "{\"output\": \"$output_yaml\"}"

    echo "$output_yaml"
}

# 生成されたYAMLを検証
validate_generated_yaml() {
    local yaml_file="$1"

    log_ir_to_yaml "INFO" "Validating generated YAML" "{\"file\": \"$yaml_file\"}"

    # yqで構文チェック
    if ! yq eval '.' "$yaml_file" > /dev/null 2>&1; then
        log_ir_to_yaml "ERROR" "Invalid YAML syntax" "{\"file\": \"$yaml_file\"}"
        return 1
    fi

    # fork_join_enabledチェック
    local fork_join_enabled
    fork_join_enabled=$(yq eval '.profiles.*.workflows.*.phases[] | select(.fork_join_enabled == true) | .fork_join_enabled' "$yaml_file" 2>/dev/null || echo "false")

    if [[ "$fork_join_enabled" != "true" ]]; then
        log_ir_to_yaml "WARN" "fork_join_enabled not set to true" "{}"
    fi

    log_ir_to_yaml "INFO" "YAML validation passed" "{}"
}

# ============================================================================
# エクスポート
# ============================================================================

export -f convert_ir_to_yaml
export -f generate_organizer_prompt
export -f invoke_organizer_ai
export -f generate_workflow_from_goal
export -f validate_generated_yaml

# スクリプト直接実行時のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_ir_to_yaml "INFO" "IR-to-YAML Converter loaded (test mode)"

    # 使用例
    # generate_workflow_from_goal "Implement authentication feature" "claude" "qwen,droid,codex"
fi
