#!/usr/bin/env bash
# worktree-preflight-check.sh - Git Worktrees統合のプリフライトチェック
# フェーズ0: 環境検証とセキュリティチェック

set -euo pipefail

# 非対話モード（環境変数で設定）
NON_INTERACTIVE=${NON_INTERACTIVE:-false}

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# チェック結果カウンタ
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# ログ関数
log_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNING++))
}

log_info() {
    echo -e "ℹ $1"
}

# ========================================
# 0.1 環境要件チェック
# ========================================

echo "=========================================="
echo "フェーズ0.1: 環境要件チェック"
echo "=========================================="
echo ""

# Gitバージョンチェック
log_info "Gitバージョンをチェック中..."
if command -v git &>/dev/null; then
    git_version=$(git --version | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
    required_version="2.15.0"

    if [[ $(printf '%s\n' "$required_version" "$git_version" | sort -V | head -n1) == "$required_version" ]]; then
        log_success "Git $git_version (>= $required_version が必要)"
    else
        log_error "Git $git_version は要件を満たしていません（>= $required_version が必要）"
    fi
else
    log_error "Gitがインストールされていません"
fi

# ディスク容量チェック
log_info "ディスク容量をチェック中..."
available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $available_gb -ge 10 ]]; then
    log_success "ディスク容量: ${available_gb}GB利用可能 (>= 10GB推奨)"
elif [[ $available_gb -ge 5 ]]; then
    log_warning "ディスク容量: ${available_gb}GB利用可能（10GB推奨、継続可能）"
else
    log_error "ディスク容量不足: ${available_gb}GB利用可能（10GB推奨）"
fi

# 必須ツールチェック
log_info "必須ツールをチェック中..."
for tool in flock jq; do
    if command -v "$tool" &>/dev/null; then
        log_success "$tool がインストール済み"
    else
        log_error "$tool が見つかりません（インストール: sudo apt install $tool または brew install $tool）"
    fi
done

# yqはオプショナル（YAML操作用）
if command -v yq &>/dev/null; then
    log_success "yq がインストール済み（オプション）"
else
    log_warning "yq が見つかりません（オプション、YAML操作で推奨）"
fi

# Bashバージョンチェック
log_info "Bashバージョンをチェック中..."
bash_version=${BASH_VERSION%%.*}
if [[ $bash_version -ge 4 ]]; then
    log_success "Bash $BASH_VERSION (>= 4.0が必要)"
else
    log_error "Bash $BASH_VERSION は要件を満たしていません（>= 4.0が必要）"
fi

echo ""

# ========================================
# 0.2 リポジトリ状態検証
# ========================================

echo "=========================================="
echo "フェーズ0.2: リポジトリ状態検証"
echo "=========================================="
echo ""

# Gitリポジトリ内にいるかチェック
log_info "Gitリポジトリの存在をチェック中..."
if git rev-parse --is-inside-work-tree &>/dev/null; then
    log_success "Gitリポジトリ内で実行中"
else
    log_error "Gitリポジトリ内で実行してください"
    exit 1
fi

# クリーンな作業ディレクトリチェック
log_info "作業ディレクトリの状態をチェック中..."
if [[ -z $(git status --porcelain) ]]; then
    log_success "作業ディレクトリがクリーンです"
else
    log_warning "作業ディレクトリにコミットされていない変更があります："
    git status --short | head -n 5
    echo ""
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -p "続行しますか？ (y/N): " confirm
        if [[ $confirm != "y" && $confirm != "Y" ]]; then
            echo "中止しました"
            exit 1
        fi
    else
        log_info "非対話モード: 警告を記録して続行します"
    fi
fi

# 既存ワークツリーチェック
log_info "既存ワークツリーをチェック中..."
existing_worktrees=$(git worktree list 2>/dev/null | wc -l)
if [[ $existing_worktrees -eq 1 ]]; then
    log_success "既存ワークツリーなし（メインリポジトリのみ）"
elif [[ $existing_worktrees -gt 1 ]]; then
    log_warning "$((existing_worktrees - 1))個の既存ワークツリーが見つかりました："
    git worktree list
    echo ""
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -p "続行前にすべてのワークツリーを削除しますか？ (y/N): " confirm
        if [[ $confirm == "y" || $confirm == "Y" ]]; then
            git worktree prune
            log_success "既存ワークツリーを削除しました"
        fi
    else
        log_info "非対話モード: 既存ワークツリーを保持します"
    fi
fi

# メインブランチ検証
log_info "現在のブランチをチェック中..."
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [[ $current_branch == "main" || $current_branch == "master" ]]; then
    log_success "メインブランチにいます（$current_branch）"
else
    log_warning "メインブランチにいません（現在: $current_branch）"
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -p "mainブランチに切り替えますか？ (y/N): " confirm
        if [[ $confirm == "y" || $confirm == "Y" ]]; then
            if git checkout main 2>/dev/null || git checkout master 2>/dev/null; then
                log_success "メインブランチに切り替えました"
            else
                log_error "メインブランチへの切り替えに失敗しました"
            fi
        fi
    else
        log_info "非対話モード: 現在のブランチを保持します"
    fi
fi

echo ""

# ========================================
# 0.3 セキュリティ事前チェック
# ========================================

echo "=========================================="
echo "フェーズ0.3: セキュリティ事前チェック"
echo "=========================================="
echo ""

# ファイル権限チェック
log_info "ファイル権限設定をチェック中..."
test_dir=$(mktemp -d)
chmod 700 "$test_dir"
perms=$(stat -c "%a" "$test_dir" 2>/dev/null || stat -f "%OLp" "$test_dir" 2>/dev/null)
rm -rf "$test_dir"

if [[ $perms == "700" ]]; then
    log_success "chmod 700が正常に動作します"
else
    log_error "chmod 700が期待通りに動作しません（取得: $perms）"
fi

# Sparse Checkoutサポートチェック
log_info "Git sparse-checkoutサポートをチェック中..."
if git sparse-checkout --help &>/dev/null; then
    log_success "Git sparse-checkoutがサポートされています"
else
    log_warning "Git sparse-checkoutがサポートされていません（Gitのアップグレードを推奨）"
fi

# ロックファイルサポートチェック
log_info "flock（ファイルロック）サポートをチェック中..."
lock_file=$(mktemp)
if flock -n "$lock_file" echo "test" &>/dev/null; then
    log_success "flockが正常に動作します"
    rm -f "$lock_file"
else
    log_error "このファイルシステムでflockがサポートされていません"
    rm -f "$lock_file"
fi

echo ""

# ========================================
# 最終結果
# ========================================

echo "=========================================="
echo "プリフライトチェック結果"
echo "=========================================="
echo ""
echo -e "${GREEN}成功: $CHECKS_PASSED${NC}"
echo -e "${YELLOW}警告: $CHECKS_WARNING${NC}"
echo -e "${RED}失敗: $CHECKS_FAILED${NC}"
echo ""

if [[ $CHECKS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ すべての必須チェックに合格しました${NC}"
    echo ""
    echo "次のステップ: フェーズ0.5（MVP検証）を実行してください"
    echo "  bash scripts/worktree-mvp-validation.sh"
    exit 0
else
    echo -e "${RED}✗ $CHECKS_FAILED 個のチェックに失敗しました${NC}"
    echo ""
    echo "上記のエラーを修正してから再試行してください"
    exit 1
fi
