#!/usr/bin/env bash
# ~/.claude/hooks/on-stop.sh — fires when a Claude/Grok turn finishes.
# Always exits 0 — hook failures must not interrupt the agent.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh" 2>/dev/null || exit 0

install_watchdog 5
log_debug start "on-stop"

main() {
  parse_stdin || return 0
  log_debug parsed "agent=${HOOK_AGENT} reason=${HOOK_REASON}"

  # Grok also fires Stop at session end; notifying then is noise and can stall teardown.
  if [[ -n "${HOOK_REASON:-}" && "${HOOK_REASON}" != "end_turn" ]]; then
    log_debug skip "reason=${HOOK_REASON}"
    return 0
  fi

  lookup_pane "$HOOK_SESSION_ID"
  log_debug lookup "pane=${HOOK_PANE_TARGET:-} wt=${HOOK_WORKTREE:-}"

  # Grok's session log is not Claude jsonl; scanning it can block jq until the
  # 5s watchdog fires (live waits were exactly ~5049ms). Use the payload title.
  if [[ "$HOOK_AGENT" != "grok" ]]; then
    local last_user_ts
    last_user_ts=$(tail -c 65536 "${HOOK_TRANSCRIPT_PATH:-/dev/null}" 2>/dev/null \
      | tail -n +2 \
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
        log_debug skip "turn_under_15s"
        return 0
      fi
    fi
    extract_title "${HOOK_TRANSCRIPT_PATH:-}"
  fi
  [[ -z "${HOOK_TITLE:-}" || "$HOOK_TITLE" == "null" ]] && HOOK_TITLE="(untitled)"
  log_debug title "${HOOK_TITLE:0:80}"

  local label="✓ ${HOOK_WORKTREE}"
  local notif_title="Claude — ${HOOK_WORKTREE}"
  [[ "$HOOK_AGENT" == "grok" ]] && notif_title="Grok — ${HOOK_WORKTREE}"

  log_debug notify "$notif_title"
  notify_mac "$notif_title" "$HOOK_TITLE"

  if [[ -n "${HOOK_PANE_TARGET:-}" ]]; then
    local win_target="${HOOK_PANE_TARGET%.*}"
    local win_num win_name
    win_num=$(run_limited 2 tmux display-message -t "$win_target" -p '#{window_index}' 2>/dev/null) || win_num=""
    win_name=$(run_limited 2 tmux display-message -t "$win_target" -p '#{window_name}' 2>/dev/null) || win_name="$HOOK_WORKTREE"
    local prefix=""
    [[ -n "$win_num" ]] && prefix="[${win_num}] ${win_name}: "
    run_limited 2 tmux display-message -t "$HOOK_PANE_TARGET" \
      "✓ ${prefix}${HOOK_TITLE:0:60}" >/dev/null 2>&1 || true
  fi

  flash_window "${HOOK_PANE_TARGET:-}" "$label"
  append_ready_log "stop" "$HOOK_SESSION_ID" "$HOOK_TITLE" \
    "${HOOK_CWD:-}" "${HOOK_PANE_TARGET:-}" "${HOOK_WORKTREE:-}"
  log_debug done "title=${HOOK_TITLE:0:60}"
}

main "$@"
exit 0
