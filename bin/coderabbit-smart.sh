#!/bin/bash
#
# CodeRabbit Smart Wrapper - 5AI統合版
# 選択的品質ゲートとレート制限管理機能付き
#

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RATE_LIMIT_FILE="$PROJECT_ROOT/.coderabbit_last_run"
CONFIG_FILE="$PROJECT_ROOT/config/coderabbit-rules.yaml"
LOG_DIR="$PROJECT_ROOT/logs/coderabbit"
CACHE_DIR="$PROJECT_ROOT/.coderabbit-cache"

# ディレクトリ作成
mkdir -p "$LOG_DIR" "$CACHE_DIR"

# ログ関数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "$LOG_DIR/coderabbit.log"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" | tee -a "$LOG_DIR/coderabbit.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_DIR/coderabbit.log"
}

# レート制限チェック
check_rate_limit() {
    if [[ -f "$RATE_LIMIT_FILE" ]]; then
        local last_run=$(cat "$RATE_LIMIT_FILE")
        local current_time=$(date +%s)
        local elapsed=$((current_time - last_run))
        local min_interval=900  # 15分 = 900秒

        if [[ $elapsed -lt $min_interval ]]; then
            local remaining=$((min_interval - elapsed))
            local minutes=$((remaining / 60))
            local seconds=$((remaining % 60))
            log_warn "レート制限中: あと${minutes}分${seconds}秒待機が必要です"
            return 1
        fi
    fi
    return 0
}

# ファイル変更量チェック
check_change_size() {
    local uncommitted_lines=$(git diff --numstat 2>/dev/null | awk '{sum += $1 + $2} END {print sum + 0}')
    local staged_lines=$(git diff --cached --numstat 2>/dev/null | awk '{sum += $1 + $2} END {print sum + 0}')
    local total_lines=$((uncommitted_lines + staged_lines))

    log_info "変更量: ${total_lines}行 (uncommitted: ${uncommitted_lines}, staged: ${staged_lines})"
    echo "$total_lines"
}

# 実行判定
should_run_review() {
    local force=${1:-false}
    local change_lines=$2

    if [[ "$force" == "true" ]]; then
        log_info "強制実行モード"
        return 0
    fi

    # 変更量ベースの判定
    if [[ $change_lines -lt 10 ]]; then
        log_info "変更量が少ないためスキップ (${change_lines}行 < 10行)"
        return 1
    elif [[ $change_lines -ge 100 ]]; then
        log_info "大規模変更のため必須実行 (${change_lines}行 >= 100行)"
        return 0
    else
        log_info "中規模変更のため推奨実行 (${change_lines}行)"
        return 0
    fi
}

# セキュリティ関連ファイル検出
check_security_files() {
    local security_patterns=(
        "auth" "jwt" "token" "password" "secret" "key"
        "login" "session" "crypto" "hash" "security"
        ".env" "config" "credential"
    )

    local changed_files=$(git diff --name-only HEAD)
    for pattern in "${security_patterns[@]}"; do
        if echo "$changed_files" | grep -i "$pattern" >/dev/null; then
            log_info "セキュリティ関連ファイル検出: 必須レビュー"
            return 0
        fi
    done
    return 1
}

# キャッシュキー生成
generate_cache_key() {
    local type="$1"
    local base_commit="$2"
    local custom_config="$3"
    local prompt_only="$4"

    local head_sha=$(git rev-parse HEAD 2>/dev/null || echo "no-git")
    local config_hash=$(echo "$custom_config" | sha1sum | cut -d' ' -f1)

    echo "${type}|${base_commit}|${head_sha}|${config_hash}|${prompt_only}" | sha1sum | cut -d' ' -f1
}

# キャッシュチェック
check_cache() {
    local cache_key="$1"
    local cache_file="$CACHE_DIR/${cache_key}.json"

    if [[ -f "$cache_file" ]]; then
        # 1時間以内のキャッシュは有効
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 3600 ]]; then
            log_info "キャッシュヒット: ${cache_key}"
            cat "$cache_file"
            return 0
        fi
    fi
    return 1
}

# キャッシュ保存
save_cache() {
    local cache_key="$1"
    local output="$2"
    local cache_file="$CACHE_DIR/${cache_key}.json"

    echo "$output" > "$cache_file"
    log_info "キャッシュ保存: ${cache_key}"
}

# CodeRabbitバージョン検出
check_coderabbit_version() {
    if command -v coderabbit >/dev/null 2>&1; then
        local version=$(coderabbit --version 2>/dev/null || echo "unknown")
        log_info "CodeRabbit CLI バージョン: $version"
        return 0
    else
        log_warn "CodeRabbit CLI not found, using 'cr' command"
        return 1
    fi
}

