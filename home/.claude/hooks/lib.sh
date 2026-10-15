#!/usr/bin/env bash
# ~/.claude/hooks/lib.sh — shared helpers for on-stop / on-notification / on-session-start.
# Never called directly.

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

PANE_MAP_DIR="$HOME/.claude/pane-map"
READY_LOG="$HOME/.claude/ready.log"
ERROR_LOG="$HOME/.claude/hooks/error.log"
DEBUG_LOG="$HOME/.claude/hooks/debug.jsonl"

HOOK_START_S=${SECONDS}
HOOK_AGENT="claude"
HOOK_WATCHDOG_PID=""

log_error() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$ERROR_LOG" 2>/dev/null || true
}

# One JSON line per hook step. Safe to call before parse_stdin.
log_debug() {
  local step="$1"
  local detail="${*:2}"
  mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
  jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson elapsed "$((SECONDS - HOOK_START_S))" \
    --argjson pid "$$" \
    --arg event "${HOOK_EVENT:-}" \
    --arg step "$step" \
    --arg session_id "${HOOK_SESSION_ID:-}" \
    --arg agent "${HOOK_AGENT:-}" \
    --arg reason "${HOOK_REASON:-}" \
    --arg cwd "${HOOK_CWD:-}" \
    --arg detail "$detail" \
    '{ts:$ts,elapsed_sec:$elapsed,pid:$pid,event:$event,step:$step,session_id:$session_id,agent:$agent,reason:$reason,cwd:$cwd,detail:$detail}' \
    >> "$DEBUG_LOG" 2>/dev/null || true
}

# Hard-cap the hook so Claude/Grok never sit on "Running stop hook" for minutes.
# Grok's default Stop timeout is 600s; this watchdog is the inner fuse.
install_watchdog() {
  local sec="${1:-5}"
  (
    sleep "$sec"
    if kill -0 $$ 2>/dev/null; then
      jq -cn \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson elapsed "$sec" \
        --argjson pid "$$" \
        --arg event "${HOOK_EVENT:-}" \
        --arg step "watchdog_timeout" \
        --arg session_id "${HOOK_SESSION_ID:-}" \
        --arg agent "${HOOK_AGENT:-}" \
        --arg reason "${HOOK_REASON:-}" \
        --arg cwd "${HOOK_CWD:-}" \
        --arg detail "killed after ${sec}s" \
        '{ts:$ts,elapsed_sec:$elapsed,pid:$pid,event:$event,step:$step,session_id:$session_id,agent:$agent,reason:$reason,cwd:$cwd,detail:$detail}' \
        >> "$DEBUG_LOG" 2>/dev/null || true
      kill -TERM $$ 2>/dev/null || true
    fi
  ) &
  HOOK_WATCHDOG_PID=$!
  trap 'kill "$HOOK_WATCHDOG_PID" 2>/dev/null || true' EXIT
}

# Run a command with a wall-clock cap. GNU timeout(1) is standard on WSL/Linux;
# the perl fork+alarm fallback is the macOS repo's version, kept for parity.
run_limited() {
  local sec="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$sec" "$@"
    return
  fi
  perl -e '
    my $s = shift;
    my $pid = fork();
    exit 127 unless defined $pid;
    if ($pid == 0) { exec @ARGV; exit 127; }
    $SIG{ALRM} = sub { kill "TERM", $pid; exit 124 };
    alarm $s;
    waitpid $pid, 0;
    exit ($? == -1 ? 127 : ($? & 127 ? 128 + ($? & 127) : $? >> 8));
  ' "$sec" "$@"
}

