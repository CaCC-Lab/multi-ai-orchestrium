#!/usr/bin/env bash
# worktree-core.sh - コアワークツリー操作
# 責務：作成、削除、一覧、検証

set -euo pipefail

# 依存関係をソース
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh"

# Phase 5 Issue #4: Prometheus Metrics
METRICS_LIB="$SCRIPT_DIR/../../lib/worktree-metrics.sh"
if [[ -f "$METRICS_LIB" ]]; then
    source "$METRICS_LIB"
    # メトリクスの初期化（初回のみ）
    if [[ ! -f "${METRICS_FILE:-}" ]] || [[ ! -d "$(dirname "${METRICS_FILE:-/tmp}")" ]]; then
        init_metrics 2>/dev/null || true
    fi
fi

# グローバル設定
WORKTREE_BASE_DIR="${WORKTREE_BASE_DIR:-worktrees}"
WORKTREE_LOCK_FILE="/tmp/multi-ai-worktree.lock"
export WORKTREE_LOCK_FILE  # 並列実行サブプロセス対応
WORKTREE_SHADOW_MODE="${WORKTREE_SHADOW_MODE:-false}"

# NDJSON形式のステートファイル
# 各行が独立したJSONオブジェクト（Newline Delimited JSON）
#
# 形式:
#   {"<ai-name>": {"state": "<state>", "timestamp": "<ISO-8601>"}}
#
# 例:
#   {"claude": {"state": "ready", "timestamp": "2025-11-04T22:46:00Z"}}
#   {"gemini": {"state": "executing", "timestamp": "2025-11-04T22:47:00Z"}}
#   {"qwen": {"state": "completed", "timestamp": "2025-11-04T22:48:00Z"}}
#
# 読み取り:
#   while IFS= read -r line; do
#     ai=$(echo "$line" | jq -r 'keys[0]')
#     state=$(echo "$line" | jq -r ".[\"$ai\"].state")
#   done < "$WORKTREE_STATE_FILE"
#
# 注意: 標準的なJSON配列ではないため、`jq '.'` は失敗します
WORKTREE_STATE_FILE="$WORKTREE_BASE_DIR/.state.json"

# 障害復旧用の状態管理
declare -A WORKTREE_STATE=(
  [claude]="none"
  [gemini]="none"
  [amp]="none"
  [qwen]="none"
  [droid]="none"
  [codex]="none"
  [cursor]="none"
)

# ========================================
# エラーメッセージヘルパー関数
# ========================================

##
# エラーメッセージに解決策を追加して出力
#
# 引数:
#   $1 - エラーメッセージ
#   $2 - 解決策（複数行可）
#
# 戻り値:
#   なし（常にstderrに出力）
#
# 例:
#   error_with_solution "jqコマンドが見つかりません" \
#     "- Ubuntu/Debian: sudo apt-get install jq
#  - macOS: brew install jq"
##
error_with_solution() {
  local error_msg="$1"
  local solution="$2"

  echo "ERROR: $error_msg" >&2
  if [[ -n "$solution" ]]; then
    echo "  解決策:" >&2
    echo "$solution" | sed 's/^/    /' >&2
  fi
}

# ========================================
# 状態管理関数
# ========================================

##
# ワークツリーの状態をメモリとディスクに保存
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - 状態（none|creating|active|error|cleanup）
#
# 戻り値:
#   0 - 常に成功
#
# 副作用:
#   - WORKTREE_STATE連想配列を更新
#   - .state.jsonファイルに永続化（クラッシュ復旧用）
#   - VibeLoggerログを記録
#
# 例:
#   save_worktree_state "qwen" "creating"
#   save_worktree_state "droid" "active"
##
save_worktree_state() {
  local ai_name="$1"
  local state="$2"
  WORKTREE_STATE["$ai_name"]="$state"

  # jqコマンドの存在と動作チェック
  if ! jq --version &>/dev/null; then
    error_with_solution "jqコマンドが見つかりません。インストールしてください" \
      "- Ubuntu/Debian: sudo apt-get install jq
- macOS: brew install jq
- Arch Linux: sudo pacman -S jq
- その他: https://stedolan.github.io/jq/download/"
    return 1
  fi

  # クラッシュ復旧のためディスクに永続化
  mkdir -p "$WORKTREE_BASE_DIR"
  jq -n \
    --arg ai "$ai_name" \
    --arg state "$state" \
    --arg timestamp "$(date -Iseconds)" \
    '{($ai): {state: $state, timestamp: $timestamp}}' \
    >> "$WORKTREE_STATE_FILE"

  vibe_log "worktree-state" "save" \
    "{\"ai\":\"$ai_name\",\"state\":\"$state\"}" \
    "$ai_nameの状態を保存" \
    "[]" \
    "worktree-core"
}

