#!/bin/bash
# Fork-Join DSL Parser for AsyncThink Integration
# Version: 1.0
# Phase 1 週3-4: Bashパーサー実装
# 担当: Qwen (高速プロトタイパー)

set -euo pipefail

# ============================================================================
# グローバル変数
# ============================================================================

# Fork/Joinノードの状態管理
declare -A FORK_NODES       # key: fork-id, value: worker_ai|task|timeout|status
declare -A JOIN_NODES       # key: join-id, value: blocking|status
declare -A WORKER_PIDS      # key: fork-id, value: process_id
declare -A WORKER_RESULTS   # key: fork-id, value: result_file_path

# Agent Pool管理
AGENT_POOL_CAPACITY=4
declare -a AVAILABLE_WORKERS=()
declare -a ACTIVE_WORKERS=()

# ============================================================================
# ユーティリティ関数
# ============================================================================

# ロギング関数（VibeLogger統合）
log_fork_join() {
    local level="$1"
    local message="$2"
    local metadata="${3:-{}}"

    # VibeLogger形式のログ出力
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [fork-join-parser] [$level] $message | metadata=$metadata" >&2
}

# エラーハンドリング
handle_parse_error() {
    local error_type="$1"
    local error_message="$2"
    local line_number="${3:-unknown}"

    log_fork_join "ERROR" "Parse error: $error_type at line $line_number" "{\"error\": \"$error_message\"}"
    return 1
}

# ============================================================================
# DSL構文解析
# ============================================================================

# YAML Fork-Join操作をパース
parse_fork_join_yaml() {
    local yaml_file="$1"
    local workflow_name="$2"

    log_fork_join "INFO" "Parsing Fork-Join YAML" "{\"file\": \"$yaml_file\", \"workflow\": \"$workflow_name\"}"

    # YAMLからfork_join_operationsを抽出（yqが必要）
    if ! command -v yq &> /dev/null; then
        handle_parse_error "MISSING_DEPENDENCY" "yq command not found" "0"
        return 1
    fi

    # fork_join_enabled チェック
    local fork_join_enabled
    fork_join_enabled=$(yq eval ".profiles.$workflow_name.workflows.*.phases[] | select(.fork_join_enabled == true) | .fork_join_enabled" "$yaml_file" 2>/dev/null || echo "false")

    if [[ "$fork_join_enabled" != "true" ]]; then
        log_fork_join "INFO" "Fork-Join disabled for workflow" "{\"workflow\": \"$workflow_name\"}"
        return 0
    fi

    log_fork_join "INFO" "Fork-Join enabled, parsing operations" "{\"workflow\": \"$workflow_name\"}"

    # fork_join_operationsをパース
    parse_operations "$yaml_file" "$workflow_name"
}

# Fork/Join操作の個別パース
parse_operations() {
    local yaml_file="$1"
    local workflow_name="$2"

    local operations
    operations=$(yq eval ".profiles.$workflow_name.workflows.*.phases[] | select(.fork_join_enabled == true) | .fork_join_operations[]" "$yaml_file")

    local op_count=0
    while IFS= read -r operation; do
        ((op_count++))

        # FORK操作
        if echo "$operation" | grep -q "^fork:"; then
            parse_fork_operation "$operation" "$op_count"

        # JOIN操作
        elif echo "$operation" | grep -q "^join:"; then
            parse_join_operation "$operation" "$op_count"

        # THINK操作（Phase 3で実装）
        elif echo "$operation" | grep -q "^think:"; then
            log_fork_join "INFO" "THINK operation (Phase 3 feature, skipped)" "{\"op\": $op_count}"

        # ANSWER操作（Phase 3で実装）
        elif echo "$operation" | grep -q "^answer:"; then
            log_fork_join "INFO" "ANSWER operation (Phase 3 feature, skipped)" "{\"op\": $op_count}"

        else
            handle_parse_error "UNKNOWN_OPERATION" "Unknown operation type" "$op_count"
        fi
    done <<< "$operations"

    log_fork_join "INFO" "Parsed operations" "{\"total\": $op_count}"
}