# Read hook stdin JSON. Accepts Claude snake_case and Grok camelCase.
# Sets: HOOK_RAW, HOOK_SESSION_ID, HOOK_TRANSCRIPT_PATH, HOOK_CWD, HOOK_EVENT,
#       HOOK_MESSAGE, HOOK_REASON, HOOK_TITLE, HOOK_AGENT
parse_stdin() {
  HOOK_RAW=$(cat)
  local parsed
  parsed=$(printf '%s' "$HOOK_RAW" | jq -c '{
    session_id: (.session_id // .sessionId // ""),
    transcript_path: (.transcript_path // .transcriptPath // ""),
    cwd: (.cwd // ""),
    event: (.hook_event_name // .hookEventName // ""),
    message: (.message // ""),
    reason: (.reason // ""),
    last_assistant: (.lastAssistantMessage // .last_assistant_message // "")
  }' 2>/dev/null) || parsed=""

  if [[ -z "$parsed" ]]; then
    log_error "parse_stdin: invalid JSON"
    log_debug parse_fail "invalid JSON"
    return 1
  fi

  HOOK_SESSION_ID=$(printf '%s' "$parsed" | jq -r '.session_id')
  HOOK_TRANSCRIPT_PATH=$(printf '%s' "$parsed" | jq -r '.transcript_path')
  HOOK_CWD=$(printf '%s' "$parsed" | jq -r '.cwd')
  HOOK_EVENT=$(printf '%s' "$parsed" | jq -r '.event')
  HOOK_MESSAGE=$(printf '%s' "$parsed" | jq -r '.message')
  HOOK_REASON=$(printf '%s' "$parsed" | jq -r '.reason')
  # Collapse whitespace inside jq: `| tr '\n' ' '` also turned jq's trailing
  # newline into a space, so an empty title became " " and skipped extract_title.
  HOOK_TITLE=$(printf '%s' "$parsed" | jq -r '.last_assistant | gsub("\\s+"; " ") | ltrimstr(" ") | .[:80]')

  if [[ -n "${GROK_SESSION_ID:-}" || -n "${GROK_HOOK_EVENT:-}" ]]; then
    HOOK_AGENT="grok"
  fi

  if [[ -z "${HOOK_SESSION_ID:-}" ]]; then
    log_error "parse_stdin: missing session_id"
    log_debug parse_fail "missing session_id"
    return 1
  fi
}

# Prefer the payload title; otherwise scan only the tail of the transcript.
extract_title() {
  local jsonl="$1"
  if [[ -n "${HOOK_TITLE:-}" && "$HOOK_TITLE" != "null" ]]; then
    return 0
  fi
  HOOK_TITLE="(untitled)"
  [[ -f "$jsonl" ]] || return 0

  local result
  result=$(tail -c 131072 "$jsonl" 2>/dev/null \
    | tail -n +2 \
    | jq -r '
        select((.role // .message.role // .type) == "user") |
        (.message.content // .content) |
        if type == "string" then .
        elif type == "array" then map(.text // "") | join("")
        else empty end |
        select(length > 0 and length <= 500) |
        select(test("^\\s*<") | not) |
        gsub("\n"; " ") |
        .[:80]
      ' 2>/dev/null | tail -1) || true

  [[ -n "$result" ]] && HOOK_TITLE="$result"
}

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
# macOS repo; on WSL it uses notify-send (WSLg / a Linux daemon), else a Windows
# balloon toast via PowerShell. The notifier is detached (setsid) with its fds
# closed: the agent waits on the hook's process group, and powershell.exe takes
# 1-2s just to start — a non-detached notifier is exactly what pinned the macOS
# "Running stop hook" for minutes (terminal-notifier). Best-effort, never blocks.
notify_mac() {
  local title="$1" message="$2"
  message=$(printf '%s' "$message" | tr '\n' ' ' | cut -c1-180)
  local detach=()
  command -v setsid >/dev/null 2>&1 && detach=(setsid -f)

  if command -v notify-send >/dev/null 2>&1; then
    ${detach[@]+"${detach[@]}"} notify-send "$title" "$message" </dev/null >/dev/null 2>&1 &
  elif command -v powershell.exe >/dev/null 2>&1; then
    # PowerShell single-quoted strings escape ' as ''.
    local q="'"
    local title_ps="${title//$q/$q$q}" message_ps="${message//$q/$q$q}"
    ${detach[@]+"${detach[@]}"} powershell.exe -NoProfile -NonInteractive -Command "
      Add-Type -AssemblyName System.Windows.Forms;
      \$n = New-Object System.Windows.Forms.NotifyIcon;
      \$n.Icon = [System.Drawing.SystemIcons]::Information;
      \$n.BalloonTipTitle = '${title_ps}'; \$n.BalloonTipText = '${message_ps}';
      \$n.Visible = \$true; \$n.ShowBalloonTip(4000); Start-Sleep -Seconds 5; \$n.Dispose()" \
      </dev/null >/dev/null 2>&1 &
  fi
  return 0
}

flash_window() {
  local pane_target="$1" label="$2"
  [[ -z "$pane_target" ]] && return 0
  command -v tmux >/dev/null 2>&1 || return 0
  local win_target="${pane_target%.*}"
  local active_window
  active_window=$(run_limited 2 tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null) || true
  [[ "$win_target" == "$active_window" ]] && return 0
  run_limited 2 tmux rename-window -t "$win_target" "$label" >/dev/null 2>&1 || true
}
