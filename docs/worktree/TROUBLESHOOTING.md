# Git Worktrees トラブルシューティングガイド

**バージョン:** v1.0
**最終更新:** 2025-11-08

---

## 📋 目次

1. [よくある問題と解決策](#よくある問題と解決策)
2. [エラーコード一覧](#エラーコード一覧)
3. [FAQ](#faq)
4. [デバッグ方法](#デバッグ方法)
5. [緊急時の対応](#緊急時の対応)

---

## よくある問題と解決策

### 問題1: Worktreeが自動削除されない

**症状:**
```
ERROR: Failed to remove worktree 'worktrees/qwen'
fatal: 'remove' refuses to remove worktrees with modifications
```

**原因:**
- Worktree内に未コミットの変更がある
- Phase 0以前のtrap設定タイミング問題（修正済み）

**解決策:**

```bash
# オプション1: 手動で強制削除
git worktree remove worktrees/qwen --force

# オプション2: 変更をコミット後に削除
cd worktrees/qwen
git add .
git commit -m "Save changes"
cd ../..
git worktree remove worktrees/qwen

# オプション3: 自動修正スクリプト実行
bash scripts/test-worktree-recovery.sh
```

**予防策:**
- Phase 0修正後は`setup_worktree_cleanup_trap()`を明示的に呼び出す
- `cleanup_worktree()`は自動的に`--force`にフォールバック

---

### 問題2: "Worktree already exists" エラー

**症状:**
```
ERROR [WT102]: Worktree already exists for AI 'qwen'

What: Cannot create worktree because it already exists
Why: A worktree at 'worktrees/qwen' is already registered
How: Clean up the existing worktree first or use a different path
```

**原因:**
- 前回の実行が異常終了してWorktreeが残っている
- 複数のワークフローが同時実行されている

**解決策:**

```bash
# オプション1: 既存Worktreeを確認
git worktree list

# オプション2: クリーンアップ実行
bash scripts/orchestrate/lib/worktree-cleanup.sh
cleanup_worktree "qwen"

# オプション3: 全Worktreeをクリーンアップ
cleanup_all_worktrees

# オプション4: 自動リカバリー
source scripts/orchestrate/lib/worktree-execution.sh
recover_orphaned_worktrees --auto
```

**予防策:**
- ワークフロー終了時に必ず`cleanup_all_worktrees()`を呼び出す
- Trapを適切に設定する（`setup_worktree_cleanup_trap()`）

---

### 問題3: 並列実行でWorktree作成が失敗する

**症状:**
```
ERROR [WT401]: Failed to acquire worktree lock
What: Lock file already exists at '/tmp/multi-ai-worktree.lock'
```

**原因:**
- 並列度制限を超えた実行
- 前回のロックファイルが残っている

**解決策:**

```bash
# オプション1: ロックファイルを手動削除
rm -f /tmp/multi-ai-worktree.lock

# オプション2: 並列度を調整
export MAX_PARALLEL_WORKTREES=2
create_worktrees_parallel claude gemini qwen droid

# オプション3: 古いロックを自動クリーンアップ
source scripts/orchestrate/lib/worktree-core.sh
cleanup_stale_locks
```

**予防策:**
- 環境に応じて`MAX_PARALLEL_WORKTREES`を設定
  - ローカル: 4-7
  - CI環境: 2-4
  - 低スペック: 1-2

---

### 問題4: マージ競合が解決できない

**症状:**
```
ERROR [WT302]: Merge conflict detected in 'worktrees/qwen'
CONFLICT (content): Merge conflict in src/main.sh
```

**原因:**
- 複数のAIが同じファイルを異なる方法で変更
- ベースブランチとAIブランチで同じ行が変更されている

**解決策:**

```bash
# オプション1: 競合を可視化
source scripts/orchestrate/lib/worktree-merge.sh
visualize_merge_conflicts "qwen"

# オプション2: AIブランチを優先してマージ
merge_worktree_branch "qwen" "main" "theirs"

# オプション3: ベースブランチを優先してマージ
merge_worktree_branch "qwen" "main" "ours"

# オプション4: 手動で競合解決
cd worktrees/qwen
# ファイルを編集して競合を解決
git add .
git commit -m "Resolve merge conflicts"
cd ../..
merge_worktree_branch "qwen" "main" "no-ff"
```

**マージ戦略の選択:**

| 戦略 | 使用場面 |
|------|---------|
| `theirs` | AIの変更を信頼する場合 |
| `ours` | ベースブランチを優先する場合 |
| `best` | 品質スコアで自動選択 |
| `manual` | 手動で解決したい場合 |

---

### 問題5: 状態ファイルが破損している

**症状:**
```
ERROR [WT501]: Invalid state transition from 'active' to 'creating'
parse error: Invalid JSON
```

**原因:**
- 状態ファイル（`.state.json`）が不正なJSON
- ディスク容量不足で書き込み失敗
- 同時書き込みによる破損

**解決策:**

```bash
# オプション1: 状態ファイルを検証
cat worktrees/.state.json | jq '.'

# オプション2: 状態ファイルをリセット
rm -f worktrees/.state.json
source scripts/orchestrate/lib/worktree-state.sh
reset_all_worktree_states

# オプション3: 破損行を削除
# 各行が独立したJSONなので、破損行のみ削除可能
grep -v "invalid" worktrees/.state.json > worktrees/.state.json.tmp
mv worktrees/.state.json.tmp worktrees/.state.json
```

**予防策:**
- 定期的にバックアップ（`cp worktrees/.state.json worktrees/.state.json.bak`）
- ディスク容量を監視

---

### 問題6: タイムアウトエラー

**症状:**
```
ERROR: Command timed out after 600 seconds
Exit code: 124
```

**原因:**
- AI実行時間がタイムアウト値を超えた
- タイムアウト設定が短すぎる

**解決策:**

```bash
# オプション1: タイムアウトを延長
execute_in_worktree "droid" "bash scripts/heavy-task.sh" 1800  # 30分

# オプション2: 環境変数で設定
export CLAUDE_MCP_TIMEOUT=1200s
execute_in_worktree "claude" "bash scripts/analysis.sh"

# オプション3: タイムアウトを無効化（推奨しない）
execute_in_worktree "qwen" "bash scripts/task.sh" 0
```

**タイムアウト推奨値:**

| AI | 軽量タスク | 標準タスク | 重量タスク |
|----|----------|----------|----------|
| Qwen | 300s | 600s | 900s |
| Claude | 300s | 600s | 1200s |
| Gemini | 300s | 900s | 1500s |
| Droid | 600s | 1200s | 1800s |

---

### 問題7: 孤立ブランチが残る

**症状:**
```bash
$ git branch | grep "ai/"
  ai/qwen/20251108-120000
  ai/droid/20251108-120100
  ai/claude/20251108-120200
```

**原因:**
- Worktreeは削除されたがブランチが残っている
- クリーンアップ処理が途中で中断された

**解決策:**

```bash
# オプション1: 孤立ブランチを検出して削除
source scripts/orchestrate/lib/worktree-execution.sh
detect_orphaned_branches
recover_orphaned_branches --auto

# オプション2: 手動で削除
git branch -D ai/qwen/20251108-120000

# オプション3: 正規表現で一括削除（注意！）
git branch | grep "ai/" | xargs -r git branch -D
```

**予防策:**
- `cleanup_worktree()`はブランチも自動削除する
- 定期的に`recover_orphaned_branches`を実行

---

### 問題8: 非対話モードで手動マージ戦略が使えない

**症状:**
```
ERROR: manual merge strategy requires interactive mode
```

**原因:**
- CI環境や`NON_INTERACTIVE=true`で手動マージが実行された
- Phase 2.3以前のバージョン

**解決策:**

```bash
# オプション1: Phase 2.3以降にアップグレード
# manual戦略は自動的にtheirs戦略にフォールバックする

# オプション2: 明示的にtheirs戦略を使用
merge_worktree_branch "qwen" "main" "theirs"

# オプション3: 非対話モードを無効化（ローカル環境のみ）
unset NON_INTERACTIVE
merge_worktree_branch "qwen" "main" "manual"
```

---

### 問題9: jqコマンドが見つからない

**症状:**
```
ERROR [WT902]: Dependency 'jq' not found
```

**原因:**
- jqがインストールされていない
- PATHが設定されていない

**解決策:**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq

# macOS
brew install jq

# RHEL/CentOS
sudo yum install -y jq

# インストール確認
jq --version
```

---

### 問題10: ディスク容量不足

**症状:**
```
ERROR: No space left on device
fatal: could not create work tree dir 'worktrees/qwen'
```

**原因:**
- 7つのWorktreeを作成するとディスク使用量が増加
- 一時ファイルやログが蓄積

**解決策:**

```bash
# オプション1: 使用量を確認
du -sh worktrees/

# オプション2: 不要なWorktreeを削除
cleanup_all_worktrees

# オプション3: 古いログを削除
find logs/worktree-* -type f -mtime +30 -delete

# オプション4: Git garbage collection
git gc --aggressive
git prune
```

**ディスク使用量の目安:**
- 1 Worktree: 約50-100MB
- 7 Worktrees: 約350-700MB
- ログ（1週間）: 約10-20MB

---

## エラーコード一覧

| コード | 説明 | 原因 | 対処方法 |
|-------|------|------|---------|
| **WT001** | 無効なAI名 | サポートされていないAI名 | claude, gemini, amp, qwen, droid, codex, cursorのいずれかを指定 |
| **WT101** | Worktree作成失敗 | Git エラー、ディスク容量不足 | ディスク容量確認、Git設定確認 |
| **WT102** | Worktree既存 | 既にWorktreeが存在 | `cleanup_worktree()`実行 |
| **WT201** | Worktree削除失敗 | 未コミット変更、ロックファイル | `--force`オプション使用 |
| **WT202** | Worktree未存在 | 削除対象が存在しない | 無視して続行 |
| **WT301** | マージ失敗 | Git マージエラー | マージ戦略変更、手動解決 |
| **WT302** | マージ競合 | ファイル競合 | `visualize_merge_conflicts()`で確認 |
| **WT401** | ロック取得失敗 | 並列実行制限、古いロック | `cleanup_stale_locks()`実行 |
| **WT402** | ロック解放失敗 | ロックファイル削除失敗 | 手動で`rm /tmp/multi-ai-worktree.lock` |
| **WT501** | 状態遷移エラー | 不正な状態遷移 | 状態ファイルリセット |
| **WT502** | 無効な状態 | 未定義の状態値 | 状態ファイルリセット |
| **WT901** | 内部エラー | 予期しないエラー | ログ確認、Issue報告 |
| **WT902** | 依存関係エラー | jq未インストール | 依存パッケージインストール |

**エラーコードの読み方:**
- `WT0xx`: 検証エラー
- `WT1xx`: 作成エラー
- `WT2xx`: 削除エラー
- `WT3xx`: マージエラー
- `WT4xx`: 並列制御エラー
- `WT5xx`: 状態管理エラー
- `WT9xx`: システムエラー

---

## FAQ

### Q1: 最大何個のWorktreeを作成できますか？

**A:** 理論上は無制限ですが、Multi-AI Orchestriumでは7個（AI数）が上限です。

**推奨設定:**
- ローカル開発: 4並列（`MAX_PARALLEL_WORKTREES=4`）
- CI環境: 2並列（`MAX_PARALLEL_WORKTREES=2`）
- 低スペック: 1-2並列

**リソース要件（7 Worktree同時実行）:**
- CPU: 4コア以上
- メモリ: 8GB以上
- ディスク: 1GB以上の空き

---

### Q2: Worktreeとブランチの違いは何ですか？

**A:**

| 機能 | ブランチ | Worktree |
|------|---------|---------|
| ファイル実体 | 1つ（共有） | 独立（並列実行可） |
| 切り替えコスト | 低（git checkout） | 高（ディスク容量） |
| 並列実行 | 不可（競合） | 可能（独立） |
| クリーンアップ | 不要 | 必要 |

**使い分け:**
- 順次実行: ブランチで十分
- 並列実行: Worktreeが必要

---

### Q3: 状態ファイル（.state.json）は手動で編集できますか？

**A:** 可能ですが推奨しません。

**理由:**
- NDJSON形式（各行が独立したJSON）
- 不正な編集で状態遷移エラーが発生
- 自動修復機能がある

**安全な編集方法:**
```bash
# 特定のAI状態をリセット
source scripts/orchestrate/lib/worktree-state.sh
update_worktree_state "qwen" "none"

# 全状態をリセット
reset_all_worktree_states
```

---

### Q4: CI環境でWorktreeを使う場合の注意点は？

**A:**

**推奨設定:**
```bash
export NON_INTERACTIVE=true
export MAX_PARALLEL_WORKTREES=2
export WORKTREE_BASE_DIR="worktrees"
```

**注意点:**
1. **並列度を制限** - CI環境はリソースが限られている
2. **非対話モード必須** - ユーザー入力ができない
3. **クリーンアップ確認** - ディスク容量を圧迫しない
4. **タイムアウト設定** - CI全体のタイムアウトを考慮

**GitHub Actions例:**
```yaml
env:
  NON_INTERACTIVE: true
  MAX_PARALLEL_WORKTREES: 2

steps:
  - name: Run worktree tests
    run: |
      bash scripts/test-all-worktree-workflows.sh
```

---

### Q5: Worktree作成時のブランチ名規則は？

**A:**

**自動生成形式:**
```
ai/<ai-name>/<timestamp>
```

**例:**
```
ai/qwen/20251108-120000
ai/claude/20251108-120100
ai/gemini/20251108-120200
```

**カスタムブランチ名:**
```bash
create_worktree "qwen" "worktrees/qwen" "feature/custom-branch"
```

**注意:**
- ブランチ名の衝突を避けるためタイムスタンプ付き
- 命名規則に従うと自動クリーンアップが容易

---

### Q6: 複数のワークフローを同時実行できますか？

**A:** 技術的には可能ですが、推奨しません。

**問題点:**
1. **ロック競合** - 同じWorktreeを作成しようとする
2. **リソース競合** - CPU/メモリが不足
3. **状態競合** - 状態ファイルの同時書き込み

**対策:**
```bash
# ワークフロー1
export WORKTREE_BASE_DIR="worktrees-workflow1"

# ワークフロー2
export WORKTREE_BASE_DIR="worktrees-workflow2"
```

---

### Q7: Worktree削除後もブランチが残る理由は？

**A:** `cleanup_worktree()`は自動的にブランチも削除しますが、Phase 0以前のバージョンでは残る場合がありました。

**確認方法:**
```bash
git branch | grep "ai/"
```

**削除方法:**
```bash
# 自動削除
source scripts/orchestrate/lib/worktree-execution.sh
recover_orphaned_branches --auto

# 手動削除
git branch -D ai/qwen/20251108-120000
```

---

### Q8: マージ戦略の選び方は？

**A:**

| シナリオ | 推奨戦略 | 理由 |
|---------|---------|------|
| 単一AI実行 | `no-ff` | マージ履歴を保持 |
| 実験的変更 | `squash` | コミット履歴を簡潔に |
| 競合時にAI優先 | `theirs` | AIの変更を信頼 |
| 競合時にベース優先 | `ours` | 既存コードを維持 |
| 自動選択 | `best` | 品質スコアで判定 |
| CI環境 | `theirs` | 非対話モード対応 |

---

### Q9: パフォーマンスを最適化する方法は？

**A:**

**並列度の調整:**
```bash
# パフォーマンステスト実行
bash scripts/test-parallel-performance.sh

# 最適な並列度を設定
export MAX_PARALLEL_WORKTREES=4
```

**結果:**
- 順次作成（7 Worktrees）: 約3.5秒
- 並列作成（4並列）: 約0.7秒（**5倍高速化**）

**その他の最適化:**
1. SSD使用（HDD比2-3倍高速）
2. Gitキャッシュ最適化（`git gc --aggressive`）
3. 不要なログ削除

---

### Q10: トラブル時の緊急対応手順は？

**A:**

**緊急時のクリーンアップ:**
```bash
# 1. 全Worktreeをリスト
git worktree list

# 2. 強制削除
git worktree prune -v
rm -rf worktrees/

# 3. 孤立ブランチ削除
git branch | grep "ai/" | xargs -r git branch -D

# 4. 状態ファイルリセット
rm -f worktrees/.state.json

# 5. ロックファイル削除
rm -f /tmp/multi-ai-worktree.lock

# 6. 再起動
# 上記で解決しない場合、システム再起動
```

---

## デバッグ方法

### 基本デバッグ

**ログレベル設定:**
```bash
export WORKTREE_DEBUG=1
export VIBE_LOG_LEVEL=DEBUG
```

**VibeLoggerログ確認:**
```bash
# 最新のログファイル
ls -lt logs/vibe/$(date +%Y%m%d)/*.jsonl | head -1

# 特定のイベントを検索
cat logs/vibe/$(date +%Y%m%d)/*.jsonl | jq 'select(.event == "worktree_create")'

# エラーのみ抽出
cat logs/vibe/$(date +%Y%m%d)/*.jsonl | jq 'select(.level == "error")'
```

---

### 状態ファイルのデバッグ

**状態確認:**
```bash
source scripts/orchestrate/lib/worktree-state.sh

# 特定AIの状態
get_worktree_state "qwen"

# 全AI状態
get_all_worktree_states

# 状態ファイルの内容（NDJSON）
cat worktrees/.state.json | jq '.'
# 注意: 各行が独立したJSONなので、jq '.' は失敗する

# 正しい確認方法
cat worktrees/.state.json
```

---

### 履歴ファイルのデバッグ

**履歴確認:**
```bash
source scripts/orchestrate/lib/worktree-history.sh

# 過去7日の統計
get_execution_statistics

# 特定ワークフローの統計
get_execution_statistics "multi-ai-full-orchestrate" 7

# 成功率
get_workflow_success_rate "multi-ai-full-orchestrate" 7

# 生のNDJSONファイル
cat logs/worktree-history/$(date +%Y%m%d)/history.ndjson
```

---

### メトリクスのデバッグ

**メトリクス確認:**
```bash
source scripts/orchestrate/lib/worktree-metrics.sh

# ダッシュボード生成
bash scripts/generate-metrics-dashboard.sh

# ブラウザで確認
open logs/worktree-metrics/dashboard.html

# 生データ確認
cat logs/worktree-metrics/metrics.ndjson | jq '.'
```

---

### Git Worktreeのデバッグ

**Git worktreeコマンド:**
```bash
# 全Worktreeリスト
git worktree list

# 詳細情報
git worktree list --porcelain

# Worktree削除（dry-run）
git worktree remove worktrees/qwen --dry-run

# ガベージコレクション
git worktree prune -v

# Worktree repair（破損時）
git worktree repair
```

---

### パフォーマンスのデバッグ

**実行時間計測:**
```bash
# time コマンド使用
time create_worktrees_parallel claude gemini qwen droid

# ベンチマークスクリプト
bash scripts/benchmark-parallel-worktrees.sh

# パフォーマンステスト
bash scripts/test-parallel-performance.sh
```

**リソース監視:**
```bash
# CPU/メモリ監視
top -p $(pgrep -f "worktrees")

# ディスク使用量
du -sh worktrees/
df -h
```

---

## 緊急時の対応

### レベル1: 軽度の問題（5分以内）

**症状:** 単一Worktreeのクリーンアップ失敗

**対応:**
```bash
git worktree remove worktrees/qwen --force
git branch -D ai/qwen/20251108-120000
```

---

### レベル2: 中度の問題（15分以内）

**症状:** 複数Worktreeの孤立、状態ファイル破損

**対応:**
```bash
source scripts/orchestrate/lib/worktree-execution.sh
recover_orphaned_worktrees --auto
recover_orphaned_branches --auto
rm -f worktrees/.state.json
reset_all_worktree_states
```

---

### レベル3: 重度の問題（30分以内）

**症状:** 全Worktreeが応答しない、システム不安定

**対応:**
```bash
# 全プロセスを停止
pkill -f "worktrees"

# 全クリーンアップ
git worktree prune -v
rm -rf worktrees/
git branch | grep "ai/" | xargs -r git branch -D
rm -f /tmp/multi-ai-worktree.lock
rm -f worktrees/.state.json

# 再起動
# 必要に応じてシステム再起動
```

---

### レベル4: 緊急対応（1時間以上）

**症状:** データ損失の可能性、Git リポジトリ破損

**対応:**
```bash
# 1. バックアップ作成
git stash
git bundle create backup.bundle --all

# 2. リポジトリ検証
git fsck --full

# 3. 修復
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 4. 最悪の場合はクローンし直す
cd ..
git clone <repository-url> multi-ai-orchestrium-new
cd multi-ai-orchestrium-new
```

---

## サポート

### コミュニティ

- **GitHub Issues**: [multi-ai-orchestrium/issues](https://github.com/CaCC-Lab/multi-ai-orchestrium/issues)
- **Discussions**: [multi-ai-orchestrium/discussions](https://github.com/CaCC-Lab/multi-ai-orchestrium/discussions)

### ドキュメント

- [APIリファレンス](API_REFERENCE.md)
- [アーキテクチャドキュメント](ARCHITECTURE.md)
- [貢献ガイド](CONTRIBUTING.md)

### ログ提出時の情報

Issue報告時は以下の情報を含めてください：

```bash
# システム情報
uname -a
git --version
jq --version
bash --version

# Worktree状態
git worktree list
git branch | grep "ai/"

# ログ（最新100行）
tail -100 logs/vibe/$(date +%Y%m%d)/*.jsonl

# 状態ファイル
cat worktrees/.state.json
```

---

**最終更新:** 2025-11-08
**バージョン:** v1.0
**メンテナー:** Multi-AI Orchestrium Contributors