# CodeRabbit実行
run_coderabbit() {
    local mode="$1"
    local type="$2"
    local base_commit="$3"
    local custom_config="$4"
    local use_cache="$5"

    # キャッシュキー生成
    local cache_key=$(generate_cache_key "$type" "$base_commit" "$custom_config" "$mode")

    # キャッシュチェック
    if [[ "$use_cache" == "true" ]] && check_cache "$cache_key"; then
        return 0
    fi

    # コマンド構築
    local cmd="cr"
    local args=()

    # CLI可用性チェック
    if check_coderabbit_version; then
        cmd="coderabbit"
    fi

    # モード設定
    if [[ "$mode" == "--prompt-only" ]]; then
        args+=("--prompt-only")
    elif [[ "$mode" == "--plain" ]]; then
        args+=("--plain")
    fi

    # タイプ設定
    if [[ -n "$type" && "$type" != "auto" ]]; then
        args+=("--type" "$type")
    fi

    # ベースコミット設定
    if [[ -n "$base_commit" ]]; then
        args+=("--base-commit" "$base_commit")
    else
        # デフォルトブランチを自動検出（masterまたはmain）
        local default_branch
        default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || git branch --show-current)
        [[ -z "$default_branch" ]] && default_branch="master"
        args+=("--base" "$default_branch")
    fi

    # カスタム設定
    if [[ -n "$custom_config" ]]; then
        if [[ -f "$custom_config" ]]; then
            args+=("-c" "@$custom_config")
        else
            args+=("-c" "$custom_config")
        fi
    fi

    log_info "CodeRabbit実行開始: $cmd review ${args[*]}"

    # タイムスタンプ記録
    date +%s > "$RATE_LIMIT_FILE"

    # 実行 (review subcommand必須)
    local output_file="$LOG_DIR/coderabbit_output_$(date +%Y%m%d_%H%M%S).log"
    if "$cmd" review "${args[@]}" 2>&1 | tee "$output_file"; then
        log_info "CodeRabbit実行完了"

        # キャッシュ保存
        if [[ "$use_cache" == "true" ]]; then
            save_cache "$cache_key" "$(cat "$output_file")"
        fi

        return 0
    else
        log_error "CodeRabbit実行失敗"
        return 1
    fi
}

# 使用方法表示
show_usage() {
    cat << EOF
CodeRabbit Smart Wrapper - 5AI統合版

使用方法:
  $0 [オプション]

P0機能（新規実装）:
  --prompt-only        AI専用最小出力（40-80%トークン削減）
  --type TYPE          レビュー範囲指定 (all|committed|uncommitted)
  --base-commit HASH   特定コミットからの差分レビュー
  -c CONFIG            カスタムルール (ファイルパス or インライン)

既存オプション:
  --force              強制実行（レート制限・変更量無視）
  --plain              プレインモード（デフォルト）
  --check              実行判定のみ（実際には実行しない）
  --status             レート制限状態確認
  --no-cache           キャッシュ無効化
  --help               このヘルプを表示

エイリアス:
  crcheck   = $0
  crforce   = $0 --force
  crstatus  = $0 --status

例:
  $0                                        # 自動判定で実行
  $0 --prompt-only --type uncommitted      # 未コミット分のみ、AI専用出力
  $0 --type committed --base-commit main    # mainからの差分レビュー
  $0 -c games/eva_tetris/rules.yaml        # カスタムルール適用
  $0 --force --no-cache                     # キャッシュ無効化で強制実行
  crforce                                   # エイリアス使用
EOF
}

# メイン処理
main() {
    local force=false
    local mode="--prompt-only"  # デフォルトはAI agent互換の--prompt-only
    local check_only=false
    local status_only=false
    local type="auto"
    local base_commit=""
    local custom_config=""
    local use_cache=true

    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                shift
                ;;
            --plain)
                mode="--plain"
                shift
                ;;
            --prompt-only)
                mode="--prompt-only"
                shift
                ;;
            --type)
                type="$2"
                if [[ ! "$type" =~ ^(all|committed|uncommitted)$ ]]; then
                    log_error "無効なtype: $type (all|committed|uncommitted)"
                    exit 1
                fi
                shift 2
                ;;
            --base-commit)
                base_commit="$2"
                shift 2
                ;;
            -c)
                custom_config="$2"
                shift 2
                ;;
            --no-cache)
                use_cache=false
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            --status)
                status_only=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # ステータス確認のみ
    if [[ "$status_only" == "true" ]]; then
        if check_rate_limit; then
            echo "✅ レート制限なし - 実行可能"
        else
            echo "⏰ レート制限中 - 実行不可"
        fi
        exit 0
    fi

    # 変更量チェック
    check_change_size > /tmp/change_info.tmp 2>&1
    local change_lines=$(git diff --numstat 2>/dev/null | awk '{sum += $1 + $2} END {print sum + 0}')
    local staged_lines=$(git diff --cached --numstat 2>/dev/null | awk '{sum += $1 + $2} END {print sum + 0}')
    change_lines=$((change_lines + staged_lines))

    # セキュリティファイルチェック
    local is_security=false
    if check_security_files; then
        is_security=true
        log_info "セキュリティ関連ファイル検出"
    fi

    # Smart Wrapper実行判定（typeが明示されていない場合のみ）
    local should_run=false
    if [[ "$type" != "auto" ]]; then
        # typeが指定されている場合は常に実行
        should_run=true
        log_info "type指定により実行: $type"
    elif [[ "$is_security" == "true" ]] || should_run_review "$force" "$change_lines"; then
        should_run=true
        # typeが未指定の場合は従来通りuncommittedを使用
        type="uncommitted"
    fi

    if [[ "$check_only" == "true" ]]; then
        if [[ "$should_run" == "true" ]]; then
            echo "✅ 実行推奨: 変更量${change_lines}行"
            echo "📋 type: $type"
            [[ -n "$base_commit" ]] && echo "🔄 base-commit: $base_commit"
            [[ -n "$custom_config" ]] && echo "⚙️ custom-config: $custom_config"
            [[ "$mode" == "--prompt-only" ]] && echo "🤖 prompt-only: enabled"
            [[ "$is_security" == "true" ]] && echo "🔒 セキュリティ関連変更あり"
        else
            echo "⏭️  実行スキップ: 変更量${change_lines}行"
        fi
        exit 0
    fi

    # レート制限チェック
    if [[ "$force" != "true" ]] && ! check_rate_limit; then
        exit 1
    fi

    # 実行判定
    if [[ "$should_run" != "true" ]]; then
        log_info "実行条件を満たしていません"
        exit 0
    fi

    # CodeRabbit実行
    run_coderabbit "$mode" "$type" "$base_commit" "$custom_config" "$use_cache"
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi