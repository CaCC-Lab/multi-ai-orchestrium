# 関数APIリファレンス

Multi-AI Orchestrium の主要ライブラリに含まれる全関数の包括的なリファレンスです。

**最終更新**: 2025-10-24
**バージョン**: v3.2
**総関数数**: 96関数（8ライブラリ）

---

## 目次

1. [multi-ai-core.sh (16関数)](#multi-ai-coresh)
2. [multi-ai-ai-interface.sh (8関数)](#multi-ai-ai-interfacesh)
3. [multi-ai-config.sh (17関数)](#multi-ai-configsh)
4. [multi-ai-workflows.sh (13関数)](#multi-ai-workflowssh)
5. [common-wrapper-lib.sh (8関数)](#common-wrapper-libsh)
6. [agents-utils.sh (9関数)](#agents-utilssh)
7. [vibe-logger-lib.sh (17関数)](#vibe-logger-libsh)
8. [sanitize.sh (8関数)](#sanitizesh)

---

## multi-ai-core.sh

**ファイルパス**: `scripts/orchestrate/lib/multi-ai-core.sh`
**目的**: コアユーティリティ関数（ロギング、タイムスタンプ、バナー表示）
**関数数**: 16

### 1. log_info()

**説明**: 情報メッセージをstderrに出力します。

**使用法**:
```bash
log_info "処理を開始します"
```

**パラメータ**:
- `$1` (string): 出力するメッセージ

**出力**: `[INFO] メッセージ` 形式でstderrに出力

**使用例**:
```bash
log_info "Claude APIを呼び出しています..."
```

---

### 2. log_success()

**説明**: 成功メッセージを緑色でstderrに出力します。

**使用法**:
```bash
log_success "処理が完了しました"
```

**パラメータ**:
- `$1` (string): 成功メッセージ

**出力**: `✓ メッセージ` 形式で緑色表示

---

### 3. log_warning()

**説明**: 警告メッセージを黄色でstderrに出力します。

**使用法**:
```bash
log_warning "タイムアウトが近づいています"
```

**パラメータ**:
- `$1` (string): 警告メッセージ

**出力**: `⚠ メッセージ` 形式で黄色表示

---

### 4. log_error()

**説明**: エラーメッセージを赤色でstderrに出力します。

**使用法**:
```bash
log_error "AI呼び出しに失敗しました"
```

**パラメータ**:
- `$1` (string): エラーメッセージ

**出力**: `✗ メッセージ` 形式で赤色表示

---

### 5. log_phase()

**説明**: フェーズ開始メッセージを装飾付きで出力します。

**使用法**:
```bash
log_phase "戦略的計画フェーズ"
```

**パラメータ**:
- `$1` (string): フェーズ名

**出力**:
```
===========================================
Phase: フェーズ名
===========================================
```

---

### 6. get_timestamp_ms()

**説明**: 現在時刻をミリ秒精度で取得します。

**使用法**:
```bash
start_time=$(get_timestamp_ms)
```

**パラメータ**: なし

**戻り値**: ミリ秒単位のタイムスタンプ（例: 1729800000123）

**使用例**:
```bash
start=$(get_timestamp_ms)
# ... 処理 ...
end=$(get_timestamp_ms)
duration=$((end - start))
echo "処理時間: ${duration}ms"
```

---

### 7. vibe_log()

**説明**: VibeLogger形式の構造化ログを出力します。

**使用法**:
```bash
vibe_log "event_type" "action" '{"key":"value"}' "人間向けメモ" "ai_todo" "tool_name"
```

**パラメータ**:
- `$1` (string): イベントタイプ
- `$2` (string): アクション名
- `$3` (JSON string): メタデータ
- `$4` (string): 人間向けメモ
- `$5` (string, optional): AI向けTODO
- `$6` (string, optional): ツール名

**出力**: JSONL形式でログファイルに保存（`logs/vibe/YYYYMMDD/*.jsonl`）

---

### 8. vibe_pipeline_start()

**説明**: パイプライン開始イベントをログに記録します。

**使用法**:
```bash
vibe_pipeline_start "multi-ai-full-orchestrate" "バランス型ワークフロー" 4
```

**パラメータ**:
- `$1` (string): パイプライン名
- `$2` (string): 説明
- `$3` (int): フェーズ数

---

### 9. vibe_pipeline_done()

**説明**: パイプライン完了イベントをログに記録します。

**使用法**:
```bash
vibe_pipeline_done "multi-ai-full-orchestrate" "success" "$duration_ms" 7
```

**パラメータ**:
- `$1` (string): パイプライン名
- `$2` (string): ステータス（success/failure）
- `$3` (int): 実行時間（ミリ秒）
- `$4` (int): AI呼び出し回数

---

### 10. vibe_phase_start()

**説明**: フェーズ開始イベントをログに記録します。

---

### 11. vibe_phase_done()

**説明**: フェーズ完了イベントをログに記録します。

---

### 12. vibe_summary_done()

**説明**: サマリー完了イベントをログに記録します。

---

### 13. sanitize_input()

**説明**: ユーザー入力をサニタイズして安全な形式に変換します。

**使用法**:
```bash
safe_input=$(sanitize_input "$user_input")
```

**パラメータ**:
- `$1` (string): サニタイズ対象の入力

**戻り値**: サニタイズされた安全な文字列

**セキュリティ**:
- コマンドインジェクション防止
- パストラバーサル保護
- 特殊文字のエスケープ

---

### 14. sanitize_input_for_file()

**説明**: ファイル経由で渡すプロンプトのサニタイズを行います。

**使用法**:
```bash
safe_prompt=$(sanitize_input_for_file "$large_prompt")
```

**パラメータ**:
- `$1` (string): サニタイズ対象のプロンプト

**戻り値**: ファイル保存に適した形式のプロンプト

**注意**: 2KB以上のプロンプトでは制限を緩和（ファイルベースルーティング前提）

---

### 15. run_with_timeout()

**説明**: コマンドをタイムアウト付きで実行します。

**使用法**:
```bash
run_with_timeout 300 "claude" "-p" "task description"
```

**パラメータ**:
- `$1` (int): タイムアウト秒数
- `$2+` (string...): 実行するコマンドと引数

**戻り値**: コマンドの終了コード（124=タイムアウト）

---

### 16. show_multi_ai_banner()

**説明**: Multi-AI Orchestriumのバナーを表示します。

**使用法**:
```bash
show_multi_ai_banner
```

**パラメータ**: なし

**出力**: ASCIIアートバナーとバージョン情報

---

## multi-ai-ai-interface.sh

**ファイルパス**: `scripts/orchestrate/lib/multi-ai-ai-interface.sh`
**目的**: AI CLI呼び出しとフォールバック処理
**関数数**: 8

### 1. check_ai_available()

**説明**: 指定されたAI CLIが利用可能か確認します。

**使用法**:
```bash
if check_ai_available "claude"; then
    echo "Claude CLI is available"
fi
```

**パラメータ**:
- `$1` (string): AI名（claude/gemini/amp/qwen/droid/codex/cursor）

**戻り値**:
- 0: 利用可能
- 1: 利用不可

---

### 2. check_ai_with_details()

**説明**: AI CLIの詳細情報（バージョン、パス）を取得します。

**使用法**:
```bash
check_ai_with_details "claude"
```

**パラメータ**:
- `$1` (string): AI名

**出力**: AI名、バージョン、パスを表示

---

### 3. call_ai()

**説明**: 指定されたAIを呼び出してタスクを実行します。

**使用法**:
```bash
result=$(call_ai "claude" "タスクの説明" 300)
```

**パラメータ**:
- `$1` (string): AI名
- `$2` (string): プロンプト
- `$3` (int): タイムアウト秒数

**戻り値**: AIの出力（stdout）

**内部動作**: 自動的に`call_ai_with_context()`を呼び出し、プロンプトサイズに応じてファイル経由/コマンドライン引数を選択

---

### 4. call_ai_with_fallback()

**説明**: 第1候補AIで失敗した場合、第2候補AIにフォールバックします。

**使用法**:
```bash
result=$(call_ai_with_fallback "droid" "cursor" "タスクの説明" 300)
```

**パラメータ**:
- `$1` (string): 第1候補AI名
- `$2` (string): 第2候補AI名
- `$3` (string): プロンプト
- `$4` (int): タイムアウト秒数

**戻り値**: AI出力（第1候補成功時）または第2候補の出力

---

### 5. supports_file_input()

**説明**: 指定されたAIがファイル経由の入力をサポートしているか確認します。

**使用法**:
```bash
if supports_file_input "claude"; then
    echo "File input is supported"
fi
```

**パラメータ**:
- `$1` (string): AI名

**戻り値**:
- 0: サポートあり
- 1: サポートなし

**現在のサポート状況**: すべてのAI（claude/gemini/amp/qwen/droid/codex/cursor）がstdin経由でファイル入力をサポート

---

### 6. create_secure_prompt_file()

**説明**: セキュアな一時ファイルにプロンプトを書き込みます。

**使用法**:
```bash
prompt_file=$(create_secure_prompt_file "$large_prompt")
```

**パラメータ**:
- `$1` (string): プロンプト内容

**戻り値**: 一時ファイルのパス

**セキュリティ**:
- `mktemp`で一意ファイル生成
- `chmod 600`で所有者のみアクセス可能
- 自動クリーンアップ（trap EXIT/INT/TERM）

---

### 7. cleanup_prompt_file()

**説明**: 一時プロンプトファイルを削除します。

**使用法**:
```bash
cleanup_prompt_file "$prompt_file"
```

**パラメータ**:
- `$1` (string): 削除対象のファイルパス

**動作**: ファイルが存在する場合のみ削除（エラー無視）

---

### 8. call_ai_with_context()

**説明**: プロンプトサイズに応じて自動的にファイル経由/コマンドライン引数を選択してAIを呼び出します。

**使用法**:
```bash
result=$(call_ai_with_context "claude" "$large_prompt" 600)
```

**パラメータ**:
- `$1` (string): AI名
- `$2` (string): プロンプト
- `$3` (int): タイムアウト秒数

**動作**:
- プロンプト < 1KB: コマンドライン引数（`--prompt "$prompt"`）
- プロンプト ≥ 1KB: ファイル経由（stdin redirect）

**戻り値**: AI出力

---

## multi-ai-config.sh

**ファイルパス**: `scripts/orchestrate/lib/multi-ai-config.sh`
**目的**: YAMLプロファイル解析とワークフロー実行
**関数数**: 17

### 1. load_multi_ai_profile()

**説明**: YAMLプロファイルをロードして環境変数にエクスポートします。

**使用法**:
```bash
load_multi_ai_profile "balanced-multi-ai"
```

**パラメータ**:
- `$1` (string): プロファイル名

**動作**: `config/multi-ai-profiles.yaml`から指定されたプロファイルを解析

---

### 2. get_workflow_config()

**説明**: ワークフロー設定を検証して取得します。

**使用法**:
```bash
workflow=$(get_workflow_config "balanced-multi-ai" "multi-ai-full-orchestrate")
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名

**戻り値**: ワークフロー名（検証成功時）

---

### 3. get_phases()

**説明**: ワークフローのフェーズ数を取得します。

**使用法**:
```bash
count=$(get_phases "balanced-multi-ai" "multi-ai-full-orchestrate")
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名

**戻り値**: フェーズ数（整数）

---

### 4. get_phase_info()

**説明**: 特定フェーズの名前と並列実行フラグを取得します。

**使用法**:
```bash
info=$(get_phase_info "balanced-multi-ai" "multi-ai-full-orchestrate" 0)
phase_name="${info%|*}"
has_parallel="${info#*|}"
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス（0始まり）

**戻り値**: "フェーズ名|true/false"形式

---

### 5. get_phase_ai()

**説明**: 順次実行フェーズで使用するAI名を取得します。

**使用法**:
```bash
ai=$(get_phase_ai "balanced-multi-ai" "multi-ai-full-orchestrate" 0)
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス

**戻り値**: AI名（claude/gemini/amp/qwen/droid/codex/cursor）

---

### 6. get_phase_role()

**説明**: フェーズでのAIロール説明を取得します。

**使用法**:
```bash
role=$(get_phase_role "balanced-multi-ai" "multi-ai-full-orchestrate" 0)
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス

**戻り値**: ロール説明（自由形式の文字列）

---

### 7. get_phase_timeout()

**説明**: フェーズのタイムアウト秒数を取得します（未設定時は120秒）。

**使用法**:
```bash
timeout=$(get_phase_timeout "balanced-multi-ai" "multi-ai-full-orchestrate" 0)
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス

**戻り値**: タイムアウト秒数（デフォルト: 120）

---

### 8. get_parallel_count()

**説明**: 並列実行タスク数を取得します。

**使用法**:
```bash
count=$(get_parallel_count "balanced-multi-ai" "multi-ai-full-orchestrate" 1)
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス

**戻り値**: 並列タスク数（整数）

---

### 9. get_parallel_ai()

**説明**: 並列タスクのAI名を取得します。

**使用法**:
```bash
ai=$(get_parallel_ai "balanced-multi-ai" "multi-ai-full-orchestrate" 1 0)
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス
- `$4` (int): 並列タスクインデックス

**戻り値**: AI名

---

### 10. get_parallel_role()

**説明**: 並列タスクのロール説明を取得します。

**パラメータ**: get_parallel_ai()と同じ

**戻り値**: ロール説明

---

### 11. get_parallel_timeout()

**説明**: 並列タスクのタイムアウトを取得します（未設定時は120秒）。

**パラメータ**: get_parallel_ai()と同じ

**戻り値**: タイムアウト秒数（デフォルト: 120）

---

### 12. get_parallel_name()

**説明**: 並列タスクの名前を取得します。

**パラメータ**: get_parallel_ai()と同じ

**戻り値**: タスク名

---

### 13. get_parallel_blocking()

**説明**: 並列タスクがブロッキングか確認します（未設定時はtrue）。

**使用法**:
```bash
blocking=$(get_parallel_blocking "balanced-multi-ai" "multi-ai-full-orchestrate" 1 0)
if [[ "$blocking" == "true" ]]; then
    echo "ブロッキングタスク（失敗時にフェーズ失敗）"
fi
```

**パラメータ**: get_parallel_ai()と同じ

**戻り値**: "true" または "false"（デフォルト: "true"）

---

### 14. execute_phase()

**説明**: 単一フェーズを実行します（順次または並列を自動判定）。

**使用法**:
```bash
execute_phase "balanced-multi-ai" "multi-ai-full-orchestrate" 0 "タスクの説明" "/tmp/work"
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (int): フェーズインデックス
- `$4` (string): タスク内容
- `$5` (string): 作業ディレクトリ

**動作**: has_parallelフラグに応じてexecute_sequential_phase()またはexecute_parallel_phase()を呼び出し

---

### 15. execute_sequential_phase()

**説明**: 順次実行フェーズを実行します。

**使用法**:
```bash
execute_sequential_phase "balanced-multi-ai" "multi-ai-full-orchestrate" 0 "タスク" "/tmp/work"
```

**パラメータ**: execute_phase()と同じ

**動作**:
1. AIとロール、タイムアウトを取得
2. プロンプト構築（タスク + ロール + AI名）
3. call_ai()でAI実行
4. 結果を`${work_dir}/${ai}_${role}.md`に保存

---

### 16. execute_parallel_phase()

**説明**: 並列実行フェーズを実行します。

**使用法**:
```bash
execute_parallel_phase "balanced-multi-ai" "multi-ai-full-orchestrate" 1 "タスク" "/tmp/work"
```

**パラメータ**: execute_phase()と同じ

**動作**:
1. 並列タスク数を取得
2. 全タスクをバックグラウンドで起動
3. 各タスクのPID、AI名、blockingフラグを記録
4. wait でタスク完了を待機
5. blockingタスクが失敗した場合、フェーズ失敗
6. non-blockingタスク失敗は警告のみ

---

### 17. execute_yaml_workflow()

**説明**: YAMLで定義されたワークフロー全体を実行します。

**使用法**:
```bash
execute_yaml_workflow "balanced-multi-ai" "multi-ai-full-orchestrate" "タスクの説明"
```

**パラメータ**:
- `$1` (string): プロファイル名
- `$2` (string): ワークフロー名
- `$3` (string): タスク内容

**動作**: プロファイルからワークフロー定義を読み込み、全フェーズを順次/並列実行

---

## multi-ai-workflows.sh

**ファイルパス**: `scripts/orchestrate/lib/multi-ai-workflows.sh`
**目的**: ワークフロー実装関数
**関数数**: 13

### 1. multi-ai-full-orchestrate()

**説明**: 5-8分のバランス型ワークフロー（7AI協調）を実行します。

**使用法**:
```bash
multi-ai-full-orchestrate "機能の説明"
```

**パラメータ**:
- `$1` (string): 実装する機能の説明

**動作**: 戦略的計画 → 並列実装（Qwen+Droid） → 統合レビュー（Codex+Cursor）

---

### 2. multi-ai-speed-prototype()

**説明**: 2-4分の高速プロトタイピングワークフロー。

**使用法**:
```bash
multi-ai-speed-prototype "簡易機能の説明"
```

**プロファイル**: speed-first-multi-ai

**フェーズ**: Qwen高速実装 → Cursor統合テスト

---

### 3. multi-ai-enterprise-quality()

**説明**: 15-20分のエンタープライズ品質ワークフロー。

**使用法**:
```bash
multi-ai-enterprise-quality "本番機能の説明"
```

**プロファイル**: quality-first-multi-ai

**フェーズ**: Claude設計 → Droid実装 → Codex+Cursor品質保証

---

### 4. multi-ai-hybrid-development()

**説明**: 5-15分の適応型ハイブリッドワークフロー。

**使用法**:
```bash
multi-ai-hybrid-development "適応型機能の説明"
```

**プロファイル**: hybrid-multi-ai

**フェーズ**: タスク分類に応じて動的に速度重視または品質重視を選択

---

### 5. multi-ai-consensus-review()

**説明**: 7AI合意形成レビュー（3ラウンド品質保証）。

**使用法**:
```bash
multi-ai-consensus-review "複雑な意思決定"
```

**プロファイル**: consensus-review

**フェーズ**: 全7AI並列レビュー → 合意形成 → 最終判定

---

### 6. multi-ai-chatdev-develop()

**説明**: ChatDev形式のロールベース開発サイクル。

**使用法**:
```bash
multi-ai-chatdev-develop "プロジェクトの説明"
```

**プロファイル**: chatdev-workflow

**フェーズ**: CEO(Claude) → CTO(Gemini) → Programmer(Qwen) → Reviewer(Codex) → Tester(Cursor)

---

### 7. multi-ai-discuss-before()

**説明**: 実装前ディスカッション（5AI協調）。

**使用法**:
```bash
multi-ai-discuss-before "実装計画"
```

**プロファイル**: discuss-before

**フェーズ**: 5AI並列ディスカッション → Claude総括

---

### 8. multi-ai-review-after()

**説明**: 実装後レビュー（5AI協調）。

**使用法**:
```bash
multi-ai-review-after "コードまたはファイル"
```

**プロファイル**: review-after

**フェーズ**: 5AI並列レビュー → Gemini統合フィードバック

---

### 9. multi-ai-coa-analyze()

**説明**: Chain-of-Agents型長文解析（O(nk)複雑度削減）。

**使用法**:
```bash
multi-ai-coa-analyze "長文ドキュメントや複雑なトピック"
```

**プロファイル**: coa-analyze

**フェーズ**: 文書分割 → 各AIが担当セクション解析 → Amp統合サマリー

---

### 10. multi-ai-code-review()

**説明**: コードレビューワークフロー（Codex + Cursor）。

**使用法**:
```bash
multi-ai-code-review "コードパスまたはコミット"
```

**フェーズ**: Codex静的解析 → Cursor実行時テスト

---

### 11. multi-ai-coderabbit-review()

**説明**: CodeRabbit統合レビューワークフロー。

**使用法**:
```bash
multi-ai-coderabbit-review "PRまたはコミット"
```

**フェーズ**: CodeRabbitレビュー → Claude改善提案

---

### 12. multi-ai-full-review()

**説明**: 包括的レビューワークフロー（全AI協調）。

**使用法**:
```bash
multi-ai-full-review "実装またはドキュメント"
```

**フェーズ**: 7AI並列レビュー → Claude統合レポート

---

### 13. multi-ai-dual-review()

**説明**: 2AI並列レビューワークフロー（高速レビュー）。

**使用法**:
```bash
multi-ai-dual-review "コードまたは設計"
```

**フェーズ**: Codex + Cursor並列レビュー

---

## common-wrapper-lib.sh

**ファイルパス**: `bin/common-wrapper-lib.sh`
**目的**: AIラッパースクリプト共通機能
**関数数**: 8

### 1. wrapper_load_dependencies()

**説明**: ラッパースクリプトの依存ライブラリをロードします。

**使用法**:
```bash
wrapper_load_dependencies
```

**動作**:
- `bin/agents-utils.sh`（タスク分類）
- `bin/vibe-logger-lib.sh`（ロギング）
- `scripts/lib/sanitize.sh`（入力検証）

---

### 2. wrapper_generate_help()

**説明**: ラッパースクリプトのヘルプテキストを生成します。

**使用法**:
```bash
wrapper_generate_help "Claude" "claude"
```

**パラメータ**:
- `$1` (string): AI名（表示用）
- `$2` (string): CLI名（コマンド名）

---

### 3. wrapper_parse_args()

**説明**: ラッパースクリプトの共通引数を解析します。

**使用法**:
```bash
wrapper_parse_args "$@"
```

**対応オプション**:
- `--prompt TEXT`: プロンプトテキスト
- `--stdin`: 標準入力から読み込み
- `--non-interactive`: 承認プロンプトをスキップ
- `--workspace PATH`: 作業ディレクトリ
- `--raw ARGS...`: AI CLIに直接渡す引数

**グローバル変数設定**:
- `PROMPT`: プロンプト内容
- `WORKSPACE`: 作業ディレクトリ
- `NON_INTERACTIVE`: true/false
- `RAW`: 生引数の配列

---

### 4. wrapper_check_approval()

**説明**: 重要タスクの承認プロンプトを表示します。

**使用法**:
```bash
wrapper_check_approval "$classification" "$prompt" "Claude" "$start_time"
```

**パラメータ**:
- `$1` (string): タスク分類（lightweight/standard/critical）
- `$2` (string): プロンプト内容
- `$3` (string): AI名
- `$4` (int): 開始時刻（ミリ秒）

**動作**:
- `critical`タスクの場合のみ承認プロンプト表示
- `NON_INTERACTIVE=true`の場合は自動承認
- 拒否された場合はexit 1

---

### 5. wrapper_apply_timeout()

**説明**: タイムアウト付きでコマンドを実行します。

**使用法**:
```bash
wrapper_apply_timeout "300s" "claude" "--prompt" "task"
```

**パラメータ**:
- `$1` (string): タイムアウト（例: 300s, 5m）
- `$2+` (string...): 実行するコマンドと引数

**動作**:
- `WRAPPER_SKIP_TIMEOUT=true`の場合はタイムアウトなしで実行
- それ以外は`timeout`コマンドで実行

---

### 6. wrapper_run_ai()

**説明**: AI CLIを実行します（タスク分類、承認、ログを含む）。

**使用法**:
```bash
wrapper_run_ai "$AI_NAME" "$PROMPT" "$BASE_TIMEOUT" "${AI_COMMAND[@]}"
```

**パラメータ**:
- `$1` (string): AI名
- `$2` (string): プロンプト
- `$3` (int): ベースタイムアウト秒数
- `$4+` (string...): AI CLIコマンドと引数

**動作**:
1. VibeLogger: wrapper_start
2. AGENTS.md分類によるタイムアウト調整
3. 承認チェック（criticalタスクのみ）
4. AI CLI実行
5. VibeLogger: wrapper_done

---

### 7. wrapper_handle_raw_args()

**説明**: `--raw`引数でAI CLIに直接渡します。

**使用法**:
```bash
if wrapper_handle_raw_args; then
    exit 0
fi
```

**グローバル変数使用**:
- `RAW`: 生引数の配列
- `AI_COMMAND`: AI CLIコマンド
- `BASE_TIMEOUT`: タイムアウト

**戻り値**:
- 0: 実行成功（スクリプト終了推奨）
- 1: RAW引数なし（通常処理継続）

---

### 8. wrapper_handle_stdin()

**説明**: 標準入力からプロンプトを読み込みます。

**使用法**:
```bash
if wrapper_handle_stdin; then
    PROMPT="$INPUT"
fi
```

**グローバル変数設定**:
- `INPUT`: 標準入力の内容

**戻り値**:
- 0: 標準入力あり
- 1: 標準入力なし

---

## agents-utils.sh

**ファイルパス**: `bin/agents-utils.sh`
**目的**: AGENTS.mdに基づくタスク分類と設定
**関数数**: 9

### 1. classify_task()

**説明**: タスクをAGENTS.mdの基準に基づいて分類します。

**使用法**:
```bash
classification=$(classify_task "ユーザーリクエスト")
```

**パラメータ**:
- `$1` (string): タスクの説明

**戻り値**: lightweight | standard | critical

**分類基準**:
- `critical`: コード削除、本番デプロイ、セキュリティ関連
- `standard`: 実装、リファクタリング、テスト作成
- `lightweight`: 簡易な情報取得、ファイル読み込み

---

### 2. to_seconds()

**説明**: タイムアウト文字列を秒数に変換します。

**使用法**:
```bash
seconds=$(to_seconds "5m")
```

**パラメータ**:
- `$1` (string): タイムアウト（例: 300s, 5m, 1h）

**戻り値**: 秒数（整数）

**対応単位**:
- `s`: 秒
- `m`: 分
- `h`: 時間

---

### 3. get_task_timeout()

**説明**: タスク分類に基づいて動的タイムアウトを取得します。

**使用法**:
```bash
timeout=$(get_task_timeout "critical" 60)
```

**パラメータ**:
- `$1` (string): タスク分類（lightweight/standard/critical）
- `$2` (int): ベースタイムアウト秒数

**戻り値**: 調整されたタイムアウト文字列（例: "180s"）

**調整ルール**:
- `lightweight`: base × 0.5
- `standard`: base × 1.0
- `critical`: base × 3.0

---

### 4. get_process_label()

**説明**: タスク分類に対応するプロセスラベルを取得します。

**使用法**:
```bash
label=$(get_process_label "critical")
```

**パラメータ**:
- `$1` (string): タスク分類

**戻り値**:
- `lightweight`: "⚡ LIGHTWEIGHT"
- `standard`: "📋 STANDARD"
- `critical`: "🔥 CRITICAL"

---

### 5. requires_approval()

**説明**: タスクが承認を必要とするか確認します。

**使用法**:
```bash
if requires_approval "critical"; then
    echo "承認が必要です"
fi
```

**パラメータ**:
- `$1` (string): タスク分類

**戻り値**:
- 0: 承認必要（criticalタスク）
- 1: 承認不要

---

### 6. get_agents_path()

**説明**: AGENTS.mdファイルのパスを取得します。

**使用法**:
```bash
agents_file=$(get_agents_path)
```

**戻り値**: AGENTS.mdの絶対パス

**検索順序**:
1. `$PROJECT_ROOT/AGENTS.md`
2. `$HOME/.config/multi-ai-orchestrium/AGENTS.md`
3. `/etc/multi-ai-orchestrium/AGENTS.md`

---

### 7. validate_agents_md()

**説明**: AGENTS.mdファイルが存在し、必須セクションを含むか検証します。

**使用法**:
```bash
if validate_agents_md; then
    echo "AGENTS.md is valid"
fi
```

**戻り値**:
- 0: 有効
- 1: 無効（存在しない、または必須セクション欠落）

**検証項目**:
- ファイル存在確認
- "lightweight", "standard", "critical"セクション確認

---

### 8. get_quality_level()

**説明**: タスク分類に基づく品質レベルを取得します。

**使用法**:
```bash
quality=$(get_quality_level "critical")
```

**パラメータ**:
- `$1` (string): タスク分類（lightweight/standard/critical）

**戻り値**:
- `lightweight`: "low"
- `standard`: "medium"
- `critical`: "high"

**用途**: Droidの`--quality`パラメータ決定

---

### 9. find_agents_md()

**説明**: AGENTS.mdファイルをプロジェクトルートから再帰的に検索します。

**使用法**:
```bash
agents_file=$(find_agents_md "/path/to/project")
```

**パラメータ**:
- `$1` (string): 検索開始ディレクトリ（省略時: カレントディレクトリ）

**戻り値**: 最初に見つかったAGENTS.mdのパス（見つからない場合は空文字列）

**注意**: 上位ディレクトリへの遡り検索あり（最大5階層）

---

## vibe-logger-lib.sh

**ファイルパス**: `bin/vibe-logger-lib.sh`
**目的**: AI最適化構造化ロギング（VibeLogger）
**関数数**: 17

### 1. get_timestamp_ms()

**説明**: 現在時刻をミリ秒精度で取得します（multi-ai-core.shと同じ）。

---

### 2. vibe_log()

**説明**: 汎用VibeLoggerイベントをログに記録します（multi-ai-core.shと同じ）。

---

### 3. vibe_wrapper_start()

**説明**: ラッパースクリプト開始イベントをログに記録します。

**使用法**:
```bash
vibe_wrapper_start "Claude" "$prompt" "$timeout"
```

**パラメータ**:
- `$1` (string): AI名
- `$2` (string): プロンプト
- `$3` (string): タイムアウト

---

### 4. vibe_wrapper_done()

**説明**: ラッパースクリプト完了イベントをログに記録します。

**使用法**:
```bash
vibe_wrapper_done "Claude" "success" "$duration_ms" "0"
```

**パラメータ**:
- `$1` (string): AI名
- `$2` (string): ステータス（success/failure/timeout）
- `$3` (int): 実行時間（ミリ秒）
- `$4` (int): 終了コード

---

### 5. vibe_wrapper_config()

**説明**: ラッパー設定イベントをログに記録します（タイムアウト、品質レベルなど）。

**使用法**:
```bash
vibe_wrapper_config "Claude" "timeout" "300s"
```

**パラメータ**:
- `$1` (string): AI名
- `$2` (string): 設定項目名
- `$3` (string): 設定値

---

### 6. vibe_tdd_phase_start()

**説明**: TDDフェーズ開始イベントをログに記録します。

**使用法**:
```bash
vibe_tdd_phase_start "RED" 1 3
```

**パラメータ**:
- `$1` (string): フェーズ名（RED/GREEN/REFACTOR）
- `$2` (int): 現在のフェーズ番号
- `$3` (int): 総フェーズ数

---

### 7. vibe_tdd_phase_done()

**説明**: TDDフェーズ完了イベントをログに記録します。

**使用法**:
```bash
vibe_tdd_phase_done "RED" 1 3 0 "$duration_ms"
```

**パラメータ**:
- `$1` (string): フェーズ名
- `$2` (int): 現在のフェーズ番号
- `$3` (int): 総フェーズ数
- `$4` (int): 終了コード
- `$5` (int): 実行時間（ミリ秒）

---

### 8. vibe_tdd_test_result()

**説明**: TDDテスト結果をログに記録します（合格/失敗）。

**使用法**:
```bash
vibe_tdd_test_result "test_authentication" "passed" "$duration_ms"
```

**パラメータ**:
- `$1` (string): テスト名
- `$2` (string): 結果（passed/failed）
- `$3` (int): 実行時間（ミリ秒）

---

### 9. vibe_tdd_cycle_start()

**説明**: TDDサイクル開始イベントをログに記録します。

**使用法**:
```bash
vibe_tdd_cycle_start "認証機能" 5
```

**パラメータ**:
- `$1` (string): 機能名
- `$2` (int): 総ステップ数

---

### 10. vibe_tdd_cycle_done()

**説明**: TDDサイクル完了イベントをログに記録します。

**使用法**:
```bash
vibe_tdd_cycle_done "認証機能" "success" "$total_ms" 10 10 0
```

**パラメータ**:
- `$1` (string): 機能名
- `$2` (string): ステータス
- `$3` (int): 総実行時間（ミリ秒）
- `$4` (int): 総テスト数
- `$5` (int): 合格テスト数
- `$6` (int): 失敗テスト数

---

### 11. vibe_pipeline_start()

**説明**: パイプライン開始イベントをログに記録します（multi-ai-core.shと同じ）。

---

### 12. vibe_pipeline_done()

**説明**: パイプライン完了イベントをログに記録します（multi-ai-core.shと同じ）。

---

### 13. vibe_file_prompt_start()

**説明**: ファイルベースプロンプト開始イベントをログに記録します（Phase 1機能）。

**パラメータ**: AI名、プロンプトサイズ、ファイルパス

---

### 14. vibe_file_prompt_done()

**説明**: ファイルベースプロンプト完了イベントをログに記録します（Phase 1機能）。

**パラメータ**: AI名、ステータス、実行時間、終了コード

---

### 15. vibe_file_created()

**説明**: 一時ファイル作成イベントをログに記録します（セキュリティ監査用）。

**パラメータ**: ファイルパス、サイズ、権限（mode）

---

### 16. vibe_file_cleanup()

**説明**: 一時ファイルクリーンアップイベントをログに記録します（リソース管理用）。

**パラメータ**: ファイルパス、削除成功/失敗

---

### 17. vibe_prompt_size_analysis()

**説明**: プロンプトサイズ分析結果をログに記録します（パフォーマンス最適化用）。

**パラメータ**: プロンプトサイズ（バイト）、ルーティング方法（commandline/file）、推奨方法

---

## sanitize.sh

**ファイルパス**: `scripts/lib/sanitize.sh`
**目的**: 入力検証とセキュリティ保護
**関数数**: 8

### 1. sanitize_prompt()

**説明**: プロンプトをサニタイズして安全な形式に変換します。

**使用法**:
```bash
safe_prompt=$(sanitize_prompt "$user_input")
```

**パラメータ**:
- `$1` (string): サニタイズ対象のプロンプト

**戻り値**: サニタイズされたプロンプト

**セキュリティ**:
- コマンドインジェクション防止
- 特殊文字のエスケープ
- 長さ制限（最大100KB）

---

### 2. sanitize_prompt_to_file()

**説明**: ファイル保存用にプロンプトをサニタイズします。

**使用法**:
```bash
sanitize_prompt_to_file "$large_prompt" "$temp_file"
```

**パラメータ**:
- `$1` (string): プロンプト内容
- `$2` (string): 出力ファイルパス

**動作**: サニタイズしたプロンプトをファイルに書き込み

---

### 3. should_use_file()

**説明**: プロンプトサイズに基づいてファイル経由を使うべきか判定します。

**使用法**:
```bash
if should_use_file "$prompt"; then
    echo "ファイル経由を使用します"
fi
```

**パラメータ**:
- `$1` (string): プロンプト

**戻り値**:
- 0: ファイル経由を使用（≥1KB）
- 1: コマンドライン引数を使用（<1KB）

---

### 4. sanitize_log_output()

**説明**: ログ出力をサニタイズして機密情報を隠します（パスワード、トークンなど）。

**使用法**:
```bash
safe_log=$(sanitize_log_output "$raw_log")
```

**パラメータ**:
- `$1` (string): サニタイズ対象のログ

**戻り値**: 機密情報がマスクされたログ

**マスク対象**:
- パスワード（password=***）
- APIキー（api_key=***）
- トークン（token=***）
- 秘密鍵（private_key=***）

---

### 5. get_prompt_length()

**説明**: プロンプトのバイト数を取得します。

**使用法**:
```bash
length=$(get_prompt_length "$prompt")
```

**パラメータ**:
- `$1` (string): プロンプト

**戻り値**: バイト数（整数）

---

### 6. get_prompt_hash()

**説明**: プロンプトのSHA256ハッシュを取得します。

**使用法**:
```bash
hash=$(get_prompt_hash "$prompt")
```

**パラメータ**:
- `$1` (string): プロンプト

**戻り値**: SHA256ハッシュ（16進数文字列）

**用途**: プロンプトの一意識別、重複検出

---

### 7. sanitize_workflow_prompt()

**説明**: ワークフロー用にプロンプトをサニタイズします（最大1MB）。

**使用法**:
```bash
safe_prompt=$(sanitize_workflow_prompt "$large_workflow_prompt")
```

**パラメータ**:
- `$1` (string): ワークフロープロンプト

**戻り値**: サニタイズされたプロンプト

**制限**: 通常のサニタイズより緩和（最大1MB）

---

### 8. sanitize_with_fallback()

**説明**: サニタイズに失敗した場合、フォールバック処理を行います。

**使用法**:
```bash
safe_prompt=$(sanitize_with_fallback "$risky_input")
```

**パラメータ**:
- `$1` (string): サニタイズ対象

**戻り値**: サニタイズされたプロンプト、または切り詰められた安全なフォールバック

**動作**:
1. `sanitize_prompt()`を試行
2. 失敗した場合、1KBに切り詰めて再試行
3. それでも失敗した場合、エラーメッセージを返す

---

## まとめ

**総関数数**: 96関数（8ライブラリ）

**カテゴリ別統計**:
- ロギング関数: 29関数（30%）
- AI呼び出し関数: 8関数（8%）
- 設定・YAML解析: 17関数（18%）
- ワークフロー: 13関数（14%）
- ラッパー共通機能: 8関数（8%）
- タスク分類・設定: 9関数（9%）
- サニタイゼーション: 8関数（8%）
- その他ユーティリティ: 4関数（4%）

**使用頻度の高い関数トップ10**:
1. `call_ai()` - AI呼び出しのエントリーポイント
2. `classify_task()` - タスク分類（全ラッパーで使用）
3. `sanitize_input()` - 入力検証（セキュリティ必須）
4. `vibe_log()` - 構造化ロギング
5. `wrapper_run_ai()` - ラッパー実行の中核
6. `get_timestamp_ms()` - パフォーマンス測定
7. `log_info()` - 情報ログ出力
8. `execute_yaml_workflow()` - ワークフロー実行
9. `wrapper_parse_args()` - 引数解析
10. `get_task_timeout()` - タイムアウト調整

**保守性向上のポイント**:
- 関数名が目的を明確に表現
- パラメータと戻り値が型付けされている
- グローバル変数の使用箇所が明示されている
- セキュリティ関連関数が適切に分離
- ログ関数が統一された形式で提供

**次のステップ**:
- 各関数の実装詳細を確認（ソースコードレビュー）
- 依存関係マップの作成
- 使用例の追加
- 性能ベンチマーク結果の追加

---

**ドキュメントバージョン**: 1.0
**作成日**: 2025-10-24
**更新履歴**: 初版作成