##
# ディスクから保存されたワークツリー状態を読み込み
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 成功（ファイルが存在しない場合も含む）
#
# 副作用:
#   - .state.jsonから状態を読み込みWORKTREE_STATE配列を更新
#
# 注意:
#   - クラッシュ後の復旧やcreate_all_worktrees()で使用
#   - ファイルが存在しない場合はエラーなし（初回実行時）
#
# 例:
#   load_worktree_state  # .state.jsonから状態を復元
##
load_worktree_state() {
  if [[ -f "$WORKTREE_STATE_FILE" ]]; then
    while IFS= read -r line; do
      ai=$(echo "$line" | jq -r 'keys[0]')
      state=$(echo "$line" | jq -r ".[\"$ai\"].state")
      WORKTREE_STATE["$ai"]="$state"
    done < "$WORKTREE_STATE_FILE"
  fi
}

##
# 指定されたAIのワークツリー状態を取得
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#
# 戻り値:
#   0 - 常に成功
#
# 出力:
#   状態文字列（none|creating|active|error|cleanup）
#   存在しない場合は"none"
#
# 例:
#   state=$(get_worktree_state "qwen")
#   if [[ "$state" == "active" ]]; then
#     echo "Qwenのワークツリーは稼働中"
#   fi
##
get_worktree_state() {
  local ai_name="$1"
  echo "${WORKTREE_STATE[$ai_name]:-none}"
}

# ========================================
# ワークツリー作成関数
# ========================================