# FORK操作のパース
parse_fork_operation() {
    local operation="$1"
    local line_number="$2"

    # 必須フィールドを抽出
    local fork_id worker task timeout
    fork_id=$(echo "$operation" | yq eval '.fork.id' -)
    worker=$(echo "$operation" | yq eval '.fork.worker' -)
    task=$(echo "$operation" | yq eval '.fork.task' -)
    timeout=$(echo "$operation" | yq eval '.fork.timeout' -)

    # バリデーション
    if [[ -z "$fork_id" || "$fork_id" == "null" ]]; then
        handle_parse_error "MISSING_FIELD" "fork.id is required" "$line_number"
        return 1
    fi

    if [[ -z "$worker" || "$worker" == "null" ]]; then
        handle_parse_error "MISSING_FIELD" "fork.worker is required" "$line_number"
        return 1
    fi

    # デフォルトタイムアウト: 300秒
    timeout="${timeout:-300}"

    # FORK_NODESに登録
    FORK_NODES["fork-$fork_id"]="$worker|$task|$timeout|pending"

    log_fork_join "INFO" "Parsed FORK operation" "{\"id\": \"fork-$fork_id\", \"worker\": \"$worker\", \"timeout\": $timeout}"
}

# JOIN操作のパース
parse_join_operation() {
    local operation="$1"
    local line_number="$2"

    # 必須フィールドを抽出
    local join_id blocking
    join_id=$(echo "$operation" | yq eval '.join.id' -)
    blocking=$(echo "$operation" | yq eval '.join.blocking' -)

    # バリデーション
    if [[ -z "$join_id" || "$join_id" == "null" ]]; then
        handle_parse_error "MISSING_FIELD" "join.id is required" "$line_number"
        return 1
    fi

    # デフォルト: blocking=true
    blocking="${blocking:-true}"

    # JOIN_NODESに登録
    JOIN_NODES["join-$join_id"]="$blocking|pending"

    log_fork_join "INFO" "Parsed JOIN operation" "{\"id\": \"join-$join_id\", \"blocking\": \"$blocking\"}"
}

# ============================================================================
# Agent Pool管理
# ============================================================================

# Agent Poolの初期化
init_agent_pool() {
    local yaml_file="$1"
    local workflow_name="$2"

    # Agent Pool設定を読み込み
    local capacity
    capacity=$(yq eval ".profiles.$workflow_name.workflows.*.phases[] | select(.fork_join_enabled == true) | .agent_pool.capacity" "$yaml_file" 2>/dev/null || echo "4")
    AGENT_POOL_CAPACITY="${capacity:-4}"

    # Available Workers を初期化
    local workers
    workers=$(yq eval ".profiles.$workflow_name.workflows.*.phases[] | select(.fork_join_enabled == true) | .agent_pool.workers[]" "$yaml_file" 2>/dev/null || echo "")

    if [[ -z "$workers" ]]; then
        # デフォルト: qwen, droid, codex, cursor
        AVAILABLE_WORKERS=(qwen droid codex cursor)
    else
        AVAILABLE_WORKERS=()
        while IFS= read -r worker; do
            AVAILABLE_WORKERS+=("$worker")
        done <<< "$workers"
    fi

    log_fork_join "INFO" "Agent Pool initialized" "{\"capacity\": $AGENT_POOL_CAPACITY, \"workers\": \"${AVAILABLE_WORKERS[*]}\"}"
}

