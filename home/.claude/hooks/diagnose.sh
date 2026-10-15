#!/usr/bin/env bash
# Print hook state that explains a hung Copilot agentStop hook or a missing ✓/!
# window tick. Read-only except for listing processes.
set -uo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

echo "=== hook files ==="
ls -la "$HOME/.claude/hooks/"
echo
echo "=== Copilot hooks (~/.copilot/settings.json — registered by install.sh) ==="
jq '.hooks // "(no hooks registered — re-run ~/dotfiles-wsl/install.sh)"' \
  "$HOME/.copilot/settings.json" 2>/dev/null || echo "(no ~/.copilot/settings.json — run copilot once)"
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
echo "=== hook-related lines in the newest Copilot log ==="
latest=$(ls -t "$HOME/.copilot/logs/"*.log 2>/dev/null | head -1)
if [[ -n "$latest" ]]; then
  grep -iE 'hook|agentStop' "$latest" | tail -15 || echo "(none in $latest)"
else
  echo "(no ~/.copilot/logs yet)"
fi
echo
echo "Hook debug log: $HOME/.claude/hooks/debug.jsonl"