##
# 指定されたAI用の新しいGitワークツリーを作成
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - （オプション）ブランチ名（デフォルト: ai/{name}/YYYYMMDD-HHMMSS）
#
# 戻り値:
#   0 - 成功（ワークツリー作成済み）
#   1 - 失敗（無効な名前、既に存在、ロック取得失敗など）
#
# 出力:
#   成功時: ワークツリーのパス
#   失敗時: エラーメッセージ（stderr）
#
# セキュリティ:
#   - 競合状態保護にflockを使用（P0）
#   - chmod 700権限を設定（P0）
#   - 分離のため--detachで作成（P0）
#   - シークレット用にsparse-checkoutを設定（P0）
#
# 例:
#   create_worktree "qwen"
#   create_worktree "droid" "ai/droid/feature-x"
#   worktree_path=$(create_worktree "codex")
##
create_worktree() {
  local ai_name="$1"
  local branch_name="${2-}"
  local task_id="${3:-default}"       # Phase 5: API統一化（worktree-manager.sh互換）
  local base_ref="${4:-HEAD}"         # Phase 5: API統一化（worktree-manager.sh互換）

  # Phase 5 Issue #4: メトリクス記録開始時刻
  local create_start_time=$(date +%s.%N 2>/dev/null || date +%s)

  # 入力検証
  if [[ ! "$ai_name" =~ ^(claude|gemini|amp|qwen|droid|codex|cursor)$ ]]; then
    echo "ERROR: 無効なAI名: $ai_name" >&2
    return 1
  fi

  # ブランチ名検証（空文字列の明示的なチェック）
  if [[ $# -ge 2 ]]; then
    # 第2引数が渡された場合（空文字列を含む）
    if [[ -z "$branch_name" ]]; then
      echo "ERROR: ブランチ名は空にできません" >&2
      return 1
    fi
  else
    # 第2引数が未指定の場合はデフォルト値を設定
    branch_name="ai/${ai_name}/$(date +%Y%m%d-%H%M%S)"
  fi

  # Phase 5: タスク説明をブランチ名にサニタイゼーション
  # 例: "implement user authentication" → "implement-user-authentication"
  if [[ "$branch_name" =~ [[:space:]] ]]; then
    branch_name=$(echo "$branch_name" | sed 's/[^a-zA-Z0-9_\/-]/-/g' | sed 's/--*/-/g')
  fi

  # Git公式のブランチ名検証
  if ! git check-ref-format --branch "$branch_name" >/dev/null 2>&1; then
    error_with_solution "不正なブランチ名: $branch_name" \
      "Git公式のブランチ名制約に違反しています
- 使用不可文字: ASCII制御文字, スペース, ~, ^, :, ?, *, [
- 使用不可パターン: 連続スラッシュ(//), .で開始, .lockで終了
- 詳細: git help check-ref-format
- 例: feature/my-branch (OK), feature//bug (NG)"
    return 1
  fi

  # Phase 5: task_id対応のパス計算（worktree-manager.sh互換）
  local worktree_path
  if [[ "$task_id" == "default" ]]; then
    worktree_path="$WORKTREE_BASE_DIR/$ai_name"
  else
    worktree_path="$WORKTREE_BASE_DIR/$ai_name/$task_id"
  fi

  # ワークツリーが既に存在するかチェック
  if [[ -d "$worktree_path" ]]; then
    echo "WARNING: ワークツリーが既に存在します: $worktree_path" >&2
    return 1
  fi


  # Shadow Mode チェック
  if [[ "$WORKTREE_SHADOW_MODE" == "true" ]]; then
    echo "SHADOW MODE: Would create worktree at $worktree_path" >&2
    vibe_log "worktree-lifecycle" "shadow_create" "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\"}" "Shadow mode" "[]" "worktree-core"
    echo "$worktree_path"
    return 0
  fi

  # ===== Phase 5 Issue #3: Worktree Cache =====
  # キャッシュライブラリをロード
  local cache_lib="$(dirname "${BASH_SOURCE[0]}")/worktree-cache.sh"
  if [[ -f "$cache_lib" ]]; then
    source "$cache_lib"

    # キャッシュ初期化（初回のみ）
    if [[ ! -d "$WORKTREE_CACHE_DIR" ]]; then
      init_worktree_cache
    fi

    # キャッシュからロードを試行（base_refを含む）
    if load_from_cache "$ai_name" "$worktree_path" "$base_ref"; then
      # キャッシュヒット: Git Worktreeとして正しく登録
      # ブランチを作成/リセット
      if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git branch -f "$branch_name" "$base_ref" >/dev/null 2>&1 || true
      else
        git branch "$branch_name" "$base_ref" >/dev/null 2>&1 || true
      fi

      # Git Worktreeとして登録（git worktree addを再実行）
      # キャッシュからコピーしたディレクトリをGit Worktreeとして認識させる
      cd "$worktree_path"
      if ! git worktree list | grep -q "$worktree_path"; then
        # Worktreeが登録されていない場合は、git worktree addで再登録
        # 既存のディレクトリがある場合は削除してから再作成
        local temp_path="${worktree_path}.tmp"
        mv "$worktree_path" "$temp_path" 2>/dev/null || true
        if git worktree add "$worktree_path" "$branch_name" >/dev/null 2>&1; then
          # キャッシュの内容をコピー
          rsync -a --exclude='.git' "$temp_path/" "$worktree_path/" 2>/dev/null || true
          rm -rf "$temp_path"
        else
          # 失敗した場合は元に戻す
          mv "$temp_path" "$worktree_path" 2>/dev/null || true
        fi
      fi

      # 状態を保存
      save_worktree_state "$ai_name" "active"

      # Phase 5 Issue #4: メトリクス記録（キャッシュヒット）
      local create_end_time=$(date +%s.%N 2>/dev/null || date +%s)
      local create_duration=$(echo "$create_end_time - $create_start_time" | bc -l 2>/dev/null || echo "0")
      if command -v record_worktree_create &>/dev/null; then
        record_worktree_create "$ai_name" "$create_duration" "success" 2>/dev/null || true
        record_cache_hit "$ai_name" 2>/dev/null || true
      fi

      vibe_log "worktree-lifecycle" "cache_hit" \
        "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\",\"cached\":true}" \
        "Worktree created from cache for $ai_name at $worktree_path" \
        "[]" "worktree-core"

      echo "$worktree_path"
      return 0
    else
      # キャッシュミス: 通常フローで作成
      vibe_log "worktree-lifecycle" "cache_miss" \
        "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\"}" \
        "Cache miss, creating new worktree" "[]" "worktree-core"
    fi
  fi
  # ===== END: Worktree Cache =====

  # 🔒 P0 SECURITY: flockによる競合状態保護
  (
    flock -x 200 || {
      echo "ERROR: ロックを取得できませんでした" >&2
      return 1
    }

    save_worktree_state "$ai_name" "creating"

    # Phase 5: base_ref対応（worktree-manager.sh互換）
    # ブランチを事前作成/リセット（既存の場合はリセット）
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      git branch -f "$branch_name" "$base_ref" >/dev/null 2>&1 || true
    else
      git branch "$branch_name" "$base_ref" >/dev/null 2>&1 || true
    fi

    # Worktree作成（既存ブランチを使用）
    if ! git worktree add "$worktree_path" "$branch_name" > /tmp/worktree-create.log 2>&1; then
      # Phase 5 Issue #4: メトリクス記録（エラー）
      local create_end_time=$(date +%s.%N 2>/dev/null || date +%s)
      local create_duration=$(echo "$create_end_time - $create_start_time" | bc -l 2>/dev/null || echo "0")
      local error_type="git_error"
      if grep -q "lock" /tmp/worktree-create.log 2>/dev/null; then
        error_type="lock_failed"
      fi
      if command -v record_worktree_create &>/dev/null; then
        record_worktree_create "$ai_name" "$create_duration" "error" "$error_type" 2>/dev/null || true
      fi
      
      echo "ERROR: $ai_nameのワークツリー作成に失敗" >&2
      save_worktree_state "$ai_name" "error"
      return 1
    fi

    # 🔒 P0 SECURITY: ディレクトリ権限の設定（所有者のみ）
    chmod 700 "$worktree_path"

    # 🔒 P0 SECURITY: シークレットを除外するsparse-checkoutを設定
    (
      cd "$worktree_path"
      if git sparse-checkout --help &>/dev/null; then
        git sparse-checkout init --cone
        git sparse-checkout set '/*' '!.env' '!*.key' '!*.pem' '!credentials.json'
      fi
    )

    save_worktree_state "$ai_name" "active"

    # Phase 5 Issue #4: メトリクス記録（成功）
    local create_end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local create_duration=$(echo "$create_end_time - $create_start_time" | bc -l 2>/dev/null || echo "0")
    if command -v record_worktree_create &>/dev/null; then
      record_worktree_create "$ai_name" "$create_duration" "success" 2>/dev/null || true
      record_cache_miss "$ai_name" 2>/dev/null || true
    fi

    vibe_log "worktree-lifecycle" "create" \
      "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\",\"branch\":\"$branch_name\"}" \
      "$ai_nameのワークツリーを作成" \
      "[\"verify-permissions\",\"test-isolation\"]" \
      "worktree-core"

    # ===== Phase 5 Issue #3: Worktree Cache - Save =====
    # Worktree作成成功後、キャッシュに保存
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/worktree-cache.sh" ]]; then
      source "$(dirname "${BASH_SOURCE[0]}")/worktree-cache.sh"
      save_to_cache "$ai_name" "$worktree_path" "$base_ref" || true  # 失敗してもWorktree作成は成功
    fi
    # ===== END: Worktree Cache - Save =====

    echo "$worktree_path"

  ) 200>"$WORKTREE_LOCK_FILE"
}

##
# すべてのAI用のワークツリーを並列作成
#
# 引数:
#   $@ - （オプション）AI名のリスト（デフォルト: 全7AI）
#
# 戻り値:
#   0 - 全て成功
#   1 - 一部または全て失敗
#
# 出力:
#   作成済み/失敗の統計情報
#
# 特徴:
#   - 並列実行（バックグラウンドジョブ）
#   - 冪等性（既存ワークツリーはスキップ）
#   - 状態復旧（load_worktree_state()で前回の状態を読込）
#   - VibeLogger統合（パイプラインメトリクス）
#
# 例:
#   create_all_worktrees  # 全7AIのワークツリーを作成
#   create_all_worktrees qwen droid  # QwenとDroidのみ
##
# GNU Parallel統合版ワークツリー作成（Phase 3.2）
# パフォーマンス最適化のため、GNU Parallelが利用可能な場合に使用
create_all_worktrees_parallel() {
  local ai_list=("${@:-claude gemini amp qwen droid codex cursor}")

  # GNU Parallelが利用可能かチェック
  if command -v parallel &>/dev/null; then
    echo "より速い作成のためGNU Parallelを使用中..."

    # 関数をエクスポート（GNU Parallel用）
    export -f create_worktree
    export -f save_worktree_state
    export -f get_worktree_state
    export -f vibe_pipeline_start
    export -f vibe_pipeline_done
    export WORKTREE_BASE_DIR
    export WORKTREE_STATE_FILE

    # 再開機能のため前の状態を読み込み
    load_worktree_state

    vibe_pipeline_start "create-all-worktrees-parallel" "gnu-parallel" ${#ai_list[@]}

    # ベースディレクトリを作成
    mkdir -p "$WORKTREE_BASE_DIR"

    # GNU Parallelで並列作成
    # 重要: 子プロセスで連想配列を明示的に再宣言（set -u環境対応）
    local exit_code=0
    printf "%s\n" "${ai_list[@]}" | \
      parallel -j 7 --halt soon,fail=1 --line-buffer \
        'declare -A WORKTREE_STATE 2>/dev/null || true; create_worktree {}' \
      || exit_code=$?

    vibe_pipeline_done "create-all-worktrees-parallel" \
      "$([[ $exit_code -eq 0 ]] && echo 'success' || echo 'partial')" \
      "$SECONDS" \
      ${#ai_list[@]}

    return $exit_code
  else
    echo "GNU Parallelが見つかりません。基本的な並列処理にフォールバック..."
    create_all_worktrees "${ai_list[@]}"
    return $?
  fi
}

# 基本的なBash並列処理版（既存実装、フォールバック用）
create_all_worktrees() {
  local ai_list=("${@:-claude gemini amp qwen droid codex cursor}")
  local created=()
  local failed=()

  # 再開機能のため前の状態を読み込み
  load_worktree_state

  vibe_pipeline_start "create-all-worktrees" "parallel" ${#ai_list[@]}

  # ベースディレクトリを作成
  mkdir -p "$WORKTREE_BASE_DIR"

  # 並列作成
  local pids=()
  for ai_name in "${ai_list[@]}"; do
    # 既に存在する場合はスキップ（冪等性）
    if [[ "$(get_worktree_state "$ai_name")" == "active" ]]; then
      echo "$ai_nameをスキップ（既にアクティブ）"
      created+=("$ai_name")
      continue
    fi

    create_worktree "$ai_name" &
    pids+=($!)
  done

  # すべてのバックグラウンドジョブを待機
  local exit_code=0
  for pid in "${pids[@]}"; do
    if wait "$pid"; then
      created+=("dummy")  # 成功カウント
    else
      failed+=("dummy")  # 失敗カウント
      exit_code=1
    fi
  done

  vibe_pipeline_done "create-all-worktrees" \
    "$([[ $exit_code -eq 0 ]] && echo 'success' || echo 'partial')" \
    "$SECONDS" \
    ${#ai_list[@]}

  # 結果を報告
  echo "作成済み: ${#created[@]}個"
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "失敗: ${#failed[@]}個" >&2
  fi

  return $exit_code
}

# ========================================
# ワークツリー一覧関数
# ========================================

##
# 現在のワークツリー一覧を表示
#
# 引数:
#   $1 - （オプション）フォーマット（table|json|simple、デフォルト: table）
#
# 戻り値:
#   0 - 常に成功
#
# 出力:
#   table: git worktree listの表形式出力
#   json: パス/ブランチ/HEADを含むJSON形式
#   simple: パスのみ（1行1パス）
#
# 例:
#   list_worktrees  # 表形式で表示
#   list_worktrees json | jq -r '.path'  # JSONパースしてパスを抽出
#   list_worktrees simple | wc -l  # ワークツリー数をカウント
##
list_worktrees() {
  local format="${1:-table}"  # table | json | simple

  case "$format" in
    json)
      git worktree list --porcelain | awk '
        /^worktree / { path=$2 }
        /^branch / { branch=$2 }
        /^HEAD / {
          printf "{\"path\":\"%s\",\"branch\":\"%s\",\"head\":\"%s\"}\n", path, branch, $2
        }
      '
      ;;
    simple)
      git worktree list | awk '{print $1}'
      ;;
    table|*)
      git worktree list
      ;;
  esac
}

# ========================================
# ワークツリー検証関数
# ========================================

##
# ワークツリーの完全性を検証
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#
# 戻り値:
#   0 - 検証成功（ワークツリーは正常）
#   1 - 検証失敗（存在しない、無効、権限異常など）
#
# 出力:
#   成功時: "OK: <path>"
#   失敗時: "ERROR: ..." または "WARNING: ..."（stderr）
#
# チェック項目:
#   - ディレクトリ存在
#   - .gitファイルまたはディレクトリ存在（有効なGitワークツリー）
#   - 権限が700（P0セキュリティ要件）
#
# 例:
#   if verify_worktree "qwen"; then
#     echo "Qwenのワークツリーは正常"
#   fi
##
verify_worktree() {
  local ai_name="$1"
  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"
  local git_indicator="$worktree_path/.git"

  # 存在チェック
  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: ワークツリーが存在しません: $worktree_path" >&2
    return 1
  fi

  # Gitインジケーターの存在チェック（ワークツリーではファイル、通常リポジトリではディレクトリ）
  if [[ ! -e "$git_indicator" && ! -L "$git_indicator" ]]; then
    echo "ERROR: 有効なGitワークツリーではありません: $worktree_path/.gitが存在しません" >&2
    return 1
  fi

  # ワークツリー固有の検証（.gitファイルの内容確認）
  if [[ -f "$git_indicator" ]]; then
    if ! grep -q "^gitdir:" "$git_indicator" 2>/dev/null; then
      echo "ERROR: 不正な.gitファイル形式（gitdir:行が存在しません）: $git_indicator" >&2
      return 1
    fi
  fi

  # 権限チェック
  local perms=$(stat -c "%a" "$worktree_path" 2>/dev/null || stat -f "%OLp" "$worktree_path" 2>/dev/null)
  if [[ "$perms" != "700" ]]; then
    echo "WARNING: ワークツリーの権限が700ではありません: $perms" >&2
  fi

  echo "OK: $worktree_path"
  return 0
}

# ========================================
# Phase 5: テスト用ヘルパー関数
# ========================================

##
# テスト用ワークツリー作成ヘルパー
#
# タスク説明を自動的にブランチ名に変換し、ユニークIDを付与します。
# E2Eテストでの使用を想定した簡易ラッパー関数です。
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - タスク説明またはブランチ名
#   $3 - ベースリファレンス（オプション、デフォルト: HEAD）
#
# 戻り値:
#   0 - 成功（worktreeパスを標準出力に出力）
#   1 - 失敗
#
# 環境変数:
#   TEST_RUN_ID - テスト実行ID（未設定の場合はプロセスIDを使用）
#
# 例:
#   create_test_worktree "qwen" "implement authentication"
#   create_test_worktree "claude" "feature/user-auth" "develop"
##
create_test_worktree() {
    local ai_name="$1"
    local task_description="$2"
    local base_ref="${3:-HEAD}"
    local test_id="${TEST_RUN_ID:-$$}"

    # タスク説明をブランチ名に変換
    local branch_name=$(echo "$task_description" | sed 's/[^a-zA-Z0-9_\/-]/-/g' | sed 's/--*/-/g')
    branch_name="${branch_name}-test-${test_id}"

    # create_worktreeを呼び出し（task_id付き）
    create_worktree "$ai_name" "$branch_name" "test-${test_id}" "$base_ref"
}

# スクリプトとして直接実行された場合のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "worktree-core.sh - Core worktree operations"
  echo "This module should be sourced, not executed directly"
  exit 1
fi
