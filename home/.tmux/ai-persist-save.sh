#!/usr/bin/env bash
# ~/.tmux/ai-persist-save.sh
# Snapshot the copilot sessions that are live *right now* so they can be
# re-attached after a reboot. Fired by tmux-resurrect's post-save hook
# (@resurrect-hook-post-save-all), so it runs on every save — including
# tmux-continuum's periodic auto-save.
#
# The session id for each pane is read from the LIVE PROCESS, not from tmux
# window/pane indices (which drift under `renumber-windows on`) or from the
# ~/.claude/pane-map cache (which goes stale). Specifically:
#   * copilot writes ~/.copilot/session-state/<sid>/inuse.<pid>.lock while a
#     session is open  ->  pid in the pane's process group  =>  authoritative sid
# Result frozen into ai-live.json as {pane_target, tool, session_id, cwd}.
set -uo pipefail

OUT_DIR="${AI_PERSIST_DIR:-$HOME/.tmux/ai-persist}"
OUT="$OUT_DIR/ai-live.json"
COPILOT_STATE="${AI_PERSIST_COPILOT_STATE:-$HOME/.copilot/session-state}"
mkdir -p "$OUT_DIR"

command -v jq >/dev/null 2>&1 || exit 0

# copilot: session id for a pid, from ~/.copilot/session-state/<sid>/inuse.<pid>.lock
# (kept bash-3.2 friendly — macOS default bash has no associative arrays).
copilot_sid_for_pid() {
  local pid="$1" lock
  for lock in "$COPILOT_STATE"/*/"inuse.$pid.lock"; do
    [[ -e "$lock" ]] || continue
    basename "$(dirname "$lock")"
    return 0
  done
  return 1
}

# A copilot session is only resumable if it has recorded events. When you
# `copilot --resume=<id>`, copilot spins up a fresh *empty* fork (no events.jsonl)
# and locks that — resuming that fork id would fail. So if the live session is an
# empty fork, fall back to the newest session WITH events in the same cwd (the
# parent), which is what the user actually wants back.
copilot_resumable_sid() {
  local sid="$1" cwd="$2" d best="" bestmt=0 mt c
  [[ -s "$COPILOT_STATE/$sid/events.jsonl" ]] && { echo "$sid"; return 0; }
  for d in "$COPILOT_STATE"/*/; do
    [[ -s "$d/events.jsonl" ]] || continue
    c=$(awk -F': ' '/^cwd:/{print $2; exit}' "$d/workspace.yaml" 2>/dev/null)
    [[ "$c" == "$cwd" ]] || continue
    mt=$(stat -c %Y "$d/events.jsonl" 2>/dev/null || stat -f %m "$d/events.jsonl" 2>/dev/null || echo 0)
    if (( mt >= bestmt )); then bestmt=$mt; best=$(basename "$d"); fi
  done
  [[ -n "$best" ]] && { echo "$best"; return 0; }
  return 1
}

# All pids in a pane's process group (pane_pid is the group leader).
group_pids() {
  local pane_pid="$1" pgid
  pgid=$(/bin/ps -o pgid= -p "$pane_pid" 2>/dev/null | tr -d ' ')
  [[ -n "$pgid" ]] || { echo "$pane_pid"; return; }
  /bin/ps -o pid= -g "$pgid" 2>/dev/null | tr -d ' '
}

entries=()
while IFS=$'\t' read -r target pane_pid path; do
  [[ -n "$pane_pid" ]] || continue
  tool="" sid=""
  # gather the pane's process group once
  pids=$(group_pids "$pane_pid")

  # copilot via its inuse.<pid>.lock, resolving empty forks to their resumable parent
  for p in $pids; do
    s=$(copilot_sid_for_pid "$p") || true
    if [[ -n "${s:-}" ]]; then
      s=$(copilot_resumable_sid "$s" "$path") || s=""
      [[ -n "$s" ]] && { tool="copilot"; sid="$s"; }
      break
    fi
  done

  # fallback: OSC-2 title set by cw (`copilot:<session_id>`) — e.g. if the
  # inuse lock isn't visible; still only kept if the session is resumable.
  if [[ -z "$tool" ]]; then
    pane_title=$(tmux display-message -t "$target" -p '#{pane_title}' 2>/dev/null) || true
    if [[ "$pane_title" == copilot:* ]]; then
      s=$(copilot_resumable_sid "${pane_title#copilot:}" "$path") || s=""
      [[ -n "$s" ]] && { tool="copilot"; sid="$s"; }
    fi
  fi

  [[ -n "$tool" && -n "$sid" ]] || continue
  entries+=("$(jq -nc \
    --arg t "$target" --arg tool "$tool" --arg sid "$sid" --arg cwd "$path" \
    '{pane_target:$t, tool:$tool, session_id:$sid, cwd:$cwd}')")
done < <(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}	#{pane_pid}	#{pane_current_path}')

tmp=$(mktemp "${TMPDIR:-/tmp}/ai-live.XXXXXX")
if (( ${#entries[@]} )); then
  printf '%s\n' "${entries[@]}" | jq -s '.' > "$tmp"
else
  printf '[]\n' > "$tmp"
fi
mv "$tmp" "$OUT"
