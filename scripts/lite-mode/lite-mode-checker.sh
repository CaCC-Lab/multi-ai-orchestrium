#!/usr/bin/env bash
# lite-mode-checker.sh - AI可用性チェッカー for Lite Mode
#
# Purpose: 利用可能なAIを自動検出し、最適なモードを判定
# Version: 1.0.0
# Date: 2025-11-27
#
# Usage:
#   source scripts/lite-mode/lite-mode-checker.sh
#   lite_check_all_ais
#   lite_get_available_mode

set -euo pipefail

# ============================================================================
# Constants
# ============================================================================

# AI定義: name:command:role:priority
# Priority: 1=Core(必須級), 2=Important(重要), 3=Optional(オプション)
readonly LITE_AI_DEFINITIONS=(
  "claude:claude:strategy:1"
  "gemini:gemini:research:1"
  "qwen:qwen:prototype:2"
  "droid:droid:enterprise:2"
  "codex:codex:review:3"
  "cursor:cursor:integration:3"
  "amp:amp:pm:3"
)

# モード定義
readonly LITE_MODE_SINGLE="single"      # 1 AI
readonly LITE_MODE_BASIC="basic"        # 2-3 AI
readonly LITE_MODE_STANDARD="standard"  # 4-5 AI
readonly LITE_MODE_FULL="full"          # 6-7 AI

# ============================================================================
# Global State
# ============================================================================

declare -A LITE_AI_STATUS=()       # AI名 -> available/unavailable
declare -A LITE_AI_VERSION=()      # AI名 -> version
declare -a LITE_AVAILABLE_AIS=()   # 利用可能なAIリスト
declare LITE_CURRENT_MODE=""       # 現在のモード

# ============================================================================
# AI Detection Functions
# ============================================================================

# 単一AIの可用性チェック
# Arguments: $1=command
# Returns: 0=available, 1=unavailable
lite_check_ai_command() {
  local cmd="$1"
  
  # コマンドの存在チェック
  if ! command -v "$cmd" &>/dev/null; then
    return 1
  fi
  
  # AIごとの追加チェック（バージョン取得など）
  case "$cmd" in
    claude)
      # Claude: --version or -p で確認
      if timeout 3s "$cmd" --version &>/dev/null 2>&1; then
        return 0
      fi
      # Fallback: コマンド存在だけで判定
      return 0
      ;;
    gemini)
      # Gemini: --version で確認
      if timeout 3s "$cmd" --version &>/dev/null 2>&1; then
        return 0
      fi
      return 0
      ;;
    qwen)
      # Qwen: --version で確認
      if timeout 3s "$cmd" --version &>/dev/null 2>&1; then
        return 0
      fi
      return 0
      ;;
    droid)
      # Droid: --version (タイムアウトに注意)
      if timeout 5s "$cmd" --version &>/dev/null 2>&1; then
        return 0
      fi
      return 0
      ;;
    codex)
      # Codex: --version で確認
      if timeout 3s "$cmd" --version &>/dev/null 2>&1; then
        return 0
      fi
      return 0
      ;;
    cursor)
      # Cursor: --version で確認
      if timeout 3s "$cmd" --version &>/dev/null 2>&1; then
        return 0
      fi
      return 0
      ;;
    amp)
      # Amp: -V (大文字) で確認
      if timeout 3s "$cmd" -V &>/dev/null 2>&1; then
        return 0
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# AIのバージョン取得
# Arguments: $1=command
# Returns: version string
lite_get_ai_version() {
  local cmd="$1"
  local version=""
  
  case "$cmd" in
    claude)
      version=$(timeout 3s "$cmd" --version 2>/dev/null | head -1 || echo "unknown")
      ;;
    gemini)
      version=$(timeout 3s "$cmd" --version 2>/dev/null | head -1 || echo "unknown")
      ;;
    qwen)
      version=$(timeout 3s "$cmd" --version 2>/dev/null | head -1 || echo "unknown")
      ;;
    droid)
      version=$(timeout 5s "$cmd" --version 2>/dev/null | head -1 || echo "unknown")
      ;;
    codex)
      version=$(timeout 3s "$cmd" --version 2>/dev/null | head -1 || echo "unknown")
      ;;
    cursor)
      version=$(timeout 3s "$cmd" --version 2>/dev/null | head -1 || echo "unknown")
      ;;
    amp)
      version=$(timeout 3s "$cmd" -V 2>/dev/null | head -1 || echo "unknown")
      ;;
    *)
      version="unknown"
      ;;
  esac
  
  echo "$version"
}