# Workerを割り当て
allocate_worker() {
    local requested_worker="$1"

    # 要求されたWorkerが利用可能かチェック
    if [[ ! " ${AVAILABLE_WORKERS[*]} " =~ " ${requested_worker} " ]]; then
        log_fork_join "ERROR" "Worker not in pool" "{\"requested\": \"$requested_worker\"}"
        return 1
    fi

    # 現在のアクティブWorker数をチェック
    local active_count=${#ACTIVE_WORKERS[@]}
    if (( active_count >= AGENT_POOL_CAPACITY )); then
        log_fork_join "WARN" "Agent Pool at capacity, queueing" "{\"capacity\": $AGENT_POOL_CAPACITY, \"active\": $active_count}"
        return 2  # キュー待ち
    fi

    # Workerを割り当て
    ACTIVE_WORKERS+=("$requested_worker")
    log_fork_join "INFO" "Worker allocated" "{\"worker\": \"$requested_worker\", \"active_count\": ${#ACTIVE_WORKERS[@]}}"

    return 0
}

# Workerを解放
release_worker() {
    local worker="$1"

    # ACTIVE_WORKERSから削除
    local new_active=()
    for w in "${ACTIVE_WORKERS[@]}"; do
        if [[ "$w" != "$worker" ]]; then
            new_active+=("$w")
        fi
    done
    ACTIVE_WORKERS=("${new_active[@]}")

    log_fork_join "INFO" "Worker released" "{\"worker\": \"$worker\", \"active_count\": ${#ACTIVE_WORKERS[@]}}"
}

# ============================================================================
# Fork/Join実行
# ============================================================================

# FORK操作を実行
execute_fork() {
    local fork_id="$1"
    local node_data="${FORK_NODES[$fork_id]}"

    IFS='|' read -r worker task timeout status <<< "$node_data"

    if [[ "$status" != "pending" ]]; then
        log_fork_join "WARN" "FORK already executed" "{\"id\": \"$fork_id\", \"status\": \"$status\"}"
        return 0
    fi

    # Workerを割り当て
    allocate_worker "$worker"
    local alloc_result=$?

    if (( alloc_result == 2 )); then
        # キュー待ち
        log_fork_join "INFO" "FORK queued" "{\"id\": \"$fork_id\", \"worker\": \"$worker\"}"
        return 2
    elif (( alloc_result != 0 )); then
        handle_parse_error "ALLOCATION_FAILED" "Failed to allocate worker" "$fork_id"
        return 1
    fi

    # タスクを実行（バックグラウンド）
    log_fork_join "INFO" "Executing FORK" "{\"id\": \"$fork_id\", \"worker\": \"$worker\", \"timeout\": $timeout}"

    local result_file="/tmp/fork-join-result-$fork_id-$$.txt"
    WORKER_RESULTS["$fork_id"]="$result_file"

    # ダミー実行（Phase 1 PoC）
    # 実際のWorker呼び出しは週5-6で実装
    (
        sleep "$((timeout / 100))"  # 高速シミュレーション
        echo "FORK-$fork_id result from $worker" > "$result_file"
    ) &

    local pid=$!
    WORKER_PIDS["$fork_id"]=$pid

    # ステータス更新
    FORK_NODES["$fork_id"]="$worker|$task|$timeout|running"

    log_fork_join "INFO" "FORK started" "{\"id\": \"$fork_id\", \"pid\": $pid}"
}

# JOIN操作を実行
execute_join() {
    local join_id="$1"
    local node_data="${JOIN_NODES[$join_id]}"

    IFS='|' read -r blocking status <<< "$node_data"

    if [[ "$status" != "pending" ]]; then
        log_fork_join "WARN" "JOIN already executed" "{\"id\": \"$join_id\", \"status\": \"$status\"}"
        return 0
    fi

    # 対応するFORKの完了を待機
    local fork_id="fork-${join_id#join-}"

    if [[ -z "${FORK_NODES[$fork_id]:-}" ]]; then
        handle_parse_error "FORK_NOT_FOUND" "No corresponding FORK for JOIN" "$join_id"
        return 1
    fi

    log_fork_join "INFO" "Executing JOIN" "{\"id\": \"$join_id\", \"fork_id\": \"$fork_id\", \"blocking\": \"$blocking\"}"

    # FORKの完了を待機
    local pid="${WORKER_PIDS[$fork_id]:-}"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        if [[ "$blocking" == "true" ]]; then
            log_fork_join "INFO" "Waiting for FORK (blocking)" "{\"fork_id\": \"$fork_id\", \"pid\": $pid}"
            wait "$pid"
            local exit_code=$?

            if (( exit_code == 0 )); then
                FORK_NODES["$fork_id"]="${FORK_NODES[$fork_id]%|*}|completed"
            else
                FORK_NODES["$fork_id"]="${FORK_NODES[$fork_id]%|*}|failed"
                handle_parse_error "FORK_FAILED" "FORK task failed" "$fork_id"
            fi
        else
            log_fork_join "INFO" "JOIN non-blocking, proceeding" "{\"fork_id\": \"$fork_id\"}"
        fi
    else
        log_fork_join "INFO" "FORK already completed" "{\"fork_id\": \"$fork_id\"}"
    fi

    # Workerを解放
    local worker
    worker=$(echo "${FORK_NODES[$fork_id]}" | cut -d'|' -f1)
    release_worker "$worker"

    # ステータス更新
    JOIN_NODES["$join_id"]="$blocking|completed"

    log_fork_join "INFO" "JOIN completed" "{\"id\": \"$join_id\"}"
}

# ============================================================================
# タイムアウト処理
# ============================================================================

# FORK操作のタイムアウト監視
monitor_fork_timeout() {
    local fork_id="$1"
    local timeout="$2"
    local pid="$3"

    (
        sleep "$timeout"

        if kill -0 "$pid" 2>/dev/null; then
            log_fork_join "ERROR" "FORK timeout" "{\"id\": \"$fork_id\", \"timeout\": $timeout}"
            kill -TERM "$pid" 2>/dev/null || true

            # ステータス更新
            local node_data="${FORK_NODES[$fork_id]}"
            FORK_NODES["$fork_id"]="${node_data%|*}|timeout"
        fi
    ) &
}

# ============================================================================
# エラーハンドリング
# ============================================================================

# 不正タグ検出
validate_fork_join_structure() {
    local yaml_file="$1"

    # Fork-IDとJoin-IDの対応チェック
    for fork_id in "${!FORK_NODES[@]}"; do
        local join_id="${fork_id/fork-/join-}"

        if [[ -z "${JOIN_NODES[$join_id]:-}" ]]; then
            handle_parse_error "MISSING_JOIN" "FORK without corresponding JOIN" "$fork_id"
            return 1
        fi
    done

    log_fork_join "INFO" "Fork-Join structure validated"
    return 0
}

# ============================================================================
# メイン実行フロー
# ============================================================================

# Fork-Joinワークフローを実行
run_fork_join_workflow() {
    local yaml_file="$1"
    local workflow_name="$2"

    log_fork_join "INFO" "Starting Fork-Join workflow" "{\"yaml\": \"$yaml_file\", \"workflow\": \"$workflow_name\"}"

    # 1. YAMLをパース
    parse_fork_join_yaml "$yaml_file" "$workflow_name" || return 1

    # 2. Agent Poolを初期化
    init_agent_pool "$yaml_file" "$workflow_name" || return 1

    # 3. 構造を検証
    validate_fork_join_structure "$yaml_file" || return 1

    # 4. Fork操作を実行
    for fork_id in "${!FORK_NODES[@]}"; do
        execute_fork "$fork_id"
    done

    # 5. Join操作を実行
    for join_id in "${!JOIN_NODES[@]}"; do
        execute_join "$join_id"
    done

    log_fork_join "INFO" "Fork-Join workflow completed" "{\"workflow\": \"$workflow_name\"}"
}

# ============================================================================
# エクスポート（他スクリプトから呼び出し可能）
# ============================================================================

# 関数をエクスポート
export -f parse_fork_join_yaml
export -f init_agent_pool
export -f execute_fork
export -f execute_join
export -f run_fork_join_workflow

# スクリプト直接実行時のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_fork_join "INFO" "Fork-Join Parser loaded (test mode)"

    # 使用例
    # run_fork_join_workflow "config/asyncthink-samples.yaml" "simple-fork-join"
fi
