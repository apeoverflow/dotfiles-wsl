#!/usr/bin/env bash
# ~/.claude/hooks/lib.sh — shared functions sourced by on-stop.sh and on-notification.sh.
# Never called directly.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PANE_MAP_DIR="$HOME/.claude/pane-map"
READY_LOG="$HOME/.claude/ready.log"
ERROR_LOG="$HOME/.claude/hooks/error.log"

log_error() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$ERROR_LOG" 2>/dev/null || true
}

# Read hook stdin JSON. Sets globals:
#   HOOK_SESSION_ID, HOOK_TRANSCRIPT_PATH, HOOK_CWD, HOOK_EVENT, HOOK_MESSAGE
parse_stdin() {
  local input
  input=$(cat)
  HOOK_SESSION_ID=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || true
  HOOK_TRANSCRIPT_PATH=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || true
  HOOK_CWD=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || true
  HOOK_EVENT=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null) || true
  HOOK_MESSAGE=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null) || true

  if [[ -z "${HOOK_SESSION_ID:-}" ]]; then
    log_error "parse_stdin: missing session_id in hook input"
    return 1
  fi
}

# Extract the first non-meta user message from a jsonl file. Sets HOOK_TITLE.
extract_title() {
  local jsonl="$1"
  HOOK_TITLE="(untitled)"
  [[ -f "$jsonl" ]] || return 0

  local result
  result=$(jq -r '
    select((.role // .message.role // .type) == "user") |
    (.message.content // .content) |
    if type == "string" then .
    elif type == "array" then map(.text // "") | join("")
    else empty end |
    select(length > 0 and length <= 500) |
    select(test("^\\s*<") | not) |
    select(test("^\\s*(You are |You'\''re a|# |##)") | not) |
    gsub("\n"; " ") |
    .[:80]
  ' "$jsonl" 2>/dev/null | head -1) || true

  [[ -n "$result" ]] && HOOK_TITLE="$result"
}

# Read pane-map entry for a session. Sets HOOK_PANE_TARGET, HOOK_WORKTREE.
lookup_pane() {
  local sid="$1"
  HOOK_PANE_TARGET=""
  HOOK_WORKTREE="$(basename "${HOOK_CWD:-unknown}")"

  local mapfile="$PANE_MAP_DIR/${sid}.json"
  [[ -f "$mapfile" ]] || return 0

  HOOK_PANE_TARGET=$(jq -r '.pane_target // empty' "$mapfile" 2>/dev/null) || HOOK_PANE_TARGET=""
  local wt
  wt=$(jq -r '.worktree // empty' "$mapfile" 2>/dev/null) || true
  [[ -n "$wt" ]] && HOOK_WORKTREE="$wt"
}

# Append one JSON line to ready.log.
append_ready_log() {
  local event="$1" sid="$2" title="$3" cwd="$4" pane_target="$5" worktree="$6"
  local ts
  ts=$(date +%s)
  jq -cn \
    --argjson ts "$ts" \
    --arg event "$event" \
    --arg session_id "$sid" \
    --arg title "$title" \
    --arg cwd "$cwd" \
    --arg pane_target "$pane_target" \
    --arg worktree "$worktree" \
    '{ts:$ts,event:$event,session_id:$session_id,title:$title,cwd:$cwd,pane_target:$pane_target,worktree:$worktree}' \
    >> "$READY_LOG"
}

# Fire a desktop notification. Name kept as notify_mac() for parity with the
# macOS repo, but on WSL it uses (in order): terminal-notifier if present,
# notify-send (WSLg / a Linux notification daemon), or a Windows toast via
# PowerShell. Best-effort — never blocks or fails the hook.
notify_mac() {
  local title="$1" message="$2" sound="${3:-default}"
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$title" -message "$message" -sound "$sound" &
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message" &
  elif command -v powershell.exe >/dev/null 2>&1; then
    # Simple Windows balloon toast — no extra modules required.
    powershell.exe -NoProfile -Command "
      Add-Type -AssemblyName System.Windows.Forms;
      \$n = New-Object System.Windows.Forms.NotifyIcon;
      \$n.Icon = [System.Drawing.SystemIcons]::Information;
      \$n.BalloonTipTitle = '$title'; \$n.BalloonTipText = '$message';
      \$n.Visible = \$true; \$n.ShowBalloonTip(4000)" >/dev/null 2>&1 &
  fi
}

# Permanently rename the tmux window until the user visits it.
# The "✓ name" stays in the status bar as a persistent indicator.
# Skips rename if the user is already on this window (no hook would clear it).
flash_window() {
  local pane_target="$1" label="$2"
  [[ -z "$pane_target" ]] && return 0
  command -v tmux >/dev/null 2>&1 || return 0
  local win_target="${pane_target%.*}"
  local active_window
  active_window=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null) || true
  [[ "$win_target" == "$active_window" ]] && return 0
  tmux rename-window -t "$win_target" "$label" 2>/dev/null || true
}
