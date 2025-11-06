#!/usr/bin/env bash
# ヘルスチェックと診断ユーティリティ（簡略版）

# メイン実行
source "$(dirname "${BASH_SOURCE[0]}")/worktree-core.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Multi-AI Doctor - システムヘルスチェック"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

checks_passed=0
checks_failed=0
checks_warned=0

# チェック1: Gitバージョン
printf "%-40s" "Gitバージョン（2.15+）... "
git_version=$(git --version | sed -E 's/git version ([0-9]+\.[0-9]+).*/\1/')
if [[ $(echo "$git_version 2.15" | tr ' ' '\n' | sort -V | head -n1) == "2.15" ]]; then
  echo "✓ $git_version"
  ((checks_passed++))
else
  echo "✗ $git_version"
  ((checks_failed++))
fi

# チェック2: ディスク容量
printf "%-40s" "ディスク容量（10GB+）... "
available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $available_gb -ge 10 ]]; then
  echo "✓ ${available_gb}GB"
  ((checks_passed++))
elif [[ $available_gb -ge 5 ]]; then
  echo "⚠ ${available_gb}GB"
  ((checks_warned++))
else
  echo "✗ ${available_gb}GB"
  ((checks_failed++))
fi

# チェック3: 必須ツール
for tool in flock jq yq; do
  printf "%-40s" "ツール: $tool... "
  if command -v $tool &>/dev/null; then
    echo "✓ インストール済み"
    ((checks_passed++))
  else
    echo "✗ 未インストール"
    ((checks_failed++))
  fi
done

# チェック4: ワークツリー状態
printf "%-40s" "ワークツリー状態... "
if [[ -f "$WORKTREE_STATE_FILE" ]]; then
  echo "✓ 状態ファイルあり"
  ((checks_passed++))
else
  echo "⚠ 状態ファイルなし"
  ((checks_warned++))
fi

# チェック5: 古いワークツリー
printf "%-40s" "古いワークツリー... "
stale_count=$(git worktree list 2>/dev/null | grep -c "prunable" || echo 0)
if [[ $stale_count -eq 0 ]]; then
  echo "✓ なし"
  ((checks_passed++))
else
  echo "⚠ ${stale_count}個"
  ((checks_warned++))
fi

# チェック6: git-rerere
printf "%-40s" "git-rerere有効... "
if git config --get rerere.enabled 2>/dev/null | grep -q "true"; then
  echo "✓ 有効"
  ((checks_passed++))
else
  echo "⚠ 無効"
  ((checks_warned++))
fi

# サマリー
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "結果: ✓ $checks_passed | ⚠ $checks_warned | ✗ $checks_failed"

if [[ $checks_failed -eq 0 ]]; then
  echo "ステータス: 🟢 正常"
  exit 0
elif [[ $checks_failed -le 2 ]]; then
  echo "ステータス: 🟡 注意"
  exit 1
else
  echo "ステータス: 🔴 異常"
  exit 2
fi
