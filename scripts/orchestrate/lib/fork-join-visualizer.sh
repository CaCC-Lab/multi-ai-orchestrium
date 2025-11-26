#!/usr/bin/env bash
# Fork-Join DAG Visualizer
# Renders Fork-Join structure as ASCII art

set -euo pipefail

# データ構造
declare -A DAG_NODES
declare -a EXECUTION_ORDER
declare ORGANIZER=""
declare AGENT_POOL_CAPACITY=0
declare -a AGENT_POOL_WORKERS

# YAML解析: fork_join_operationsを抽出
parse_fork_join_yaml() {
    local yaml_file="$1"
    local profile="$2"

    # Organizer取得
    ORGANIZER=$(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .organizer" "$yaml_file" | head -1)

    # Agent Pool設定取得
    AGENT_POOL_CAPACITY=$(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .agent_pool.capacity" "$yaml_file" | head -1)

    # Workers取得
    mapfile -t AGENT_POOL_WORKERS < <(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .agent_pool.workers[]" "$yaml_file")

    # fork_join_operations解析（1行ずつJSONを処理）
    local index=0
    while IFS= read -r operation; do
        if [[ -z "$operation" ]]; then
            continue
        fi

        # FORKまたはJOINを判定
        if echo "$operation" | jq -e '.fork' > /dev/null 2>&1; then
            parse_fork_operation "$operation" "$index"
        elif echo "$operation" | jq -e '.join' > /dev/null 2>&1; then
            parse_join_operation "$operation" "$index"
        fi

        ((index++))
    done < <(yq eval -o=json ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .fork_join_operations[]" "$yaml_file" | jq -c '.')
}

# FORK操作解析
parse_fork_operation() {
    local operation="$1"
    local index="$2"

    local id=$(echo "$operation" | jq -r '.fork.id')
    local worker=$(echo "$operation" | jq -r '.fork.worker')
    local timeout=$(echo "$operation" | jq -r '.fork.timeout // 300')
    local blocking=$(echo "$operation" | jq -r '.fork.blocking // false')
    local depends_on=$(echo "$operation" | jq -r '.fork.depends_on // []' | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

    DAG_NODES["fork-${id}"]="type:FORK|worker:${worker}|timeout:${timeout}|blocking:${blocking}|depends_on:${depends_on}"
    EXECUTION_ORDER+=("fork-${id}")
}

# JOIN操作解析
parse_join_operation() {
    local operation="$1"
    local index="$2"

    local id=$(echo "$operation" | jq -r '.join.id')
    local blocking=$(echo "$operation" | jq -r '.join.blocking // true')

    DAG_NODES["join-${id}"]="type:JOIN|blocking:${blocking}|depends_on:fork-${id}"
    EXECUTION_ORDER+=("join-${id}")
}

# DAG構造をASCII artで描画
render_ascii_dag() {
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║ AsyncThink Fork-Join DAG                                                  ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════╣"
    echo "║ Organizer: $ORGANIZER"
    echo "║ Agent Pool: ${#AGENT_POOL_WORKERS[@]}/${AGENT_POOL_CAPACITY} workers (${AGENT_POOL_WORKERS[*]})"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "START"
    echo "  │"

    # 実行順序に従って描画
    local prev_type=""
    local indent="  "

    for node_id in "${EXECUTION_ORDER[@]}"; do
        local node_data="${DAG_NODES[$node_id]}"
        local type=$(echo "$node_data" | grep -oP 'type:\K[^|]+')

        if [[ "$type" == "FORK" ]]; then
            local worker=$(echo "$node_data" | grep -oP 'worker:\K[^|]+')
            local timeout=$(echo "$node_data" | grep -oP 'timeout:\K[^|]+')
            local depends_on=$(echo "$node_data" | grep -oP 'depends_on:\K[^|]+')

            if [[ -n "$depends_on" ]]; then
                echo "${indent}│    └─ (depends on: [$depends_on])"
            fi

            echo "${indent}├─ 🔀 FORK-${node_id#fork-} [$worker, ${timeout}s] ─────┐"

        elif [[ "$type" == "JOIN" ]]; then
            local blocking=$(echo "$node_data" | grep -oP 'blocking:\K[^|]+')
            local mode=$([ "$blocking" == "true" ] && echo "blocking" || echo "non-blocking")

            echo "${indent}│                                                     │"
            echo "${indent}├─ 🔗 JOIN-${node_id#join-} ($mode) ◄────────────────┘"
        fi

        prev_type="$type"
    done

    echo "  │"
    echo "END"
    echo ""
}

# メイン関数
visualize_fork_join_dag() {
    local yaml_file="$1"
    local profile="${2:-simple-fork-join}"

    # YAMLファイル存在チェック
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: YAML file not found: $yaml_file" >&2
        return 1
    fi

    # fork_join_enabled チェック
    local has_fork_join=$(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true)" "$yaml_file" 2>/dev/null)
    if [[ -z "$has_fork_join" ]]; then
        echo "ERROR: Profile '$profile' does not have fork_join_enabled" >&2
        return 1
    fi

    # YAML解析
    parse_fork_join_yaml "$yaml_file" "$profile"

    # DAG描画
    render_ascii_dag
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    visualize_fork_join_dag "${1:-config/multi-ai-profiles.yaml}" "${2:-simple-fork-join}"
fi
