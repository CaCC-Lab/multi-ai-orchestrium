#!/usr/bin/env bash
# DAG Builder Module - Fork-Join DAG Construction Engine
# AsyncThink v4.0 Phase 2 - Week 9-10 (Codex)
#
# 機能:
# - タスク依存グラフ生成
# - ノード（タスク）とエッジ（依存関係）の抽象化
# - トポロジカルソート実装
# - 循環依存検出
# - Critical-Path計算の基盤
# - Graphviz DOT形式エクスポート

set -euo pipefail

# ==============================================================================
# データ構造
# ==============================================================================

# ノード情報（連想配列）
# キー: ノードID（例: "fork-1", "join-2"）
# 値: "type:FORK|worker:qwen|timeout:300|blocking:false|depends_on:[]"
declare -gA DAG_NODES

# エッジ情報（依存関係）
# キー: "from->to"（例: "fork-1->join-1"）
# 値: "weight:300" （タスク実行時間、Critical-Path計算用）
declare -gA DAG_EDGES

# 逆エッジ（依存元を高速検索するため）
# キー: ノードID
# 値: カンマ区切りの依存元ノードID（例: "fork-1,fork-2"）
declare -gA DAG_REVERSE_EDGES

# トポロジカルソート結果
declare -ga DAG_TOPO_ORDER

# グラフメタデータ
declare -g DAG_ORGANIZER=""
declare -g DAG_AGENT_POOL_CAPACITY=0
declare -ga DAG_AGENT_POOL_WORKERS

# ==============================================================================
# ノード操作
# ==============================================================================

# ノードを追加
# 引数:
#   $1: ノードID
#   $2: type (FORK | JOIN | START | END)
#   $3+: 追加属性（key:value形式）
dag_add_node() {
    local node_id="$1"
    local node_type="$2"
    shift 2

    local attributes="type:${node_type}"
    for attr in "$@"; do
        attributes="${attributes}|${attr}"
    done

    DAG_NODES["$node_id"]="$attributes"
}

# ノード属性を取得
# 引数:
#   $1: ノードID
#   $2: 属性名
dag_get_node_attr() {
    local node_id="$1"
    local attr_name="$2"

    if [[ ! -v "DAG_NODES[$node_id]" ]]; then
        echo "ERROR: Node '$node_id' not found" >&2
        return 1
    fi

    local node_data="${DAG_NODES[$node_id]}"
    echo "$node_data" | grep -oP "${attr_name}:\K[^|]+"
}

# ノードのタイプを取得
dag_get_node_type() {
    dag_get_node_attr "$1" "type"
}

# ノードの全属性を取得
dag_get_node() {
    local node_id="$1"
    if [[ ! -v "DAG_NODES[$node_id]" ]]; then
        echo "ERROR: Node '$node_id' does not exist" >&2
        return 1
    fi
    echo "${DAG_NODES[$node_id]}"
}

# 全ノードIDを取得
dag_get_all_nodes() {
    for node_id in "${!DAG_NODES[@]}"; do
        echo "$node_id"
    done
}

# ==============================================================================
# エッジ操作
# ==============================================================================

# エッジを追加（依存関係を定義）
# 引数:
#   $1: from ノードID
#   $2: to ノードID
#   $3: weight（オプション、デフォルト: 0）
dag_add_edge() {
    local from="$1"
    local to="$2"
    local weight="${3:-0}"

    # エッジ追加
    DAG_EDGES["${from}->${to}"]="weight:${weight}"

    # 逆エッジ更新（toノードの依存元リストにfromを追加）
    if [[ -v "DAG_REVERSE_EDGES[$to]" ]]; then
        DAG_REVERSE_EDGES["$to"]="${DAG_REVERSE_EDGES[$to]},${from}"
    else
        DAG_REVERSE_EDGES["$to"]="$from"
    fi
}

# エッジの重み（タスク実行時間）を取得
dag_get_edge_weight() {
    local from="$1"
    local to="$2"

    local edge_key="${from}->${to}"
    if [[ ! -v "DAG_EDGES[$edge_key]" ]]; then
        echo "0"
        return
    fi

    echo "${DAG_EDGES[$edge_key]}" | grep -oP 'weight:\K\d+'
}

