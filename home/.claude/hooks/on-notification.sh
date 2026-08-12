#!/usr/bin/env bash
# ~/.claude/hooks/on-notification.sh — fires when Claude needs user input.
# Registered under hooks.Notification in ~/.claude/settings.json.
# Input: JSON on stdin; includes message, title, notification_type fields.
# Always exits 0.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh" 2>/dev/null || exit 0

main() {
  parse_stdin || return 0
  lookup_pane "$HOOK_SESSION_ID"

  local notif_title="Claude — ${HOOK_WORKTREE} !"
  local msg="${HOOK_MESSAGE:-needs your input}"
  local label="! ${HOOK_WORKTREE}"

  notify_mac "$notif_title" "$msg" "Ping"

  if [[ -n "${HOOK_PANE_TARGET:-}" ]]; then
    tmux display-message -t "$HOOK_PANE_TARGET" \
      "! input needed: ${msg:0:60}" 2>/dev/null || true
  fi

  flash_window "${HOOK_PANE_TARGET:-}" "$label" 6

  append_ready_log "notification" "$HOOK_SESSION_ID" "$msg" \
    "${HOOK_CWD:-}" "${HOOK_PANE_TARGET:-}" "${HOOK_WORKTREE:-}"
}

main "$@"
exit 0
