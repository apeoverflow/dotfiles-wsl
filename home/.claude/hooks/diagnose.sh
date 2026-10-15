#!/usr/bin/env bash
# Print hook / plugin / MCP state that explains a hung "Running stop hook"
# or a long start-plugin spinner. Read-only except for listing processes.
set -uo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

echo "=== hook files ==="
ls -la "$HOME/.claude/hooks/"
echo
echo "=== settings.json hook timeouts ==="
jq '{Stop: .hooks.Stop, Notification: .hooks.Notification, SessionStart: .hooks.SessionStart, enabledPlugins: .enabledPlugins}' \
  "$HOME/.claude/settings.json" 2>/dev/null || echo "(no settings.json)"
echo
echo "=== leftover notifiers (a non-detached notifier pins the Stop hook) ==="
if pgrep -f 'notify-send|powershell\.exe.*NotifyIcon' >/dev/null 2>&1; then
  ps -eo pid,etime,command | grep -E '[n]otify-send|[p]owershell\.exe.*NotifyIcon'
else
  echo "(none)"
fi
echo
echo "=== last 20 hook debug lines ($HOME/.claude/hooks/debug.jsonl) ==="
if [[ -f "$HOME/.claude/hooks/debug.jsonl" ]]; then
  tail -20 "$HOME/.claude/hooks/debug.jsonl"
else
  echo "(no debug.jsonl yet — run a turn first)"
fi
echo
echo "=== last hook errors ==="
if [[ -f "$HOME/.claude/hooks/error.log" ]]; then
  tail -20 "$HOME/.claude/hooks/error.log"
else
  echo "(none)"
fi
echo
echo "=== Claude MCP auth-needed cache ==="
cat "$HOME/.claude/mcp-needs-auth-cache.json" 2>/dev/null || echo "(none)"
echo
echo "=== Grok waiting_hooks durations (from unified.jsonl) ==="
python3 - <<'PY'
import json
from pathlib import Path
p = Path.home() / ".grok/logs/unified.jsonl"
if not p.exists():
    print("(no grok unified.jsonl)")
    raise SystemExit
enter = None
rows = []
for line in p.open():
    try:
        o = json.loads(line)
    except Exception:
        continue
    if o.get("msg") != "turn.phase_transition":
        continue
    ctx = o.get("ctx") or {}
    if ctx.get("to") == "waiting_hooks":
        enter = o.get("ts")
    elif ctx.get("from") == "waiting_hooks":
        rows.append((enter, o.get("ts"), ctx.get("phase_elapsed_ms"), ctx.get("to")))
        enter = None
print(f"{'started':<28} {'left':<28} {'wait_ms':>10}  next")
for start, end, ms, nxt in rows[-15:]:
    print(f"{start or '-':<28} {end or '-':<28} {ms or 0:10}  {nxt}")
slow = [r for r in rows if (r[2] or 0) >= 5000]
print(f"\n{len(slow)} waits >= 5s out of {len(rows)} recorded Stop-hook waits")
PY
echo
echo "To capture a live Grok hang: RUST_LOG=debug GROK_LOG_FILE=/tmp/grok-hooks.log grok"
echo "Then: rg -n 'waiting_hooks|hook' /tmp/grok-hooks.log"
echo "Hook debug log: $HOME/.claude/hooks/debug.jsonl"
