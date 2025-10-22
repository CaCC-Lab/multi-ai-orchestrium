#!/usr/bin/env bash
# AI Tools Checker - Notifier Module
# Version: 2.1.0
# Date: 2025-01-12

# This module provides multi-channel notification functionality including
# Slack, Discord, Email, and generic webhooks with retry logic.

# Source dependencies
_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODULE_DIR}/../core/interfaces.sh" 2>/dev/null || true
source "${_MODULE_DIR}/../utils/helpers.sh" 2>/dev/null || true

# Notification configuration
NOTIFY_ENABLED="${NOTIFY_ENABLED:-false}"
NOTIFY_CHANNELS="${NOTIFY_CHANNELS:-}"  # Comma-separated: slack,discord,email
NOTIFY_ON_UPDATE="${NOTIFY_ON_UPDATE:-true}"
NOTIFY_ON_INSTALL="${NOTIFY_ON_INSTALL:-false}"
NOTIFY_ON_ERROR="${NOTIFY_ON_ERROR:-true}"
NOTIFY_RETRY_COUNT="${NOTIFY_RETRY_COUNT:-3}"
NOTIFY_RETRY_DELAY="${NOTIFY_RETRY_DELAY:-2}"

# Channel-specific configuration
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_FROM="${EMAIL_FROM:-aitools@localhost}"
GENERIC_WEBHOOK="${GENERIC_WEBHOOK:-}"

# ============================================================
# Notification Templates
# ============================================================

# render_template(template_name, variables...)
# Renders a notification template with variable substitution
#
# Arguments:
#   $1 - Template name (update_available, update_success, etc.)
#   $2+ - Variable assignments (KEY=VALUE)
# Returns: 0 on success
# Outputs: Rendered template to stdout
render_template() {
  local template_name="$1"
  shift
  local -A vars=()

  # Parse variable assignments
  for arg in "$@"; do
    if [[ "$arg" =~ ^([A-Z_]+)=(.*)$ ]]; then
      vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done

  # Render template
  case "$template_name" in
    update_available)
      cat <<TEMPLATE
🔔 **AI Tool Update Available**

**Tool:** ${vars[TOOL_NAME]:-Unknown}
**Current:** ${vars[CURRENT_VERSION]:-Unknown}
**Latest:** ${vars[LATEST_VERSION]:-Unknown}