# ============================================================================
# Main Check Functions
# ============================================================================

# 全AIの可用性チェック
lite_check_all_ais() {
  LITE_AI_STATUS=()
  LITE_AI_VERSION=()
  LITE_AVAILABLE_AIS=()
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "  🔍 AI Tools Availability Check" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  
  for def in "${LITE_AI_DEFINITIONS[@]}"; do
    IFS=':' read -r name cmd role priority <<< "$def"
    
    printf "  %-10s ... " "$name" >&2
    
    if lite_check_ai_command "$cmd"; then
      LITE_AI_STATUS["$name"]="available"
      LITE_AI_VERSION["$name"]=$(lite_get_ai_version "$cmd")
      LITE_AVAILABLE_AIS+=("$name")
      echo "✅ available (${LITE_AI_VERSION[$name]:-unknown})" >&2
    else
      LITE_AI_STATUS["$name"]="unavailable"
      LITE_AI_VERSION["$name"]=""
      echo "❌ not found" >&2
    fi
  done
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "  Total: ${#LITE_AVAILABLE_AIS[@]}/7 AIs available" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  
  # モード判定
  lite_determine_mode
}

# モード判定
lite_determine_mode() {
  local count=${#LITE_AVAILABLE_AIS[@]}
  
  if [[ $count -eq 0 ]]; then
    LITE_CURRENT_MODE="none"
    echo "" >&2
    echo "⚠️  No AI tools found. Please install at least one AI CLI." >&2
  elif [[ $count -eq 1 ]]; then
    LITE_CURRENT_MODE="$LITE_MODE_SINGLE"
    echo "" >&2
    echo "📦 Mode: SINGLE (1 AI) - Basic operations available" >&2
  elif [[ $count -le 3 ]]; then
    LITE_CURRENT_MODE="$LITE_MODE_BASIC"
    echo "" >&2
    echo "📦 Mode: BASIC (2-3 AIs) - Core workflows available" >&2
  elif [[ $count -le 5 ]]; then
    LITE_CURRENT_MODE="$LITE_MODE_STANDARD"
    echo "" >&2
    echo "📦 Mode: STANDARD (4-5 AIs) - Most workflows available" >&2
  else
    LITE_CURRENT_MODE="$LITE_MODE_FULL"
    echo "" >&2
    echo "📦 Mode: FULL (6-7 AIs) - All workflows available" >&2
  fi
}

# ============================================================================
# Query Functions
# ============================================================================

# 利用可能なモードを取得
lite_get_available_mode() {
  echo "$LITE_CURRENT_MODE"
}

# 利用可能なAIリストを取得
lite_get_available_ais() {
  echo "${LITE_AVAILABLE_AIS[*]}"
}

# 特定のAIが利用可能かチェック
lite_is_ai_available() {
  local ai_name="$1"
  [[ "${LITE_AI_STATUS[$ai_name]:-}" == "available" ]]
}

# 利用可能なAI数を取得
lite_get_ai_count() {
  echo "${#LITE_AVAILABLE_AIS[@]}"
}

# ============================================================================
# Fallback Chain Functions
# ============================================================================

# フォールバックチェーンからベストなAIを取得
# Arguments: $@=AI names in priority order
# Returns: first available AI name, or empty
lite_get_best_available() {
  for ai in "$@"; do
    if lite_is_ai_available "$ai"; then
      echo "$ai"
      return 0
    fi
  done
  echo ""
  return 1
}

# ロール別のベストAIを取得
# Arguments: $1=role (strategy/research/prototype/enterprise/review/integration/pm)
lite_get_ai_for_role() {
  local role="$1"
  
  case "$role" in
    strategy|architecture)
      lite_get_best_available "claude" "gemini" "amp"
      ;;
    research|security)
      lite_get_best_available "gemini" "claude" "amp"
      ;;
    prototype|fast)
      lite_get_best_available "qwen" "claude" "cursor"
      ;;
    enterprise|quality)
      lite_get_best_available "droid" "claude" "qwen"
      ;;
    review|optimize)
      lite_get_best_available "codex" "claude" "gemini"
      ;;
    integration|testing)
      lite_get_best_available "cursor" "qwen" "codex"
      ;;
    pm|documentation)
      lite_get_best_available "amp" "claude" "gemini"
      ;;
    *)
      # デフォルト: 利用可能な最初のAI
      echo "${LITE_AVAILABLE_AIS[0]:-}"
      ;;
  esac
}

