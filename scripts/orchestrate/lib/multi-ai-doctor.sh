#!/usr/bin/env bash
# ヘルスチェックと診断ユーティリティ

run_doctor_checks() {
  local checks_passed=0
  local checks_failed=0
  local checks_warned=0

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Multi-AI Doctor - システムヘルスチェック"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # チェック1: Gitバージョン
  echo -n "Gitバージョン（2.15+）... "
  git_version=$(git --version | sed -E 's/git version ([0-9]+\.[0-9]+).*/\1/')
  if [[ $(echo "$git_version 2.15" | tr ' ' '\n' | sort -V | head -n1) == "2.15" ]]; then
    echo "✓ $git_version"
    ((checks_passed++))
  else
    echo "✗ $git_version（古すぎます）"
    ((checks_failed++))
  fi

  # チェック2: ディスク容量
  echo -n "ディスク容量（10GB+）... "
  available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
  if [[ $available_gb -ge 10 ]]; then
    echo "✓ ${available_gb}GB"
    ((checks_passed++))
  elif [[ $available_gb -ge 5 ]]; then
    echo "⚠ ${available_gb}GB（低い）"
    ((checks_warned++))
  else
    echo "✗ ${available_gb}GB（不十分）"
    ((checks_failed++))
  fi

  # チェック3: 必須ツール
  for tool in flock jq yq; do
    echo -n "ツール: $tool... "
    if command -v $tool &>/dev/null; then
      echo "✓ インストール済み"
      ((checks_passed++))
    else
      echo "✗ 未インストール"
      ((checks_failed++))
    fi
  done

  # チェック4: ワークツリー状態
  echo -n "ワークツリー状態... "
  if [[ -f "$WORKTREE_STATE_FILE" ]]; then
    echo "✓ 状態ファイルが存在"
    ((checks_passed++))
  else
    echo "⚠ 状態ファイルなし（初回実行）"
    ((checks_warned++))
  fi

  # チェック5: 古いワークツリー
  echo -n "古いワークツリー... "
  stale_count=$(git worktree list | grep -c "prunable" || echo 0)
  if [[ $stale_count -eq 0 ]]; then
    echo "✓ なし"
    ((checks_passed++))
  else
    echo "⚠ ${stale_count}個見つかりました（実行: git worktree prune）"
    ((checks_warned++))
  fi

  # チェック6: git-rerere有効化
  echo -n "git-rerere有効... "
  if git config --get rerere.enabled | grep -q "true"; then
    echo "✓ 有効"
    ((checks_passed++))
  else
    echo "⚠ 無効（競合解決に推奨）"
    ((checks_warned++))
  fi

  # サマリー
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "結果: ✓ $checks_passed | ⚠ $checks_warned | ✗ $checks_failed"

  if [[ $checks_failed -eq 0 ]]; then
    echo "ステータス: 🟢 正常 - ワークツリー準備完了"
    return 0
  elif [[ $checks_failed -le 2 ]]; then
    echo "ステータス: 🟡 注意 - 続行前に問題を修正"
    return 1
  else
    echo "ステータス: 🔴 異常 - ワークツリー準備未完了"
    return 2
  fi
}

# 自動修正関数
auto_fix() {
  echo "自動修正を試みています..."

  # git-rerereを有効化
  if ! git config --get rerere.enabled | grep -q "true"; then
    git config rerere.enabled true
    git config rerere.autoupdate true
    echo "✓ git-rerereを有効化しました"
  fi

  # 古いワークツリーを削除
  git worktree prune
  echo "✓ 古いワークツリーを削除しました"

  echo "再度doctorを実行して修正を確認してください"
}

# メイン実行
source "$(dirname "${BASH_SOURCE[0]}")/worktree-core.sh"

case "${1:-check}" in
  check)
    run_doctor_checks
    ;;
  fix)
    auto_fix
    ;;
  *)
    echo "使用法: $0 {check|fix}"
    exit 1
    ;;
esac