# ノードの依存元（predecessors）を取得
dag_get_predecessors() {
    local node_id="$1"

    if [[ ! -v "DAG_REVERSE_EDGES[$node_id]" ]]; then
        return 0
    fi

    echo "${DAG_REVERSE_EDGES[$node_id]}" | tr ',' '\n'
}

# ノードの依存先（successors）を取得
dag_get_successors() {
    local node_id="$1"

    for edge_key in "${!DAG_EDGES[@]}"; do
        local from="${edge_key%%->*}"
        local to="${edge_key##*->}"

        if [[ "$from" == "$node_id" ]]; then
            echo "$to"
        fi
    done
}

# ==============================================================================
# YAML解析
# ==============================================================================

# YAMLプロファイルからDAGを構築
# 引数:
#   $1: YAMLファイルパス
#   $2: プロファイル名
dag_build_from_yaml() {
    local yaml_file="$1"
    local profile="$2"

    # プロファイル存在確認
    if ! yq eval ".profiles | has(\"$profile\")" "$yaml_file" | grep -q "true"; then
        echo "ERROR: Profile '$profile' not found in $yaml_file" >&2
        return 1
    fi

    # メタデータ取得
    DAG_ORGANIZER=$(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .organizer" "$yaml_file" | head -1)
    DAG_AGENT_POOL_CAPACITY=$(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .agent_pool.capacity" "$yaml_file" | head -1)
    mapfile -t DAG_AGENT_POOL_WORKERS < <(yq eval ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .agent_pool.workers[]" "$yaml_file")

    # STARTノード追加
    dag_add_node "START" "START"

    # fork_join_operations解析（2パス: 先にノード作成、後でエッジ作成）
    # Pass 1: ノード作成
    while IFS= read -r operation; do
        if [[ -z "$operation" ]]; then
            continue
        fi

        if echo "$operation" | jq -e '.fork' > /dev/null 2>&1; then
            _parse_fork_node "$operation"
        elif echo "$operation" | jq -e '.join' > /dev/null 2>&1; then
            _parse_join_node "$operation"
        fi
    done < <(yq eval -o=json ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .fork_join_operations[]" "$yaml_file" | jq -c '.')

    # Pass 2: エッジ作成
    local last_join_id=""
    while IFS= read -r operation; do
        if [[ -z "$operation" ]]; then
            continue
        fi

        if echo "$operation" | jq -e '.fork' > /dev/null 2>&1; then
            local id=$(echo "$operation" | jq -r '.fork.id')
            local timeout=$(echo "$operation" | jq -r '.fork.timeout // 300')
            local depends_on=$(echo "$operation" | jq -r '.fork.depends_on // []' | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

            # FORKはSTARTから開始（並列実行）
            if [[ -z "$depends_on" ]]; then
                dag_add_edge "START" "fork-${id}" "$timeout"
            else
                # depends_on依存関係の処理
                IFS=',' read -ra deps <<< "$depends_on"
                for dep in "${deps[@]}"; do
                    dag_add_edge "join-${dep}" "fork-${id}" "$timeout"
                done
            fi

        elif echo "$operation" | jq -e '.join' > /dev/null 2>&1; then
            local id=$(echo "$operation" | jq -r '.join.id')
            # JOIN対応するFORKから
            dag_add_edge "fork-${id}" "join-${id}" 0
            last_join_id="$id"
        fi
    done < <(yq eval -o=json ".profiles.$profile.workflows.*.phases[] | select(.fork_join_enabled == true) | .fork_join_operations[]" "$yaml_file" | jq -c '.')

    # ENDノード追加
    dag_add_node "END" "END"
    if [[ -n "$last_join_id" ]]; then
        dag_add_edge "join-${last_join_id}" "END" 0
    fi
}

# FORK ノード作成（内部関数、エッジは作成しない）
_parse_fork_node() {
    local operation="$1"

    local id=$(echo "$operation" | jq -r '.fork.id')
    local worker=$(echo "$operation" | jq -r '.fork.worker')
    local timeout=$(echo "$operation" | jq -r '.fork.timeout // 300')
    local blocking=$(echo "$operation" | jq -r '.fork.blocking // false')
    local depends_on=$(echo "$operation" | jq -r '.fork.depends_on // []' | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

    local node_id="fork-${id}"

    # ノード追加のみ
    dag_add_node "$node_id" "FORK" \
        "worker:${worker}" \
        "timeout:${timeout}" \
        "blocking:${blocking}" \
        "depends_on:${depends_on}"
}

# JOIN ノード作成（内部関数、エッジは作成しない）
_parse_join_node() {
    local operation="$1"

    local id=$(echo "$operation" | jq -r '.join.id')
    local blocking=$(echo "$operation" | jq -r '.join.blocking // true')

    local node_id="join-${id}"

    # ノード追加のみ
    dag_add_node "$node_id" "JOIN" \
        "blocking:${blocking}" \
        "depends_on:fork-${id}"
}

# ==============================================================================
# トポロジカルソート（Kahn's Algorithm）
# ==============================================================================

# トポロジカルソートを実行
# 返り値: 0=成功、1=循環依存検出
dag_topological_sort() {
    DAG_TOPO_ORDER=()

    # 入次数を計算
    declare -A in_degree
    for node_id in $(dag_get_all_nodes); do
        in_degree["$node_id"]=0
    done

    for edge_key in "${!DAG_EDGES[@]}"; do
        local to="${edge_key##*->}"
        in_degree["$to"]=$((in_degree["$to"] + 1))
    done

    # 入次数0のノードをキューに追加
    local queue=()
    for node_id in "${!in_degree[@]}"; do
        if [[ ${in_degree["$node_id"]} -eq 0 ]]; then
            queue+=("$node_id")
        fi
    done

    # Kahn's Algorithm実行
    local visited_count=0
    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")

        DAG_TOPO_ORDER+=("$current")
        visited_count=$((visited_count + 1))

        # 後続ノードの入次数を減らす
        for successor in $(dag_get_successors "$current"); do
            in_degree["$successor"]=$((in_degree["$successor"] - 1))

            if [[ ${in_degree["$successor"]} -eq 0 ]]; then
                queue+=("$successor")
            fi
        done
    done

    # 循環依存検出
    local total_nodes=${#DAG_NODES[@]}
    if [[ $visited_count -ne $total_nodes ]]; then
        echo "ERROR: Cyclic dependency detected! Visited $visited_count nodes, but graph has $total_nodes nodes." >&2
        return 1
    fi

    return 0
}

# トポロジカルソート結果を取得
dag_get_topo_order() {
    for node_id in "${DAG_TOPO_ORDER[@]}"; do
        echo "$node_id"
    done
}

# ==============================================================================
# 循環依存検出（DFS-based）
# ==============================================================================

# グローバル変数（DFS用）
declare -gA _DAG_VISITED
declare -gA _DAG_REC_STACK

# 循環依存を検出（DFS with visited/recursion stack）
# 返り値: 0=循環なし、1=循環あり
dag_detect_cycle() {
    # グローバル変数初期化
    _DAG_VISITED=()
    _DAG_REC_STACK=()

    for node_id in $(dag_get_all_nodes); do
        _DAG_VISITED["$node_id"]=0
        _DAG_REC_STACK["$node_id"]=0
    done

    for node_id in $(dag_get_all_nodes); do
        if [[ ${_DAG_VISITED["$node_id"]} -eq 0 ]]; then
            # 返り値: 0=循環なし、1=循環あり
            # → 循環ありの場合（return 1）に早期リターン
            if ! _dag_dfs_cycle "$node_id"; then
                return 1  # 循環検出
            fi
        fi
    done

    return 0  # 循環なし
}

# DFS for cycle detection（内部関数、グローバル変数使用）
_dag_dfs_cycle() {
    local node="$1"

    _DAG_VISITED["$node"]=1
    _DAG_REC_STACK["$node"]=1

    for successor in $(dag_get_successors "$node"); do
        if [[ ${_DAG_VISITED["$successor"]} -eq 0 ]]; then
            # 返り値: 0=循環なし、1=循環あり
            # → 循環ありの場合（return 1）に伝播させる
            if ! _dag_dfs_cycle "$successor"; then
                return 1
            fi
        elif [[ ${_DAG_REC_STACK["$successor"]} -eq 1 ]]; then
            echo "ERROR: Cycle detected: $node -> $successor" >&2
            return 1
        fi
    done

    _DAG_REC_STACK["$node"]=0
    return 0
}

# ==============================================================================
# エクスポート機能
# ==============================================================================

# Graphviz DOT形式でエクスポート
dag_export_dot() {
    local output_file="${1:-}"

    local dot_content=""
    dot_content+="digraph AsyncThinkDAG {\n"
    dot_content+="  rankdir=TB;\n"
    dot_content+="  node [shape=box, style=rounded];\n"
    dot_content+="\n"
    dot_content+="  // Metadata\n"
    dot_content+="  labelloc=\"t\";\n"
    dot_content+="  label=\"AsyncThink Fork-Join DAG\\nOrganizer: $DAG_ORGANIZER\\nAgent Pool: ${#DAG_AGENT_POOL_WORKERS[@]}/${DAG_AGENT_POOL_CAPACITY}\";\n"
    dot_content+="\n"

    # ノード定義
    dot_content+="  // Nodes\n"
    for node_id in $(dag_get_all_nodes); do
        local node_type=$(dag_get_node_type "$node_id")
        local label="$node_id"
        local shape="box"
        local color="black"

        case "$node_type" in
            START)
                shape="ellipse"
                color="green"
                ;;
            END)
                shape="ellipse"
                color="red"
                ;;
            FORK)
                local worker=$(dag_get_node_attr "$node_id" "worker" || echo "")
                local timeout=$(dag_get_node_attr "$node_id" "timeout" || echo "")
                label="${node_id}\\n(${worker}, ${timeout}s)"
                color="blue"
                ;;
            JOIN)
                color="orange"
                ;;
        esac

        dot_content+="  \"$node_id\" [label=\"$label\", shape=$shape, color=$color];\n"
    done

    dot_content+="\n"

    # エッジ定義
    dot_content+="  // Edges\n"
    for edge_key in "${!DAG_EDGES[@]}"; do
        local from="${edge_key%%->*}"
        local to="${edge_key##*->}"
        local weight=$(dag_get_edge_weight "$from" "$to")

        local label=""
        if [[ $weight -gt 0 ]]; then
            label="[label=\"${weight}s\"]"
        fi

        dot_content+="  \"$from\" -> \"$to\" $label;\n"
    done

    dot_content+="}\n"

    if [[ -n "$output_file" ]]; then
        echo -e "$dot_content" > "$output_file"
    else
        echo -e "$dot_content"
    fi
}

# JSON形式でエクスポート
dag_export_json() {
    local output_file="${1:-}"

    local json="{\n"
    json+="  \"metadata\": {\n"
    json+="    \"organizer\": \"$DAG_ORGANIZER\",\n"
    json+="    \"agent_pool_capacity\": $DAG_AGENT_POOL_CAPACITY,\n"

    # Build workers array properly
    local workers_json="["
    local worker_count=0
    if [[ ${#DAG_AGENT_POOL_WORKERS[@]} -gt 0 ]]; then
        for worker in "${DAG_AGENT_POOL_WORKERS[@]}"; do
            worker_count=$((worker_count + 1))
            if [[ $worker_count -gt 1 ]]; then
                workers_json+=", "
            fi
            workers_json+="\"$worker\""
        done
    fi
    workers_json+="]"

    json+="    \"agent_pool_workers\": $workers_json\n"
    json+="  },\n"
    json+="  \"nodes\": {\n"

    local node_count=0
    local total_nodes=${#DAG_NODES[@]}
    for node_id in $(dag_get_all_nodes); do
        node_count=$((node_count + 1))
        json+="    \"$node_id\": {\n"

        local node_data="${DAG_NODES[$node_id]}"
        IFS='|' read -ra attrs <<< "$node_data"

        local attr_count=0
        for attr in "${attrs[@]}"; do
            attr_count=$((attr_count + 1))
            local key="${attr%%:*}"
            local value="${attr##*:}"

            if [[ "$attr_count" -lt ${#attrs[@]} ]]; then
                json+="      \"$key\": \"$value\",\n"
            else
                json+="      \"$key\": \"$value\"\n"
            fi
        done

        if [[ $node_count -lt $total_nodes ]]; then
            json+="    },\n"
        else
            json+="    }\n"
        fi
    done

    json+="  },\n"
    json+="  \"edges\": [\n"

    local edge_count=0
    local total_edges=${#DAG_EDGES[@]}
    for edge_key in "${!DAG_EDGES[@]}"; do
        edge_count=$((edge_count + 1))
        local from="${edge_key%%->*}"
        local to="${edge_key##*->}"
        local weight=$(dag_get_edge_weight "$from" "$to")

        if [[ $edge_count -lt $total_edges ]]; then
            json+="    {\"from\": \"$from\", \"to\": \"$to\", \"weight\": $weight},\n"
        else
            json+="    {\"from\": \"$from\", \"to\": \"$to\", \"weight\": $weight}\n"
        fi
    done

    json+="  ]\n"
    json+="}\n"

    if [[ -n "$output_file" ]]; then
        echo -e "$json" > "$output_file"
    else
        echo -e "$json"
    fi
}

# ==============================================================================
# ユーティリティ
# ==============================================================================

# DAG統計情報を表示
dag_print_stats() {
    echo "DAG Statistics:"
    echo "  - Total nodes: ${#DAG_NODES[@]}"
    echo "  - Total edges: ${#DAG_EDGES[@]}"
    echo "  - Organizer: ${DAG_ORGANIZER:-<none>}"

    if [[ -v DAG_AGENT_POOL_WORKERS ]] && [[ ${#DAG_AGENT_POOL_WORKERS[@]} -gt 0 ]]; then
        echo "  - Agent pool: ${#DAG_AGENT_POOL_WORKERS[@]}/${DAG_AGENT_POOL_CAPACITY}"
        echo "  - Workers: ${DAG_AGENT_POOL_WORKERS[*]}"
    else
        echo "  - Agent pool: 0/${DAG_AGENT_POOL_CAPACITY:-0}"
        echo "  - Workers: (none)"
    fi
}

# DAGをリセット
dag_reset() {
    # Properly initialize arrays to work with set -u
    DAG_NODES=()
    DAG_EDGES=()
    DAG_REVERSE_EDGES=()
    DAG_TOPO_ORDER=()

    DAG_ORGANIZER=""
    DAG_AGENT_POOL_CAPACITY=0
    DAG_AGENT_POOL_WORKERS=()
}

# ==============================================================================
# メイン処理（スタンドアロン実行時）
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # スタンドアロン実行: YAML from arguments
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <yaml_file> <profile> [command]" >&2
        echo "Commands: stats | topo | dot | json | cycle" >&2
        exit 1
    fi

    YAML_FILE="$1"
    PROFILE="$2"
    COMMAND="${3:-stats}"

    # DAG構築
    dag_build_from_yaml "$YAML_FILE" "$PROFILE"

    # コマンド実行
    case "$COMMAND" in
        stats)
            dag_print_stats
            ;;
        topo)
            if dag_topological_sort; then
                echo "Topological order:"
                dag_get_topo_order
            else
                exit 1
            fi
            ;;
        dot)
            dag_export_dot
            ;;
        json)
            dag_export_json
            ;;
        cycle)
            if dag_detect_cycle; then
                echo "No cycles detected ✅"
            else
                echo "Cycles detected ❌"
                exit 1
            fi
            ;;
        *)
            echo "Unknown command: $COMMAND" >&2
            exit 1
            ;;
    esac
fi