# ============================================================================
# Recommendation Functions
# ============================================================================

# 不足AIのインストール推奨を表示
lite_show_recommendations() {
  local missing_core=()
  local missing_important=()
  local missing_optional=()
  
  for def in "${LITE_AI_DEFINITIONS[@]}"; do
    IFS=':' read -r name cmd role priority <<< "$def"
    
    if [[ "${LITE_AI_STATUS[$name]:-}" != "available" ]]; then
      case "$priority" in
        1) missing_core+=("$name");;
        2) missing_important+=("$name");;
        3) missing_optional+=("$name");;
      esac
    fi
  done
  
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "  📋 Recommendations" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  
  if [[ ${#missing_core[@]} -gt 0 ]]; then
    echo "" >&2
    echo "  🔴 Core AIs (highly recommended):" >&2
    for ai in "${missing_core[@]}"; do
      _lite_show_install_hint "$ai"
    done
  fi
  
  if [[ ${#missing_important[@]} -gt 0 ]]; then
    echo "" >&2
    echo "  🟡 Important AIs (recommended for better results):" >&2
    for ai in "${missing_important[@]}"; do
      _lite_show_install_hint "$ai"
    done
  fi
  
  if [[ ${#missing_optional[@]} -gt 0 ]]; then
    echo "" >&2
    echo "  🟢 Optional AIs (for full experience):" >&2
    for ai in "${missing_optional[@]}"; do
      _lite_show_install_hint "$ai"
    done
  fi
  
  echo "" >&2
}

# AIごとのインストールヒント
_lite_show_install_hint() {
  local ai="$1"
  
  case "$ai" in
    claude)
      echo "     • claude: npm install -g @anthropic-ai/claude-code" >&2
      ;;
    gemini)
      echo "     • gemini: npm install -g @google/gemini-cli" >&2
      ;;
    qwen)
      echo "     • qwen: npm install -g @anthropic-ai/qwen-code" >&2
      ;;
    droid)
      echo "     • droid: https://docs.factory.ai/cli/getting-started/quickstart" >&2
      ;;
    codex)
      echo "     • codex: npm install -g @openai/codex" >&2
      ;;
    cursor)
      echo "     • cursor: https://cursor.com/ja/docs/cli/overview" >&2
      ;;
    amp)
      echo "     • amp: https://ampcode.com/manual" >&2
      ;;
  esac
}

# ============================================================================
# JSON Output
# ============================================================================

# JSON形式で結果を出力
lite_output_json() {
  local json="{"
  json+="\"mode\":\"$LITE_CURRENT_MODE\","
  json+="\"ai_count\":${#LITE_AVAILABLE_AIS[@]},"
  json+="\"available_ais\":["
  
  local first=true
  for ai in "${LITE_AVAILABLE_AIS[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      json+=","
    fi
    json+="{\"name\":\"$ai\",\"version\":\"${LITE_AI_VERSION[$ai]:-unknown}\"}"
  done
  
  json+="],"
  json+="\"unavailable_ais\":["
  
  first=true
  for def in "${LITE_AI_DEFINITIONS[@]}"; do
    IFS=':' read -r name cmd role priority <<< "$def"
    if [[ "${LITE_AI_STATUS[$name]:-}" != "available" ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        json+=","
      fi
      json+="\"$name\""
    fi
  done
  
  json+="]}"
  
  echo "$json"
}

# ============================================================================
# Main Entry Point (if run directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # コマンドライン引数の処理
  case "${1:-check}" in
    check)
      lite_check_all_ais
      ;;
    recommend)
      lite_check_all_ais
      lite_show_recommendations
      ;;
    json)
      lite_check_all_ais 2>/dev/null
      lite_output_json
      ;;
    mode)
      lite_check_all_ais 2>/dev/null
      lite_get_available_mode
      ;;
    list)
      lite_check_all_ais 2>/dev/null
      lite_get_available_ais
      ;;
    *)
      echo "Usage: $0 {check|recommend|json|mode|list}"
      echo ""
      echo "Commands:"
      echo "  check     - Check all AIs and show status (default)"
      echo "  recommend - Check AIs and show installation recommendations"
      echo "  json      - Output results in JSON format"
      echo "  mode      - Output only the detected mode"
      echo "  list      - Output only the list of available AIs"
      exit 1
      ;;
  esac
fi
