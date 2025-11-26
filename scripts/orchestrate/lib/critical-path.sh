#!/usr/bin/env bash
# Critical-Path Calculation Engine
# AsyncThink v4.0 Phase 2 - Week 11-12 (Codex)
#
# 機能:
# - Earliest-Start-Time (EST) 計算
# - Latest-Finish-Time (LFT) 計算
# - Critical-Path抽出
# - Slack Time算出
# - レイテンシ予測

set -euo pipefail

# ==============================================================================
# データ構造
# ==============================================================================

# Earliest-Start-Time（最も早い開始時刻）
# キー: ノードID
# 値: 秒数（数値）
declare -gA CPM_EST

# Latest-Finish-Time（最も遅い終了時刻）
# キー: ノードID
# 値: 秒数（数値）
declare -gA CPM_LFT

# Slack Time（余裕時間）
# キー: ノードID
# 値: 秒数（数値）
declare -gA CPM_SLACK

# Critical-Path（クリティカルパス）
# 配列: ノードIDのリスト
declare -ga CPM_CRITICAL_PATH

# Total Project Duration（プロジェクト全体の所要時間）
declare -g CPM_TOTAL_DURATION=0

# ==============================================================================
# EST計算（前方パス）
# ==============================================================================

# Earliest-Start-Timeを計算
# アルゴリズム: トポロジカル順序で前方に伝播
# EST(v) = max(EST(u) + duration(u)) for all predecessors u
cpm_calculate_est() {
    # DAG Builderのトポロジカルソートが必要
    if [[ ! -v DAG_TOPO_ORDER ]] || [[ ${#DAG_TOPO_ORDER[@]} -eq 0 ]]; then
        echo "ERROR: Topological order not available. Run dag_topological_sort first." >&2
        return 1
    fi

    # ESTを初期化
    CPM_EST=()
    for node_id in $(dag_get_all_nodes); do
        CPM_EST["$node_id"]=0
    done

    # トポロジカル順序で計算
    for node_id in "${DAG_TOPO_ORDER[@]}"; do
        local max_est=0

        # すべての前方ノード（predecessors）から最大ESTを計算
        local predecessors=$(dag_get_predecessors "$node_id")
        if [[ -n "$predecessors" ]]; then
            for pred in $predecessors; do
                # predecessor のEST + edge weight（タスク実行時間）
                local pred_est=${CPM_EST[$pred]}
                local edge_weight=$(dag_get_edge_weight "$pred" "$node_id")

                local pred_finish_time=$((pred_est + edge_weight))

                if [[ $pred_finish_time -gt $max_est ]]; then
                    max_est=$pred_finish_time
                fi
            done
        fi

        CPM_EST["$node_id"]=$max_est
    done

    return 0
}

# ==============================================================================
# LFT計算（後方パス）
# ==============================================================================

# Latest-Finish-Timeを計算
# アルゴリズム: 逆トポロジカル順序で後方に伝播
# LFT(u) = min(LFT(v) - duration(u->v)) for all successors v
cpm_calculate_lft() {
    # ESTが計算済みであることを確認
    if [[ ${#CPM_EST[@]} -eq 0 ]]; then
        echo "ERROR: EST not calculated. Run cpm_calculate_est first." >&2
        return 1
    fi

    # LFTを初期化（ENDノードのLFTをプロジェクト完了時刻に設定）
    CPM_LFT=()

    # ENDノードのESTをプロジェクト完了時刻とする
    local end_node=""
    for node_id in "${DAG_TOPO_ORDER[@]}"; do
        local node_type=$(dag_get_node_type "$node_id")
        if [[ "$node_type" == "END" ]]; then
            end_node="$node_id"
            break
        fi
    done

    if [[ -z "$end_node" ]]; then
        echo "ERROR: END node not found" >&2
        return 1
    fi

    CPM_TOTAL_DURATION=${CPM_EST[$end_node]}
    CPM_LFT["$end_node"]=$CPM_TOTAL_DURATION

    # 逆トポロジカル順序で計算（ENDから遡る）
    local reverse_order=()
    for ((i=${#DAG_TOPO_ORDER[@]}-1; i>=0; i--)); do
        reverse_order+=("${DAG_TOPO_ORDER[$i]}")
    done

    for node_id in "${reverse_order[@]}"; do
        # ENDノードはスキップ（既に設定済み）
        if [[ "$node_id" == "$end_node" ]]; then
            continue
        fi

        # 後続ノード（successors）がない場合、LFT = プロジェクト完了時刻
        local successors=$(dag_get_successors "$node_id")
        if [[ -z "$successors" ]]; then
            CPM_LFT["$node_id"]=$CPM_TOTAL_DURATION
            continue
        fi

        # すべての後続ノードから最小LFTを計算
        local min_lft=$CPM_TOTAL_DURATION
        for succ in $successors; do
            # successor のLFT - edge weight
            local succ_lft=${CPM_LFT[$succ]}
            local edge_weight=$(dag_get_edge_weight "$node_id" "$succ")

            local required_finish_time=$((succ_lft - edge_weight))

            if [[ $required_finish_time -lt $min_lft ]]; then
                min_lft=$required_finish_time
            fi
        done

        CPM_LFT["$node_id"]=$min_lft
    done

    return 0
}

# ==============================================================================
# Slack Time計算
# ==============================================================================

# Slack Time（余裕時間）を計算
# Slack = LFT - EST - Duration
# Slack = 0 のノードがCritical-Path上にある
cpm_calculate_slack() {
    # ESTとLFTが計算済みであることを確認
    if [[ ${#CPM_EST[@]} -eq 0 ]] || [[ ${#CPM_LFT[@]} -eq 0 ]]; then
        echo "ERROR: EST or LFT not calculated" >&2
        return 1
    fi

    CPM_SLACK=()

    for node_id in $(dag_get_all_nodes); do
        local est=${CPM_EST[$node_id]}
        local lft=${CPM_LFT[$node_id]}

        # Slack = LFT - EST
        local slack=$((lft - est))

        CPM_SLACK["$node_id"]=$slack
    done

    return 0
}

# ==============================================================================
# Critical-Path抽出
# ==============================================================================

# Critical-Pathを抽出
# Slack = 0 のノードをSTARTからENDまで辿る
cpm_extract_critical_path() {
    # Slackが計算済みであることを確認
    if [[ ${#CPM_SLACK[@]} -eq 0 ]]; then
        echo "ERROR: Slack not calculated. Run cpm_calculate_slack first." >&2
        return 1
    fi

    CPM_CRITICAL_PATH=()

    # STARTノードを見つける
    local start_node=""
    for node_id in $(dag_get_all_nodes); do
        local node_type=$(dag_get_node_type "$node_id")
        if [[ "$node_type" == "START" ]]; then
            start_node="$node_id"
            break
        fi
    done

    if [[ -z "$start_node" ]]; then
        echo "ERROR: START node not found" >&2
        return 1
    fi

    # STARTからCritical-Pathを辿る（DFS）
    _cpm_dfs_critical_path "$start_node"

    return 0
}

# Critical-PathのDFS探索（内部関数）
_cpm_dfs_critical_path() {
    local node_id="$1"

    # Critical-Pathに追加
    CPM_CRITICAL_PATH+=("$node_id")

    # ENDノードに到達したら終了
    local node_type=$(dag_get_node_type "$node_id")
    if [[ "$node_type" == "END" ]]; then
        return 0
    fi

    # Slack = 0 の後続ノードを探す
    local successors=$(dag_get_successors "$node_id")
    for succ in $successors; do
        local slack=${CPM_SLACK[$succ]}
        if [[ $slack -eq 0 ]]; then
            _cpm_dfs_critical_path "$succ"
            return 0
        fi
    done

    # Slack = 0 の後続ノードがない場合、最もSlackの小さいノードを選ぶ
    local min_slack=999999
    local next_node=""
    for succ in $successors; do
        local slack=${CPM_SLACK[$succ]}
        if [[ $slack -lt $min_slack ]]; then
            min_slack=$slack
            next_node="$succ"
        fi
    done

    if [[ -n "$next_node" ]]; then
        _cpm_dfs_critical_path "$next_node"
    fi

    return 0
}

# ==============================================================================
# 完全計算（ワンストップ）
# ==============================================================================

# Critical-Path計算のワンストップ実行
# 引数: なし（DAG Builderで構築済みのDAGを使用）
cpm_calculate_all() {
    echo "=== Critical-Path Calculation ===" >&2

    # Step 1: トポロジカルソート確認
    if [[ ! -v DAG_TOPO_ORDER ]] || [[ ${#DAG_TOPO_ORDER[@]} -eq 0 ]]; then
        echo "Step 1: Running topological sort..." >&2
        dag_topological_sort || {
            echo "ERROR: Topological sort failed" >&2
            return 1
        }
    fi

    # Step 2: EST計算
    echo "Step 2: Calculating Earliest-Start-Time..." >&2
    cpm_calculate_est || {
        echo "ERROR: EST calculation failed" >&2
        return 1
    }

    # Step 3: LFT計算
    echo "Step 3: Calculating Latest-Finish-Time..." >&2
    cpm_calculate_lft || {
        echo "ERROR: LFT calculation failed" >&2
        return 1
    }

    # Step 4: Slack計算
    echo "Step 4: Calculating Slack Time..." >&2
    cpm_calculate_slack || {
        echo "ERROR: Slack calculation failed" >&2
        return 1
    }

    # Step 5: Critical-Path抽出
    echo "Step 5: Extracting Critical-Path..." >&2
    cpm_extract_critical_path || {
        echo "ERROR: Critical-Path extraction failed" >&2
        return 1
    }

    echo "=== Calculation Complete ===" >&2
    echo "Total Project Duration: $CPM_TOTAL_DURATION seconds" >&2
    echo "Critical-Path Length: ${#CPM_CRITICAL_PATH[@]} nodes" >&2

    return 0
}

# ==============================================================================
# レポート出力
# ==============================================================================

# Critical-Path計算結果をテーブル形式で表示
cpm_print_report() {
    if [[ ${#CPM_EST[@]} -eq 0 ]] || [[ ${#CPM_LFT[@]} -eq 0 ]] || [[ ${#CPM_SLACK[@]} -eq 0 ]]; then
        echo "ERROR: CPM calculation not complete" >&2
        return 1
    fi

    echo "Critical-Path Analysis Report"
    echo "=============================="
    echo ""
    echo "Total Project Duration: $CPM_TOTAL_DURATION seconds"
    echo "Critical-Path: ${CPM_CRITICAL_PATH[*]}"
    echo ""
    echo "Node Details:"
    printf "%-15s %-10s %-10s %-10s %-15s\n" "Node ID" "EST" "LFT" "Slack" "On CP?"
    printf "%-15s %-10s %-10s %-10s %-15s\n" "---------------" "----------" "----------" "----------" "---------------"

    for node_id in "${DAG_TOPO_ORDER[@]}"; do
        local est=${CPM_EST[$node_id]}
        local lft=${CPM_LFT[$node_id]}
        local slack=${CPM_SLACK[$node_id]}
        local on_cp="No"

        # Critical-Path上にあるか確認
        for cp_node in "${CPM_CRITICAL_PATH[@]}"; do
            if [[ "$cp_node" == "$node_id" ]]; then
                on_cp="Yes"
                break
            fi
        done

        printf "%-15s %-10d %-10d %-10d %-15s\n" "$node_id" "$est" "$lft" "$slack" "$on_cp"
    done
}

# JSON形式でエクスポート
cpm_export_json() {
    local output_file="${1:-}"

    if [[ ${#CPM_EST[@]} -eq 0 ]] || [[ ${#CPM_LFT[@]} -eq 0 ]] || [[ ${#CPM_SLACK[@]} -eq 0 ]]; then
        echo "ERROR: CPM calculation not complete" >&2
        return 1
    fi

    local json=""
    json+="{\n"
    json+="  \"total_duration\": $CPM_TOTAL_DURATION,\n"
    json+="  \"critical_path\": ["

    # Critical-Path配列
    local cp_count=0
    for node in "${CPM_CRITICAL_PATH[@]}"; do
        cp_count=$((cp_count + 1))
        if [[ $cp_count -gt 1 ]]; then
            json+=", "
        fi
        json+="\"$node\""
    done
    json+="],\n"

    json+="  \"nodes\": {\n"

    # ノード詳細
    local node_count=0
    local total_nodes=${#DAG_TOPO_ORDER[@]}
    for node_id in "${DAG_TOPO_ORDER[@]}"; do
        node_count=$((node_count + 1))
        json+="    \"$node_id\": {\n"
        json+="      \"est\": ${CPM_EST[$node_id]},\n"
        json+="      \"lft\": ${CPM_LFT[$node_id]},\n"
        json+="      \"slack\": ${CPM_SLACK[$node_id]}\n"

        if [[ $node_count -lt $total_nodes ]]; then
            json+="    },\n"
        else
            json+="    }\n"
        fi
    done

    json+="  }\n"
    json+="}\n"

    if [[ -n "$output_file" ]]; then
        echo -e "$json" > "$output_file"
    else
        echo -e "$json"
    fi
}

# ==============================================================================
# キャッシング機構（Phase 2 週11-12）
# ==============================================================================

# キャッシュディレクトリとTTL設定
CPM_CACHE_DIR="${CPM_CACHE_DIR:-logs/metrics/cpm-cache}"
CPM_CACHE_TTL="${CPM_CACHE_TTL:-86400}"  # 24時間（秒）

# キャッシュキーを計算（DAG構造のハッシュ値）
cpm_cache_compute_key() {
    local nodes=$(dag_get_all_nodes | sort)
    local edges_info=""

    # すべてのエッジ情報を収集
    for node in $nodes; do
        local successors=$(dag_get_successors "$node" | sort)
        for succ in $successors; do
            local weight=$(dag_get_edge_weight "$node" "$succ")
            edges_info+="${node}->${succ}:${weight};"
        done
    done

    # ハッシュ値を計算（SHA256の最初の16文字）
    echo "${nodes}${edges_info}" | sha256sum | cut -c1-16
}

# 計算結果をキャッシュに保存
cpm_cache_save() {
    local cache_key="$1"

    # キャッシュディレクトリを作成
    mkdir -p "$CPM_CACHE_DIR" 2>/dev/null || return 1

    local cache_file="$CPM_CACHE_DIR/${cache_key}.json"

    # JSON形式で保存
    {
        echo "{"
        echo "  \"version\": \"1.0\","
        echo "  \"timestamp\": $(date +%s),"
        echo "  \"total_duration\": $CPM_TOTAL_DURATION,"
        echo "  \"est\": {"

        local first=true
        for node in $(dag_get_all_nodes); do
            if [[ "$first" == "false" ]]; then echo ","; fi
            echo -n "    \"$node\": ${CPM_EST[$node]}"
            first=false
        done
        echo ""
        echo "  },"
        echo "  \"lft\": {"

        first=true
        for node in $(dag_get_all_nodes); do
            if [[ "$first" == "false" ]]; then echo ","; fi
            echo -n "    \"$node\": ${CPM_LFT[$node]}"
            first=false
        done
        echo ""
        echo "  },"
        echo "  \"slack\": {"

        first=true
        for node in $(dag_get_all_nodes); do
            if [[ "$first" == "false" ]]; then echo ","; fi
            echo -n "    \"$node\": ${CPM_SLACK[$node]}"
            first=false
        done
        echo ""
        echo "  },"
        echo "  \"critical_path\": ["

        first=true
        for node in "${CPM_CRITICAL_PATH[@]}"; do
            if [[ "$first" == "false" ]]; then echo ","; fi
            echo -n "    \"$node\""
            first=false
        done
        echo ""
        echo "  ]"
        echo "}"
    } > "$cache_file"

    # パーミッション設定
    chmod 600 "$cache_file"

    return 0
}

# キャッシュから読み込み
cpm_cache_load() {
    local cache_key="$1"
    local cache_file="$CPM_CACHE_DIR/${cache_key}.json"

    # キャッシュファイルが存在するか確認
    [[ -f "$cache_file" ]] || return 1

    # キャッシュの有効性をチェック
    cpm_cache_is_valid "$cache_file" || return 1

    # JSONをパース（jq使用）
    if ! command -v jq &>/dev/null; then
        # jqがない場合はキャッシュを使用しない
        return 1
    fi

    # Total Durationを読み込み
    CPM_TOTAL_DURATION=$(jq -r '.total_duration' "$cache_file")

    # ESTを読み込み
    CPM_EST=()
    while IFS='=' read -r node value; do
        CPM_EST["$node"]=$value
    done < <(jq -r '.est | to_entries[] | "\(.key)=\(.value)"' "$cache_file")

    # LFTを読み込み
    CPM_LFT=()
    while IFS='=' read -r node value; do
        CPM_LFT["$node"]=$value
    done < <(jq -r '.lft | to_entries[] | "\(.key)=\(.value)"' "$cache_file")

    # SLACKを読み込み
    CPM_SLACK=()
    while IFS='=' read -r node value; do
        CPM_SLACK["$node"]=$value
    done < <(jq -r '.slack | to_entries[] | "\(.key)=\(.value)"' "$cache_file")

    # Critical-Pathを読み込み
    CPM_CRITICAL_PATH=()
    while IFS= read -r node; do
        CPM_CRITICAL_PATH+=("$node")
    done < <(jq -r '.critical_path[]' "$cache_file")

    return 0
}

# キャッシュの有効性をチェック（TTLベース）
cpm_cache_is_valid() {
    local cache_file="$1"

    # ファイルが存在しない場合は無効
    [[ -f "$cache_file" ]] || return 1

    # jqがない場合は無効扱い
    command -v jq &>/dev/null || return 1

    # タイムスタンプを取得
    local cache_timestamp=$(jq -r '.timestamp' "$cache_file" 2>/dev/null)
    [[ -n "$cache_timestamp" ]] || return 1

    # 現在時刻
    local current_time=$(date +%s)

    # 経過時間を計算
    local elapsed=$((current_time - cache_timestamp))

    # TTL以内であれば有効
    [[ $elapsed -lt $CPM_CACHE_TTL ]]
}

# キャッシュを使用したCPM計算
cpm_calculate_all_cached() {
    # キャッシュキーを計算
    local cache_key=$(cpm_cache_compute_key)

    # キャッシュから読み込みを試行
    if cpm_cache_load "$cache_key"; then
        echo "INFO: CPM cache hit (key: $cache_key)" >&2
        return 0
    fi

    # キャッシュミス：通常の計算を実行
    echo "INFO: CPM cache miss (key: $cache_key). Computing..." >&2
    cpm_calculate_all || return 1

    # 計算結果をキャッシュに保存
    cpm_cache_save "$cache_key"

    return 0
}

# ==============================================================================
# ユーティリティ
# ==============================================================================

# CPM計算結果をリセット
cpm_reset() {
    CPM_EST=()
    CPM_LFT=()
    CPM_SLACK=()
    CPM_CRITICAL_PATH=()
    CPM_TOTAL_DURATION=0
}

# ==============================================================================
# メイン処理（スタンドアロン実行時）
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # スタンドアロン実行モード

    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <yaml_file> <profile> [command]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  calculate    - Run full CPM calculation" >&2
        echo "  report       - Print CPM report" >&2
        echo "  json         - Export JSON" >&2
        exit 1
    fi

    yaml_file="$1"
    profile="$2"
    command="${3:-calculate}"

    # DAG Builderをソース
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/dag-builder.sh"

    # DAG構築
    dag_build_from_yaml "$yaml_file" "$profile" || exit 1

    # コマンド実行
    case "$command" in
        calculate)
            cpm_calculate_all
            ;;
        report)
            cpm_calculate_all
            cpm_print_report
            ;;
        json)
            cpm_calculate_all
            cpm_export_json
            ;;
        *)
            echo "ERROR: Unknown command: $command" >&2
            exit 1
            ;;
    esac
fi
