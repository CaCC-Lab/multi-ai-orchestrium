#!/usr/bin/env bash

# Spec Analyzer - 仕様書解析器
# Purpose: Markdown仕様書からセクション抽出、キーワード抽出、AI特性マッピング
# Version: 1.0
# Created: 2025-11-11
# Team: Qwen (Implementation) + Claude (Review)

set -euo pipefail

# ==============================================================================
# 1. セクション抽出
# ==============================================================================

# Markdown仕様書からセクションを抽出
# Usage: extract_sections <spec_file> <output_dir>
extract_sections() {
    local spec_file="$1"
    local output_dir="$2"

    if [[ ! -f "$spec_file" ]]; then
        echo "ERROR: Spec file not found: $spec_file" >&2
        return 1
    fi

    mkdir -p "$output_dir"

    # Markdown見出し（## で始まる行）ベースでセクション分割
    awk '
        /^## Frontend/ {
            section="frontend"
            print "Extracting Frontend section..." > "/dev/stderr"
            next
        }
        /^## Backend/ {
            section="backend"
            print "Extracting Backend section..." > "/dev/stderr"
            next
        }
        /^## Database/ {
            section="database"
            print "Extracting Database section..." > "/dev/stderr"
            next
        }
        /^## Testing/ {
            section="testing"
            print "Extracting Testing section..." > "/dev/stderr"
            next
        }
        /^## Documentation/ {
            section="documentation"
            print "Extracting Documentation section..." > "/dev/stderr"
            next
        }
        /^## / {
            # 未対応のセクション見出しは無視
            section=""
            next
        }
        section != "" {
            # 現在のセクションに属する行を対応ファイルに出力
            print > "'"$output_dir"'/" section ".md"
        }
    ' "$spec_file"

    # 抽出されたセクションファイル一覧を返す
    ls "$output_dir"/*.md 2>/dev/null || echo "No sections extracted" >&2
}

# ==============================================================================
# 2. キーワード抽出
# ==============================================================================

# セクションファイルから主要キーワードを抽出
# Usage: extract_keywords <section_file>
extract_keywords() {
    local section_file="$1"

    if [[ ! -f "$section_file" ]]; then
        echo "ERROR: Section file not found: $section_file" >&2
        return 1
    fi

    # 主要キーワードパターン（大文字・小文字を区別しない）
    # - UI/UX関連: UI, UX, component(s), widget(s), form(s), button(s), login, responsive
    # - Backend関連: API, endpoint(s), service(s), handler(s), controller(s), server(s), backend, logic, JWT, token(s), session(s)
    # - Database関連: database(s), schema(s), migration(s), query/queries, table(s), SQL, PostgreSQL, ORM
    # - Testing関連: test(s), unittest(s), integration, e2e, coverage, security
    # - その他: authentication, authorization, validation, password(s), user(s)

    grep -oiE '\b(ui|ux|components?|widgets?|forms?|buttons?|login|responsive|apis?|endpoints?|services?|handlers?|controllers?|servers?|backend|logic|jwt|tokens?|sessions?|databases?|schemas?|migrations?|quer(y|ies)|tables?|sql|postgresql|orms?|typeorms?|tests?|unittests?|integrations?|e2e|coverage|security|authentications?|authorizations?|validations?|passwords?|users?|hashings?|bcrypts?)\b' "$section_file" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/s$//' \
        | sed 's/ies$/y/' \
        | sed 's/queries$/query/' \
        | sort \
        | uniq -c \
        | sort -rn

    # 出力形式: "回数 キーワード" (例: "5 api")
}

# ==============================================================================
# 3. AI特性マッピング
# ==============================================================================

# 役割キーワードから最適なAIを選択
# Usage: map_ai_to_role <role_keyword>
# Based on: COMPREHENSIVE_7AI_ANALYSIS.md
map_ai_to_role() {
    local role="$1"

    case "$role" in
        # Frontend関連
        frontend|ui|ux|component|widget|form|button)
            echo "cursor"
            ;;

        # Backend関連
        backend|api|endpoint|service|handler|controller|logic)
            echo "claude"
            ;;

        # Database関連
        database|schema|migration|query|table|orm)
            echo "claude"
            ;;

        # Testing関連
        test|testing|unittest|integration|e2e|coverage|qa|validation)
            echo "qwen"
            ;;

        # Review/Security関連
        review|security|optimization|performance|audit)
            echo "gemini"
            ;;

        # Enterprise/Compliance関連
        enterprise|compliance|quality|scalability|reliability)
            echo "droid"
            ;;

        # Documentation関連
        documentation|docs|readme|guide|tutorial)
            echo "amp"
            ;;

        # Problem Solving関連
        debug|troubleshoot|error|fix|refactor)
            echo "codex"
            ;;

        # デフォルト（不明な役割）
        *)
            echo "claude"  # Claude is the most versatile
            ;;
    esac
}

# ==============================================================================
# 4. スコアリングアルゴリズム
# ==============================================================================

# キーワード頻度からAIスコアを計算
# Usage: score_ai_for_section <section_file>
# Output: AI名とスコアのペア（降順）
score_ai_for_section() {
    local section_file="$1"

    if [[ ! -f "$section_file" ]]; then
        echo "ERROR: Section file not found: $section_file" >&2
        return 1
    fi

    # 一時ファイルでスコア集計
    local score_file=$(mktemp)
    trap "rm -f $score_file" EXIT

    # キーワード抽出してAIマッピング
    while read -r count keyword; do
        local ai=$(map_ai_to_role "$keyword")
        echo "$ai $count"
    done < <(extract_keywords "$section_file") >> "$score_file"

    # AI別にスコア合計を計算
    awk '{ai[$1] += $2} END {for (a in ai) print ai[a], a}' "$score_file" \
        | sort -rn \
        | awk '{print $2 ": " $1}'
}

# ==============================================================================
# 5. 仕様準拠ゲート（Validation）
# ==============================================================================

# セクションファイルが最低限の要件を満たしているか検証
# Usage: validate_section <section_file>
validate_section() {
    local section_file="$1"

    if [[ ! -f "$section_file" ]]; then
        echo "FAIL: Section file not found" >&2
        return 1
    fi

    # 最低文字数チェック（50文字以上）
    local char_count=$(wc -m < "$section_file")
    if [[ $char_count -lt 50 ]]; then
        echo "FAIL: Section too short ($char_count chars < 50)" >&2
        return 1
    fi

    # 最低キーワード数チェック（3キーワード以上）
    local keyword_count=$(extract_keywords "$section_file" | wc -l)
    if [[ $keyword_count -lt 3 ]]; then
        echo "FAIL: Too few keywords ($keyword_count < 3)" >&2
        return 1
    fi

    echo "PASS: Section validated ($char_count chars, $keyword_count keywords)"
}

# ==============================================================================
# 6. メイン処理関数
# ==============================================================================

# 仕様書を解析してAI割り当てを推奨
# Usage: analyze_spec <spec_file>
analyze_spec() {
    local spec_file="$1"
    local output_dir="${2:-/tmp/spec-analysis-$(date +%s)}"

    echo "======================================"
    echo "  Spec Analyzer"
    echo "======================================"
    echo ""
    echo "Input: $spec_file"
    echo "Output: $output_dir"
    echo ""

    # Step 1: セクション抽出
    echo "[Step 1/3] Extracting sections..."
    extract_sections "$spec_file" "$output_dir"
    echo ""

    # Step 2: 各セクションの分析
    echo "[Step 2/3] Analyzing sections..."
    for section_file in "$output_dir"/*.md; do
        if [[ -f "$section_file" ]]; then
            local section_name=$(basename "$section_file" .md)
            echo ""
            echo "Section: $section_name"
            echo "----------------------------------------"

            # Validation
            validate_section "$section_file"

            # AI推奨スコア
            echo ""
            echo "Recommended AI (by score):"
            score_ai_for_section "$section_file"
        fi
    done
    echo ""

    # Step 3: サマリー
    echo "[Step 3/3] Summary"
    echo "----------------------------------------"
    echo "Sections extracted: $(ls "$output_dir"/*.md 2>/dev/null | wc -l)"
    echo "Output directory: $output_dir"
    echo ""
    echo "✅ Spec analysis complete!"
}

# ==============================================================================
# CLI実行
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # スクリプトが直接実行された場合
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <spec_file> [output_dir]"
        echo ""
        echo "Example:"
        echo "  $0 docs/specs/my-feature-spec.md /tmp/spec-analysis"
        exit 1
    fi

    analyze_spec "$@"
fi
