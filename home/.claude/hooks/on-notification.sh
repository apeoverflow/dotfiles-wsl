#!/usr/bin/env bash
# ~/.claude/hooks/on-notification.sh — fires when the agent needs user input.
# Always exits 0.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh" 2>/dev/null || exit 0

install_watchdog 5
log_debug start "on-notification"

main() {
  parse_stdin || return 0
  lookup_pane "$HOOK_SESSION_ID"

  local notif_title="Copilot — ${HOOK_WORKTREE} !"
  local msg="${HOOK_MESSAGE:-needs your input}"
  local label="! ${HOOK_WORKTREE}"

  log_debug notify "$notif_title"
  notify_mac "$notif_title" "$msg" "Ping"

  if [[ -n "${HOOK_PANE_TARGET:-}" ]]; then
    run_limited 2 tmux display-message -t "$HOOK_PANE_TARGET" \
      "! input needed: ${msg:0:60}" >/dev/null 2>&1 || true
  fi

  flash_window "${HOOK_PANE_TARGET:-}" "$label"
  append_ready_log "notification" "$HOOK_SESSION_ID" "$msg" \
    "${HOOK_CWD:-}" "${HOOK_PANE_TARGET:-}" "${HOOK_WORKTREE:-}"
  log_debug done "$msg"
}

main "$@"
exit 0
