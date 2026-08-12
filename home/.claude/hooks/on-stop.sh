#!/usr/bin/env bash
# ~/.claude/hooks/on-stop.sh — fires when a Claude session finishes a turn.
# Registered under hooks.Stop in ~/.claude/settings.json.
# Input: JSON on stdin with session_id, transcript_path, cwd, hook_event_name.
# Always exits 0 — hook failures must not interrupt Claude.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh" 2>/dev/null || exit 0

main() {
  parse_stdin || return 0
  lookup_pane "$HOOK_SESSION_ID"

  # Skip notification if the turn completed in under 15 seconds
  local last_user_ts
  last_user_ts=$(tail -20 "${HOOK_TRANSCRIPT_PATH:-/dev/null}" 2>/dev/null \
    | jq -r 'select(.type == "user") | .timestamp // empty' 2>/dev/null \
    | tail -1) || true
  if [[ -n "$last_user_ts" ]]; then
    local clean_ts="${last_user_ts%%.*}"
    clean_ts="${clean_ts%Z}"
    local user_epoch now_ts
    # GNU date (Linux/WSL) first, BSD date (macOS) as fallback — portable.
    user_epoch=$(date -u -d "$clean_ts" +%s 2>/dev/null \
      || date -j -u -f "%Y-%m-%dT%H:%M:%S" "$clean_ts" +%s 2>/dev/null) || user_epoch=0
    now_ts=$(date +%s)
    if (( now_ts - user_epoch < 15 )); then
      return 0
    fi
  fi

  extract_title "${HOOK_TRANSCRIPT_PATH:-}"

  local label="✓ ${HOOK_WORKTREE}"
  local notif_title="Claude — ${HOOK_WORKTREE}"

  notify_mac "$notif_title" "$HOOK_TITLE"

  if [[ -n "${HOOK_PANE_TARGET:-}" ]]; then
    local win_target="${HOOK_PANE_TARGET%.*}"
    local win_num win_name
    win_num=$(tmux display-message -t "$win_target" -p '#{window_index}' 2>/dev/null) || win_num=""
    win_name=$(tmux display-message -t "$win_target" -p '#{window_name}' 2>/dev/null) || win_name="$HOOK_WORKTREE"
    local prefix=""
    [[ -n "$win_num" ]] && prefix="[${win_num}] ${win_name}: "
    tmux display-message -t "$HOOK_PANE_TARGET" \
      "✓ ${prefix}${HOOK_TITLE:0:60}" 2>/dev/null || true
  fi

  flash_window "${HOOK_PANE_TARGET:-}" "$label" 6

  append_ready_log "stop" "$HOOK_SESSION_ID" "$HOOK_TITLE" \
    "${HOOK_CWD:-}" "${HOOK_PANE_TARGET:-}" "${HOOK_WORKTREE:-}"
}

main "$@"
exit 0
