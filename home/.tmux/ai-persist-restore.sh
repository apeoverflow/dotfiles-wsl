#!/usr/bin/env bash
# ~/.tmux/ai-persist-restore.sh
# Re-attach claude/copilot sessions after tmux-resurrect has rebuilt the window
# geometry. Fired by @resurrect-hook-post-restore-all, so it runs after every
# restore (manual prefix+Ctrl-r or continuum auto-restore).
#
# tmux-resurrect brings each AI window back as a plain shell sitting in the
# correct worktree directory. We read the frozen ai-live.json and type the
# exact resume command into each restored pane:
#     claude  --resume  <session_id>
#     copilot --resume=<session_id>
set -uo pipefail

IN="${AI_PERSIST_DIR:-$HOME/.tmux/ai-persist}/ai-live.json"
[[ -f "$IN" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

is_shell() {
  case "$1" in
    zsh|-zsh|bash|-bash|sh|-sh|fish|-fish|login|reattach-to-user-namespace) return 0 ;;
    *) return 1 ;;
  esac
}

count=$(jq 'length' "$IN" 2>/dev/null || echo 0)
for (( i = 0; i < count; i++ )); do
  target=$(jq -r ".[$i].pane_target // empty" "$IN")
  tool=$(jq -r ".[$i].tool // empty" "$IN")
  sid=$(jq -r ".[$i].session_id // empty" "$IN")
  cwd=$(jq -r ".[$i].cwd // empty" "$IN")
  [[ -n "$target" && -n "$sid" && -n "$tool" ]] || continue

  # The pane must exist after the restore.
  info=$(tmux display-message -t "$target" -p '#{pane_current_command}||#{pane_current_path}' 2>/dev/null) || continue
  curcmd=${info%%||*}
  curpath=${info##*||}

  # Only type into a fresh shell — never stomp a pane that is already busy.
  is_shell "$curcmd" || continue
  # Guard against window/pane indices drifting: the dir must still match.
  [[ -n "$cwd" && "$cwd" != "$curpath" ]] && continue

  case "$tool" in
    claude)  cmd="claude --resume $sid" ;;
    copilot) cmd="copilot --resume=$sid" ;;
    *) continue ;;
  esac

  tmux send-keys -t "$target" "$cmd" C-m
done