Run \`check-ai-tools update\` to update.
TEMPLATE
      ;;

    update_success)
      cat <<TEMPLATE
✅ **AI Tool Updated Successfully**

**Tool:** ${vars[TOOL_NAME]:-Unknown}
**From:** ${vars[OLD_VERSION]:-Unknown}
**To:** ${vars[NEW_VERSION]:-Unknown}

Update completed at $(date '+%Y-%m-%d %H:%M:%S')
TEMPLATE
      ;;

    update_error)
      cat <<TEMPLATE
❌ **AI Tool Update Failed**

**Tool:** ${vars[TOOL_NAME]:-Unknown}
**Error:** ${vars[ERROR_MESSAGE]:-Unknown error}

Please check the logs for more details.
TEMPLATE
      ;;

    install_success)
      cat <<TEMPLATE
🎉 **AI Tool Installed Successfully**

**Tool:** ${vars[TOOL_NAME]:-Unknown}
**Version:** ${vars[VERSION]:-Unknown}

Installation completed at $(date '+%Y-%m-%d %H:%M:%S')
TEMPLATE
      ;;

    breaking_changes)
      cat <<TEMPLATE
⚠️ **Breaking Changes Detected**

**Tool:** ${vars[TOOL_NAME]:-Unknown}
**Current:** ${vars[CURRENT_VERSION]:-Unknown}
**Latest:** ${vars[LATEST_VERSION]:-Unknown}

Major version update detected. Please review release notes before updating.
TEMPLATE
      ;;

    *)
      echo "Unknown template: $template_name"
      return 1
      ;;
  esac

  return 0
}

# ============================================================
# Slack Notifications
# ============================================================

# send_slack(message, [color])
# Sends a notification to Slack via webhook
#
# Arguments:
#   $1 - Message text
#   $2 - Optional color (good, warning, danger)
# Returns: 0 on success, 1 on failure
send_slack() {
  local message="$1"
  local color="${2:-good}"

  if [[ -z "$SLACK_WEBHOOK" ]]; then
    log_warn "SLACK_WEBHOOK not configured"
    return 1
  fi

  log_debug "Sending Slack notification"

  # Build JSON payload
  local payload
  payload=$(cat <<SLACKJSON
{
  "attachments": [
    {
      "color": "$color",
      "text": $(echo "$message" | jq -Rs .),
      "footer": "AI Tools Checker",
      "footer_icon": "https://platform.slack-edge.com/img/default_application_icon.png",
      "ts": $(date +%s)
    }
  ]
}
SLACKJSON
)

  # Send with retry
  if send_webhook "$SLACK_WEBHOOK" "$payload"; then
    log_info "Slack notification sent successfully"
    return 0
  else
    log_error "Failed to send Slack notification"
    return 1
  fi
}

# ============================================================
# Discord Notifications
# ============================================================

# send_discord(message, [color])
# Sends a notification to Discord via webhook
#
# Arguments:
#   $1 - Message text
#   $2 - Optional color (hex code, default: 0x00ff00)
# Returns: 0 on success, 1 on failure
send_discord() {
  local message="$1"
  local color="${2:-0x00ff00}"

  if [[ -z "$DISCORD_WEBHOOK" ]]; then
    log_warn "DISCORD_WEBHOOK not configured"
    return 1
  fi

  log_debug "Sending Discord notification"

  # Convert named colors to hex
  case "$color" in
    good|success|green) color="0x00ff00" ;;
    warning|yellow) color="0xffff00" ;;
    danger|error|red) color="0xff0000" ;;
  esac

  # Build JSON payload
  local payload
  payload=$(cat <<DISCORDJSON
{
  "embeds": [
    {
      "description": $(echo "$message" | jq -Rs .),
      "color": $color,
      "footer": {
        "text": "AI Tools Checker"
      },
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
  ]
}
DISCORDJSON
)

  # Send with retry
  if send_webhook "$DISCORD_WEBHOOK" "$payload"; then
    log_info "Discord notification sent successfully"
    return 0
  else
    log_error "Failed to send Discord notification"
    return 1
  fi
}

# ============================================================
# Email Notifications
# ============================================================

# send_email(subject, body)
# Sends an email notification
#
# Arguments:
#   $1 - Email subject
#   $2 - Email body
# Returns: 0 on success, 1 on failure
send_email() {
  local subject="$1"
  local body="$2"

  if [[ -z "$EMAIL_TO" ]]; then
    log_warn "EMAIL_TO not configured"
    return 1
  fi

  log_debug "Sending email notification to: $EMAIL_TO"

  # Check for mail command
  if ! have mail && ! have sendmail; then
    log_error "No mail command available (mail or sendmail)"
    return 1
  fi

  # Send email
  if have mail; then
    echo "$body" | mail -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO"
  elif have sendmail; then
    {
      echo "From: $EMAIL_FROM"
      echo "To: $EMAIL_TO"
      echo "Subject: $subject"
      echo ""
      echo "$body"
    } | sendmail -t
  fi

  local result=$?

  if [[ $result -eq 0 ]]; then
    log_info "Email notification sent successfully"
    return 0
  else
    log_error "Failed to send email notification"
    return 1
  fi
}

# ============================================================
# Generic Webhook
# ============================================================

# send_webhook(url, payload)
# Sends a generic webhook POST request with retry logic
#
# Arguments:
#   $1 - Webhook URL
#   $2 - JSON payload
# Returns: 0 on success, 1 on failure
send_webhook() {
  local url="$1"
  local payload="$2"
  local attempt=0

  while [[ $attempt -lt $NOTIFY_RETRY_COUNT ]]; do
    attempt=$((attempt + 1))

    log_debug "Webhook attempt $attempt/$NOTIFY_RETRY_COUNT: $url"

    # Send POST request
    local response
    local http_code

    if have curl; then
      response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$url" 2>&1)
      http_code=$(echo "$response" | tail -n1)
    elif have wget; then
      response=$(wget -q -O- \
        --method=POST \
        --header="Content-Type: application/json" \
        --body-data="$payload" \
        "$url" 2>&1)
      http_code="$?"
      [[ "$http_code" == "0" ]] && http_code="200"
    else
      log_error "Neither curl nor wget available"
      return 1
    fi

    # Check response
    if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
      log_debug "Webhook sent successfully (HTTP $http_code)"
      return 0
    else
      log_warn "Webhook failed with HTTP $http_code (attempt $attempt/$NOTIFY_RETRY_COUNT)"

      if [[ $attempt -lt $NOTIFY_RETRY_COUNT ]]; then
        sleep "$NOTIFY_RETRY_DELAY"
      fi
    fi
  done

  log_error "Webhook failed after $NOTIFY_RETRY_COUNT attempts"
  return 1
}

# ============================================================
# High-Level Notification Functions
# ============================================================

# notify(template_name, variables...)
# Sends notification to all configured channels
#
# Arguments:
#   $1 - Template name
#   $2+ - Variable assignments (KEY=VALUE)
# Returns: 0 if at least one channel succeeds
notify() {
  if [[ "$NOTIFY_ENABLED" != "true" ]]; then
    log_debug "Notifications disabled (NOTIFY_ENABLED=false)"
    return 0
  fi

  local template_name="$1"
  shift

  # Render message
  local message
  message=$(render_template "$template_name" "$@")

  if [[ -z "$message" ]]; then
    log_error "Failed to render template: $template_name"
    return 1
  fi

  # Determine color based on template
  local color="good"
  case "$template_name" in
    *_error|breaking_changes) color="danger" ;;
    update_available) color="warning" ;;
  esac

  # Parse channels
  local -a channels=()
  IFS=',' read -ra channels <<< "$NOTIFY_CHANNELS"

  if [[ ${#channels[@]} -eq 0 ]]; then
    log_warn "No notification channels configured (NOTIFY_CHANNELS)"
    return 0
  fi

  # Send to each channel
  local success_count=0
  local fail_count=0

  for channel in "${channels[@]}"; do
    channel=$(echo "$channel" | xargs)  # Trim whitespace

    case "$channel" in
      slack)
        if send_slack "$message" "$color"; then
          success_count=$((success_count + 1))
        else
          fail_count=$((fail_count + 1))
        fi
        ;;

      discord)
        if send_discord "$message" "$color"; then
          success_count=$((success_count + 1))
        else
          fail_count=$((fail_count + 1))
        fi
        ;;

      email)
        local subject="AI Tools Checker: $template_name"
        if send_email "$subject" "$message"; then
          success_count=$((success_count + 1))
        else
          fail_count=$((fail_count + 1))
        fi
        ;;

      webhook)
        if [[ -n "$GENERIC_WEBHOOK" ]]; then
          local payload="{\"text\": $(echo "$message" | jq -Rs .)}"
          if send_webhook "$GENERIC_WEBHOOK" "$payload"; then
            success_count=$((success_count + 1))
          else
            fail_count=$((fail_count + 1))
          fi
        else
          log_warn "Generic webhook channel configured but GENERIC_WEBHOOK not set"
          fail_count=$((fail_count + 1))
        fi
        ;;

      *)
        log_warn "Unknown notification channel: $channel"
        fail_count=$((fail_count + 1))
        ;;
    esac
  done

  log_info "Notifications: $success_count succeeded, $fail_count failed"

  # Success if at least one channel succeeded
  [[ $success_count -gt 0 ]]
}

# ============================================================
# Convenience Notification Functions
# ============================================================

# notify_update_available(tool_name, current_version, latest_version)
# Notifies about available update
notify_update_available() {
  if [[ "$NOTIFY_ON_UPDATE" != "true" ]]; then
    return 0
  fi

  notify "update_available" \
    "TOOL_NAME=$1" \
    "CURRENT_VERSION=$2" \
    "LATEST_VERSION=$3"
}

# notify_update_success(tool_name, old_version, new_version)
# Notifies about successful update
notify_update_success() {
  if [[ "$NOTIFY_ON_UPDATE" != "true" ]]; then
    return 0
  fi

  notify "update_success" \
    "TOOL_NAME=$1" \
    "OLD_VERSION=$2" \
    "NEW_VERSION=$3"
}

# notify_update_error(tool_name, error_message)
# Notifies about update error
notify_update_error() {
  if [[ "$NOTIFY_ON_ERROR" != "true" ]]; then
    return 0
  fi

  notify "update_error" \
    "TOOL_NAME=$1" \
    "ERROR_MESSAGE=$2"
}

# notify_install_success(tool_name, version)
# Notifies about successful installation
notify_install_success() {
  if [[ "$NOTIFY_ON_INSTALL" != "true" ]]; then
    return 0
  fi

  notify "install_success" \
    "TOOL_NAME=$1" \
    "VERSION=$2"
}

# notify_breaking_changes(tool_name, current_version, latest_version)
# Notifies about breaking changes
notify_breaking_changes() {
  if [[ "$NOTIFY_ON_UPDATE" != "true" ]]; then
    return 0
  fi

  notify "breaking_changes" \
    "TOOL_NAME=$1" \
    "CURRENT_VERSION=$2" \
    "LATEST_VERSION=$3"
}

# ============================================================
# Testing & Validation
# ============================================================

# test_notifications()
# Sends test notifications to all configured channels
#
# Returns: 0 on success
test_notifications() {
  display_section "Testing Notification Channels"

  local test_message="🧪 **Test Notification**

This is a test message from AI Tools Checker.

Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)"

  # Parse channels
  local -a channels=()
  IFS=',' read -ra channels <<< "$NOTIFY_CHANNELS"

  if [[ ${#channels[@]} -eq 0 ]]; then
    display_warning "No notification channels configured"
    echo "Set NOTIFY_CHANNELS environment variable (e.g., 'slack,discord,email')"
    return 1
  fi

  echo "Testing channels: ${channels[*]}"
  echo ""

  local success_count=0
  local fail_count=0

  for channel in "${channels[@]}"; do
    channel=$(echo "$channel" | xargs)

    print_blue "Testing $channel..."

    case "$channel" in
      slack)
        if send_slack "$test_message" "good"; then
          print_green "  ✓ Slack test successful"
          success_count=$((success_count + 1))
        else
          print_red "  ✗ Slack test failed"
          fail_count=$((fail_count + 1))
        fi
        ;;

      discord)
        if send_discord "$test_message" "0x00ff00"; then
          print_green "  ✓ Discord test successful"
          success_count=$((success_count + 1))
        else
          print_red "  ✗ Discord test failed"
          fail_count=$((fail_count + 1))
        fi
        ;;

      email)
        if send_email "AI Tools Checker Test" "$test_message"; then
          print_green "  ✓ Email test successful"
          success_count=$((success_count + 1))
        else
          print_red "  ✗ Email test failed"
          fail_count=$((fail_count + 1))
        fi
        ;;

      webhook)
        if [[ -n "$GENERIC_WEBHOOK" ]]; then
          local payload="{\"text\": $(echo "$test_message" | jq -Rs .)}"
          if send_webhook "$GENERIC_WEBHOOK" "$payload"; then
            print_green "  ✓ Webhook test successful"
            success_count=$((success_count + 1))
          else
            print_red "  ✗ Webhook test failed"
            fail_count=$((fail_count + 1))
          fi
        else
          print_red "  ✗ GENERIC_WEBHOOK not configured"
          fail_count=$((fail_count + 1))
        fi
        ;;

      *)
        print_red "  ✗ Unknown channel: $channel"
        fail_count=$((fail_count + 1))
        ;;
    esac
  done

  echo ""
  print_blue "Test Summary:"
  echo "  Success: $success_count/${#channels[@]}"
  echo "  Failed:  $fail_count/${#channels[@]}"

  [[ $fail_count -eq 0 ]]
}

# ============================================================
# Module Information
# ============================================================

# notifier_module_info()
# Displays module information
notifier_module_info() {
  cat <<EOF
AI Tools Checker - Notifier Module
Version: 2.1.0
Date: 2025-01-12

Functions provided:
  Templates:
    - render_template()             Render notification template

  Channels:
    - send_slack()                  Send to Slack
    - send_discord()                Send to Discord
    - send_email()                  Send email
    - send_webhook()                Generic webhook (with retry)

  High-Level:
    - notify()                      Multi-channel notification
    - notify_update_available()     Update available notification
    - notify_update_success()       Update success notification
    - notify_update_error()         Update error notification
    - notify_install_success()      Install success notification
    - notify_breaking_changes()     Breaking changes notification

  Testing:
    - test_notifications()          Test all channels

Configuration:
  - NOTIFY_ENABLED:         $NOTIFY_ENABLED
  - NOTIFY_CHANNELS:        $NOTIFY_CHANNELS
  - NOTIFY_ON_UPDATE:       $NOTIFY_ON_UPDATE
  - NOTIFY_ON_INSTALL:      $NOTIFY_ON_INSTALL
  - NOTIFY_ON_ERROR:        $NOTIFY_ON_ERROR
  - NOTIFY_RETRY_COUNT:     $NOTIFY_RETRY_COUNT
  - NOTIFY_RETRY_DELAY:     $NOTIFY_RETRY_DELAY

  - SLACK_WEBHOOK:          $(if [[ -n "$SLACK_WEBHOOK" ]]; then echo "Configured"; else echo "Not set"; fi)
  - DISCORD_WEBHOOK:        $(if [[ -n "$DISCORD_WEBHOOK" ]]; then echo "Configured"; else echo "Not set"; fi)
  - EMAIL_TO:               $(if [[ -n "$EMAIL_TO" ]]; then echo "Configured"; else echo "Not set"; fi)
  - GENERIC_WEBHOOK:        $(if [[ -n "$GENERIC_WEBHOOK" ]]; then echo "Configured"; else echo "Not set"; fi)

Available Templates:
  - update_available
  - update_success
  - update_error
  - install_success
  - breaking_changes

Dependencies:
  - interfaces.sh (log_*)
  - helpers.sh (have, display_*)
  - curl or wget (for webhooks)
  - mail or sendmail (for email)
  - jq (for JSON encoding)
EOF
}

# Export functions
declare -fx render_template 2>/dev/null || true
declare -fx send_slack 2>/dev/null || true
declare -fx send_discord 2>/dev/null || true
declare -fx send_email 2>/dev/null || true
declare -fx send_webhook 2>/dev/null || true
declare -fx notify 2>/dev/null || true
declare -fx notify_update_available 2>/dev/null || true
declare -fx notify_update_success 2>/dev/null || true
declare -fx notify_update_error 2>/dev/null || true
declare -fx notify_install_success 2>/dev/null || true
declare -fx notify_breaking_changes 2>/dev/null || true
declare -fx test_notifications 2>/dev/null || true
